#[test_only]
module typus_perp::test_trading {
    use std::type_name;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::sui::SUI;
    use sui::test_scenario::{Scenario, begin, end, ctx, sender, next_tx, take_shared, return_shared, take_from_sender, return_to_sender, take_shared_by_id, take_from_address};
    use sui::transfer_policy;

    use typus_perp::admin::{Self, Version};
    use typus_perp::profit_vault::{Self, ProfitVault};
    use typus_perp::tlp::{Self, TLP};
    use typus_perp::trading::{Self, MarketRegistry};
    use typus_perp::lp_pool::{Self, Registry as LpPoolRegistry};
    use typus_perp::treasury_caps::{Self, TreasuryCaps};
    use typus_perp::test_lp_pool;
    use typus_perp::competition::{Self, CompetitionConfig};
    use typus_perp::babe::BABE;

    use typus_nft::typus_nft::{Self, Tails, ManagerCap as TailsManagerCap};
    use typus::ecosystem::{Self, Version as TypusEcosystemVersion};
    use typus::leaderboard::{Self, TypusLeaderboardRegistry};
    use typus::tails_staking::{Self, TailsStakingRegistry};
    use typus::tgld::{Self, TgldRegistry};
    use typus::user::{Self, TypusUserRegistry};
    use typus_oracle::oracle::{Self, Oracle, ManagerCap as OracleManagerCap};
    use typus_dov::typus_dov_single::{Self, Registry as DovRegistry};
    use typus_dov::tds_user_entry;
    use typus_dov::tds_authorized_entry;
    use typus_dov::tds_registry_authorized_entry;
    use typus_framework::vault::TypusBidReceipt;

    const ADMIN: address = @0xFFFF;
    const USER_1: address = @0xAA1;
    const USER_2: address = @0xAA2;
    const SUI_PRICE: u64 = 10_0000_0000;
    const MARKET_INDEX: u64 = 0;
    const TRADING_FEE_PROTOCOL_SHARE_BP: u64 = 3000;
    // market info
    const SIZE_DECIMAL: u64 = 9;
    // market config
    // const oracle: &PriceInfoObject = ;
    const MAX_LEVERAGE_MBP: u64 = 1000000000;
    const OPTION_COLLATERAL_MAX_LEVERAGE_MBP: u64 = 100000000000;
    const MIN_SIZE: u64 = 1_0000_00000;
    const LOT_SIZE: u64 = 1_0000_00000;
    const TRADING_FEE_CONFIG: vector<u64> = vector[0_0010_000, 0_0020_000, 0_2000_000, 2, 1];
    const BASIC_FUNDING_RATE: u64 = 0_0001_00000;

    const EXP_MULTIPLIER: u64 = 200;
    const COOL_DOWN_THRESHOLD_TS_MS: u64 = 10_000;
    const MAX_BUY_OPEN_INTEREST: u64 = 1_000_000_000000000; // 1 million SUI
    const MAX_SELL_OPEN_INTEREST: u64 = 1_000_000_000000000;
    const MAINTENANCE_MARGIN_RATE_BP: u64 = 150; // 1.5%
    const OPTION_MAINTENANCE_MARGIN_RATE_BP: u64 = 20; // 0.2%
    const OPTION_TRADING_FEE_CONFIG: vector<u64> = vector[0_0002_000, 0_0004_000, 0_5000_000, 1, 1];
    const TRADING_FEE_FORMULA_VERSION: u64 = 0;
    const PROFIT_VAULT_FLAG: u64 = 0;

    const UNLOCK_COUNTDOWN_TS_MS: u64 = 3_600_000;

    const CURRENT_TS_MS: u64 = 1_715_212_800_000;
    const FUNDING_INTERVAL_TS_MS: u64 = 3_600_000;

    public struct TOKEN_1 has drop {}
    public struct TOKEN_2 has drop {}
    public struct USD has drop {}

