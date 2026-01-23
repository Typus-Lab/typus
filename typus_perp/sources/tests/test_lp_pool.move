
#[test_only]
module typus_perp::test_lp_pool {
    use std::type_name;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::sui::SUI;
    use sui::test_scenario::{Scenario, end, ctx, sender, next_tx, take_shared, return_shared, take_from_sender, return_to_sender, take_shared_by_id, take_immutable, return_immutable};

    use typus_perp::admin::{Self, Version};
    use typus_perp::babe::{Self, BABE};
    use typus_perp::babe2::{Self, BABE2};
    use typus_perp::error;
    use typus_perp::lp_pool::{Self, Registry, ManagerDepositReceipt};
    use typus_perp::math;
    use typus_perp::scallop_tests;
    use typus_perp::tlp::{Self, TLP};
    use typus_perp::trading::USD;
    use typus_perp::treasury_caps::{Self, TreasuryCaps};

    use oracle::oracle::{Self as navi_oracle};
    use oracle::oracle_manage;
    use pyth::pyth_tests;
    use pyth::pyth;
    use pyth::price_info::PriceInfoObject;
    use wormhole::state::{State as WormState};
    use wormhole::vaa::{Self, VAA};
    use protocol::mint;

    use typus_oracle::oracle::{Self as typus_oracle, Oracle, ManagerCap as OracleManagerCap};

    const ADMIN: address = @0xFFFF;
    const USER_2: address = @0xAA2;
    const CURRENT_TS_MS: u64 = 1_715_212_800_000;
    const LP_TOKEN_DECIMAL: u64 = 9;
    const UNLOCK_COUNTDOWN_TS_MS: u64 = 100000;
    const SUI_PRICE: u64 = 10_0000_0000;
    const SUI_PRICE_DECIMAL: u64 = 8;

    // spot config
    const TOKEN_DECIMAL: u64 = 9;
    const TARGET_WEIGHT_BP: u64 = 5000;
    const MIN_DEPOSIT: u64 = 1_0000_00000;
    const MAX_CAPACITY: u64 = 1_000_000_000_0000_00000;
    const BASIC_MINT_FEE_BP: u64 = 10;
    const ADDITIONAL_MINT_FEE_BP: u64 = 5;
    const BASIC_BURN_FEE_BP: u64 = 10;
    const ADDITIONAL_BURN_FEE_BP: u64 = 5;
    const SWAP_FEE_BP: u64 = 5;
    const SWAP_FEE_PROTOCOL_SHARE_BP: u64 = 3000;

    // margin config
    const BASIC_BORROW_RATE_0: u64 = 100;
    const BASIC_BORROW_RATE_1: u64 = 200;
    const BASIC_BORROW_RATE_2: u64 = 300;
    const UTILITY_THRESHOLD_BP_0: u64 = 3000;
    const UTILITY_THRESHOLD_BP_1: u64 = 6000;
    const FUNDING_INTERVAL_TS_MS: u64 = 10000;
    const MAX_ORDER_RESERVE_RATIO_BP: u64 = 1000;

    public struct FeePool has key, store {
        id: UID,
        fee_infos: vector<u64>,
    }

