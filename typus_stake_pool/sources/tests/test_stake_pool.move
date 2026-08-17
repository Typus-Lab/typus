#[test_only]
module typus_stake_pool::test_stake_pool {
    use std::type_name;

    use sui::balance;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::test_scenario::{Scenario, begin, end, ctx, next_tx, take_shared, return_shared, sender};

    use typus_stake_pool::admin::{Self, Version};
    use typus_stake_pool::stake_pool::{Self, StakePoolRegistry};
    use typus_stake_pool::test_tlp::TEST_TLP;
    use typus_stake_pool::babe::BABE;

    use typus::ecosystem::{Self, Version as TypusEcosystemVersion};
    use typus::user::{Self, TypusUserRegistry};

    const ADMIN: address = @0xFFFF;
    const USER_1: address = @0xBABE1;
    const USER_2: address = @0xBABE2;
    const UNLOCK_COUNTDOWN_TS_MS: u64 = 5 * 24 * 60 * 60 * 1000; // 5 days
    const PERIOD_INCENTIVE_AMOUNT: u64 = 0_0100_00000;
    const INCENTIVE_INTERVAL_TS_MS: u64 = 60_000;
    const C_INCENTIVE_INDEX_DECIMAL: u64 = 9;

    const CURRENT_TS_MS: u64 = 1_715_212_800_000;

