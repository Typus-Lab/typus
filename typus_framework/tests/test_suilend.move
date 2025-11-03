#[test_only]
extend module typus_framework::suilend {
    use sui::balance;
    use sui::clock;
    use sui::object_table;
    use sui::test_scenario::{Self, Scenario};

    #[test_only]
    fun init_suilend_tests(scenario: &mut Scenario): (LendingMarket<MAIN_POOL>, ObligationOwnerCap<MAIN_POOL>) {
        let obligation = suilend::obligation::mock_for_testing(
            sui::object::id_from_address(@0xABCD),
            vector[],
            vector[],
            suilend::decimal::from(0),
            suilend::decimal::from(0),
            suilend::decimal::from(0),
            suilend::decimal::from(0),
            suilend::decimal::from(0),
            suilend::decimal::from(0),
            suilend::decimal::from(0),
            true,
            vector[],
            suilend::decimal::from(0),
            true,
            scenario.ctx(),
        );
        let obligation_id = sui::object::id(&obligation);
        let mut obligations = object_table::new(scenario.ctx());
        obligations.add(obligation_id, obligation);
        let lending_market = suilend::lending_market::mock_for_testing(
            vector[],
            obligations,
            @0xABCD,
            suilend::decimal::from(0),
            suilend::decimal::from(0),
            scenario.ctx(),
        );
        let obligation_owner_cap = suilend::lending_market::new_obligation_owner_cap_for_testing(
            &lending_market,
            obligation_id,
            scenario.ctx(),
        );

        (lending_market, obligation_owner_cap)
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_suilend_obligation_owner_cap_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let (mut lending_market, obligation_owner_cap) = init_suilend_tests(&mut scenario);
        let new_obligation_owner_cap = new_suilend_obligation_owner_cap(&mut lending_market, scenario.ctx());
        transfer::public_transfer(lending_market, scenario.sender());
        transfer::public_transfer(obligation_owner_cap, scenario.sender());
        transfer::public_transfer(new_obligation_owner_cap, scenario.sender());
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_deposit_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let (mut lending_market, obligation_owner_cap) = init_suilend_tests(&mut scenario);
        deposit<sui::sui::SUI>(
            &mut deposit_vault,
            &mut lending_market,
            0,
            &obligation_owner_cap,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(lending_market, scenario.sender());
        transfer::public_transfer(obligation_owner_cap, scenario.sender());
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        let (mut lending_market, obligation_owner_cap) = init_suilend_tests(&mut scenario);
        withdraw<sui::sui::SUI, sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &mut lending_market,
            0,
            0,
            &obligation_owner_cap,
            true,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(lending_market, scenario.sender());
        transfer::public_transfer(obligation_owner_cap, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        balance.destroy_zero();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_without_reward_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        let (mut lending_market, obligation_owner_cap) = init_suilend_tests(&mut scenario);
        withdraw_without_reward<sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &mut lending_market,
            0,
            &obligation_owner_cap,
            true,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(lending_market, scenario.sender());
        transfer::public_transfer(obligation_owner_cap, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        balance.destroy_zero();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_reward_without_reward_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let (mut lending_market, obligation_owner_cap) = init_suilend_tests(&mut scenario);
        reward<sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut lending_market,
            0,
            0,
            &obligation_owner_cap,
            true,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(lending_market, scenario.sender());
        transfer::public_transfer(obligation_owner_cap, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        clock.destroy_for_testing();
        scenario.end();
    }
}