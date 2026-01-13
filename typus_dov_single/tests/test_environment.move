#[test_only]
module typus_dov::test_environment {
    use std::type_name;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::test_scenario::{Scenario, ctx, sender, next_tx, take_shared, return_shared, take_from_sender, return_to_sender, take_shared_by_id, take_immutable, return_immutable};
    use typus_dov::typus_dov_single::{Self, Registry as DovRegistry};
    use typus_dov::auto_bid::{Self, StrategyPoolV3};
    use typus_dov::babe::{Self, BABE};
    use typus_dov::babe2::{Self, BABE2};
    use typus_dov::scallop_tests;
    use typus::ecosystem::{Self, Version as TypusEcosystemVersion};
    use typus::leaderboard::{Self, TypusLeaderboardRegistry};
    use typus::user::{Self, TypusUserRegistry};
    use typus::tgld::{Self, TgldRegistry};
    use typus_oracle::oracle::{Self as typus_oracle, Oracle, ManagerCap as OracleManagerCap};

    use pyth::pyth_tests;
    use pyth::pyth;
    use wormhole::state::{State as WormState};
    use wormhole::vaa::{Self, VAA};
    use oracle::oracle::{Self as navi_oracle};
    use oracle::oracle_manage;
    use protocol::mint;

    const ADMIN: address = @0xFFFF;
    const BABE_2: address = @0xBABE2;
    const CURRENT_TS_MS: u64 = 1_715_212_800_000;
    const SUI_PRICE: u64 = 100000_0000_0000;
    const SUI_PRICE_DECIMAL: u64 = 8;

    public struct USD has drop {}
    public struct USDC has drop {}