    fun new_registry(scenario: &mut Scenario) {
        trading::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_lp_pool_registry(scenario: &mut Scenario) {
        lp_pool::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_version(scenario: &mut Scenario) {
        admin::test_init(ctx(scenario));
        ecosystem::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_clock(scenario: &mut Scenario): Clock {
        let mut clock = clock::create_for_testing(ctx(scenario));
        clock::set_for_testing(&mut clock, CURRENT_TS_MS);
        clock
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

    fun new_profit_vault(scenario: &mut Scenario) {
        let version = version(scenario);
        profit_vault::create_profit_vault(&version, UNLOCK_COUNTDOWN_TS_MS, ctx(scenario));
        profit_vault::create_lock_vault(&version, ctx(scenario));
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun new_typus_user_registry(scenario: &mut Scenario) {
        user::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_leaderboard_registry(scenario: &mut Scenario) {
        leaderboard::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_tgld_registry(scenario: &mut Scenario) {
        tgld::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_competition_config(scenario: &mut Scenario) {
        let version = version(scenario);
        let program_name = std::ascii::string(b"");
        competition::new_competition_config(
            &version,
            vector[1, 1, 1, 1, 1, 1, 1, 1],
            program_name,
            ctx(scenario)
        );
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun new_tails_staking_registry(scenario: &mut Scenario) {
        let ecosystem_version = ecosystem_version(scenario);
        let typus_nft_manager_cap = typus_nft_manager_cap(scenario);
        let (policy, policy_cap) = transfer_policy::new_for_testing<Tails>(ctx(scenario));
        tails_staking::init_tails_staking_registry(
            &ecosystem_version,
            typus_nft_manager_cap,
            policy,
            ctx(scenario),
        );
        return_shared(ecosystem_version);
        transfer::public_transfer(policy_cap, sender(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_treasury_caps(scenario: &mut Scenario) {
        treasury_caps::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_nft_pool(scenario: &mut Scenario) {
        typus_nft::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_dov_registry(scenario: &mut Scenario) {
        typus_dov_single::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun init_oracle(scenario: &mut Scenario) {
        oracle::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_oracle<TOKEN>(scenario: &mut Scenario): ID {
        let manager_cap = oracle_manager_cap(scenario);
        oracle::new_oracle<TOKEN, USD>(
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
        oracle::update(
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

    fun update_oracle(scenario: &mut Scenario, oracle: &mut Oracle, new_price: u64, ts_ms: u64) {
        let mut clock = new_clock(scenario);
        let manager_cap = oracle_manager_cap(scenario);
        update_clock(&mut clock, ts_ms);
        oracle::update(
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

    fun install_ecosystem_manager_cap_entry(
        scenario: &mut Scenario
    ) {
        let mut version = version(scenario);
        let ecosystem_version = ecosystem_version(scenario);
        admin::install_ecosystem_manager_cap_entry(&mut version, &ecosystem_version, ctx(scenario));
        return_shared(version);
        return_shared(ecosystem_version);
        next_tx(scenario, ADMIN);
    }

    const OPTION_TYPE: u64 = 0; // call
    const PERIOD: u8 = 0; // 1 day
    const D_TOKEN_DECIMAL: u64 = 9;
    const B_TOKEN_DECIMAL: u64 = 9;
    const O_TOKEN_DECIMAL: u64 = 9;
    const ACTIVATION_TS_MS: u64 = CURRENT_TS_MS;
    const EXPIRATION_TS_MS: u64 = CURRENT_TS_MS + 86_400_000; // in 1 day
    const DEPOSIT_LOT_SIZE: u64 = 1_0000_00000; // 1 tokens
    const BID_LOT_SIZE: u64 = 10_0000_00000; // 10 tokens
    const MIN_DEPOSIT_SIZE: u64 = 1_0000_00000; // 1 tokens
    const MIN_BID_SIZE: u64 = 10_0000_00000; // 10 tokens
    const MAX_DEPOSIT_ENTRY: u64 = 1000;
    const MAX_BID_ENTRY: u64 = 1000;
    const DEPOSIT_FEE_BP: u64 = 0; // 0.0%
    const BID_FEE_BP: u64 = 1000; // 10%
    const DEPOSIT_INCENTIVE_BP: u64 = 0; // 0%
    const BID_INCENTIVE_BP: u64 = 0; // 0%
    const AUCTION_DELAY_TS_MS: u64 = 0; // 0 hour
    const AUCTION_DURATION_TS_MS: u64 = 3_600_000; // 1 hour
    const RECOUP_DELAY_TS_MS: u64 = 3_600_000; // 1 hour
    const CAPACITY: u64 = 1_000_000_000000000; // 1 million SUI
    const LEVERAGE: u64 = 100; // 1x
    const RISK_LEVEL: u64 = 1;
    const HAS_NEXT: bool = true;
    const STRIKE_BP: vector<u64> = vector[10000]; // at the money
    const WEIGHT: vector<u64> = vector[1];
    const IS_BUYER: vector<bool> = vector[false];
    const STRIKE_INCREMENT: u64 = 0_0001_0000;
    const DECAY_SPEED: u64 = 1;
    const INITIAL_PRICE: u64 = 0_1000_00000; // 20 tokens
    const FINAL_PRICE: u64 = 0_0100_00000; // 10 tokens
    const WHITELIST: vector<address> = vector[ADMIN];

    fun new_portfolio_vault<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        oracle_id: ID,
    ) {
        let mut dov_registry = dov_registry(scenario);
        let oracle = oracle(scenario, oracle_id);
        let clock = new_clock(scenario);
        tds_registry_authorized_entry::new_portfolio_vault<D_TOKEN, B_TOKEN>(
            &mut dov_registry,
            OPTION_TYPE,
            PERIOD,
            D_TOKEN_DECIMAL,
            B_TOKEN_DECIMAL,
            O_TOKEN_DECIMAL,
            ACTIVATION_TS_MS,
            EXPIRATION_TS_MS,
            &oracle,
            DEPOSIT_LOT_SIZE,
            BID_LOT_SIZE,
            MIN_DEPOSIT_SIZE,
            MIN_BID_SIZE,
            MAX_DEPOSIT_ENTRY,
            MAX_BID_ENTRY,
            DEPOSIT_FEE_BP,
            BID_FEE_BP,
            DEPOSIT_INCENTIVE_BP,
            BID_INCENTIVE_BP,
            AUCTION_DELAY_TS_MS,
            AUCTION_DURATION_TS_MS,
            RECOUP_DELAY_TS_MS,
            CAPACITY,
            LEVERAGE,
            RISK_LEVEL,
            HAS_NEXT,
            STRIKE_BP,
            WEIGHT,
            IS_BUYER,
            STRIKE_INCREMENT,
            DECAY_SPEED,
            INITIAL_PRICE,
            FINAL_PRICE,
            WHITELIST,
            &clock,
            ctx(scenario)
        );

        return_shared(dov_registry);
        return_shared(oracle);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    fun registry(scenario: &Scenario): MarketRegistry {
        take_shared<MarketRegistry>(scenario)
    }

    fun lp_pool_registry(scenario: &Scenario): LpPoolRegistry {
        take_shared<LpPoolRegistry>(scenario)
    }

    fun version(scenario: &Scenario): Version {
        take_shared<Version>(scenario)
    }

    fun ecosystem_version(scenario: &Scenario): TypusEcosystemVersion {
        take_shared<TypusEcosystemVersion>(scenario)
    }

    fun leaderboard_registry(scenario: &Scenario): TypusLeaderboardRegistry {
        take_shared<TypusLeaderboardRegistry>(scenario)
    }

    fun tgld_registry(scenario: &Scenario): TgldRegistry {
        take_shared<TgldRegistry>(scenario)
    }

    fun typus_user_registry(scenario: &Scenario): TypusUserRegistry {
        take_shared<TypusUserRegistry>(scenario)
    }

    fun competition_config(scenario: &Scenario): CompetitionConfig {
        take_shared<CompetitionConfig>(scenario)
    }

    fun treasury_caps(scenario: &Scenario): TreasuryCaps {
        take_shared<TreasuryCaps>(scenario)
    }

    fun profit_vault(scenario: &Scenario): ProfitVault {
        take_shared<ProfitVault>(scenario)
    }

    fun tails_staking_registry(scenario: &Scenario): TailsStakingRegistry {
        take_shared<TailsStakingRegistry>(scenario)
    }

    fun typus_nft_manager_cap(scenario: &Scenario): TailsManagerCap {
        take_from_address<TailsManagerCap>(scenario, ADMIN)
    }

    fun dov_registry(scenario: &Scenario): DovRegistry {
        take_shared<DovRegistry>(scenario)
    }

    fun oracle(scenario: &Scenario, id: ID): Oracle {
        take_shared_by_id<Oracle>(scenario, id)
    }

    fun oracle_manager_cap(scenario: &Scenario): OracleManagerCap {
        take_from_sender<OracleManagerCap>(scenario)
    }

    fun mint_test_coin<T>(scenario: &mut Scenario, amount: u64): Coin<T> {
        coin::mint_for_testing<T>(amount, ctx(scenario))
    }

    fun update_clock(clock: &mut Clock, ts_ms: u64) {
        clock::set_for_testing(clock, ts_ms);
    }

    fun test_new_markets_(scenario: &mut Scenario) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        trading::new_markets<TLP, USD>(
            &version,
            &mut registry,
            TRADING_FEE_PROTOCOL_SHARE_BP,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_add_trading_symbol_<BASE_TOKEN>(scenario: &mut Scenario, oracle_id: ID, ts_ms: u64) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let oracle = oracle(scenario, oracle_id);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        trading::add_trading_symbol<BASE_TOKEN>(
            &version,
            &mut registry,
            MARKET_INDEX,
            // market info
            SIZE_DECIMAL,
            // market config
            &oracle,
            MAX_LEVERAGE_MBP,
            OPTION_COLLATERAL_MAX_LEVERAGE_MBP,
            MIN_SIZE,
            LOT_SIZE,
            TRADING_FEE_CONFIG,
            BASIC_FUNDING_RATE,
            FUNDING_INTERVAL_TS_MS,
            EXP_MULTIPLIER,
            COOL_DOWN_THRESHOLD_TS_MS,
            MAX_BUY_OPEN_INTEREST,
            MAX_SELL_OPEN_INTEREST,
            MAINTENANCE_MARGIN_RATE_BP,
            OPTION_MAINTENANCE_MARGIN_RATE_BP,
            OPTION_TRADING_FEE_CONFIG,
            TRADING_FEE_FORMULA_VERSION,
            PROFIT_VAULT_FLAG,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        return_shared(oracle);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_update_protocol_fee_share_bp_(scenario: &mut Scenario, new_fee_share_bp: u64) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        trading::update_protocol_fee_share_bp(
            &version,
            &mut registry,
            MARKET_INDEX,
            new_fee_share_bp,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_update_market_config_<BASE_TOKEN>(scenario: &mut Scenario, oracle_id: ID) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let oracle = oracle(scenario, oracle_id);
        trading::update_market_config<BASE_TOKEN>(
            &version,
            &mut registry,
            MARKET_INDEX,
            // market config
            option::some(object::id_address(&oracle)),
            option::some(MAX_LEVERAGE_MBP + 1),
            option::some(OPTION_COLLATERAL_MAX_LEVERAGE_MBP + 1),
            option::some(MIN_SIZE + 1_0000_00000),
            option::some(LOT_SIZE / 10),
            option::some(vector[0_0008_000, 0_0020_000, 0_2000_000, 2, 1]),
            option::some(BASIC_FUNDING_RATE),
            option::some(FUNDING_INTERVAL_TS_MS),
            option::some(EXP_MULTIPLIER),
            option::some(COOL_DOWN_THRESHOLD_TS_MS),
            option::some(MAX_BUY_OPEN_INTEREST),
            option::some(MAX_SELL_OPEN_INTEREST),
            option::some(MAINTENANCE_MARGIN_RATE_BP),
            option::some(OPTION_MAINTENANCE_MARGIN_RATE_BP),
            option::some(OPTION_TRADING_FEE_CONFIG),
            option::some(TRADING_FEE_FORMULA_VERSION),
            option::some(PROFIT_VAULT_FLAG),
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        return_shared(oracle);
        next_tx(scenario, ADMIN);
    }

    fun test_create_trading_order_<C_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        reduce_only: bool,
        is_long: bool,
        is_stop_order: bool,
        size: u64,
        trigger_price: u64,
        collateral_amount: u64,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        c_token_price: u64,
        t_token_price: u64,
        linked_position_id: Option<u64>,
        ts_ms: u64
    ) {
        let mut version = version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut clock = new_clock(scenario);
        clock.set_for_testing(ts_ms);
        let collateral = mint_test_coin<C_TOKEN>(scenario, collateral_amount);

        if (c_oracle_id == trading_oracle_id) {
            let mut oracle_c_token = oracle(scenario, c_oracle_id);
            let sender_address = sender(scenario);
            next_tx(scenario, ADMIN);
            update_oracle(scenario, &mut oracle_c_token, c_token_price, ts_ms);
            next_tx(scenario, sender_address);
            trading::create_trading_order<C_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &oracle_c_token,
                &oracle_c_token,
                &clock,
                MARKET_INDEX,
                0, // pool_index
                // order parameters
                linked_position_id,
                collateral,
                reduce_only,
                is_long,
                is_stop_order,
                size,
                trigger_price,
                ctx(scenario)
            );
            return_shared(oracle_c_token);
        } else {
            let mut oracle_c_token = oracle(scenario, c_oracle_id);
            let mut oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            let sender_address = sender(scenario);
            next_tx(scenario, ADMIN);
            update_oracle(scenario, &mut oracle_c_token, c_token_price, ts_ms);
            update_oracle(scenario, &mut oracle_trading_symbol, t_token_price, ts_ms);
            next_tx(scenario, sender_address);
            trading::create_trading_order<C_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &oracle_c_token,
                &oracle_trading_symbol,
                &clock,
                MARKET_INDEX,
                0, // pool_index
                // order parameters
                linked_position_id,
                collateral,
                reduce_only,
                is_long,
                is_stop_order,
                size,
                trigger_price,
                ctx(scenario)
            );
            return_shared(oracle_c_token);
            return_shared(oracle_trading_symbol);
        };

        return_shared(registry);
        return_shared(pool_registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_cancel_trading_order_<C_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        order_id: u64,
        trigger_price: u64, // pass this for reducing network fee cost
        order_user: Option<address>, // if some => ctx should be a manager; none => cancel sender(ctx)'s order
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let coin = trading::cancel_trading_order<C_TOKEN, BASE_TOKEN>(
            &version,
            &mut registry,
            MARKET_INDEX,
            order_id,
            trigger_price,
            order_user,
            ctx(scenario)
        );

        return_shared(registry);
        return_shared(version);
        transfer::public_transfer(coin, sender(scenario));
        next_tx(scenario, ADMIN);
    }

    fun test_release_collateral_<C_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        c_token_price: u64,
        t_token_price: u64,
        position_id: u64,
        release_amount: u64,
        ts_ms: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut clock = new_clock(scenario);
        clock.set_for_testing(ts_ms);
        let coin = if (c_oracle_id == trading_oracle_id) {
            let mut oracle_c_token = oracle(scenario, c_oracle_id);
            let sender_address = sender(scenario);
            next_tx(scenario, ADMIN);
            update_oracle(scenario, &mut oracle_c_token, c_token_price, ts_ms);
            next_tx(scenario, sender_address);
            let coin = trading::release_collateral<C_TOKEN, BASE_TOKEN>(
                &version,
                &mut registry,
                &mut pool_registry,
                &oracle_c_token,
                &oracle_c_token,
                &clock,
                MARKET_INDEX,
                0,
                position_id,
                release_amount,
                ctx(scenario),
            );
            return_shared(oracle_c_token);
            coin
        } else {
            let mut oracle_c_token = oracle(scenario, c_oracle_id);
            let mut oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            let sender_address = sender(scenario);
            next_tx(scenario, ADMIN);
            update_oracle(scenario, &mut oracle_c_token, c_token_price, ts_ms);
            update_oracle(scenario, &mut oracle_trading_symbol, t_token_price, ts_ms);
            next_tx(scenario, sender_address);
            let coin = trading::release_collateral<C_TOKEN, BASE_TOKEN>(
                &version,
                &mut registry,
                &mut pool_registry,
                &oracle_c_token,
                &oracle_trading_symbol,
                &clock,
                MARKET_INDEX,
                0,
                position_id,
                release_amount,
                ctx(scenario),
            );
            return_shared(oracle_c_token);
            return_shared(oracle_trading_symbol);
            coin
        };
        transfer::public_transfer(coin, sender(scenario));
        return_shared(registry);
        return_shared(version);
        return_shared(pool_registry);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_increase_collateral_<C_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        position_id: u64,
        deposit_amount: u64,
        ts_ms: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut clock = new_clock(scenario);
        clock.set_for_testing(ts_ms);
        let coin = mint_test_coin<C_TOKEN>(scenario, deposit_amount);
        if (c_oracle_id == trading_oracle_id) {
            let oracle_c_token = oracle(scenario, c_oracle_id);
            trading::increase_collateral<C_TOKEN, BASE_TOKEN>(
                &version,
                &mut registry,
                &mut pool_registry,
                &oracle_c_token,
                &oracle_c_token,
                &clock,
                MARKET_INDEX,
                0,
                position_id,
                coin,
                ctx(scenario),
            );
            return_shared(oracle_c_token);
        } else {
            let oracle_c_token = oracle(scenario, c_oracle_id);
            let oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            trading::increase_collateral<C_TOKEN, BASE_TOKEN>(
                &version,
                &mut registry,
                &mut pool_registry,
                &oracle_c_token,
                &oracle_trading_symbol,
                &clock,
                MARKET_INDEX,
                0,
                position_id,
                coin,
                ctx(scenario),
            );
            return_shared(oracle_c_token);
            return_shared(oracle_trading_symbol);
        };
        return_shared(registry);
        return_shared(version);
        return_shared(pool_registry);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_collect_position_funding_fee_<C_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        position_id: u64,
        ts_ms: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        if (c_oracle_id == trading_oracle_id) {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            update_oracle(scenario, &mut typus_oracle_c_token, SUI_PRICE, ts_ms);
            trading::collect_position_funding_fee<C_TOKEN, BASE_TOKEN>(
                &version,
                &mut registry,
                &mut pool_registry,
                &typus_oracle_c_token,
                &typus_oracle_c_token,
                &clock,
                MARKET_INDEX,
                0,
                position_id,
                ctx(scenario),
            );
            return_shared(typus_oracle_c_token);
        } else {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let mut typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            update_oracle(scenario, &mut typus_oracle_c_token, SUI_PRICE, ts_ms);
            update_oracle(scenario, &mut typus_oracle_trading_symbol, SUI_PRICE, ts_ms);
            trading::collect_position_funding_fee<C_TOKEN, BASE_TOKEN>(
                &version,
                &mut registry,
                &mut pool_registry,
                &typus_oracle_c_token,
                &typus_oracle_trading_symbol,
                &clock,
                MARKET_INDEX,
                0,
                position_id,
                ctx(scenario),
            );
            return_shared(typus_oracle_c_token);
            return_shared(typus_oracle_trading_symbol);
        };
        return_shared(registry);
        return_shared(pool_registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_manager_reduce_position_<C_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        position_id: u64,
        reduced_ratio_bp: u64,
        ts_ms: u64,
    ) {
        let mut version = version(scenario);
        let ecosystem_version = ecosystem_version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut clock = new_clock(scenario);
        clock.set_for_testing(ts_ms);
        let mut typus_user_registry = typus_user_registry(scenario);
        let mut leaderboard_registry = leaderboard_registry(scenario);
        let tails_staking_registry = tails_staking_registry(scenario);
        let competition_config = competition_config(scenario);
        let mut profit_vault = profit_vault(scenario);

        if (c_oracle_id == trading_oracle_id) {
            let typus_oracle_c_token = oracle(scenario, c_oracle_id);
            trading::manager_reduce_position<C_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut profit_vault,
                &typus_oracle_c_token,
                &typus_oracle_c_token,
                &clock,
                MARKET_INDEX,
                0,
                &ecosystem_version,
                &mut typus_user_registry,
                &mut leaderboard_registry,
                &tails_staking_registry,
                &competition_config,
                position_id,
                reduced_ratio_bp,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
        } else {
            let typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            trading::manager_reduce_position<C_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut profit_vault,
                &typus_oracle_c_token,
                &typus_oracle_trading_symbol,
                &clock,
                MARKET_INDEX,
                0,
                &ecosystem_version,
                &mut typus_user_registry,
                &mut leaderboard_registry,
                &tails_staking_registry,
                &competition_config,
                position_id,
                reduced_ratio_bp,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
            return_shared(typus_oracle_trading_symbol);
        };
        return_shared(registry);
        return_shared(pool_registry);
        return_shared(profit_vault);
        return_shared(version);
        return_shared(ecosystem_version);
        clock::destroy_for_testing(clock);
        return_shared(typus_user_registry);
        return_shared(leaderboard_registry);
        return_shared(competition_config);
        return_shared(tails_staking_registry);
        next_tx(scenario, ADMIN);
    }

    fun test_match_trading_order_<C_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        c_token_price: u64,
        t_token_price: u64,
        order_type_tag: u8,
        trigger_price: u64,
        max_operation_count: u64,
        ts_ms: u64,
    ) {
        let mut version = version(scenario);
        let ecosystem_version = ecosystem_version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        let mut typus_user_registry = typus_user_registry(scenario);
        let mut leaderboard_registry = leaderboard_registry(scenario);
        let tails_staking_registry = tails_staking_registry(scenario);
        let competition_config = competition_config(scenario);
        let mut profit_vault = profit_vault(scenario);

        if (c_oracle_id == trading_oracle_id) {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            update_oracle(scenario, &mut typus_oracle_c_token, c_token_price, ts_ms);
            trading::match_trading_order<C_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut profit_vault,
                &typus_oracle_c_token,
                &typus_oracle_c_token,
                &clock,
                MARKET_INDEX,
                0,
                &ecosystem_version,
                &mut typus_user_registry,
                &mut leaderboard_registry,
                &tails_staking_registry,
                &competition_config,
                order_type_tag,
                trigger_price,
                max_operation_count,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
        } else {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let mut typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            update_oracle(scenario, &mut typus_oracle_c_token, c_token_price, ts_ms);
            update_oracle(scenario, &mut typus_oracle_trading_symbol, t_token_price, ts_ms);
            trading::match_trading_order<C_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut profit_vault,
                &typus_oracle_c_token,
                &typus_oracle_trading_symbol,
                &clock,
                MARKET_INDEX,
                0,
                &ecosystem_version,
                &mut typus_user_registry,
                &mut leaderboard_registry,
                &tails_staking_registry,
                &competition_config,
                order_type_tag,
                trigger_price,
                max_operation_count,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
            return_shared(typus_oracle_trading_symbol);
        };

        return_shared(registry);
        return_shared(pool_registry);
        return_shared(profit_vault);
        return_shared(version);
        return_shared(ecosystem_version);
        clock::destroy_for_testing(clock);
        return_shared(typus_user_registry);
        return_shared(leaderboard_registry);
        return_shared(competition_config);
        return_shared(tails_staking_registry);
        next_tx(scenario, ADMIN);
    }

    fun test_liquidate_<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        position_id: u64,
        liquidate_price_c: u64,
        liquidate_price_t: u64,
        ts_ms: u64,
    ) {
        let mut version = version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut dov_registry = dov_registry(scenario);
        let mut clock = new_clock(scenario);

        if (c_oracle_id == trading_oracle_id) {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            update_clock(&mut clock, ts_ms);
            update_oracle(scenario, &mut typus_oracle_c_token, liquidate_price_t, ts_ms); // force to liquidate
            trading::liquidate<C_TOKEN, B_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut dov_registry,
                &typus_oracle_c_token,
                &typus_oracle_c_token,
                MARKET_INDEX,
                0,
                &clock,
                position_id,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
        } else {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let mut typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            update_clock(&mut clock, ts_ms);
            update_oracle(scenario, &mut typus_oracle_c_token, liquidate_price_c, ts_ms); // force to liquidate
            update_oracle(scenario, &mut typus_oracle_trading_symbol, liquidate_price_t, ts_ms); // force to liquidate
            trading::liquidate<C_TOKEN, B_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut dov_registry,
                &typus_oracle_c_token,
                &typus_oracle_trading_symbol,
                MARKET_INDEX,
                0,
                &clock,
                position_id,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
            return_shared(typus_oracle_trading_symbol);
        };

        return_shared(registry);
        return_shared(pool_registry);
        return_shared(dov_registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_create_trading_order_with_bid_receipt_v3_<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        trading_oracle_price: u64,
        is_long: bool,
        ts_ms: u64,
    ) {
        let mut version = version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut dov_registry = dov_registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        let ecosystem_version = ecosystem_version(scenario);
        let mut typus_user_registry = typus_user_registry(scenario);
        let mut leaderboard_registry = leaderboard_registry(scenario);
        let tails_staking_registry = tails_staking_registry(scenario);
        let competition_config = competition_config(scenario);
        let bid_receipt = take_from_address<TypusBidReceipt>(scenario, USER_1);
        if (c_oracle_id == trading_oracle_id) {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            next_tx(scenario, ADMIN);
            update_oracle(scenario, &mut typus_oracle_c_token, trading_oracle_price, ts_ms);
            next_tx(scenario, USER_1);
            trading::create_trading_order_with_bid_receipt<C_TOKEN, B_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut dov_registry,
                &typus_oracle_c_token,
                &typus_oracle_c_token,
                &clock,
                MARKET_INDEX,
                0, // pool_index
                &ecosystem_version,
                &mut typus_user_registry,
                &mut leaderboard_registry,
                &tails_staking_registry,
                &competition_config,
                bid_receipt,
                is_long,
                ctx(scenario),
            );
            return_shared(typus_oracle_c_token);
        } else {
            let typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let mut typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            next_tx(scenario, ADMIN);
            update_oracle(scenario, &mut typus_oracle_trading_symbol, trading_oracle_price, ts_ms);
            next_tx(scenario, USER_1);
            trading::create_trading_order_with_bid_receipt<C_TOKEN, B_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut dov_registry,
                &typus_oracle_c_token,
                &typus_oracle_trading_symbol,
                &clock,
                MARKET_INDEX,
                0, // pool_index
                &ecosystem_version,
                &mut typus_user_registry,
                &mut leaderboard_registry,
                &tails_staking_registry,
                &competition_config,
                bid_receipt,
                is_long,
                ctx(scenario),
            );
            return_shared(typus_oracle_c_token);
            return_shared(typus_oracle_trading_symbol);
        };
        return_shared(registry);
        return_shared(pool_registry);
        return_shared(dov_registry);
        return_shared(version);
        return_shared(ecosystem_version);
        clock::destroy_for_testing(clock);
        return_shared(typus_user_registry);
        return_shared(leaderboard_registry);
        return_shared(competition_config);
        return_shared(tails_staking_registry);
        next_tx(scenario, ADMIN);
    }

    fun test_reduce_option_collateral_position_size_<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        trading_oracle_price: u64,
        position_id: u64,
        order_size: Option<u64>, // in contract size decimal. if none => close position
        ts_ms: u64,
    ) {
        let mut version = version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut dov_registry = dov_registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        let ecosystem_version = ecosystem_version(scenario);
        let mut typus_user_registry = typus_user_registry(scenario);
        let mut leaderboard_registry = leaderboard_registry(scenario);
        let tails_staking_registry = tails_staking_registry(scenario);
        let competition_config = competition_config(scenario);
        if (c_oracle_id == trading_oracle_id) {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            next_tx(scenario, ADMIN);
            update_oracle(scenario, &mut typus_oracle_c_token, trading_oracle_price, ts_ms);
            next_tx(scenario, USER_1);
            trading::reduce_option_collateral_position_size<C_TOKEN, B_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut dov_registry,
                &typus_oracle_c_token,
                &typus_oracle_c_token,
                &clock,
                MARKET_INDEX,
                0,
                &ecosystem_version,
                &mut typus_user_registry,
                &mut leaderboard_registry,
                &tails_staking_registry,
                &competition_config,
                position_id,
                order_size,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
        } else {
            let typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let mut typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            next_tx(scenario, ADMIN);
            update_oracle(scenario, &mut typus_oracle_trading_symbol, trading_oracle_price, ts_ms);
            next_tx(scenario, USER_1);
            trading::reduce_option_collateral_position_size<C_TOKEN, B_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut dov_registry,
                &typus_oracle_c_token,
                &typus_oracle_trading_symbol,
                &clock,
                MARKET_INDEX,
                0,
                &ecosystem_version,
                &mut typus_user_registry,
                &mut leaderboard_registry,
                &tails_staking_registry,
                &competition_config,
                position_id,
                order_size,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
            return_shared(typus_oracle_trading_symbol);
        };
        return_shared(registry);
        return_shared(pool_registry);
        return_shared(dov_registry);
        return_shared(version);
        return_shared(ecosystem_version);
        clock::destroy_for_testing(clock);
        return_shared(typus_user_registry);
        return_shared(leaderboard_registry);
        return_shared(competition_config);
        return_shared(tails_staking_registry);
        next_tx(scenario, ADMIN);
    }

    fun test_update_funding_rate_<BASE_TOKEN>(
        scenario: &mut Scenario,
        trading_oracle_id: ID,
        t_token_price: u64,
        ts_ms: u64,
    ) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let pool_registry = lp_pool_registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);

        let mut typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
        let sender_address = sender(scenario);
        next_tx(scenario, ADMIN);
        update_oracle(scenario, &mut typus_oracle_trading_symbol, t_token_price, ts_ms);
        next_tx(scenario, sender_address);
        trading::update_funding_rate<BASE_TOKEN>(
            &version,
            &mut registry,
            &pool_registry,
            &typus_oracle_trading_symbol,
            &clock,
            MARKET_INDEX,
            0,
            ctx(scenario)
        );

        return_shared(registry);
        return_shared(pool_registry);
        return_shared(version);
        return_shared(typus_oracle_trading_symbol);
        clock::destroy_for_testing(clock);

        next_tx(scenario, ADMIN);
    }

    fun test_manager_close_option_position<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        c_oracle_price: u64,
        trading_oracle_price: u64,
        position_id: u64,
        ts_ms: u64,
    ) {
        let mut version = version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut dov_registry = dov_registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        let ecosystem_version = ecosystem_version(scenario);
        let mut typus_user_registry = typus_user_registry(scenario);
        let mut leaderboard_registry = leaderboard_registry(scenario);
        let tails_staking_registry = tails_staking_registry(scenario);
        let competition_config = competition_config(scenario);
        if (c_oracle_id == trading_oracle_id) {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            update_oracle(scenario, &mut typus_oracle_c_token, c_oracle_price, ts_ms);
            trading::manager_close_option_position<C_TOKEN, B_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut dov_registry,
                &typus_oracle_c_token,
                &typus_oracle_c_token,
                &clock,
                MARKET_INDEX,
                0,
                &ecosystem_version,
                &mut typus_user_registry,
                &mut leaderboard_registry,
                &tails_staking_registry,
                &competition_config,
                position_id,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
        } else {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let mut typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            update_oracle(scenario, &mut typus_oracle_c_token, c_oracle_price, ts_ms);
            update_oracle(scenario, &mut typus_oracle_trading_symbol, trading_oracle_price, ts_ms);
            trading::manager_close_option_position<C_TOKEN, B_TOKEN, BASE_TOKEN>(
                &mut version,
                &mut registry,
                &mut pool_registry,
                &mut dov_registry,
                &typus_oracle_c_token,
                &typus_oracle_trading_symbol,
                &clock,
                MARKET_INDEX,
                0,
                &ecosystem_version,
                &mut typus_user_registry,
                &mut leaderboard_registry,
                &tails_staking_registry,
                &competition_config,
                position_id,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
            return_shared(typus_oracle_trading_symbol);
        };
        return_shared(registry);
        return_shared(pool_registry);
        return_shared(dov_registry);
        return_shared(version);
        return_shared(ecosystem_version);
        clock::destroy_for_testing(clock);
        return_shared(typus_user_registry);
        return_shared(leaderboard_registry);
        return_shared(competition_config);
        return_shared(tails_staking_registry);
        next_tx(scenario, ADMIN);
    }

    fun test_settle_receipt_collateral_<C_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        c_oracle_price: u64,
        ts_ms: u64
    ) {
        let mut version = version(scenario);
        let mut registry = registry(scenario);
        let mut pool_registry = lp_pool_registry(scenario);
        let mut dov_registry = dov_registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
        update_oracle(scenario, &mut typus_oracle_c_token, c_oracle_price, ts_ms);
        trading::settle_receipt_collateral<C_TOKEN, B_TOKEN>(
            &mut version,
            &mut registry,
            &mut pool_registry,
            &mut dov_registry,
            &typus_oracle_c_token,
            &clock,
            MARKET_INDEX,
            0,
            ctx(scenario)
        );
        return_shared(typus_oracle_c_token);
        return_shared(registry);
        return_shared(pool_registry);
        return_shared(dov_registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_get_estimated_liquidation_price_and_pnl_<C_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        c_token_price: u64,
        t_token_price: u64,
        position_id: u64,
        ts_ms: u64,
    ): (u64, bool, u64, bool, u64, bool, u64, u64, u64) {
        let version = version(scenario);
        let mut registry = registry(scenario);
        let pool_registry = lp_pool_registry(scenario);
        let dov_registry = dov_registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);

        let (
            estimated_liquidation_price,
            has_profit,
            pnl_usd,
            is_cost,
            unrealized_cost_in_usd,
            unrealized_funding_sign,
            unrealized_funding_fee_usd,
            unrealized_borrow_fee_usd,
            close_fee_usd
        ) = if (c_oracle_id == trading_oracle_id) {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let sender_address = sender(scenario);
            next_tx(scenario, ADMIN);
            update_oracle(scenario, &mut typus_oracle_c_token, c_token_price, ts_ms);
            next_tx(scenario, sender_address);
            let (
                estimated_liquidation_price,
                has_profit,
                pnl_usd,
                is_cost,
                unrealized_cost_in_usd,
                unrealized_funding_sign,
                unrealized_funding_fee_usd,
                unrealized_borrow_fee_usd,
                close_fee_usd
            ) = trading::get_estimated_liquidation_price_and_pnl<C_TOKEN, BASE_TOKEN>(
                &version,
                &mut registry,
                &pool_registry,
                &dov_registry,
                &typus_oracle_c_token,
                &typus_oracle_c_token,
                MARKET_INDEX,
                0,
                &clock,
                position_id
            );
            return_shared(typus_oracle_c_token);
            (estimated_liquidation_price, has_profit, pnl_usd, is_cost, unrealized_cost_in_usd, unrealized_funding_sign, unrealized_funding_fee_usd, unrealized_borrow_fee_usd, close_fee_usd)
        } else {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let mut typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            let sender_address = sender(scenario);
            next_tx(scenario, ADMIN);
            update_oracle(scenario, &mut typus_oracle_c_token, c_token_price, ts_ms);
            update_oracle(scenario, &mut typus_oracle_trading_symbol, t_token_price, ts_ms);
            next_tx(scenario, sender_address);
            let (
                estimated_liquidation_price,
                has_profit,
                pnl_usd,
                is_cost,
                unrealized_cost_in_usd,
                unrealized_funding_sign,
                unrealized_funding_fee_usd,
                unrealized_borrow_fee_usd,
                close_fee_usd
            ) = trading::get_estimated_liquidation_price_and_pnl<C_TOKEN, BASE_TOKEN>(
                &version,
                &mut registry,
                &pool_registry,
                &dov_registry,
                &typus_oracle_c_token,
                &typus_oracle_trading_symbol,
                MARKET_INDEX,
                0,
                &clock,
                position_id
            );
            return_shared(typus_oracle_c_token);
            return_shared(typus_oracle_trading_symbol);
            (estimated_liquidation_price, has_profit, pnl_usd, is_cost, unrealized_cost_in_usd, unrealized_funding_sign, unrealized_funding_fee_usd, unrealized_borrow_fee_usd, close_fee_usd)
        };

        return_shared(registry);
        return_shared(pool_registry);
        return_shared(dov_registry);
        return_shared(version);
        clock::destroy_for_testing(clock);

        next_tx(scenario, ADMIN);

        (estimated_liquidation_price, has_profit, pnl_usd, is_cost, unrealized_cost_in_usd, unrealized_funding_sign, unrealized_funding_fee_usd, unrealized_borrow_fee_usd, close_fee_usd)
    }

    fun test_dov_recoup_and_settle_and_activate_<C_TOKEN, BASE_TOKEN>(
        scenario: &mut Scenario,
        c_oracle_id: ID,
        trading_oracle_id: ID,
        c_token_price: u64,
        t_token_price: u64,
        ts_ms: u64,
    ) {
        let mut dov_registry = dov_registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        tds_authorized_entry::recoup<C_TOKEN, BASE_TOKEN>(
            &mut dov_registry,
            0,
            &clock,
                ctx(scenario)
        );

        if (c_oracle_id == trading_oracle_id) {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            update_oracle(scenario, &mut typus_oracle_c_token, c_token_price, ts_ms);
            // D_TOKEN = C_TOKEN, O_TOKEN = BASE_TOKEN
            tds_authorized_entry::settle<C_TOKEN, BASE_TOKEN>(
                &mut dov_registry,
                0,
                &typus_oracle_c_token,
                &typus_oracle_c_token,
                &clock,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
        } else {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let mut typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            update_oracle(scenario, &mut typus_oracle_c_token, c_token_price, ts_ms);
            update_oracle(scenario, &mut typus_oracle_trading_symbol, t_token_price, ts_ms);
            // D_TOKEN = C_TOKEN, O_TOKEN = BASE_TOKEN
            tds_authorized_entry::settle<C_TOKEN, BASE_TOKEN>(
                &mut dov_registry,
                0,
                &typus_oracle_trading_symbol,
                &typus_oracle_c_token,
                &clock,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
            return_shared(typus_oracle_trading_symbol);
        };

        // activate vault (create bid vault)
        next_tx(scenario, ADMIN);
        if (c_oracle_id == trading_oracle_id) {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            update_oracle(scenario, &mut typus_oracle_c_token, c_token_price, ts_ms);
            tds_authorized_entry::activate<C_TOKEN, C_TOKEN, BASE_TOKEN>(
                &mut dov_registry,
                0,
                &typus_oracle_c_token,
                &typus_oracle_c_token,
                &clock,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
        } else {
            let mut typus_oracle_c_token = oracle(scenario, c_oracle_id);
            let mut typus_oracle_trading_symbol = oracle(scenario, trading_oracle_id);
            update_oracle(scenario, &mut typus_oracle_c_token, c_token_price, ts_ms);
            update_oracle(scenario, &mut typus_oracle_trading_symbol, t_token_price, ts_ms);
            tds_authorized_entry::activate<C_TOKEN, C_TOKEN, BASE_TOKEN>(
                &mut dov_registry,
                0,
                &typus_oracle_trading_symbol,
                &typus_oracle_c_token,
                &clock,
                ctx(scenario)
            );
            return_shared(typus_oracle_c_token);
            return_shared(typus_oracle_trading_symbol);
        };
        next_tx(scenario, ADMIN);

        return_shared(dov_registry);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    public(package) fun begin_test(): Scenario {
        let mut scenario = begin(ADMIN);
        new_registry(&mut scenario);
        new_lp_pool_registry(&mut scenario);
        new_version(&mut scenario);
        new_leaderboard_registry(&mut scenario);
        new_typus_user_registry(&mut scenario);
        new_competition_config(&mut scenario);
        init_oracle(&mut scenario);
        new_treasury_caps(&mut scenario);
        new_tlp(&mut scenario);
        new_profit_vault(&mut scenario);
        new_nft_pool(&mut scenario);
        new_tails_staking_registry(&mut scenario);
        install_ecosystem_manager_cap_entry(&mut scenario);
        new_dov_registry(&mut scenario);
        next_tx(&mut scenario, ADMIN);
        new_tgld_registry(&mut scenario);
        next_tx(&mut scenario, ADMIN);
        scenario
    }

    fun prepare_lp_pool_env(scenario: &mut Scenario, lp_token_amount: u64): (ID, ID) {
        // use SUI as collateral token
        let pool_index = 0;
        test_lp_pool::test_new_liquidity_pool_<TLP>(scenario);
        let sui_oracle_id = new_oracle<SUI>(scenario);
        test_lp_pool::test_add_liquidity_token_<SUI>(scenario, sui_oracle_id, pool_index);
        let babe_oracle_id = new_oracle<BABE>(scenario);
        test_lp_pool::test_add_liquidity_token_<BABE>(scenario, babe_oracle_id, pool_index);
        test_lp_pool::test_mint_lp_<SUI>(scenario, sui_oracle_id, pool_index, lp_token_amount);
        test_lp_pool::test_mint_lp_<BABE>(scenario, babe_oracle_id, pool_index, lp_token_amount);
        (sui_oracle_id, babe_oracle_id)
    }

    fun prepare_option_collateral_dov_env<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        oracle_id: ID,
        d_token_price_oracle: ID,
    ) {
        // new vault
        new_portfolio_vault<D_TOKEN, B_TOKEN>(scenario, oracle_id);

        // create deposit snapshot
        let mut dov_registry = dov_registry(scenario);
        typus_dov_single::create_deposit_snapshots_additional_config(&mut dov_registry, ctx(scenario));
        next_tx(scenario, ADMIN);

        // issue ecosystem manager cap into typus_dov_single
        let ecosystem_version = ecosystem_version(scenario);
        typus_dov_single::test_issue_ecosystem_manager_cap(&mut dov_registry, &ecosystem_version, ctx(scenario));
        next_tx(scenario, ADMIN);

        // raise fund
        let mut typus_user_registry = typus_user_registry(scenario);
        let mut leaderboard_registry = leaderboard_registry(scenario);
        let mut clock = new_clock(scenario);
        let coin = mint_test_coin<D_TOKEN>(scenario, 1_000_000000000);
        let (deposit_receipt, _log) = tds_user_entry::public_raise_fund<D_TOKEN, B_TOKEN>(
            &ecosystem_version,
            &mut typus_user_registry,
            &mut leaderboard_registry,
            &mut dov_registry,
            0,
            vector[],
            coin.into_balance(),
            false,
            false,
            &clock,
            ctx(scenario)
        );
        transfer::public_transfer(deposit_receipt, sender(scenario));
        next_tx(scenario, ADMIN);

        // activate vault (create bid vault)
        if (oracle_id == d_token_price_oracle) {
            let d_token_price_oracle = oracle(scenario, d_token_price_oracle);
            tds_authorized_entry::activate<D_TOKEN, B_TOKEN, D_TOKEN>(
                &mut dov_registry,
                0,
                &d_token_price_oracle,
                &d_token_price_oracle,
                &clock,
                ctx(scenario)
            );
            return_shared(d_token_price_oracle);
        } else {
            let oracle = oracle(scenario, oracle_id);
            let d_token_price_oracle = oracle(scenario, d_token_price_oracle);
            tds_authorized_entry::activate<D_TOKEN, B_TOKEN, D_TOKEN>(
                &mut dov_registry,
                0,
                &oracle,
                &d_token_price_oracle,
                &clock,
                ctx(scenario)
            );
            return_shared(oracle);
            return_shared(d_token_price_oracle);
        };
        next_tx(scenario, ADMIN);

        // new auction
        tds_authorized_entry::new_auction<D_TOKEN, B_TOKEN>(
            &mut dov_registry,
            0,
            option::none(),
            option::none(),
            ctx(scenario)
        );
        next_tx(scenario, USER_1);

        // new bid
        update_clock(&mut clock, CURRENT_TS_MS + 1);
        let mut tgld_registry = tgld_registry(scenario);
        let coin = mint_test_coin<B_TOKEN>(scenario, 1000_0000_00000);
        let (bid_receipt, rebate_coin, _log) = tds_user_entry::public_bid<D_TOKEN, B_TOKEN>(
            &ecosystem_version,
            &mut typus_user_registry,
            &mut tgld_registry,
            &mut leaderboard_registry,
            &mut dov_registry,
            0,
            vector[coin],
            100_0000_00000,
            &clock,
            ctx(scenario)
        );
        transfer::public_transfer(bid_receipt, sender(scenario));
        transfer::public_transfer(rebate_coin, sender(scenario));

        // new bid 2
        next_tx(scenario, USER_2);
        update_clock(&mut clock, CURRENT_TS_MS + 500);
        let coin = mint_test_coin<B_TOKEN>(scenario, 1000_0000_00000);
        let (bid_receipt, rebate_coin, _log) = tds_user_entry::public_bid<D_TOKEN, B_TOKEN>(
            &ecosystem_version,
            &mut typus_user_registry,
            &mut tgld_registry,
            &mut leaderboard_registry,
            &mut dov_registry,
            0,
            vector[coin],
            100_0000_00000,
            &clock,
            ctx(scenario)
        );
        transfer::public_transfer(bid_receipt, sender(scenario));
        transfer::public_transfer(rebate_coin, sender(scenario));
        next_tx(scenario, ADMIN);

        // delivery
        update_clock(&mut clock, CURRENT_TS_MS + AUCTION_DURATION_TS_MS);
        tds_authorized_entry::delivery<D_TOKEN, B_TOKEN, D_TOKEN>(
            &mut dov_registry,
            0,
            false,
            &clock,
            ctx(scenario)
        );
        next_tx(scenario, ADMIN);

        return_shared(ecosystem_version);
        return_shared(typus_user_registry);
        return_shared(leaderboard_registry);
        return_shared(dov_registry);
        return_shared(tgld_registry);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    #[test]
    public(package) fun test_new_markets() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        {
            let registry = registry(&scenario);
            let result_1 = trading::get_markets_bcs(&registry, vector[0]);
            assert!(result_1.length() > 0, 0);
            let result_2 = trading::get_markets_bcs(&registry, vector[]);
            assert!(result_1 == result_2, 0);
            let result_3 = trading::get_markets_bcs(&registry, vector[1]);
            assert!(result_3.length() == 0, 0);
            return_shared(registry);
        };
        end(scenario);
    }

    #[test]
    public(package) fun test_add_trading_symbol() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (sui_oracle_id, babe_oracle_id) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);
        test_add_trading_symbol_<BABE>(&mut scenario, babe_oracle_id, CURRENT_TS_MS);
        end(scenario);
    }

    #[test]
    public(package) fun test_update_protocol_fee_share_bp() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (_, _) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        let new_share_bp = 5000;
        test_update_protocol_fee_share_bp_(&mut scenario, new_share_bp);
        end(scenario);
    }

    #[test]
    public(package) fun test_update_market_config() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (sui_oracle_id, _babe_oracle_id) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);
        test_update_market_config_<SUI>(&mut scenario, sui_oracle_id);
        end(scenario);
    }

    #[test]
    public(package) fun test_create_and_cancel_trading_order() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (sui_oracle_id, _babe_oracle_id) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);
        test_update_market_config_<SUI>(&mut scenario, sui_oracle_id);

        let (reduce_only, is_long, is_stop_order) = (false, true, false);
        let (size, trigger_price) = (10_0000_00000, 9_0000_0000); // 10 contract size, SUIUSD = 9
        let collateral_amount = 1_0000_00000; // 1 SUI as collateral
        test_create_trading_order_<SUI, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            collateral_amount,
            sui_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::none(),
            CURRENT_TS_MS
        );
        {
            let version = version(&scenario);
            let registry = registry(&scenario);
            let result = trading::get_active_orders_by_order_tag<SUI>(
                &version,
                &registry,
                MARKET_INDEX,
                0
            );
            assert!(result.length() > 0, 0);
            let orders = trading::get_user_orders(
                &version,
                &registry,
                MARKET_INDEX,
                sender(&scenario)
            );
            assert!(orders.length() > 0, 0);
            return_shared(registry);
            return_shared(version);
        };
        next_tx(&mut scenario, ADMIN);
        let order_id = 0;
        test_cancel_trading_order_<SUI, SUI>(
            &mut scenario,
            order_id,
            trigger_price,
            option::none()
        );

        {
            let version = version(&scenario);
            let registry = registry(&scenario);
            let result = trading::get_all_positions<SUI>(
                &version,
                &registry,
                MARKET_INDEX,
                100,
                1,
            );
            std::debug::print(&result); // should be zero in bytes of vec
            return_shared(registry);
            return_shared(version);
        };
        end(scenario);
    }

    #[test]
    public(package) fun test_normal_operation_for_position() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (sui_oracle_id, babe_oracle_id) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);
        test_update_market_config_<SUI>(&mut scenario, sui_oracle_id);

        let (reduce_only, is_long, is_stop_order) = (false, true, false);
        let (size, trigger_price) = (10_0000_00000, 10_0000_0000); // 10 contract size, SUIUSD = 10 => should be filled immediately
        let collateral_amount = 1_0000_00000; // 1 SUI as collateral
        test_create_trading_order_<SUI, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            collateral_amount,
            sui_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::none(),
            CURRENT_TS_MS
        ); // filled immediately
        next_tx(&mut scenario, ADMIN);
        let order_type_tag = 0;
        let ts_ms = CURRENT_TS_MS;
        let max_operation_count = 10;
        test_match_trading_order_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            trigger_price,
            trigger_price,
            order_type_tag,
            trigger_price,
            max_operation_count,
            ts_ms
        );
        test_create_trading_order_<BABE, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            collateral_amount,
            babe_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::none(),
            CURRENT_TS_MS
        ); // filled immediately
        next_tx(&mut scenario, ADMIN);
        let order_type_tag = 0;
        let ts_ms = CURRENT_TS_MS;
        let max_operation_count = 10;
        test_match_trading_order_<BABE, SUI>(
            &mut scenario,
            babe_oracle_id,
            sui_oracle_id,
            trigger_price,
            trigger_price,
            order_type_tag,
            trigger_price,
            max_operation_count,
            ts_ms
        );

        next_tx(&mut scenario, USER_2);
        let (reduce_only, is_long, is_stop_order) = (false, false, false);
        test_create_trading_order_<BABE, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size * 3,
            trigger_price,
            collateral_amount,
            babe_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::none(),
            CURRENT_TS_MS
        );
        // filled immediately
        next_tx(&mut scenario, ADMIN);
        let order_type_tag = 1;
        let ts_ms = CURRENT_TS_MS;
        let max_operation_count = 10;
        test_match_trading_order_<BABE, SUI>(
            &mut scenario,
            babe_oracle_id,
            sui_oracle_id,
            trigger_price,
            trigger_price,
            order_type_tag,
            trigger_price,
            max_operation_count,
            ts_ms
        );

        next_tx(&mut scenario, USER_2);
        let (reduce_only, is_long, is_stop_order) = (true, true, false);
        test_create_trading_order_<BABE, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size * 3,
            trigger_price,
            collateral_amount,
            babe_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::some(2),
            CURRENT_TS_MS + 10_000, // avoid position cooldown case
        );

        {
            let version = version(&scenario);
            let registry = registry(&scenario);
            let result = trading::get_all_positions<SUI>(
                &version,
                &registry,
                MARKET_INDEX,
                100,
                1,
            );
            assert!(result.length() > 0, 0);
            return_shared(registry);
            return_shared(version);
        };
        next_tx(&mut scenario, ADMIN);

        let position_id = 0;
        // release collateral when profit
        let new_price = 11_0000_0000;
        test_release_collateral_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            new_price,
            new_price,
            position_id,
            0_5000_00000, // release 0.5 SUI
            CURRENT_TS_MS + 10_000
        );
        test_increase_collateral_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            position_id,
            1_0000_00000, // increase 1.0 SUI
            CURRENT_TS_MS + 10_000
        );

        let (
            estimated_liquidation_price,
            has_profit,
            pnl_usd,
            _is_cost,
            _unrealized_cost_in_usd,
            _unrealized_funding_sign,
            _unrealized_funding_fee_usd,
            _unrealized_borrow_fee_usd,
            close_fee_usd
        ) = test_get_estimated_liquidation_price_and_pnl_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            new_price,
            new_price,
            position_id,
            CURRENT_TS_MS + 10_000,
        );
        // pnl_usd = gross pnl - closing position trading fee
        // gross pnl = 10_0000_00000 * (11_0000_0000 - 10_0000_0000) / 10^8 = 10_0000_00000
        // closing position trading fee = 10_0000_00000 * 11_0000_0000 / 10^8 * 0_0008_000 / 10^7 = 880_00000
        // 10_0000_00000 - 880_00000 = 9_9120_00000
        assert!(estimated_liquidation_price == 8_8230_1041, 0);
        assert!(has_profit == true, 0);
        assert!(pnl_usd == 9_9120_00000, 0);
        assert!(close_fee_usd == 880_00000, 0);

        let (
            estimated_liquidation_price,
            has_profit,
            pnl_usd,
            _is_cost,
            _unrealized_cost_in_usd,
            _unrealized_funding_sign,
            _unrealized_funding_fee_usd,
            _unrealized_borrow_fee_usd,
            close_fee_usd
        ) = test_get_estimated_liquidation_price_and_pnl_<BABE, SUI>(
            &mut scenario,
            babe_oracle_id,
            sui_oracle_id,
            new_price,
            new_price,
            1,
            CURRENT_TS_MS + 10_000,
        );
        // pnl_usd = gross pnl - closing position trading fee
        // gross pnl = 10_0000_00000 * (11_0000_0000 - 10_0000_0000) / 10^8 = 10_0000_00000
        // closing position trading fee = 10_0000_00000 * 11_0000_0000 / 10^8 * 0_0008_000 / 10^7 = 880_00000
        // 10_0000_00000 - 880_00000 = 9_9120_00000
        assert!(estimated_liquidation_price == 9_0518_1873, 0); // assume collateral token price unchanged
        assert!(has_profit == true, 0);
        assert!(pnl_usd == 9_9120_00000, 0);
        assert!(close_fee_usd == 880_00000, 0);

        // release collateral when loss
        let new_price = 9_8000_0000;
        test_release_collateral_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            new_price,
            new_price,
            position_id,
            0_5000_00000, // release 0.5 SUI
            CURRENT_TS_MS + 10_000
        );

