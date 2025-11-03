#[deprecated]
module typus_framework::navi {
    use lending_core::account::AccountCap;
    use sui::balance::Balance;
    use sui::clock::Clock;
    use typus_framework::balance_pool::BalancePool;
    use typus_framework::vault::DepositVault;

    #[deprecated]
    public fun new_navi_account_cap(_ctx: &mut TxContext): AccountCap { abort 0 }
    #[deprecated]
    public fun deposit<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _navi_account_cap: &AccountCap,
        _storage: &mut lending_core::storage::Storage,
        _pool: &mut lending_core::pool::Pool<TOKEN>,
        _asset: u8,
        _incentive_v1: &mut lending_core::incentive::Incentive,
        _incentive_v2: &mut lending_core::incentive_v2::Incentive,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun withdraw<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<TOKEN>,
        _distribute: bool,
        _navi_account_cap: &AccountCap,
        _oracle_config: &mut oracle::config::OracleConfig,
        _price_oracle: &mut oracle::oracle::PriceOracle,
        _supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        _pyth_price_info: &pyth::price_info::PriceInfoObject,
        _feed_address: address,
        _storage: &mut lending_core::storage::Storage,
        _pool: &mut lending_core::pool::Pool<TOKEN>,
        _asset: u8,
        _incentive_v1: &mut lending_core::incentive::Incentive,
        _incentive_v2: &mut lending_core::incentive_v2::Incentive,
        _clock: &Clock,
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun reward<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _distribute: bool,
        _navi_account_cap: &AccountCap,
        _storage: &mut lending_core::storage::Storage,
        _incentive_funds_pool: &mut lending_core::incentive_v2::IncentiveFundsPool<TOKEN>,
        _asset: u8,
        _option: u8,
        _incentive_v2: &mut lending_core::incentive_v2::Incentive,
        _clock: &Clock,
    ): vector<u64> { abort 0 }
}

#[test_only]
extend module typus_framework::navi {
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