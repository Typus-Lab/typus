#[test_only]
extend module typus_framework::navi {
    use sui::balance;
    use sui::clock;
    use sui::test_scenario;

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_navi_account_cap_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let account_cap = new_navi_account_cap(scenario.ctx());
        transfer::public_transfer(account_cap, scenario.sender());
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_deposit_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        lending_core::global::init_protocol(&mut scenario);
        scenario.next_tx(@0xA);
        let mut clock = clock::create_for_testing(scenario.ctx());
        let current_timestamp = 1700006400000;
        clock::set_for_testing(&mut clock, current_timestamp);
        lending_core::base::initial_protocol(&mut scenario, &clock);
        lending_core::incentive_v2_test::initial_incentive_v2_v3(&mut scenario);
        scenario.next_tx(@0xA);
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<lending_core::sui_test::SUI_TEST, lending_core::sui_test::SUI_TEST>(0, 0, b"test".to_string(), scenario.ctx());
        let account_cap = lending_core::lending::create_account(scenario.ctx());
        let mut storage = scenario.take_shared<lending_core::storage::Storage>();
        let mut pool = scenario.take_shared<lending_core::pool::Pool<lending_core::sui_test::SUI_TEST>>();
        let mut incentive_v1 = scenario.take_shared<lending_core::incentive::Incentive>();
        let mut incentive_v2 = scenario.take_shared<lending_core::incentive_v2::Incentive>();
        deposit(
            &mut deposit_vault,
            &account_cap,
            &mut storage,
            &mut pool,
            0,
            &mut incentive_v1,
            &mut incentive_v2,
            &clock,
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<lending_core::sui_test::SUI_TEST, lending_core::sui_test::SUI_TEST>();
        transfer::public_transfer(account_cap, scenario.sender());
        test_scenario::return_shared(storage);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(incentive_v1);
        test_scenario::return_shared(incentive_v2);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        lending_core::global::init_protocol(&mut scenario);
        scenario.next_tx(@0xA);
        let mut clock = clock::create_for_testing(scenario.ctx());
        let current_timestamp = 1700006400000;
        clock::set_for_testing(&mut clock, current_timestamp);
        lending_core::base::initial_protocol(&mut scenario, &clock);
        lending_core::incentive_v2_test::initial_incentive_v2_v3(&mut scenario);
        scenario.next_tx(@0xA);
        SupraOracle::SupraSValueFeed::test_init(scenario.ctx());
        scenario.next_tx(@0xA);
        oracle::oracle_global::init_protocol_without_provider(&mut scenario);
        scenario.next_tx(@0xA);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xA], scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<lending_core::sui_test::SUI_TEST, lending_core::sui_test::SUI_TEST>(0, 0, b"test".to_string(), scenario.ctx());
        let mut balance = balance::zero();
        let account_cap = lending_core::lending::create_account(scenario.ctx());
        let mut oracle_config = scenario.take_shared();
        let mut price_oracle = scenario.take_shared();
        let supra_oracle_holder = scenario.take_shared();
        let price_info = pyth::price_info::new_price_info(
            1663680747,
            1663074349,
            pyth::price_feed::new(
                pyth::price_identifier::from_byte_vec(x"c6c75c89f14810ec1c54c03ab8f1864a4c4032791f05747f560faec380a695d1"),
                pyth::price::new(pyth::i64::new(1557, false), 7, pyth::i64::new(5, true), 1663680740),
                pyth::price::new(pyth::i64::new(1500, false), 3, pyth::i64::new(5, true), 1663680740),
            ),
        );
        let pyth_price_info = pyth::price_info::new_price_info_object_for_test(price_info, scenario.ctx());
        let mut storage = scenario.take_shared();
        let mut pool = scenario.take_shared<lending_core::pool::Pool<lending_core::sui_test::SUI_TEST>>();
        let mut incentive_v1 = scenario.take_shared<lending_core::incentive::Incentive>();
        let mut incentive_v2 = scenario.take_shared<lending_core::incentive_v2::Incentive>();
        withdraw(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            true,
            &account_cap,
            &mut oracle_config,
            &mut price_oracle,
            &supra_oracle_holder,
            &pyth_price_info,
            @0xABCD,
            &mut storage,
            &mut pool,
            0,
            &mut incentive_v1,
            &mut incentive_v2,
            &clock,
        );
        fee_pool.drop_balance_pool(scenario.ctx());
        deposit_vault.drop_deposit_vault<lending_core::sui_test::SUI_TEST, lending_core::sui_test::SUI_TEST>();
        balance.destroy_zero();
        pyth_price_info.destroy();
        transfer::public_transfer(account_cap, scenario.sender());
        test_scenario::return_shared(oracle_config);
        test_scenario::return_shared(price_oracle);
        test_scenario::return_shared(supra_oracle_holder);
        test_scenario::return_shared(storage);
        test_scenario::return_shared(pool);
        test_scenario::return_shared(incentive_v1);
        test_scenario::return_shared(incentive_v2);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_reward_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        lending_core::global::init_protocol(&mut scenario);
        scenario.next_tx(@0xA);
        let mut clock = clock::create_for_testing(scenario.ctx());
        let current_timestamp = 1700006400000;
        clock::set_for_testing(&mut clock, current_timestamp);
        lending_core::base::initial_protocol(&mut scenario, &clock);
        lending_core::incentive_v2_test::initial_incentive_v2_v3(&mut scenario);
        scenario.next_tx(@0xA);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xA], scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<lending_core::sui_test::SUI_TEST, lending_core::sui_test::SUI_TEST>(0, 0, b"test".to_string(), scenario.ctx());
        let account_cap = lending_core::lending::create_account(scenario.ctx());
        let mut storage = scenario.take_shared<lending_core::storage::Storage>();
        let mut incentive_funds_pool = scenario.take_shared<lending_core::incentive_v2::IncentiveFundsPool<lending_core::usdt_test::USDT_TEST>>();
        let mut incentive_v2 = scenario.take_shared<lending_core::incentive_v2::Incentive>();
        reward(
            &mut fee_pool,
            &mut deposit_vault,
            true,
            &account_cap,
            &mut storage,
            &mut incentive_funds_pool,
            0,
            0,
            &mut incentive_v2,
            &clock,
        );
        fee_pool.drop_balance_pool(scenario.ctx());
        deposit_vault.drop_deposit_vault<lending_core::sui_test::SUI_TEST, lending_core::sui_test::SUI_TEST>();
        transfer::public_transfer(account_cap, scenario.sender());
        test_scenario::return_shared(storage);
        test_scenario::return_shared(incentive_funds_pool);
        test_scenario::return_shared(incentive_v2);
        clock.destroy_for_testing();
        scenario.end();
    }
}