    fun new_registry(scenario: &mut Scenario) {
        stake_pool::test_init(ctx(scenario));
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

    fun new_typus_user_registry(scenario: &mut Scenario) {
        user::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun registry(scenario: &Scenario): StakePoolRegistry {
        take_shared<StakePoolRegistry>(scenario)
    }

    fun version(scenario: &Scenario): Version {
        take_shared<Version>(scenario)
    }

    fun ecosystem_version(scenario: &Scenario): TypusEcosystemVersion {
        take_shared<TypusEcosystemVersion>(scenario)
    }

    fun typus_user_registry(scenario: &Scenario): TypusUserRegistry {
        take_shared<TypusUserRegistry>(scenario)
    }

    fun mint_test_coin<T>(scenario: &mut Scenario, amount: u64): Coin<T> {
        coin::mint_for_testing<T>(amount, ctx(scenario))
    }

    fun update_clock(clock: &mut Clock, ts_ms: u64) {
        clock::set_for_testing(clock, ts_ms);
    }

    fun test_new_stake_pool_<LP_TOKEN>(scenario: &mut Scenario) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        stake_pool::new_stake_pool<LP_TOKEN>(
            &version,
            &mut registry,
            UNLOCK_COUNTDOWN_TS_MS,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_add_incentive_token_<I_TOKEN>(scenario: &mut Scenario, index: u64) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let clock = new_clock(scenario);
        stake_pool::add_incentive_token<I_TOKEN>(
            &version,
            &mut registry,
            index,
            // incentive config
            PERIOD_INCENTIVE_AMOUNT,
            INCENTIVE_INTERVAL_TS_MS,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_remove_incentive_token_<I_TOKEN>(scenario: &mut Scenario, index: u64) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let incentive = stake_pool::remove_incentive_token<I_TOKEN>(
            &version,
            &mut registry,
            index,
            ctx(scenario)
        );
        transfer::public_transfer(incentive, ADMIN);
        return_shared(registry);
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_deactivate_incentive_token_<I_TOKEN>(scenario: &mut Scenario, index: u64) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let clock = new_clock(scenario);
        stake_pool::deactivate_incentive_token<I_TOKEN>(
            &version,
            &mut registry,
            index,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_activate_incentive_token_<I_TOKEN>(scenario: &mut Scenario, index: u64) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let clock = new_clock(scenario);
        stake_pool::activate_incentive_token<I_TOKEN>(
            &version,
            &mut registry,
            index,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_deposit_incentive_<I_TOKEN>(scenario: &mut Scenario, index: u64, incentive_amount: u64) {
        let deposit_incentive = mint_test_coin<I_TOKEN>(scenario, incentive_amount);
        let mut registry = registry(scenario);
        let version = version(scenario);
        stake_pool::deposit_incentive<I_TOKEN>(
            &version,
            &mut registry,
            index,
            deposit_incentive,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_withdraw_incentive_v2_<I_TOKEN>(scenario: &mut Scenario, index: u64, incentive_amount: Option<u64>) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let clock = new_clock(scenario);
        let incentive_coin = stake_pool::withdraw_incentive<I_TOKEN>(
            &version,
            &mut registry,
            index,
            incentive_amount,
            &clock,
            ctx(scenario)
        );
        transfer::public_transfer(incentive_coin, ADMIN);
        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_stake_<LP_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        stake_amount: u64,
        stake_ts_ms: u64
    ) {
        let lp_token = mint_test_coin<LP_TOKEN>(scenario, stake_amount);
        let mut registry = registry(scenario);
        let version = version(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, stake_ts_ms);
        stake_pool::stake<LP_TOKEN>(
            &version,
            &mut registry,
            index,
            lp_token,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_unsubscribe_<LP_TOKEN>(scenario: &mut Scenario, index: u64, unsubscribed_shares: Option<u64>, unsubscribe_ts_ms: u64) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, unsubscribe_ts_ms);

        stake_pool::unsubscribe<LP_TOKEN>(
            &version,
            &mut registry,
            index,
            unsubscribed_shares,
            &clock,
            ctx(scenario)
        );

        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_snapshot_(scenario: &mut Scenario, index: u64, snapshot_ts_ms: u64) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let ecosystem_version = ecosystem_version(scenario);
        let mut typus_user_registry = typus_user_registry(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, snapshot_ts_ms);

        stake_pool::snapshot(
            &version,
            &mut registry,
            &ecosystem_version,
            &mut typus_user_registry,
            index,
            &clock,
            ctx(scenario)
        );

        return_shared(registry);
        return_shared(version);
        return_shared(ecosystem_version);
        return_shared(typus_user_registry);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_unstake_<LP_TOKEN>(scenario: &mut Scenario, index: u64, unstake_ts_ms: u64): u64 {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, unstake_ts_ms);

        let mut balance = balance::zero<LP_TOKEN>();
        let unstake_coin = stake_pool::unstake<LP_TOKEN>(
            &version,
            &mut registry,
            index,
            &clock,
            ctx(scenario),
        );
        balance.join(unstake_coin.into_balance());

        let unstake_balance_value = balance.value();
        transfer::public_transfer(coin::from_balance(balance, ctx(scenario)), sender(scenario));

        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
        unstake_balance_value
    }

    fun test_auto_compound_<LP_TOKEN>(scenario: &mut Scenario, index: u64, ts_ms: u64) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, ts_ms);

        stake_pool::auto_compound<LP_TOKEN>(
            &version,
            &mut registry,
            index,
            &clock,
            ctx(scenario),
        );

        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_harvest_per_user_share_<I_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        harvest_ts_ms: u64
    ): (u64, u64) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        let mut clock = new_clock(scenario);
        update_clock(&mut clock, harvest_ts_ms);
        let harvest_coin = stake_pool::harvest_per_user_share<I_TOKEN>(
            &version,
            &mut registry,
            index,
            &clock,
            ctx(scenario),
        );
        let harvest_coin_value = harvest_coin.value();
        let (_user_share_id, _, _, _, last_incentive_price_index)
            = stake_pool::test_get_single_lp_user_share_info<I_TOKEN>(&registry, index, ctx(scenario));
        let incentive_token = type_name::with_defining_ids<I_TOKEN>();
        let incentive_idx_opt = stake_pool::test_get_incentive_idx(stake_pool::test_get_stake_pool(&registry, index), &incentive_token);
        let incentive_idx = incentive_idx_opt.destroy_some();
        let incentive_price_indices
            = stake_pool::test_get_last_incentive_price_index(stake_pool::test_get_stake_pool(&registry, index));
        let incentive_price_index = incentive_price_indices[incentive_idx];
        assert!(last_incentive_price_index == incentive_price_index, 0);
        transfer::public_transfer(harvest_coin, sender(scenario));
        return_shared(registry);
        return_shared(version);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
        (harvest_coin_value, incentive_price_index)
    }

    fun update_pool_info_u64_padding(
        scenario: &mut Scenario,
        index: u64,
        tlp_price: u64, // decimal 4
        usd_per_exp: u64, // 200 usd = earn 1 exp for 1 hour
    ) {
        let mut registry = registry(scenario);
        let version = version(scenario);
        stake_pool::update_pool_info_u64_padding(
            &version,
            &mut registry,
            index,
            tlp_price,
            usd_per_exp,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun multiplier(decimal: u64): u64 {
        let mut i = 0;
        let mut multiplier = 1;
        while (i < decimal) {
            multiplier = multiplier * 10;
            i = i + 1;
        };
        multiplier
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

    fun begin_test(): Scenario {
        let mut scenario = begin(ADMIN);
        new_registry(&mut scenario);
        new_version(&mut scenario);
        new_typus_user_registry(&mut scenario);
        install_ecosystem_manager_cap_entry(&mut scenario);
        test_new_stake_pool_<TEST_TLP>(&mut scenario);
        update_pool_info_u64_padding(&mut scenario, 0, 1_0000, 200);
        next_tx(&mut scenario, ADMIN);
        scenario
    }

    #[test]
    public(package) fun test_add_and_remove_incentive_token() {
        let mut scenario = begin_test();
        let index = 0;
        test_add_incentive_token_<SUI>(&mut scenario, index);
        test_add_incentive_token_<BABE>(&mut scenario, index);
        test_add_incentive_token_<TEST_TLP>(&mut scenario, index);
        test_remove_incentive_token_<BABE>(&mut scenario, index);
        test_deactivate_incentive_token_<TEST_TLP>(&mut scenario, index);
        test_activate_incentive_token_<TEST_TLP>(&mut scenario, index);
        end(scenario);
    }

    #[test]
    public(package) fun test_deposit_and_withdraw_incentive() {
        let mut scenario = begin_test();
        let index = 0;
        test_add_incentive_token_<SUI>(&mut scenario, index);
        let incentive_amount = 1000_0000_00000;
        test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);
        test_withdraw_incentive_v2_<SUI>(&mut scenario, index, option::some(100_0000_00000));
        end(scenario);
    }

    #[test]
    public(package) fun test_update_config() {
        let mut scenario = begin_test();
        let index = 0;
        test_add_incentive_token_<SUI>(&mut scenario, index);
        let incentive_amount = 1000_0000_00000;
        test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);
        {
            let version = version(&scenario);
            let mut registry = registry(&scenario);
            stake_pool::update_unlock_countdown_ts_ms(&version, &mut registry, index, 1, ctx(&mut scenario));
            return_shared(version);
            return_shared(registry);
        };
        next_tx(&mut scenario, ADMIN);
        {
            let version = version(&scenario);
            let mut registry = registry(&scenario);
            let clock = new_clock(&mut scenario);
            stake_pool::update_incentive_config<SUI>(
                &version,
                &mut registry,
                index,
                &clock,
                // incentive config
                option::some(PERIOD_INCENTIVE_AMOUNT),
                option::some(INCENTIVE_INTERVAL_TS_MS),
                option::some(vector[]),
                ctx(&mut scenario)
            );
            return_shared(version);
            return_shared(registry);
            clock.destroy_for_testing();
        };
        end(scenario);
    }

    #[test]
    public(package) fun test_stake() {
        let mut scenario = begin_test();
        let index = 0;
        test_add_incentive_token_<SUI>(&mut scenario, index);
        let incentive_amount = 1000_0000_00000;
        test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);

        let stake_amount = 1_0000_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount, CURRENT_TS_MS);
        end(scenario);
    }

    #[test]
    public(package) fun test_harvest_per_user_share() {
        let mut scenario = begin_test();
        let index = 0;
        test_add_incentive_token_<SUI>(&mut scenario, index);
        let incentive_amount = 1000_0000_00000;
        test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);

        next_tx(&mut scenario, USER_1);
        let stake_amount_1 = 1_0000_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_1, CURRENT_TS_MS);

        next_tx(&mut scenario, USER_1);
        let stake_amount_2 = 0_0100_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_2, CURRENT_TS_MS);

        next_tx(&mut scenario, USER_2);
        let stake_amount_3 = 0_2000_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_3, CURRENT_TS_MS);

