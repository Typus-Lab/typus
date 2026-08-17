#[test_only]
extend module typus::utility {

    use sui::balance;
    use sui::test_scenario;

    public struct TestToken has drop {}

    #[test]
    fun test_transfer_coins() {
        let mut scenario = test_scenario::begin(@0xABCD);
        transfer_coins<TestToken>(vector[], @0xABCD);
        transfer_coins<TestToken>(vector[coin::zero(test_scenario::ctx(&mut scenario))], @0xABCD);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_transfer_balance() {
        let mut scenario = test_scenario::begin(@0xABCD);
        transfer_balance<TestToken>(balance::zero(), @0xABCD, test_scenario::ctx(&mut scenario));
        transfer_balance<TestToken>(balance::create_for_testing(10), @0xABCD, test_scenario::ctx(&mut scenario));
        test_scenario::end(scenario);
    }

    #[test]
    fun test_transfer_balance_opt() {
        let mut scenario = test_scenario::begin(@0xABCD);
        transfer_balance_opt<TestToken>(option::none(), @0xABCD, test_scenario::ctx(&mut scenario));
        transfer_balance_opt<TestToken>(option::some(balance::zero()), @0xABCD, test_scenario::ctx(&mut scenario));
        transfer_balance_opt<TestToken>(option::some(balance::create_for_testing(10)), @0xABCD, test_scenario::ctx(&mut scenario));
        test_scenario::end(scenario);
    }

    #[test]
    fun test_basis_point_value() {
        assert!(basis_point_value(123, 2000) == 24, 0);
    }

    #[test]
    fun test_u64_vector_value() {
        let mut data = vector[];
        set_u64_vector_value(&mut data, 1, 30);
        increase_u64_vector_value(&mut data, 0, 10);
        decrease_u64_vector_value(&mut data, 1, 10);
        assert!(get_u64_vector_value(&data, 0) == 10);
        assert!(get_u64_vector_value(&data, 1) == 20);
        assert!(get_u64_vector_value(&data, 2) == 0);
    }

    #[test]
    fun test_multiplier() {
        assert!(multiplier(10) == 10000000000, 0);
    }
}