        let ts_ms = CURRENT_TS_MS + 10_000 + 1;
        test_update_funding_rate_<SUI>(&mut scenario, sui_oracle_id, new_price, ts_ms);
        test_collect_position_funding_fee_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            position_id,
            ts_ms
        );

        let ts_ms = CURRENT_TS_MS + 10_000 + FUNDING_INTERVAL_TS_MS + 1;
        test_update_funding_rate_<SUI>(&mut scenario, sui_oracle_id, new_price, ts_ms);
        test_collect_position_funding_fee_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            position_id,
            ts_ms
        );

        end(scenario);
    }

    #[test]
    public(package) fun test_manager_operations() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (sui_oracle_id, babe_oracle_id) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);

        test_update_market_config_<SUI>(&mut scenario, sui_oracle_id);
        {
            let version = version(&scenario);
            let mut registry = registry(&scenario);
            trading::suspend_trading_symbol<SUI>(
                &version,
                &mut registry,
                MARKET_INDEX,
                ctx(&mut scenario)
            );
            next_tx(&mut scenario, ADMIN);
            trading::resume_trading_symbol<SUI>(
                &version,
                &mut registry,
                MARKET_INDEX,
                ctx(&mut scenario)
            );
            next_tx(&mut scenario, ADMIN);
            trading::suspend_trading_symbol<SUI>(
                &version,
                &mut registry,
                MARKET_INDEX,
                ctx(&mut scenario)
            );
            next_tx(&mut scenario, ADMIN);
            trading::remove_trading_symbol<SUI>(
                &version,
                &mut registry,
                MARKET_INDEX,
                ctx(&mut scenario)
            );
            return_shared(version);
            return_shared(registry);
            next_tx(&mut scenario, ADMIN);
            test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);
            test_update_market_config_<SUI>(&mut scenario, sui_oracle_id);
        };

        prepare_option_collateral_dov_env<SUI, SUI>(&mut scenario, sui_oracle_id, sui_oracle_id);

        // Open three orders by USER_1 (id 0 not filled, id 1 filled, id 2 is position 0 reduce only order)
        next_tx(&mut scenario, USER_1);
        let (reduce_only, is_long, is_stop_order) = (false, true, false);
        let (size, trigger_price) = (10_0000_00000, 9_0000_0000); // 10 contract size, SUIUSD = 9 => should not be filled
        let collateral_amount = 1_0000_00000; // 1 SUI as collateral
        test_create_trading_order_<SUI, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            collateral_amount,
            sui_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::none(),
            CURRENT_TS_MS
        );
        next_tx(&mut scenario, USER_1);
        let (reduce_only, is_long, is_stop_order) = (false, true, false);
        let (size, trigger_price) = (10_0000_00000, 10_0000_0000); // 10 contract size, SUIUSD = 10 => should be filled immediately
        let collateral_amount = 1_0000_00000; // 1 SUI as collateral
        test_create_trading_order_<SUI, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            collateral_amount,
            sui_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::none(),
            CURRENT_TS_MS
        );
        // filled immediately
        next_tx(&mut scenario, ADMIN);
        let order_type_tag = 0;
        let ts_ms = CURRENT_TS_MS;
        let max_operation_count = 10;
        test_match_trading_order_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            trigger_price,
            trigger_price,
            order_type_tag,
            trigger_price,
            max_operation_count,
            ts_ms
        );

        // linked order
        next_tx(&mut scenario, USER_1);
        let (reduce_only, is_long, is_stop_order) = (true, false, false);
        let (size, trigger_price) = (10_0000_00000, 11_0000_0000); // 10 contract size, SUIUSD = 11
        let collateral_amount = 0_0000_00000; // 1 SUI as collateral
        test_create_trading_order_<SUI, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            collateral_amount,
            sui_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::some(0),
            CURRENT_TS_MS + 10_000 // avoid position cooldown case
        );

        // manager reduce position id 0
        let position_id = 0;
        let reduced_ratio_bp = 1_0000; // reduce 100%
        test_manager_reduce_position_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            position_id,
            reduced_ratio_bp,
            CURRENT_TS_MS + 10_000
        );

        // Open one orders by USER_1 (id 3 not filled)
        next_tx(&mut scenario, USER_1);
        let (reduce_only, is_long, is_stop_order) = (false, true, false);
        let (size, trigger_price) = (10_0000_00000, 9_0000_0000); // 10 contract size, SUIUSD = 9 => should not be filled
        let collateral_amount = 1_0000_00000; // 1 SUI as collateral
        test_create_trading_order_<SUI, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            collateral_amount,
            sui_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::none(),
            CURRENT_TS_MS + 10_000
        );

        // no order filled
        next_tx(&mut scenario, ADMIN);
        let order_type_tag = 0;
        let trigger_price = 9_0000_0000;
        let sui_token_price = 10_0000_0000;
        let ts_ms = CURRENT_TS_MS + 10_000;
        let max_operation_count = 10;
        test_match_trading_order_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            sui_token_price,
            sui_token_price,
            order_type_tag,
            trigger_price,
            max_operation_count,
            ts_ms
        );

        // create position id 1 & 2 (two orders got filled)
        next_tx(&mut scenario, ADMIN);
        let order_type_tag = 0;
        let trigger_price = 9_0000_0000;
        let sui_token_price = 9_0000_0000;
        let ts_ms = CURRENT_TS_MS + 10_000;
        let max_operation_count = 10;
        test_match_trading_order_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            sui_token_price,
            sui_token_price,
            order_type_tag,
            trigger_price,
            max_operation_count,
            ts_ms
        );


        // create position id 3
        next_tx(&mut scenario, USER_1);
        let (reduce_only, is_long, is_stop_order) = (false, true, false);
        let (size, trigger_price) = (10_0000_00000, 10_0000_0000); // 10 contract size, SUIUSD = 10 => should be filled immediately
        let collateral_amount = 1_0000_00000; // 1 SUI as collateral
        test_create_trading_order_<BABE, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            collateral_amount,
            babe_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::none(),
            CURRENT_TS_MS + 10_000
        );

        // filled immediately
        next_tx(&mut scenario, ADMIN);
        let order_type_tag = 0;
        let ts_ms = CURRENT_TS_MS + 10_000;
        let max_operation_count = 10;
        test_match_trading_order_<BABE, SUI>(
            &mut scenario,
            babe_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            trigger_price,
            order_type_tag,
            trigger_price,
            max_operation_count,
            ts_ms
        );

        let liquidated_position_id = 1;
        let ts_ms = CURRENT_TS_MS + 10_000 + FUNDING_INTERVAL_TS_MS + 1;
        {
            let version = version(&scenario);
            let registry = registry(&scenario);
            let pool_registry = lp_pool_registry(&scenario);
            let dov_registry = dov_registry(&scenario);
            let mut oracle_c_token = oracle(&scenario, sui_oracle_id);
            let mut clock = new_clock(&mut scenario);
            update_clock(&mut clock, ts_ms);
            let sender_address = sender(&scenario);
            next_tx(&mut scenario, ADMIN);
            let oracle_price_liquidated = 10_0000_0000;
            update_oracle(&mut scenario, &mut oracle_c_token, oracle_price_liquidated, ts_ms);
            next_tx(&mut scenario, sender_address);
            let result = trading::get_liquidation_info<SUI, SUI>(
                &version,
                &registry,
                &pool_registry,
                &dov_registry,
                &oracle_c_token,
                &oracle_c_token,
                &clock,
                MARKET_INDEX,
                0,
                false,
                ctx(&mut scenario)
            );
            assert!(result.length() == 0, 0); // not be liquidated

            let sender_address = sender(&scenario);
            next_tx(&mut scenario, ADMIN);
            let oracle_price_liquidated = 8_0000_0000;
            update_oracle(&mut scenario, &mut oracle_c_token, oracle_price_liquidated, ts_ms);
            next_tx(&mut scenario, sender_address);
            let result = trading::get_liquidation_info<SUI, SUI>(
                &version,
                &registry,
                &pool_registry,
                &dov_registry,
                &oracle_c_token,
                &oracle_c_token,
                &clock,
                MARKET_INDEX,
                0,
                false,
                ctx(&mut scenario)
            );
            assert!(result.length() > 0, 0); // should be liquidated
            let result = trading::get_liquidation_info<SUI, SUI>(
                // for share objects
                &version,
                &registry,
                &pool_registry,
                &dov_registry,
                &oracle_c_token,
                &oracle_c_token,
                &clock,
                MARKET_INDEX,
                0,
                true,
                ctx(&mut scenario)
            );
            assert!(result.length() > 0, 0);
            return_shared(version);
            return_shared(registry);
            return_shared(pool_registry);
            return_shared(dov_registry);
            return_shared(oracle_c_token);
            clock.destroy_for_testing();
        };
        next_tx(&mut scenario, ADMIN);
        let oracle_price_liquidated = 8_0000_0000;
        test_liquidate_<SUI, SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            liquidated_position_id,
            oracle_price_liquidated, // liquidate price for collateral token
            oracle_price_liquidated, // liquidate price for trading symbol
            ts_ms
        );

        // create position id 4
        next_tx(&mut scenario, USER_1);
        let is_long = false;
        let current_trading_price = 11_0000_0000;
        let ts_ms = CURRENT_TS_MS + 10_000 + FUNDING_INTERVAL_TS_MS + 1;
        test_create_trading_order_with_bid_receipt_v3_<SUI, SUI, SUI>(&mut scenario, sui_oracle_id, sui_oracle_id, current_trading_price, is_long, ts_ms);

        let liquidated_position_id = 4;
        let ts_ms = EXPIRATION_TS_MS + 1;
        let oracle_price_liquidated = 100_0000_0000;
        // dov not settled => itm => nothing happened
        test_liquidate_<SUI, SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            liquidated_position_id,
            oracle_price_liquidated, // liquidate price for collateral token
            oracle_price_liquidated, // liquidate price for trading symbol
            ts_ms
        );

        end(scenario);
    }

    #[test]
    public(package) fun test_get_user_positions() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (sui_oracle_id, _babe_oracle_id) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);
        test_update_market_config_<SUI>(&mut scenario, sui_oracle_id);
        // Open two orders by USER_1 (id 0 not filled, id 1 filled)
        next_tx(&mut scenario, USER_1);
        let (reduce_only, is_long, is_stop_order) = (false, true, false);
        let (size, trigger_price) = (10_0000_00000, 9_0000_0000); // 10 contract size, SUIUSD = 9 => should not be filled
        let collateral_amount = 1_0000_00000; // 1 SUI as collateral
        test_create_trading_order_<SUI, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            collateral_amount,
            sui_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::none(),
            CURRENT_TS_MS
        );
        next_tx(&mut scenario, USER_1);
        let (reduce_only, is_long, is_stop_order) = (false, true, false);
        let (size, trigger_price) = (10_0000_00000, 10_0000_0000); // 10 contract size, SUIUSD = 10 => should be filled immediately
        let collateral_amount = 1_0000_00000; // 1 SUI as collateral
        test_create_trading_order_<SUI, SUI>(
            &mut scenario,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            collateral_amount,
            sui_oracle_id,
            sui_oracle_id,
            SUI_PRICE,
            SUI_PRICE,
            option::none(),
            CURRENT_TS_MS
        );
        // filled immediately
        next_tx(&mut scenario, ADMIN);
        let order_type_tag = 0;
        let ts_ms = CURRENT_TS_MS;
        let max_operation_count = 10;
        test_match_trading_order_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            trigger_price,
            trigger_price,
            order_type_tag,
            trigger_price,
            max_operation_count,
            ts_ms
        );
        next_tx(&mut scenario, ADMIN);

        // get_user_positions
        let version = version(&scenario);
        let registry = registry(&scenario);
        let positions = trading::get_user_positions(
            &version,
            &registry,
            MARKET_INDEX,
            USER_1
        );
        assert!(positions.length() > 0, 0);
        std::debug::print(&positions);
        return_shared(registry);
        return_shared(version);
        end(scenario);
    }

    #[test]
    public(package) fun test_normal_operation_for_option_position() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (sui_oracle_id, _babe_oracle_id) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);
        test_update_market_config_<SUI>(&mut scenario, sui_oracle_id);

        prepare_option_collateral_dov_env<SUI, SUI>(&mut scenario, sui_oracle_id, sui_oracle_id);

        next_tx(&mut scenario, USER_1);
        let is_long = false;
        let current_trading_price = 11_0000_0000;
        test_create_trading_order_with_bid_receipt_v3_<SUI, SUI, SUI>(&mut scenario, sui_oracle_id, sui_oracle_id, current_trading_price, is_long, CURRENT_TS_MS);

        let position_id = 0;
        let (
            estimated_liquidation_price,
            has_profit,
            pnl_usd,
            _is_cost,
            _unrealized_cost_in_usd,
            _unrealized_funding_sign,
            _unrealized_funding_fee_usd,
            _unrealized_borrow_fee_usd,
            close_fee_usd
        ) = test_get_estimated_liquidation_price_and_pnl_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            current_trading_price,
            current_trading_price,
            position_id,
            CURRENT_TS_MS,
        );
        assert!(estimated_liquidation_price == 1207078867, 0);
        assert!(has_profit == false, 0);
        assert!(pnl_usd == 220000000, 0);
        assert!(close_fee_usd == 220000000, 0);

        next_tx(&mut scenario, USER_1);
        let position_id = 0;
        let current_trading_price = 10_0000_0000;
        let order_size = 10_0000_00000;
        let ts_ms = CURRENT_TS_MS + 1;
        test_reduce_option_collateral_position_size_<SUI, SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            current_trading_price,
            position_id,
            option::some(order_size),
            ts_ms + 10_000, // avoid position cooldown case
        );

        let ts_ms = EXPIRATION_TS_MS + 1;
        test_update_funding_rate_<SUI>(&mut scenario, sui_oracle_id, current_trading_price, ts_ms);

        next_tx(&mut scenario, USER_1);
        let ts_ms = EXPIRATION_TS_MS + 1;
        test_reduce_option_collateral_position_size_<SUI, SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            current_trading_price,
            position_id,
            option::none(),
            ts_ms
        );
        end(scenario);
    }

    // manager_close_option_position_v2
    #[test]
    public(package) fun test_manager_operation_for_option_position() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (sui_oracle_id, _babe_oracle_id) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);
        test_update_market_config_<SUI>(&mut scenario, sui_oracle_id);

        prepare_option_collateral_dov_env<SUI, SUI>(&mut scenario, sui_oracle_id, sui_oracle_id);

        next_tx(&mut scenario, USER_1);
        let is_long = false;
        let current_trading_price = 11_0000_0000;
        test_create_trading_order_with_bid_receipt_v3_<SUI, SUI, SUI>(&mut scenario, sui_oracle_id, sui_oracle_id, current_trading_price, is_long, CURRENT_TS_MS);

        let ts_ms = EXPIRATION_TS_MS + 1;
        test_dov_recoup_and_settle_and_activate_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            current_trading_price,
            current_trading_price,
            ts_ms
        );
        test_update_funding_rate_<SUI>(&mut scenario, sui_oracle_id, current_trading_price, ts_ms);

        let position_id = 0;
        test_manager_close_option_position<SUI, SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            current_trading_price,
            current_trading_price,
            position_id,
            ts_ms
        );
        end(scenario);
    }
    // liquidate option collateral position
    #[test]
    public(package) fun test_liquidate_option_position() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (sui_oracle_id, _babe_oracle_id) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);
        test_update_market_config_<SUI>(&mut scenario, sui_oracle_id);

        prepare_option_collateral_dov_env<SUI, SUI>(&mut scenario, sui_oracle_id, sui_oracle_id);

        next_tx(&mut scenario, USER_1);
        let is_long = false;
        let current_trading_price = 11_0000_0000;
        test_create_trading_order_with_bid_receipt_v3_<SUI, SUI, SUI>(&mut scenario, sui_oracle_id, sui_oracle_id, current_trading_price, is_long, CURRENT_TS_MS);

        let ts_ms = EXPIRATION_TS_MS + 1;
        test_dov_recoup_and_settle_and_activate_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            current_trading_price,
            current_trading_price,
            ts_ms
        );
        test_update_funding_rate_<SUI>(&mut scenario, sui_oracle_id, current_trading_price, ts_ms);

        {
            let version = version(&scenario);
            let registry = registry(&scenario);
            let pool_registry = lp_pool_registry(&scenario);
            let dov_registry = dov_registry(&scenario);
            let result
                = trading::get_expired_position_info(&version, &registry, &pool_registry, &dov_registry, MARKET_INDEX, 0, ctx(&mut scenario));
            assert!(result.length() > 0, 0);
            return_shared(version);
            return_shared(registry);
            return_shared(pool_registry);
            return_shared(dov_registry);
        };
        next_tx(&mut scenario, ADMIN);

        // settle at current_trading_price
        let liquidated_position_id = 0;
        let ts_ms = EXPIRATION_TS_MS + 1;
        let oracle_price_liquidated = 100_0000_0000;
        next_tx(&mut scenario, ADMIN);
        test_liquidate_<SUI, SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            sui_oracle_id,
            liquidated_position_id,
            oracle_price_liquidated, // liquidate price for collateral token
            oracle_price_liquidated, // liquidate price for trading symbol
            ts_ms
        );
        end(scenario);
    }

    #[test]
    public(package) fun test_settle_receipt_collateral() {
        let mut scenario = begin_test();
        test_new_markets_(&mut scenario);
        let (sui_oracle_id, babe_oracle_id) = prepare_lp_pool_env(&mut scenario, 1_000_000_000000000); // 1 million SUI
        test_add_trading_symbol_<SUI>(&mut scenario, sui_oracle_id, CURRENT_TS_MS);
        test_update_market_config_<SUI>(&mut scenario, sui_oracle_id);

        prepare_option_collateral_dov_env<BABE, BABE>(&mut scenario, sui_oracle_id, sui_oracle_id);

        next_tx(&mut scenario, USER_1);
        let is_long = false;
        let current_trading_price = 11_0000_0000;
        test_create_trading_order_with_bid_receipt_v3_<BABE, BABE, SUI>(&mut scenario, babe_oracle_id, sui_oracle_id, current_trading_price, is_long, CURRENT_TS_MS);

        let (
            _estimated_liquidation_price,
            _has_profit,
            _pnl_usd,
            _is_cost,
            _unrealized_cost_in_usd,
            _unrealized_funding_sign,
            _unrealized_funding_fee_usd,
            _unrealized_borrow_fee_usd,
            _close_fee_usd
        ) = test_get_estimated_liquidation_price_and_pnl_<BABE, SUI>(
            &mut scenario,
            babe_oracle_id,
            sui_oracle_id,
            current_trading_price,
            current_trading_price,
            0,
            CURRENT_TS_MS,
        );

        {
            let version = version(&scenario);
            let registry = registry(&scenario);
            let pool_registry = lp_pool_registry(&scenario);
            let dov_registry = dov_registry(&scenario);
            let babe_oracle = oracle(&scenario, babe_oracle_id);
            let mut sui_oracle = oracle(&scenario, sui_oracle_id);
            let mut clock = new_clock(&mut scenario);
            update_clock(&mut clock, CURRENT_TS_MS);
            let sender_address = sender(&scenario);
            next_tx(&mut scenario, ADMIN);
            let oracle_price_liquidated = 11_0000_0000;
            update_oracle(&mut scenario, &mut sui_oracle, oracle_price_liquidated, CURRENT_TS_MS);
            next_tx(&mut scenario, sender_address);
            let result = trading::get_liquidation_info<BABE, SUI>(
                &version,
                &registry,
                &pool_registry,
                &dov_registry,
                &babe_oracle,
                &sui_oracle,
                &clock,
                MARKET_INDEX,
                0,
                false,
                ctx(&mut scenario)
            );
            assert!(result.length() == 0, 0); // not be liquidated

            let result = trading::get_liquidation_info<BABE, SUI>(
                // for share objects
                &version,
                &registry,
                &pool_registry,
                &dov_registry,
                &babe_oracle,
                &sui_oracle,
                &clock,
                MARKET_INDEX,
                0,
                true,
                ctx(&mut scenario)
            );
            assert!(result.length() > 0, 0);
            return_shared(version);
            return_shared(registry);
            return_shared(pool_registry);
            return_shared(dov_registry);
            return_shared(babe_oracle);
            return_shared(sui_oracle);
            clock.destroy_for_testing();
        };

        let ts_ms = CURRENT_TS_MS + 1;
        let liquidated_position_id = 0;
        let collateral_token_price = 10; // collateral with only small value
        let oracle_price_liquidated = 12_0000_0000; // unchanged
        next_tx(&mut scenario, ADMIN);
        test_liquidate_<BABE, BABE, SUI>(
            &mut scenario,
            babe_oracle_id,
            sui_oracle_id,
            liquidated_position_id,
            collateral_token_price, // liquidate price for collateral token
            oracle_price_liquidated, // liquidate price for trading symbol
            ts_ms
        );

        {
            let pool_registry = lp_pool_registry(&scenario);
            let result = lp_pool::get_receipt_collateral_bcs(&pool_registry, 0);
            assert!(result.length() > 0, 0);
            return_shared(pool_registry);
        };
        next_tx(&mut scenario, ADMIN);

        let ts_ms = EXPIRATION_TS_MS + 1;
        test_dov_recoup_and_settle_and_activate_<BABE, BABE>(
            &mut scenario,
            babe_oracle_id,
            sui_oracle_id,
            current_trading_price,
            current_trading_price,
            ts_ms
        );
        test_update_funding_rate_<SUI>(&mut scenario, sui_oracle_id, current_trading_price, ts_ms);

        {
            let pool_registry = lp_pool_registry(&scenario);
            let dov_registry = dov_registry(&scenario);
            let result = lp_pool::get_expired_receipt_collateral_bcs(&pool_registry, &dov_registry, 0);
            assert!(result.length() > 0);
            return_shared(pool_registry);
            return_shared(dov_registry);
        };
        next_tx(&mut scenario, ADMIN);

        // nothing happened
        test_settle_receipt_collateral_<SUI, SUI>(
            &mut scenario,
            sui_oracle_id,
            current_trading_price,
            ts_ms
        );

        test_settle_receipt_collateral_<BABE, BABE>(
            &mut scenario,
            babe_oracle_id,
            current_trading_price,
            ts_ms
        );
        end(scenario);
    }

    #[test]
    public(package) fun test_calculate_trading_fee_rate_mbp() {
        let scenario = begin_test();

        let formula_version = 1;
        let (user_long_position_size, user_short_position_size, size_decimal) = (100_0000_00000, 800_0000_00000, 9);
        let tvl_usd = 1_000_000_000000000; // 10 million USD
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = (249_5000_0000, 8);
        let (order_side, order_size) = (false, 500_0000_00000);
        let trading_fee_config = vector[0_000_6000, 0_003_0000, 0_330_0000, 3, 1];
        let trading_fee_rate_mbp = trading::calculate_trading_fee_rate_mbp(
            formula_version,
            // infos
            user_long_position_size,
            user_short_position_size,
            tvl_usd,
            size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            order_side,
            order_size,
            trading_fee_config,
        );
        assert!(trading_fee_rate_mbp == 7296, 0);


        let (order_side, order_size) = (true, 500_0000_00000);
        let trading_fee_rate_mbp = trading::calculate_trading_fee_rate_mbp(
            formula_version,
            // infos
            user_long_position_size,
            user_short_position_size,
            tvl_usd,
            size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            order_side,
            order_size,
            trading_fee_config,
        );
        assert!(trading_fee_rate_mbp == trading_fee_config[0], 0);


        let (order_side, order_size) = (true, 1400_0000_00000);
        let trading_fee_rate_mbp = trading::calculate_trading_fee_rate_mbp(
            formula_version,
            // infos
            user_long_position_size,
            user_short_position_size,
            tvl_usd,
            size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            order_side,
            order_size,
            trading_fee_config,
        );
        assert!(trading_fee_rate_mbp == trading_fee_config[0], 0);


        let (order_side, order_size) = (false, 1400_0000_00000);
        let trading_fee_rate_mbp = trading::calculate_trading_fee_rate_mbp(
            formula_version,
            // infos
            user_long_position_size,
            user_short_position_size,
            tvl_usd,
            size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            order_side,
            order_size,
            trading_fee_config,
        );
        assert!(trading_fee_rate_mbp == trading_fee_config[1], 0);


        let (order_side, order_size) = (true, 2800_0000_00000);
        let trading_fee_rate_mbp = trading::calculate_trading_fee_rate_mbp(
            formula_version,
            // infos
            user_long_position_size,
            user_short_position_size,
            tvl_usd,
            size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            order_side,
            order_size,
            trading_fee_config,
        );
        assert!(trading_fee_rate_mbp == trading_fee_config[1], 0);


        let (order_side, order_size) = (true, 1);
        let trading_fee_rate_mbp = trading::calculate_trading_fee_rate_mbp(
            formula_version,
            // infos
            user_long_position_size,
            user_short_position_size,
            tvl_usd,
            size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            order_side,
            order_size,
            trading_fee_config,
        );
        assert!(trading_fee_rate_mbp == trading_fee_config[0], 0);
        end(scenario);
    }
}