        // USER_1 harvest user_share_id 0 within locked-up period
        next_tx(&mut scenario, USER_1);
        let harvest_ts_ms_0 = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS;
        let (harvest_balance_value, incentive_price_index_1)
            = test_harvest_per_user_share_<SUI>(&mut scenario, index, harvest_ts_ms_0);
        let estimated_value_1 = ((stake_amount_1 + stake_amount_2 as u128)
                            * (incentive_price_index_1 as u128)
                                / (multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128) as u64);
        assert!(harvest_balance_value == estimated_value_1, 0);

        // USER_1 harvest user_share_id 1 within locked-up period
        next_tx(&mut scenario, USER_1);
        let harvest_ts_ms_1 = CURRENT_TS_MS + 5 * INCENTIVE_INTERVAL_TS_MS;
        let (harvest_balance_value, incentive_price_index_2)
            = test_harvest_per_user_share_<SUI>(&mut scenario, index, harvest_ts_ms_1);
        let estimated_value_2 = ((stake_amount_1 + stake_amount_2 as u128)
                            * (incentive_price_index_2 - incentive_price_index_1 as u128)
                                / (multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128) as u64);
        assert!(harvest_balance_value == estimated_value_2, 0);

        end(scenario);
    }

    #[test]
    public(package) fun test_harvest_for_zero_balance() {
        let mut scenario = begin_test();
        let index = 0;
        test_add_incentive_token_<SUI>(&mut scenario, index);
        let incentive_amount = 1000_0000_00000;
        test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);

        next_tx(&mut scenario, USER_1);
        let stake_amount_1 = 1_0000_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_1, CURRENT_TS_MS);

        next_tx(&mut scenario, USER_1);
        let stake_amount_2 = 0_0100_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_2, CURRENT_TS_MS);

        next_tx(&mut scenario, USER_2);
        let stake_amount_3 = 0_2000_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_3, CURRENT_TS_MS);

        // USER_1 harvest within locked-up period
        next_tx(&mut scenario, USER_1);
        let harvest_ts_ms_0 = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS;
        let (harvest_balance_value, incentive_price_index_1)
            = test_harvest_per_user_share_<SUI>(&mut scenario, index, harvest_ts_ms_0);
        let estimated_value_1 = ((stake_amount_1 + stake_amount_2 as u128)
                            * (incentive_price_index_1 as u128)
                                / (multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128) as u64);
        assert!(harvest_balance_value == estimated_value_1, 0);

        // USER_1 harvest within locked-up period
        next_tx(&mut scenario, USER_1);
        let harvest_ts_ms_1 = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS + 1;
        let (harvest_balance_value, incentive_price_index_2)
            = test_harvest_per_user_share_<SUI>(&mut scenario, index, harvest_ts_ms_1);
        assert!(harvest_balance_value == 0, 0);
        assert!(incentive_price_index_2 == incentive_price_index_1, 0);

        end(scenario);
    }

    #[test]
    public(package) fun test_unstake_multiple_times() {
        let mut scenario = begin_test();
        let index = 0;
        test_add_incentive_token_<SUI>(&mut scenario, index);
        test_add_incentive_token_<TEST_TLP>(&mut scenario, index);

        let incentive_amount = 1000_0000_00000;
        test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);
        let incentive_amount = 1000_0000_00000;
        test_deposit_incentive_<TEST_TLP>(&mut scenario, index, incentive_amount);

        next_tx(&mut scenario, USER_1);
        let stake_amount_1 = 1_0000_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_1, CURRENT_TS_MS);

        next_tx(&mut scenario, USER_2);
        let stake_amount_2 = 0_0100_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_2, CURRENT_TS_MS);

        next_tx(&mut scenario, USER_2);
        test_snapshot_(&mut scenario, index, CURRENT_TS_MS + 1);

        next_tx(&mut scenario, USER_2);
        let stake_amount_3 = 0_3000_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_3, CURRENT_TS_MS + 1);

        let ts_ms = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS;
        next_tx(&mut scenario, USER_1);
        test_snapshot_(&mut scenario, index, ts_ms);
        next_tx(&mut scenario, USER_1);
        let (_harvest_balance_value, _incentive_price_index)
            = test_harvest_per_user_share_<SUI>(&mut scenario, index, ts_ms);
        next_tx(&mut scenario, USER_1);
        let (_harvest_balance_value, _incentive_price_index)
            = test_harvest_per_user_share_<TEST_TLP>(&mut scenario, index, ts_ms);
        next_tx(&mut scenario, USER_1);
        let stake_amount_4 = 1_0000_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_4, ts_ms); // stake at first incentive period
        next_tx(&mut scenario, USER_1);
        test_unsubscribe_<TEST_TLP>(&mut scenario, index, option::some(1_0000_00000), ts_ms);
        next_tx(&mut scenario, USER_1);
        test_unstake_<TEST_TLP>(&mut scenario, index, ts_ms);

        let unstake_ts_ms_0 = CURRENT_TS_MS + UNLOCK_COUNTDOWN_TS_MS;
        next_tx(&mut scenario, USER_2);
        test_snapshot_(&mut scenario, index, unstake_ts_ms_0);
        // unstake user_share_id = 1 (share = 0_0100_00000)
        next_tx(&mut scenario, USER_2);
        let (_harvest_balance_value, _incentive_price_index)
            = test_harvest_per_user_share_<SUI>(&mut scenario, index, unstake_ts_ms_0);
        next_tx(&mut scenario, USER_2);
        let (_harvest_balance_value, _incentive_price_index)
            = test_harvest_per_user_share_<TEST_TLP>(&mut scenario, index, unstake_ts_ms_0);
        next_tx(&mut scenario, USER_2);
        let unstake_user_2
            = test_unstake_<TEST_TLP>(&mut scenario, index, unstake_ts_ms_0);
        assert!(unstake_user_2 == 0, 1); // nothing happened due to no deactivating shares

        // unstake USER_1 all shares
        let unstake_ts_ms_1 = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS + UNLOCK_COUNTDOWN_TS_MS;
        next_tx(&mut scenario, USER_1);
        test_snapshot_(&mut scenario, index, unstake_ts_ms_1);
        next_tx(&mut scenario, USER_1);
        let (_harvest_balance_value, _incentive_price_index)
            = test_harvest_per_user_share_<SUI>(&mut scenario, index, unstake_ts_ms_1);
        next_tx(&mut scenario, USER_1);
        let (_harvest_balance_value, _incentive_price_index)
            = test_harvest_per_user_share_<TEST_TLP>(&mut scenario, index, unstake_ts_ms_1);
        next_tx(&mut scenario, USER_1);
        let unstake_user_1 = test_unstake_<TEST_TLP>(&mut scenario, index, unstake_ts_ms_1);
        assert!(unstake_user_1 == 1_0000_00000, 1);

        let ts_ms = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS * 5 + UNLOCK_COUNTDOWN_TS_MS;
        test_auto_compound_<TEST_TLP>(&mut scenario, index, ts_ms);

        next_tx(&mut scenario, USER_1);
        test_snapshot_(&mut scenario, index, ts_ms);
        next_tx(&mut scenario, USER_1);
        let (_harvest_balance_value, _incentive_price_index)
            = test_harvest_per_user_share_<SUI>(&mut scenario, index, ts_ms);
        next_tx(&mut scenario, USER_1);
        let (_harvest_balance_value, _incentive_price_index)
            = test_harvest_per_user_share_<TEST_TLP>(&mut scenario, index, ts_ms);
        next_tx(&mut scenario, USER_1);
        test_unsubscribe_<TEST_TLP>(&mut scenario, index, option::none(), ts_ms);

        let ts_ms = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS * 5 + UNLOCK_COUNTDOWN_TS_MS * 2;
        next_tx(&mut scenario, USER_1);
        test_snapshot_(&mut scenario, index, ts_ms);
        next_tx(&mut scenario, USER_1);
        let (_harvest_balance_value, _incentive_price_index)
            = test_harvest_per_user_share_<SUI>(&mut scenario, index, ts_ms);
        next_tx(&mut scenario, USER_1);
        let (_harvest_balance_value, _incentive_price_index)
            = test_harvest_per_user_share_<TEST_TLP>(&mut scenario, index, ts_ms);
        next_tx(&mut scenario, USER_1);
        test_unstake_<TEST_TLP>(&mut scenario, index, ts_ms);

        end(scenario);
    }

    #[test]
    public(package) fun test_get_user_shares() {
        let mut scenario = begin_test();
        let index = 0;
        test_add_incentive_token_<SUI>(&mut scenario, index);

        let incentive_amount = 1000_0000_00000;
        test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);

        next_tx(&mut scenario, USER_1);
        let stake_amount_1 = 1_0000_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_1, CURRENT_TS_MS);

        next_tx(&mut scenario, USER_1);
        let stake_amount_2 = 0_0100_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_2, CURRENT_TS_MS);

        next_tx(&mut scenario, USER_2);
        let stake_amount_3 = 0_0800_00000;
        test_stake_<TEST_TLP>(&mut scenario, index, stake_amount_3, CURRENT_TS_MS);

        test_add_incentive_token_<BABE>(&mut scenario, index);

        next_tx(&mut scenario, ADMIN);
        {
            let registry = registry(&scenario);
            let result = stake_pool::get_user_shares(&registry, index, USER_1);
            return_shared(registry);
            assert!(result.length() > 0, 0);
        };

        next_tx(&mut scenario, USER_1);
        {
            let registry = registry(&scenario);
            let result = stake_pool::get_user_shares(&registry, index, USER_1);
            return_shared(registry);
            assert!(result.length() > 0, 0);
        };

        next_tx(&mut scenario, USER_2);
        {
            let registry = registry(&scenario);
            let result = stake_pool::get_user_shares_by_user_share_id(&registry, index, 1);
            return_shared(registry);
            assert!(result.length() > 0, 0);
        };

        end(scenario);
    }
}


#[test_only]
module typus_stake_pool::test_tlp {
    use sui::coin;
    use sui::url;

    public struct TEST_TLP has drop {}

    const Decimals: u8 = 9;
    // Due to the package size, we changed it to a test_only function
    #[test_only]
    fun init(witness: TEST_TLP, ctx: &mut TxContext) {
        let (treasury_cap, coin_metadata) = coin::create_currency(
            witness,
            Decimals,
            b"TEST_TLP",
            b"Typus Perp Test TLP Token",
            b"Typus Perp Test TLP Token Description", // TODO: update description
            option::some(url::new_unsafe_from_bytes(b"https://raw.githubusercontent.com/Typus-Lab/typus-asset/main/assets/BABE.svg")),
            ctx
        );

        transfer::public_freeze_object(coin_metadata);
        transfer::public_transfer(treasury_cap, ctx.sender());
    }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(TEST_TLP {}, ctx);
    }
}

#[test_only]
module typus_stake_pool::babe {
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