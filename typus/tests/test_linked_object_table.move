#[test_only]
extend module typus::linked_object_table {
    use sui::test_scenario;
    use sui::bag::{Self, Bag};

    #[test]
    fun test_linked_object_table() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let table = new<u64, Bag>(test_scenario::ctx(&mut scenario));
        let ctx = test_scenario::ctx(&mut scenario);
        assert!(table.length() == 0, 0);
        assert!(table.is_empty(), 0);
        assert!(!table.contains(0), 0);
        table.destroy_empty();
        let mut table = new<u64, Bag>(ctx);
        assert!(table.front() == option::none());
        assert!(table.back() == option::none());
        table.push_back(0, bag::new(ctx));
        table.borrow(0);
        table.borrow_mut(0);
        let (_, v) = table.pop_back();
        v.destroy_empty();
        table.push_front(0, bag::new(ctx));
        let (_, v) = table.pop_front();
        v.destroy_empty();
        table.push_back(1, bag::new(ctx));
        table.push_back(2, bag::new(ctx));
        table.push_front(3, bag::new(ctx));
        table.push_front(4, bag::new(ctx));
        assert!(table.prev(2) == option::some(1));
        assert!(table.next(2) == option::none());
        let (_, v) = table.pop_back();
        v.destroy_empty();
        let (_, v) = table.pop_back();
        v.destroy_empty();
        let (_, v) = table.pop_front();
        v.destroy_empty();
        let (_, v) = table.pop_front();
        v.destroy_empty();
        table.destroy_empty();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ETableIsEmpty)]
    fun test_pop_front_table_is_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let ctx = test_scenario::ctx(&mut scenario);
        let mut table = new<u64, Bag>(ctx);
        let (_, v) = table.pop_front();
        v.destroy_empty();
        table.destroy_empty();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ETableIsEmpty)]
    fun test_pop_back_table_is_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let ctx = test_scenario::ctx(&mut scenario);
        let mut table = new<u64, Bag>(ctx);
        let (_, v) = table.pop_back();
        v.destroy_empty();
        table.destroy_empty();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ETableNotEmpty)]
    fun test_destroy_empty_table_not_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let ctx = test_scenario::ctx(&mut scenario);
        let mut table = new<u64, Bag>(ctx);
        table.push_back(0, bag::new(ctx));
        table.destroy_empty();
        test_scenario::end(scenario);
    }

}