    public(package) fun new_dov_registry(scenario: &mut Scenario) {
        typus_dov_single::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_typus_user_registry(scenario: &mut Scenario) {
        user::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_leaderboard_registry(scenario: &mut Scenario) {
        leaderboard::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_tgld_registry(scenario: &mut Scenario) {
        tgld::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_version(scenario: &mut Scenario) {
        ecosystem::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_clock(scenario: &mut Scenario): Clock {
        let mut clock = clock::create_for_testing(ctx(scenario));
        clock::set_for_testing(&mut clock, CURRENT_TS_MS);
        clock
    }

    public(package) fun update_clock(clock: &mut Clock, ts_ms: u64) {
        clock::set_for_testing(clock, ts_ms);
    }

    public(package) fun init_oracle(scenario: &mut Scenario) {
        typus_oracle::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_oracle<TOKEN>(scenario: &mut Scenario): ID {
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

    public(package) fun update_oracle(scenario: &mut Scenario, oracle: &mut Oracle, new_price: u64, ts_ms: u64) {
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

    public(package) fun new_strategy_pool(scenario: &mut Scenario) {
        auto_bid::new_strategy_pool(scenario);
        next_tx(scenario, ADMIN);
    }

    public(package) fun mint_test_coin<T>(scenario: &mut Scenario, amount: u64): Coin<T> {
        coin::mint_for_testing<T>(amount, ctx(scenario))
    }

    public(package) fun dov_registry(scenario: &Scenario): DovRegistry {
        take_shared<DovRegistry>(scenario)
    }

    // public(package) fun strategy_pool_v2(scenario: &Scenario): StrategyPoolV2 {
    //     take_shared<StrategyPoolV2>(scenario)
    // }

    public(package) fun strategy_pool_v3(scenario: &Scenario): StrategyPoolV3 {
        take_shared<StrategyPoolV3>(scenario)
    }

    public(package) fun typus_user_registry(scenario: &Scenario): TypusUserRegistry {
        take_shared<TypusUserRegistry>(scenario)
    }

    public(package) fun leaderboard_registry(scenario: &Scenario): TypusLeaderboardRegistry {
        take_shared<TypusLeaderboardRegistry>(scenario)
    }

    public(package) fun tgld_registry(scenario: &Scenario): TgldRegistry {
        take_shared<TgldRegistry>(scenario)
    }

    public(package) fun ecosystem_version(scenario: &Scenario): TypusEcosystemVersion {
        take_shared<TypusEcosystemVersion>(scenario)
    }

    public(package) fun oracle(scenario: &Scenario, id: ID): Oracle {
        take_shared_by_id<Oracle>(scenario, id)
    }

    public(package) fun oracle_manager_cap(scenario: &Scenario): OracleManagerCap {
        take_from_sender<OracleManagerCap>(scenario)
    }

    public(package) fun current_ts_ms(): u64 { return CURRENT_TS_MS }

    public(package) fun navi_update_token_price(
        scenario: &mut Scenario,
        asset_id: u8,
        new_token_price: u256,
        ts_ms: u64,
    ) {
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);
        let mut price_oracle = take_shared<oracle::oracle::PriceOracle>(scenario);
        let oracle_feeder_cap = take_from_sender<oracle::oracle::OracleFeederCap>(scenario);

        navi_oracle::update_token_price(
            &oracle_feeder_cap,
            &clock,
            &mut price_oracle,
            asset_id,
            new_token_price,
        );

        return_to_sender(scenario, oracle_feeder_cap);
        return_shared(price_oracle);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    public(package) fun begin_test(): Scenario {
        let (mut scenario, _clock_ts_ms) = prepare_pyth();
        new_dov_registry(&mut scenario);
        new_strategy_pool(&mut scenario);

        babe::test_init(ctx(&mut scenario));
        babe2::test_init(ctx(&mut scenario));

        // create deposit snapshot
        let mut dov_registry = dov_registry(&scenario);
        typus_dov_single::create_deposit_snapshots_additional_config(&mut dov_registry, ctx(&mut scenario));
        next_tx(&mut scenario, ADMIN);

        new_version(&mut scenario);
        next_tx(&mut scenario, ADMIN);

        // issue ecosystem manager cap into typus_dov_single
        let ecosystem_version = ecosystem_version(&scenario);
        typus_dov_single::test_issue_ecosystem_manager_cap(&mut dov_registry, &ecosystem_version, ctx(&mut scenario));
        next_tx(&mut scenario, ADMIN);

        new_typus_user_registry(&mut scenario);
        new_leaderboard_registry(&mut scenario);
        init_oracle(&mut scenario);

        new_tgld_registry(&mut scenario);

        return_shared(dov_registry);
        return_shared(ecosystem_version);
        next_tx(&mut scenario, ADMIN);
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

    public(package) fun prepare_pyth(): (Scenario, u64) {
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

    public(package) fun prepare_scallop_lending_env(scenario: &mut Scenario) {
        let clock = new_clock(scenario);
        let version = protocol::version::create_for_testing(ctx(scenario));
        let (mut market, admin_cap) = scallop_tests::app_init(scenario);
        let babe_interest_params = scallop_tests::babe_interest_model_params();
        next_tx(scenario, ADMIN);

        scallop_tests::add_interest_model_t<BABE>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &babe_interest_params, &clock);

        let mut coin_decimals_registry_obj = scallop_tests::coin_decimals_registry_init(scenario);
        coin_decimals_registry::coin_decimals_registry::register_decimals_t<BABE>(&mut coin_decimals_registry_obj, 9);

        next_tx(scenario, BABE_2);
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

    public(package) fun prepare_navi_lending_env(scenario: &mut Scenario) {
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
        let sui_coin_metadata = take_immutable<sui::coin::CoinMetadata<BABE>>(scenario);
        let storage_admin_cap = take_from_sender<lending_core::storage::StorageAdminCap>(scenario);
        let oracle_id = 0; // 4
        let is_isolated = true; // 5
        let max_capacity = 20000000000000000000000000000000000000000000; // idx 6
        let max_borrow_capacity = 900000000000000000000000000; // 7
        let (
            base_rate,
            optimal_utilization,
            multiplier,
            jump_rate_multiplier,
            reserve_factor,
        ) = (
            0,
            550000000000000000000000000,
            116360000000000000000000000,
            3000000000000000000000000000,
            200000000000000000000000000
        );
        let ltv = 550000000000000000000000000; // 13
        let treasury_factor = 100000000000000000000000000; // 14
        let (bonus, ratio, threshold) = (100000000000000000000000000, 350000000000000000000000000, 800000000000000000000000000); // 15~17
        lending_core::storage::init_reserve<BABE>(
            &storage_admin_cap, &pool_admin_cap, &clock, &mut storage, oracle_id,
            is_isolated, max_capacity, max_borrow_capacity,
            base_rate, optimal_utilization, multiplier, jump_rate_multiplier, reserve_factor,
            ltv, treasury_factor, bonus, ratio, threshold, &sui_coin_metadata, ctx(scenario));
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
}

#[test_only]
module typus_dov::babe {
    use sui::coin;
    use sui::url;

    public struct BABE has drop {}

    const Decimals: u8 = 9;
    // Due to the package size, we changed it to a test_only function
    #[test_only, allow(deprecated_usage)]
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
module typus_dov::babe2 {
    use sui::coin;
    use sui::url;

    public struct BABE2 has drop {}

    const Decimals: u8 = 9;
    // Due to the package size, we changed it to a test_only function
    #[test_only, allow(deprecated_usage)]
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
module typus_dov::scallop_tests {
    use sui::test_scenario::{Self, Scenario, next_tx, next_epoch, sender, ctx, take_shared, take_from_sender};
    use sui::clock::Clock;
    use protocol::market::Market;
    use protocol::app::{Self, AdminCap};
    use whitelist::whitelist;
    use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};
    use math::u64;
    use typus_dov::babe::BABE;

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

        // set-up incentive rewards
        // app::set_incentive_reward_factor<BABE>(
        //     &adminCap,
        //     &mut market,
        //     1000,
        //     1,
        //     ctx(scenario)
        // );

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

        app::update_borrow_fee_recipient(
            &adminCap,
            &mut market,
            sender
        );

        whitelist::allow_all(app::ext(&adminCap, &mut market));

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