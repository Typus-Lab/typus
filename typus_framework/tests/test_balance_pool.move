#[test_only]
extend module typus_framework::balance_pool {
    use sui::test_scenario;

    #[test_only]
    public struct TEST has drop {}

    #[test]
    fun test_balance_pool() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.add_authorized_user(@0xA);
        balance_pool.remove_authorized_user(@0xA);
        balance_pool.authority();
        balance_pool.put<sui::sui::SUI>(balance::create_for_testing(1));
        balance_pool.put<TEST>(balance::create_for_testing(1));
        balance_pool.put<sui::sui::SUI>(balance::create_for_testing(1));
        balance_pool.put<TEST>(balance::create_for_testing(1));
        balance_pool.take<sui::sui::SUI>(option::some(1), scenario.ctx());
        balance_pool.take<TEST>(option::some(1), scenario.ctx());
        balance_pool.take<TEST>(option::none(), scenario.ctx());
        balance_pool.take<sui::sui::SUI>(option::none(), scenario.ctx());
        balance_pool.put<sui::sui::SUI>(balance::create_for_testing(1));
        balance_pool.put<TEST>(balance::create_for_testing(1));
        balance_pool.put<sui::sui::SUI>(balance::create_for_testing(1));
        balance_pool.put<TEST>(balance::create_for_testing(1));
        balance_pool.send<sui::sui::SUI>(option::some(1), scenario.sender(), scenario.ctx());
        balance_pool.send<TEST>(option::some(1), scenario.sender(), scenario.ctx());
        balance_pool.send<TEST>(option::none(), scenario.sender(), scenario.ctx());
        balance_pool.send<sui::sui::SUI>(option::none(), scenario.sender(), scenario.ctx());
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = E_INVALID_TOKEN, location = Self)]
    fun test_take_invalid_token() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.take<sui::sui::SUI>(option::none(), scenario.ctx());
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = E_INVALID_TOKEN, location = Self)]
    fun test_send_invalid_token() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.send<sui::sui::SUI>(option::none(), scenario.sender(), scenario.ctx());
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_shared_balance_pool_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.new_shared_balance_pool(vector[], vector[], scenario.ctx());
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }
    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_add_shared_authorized_user_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.add_shared_authorized_user(vector[], @0xABCD);
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }
    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_remove_shared_authorized_user_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.remove_shared_authorized_user(vector[], @0xABCD);
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }
    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_put_shared_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.put_shared(vector[], balance::zero<sui::sui::SUI>());
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }
    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_take_shared_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.take_shared<sui::sui::SUI>(vector[], option::none(), scenario.ctx());
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }
    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_send_shared_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.send_shared<sui::sui::SUI>(vector[], option::none(), @0xABCD, scenario.ctx());
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }
    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_shared_authority_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.shared_authority(vector[]);
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }
    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_drop_shared_balance_pool_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut balance_pool = new(vector[@0xABCD], scenario.ctx());
        balance_pool.drop_shared_balance_pool(vector[], scenario.ctx());
        balance_pool.drop_balance_pool(scenario.ctx());
        scenario.end();
    }
}