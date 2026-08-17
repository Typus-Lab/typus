#[test_only]
extend module typus::linked_set {
    use sui::test_scenario;

    #[test]
    fun test_linked_set() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let linked_set = new<u64>(test_scenario::ctx(&mut scenario));
        assert!(linked_set.length() == 0, 0);
        assert!(linked_set.is_empty(), 0);
        assert!(!linked_set.contains(0), 0);
        linked_set.destroy_empty();
        let mut linked_set = new<u64>(test_scenario::ctx(&mut scenario));
        assert!(linked_set.front() == option::none());
        assert!(linked_set.back() == option::none());
        linked_set.push_back(0);
        linked_set.pop_back();
        linked_set.push_front(0);
        linked_set.pop_front();
        linked_set.push_back(1);
        linked_set.push_back(2);
        linked_set.push_front(3);
        linked_set.push_front(4);
        assert!(linked_set.prev(2) == option::some(1));
        assert!(linked_set.next(2) == option::none());
        linked_set.pop_back();
        linked_set.pop_back();
        linked_set.pop_front();
        linked_set.pop_front();
        linked_set.drop();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ESetIsEmpty)]
    fun test_pop_front_set_is_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut linked_set = new<u64>(test_scenario::ctx(&mut scenario));
        linked_set.pop_front();
        linked_set.drop();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ESetIsEmpty)]
    fun test_pop_back_set_is_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut linked_set = new<u64>(test_scenario::ctx(&mut scenario));
        linked_set.pop_back();
        linked_set.drop();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ESetNotEmpty)]
    fun test_destroy_empty_set_not_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut linked_set = new<u64>(test_scenario::ctx(&mut scenario));
        linked_set.push_back(0);
        linked_set.destroy_empty();
        test_scenario::end(scenario);
    }
}