    fun new_registry(scenario: &mut Scenario) {
        lp_pool::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_version(scenario: &mut Scenario) {
        admin::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_tlp(scenario: &mut Scenario) {
        tlp::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);

        let treasury_cap = take_from_sender<TreasuryCap<TLP>>(scenario);
        let version = version(scenario);
        let mut treasury_caps = treasury_caps(scenario);
        treasury_caps::manager_store_treasury_cap(&version, &mut treasury_caps, treasury_cap, ctx(scenario));
        return_shared(version);
        return_shared(treasury_caps);
        next_tx(scenario, ADMIN);
    }

    fun new_treasury_caps(scenario: &mut Scenario) {
        treasury_caps::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun init_oracle(scenario: &mut Scenario) {
        typus_oracle::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_oracle<TOKEN>(scenario: &mut Scenario): ID {
        let manager_cap = oracle_manager_cap(scenario);
        typus_oracle::new_oracle<TOKEN, USD>(
            &manager_cap,
            type_name::with_defining_ids<TOKEN>().into_string(),
            std::ascii::string(b"USD"),
            8,
            ctx(scenario)
        );
        next_tx(scenario, ADMIN);
        let mut oracle = take_shared<Oracle>(scenario); // most recent shared object
        let id = object::id(&oracle);
        let clock = new_clock(scenario);
        typus_oracle::update(
            &mut oracle,
            &manager_cap,
            SUI_PRICE,
            SUI_PRICE,
            &clock,
            ctx(scenario)
        );
        return_shared(oracle);
        clock.destroy_for_testing();
        return_to_sender(scenario, manager_cap);
        next_tx(scenario, ADMIN);
        id
    }

    fun new_clock(scenario: &mut Scenario): Clock {
        let mut clock = clock::create_for_testing(ctx(scenario));
        update_clock(&mut clock, CURRENT_TS_MS);
        clock
    }

    fun update_clock(clock: &mut Clock, ts_ms: u64) {
        clock::set_for_testing(clock, ts_ms);
    }

    fun registry(scenario: &Scenario): Registry {
        take_shared<Registry>(scenario)
    }

    fun oracle_manager_cap(scenario: &Scenario): OracleManagerCap {
        take_from_sender<OracleManagerCap>(scenario)
    }

    fun version(scenario: &Scenario): Version {
        take_shared<Version>(scenario)
    }

    fun treasury_caps(scenario: &Scenario): TreasuryCaps {
        take_shared<TreasuryCaps>(scenario)
    }

    fun oracle(scenario: &Scenario, id: ID): Oracle {
        take_shared_by_id<Oracle>(scenario, id)
    }

    fun mint_test_coin<T>(scenario: &mut Scenario, amount: u64): Coin<T> {
        coin::mint_for_testing<T>(amount, ctx(scenario))
    }

    fun update_oracle(scenario: &mut Scenario, oracle: &mut Oracle, new_price: u64, ts_ms: u64) {
        let mut clock = new_clock(scenario);
        let manager_cap = oracle_manager_cap(scenario);
        update_clock(&mut clock, ts_ms);
        typus_oracle::update(
            oracle,
            &manager_cap,
            new_price,
            new_price,
            &clock,
            ctx(scenario)
        );
        clock.destroy_for_testing();
        return_to_sender(scenario, manager_cap);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_new_liquidity_pool_<LP_TOKEN>(scenario: &mut Scenario) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        lp_pool::new_liquidity_pool<LP_TOKEN>(
            &version,
            &mut registry,
            LP_TOKEN_DECIMAL,
            UNLOCK_COUNTDOWN_TS_MS,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_add_liquidity_token_<TOKEN>(scenario: &mut Scenario, oracle_id: ID, index: u64) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let clock = new_clock(scenario);
        let oracle = oracle(scenario, oracle_id);
        lp_pool::add_liquidity_token<TOKEN>(
            &version,
            &mut registry,
            index,
            &oracle,
            // config
            TOKEN_DECIMAL,
            // spot config
            TARGET_WEIGHT_BP,
            MIN_DEPOSIT,
            MAX_CAPACITY,
            BASIC_MINT_FEE_BP,
            ADDITIONAL_MINT_FEE_BP,
            BASIC_BURN_FEE_BP,
            ADDITIONAL_BURN_FEE_BP,
            SWAP_FEE_BP,
            SWAP_FEE_PROTOCOL_SHARE_BP,
            1000,
            BASIC_BORROW_RATE_0,
            BASIC_BORROW_RATE_1,
            BASIC_BORROW_RATE_2,
            UTILITY_THRESHOLD_BP_0,
            UTILITY_THRESHOLD_BP_1,
            FUNDING_INTERVAL_TS_MS,
            MAX_ORDER_RESERVE_RATIO_BP,
            &clock,
            ctx(scenario)
        );
        return_shared(oracle);
        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_mint_lp_<TOKEN>(
        scenario: &mut Scenario,
        oracle_id: ID,
        index: u64,
        deposit_amount: u64,
    ): u64 {
        let mut registry = registry(scenario);
        let mut version = version(scenario);
        let oracle = oracle(scenario, oracle_id);
        let mut treasury_caps = treasury_caps(scenario);
        let liquidity_coin = mint_test_coin<TOKEN>(scenario, deposit_amount);
        let clock = new_clock(scenario);
        let lp_coin = lp_pool::mint_lp<TOKEN, TLP>(
            &mut version,
            &mut registry,
            &mut treasury_caps,
            &oracle,
            index,
            // coin
            liquidity_coin,
            &clock,
            ctx(scenario)
        );
        let share = lp_coin.value();
        transfer::public_transfer(lp_coin, sender(scenario));
        return_shared(registry);
        return_shared(version);
        return_shared(oracle);
        return_shared(treasury_caps);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
        share
    }

    fun test_redeem_(
        scenario: &mut Scenario,
        index: u64,
        burn_amount: u64,
        ts_ms: u64,
    ) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let mut lp_token = take_from_sender<Coin<TLP>>(scenario);
        let burn_token = lp_token.split(burn_amount, ctx(scenario));
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        lp_pool::redeem<TLP>(
            &version,
            &mut registry,
            index,
            burn_token.into_balance(),
            &clock,
            ctx(scenario)
        );
        transfer::public_transfer(lp_token, sender(scenario));
        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_claim_(
        scenario: &mut Scenario,
        oracle_id: ID,
        index: u64,
        ts_ms: u64,
    ) {
        let mut registry = registry(scenario);
        let mut version = version(scenario);
        let mut oracle = oracle(scenario, oracle_id);
        let mut treasury_caps = treasury_caps(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        let oracle_manager_cap = oracle_manager_cap(scenario);
        oracle.update(
            &oracle_manager_cap,
            SUI_PRICE,
            SUI_PRICE,
            &clock,
            ctx(scenario)
        );
        let liquidity_token = lp_pool::claim<TLP, SUI>(
            &mut version,
            &mut registry,
            index,
            &mut treasury_caps,
            &oracle,
            &clock,
            ctx(scenario)
        );
        transfer::public_transfer(liquidity_token, sender(scenario));
        return_to_sender(scenario, oracle_manager_cap);
        return_shared(registry);
        return_shared(version);
        return_shared(oracle);
        return_shared(treasury_caps);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_calculate_mint_lp_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        price: u64,
        price_decimal: u64,
        deposit_amount: u64,
    ): (u64, u64, u64) {
        let registry = registry(scenario);

        let (deposit_amount_usd, mint_fee_usd, mint_amount) = lp_pool::calculate_mint_lp(
            &registry,
            index,
            type_name::with_defining_ids<TOKEN>(),
            price,
            price_decimal,
            deposit_amount,
        );

        return_shared(registry);
        next_tx(scenario, ADMIN);
        (deposit_amount_usd, mint_fee_usd, mint_amount)
    }

    fun test_calculate_burn_lp_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        price: u64,
        price_decimal: u64,
        burn_amount: u64,
    ): (u64, u64, u64) {
        let registry = registry(scenario);

        let (burn_amount_usd, burn_fee_usd, withdraw_token_amount, _burn_fee_token_amount) = lp_pool::calculate_burn_lp(
            &registry,
            index,
            type_name::with_defining_ids<TOKEN>(),
            price,
            price_decimal,
            burn_amount,
        );

        return_shared(registry);
        next_tx(scenario, ADMIN);
        (burn_amount_usd, burn_fee_usd, withdraw_token_amount)
    }

    fun test_swap_<F_TOKEN, T_TOKEN>(
        scenario: &mut Scenario,
        oracle_from_token: ID,
        oracle_to_token: ID,
        from_token_price: u64,
        to_token_price: u64,
        index: u64,
        from_amount: u64,
        ts_ms: u64,
    ): u64 {
        let mut version = version(scenario);
        let mut registry = registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);

        let mut from_token_oracle = oracle(scenario, oracle_from_token);
        let mut to_token_oracle = oracle(scenario, oracle_to_token);
        let sender_address = sender(scenario);
        next_tx(scenario, ADMIN);
        update_oracle(scenario, &mut from_token_oracle, from_token_price, ts_ms);
        update_oracle(scenario, &mut to_token_oracle, to_token_price, ts_ms);
        next_tx(scenario, sender_address);
        let from_coin = mint_test_coin<F_TOKEN>(scenario, from_amount);
        let from_amount_usd = math::amount_to_usd(from_amount, 9, from_token_price, 8);
        let min_to_amount_before_fee = math::usd_to_amount(from_amount_usd, 9, to_token_price, 8);
        let max_fee_bp = SWAP_FEE_BP * 2;
        let min_to_amount = min_to_amount_before_fee * (10000 - max_fee_bp) / 10000;

        let to_coin = lp_pool::swap<F_TOKEN, T_TOKEN>(
            &mut version,
            &mut registry,
            index,
            &from_token_oracle,
            &to_token_oracle,
            from_coin,
            min_to_amount,
            &clock,
            ctx(scenario),
        );
        let coin_value = to_coin.value();
        transfer::public_transfer(to_coin, sender(scenario));

        return_shared(version);
        return_shared(registry);
        return_shared(from_token_oracle);
        return_shared(to_token_oracle);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
        coin_value
    }

    fun test_update_liquidity_value<TOKEN>(
        scenario: &mut Scenario,
        oracle_id: ID,
        index: u64,
        ts_ms: u64,
    ) {
        let mut oracle = oracle(scenario, oracle_id);
        let version = version(scenario);
        let mut registry = registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        let oracle_manager_cap = oracle_manager_cap(scenario);
        oracle.update(
            &oracle_manager_cap,
            SUI_PRICE,
            SUI_PRICE,
            &clock,
            ctx(scenario)
        );
        lp_pool::update_liquidity_value<TOKEN>(
            &version,
            &mut registry,
            index,
            &oracle,
            &clock,
            ctx(scenario)
        );
        return_shared(oracle);
        return_shared(version);
        return_shared(registry);
        return_to_sender(scenario, oracle_manager_cap);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_suspend_pool_(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);

        lp_pool::suspend_pool(
            &version,
            &mut registry,
            index,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    fun test_resume_pool_(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);

        lp_pool::resume_pool(
            &version,
            &mut registry,
            index,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    fun test_suspend_token_pool_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);

        lp_pool::suspend_token_pool<TOKEN>(
            &version,
            &mut registry,
            index,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    fun test_resume_token_pool_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);

        lp_pool::resume_token_pool<TOKEN>(
            &version,
            &mut registry,
            index,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    fun test_update_unlock_countdown_ts_ms_(
        scenario: &mut Scenario,
        index: u64,
        unlock_countdown_ts_ms: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        lp_pool::update_unlock_countdown_ts_ms(
            &version,
            &mut registry,
            index,
            unlock_countdown_ts_ms,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    fun test_rebalance_<F_TOKEN, T_TOKEN>(
        scenario: &mut Scenario,
        oracle_from_token: ID,
        oracle_to_token: ID,
        from_token_price: u64,
        to_token_price: u64,
        index: u64,
        rebalance_amount: u64,
        assumed_swap_back_amount: u64,
        ts_ms: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let mut from_token_oracle = oracle(scenario, oracle_from_token);
        let mut to_token_oracle = oracle(scenario, oracle_to_token);
        let sender_address = sender(scenario);
        next_tx(scenario, ADMIN);
        update_oracle(scenario, &mut from_token_oracle, from_token_price, ts_ms);
        update_oracle(scenario, &mut to_token_oracle, to_token_price, ts_ms);
        next_tx(scenario, sender_address);

        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        let (rebalance_process, from_balance) = lp_pool::rebalance<F_TOKEN, T_TOKEN>(
            &version,
            &mut registry,
            index,
            &from_token_oracle,
            &to_token_oracle,
            rebalance_amount, // amount of A_TOKEN (to be swapped)
            &clock,
            ctx(scenario)
        );
        transfer::public_transfer(coin::from_balance(from_balance, ctx(scenario)), sender(scenario));
        let swapped_back_coin = mint_test_coin<T_TOKEN>(scenario, assumed_swap_back_amount);

        lp_pool::complete_rebalancing<F_TOKEN, T_TOKEN>(
            &version,
            &mut registry,
            index,
            &from_token_oracle,
            &to_token_oracle,
            swapped_back_coin.into_balance(),
            rebalance_process,
            &clock,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        return_shared(from_token_oracle);
        return_shared(to_token_oracle);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_update_rebalance_cost_threshold_bp_(
        scenario: &mut Scenario,
        index: u64,
        rebalance_cost_threshold_bp: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);

        lp_pool::update_rebalance_cost_threshold_bp(
            &version,
            &mut registry,
            index,
            rebalance_cost_threshold_bp,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }


    fun test_manager_emergency_deposit_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        deposit_amount: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let liquidity_coin = mint_test_coin<TOKEN>(scenario, deposit_amount);

        lp_pool::manager_emergency_deposit<TOKEN, TLP>(
            &version,
            &mut registry,
            index,
            liquidity_coin,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    fun test_manager_emergency_withdraw_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let manager_deposit_receipt_v2 = take_from_sender<ManagerDepositReceipt>(scenario);

        lp_pool::manager_emergency_withdraw<TOKEN>(
            &version,
            &mut registry,
            index,
            manager_deposit_receipt_v2,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    fun test_manager_remove_liquidity_token_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);

        lp_pool::manager_remove_liquidity_token<TOKEN>(
            &version,
            &mut registry,
            index,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    fun test_manager_deposit_scallop_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        lending_amount: Option<u64>, // none => deposit all
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let scallop_version = protocol::version::create_for_testing(ctx(scenario));
        let mut scallop_market = take_shared<protocol::market::Market>(scenario);
        let clock = new_clock(scenario);

        lp_pool::manager_deposit_scallop<TOKEN>(
            &version,
            &mut registry,
            index,
            &scallop_version,
            &mut scallop_market,
            &clock,
            lending_amount,
            ctx(scenario),
        );

        return_shared(version);
        return_shared(registry);
        return_shared(scallop_market);
        clock.destroy_for_testing();
        protocol::version::destroy_for_testing(scallop_version);
        next_tx(scenario, ADMIN);
    }

    fun test_manager_withdraw_scallop_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        withdraw_amount: Option<u64>
    ) {
        let mut version = version(scenario);
        let mut registry = registry(scenario);
        let scallop_version = protocol::version::create_for_testing(ctx(scenario));
        let mut scallop_market = take_shared<protocol::market::Market>(scenario);
        let clock = new_clock(scenario);

        lp_pool::manager_withdraw_scallop<TOKEN>(
            &mut version,
            &mut registry,
            index,
            &scallop_version,
            &mut scallop_market,
            &clock,
            withdraw_amount,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        return_shared(scallop_market);
        clock.destroy_for_testing();
        protocol::version::destroy_for_testing(scallop_version);
        next_tx(scenario, ADMIN);
    }

    fun test_manager_deposit_navi_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        lending_amount: Option<u64>, // none => deposit all
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let mut storage = take_shared<lending_core::storage::Storage>(scenario);
        let mut pool = take_shared<lending_core::pool::Pool<TOKEN>>(scenario);
        let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
        let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);
        let clock = new_clock(scenario);

        lp_pool::manager_deposit_navi<TOKEN>(
            &version,
            &mut registry,
            index,
            &mut storage,
            &mut pool,
            0,
            &mut incentive_v2,
            &mut incentive_v3,
            &clock,
            lending_amount,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        return_shared(storage);
        return_shared(pool);
        return_shared(incentive_v2);
        return_shared(incentive_v3);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    fun test_manager_reward_navi_<R_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let mut version = version(scenario);
        let mut registry = registry(scenario);
        let mut storage = take_shared<lending_core::storage::Storage>(scenario);
        let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);
        let mut reward_fund = take_shared<lending_core::incentive_v3::RewardFund<R_TOKEN>>(scenario);
        let clock = new_clock(scenario);

        let coin_types = vector[];
        let rule_ids = vector[];

        lp_pool::manager_reward_navi<R_TOKEN>(
            &mut version,
            &mut registry,
            index,
            &mut storage,
            &mut reward_fund,
            coin_types,
            rule_ids,
            &mut incentive_v3,
            &clock,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        return_shared(storage);
        return_shared(incentive_v3);
        return_shared(reward_fund);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    fun test_manager_withdraw_navi_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        asset: u8
    ) {
        let mut version = version(scenario);
        let mut registry = registry(scenario);
        let mut oracle_config = take_shared<oracle::config::OracleConfig>(scenario);
        let mut price_oracle = take_shared<oracle::oracle::PriceOracle>(scenario);
        let supra_oracle_holder = take_shared<SupraOracle::SupraSValueFeed::OracleHolder>(scenario);
        let pyth_price_info = take_shared<PriceInfoObject>(scenario);
        let feed_address = oracle::config::get_vec_feeds(&oracle_config)[asset as u64];
        let mut storage = take_shared<lending_core::storage::Storage>(scenario);
        let mut pool = take_shared<lending_core::pool::Pool<TOKEN>>(scenario);
        let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
        let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);
        let clock = new_clock(scenario);

        lp_pool::manager_withdraw_navi<TOKEN>(
            &mut version,
            &mut registry,
            index,
            &mut oracle_config,
            &mut price_oracle,
            &supra_oracle_holder,
            &pyth_price_info,
            feed_address,
            &mut storage,
            &mut pool,
            asset,
            &mut incentive_v2,
            &mut incentive_v3,
            &clock,
            ctx(scenario)
        );

        return_shared(version);
        return_shared(registry);
        return_shared(oracle_config);
        return_shared(price_oracle);
        return_shared(supra_oracle_holder);
        return_shared(pyth_price_info);
        return_shared(storage);
        return_shared(pool);
        return_shared(incentive_v2);
        return_shared(incentive_v3);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    fun test_view_swap_result_<F_TOKEN, T_TOKEN>(
        scenario: &mut Scenario,
        oracle_from_token: ID,
        oracle_to_token: ID,
        from_token_price: u64,
        to_token_price: u64,
        index: u64,
        from_amount: u64,
        ts_ms: u64,
    ): (u64, u64, u64) {
        let version = version(scenario);
        let registry = registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);

        let mut from_token_oracle = oracle(scenario, oracle_from_token);
        let mut to_token_oracle = oracle(scenario, oracle_to_token);
        let sender_address = sender(scenario);
        next_tx(scenario, ADMIN);
        update_oracle(scenario, &mut from_token_oracle, from_token_price, ts_ms);
        update_oracle(scenario, &mut to_token_oracle, to_token_price, ts_ms);
        next_tx(scenario, sender_address);

        let result = lp_pool::view_swap_result<F_TOKEN, T_TOKEN>(
            &version,
            &registry,
            index,
            &from_token_oracle,
            &to_token_oracle,
            from_amount,
            &clock
        );
        let (to_amount_after_fee, fee_amount, fee_amount_usd) = (result[0], result[1], result[2]);

        return_shared(version);
        return_shared(registry);
        return_shared(from_token_oracle);
        return_shared(to_token_oracle);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);

        (to_amount_after_fee, fee_amount, fee_amount_usd)
    }

    fun begin_test(): Scenario {
        let (mut scenario, _clock_ts_ms) = prepare_pyth();
        // let mut scenario = begin(ADMIN);
        babe::test_init(ctx(&mut scenario));
        babe2::test_init(ctx(&mut scenario));
        new_registry(&mut scenario);
        new_version(&mut scenario);
        init_oracle(&mut scenario);
        new_treasury_caps(&mut scenario);
        new_tlp(&mut scenario);
        test_new_liquidity_pool_<TLP>(&mut scenario);
        scenario
    }

    fun prepare_supra(scenario: &mut Scenario) {
        SupraOracle::SupraSValueFeed::test_init(ctx(scenario));
    }

    const BATCH_ATTESTATION_TEST_INITIAL_GUARDIANS: vector<vector<u8>> = vector[x"beFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"];
    const DEFAULT_BASE_UPDATE_FEE: u64 = 50;
    fun get_verified_test_vaas(worm_state: &WormState, clock: &Clock): vector<VAA> {
        let test_vaas_: vector<vector<u8>> = vector[x"0100000000010036eb563b80a24f4253bee6150eb8924e4bdf6e4fa1dfc759a6664d2e865b4b134651a7b021b7f1ce3bd078070b688b6f2e37ce2de0d9b48e6a78684561e49d5201527e4f9b00000001001171f8dcb863d176e2c420ad6610cf687359612b6fb392e0642b0ca6b1f186aa3b0000000000000001005032574800030000000102000400951436e0be37536be96f0896366089506a59763d036728332d3e3038047851aea7c6c75c89f14810ec1c54c03ab8f1864a4c4032791f05747f560faec380a695d1000000000000049a0000000000000008fffffffb00000000000005dc0000000000000003000000000100000001000000006329c0eb000000006329c0e9000000006329c0e400000000000006150000000000000007215258d81468614f6b7e194c5d145609394f67b041e93e6695dcc616faadd0603b9551a68d01d954d6387aff4df1529027ffb2fee413082e509feb29cc4904fe000000000000041a0000000000000003fffffffb00000000000005cb0000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e4000000000000048600000000000000078ac9cf3ab299af710d735163726fdae0db8465280502eb9f801f74b3c1bd190333832fad6e36eb05a8972fe5f219b27b5b2bb2230a79ce79beb4c5c5e7ecc76d00000000000003f20000000000000002fffffffb00000000000005e70000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e40000000000000685000000000000000861db714e9ff987b6fedf00d01f9fea6db7c30632d6fc83b7bc9459d7192bc44a21a28b4c6619968bd8c20e95b0aaed7df2187fd310275347e0376a2cd7427db800000000000006cb0000000000000001fffffffb00000000000005e40000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e400000000000007970000000000000001"];
        let mut verified_vaas_reversed = vector::empty<VAA>();
        let mut test_vaas = test_vaas_;
        let mut i = 0;
        while (i < vector::length(&test_vaas_)) {
            let cur_test_vaa = vector::pop_back(&mut test_vaas);
            let verified_vaa = vaa::parse_and_verify(worm_state, cur_test_vaa, clock);
            vector::push_back(&mut verified_vaas_reversed, verified_vaa);
            i=i+1;
        };
        let mut verified_vaas = vector::empty<VAA>();
        while (vector::length<VAA>(&verified_vaas_reversed)!=0){
            let cur = vector::pop_back(&mut verified_vaas_reversed);
            vector::push_back(&mut verified_vaas, cur);
        };
        vector::destroy_empty(verified_vaas_reversed);
        verified_vaas
    }
    fun prepare_pyth(): (Scenario, u64) {
        let (mut scenario, test_coins, clock) = pyth_tests::setup_test(
            500 /* stale_price_threshold */,
            23 /* governance emitter chain */,
            x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92",
            pyth_tests::data_sources_for_test_vaa(),
            BATCH_ATTESTATION_TEST_INITIAL_GUARDIANS,
            DEFAULT_BASE_UPDATE_FEE,
            0
        ); // => create DeployerCap, UpgradeCap. State shared
        next_tx(&mut scenario, ADMIN);
        let (mut pyth_state, worm_state) = pyth_tests::take_wormhole_and_pyth_states(&scenario);
        let verified_vaas = get_verified_test_vaas(&worm_state, &clock); // => get vector<VAA>
        pyth::create_price_feeds(
            &mut pyth_state,
            verified_vaas,
            &clock,
            ctx(&mut scenario)
        ); // => price info object shared
        transfer::public_transfer(test_coins, sender(&scenario));
        let ts_ms = clock.timestamp_ms();
        clock.destroy_for_testing();
        return_shared(pyth_state);
        return_shared(worm_state);
        (scenario, ts_ms)
    }

    fun prepare_navi_lending_env(scenario: &mut Scenario) {
        // oracle
        navi_oracle::init_for_testing(ctx(scenario));
        next_tx(scenario, ADMIN);
        let oracle_admin_cap = take_from_sender<oracle::oracle::OracleAdminCap>(scenario);
        oracle_manage::create_config(&oracle_admin_cap, ctx(scenario));
        next_tx(scenario, ADMIN);
        let mut oracle_config = take_shared<oracle::config::OracleConfig>(scenario);
        oracle_manage::create_price_feed<BABE>(
            &oracle_admin_cap,
            &mut oracle_config,
            0, // asset id
            0, // max_timestamp_diff
            0, // price_diff_threshold1
            0, // price_diff_threshold2
            0, // max_duration_within_thresholds
            0, // maximum_allowed_span_percentage
            115792089237316195423570985008687907853269984665640564039457584007913129639935, // maximum_effective_price
            1, // minimum_effective_price
            0, // historical_price_ttl
            ctx(scenario)
        );
        next_tx(scenario, ADMIN);
        let clock = new_clock(scenario);
        let mut price_oracle = take_shared<oracle::oracle::PriceOracle>(scenario);
        let (price, decimal) = (SUI_PRICE as u256, SUI_PRICE_DECIMAL as u8);
        oracle::oracle::register_token_price(&oracle_admin_cap, &clock, &mut price_oracle, 0, price, decimal);
        next_tx(scenario, ADMIN);

        prepare_supra(scenario);
        next_tx(scenario, ADMIN);

        // lending_core
        lending_core::pool::init_for_testing(ctx(scenario));
        next_tx(scenario, ADMIN);
        let pool_admin_cap = take_from_sender<lending_core::pool::PoolAdminCap>(scenario);
        lending_core::pool::create_pool_for_testing<BABE>(&pool_admin_cap, 9, ctx(scenario));
        next_tx(scenario, ADMIN);

        lending_core::storage::init_for_testing(ctx(scenario));
        next_tx(scenario, ADMIN);
        let storage_owner_cap = take_from_sender<lending_core::storage::OwnerCap>(scenario);
        let mut storage = take_shared<lending_core::storage::Storage>(scenario);
        let sui_coin_metadata = take_immutable<0x2::coin::CoinMetadata<BABE>>(scenario);
        let storage_admin_cap = take_from_sender<lending_core::storage::StorageAdminCap>(scenario);
        let max_capacity = 115792089237316195423570985008687907853269984665640564039457584007913129639935; // u256 max
        lending_core::storage::init_reserve<BABE>(
            &storage_admin_cap, &pool_admin_cap, &clock, &mut storage, 0,
            true, max_capacity, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, &sui_coin_metadata, ctx(scenario));
        next_tx(scenario, ADMIN);
        return_immutable(sui_coin_metadata);

        lending_core::incentive_v2::create_and_transfer_owner(&storage_owner_cap, ctx(scenario));
        next_tx(scenario, ADMIN);

        let incentive_v2_owner_cap = take_from_sender<lending_core::incentive_v2::OwnerCap>(scenario);
        lending_core::incentive_v2::create_incentive(&incentive_v2_owner_cap, ctx(scenario));
        lending_core::incentive_v3::init_for_testing(ctx(scenario));
        next_tx(scenario, ADMIN);
        let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);
        lending_core::manage::create_incentive_v3_pool<BABE>(&incentive_v2_owner_cap, &mut incentive_v3, &storage, 0, ctx(scenario));
        lending_core::manage::create_incentive_v3_reward_fund<SUI>(&incentive_v2_owner_cap, ctx(scenario));
        lending_core::manage::create_incentive_v3_reward_fund<BABE2>(&incentive_v2_owner_cap, ctx(scenario));
        next_tx(scenario, ADMIN);
        // set incentive rule: rule option = 1 => supply incentive
        lending_core::manage::create_incentive_v3_rule<BABE, SUI>(&incentive_v2_owner_cap, &clock, &mut incentive_v3, 1, ctx(scenario));
        lending_core::manage::create_incentive_v3_rule<BABE, BABE2>(&incentive_v2_owner_cap, &clock, &mut incentive_v3, 1, ctx(scenario));
        next_tx(scenario, ADMIN);
        let mut sui_reward_fund = take_shared<lending_core::incentive_v3::RewardFund<SUI>>(scenario);
        let incentive_coin = mint_test_coin<SUI>(scenario, 10000_0000_00000);
        lending_core::manage::deposit_incentive_v3_reward_fund<SUI>(&incentive_v2_owner_cap, &mut sui_reward_fund, incentive_coin, 10000_0000_00000, ctx(scenario));

        next_tx(scenario, ADMIN);
        let mut babe2_reward_fund = take_shared<lending_core::incentive_v3::RewardFund<BABE2>>(scenario);
        let incentive_coin = mint_test_coin<BABE2>(scenario, 10000_0000_00000);
        lending_core::manage::deposit_incentive_v3_reward_fund<BABE2>(&incentive_v2_owner_cap, &mut babe2_reward_fund, incentive_coin, 10000_0000_00000, ctx(scenario));

        let mut pool = take_shared<lending_core::pool::Pool<BABE>>(scenario);
        let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
        let babe_coin = mint_test_coin<BABE>(scenario, 1523_4567_89123);
        lending_core::incentive_v3::entry_deposit<BABE>(
            &clock,
            &mut storage,
            &mut pool,
            0, // BABE asset id = 0
            babe_coin,
            1523_4567_89123, // amount
            &mut incentive_v2,
            &mut incentive_v3,
            ctx(scenario)
        );
        next_tx(scenario, ADMIN);

        return_shared(incentive_v2);
        return_shared(incentive_v3);
        return_shared(storage);
        return_shared(pool);
        return_shared(sui_reward_fund);
        return_shared(babe2_reward_fund);
        return_shared(oracle_config);
        return_shared(price_oracle);
        return_to_sender(scenario, storage_admin_cap);
        return_to_sender(scenario, pool_admin_cap);
        return_to_sender(scenario, storage_owner_cap);
        return_to_sender(scenario, incentive_v2_owner_cap);
        return_to_sender(scenario, oracle_admin_cap);
        clock.destroy_for_testing();

        next_tx(scenario, ADMIN);
    }

    fun prepare_scallop_lending_env(scenario: &mut Scenario) {
        let clock = new_clock(scenario);
        let version = protocol::version::create_for_testing(ctx(scenario));
        let (mut market, admin_cap) = scallop_tests::app_init(scenario);
        let babe_interest_params = scallop_tests::babe_interest_model_params();
        next_tx(scenario, ADMIN);

        scallop_tests::add_interest_model_t<BABE>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &babe_interest_params, &clock);

        let mut coin_decimals_registry_obj = scallop_tests::coin_decimals_registry_init(scenario);
        coin_decimals_registry::coin_decimals_registry::register_decimals_t<BABE>(&mut coin_decimals_registry_obj, 9);

        next_tx(scenario, USER_2);
        let babe_coin = mint_test_coin<BABE>(scenario, 1000_0000_00000);
        let babe_amount = babe_coin.value();
        // clock::increment_for_testing(&mut clock, 100 * 1000);
        let market_coin = mint::mint(&version, &mut market, babe_coin, &clock, ctx(scenario));
        assert!(market_coin.value() == babe_amount, 0);

        transfer::public_transfer(market_coin, sender(scenario));

        protocol::version::destroy_for_testing(version);
        return_shared(coin_decimals_registry_obj);
        return_shared(market);
        transfer::public_transfer(admin_cap, sender(scenario));
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    // ======= Tests =======

    #[test]
    public(package) fun test_add_liquidity_token() {
        let mut scenario = begin_test();
        let index = 0;
        let oracle_id = new_oracle<SUI>(&mut scenario);
        test_add_liquidity_token_<SUI>(&mut scenario, oracle_id, index);
        end(scenario);
    }

    #[test]
    public(package) fun test_mint_and_swap_lp() {
        let mut scenario = begin_test();
        let index = 0;
        let oracle_id_sui = new_oracle<SUI>(&mut scenario);
        test_add_liquidity_token_<SUI>(&mut scenario, oracle_id_sui, index);
        let oracle_id_babe = new_oracle<BABE>(&mut scenario);
        test_add_liquidity_token_<BABE>(&mut scenario, oracle_id_babe, index);

        let mut share = 0;
        share = share + test_mint_lp_<SUI>(&mut scenario, oracle_id_sui, index, 10000_0000_00000);
        share = share + test_mint_lp_<BABE>(&mut scenario, oracle_id_babe, index, 1000_0000_00000);

        // liquidity = 10000, 1000
        // swap in 10 * 10 = 100 USD => out before fee = 100 / 11
        let ts_ms = CURRENT_TS_MS + 1;
        test_update_liquidity_value<SUI>(&mut scenario, oracle_id_sui, index, ts_ms);
        test_update_liquidity_value<BABE>(&mut scenario, oracle_id_babe, index, ts_ms);
        let from_token_price = 10_0000_0000;
        let to_token_price = 11_0000_0000;
        let (to_amount_after_fee, _fee_amount, _fee_amount_usd) = test_view_swap_result_<SUI, BABE>(
            &mut scenario,
            oracle_id_sui,
            oracle_id_babe,
            from_token_price,
            to_token_price,
            index,
            10_0000_00000,
            ts_ms
        );
        let swap_out_value = test_swap_<SUI, BABE>(
            &mut scenario,
            oracle_id_sui,
            oracle_id_babe,
            from_token_price,
            to_token_price,
            index,
            10_0000_00000,
            ts_ms
        );
        assert!(swap_out_value == 9_0826_40491 && swap_out_value == to_amount_after_fee, 0);

        // side without additional fee
        let from_token_price = 11_0000_0000;
        let to_token_price = 10_0000_0000;
        let swap_out_value = test_swap_<BABE, SUI>(
            &mut scenario,
            oracle_id_babe,
            oracle_id_sui,
            from_token_price,
            to_token_price,
            index,
            100_0000_00000,
            ts_ms
        );
        assert!(swap_out_value == 109_9450_00000, 0);

        {
            let version = version(&scenario);
            let registry = registry(&scenario);
            let (total_share_supply, _, _, _, _) = lp_pool::get_pool_liquidity(&version, &registry, index);
            assert!(share == total_share_supply, 0);
            return_shared(version);
            return_shared(registry);
        };

        end(scenario);
    }

    #[test]
    public(package) fun test_update_spot_config() {
        let mut scenario = begin_test();
        let index = 0;
        let oracle_id = new_oracle<SUI>(&mut scenario);
        test_add_liquidity_token_<SUI>(&mut scenario, oracle_id, index);
        let target_weight_bp = option::some(8000);

        {
            let mut registry = registry(&scenario);
            let version = version(&scenario);
            lp_pool::update_spot_config<SUI>(
                &version,
                &mut registry,
                index,
                target_weight_bp,
                option::some(MIN_DEPOSIT),
                option::some(MAX_CAPACITY),
                option::some(BASIC_MINT_FEE_BP),
                option::some(ADDITIONAL_MINT_FEE_BP),
                option::some(BASIC_BURN_FEE_BP),
                option::some(ADDITIONAL_BURN_FEE_BP),
                option::some(SWAP_FEE_BP),
                option::some(SWAP_FEE_PROTOCOL_SHARE_BP),
                option::some(1000),
                ctx(&mut scenario)
            );

            return_shared(registry);
            return_shared(version);

            next_tx(&mut scenario, ADMIN);
        };

        {
            let registry = registry(&scenario);
            let target_weight_bp = target_weight_bp.borrow();
            assert!(lp_pool::test_check_target_weight_bp<SUI>(&registry, index, *target_weight_bp), 0);
            return_shared(registry);
            next_tx(&mut scenario, ADMIN);
        };

        end(scenario);
    }

    #[test]
    public(package) fun test_update_margin_config() {
        let mut scenario = begin_test();
        let index = 0;
        let oracle_id = new_oracle<SUI>(&mut scenario);
        test_add_liquidity_token_<SUI>(&mut scenario, oracle_id, index);

        let basic_borrow_rate_0 = option::some(1000);
        let basic_borrow_rate_1 = option::some(2000);
        let basic_borrow_rate_2 = option::some(3000);
        let utilization_threshold_bp_0 = option::some(1000);
        let utilization_threshold_bp_1 = option::some(2000);

        {
            let mut registry = registry(&scenario);
            let version = version(&scenario);
            lp_pool::update_margin_config<SUI>(
                &version,
                &mut registry,
                index,
                basic_borrow_rate_0,
                basic_borrow_rate_1,
                basic_borrow_rate_2,
                utilization_threshold_bp_0,
                utilization_threshold_bp_1,
                option::none(),
                option::none(),
                ctx(&mut scenario)
            );

            return_shared(registry);
            return_shared(version);

            next_tx(&mut scenario, ADMIN);
        };

        {
            let registry = registry(&scenario);
            let basic_borrow_rate_0 = basic_borrow_rate_0.borrow();
            assert!(lp_pool::test_check_basic_borrow_rate<SUI>(&registry, index, *basic_borrow_rate_0), 0);
            return_shared(registry);
            next_tx(&mut scenario, ADMIN);
        };

        end(scenario);
    }

    #[test]
    public(package) fun test_calculate_mint_and_burn_lp() {
        let mut scenario = begin_test();
        let index = 0;
        let oracle_id_sui = new_oracle<SUI>(&mut scenario);
        test_add_liquidity_token_<SUI>(&mut scenario, oracle_id_sui, index);
        let oracle_id_babe = new_oracle<BABE>(&mut scenario);
        test_add_liquidity_token_<BABE>(&mut scenario, oracle_id_babe, index);

        let (price, price_decimal) = (SUI_PRICE, SUI_PRICE_DECIMAL);

        let deposit_amount = 1000000_0000_00000;

        // deposited liquidity usd = 1000000 * 10 = 10000000 => 500000_0000_0000

        let (deposit_amount_usd, mint_fee_usd, mint_amount)
            = test_calculate_mint_lp_<SUI>(&mut scenario, index, price, price_decimal, deposit_amount);
        test_mint_lp_<SUI>(&mut scenario, oracle_id_sui, index, deposit_amount);
        assert!(10000000000000000 == deposit_amount_usd, 0);
        assert!(10000000000000 == mint_fee_usd, 1);
        assert!(9990000000000000 == mint_amount, 2);

        let (deposit_amount_usd, mint_fee_usd, mint_amount)
            = test_calculate_mint_lp_<SUI>(&mut scenario, index, price, price_decimal, deposit_amount);

        test_mint_lp_<SUI>(&mut scenario, oracle_id_sui, index, deposit_amount);
        assert!(10000000000000000 == deposit_amount_usd, 0);
        assert!(20000000000000 == mint_fee_usd, 1);
        assert!(9980000000000000 == mint_amount, 2);

        let burn_amount = mint_amount / 2;
        let (burn_amount_usd, burn_fee_usd, withdraw_token_amount)
            = test_calculate_burn_lp_<SUI>(&mut scenario, index, price, price_decimal, burn_amount);
        let ts_ms = CURRENT_TS_MS + 1;
        test_update_liquidity_value<SUI>(&mut scenario, oracle_id_sui, index, ts_ms);
        test_update_liquidity_value<BABE>(&mut scenario, oracle_id_babe, index, ts_ms);
        test_redeem_(&mut scenario, index, burn_amount, ts_ms);
        let ts_ms = CURRENT_TS_MS + 10000;
        test_update_liquidity_value<SUI>(&mut scenario, oracle_id_sui, index, ts_ms);
        test_update_liquidity_value<BABE>(&mut scenario, oracle_id_babe, index, ts_ms);
        test_redeem_(&mut scenario, index, burn_amount, ts_ms);
        {
            let registry = registry(&scenario);
            let result = lp_pool::get_user_deactivating_shares<TLP>(&registry, index, sender(&scenario));
            assert!(result.length() > 0, 0);
            let result = lp_pool::get_user_deactivating_shares<TLP>(&registry, index, USER_2);
            assert!(result.length() == 0, 0);
            return_shared(registry);
            next_tx(&mut scenario, ADMIN);
        };

        // update unlock time => not effective on previously redempt shares
        test_update_unlock_countdown_ts_ms_(&mut scenario, index, UNLOCK_COUNTDOWN_TS_MS / 2);

        let ts_ms = CURRENT_TS_MS + UNLOCK_COUNTDOWN_TS_MS / 2 + 1;
        test_update_liquidity_value<SUI>(&mut scenario, oracle_id_sui, index, ts_ms);
        test_update_liquidity_value<BABE>(&mut scenario, oracle_id_babe, index, ts_ms);
        test_claim_(&mut scenario, oracle_id_sui, index, ts_ms); // nothing happened

        let ts_ms = CURRENT_TS_MS + UNLOCK_COUNTDOWN_TS_MS + 1;
        test_update_liquidity_value<SUI>(&mut scenario, oracle_id_sui, index, ts_ms);
        test_update_liquidity_value<BABE>(&mut scenario, oracle_id_babe, index, ts_ms);
        test_claim_(&mut scenario, oracle_id_sui, index, ts_ms);

        // collateral token amount = 999000_0000_00000 + 998000_0000_00000 = 1,997,000,000,000,000
        // total lp minted amount = 9990000000000000 + 9980000000000000 = 19970000000000000
        // burn amount = 9980000000000000
        // => burn_amount_usd = 1,997,000,000,000,000 * (9980000000000000 / 19970000000000000) = 9,980,000,000,000,000
        // => burn_fee_usd = burn_amount_usd / 1000 = 9,980,000,000,000
        // => withdraw_token_amount = (burn_amount_usd - burn_fee_usd) / price = (9,980,000,000,000,000 - 9,980,000,000,000) / 10 = 997002000000000
        assert!(4990000000000000 == burn_amount_usd, 0);
        assert!(4990000000000 == burn_fee_usd, 1);
        assert!(498501000000000 == withdraw_token_amount, 2);

        let ts_ms = CURRENT_TS_MS + UNLOCK_COUNTDOWN_TS_MS + 10000 + 1; // claim last deactivating share
        test_update_liquidity_value<SUI>(&mut scenario, oracle_id_sui, index, ts_ms);
        test_update_liquidity_value<BABE>(&mut scenario, oracle_id_babe, index, ts_ms);
        test_claim_(&mut scenario, oracle_id_sui, index, ts_ms);

        end(scenario);
    }

    #[test]
    public(package) fun test_manager_emergency_deposit_and_withdraw() {
        let mut scenario = begin_test();
        let index = 0;
        let oracle_id_sui = new_oracle<SUI>(&mut scenario);
        test_add_liquidity_token_<SUI>(&mut scenario, oracle_id_sui, index);
        let oracle_id_babe = new_oracle<BABE>(&mut scenario);
        test_add_liquidity_token_<BABE>(&mut scenario, oracle_id_babe, index);

        test_mint_lp_<SUI>(&mut scenario, oracle_id_sui, index, 1000_0000_00000);
        test_mint_lp_<BABE>(&mut scenario, oracle_id_babe, index, 1000_0000_00000);

        test_manager_emergency_deposit_<SUI>(&mut scenario, index, 100_0000_00000);
        test_manager_emergency_withdraw_<SUI>(&mut scenario, index);

        test_suspend_token_pool_<SUI>(&mut scenario, index);
        test_resume_token_pool_<SUI>(&mut scenario, index);
        test_suspend_pool_(&mut scenario, index);
        test_resume_pool_(&mut scenario, index);
        test_rebalance_<BABE, SUI>(
            &mut scenario,
            oracle_id_babe,
            oracle_id_sui,
            10_0000_0000,
            10_0000_0000,
            index,
            10_0000_00000,
            10_0000_00000,
            CURRENT_TS_MS,
        );

        test_rebalance_<BABE, SUI>(
            &mut scenario,
            oracle_id_babe,
            oracle_id_sui,
            10_0000_0000,
            10_0000_0000,
            index,
            988_4994_99500,
            988_4994_99500,
            CURRENT_TS_MS,
        );
        test_suspend_token_pool_<BABE>(&mut scenario, index);
        test_manager_remove_liquidity_token_<BABE>(&mut scenario, index);
        end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = error::EExceedRebalanceCostThreshold)]
    public(package) fun test_manager_rebalance_failed() {
        let mut scenario = begin_test();
        let index = 0;
        let oracle_id_sui = new_oracle<SUI>(&mut scenario);
        test_add_liquidity_token_<SUI>(&mut scenario, oracle_id_sui, index);
        let oracle_id_babe = new_oracle<BABE>(&mut scenario);
        test_add_liquidity_token_<BABE>(&mut scenario, oracle_id_babe, index);

        test_mint_lp_<SUI>(&mut scenario, oracle_id_sui, index, 1000_0000_00000);
        test_mint_lp_<BABE>(&mut scenario, oracle_id_babe, index, 1000_0000_00000);

        test_rebalance_<BABE, SUI>(
            &mut scenario,
            oracle_id_babe,
            oracle_id_sui,
            10_0000_0000,
            10_0000_0000,
            index,
            10_0000_00000,
            10_0000_00000,
            CURRENT_TS_MS,
        );

        test_update_rebalance_cost_threshold_bp_(&mut scenario, index, 0);

        test_rebalance_<BABE, SUI>(
            &mut scenario,
            oracle_id_babe,
            oracle_id_sui,
            10_0000_0000,
            10_0000_0000,
            index,
            988_4000_00000,
            988_0000_00000, // swapped back amount not enough
            CURRENT_TS_MS,
        ); // tx failed
        end(scenario);
    }

    #[test]
    public(package) fun test_manager_lending() {
        let mut scenario = begin_test();
        prepare_navi_lending_env(&mut scenario);
        prepare_scallop_lending_env(&mut scenario);
        let index = 0;
        let oracle_id_sui = new_oracle<SUI>(&mut scenario);
        test_add_liquidity_token_<SUI>(&mut scenario, oracle_id_sui, index);
        let oracle_id_babe = new_oracle<BABE>(&mut scenario);
        test_add_liquidity_token_<BABE>(&mut scenario, oracle_id_babe, index);

        test_mint_lp_<SUI>(&mut scenario, oracle_id_sui, index, 1000_0000_00000);
        test_mint_lp_<BABE>(&mut scenario, oracle_id_babe, index, 1000_0000_00000);

        test_manager_deposit_navi_<BABE>(&mut scenario, index, option::some(10000));
        test_manager_deposit_navi_<BABE>(&mut scenario, index, option::none());
        test_manager_deposit_navi_<BABE>(&mut scenario, index, option::some(10000)); // nothing happened
        test_manager_reward_navi_<SUI>(&mut scenario, index);
        test_manager_reward_navi_<BABE2>(&mut scenario, index);
        test_manager_withdraw_navi_<BABE>(&mut scenario, index, 0);
        test_manager_withdraw_navi_<BABE>(&mut scenario, index, 0); // nothing happened
        test_manager_deposit_scallop_<BABE>(&mut scenario, index, option::some(10000));
        test_manager_deposit_scallop_<BABE>(&mut scenario, index, option::none());
        test_manager_deposit_scallop_<BABE>(&mut scenario, index, option::some(10000)); // nothing happened
        test_manager_withdraw_scallop_<BABE>(&mut scenario, index, option::some(100));
        test_manager_withdraw_scallop_<BABE>(&mut scenario, index, option::none());
        test_manager_withdraw_scallop_<BABE>(&mut scenario, index, option::none()); // nothing happened

        end(scenario);
    }

    // manager_deposit_scallop
    // manager_withdraw_scallop
    // manager_withdraw_navi
    // reward_navi with other token type -> done
    // calculate_lending_amount_capped different cases
    // claim with zero tlp_balance value and different remaining_shares.length case -> done
    // swap with f_token_fee_usd vs t_token_fee_usd cases
    // update_borrow_info in different utilization cases -> should be done in trading tests (use lp_pool::order_filled to update reserved_amount)
    // create_deactivating_shares -> removed
    // update_unlock_countdown_ts_ms -> done
    // update_rebalance_cost_threshold_bp -> done
}

#[test_only]
module typus_perp::babe {
    use sui::coin;
    use sui::url;

    public struct BABE has drop {}

    const Decimals: u8 = 9;
    // Due to the package size, we changed it to a test_only function
    #[test_only]
    fun init(witness: BABE, ctx: &mut TxContext) {
        let (treasury_cap, coin_metadata) = coin::create_currency(
            witness,
            Decimals,
            b"BABE",
            b"Typus Perp LP Token",
            b"Typus Perp LP Token Description", // TODO: update description
            option::some(url::new_unsafe_from_bytes(b"https://raw.githubusercontent.com/Typus-Lab/typus-asset/main/assets/BABE.svg")),
            ctx
        );

        transfer::public_freeze_object(coin_metadata);
        transfer::public_transfer(treasury_cap, ctx.sender());
    }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(BABE {}, ctx);
    }
}


#[test_only]
module typus_perp::babe2 {
    use sui::coin;
    use sui::url;

    public struct BABE2 has drop {}

    const Decimals: u8 = 9;
    // Due to the package size, we changed it to a test_only function
    #[test_only]
    fun init(witness: BABE2, ctx: &mut TxContext) {
        let (treasury_cap, coin_metadata) = coin::create_currency(
            witness,
            Decimals,
            b"BABE2",
            b"Typus Perp LP Token 2",
            b"Typus Perp LP Token Description 2", // TODO: update description
            option::some(url::new_unsafe_from_bytes(b"https://raw.githubusercontent.com/Typus-Lab/typus-asset/main/assets/BABE.svg")),
            ctx
        );

        transfer::public_freeze_object(coin_metadata);
        transfer::public_transfer(treasury_cap, ctx.sender());
    }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(BABE2 {}, ctx);
    }
}

#[test_only]
module typus_perp::scallop_tests {
    use sui::test_scenario::{Self, Scenario, next_tx, next_epoch, sender, ctx, take_shared, take_from_sender};
    use sui::clock::Clock;
    use protocol::market::Market;
    use protocol::app::{Self, AdminCap};
    use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};
    use math::u64;
    use typus_perp::babe::BABE;

    const ADMIN: address = @0xFFFF;

    public struct InterestModelParams<phantom T> has copy, drop {
        base_rate_per_sec: u64,
        interest_rate_scale: u64,
        borrow_rate_on_mid_kink: u64,
        mid_kink: u64,
        borrow_rate_on_high_kink: u64,
        high_kink: u64,
        max_borrow_rate: u64,
        revenue_factor: u64,
        scale: u64,
        min_borrow_amount: u64,
        borrow_weight: u64,
    }

    public fun app_init(scenario: &mut Scenario): (Market, AdminCap) {
        app::init_t(ctx(scenario));
        let sender = sender(scenario);
        next_tx(scenario, sender);
        let adminCap = take_from_sender<AdminCap>(scenario);
        let mut market = take_shared<Market>(scenario);

        app::update_borrow_fee<BABE>(
            &adminCap,
            &mut market,
            0,
            1
        );

        app::update_supply_limit<BABE>(
            &adminCap,
            &mut market,
            1_000_000 * std::u64::pow(10, 9),
        );

        app::update_borrow_limit<BABE>(
            &adminCap,
            &mut market,
            1_000_000 * std::u64::pow(10, 9),
        );

        app::update_min_collateral_amount<BABE>(
        &adminCap,
        &mut market,
        std::u64::pow(10, 9), // 1 BABE
        );

        app::init_market_coin_price_table(
            &adminCap,
            &mut market,
            test_scenario::ctx(scenario)
        );

        app::set_apm_threshold<BABE>(
            &adminCap,
            &mut market,
            200,
            test_scenario::ctx(scenario)
        );

        app::whitelist_allow_all(&adminCap, &mut market, test_scenario::ctx(scenario));

        (market, adminCap)
    }

    public fun babe_interest_model_params(): InterestModelParams<BABE> {
        let interest_rate_scale = std::u64::pow(10, 7);
        let scale = std::u64::pow(10, 12);
        let secs_per_year = 365 * 24 * 60 * 60;

        let borrow_rate_on_mid_kink = 8 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
        let borrow_rate_on_high_kink = 50 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
        let max_borrow_rate = 300 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
        InterestModelParams {
            base_rate_per_sec: 0,
            interest_rate_scale,
            borrow_rate_on_mid_kink,
            borrow_rate_on_high_kink,
            max_borrow_rate,
            mid_kink: u64::mul_div(60, scale, 100),
            high_kink: u64::mul_div(90, scale, 100),
            revenue_factor: u64::mul_div(2, scale, 100),
            scale,
            min_borrow_amount: std::u64::pow(10, 8),
            borrow_weight: 1 * scale,
        }
    }

    public fun add_interest_model_t<T>(
        scenario: &mut Scenario,
        outflow_limit: u64, outflow_cycle_duration: u32, outflow_segment_duration: u32,
        market: &mut Market, admin_cap: &AdminCap, params: &InterestModelParams<T>, clock: &Clock,
    ) {
        test_scenario::next_tx(scenario, ADMIN);
        let interest_model = app::create_interest_model_change<T>(
            admin_cap,
            base_rate_per_sec(params),
            interest_rate_scale(params),
            borrow_rate_on_mid_kink(params),
            mid_kink(params),
            borrow_rate_on_high_kink(params),
            high_kink(params),
            max_borrow_rate(params),
            revenue_factor(params),
            borrow_weight(params),
            interest_model_scale(params),
            min_borrow_amount(params),
            test_scenario::ctx(scenario)
        );
        app::add_interest_model<T>(
            market,
            admin_cap,
            interest_model,
            clock,
            test_scenario::ctx(scenario),
        );

        skip_epoch(scenario, 11);

        app::add_limiter<T>(
            admin_cap,
            market,
            outflow_limit,
            outflow_cycle_duration,
            outflow_segment_duration,
            ctx(scenario)
        );
        next_tx(scenario, ADMIN);
    }

    public fun skip_epoch(scenario: &mut Scenario, number_of_skipped_epoch: u32) {
        let mut i = 0;
        while (i < number_of_skipped_epoch) {
            next_epoch(scenario, @0x0);
            i = i + 1;
        };
    }

    public fun coin_decimals_registry_init(scenario: &mut Scenario): CoinDecimalsRegistry {
        coin_decimals_registry::init_t(ctx(scenario));
        let sender = sender(scenario);
        next_tx(scenario, sender);
        take_shared<CoinDecimalsRegistry>(scenario)
    }

    public fun base_rate_per_sec<T>(params: &InterestModelParams<T>): u64 { params.base_rate_per_sec }
    public fun interest_rate_scale<T>(params: &InterestModelParams<T>): u64 { params.interest_rate_scale }
    public fun borrow_rate_on_mid_kink<T>(params: &InterestModelParams<T>): u64 { params.borrow_rate_on_mid_kink }
    public fun mid_kink<T>(params: &InterestModelParams<T>): u64 { params.mid_kink }
    public fun borrow_rate_on_high_kink<T>(params: &InterestModelParams<T>): u64 { params.borrow_rate_on_high_kink }
    public fun high_kink<T>(params: &InterestModelParams<T>): u64 { params.high_kink }
    public fun max_borrow_rate<T>(params: &InterestModelParams<T>): u64 { params.max_borrow_rate }
    public fun revenue_factor<T>(params: &InterestModelParams<T>): u64 { params.revenue_factor }
    public fun interest_model_scale<T>(params: &InterestModelParams<T>): u64 { params.scale }
    public fun min_borrow_amount<T>(params: &InterestModelParams<T>): u64 { params.min_borrow_amount }
    public fun borrow_weight<T>(params: &InterestModelParams<T>): u64 { params.borrow_weight }
}

/// The `tlp` module defines the TLP token and its associated functions.
#[test_only]
module typus_perp::tlp {
    use sui::coin_registry;

    /// The TLP token.
    public struct TLP has drop {}

    /// The number of decimals for the TLP token.
    const Decimals: u8 = 9;

    /// Initializes the TLP token.
    fun init(witness: TLP, ctx: &mut TxContext) {
        let (builder, treasury_cap) = coin_registry::new_currency_with_otw(
            witness,
            Decimals,
            std::string::utf8(b"TLP"),
            std::string::utf8(b"Typus Perp LP Token Main Pool"),
            std::string::utf8(b"Typus Perp LP Token for Main Pool"),
            std::string::utf8(b"https://raw.githubusercontent.com/Typus-Lab/typus-asset/main/assets/TLP.svg"),
            ctx
        );
        let metadata_cap = builder.finalize(ctx);

        transfer::public_transfer(metadata_cap, tx_context::sender(ctx));
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(TLP {}, ctx);
    }
}