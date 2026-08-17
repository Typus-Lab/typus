#[test_only]
extend module typus_framework::scallop {
    use sui::balance;
    use sui::clock;
    use sui::coin;
    use sui::test_scenario;

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_spool_account_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut spool = spool::spool::test_new<sui::sui::SUI>(scenario.ctx());
        let account = new_spool_account<sui::sui::SUI>(&mut spool, &clock, scenario.ctx());
        transfer::public_transfer(account, scenario.sender());
        spool.test_drop();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_deposit_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut spool = spool::spool::test_new<sui::sui::SUI>(scenario.ctx());
        let mut account = spool::spool_account::test_new(&spool, scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        deposit<sui::sui::SUI>(
            &mut deposit_vault,
            &version,
            &mut market,
            &mut spool,
            &mut account,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(account, scenario.sender());
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        spool.test_drop();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut spool = spool::spool::test_new<sui::sui::SUI>(scenario.ctx());
        let mut account = spool::spool_account::test_new(&spool, scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut rewards_pool = spool::rewards_pool::test_new(&spool, scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        withdraw<sui::sui::SUI, sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &version,
            &mut market,
            &mut spool,
            &mut rewards_pool,
            &mut account,
            true,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(account, scenario.sender());
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        spool.test_drop();
        rewards_pool.test_drop();
        balance.destroy_zero();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_xxx_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut spool = spool::spool::test_new<sui::sui::SUI>(scenario.ctx());
        let mut account = spool::spool_account::test_new(&spool, scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut rewards_pool = spool::rewards_pool::test_new(&spool, scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        withdraw_xxx<sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &version,
            &mut market,
            &mut spool,
            &mut rewards_pool,
            &mut account,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(account, scenario.sender());
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        spool.test_drop();
        rewards_pool.test_drop();
        balance.destroy_zero();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_xyy_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut spool = spool::spool::test_new<sui::sui::SUI>(scenario.ctx());
        let mut account = spool::spool_account::test_new(&spool, scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut rewards_pool = spool::rewards_pool::test_new(&spool, scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        withdraw_xyy<sui::sui::SUI, sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &version,
            &mut market,
            &mut spool,
            &mut rewards_pool,
            &mut account,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(account, scenario.sender());
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        spool.test_drop();
        rewards_pool.test_drop();
        balance.destroy_zero();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_xyx_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut spool = spool::spool::test_new<sui::sui::SUI>(scenario.ctx());
        let mut account = spool::spool_account::test_new(&spool, scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut rewards_pool = spool::rewards_pool::test_new(&spool, scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        withdraw_xyx<sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &version,
            &mut market,
            &mut spool,
            &mut rewards_pool,
            &mut account,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(account, scenario.sender());
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        spool.test_drop();
        rewards_pool.test_drop();
        balance.destroy_zero();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_xyz_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut spool = spool::spool::test_new<sui::sui::SUI>(scenario.ctx());
        let mut account = spool::spool_account::test_new(&spool, scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut rewards_pool = spool::rewards_pool::test_new(&spool, scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        withdraw_xyz<sui::sui::SUI, sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &version,
            &mut market,
            &mut spool,
            &mut rewards_pool,
            &mut account,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(account, scenario.sender());
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        spool.test_drop();
        rewards_pool.test_drop();
        balance.destroy_zero();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_additional_lending_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut spool = spool::spool::test_new<sui::sui::SUI>(scenario.ctx());
        let mut account = spool::spool_account::test_new(&spool, scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut rewards_pool = spool::rewards_pool::test_new(&spool, scenario.ctx());
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        withdraw_additional_lending<sui::sui::SUI, sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &version,
            &mut market,
            &mut spool,
            &mut rewards_pool,
            &mut account,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(account, scenario.sender());
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        spool.test_drop();
        rewards_pool.test_drop();
        balance.destroy_zero();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_deposit_basic_lending_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let (coin, _) = deposit_basic_lending<sui::sui::SUI>(
            &mut deposit_vault,
            &version,
            &mut market,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        coin.burn_for_testing();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_basic_lending_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        withdraw_basic_lending<sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &version,
            &mut market,
            coin::zero(scenario.ctx()),
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        balance.destroy_zero();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_basic_lending_xy_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        withdraw_basic_lending_xy<sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &version,
            &mut market,
            coin::zero(scenario.ctx()),
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        balance.destroy_zero();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_basic_lending_v2_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        protocol::app::init_t(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let version = protocol::version::create_for_testing(scenario.ctx());
        let mut market = scenario.take_shared<protocol::market::Market>();
        let mut deposit_vault = typus_framework::vault::new_deposit_vault<sui::sui::SUI, sui::sui::SUI>(0, 0, b"test".to_string(), scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut balance = balance::zero();
        withdraw_basic_lending_v2<sui::sui::SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            &mut balance,
            &version,
            &mut market,
            coin::zero(scenario.ctx()),
            true,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(version, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        balance.destroy_zero();
        test_scenario::return_shared(market);
        clock.destroy_for_testing();
        scenario.end();
    }
}