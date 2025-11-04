#[test_only]
extend module typus_framework::big_vector {
    use sui::test_scenario;

    #[test]
    #[expected_failure(abort_code = E_NOT_EMPTY)]
    fun test_big_vector_destroy_empty_not_empty_error() {
        let mut scenario = test_scenario::begin(@0xAAAA);

        let tmp = 10;
        let mut big_vector = new<u64>(3, test_scenario::ctx(&mut scenario));
        assert!(big_vector.slice_size() == 3, 0);
        assert!(big_vector.slice_id(0) == 1, 0);
        assert!(big_vector.is_empty(), 0);
        let mut count = 1;
        while (count <= tmp) {
            push_back(&mut big_vector, count);
            count = count + 1;
        };

        destroy_empty(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_big_vector_push_pop() {
        let mut scenario = test_scenario::begin(@0xAAAA);

        let tmp = 10;
        let mut big_vector = new<u64>(3, test_scenario::ctx(&mut scenario));
        assert!(big_vector.slice_size() == 3, 0);
        assert!(big_vector.slice_id(0) == 1, 0);
        assert!(big_vector.is_empty(), 0);
        let mut count = 1;
        while (count <= tmp) {
            push_back(&mut big_vector, count);
            count = count + 1;
        };
        // [1, 2, 3], [4, 5, 6], [7, 8, 9], [10]
        assert!(big_vector.borrow_slice(4) == vector[10], 0);
        assert!(big_vector.borrow_slice_mut(1) == vector[1, 2, 3], 0);
        assert!(big_vector.borrow(9) == 10, 0);
        assert!(big_vector.borrow_mut(0) == 1, 0);
        assert!(slice_count(&big_vector) == 4, 0);
        assert!(pop_back(&mut big_vector) == 10, 0);
        assert!(slice_count(&big_vector) == 3, 0);
        assert!(pop_back(&mut big_vector) == 9, 0);
        assert!(slice_count(&big_vector) == 3, 0);
        assert!(pop_back(&mut big_vector) == 8, 0);
        assert!(slice_count(&big_vector) == 3, 0);
        assert!(pop_back(&mut big_vector) == 7, 0);
        assert!(slice_count(&big_vector) == 2, 0);
        assert!(pop_back(&mut big_vector) == 6, 0);
        assert!(slice_count(&big_vector) == 2, 0);
        assert!(pop_back(&mut big_vector) == 5, 0);
        assert!(slice_count(&big_vector) == 2, 0);
        assert!(pop_back(&mut big_vector) == 4, 0);
        assert!(slice_count(&big_vector) == 1, 0);
        assert!(pop_back(&mut big_vector) == 3, 0);
        assert!(slice_count(&big_vector) == 1, 0);
        assert!(pop_back(&mut big_vector) == 2, 0);
        assert!(slice_count(&big_vector) == 1, 0);
        assert!(pop_back(&mut big_vector) == 1, 0);

        destroy_empty(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_big_vector_swap_remove() {
        let mut scenario = test_scenario::begin(@0xAAAA);

        let tmp = 10;
        let mut big_vector = new<u64>(3, test_scenario::ctx(&mut scenario));
        let mut count = 1;
        while (count <= tmp) {
            push_back(&mut big_vector, count);
            count = count + 1;
        };
        // [1, 2, 3], [4, 5, 6], [7, 8, 9], [10]
        swap_remove(&mut big_vector, 5);
        // [1, 2, 3], [4, 5, 10], [7, 8, 9]
        swap_remove(&mut big_vector, 8);
        // [1, 2, 3], [4, 5, 10], [7, 8]
        assert!(slice_count(&big_vector) == 3, 0);
        assert!(pop_back(&mut big_vector) == 8, 0);
        assert!(slice_count(&big_vector) == 3, 0);
        assert!(pop_back(&mut big_vector) == 7, 0);
        assert!(slice_count(&big_vector) == 2, 0);
        assert!(pop_back(&mut big_vector) == 10, 0);
        assert!(slice_count(&big_vector) == 2, 0);
        assert!(pop_back(&mut big_vector) == 5, 0);
        assert!(slice_count(&big_vector) == 2, 0);
        assert!(pop_back(&mut big_vector) == 4, 0);
        assert!(slice_count(&big_vector) == 1, 0);
        assert!(pop_back(&mut big_vector) == 3, 0);
        assert!(slice_count(&big_vector) == 1, 0);
        assert!(pop_back(&mut big_vector) == 2, 0);
        assert!(slice_count(&big_vector) == 1, 0);
        assert!(pop_back(&mut big_vector) == 1, 0);

        destroy_empty(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_big_vector_remove() {
        let mut scenario = test_scenario::begin(@0xAAAA);

        let tmp = 10;
        let mut big_vector = new<u64>(3, test_scenario::ctx(&mut scenario));
        let mut count = 1;
        while (count <= tmp) {
            push_back(&mut big_vector, count);
            count = count + 1;
        };
        // [1, 2, 3], [4, 5, 6], [7, 8, 9], [10]
        remove(&mut big_vector, 5);
        // [1, 2, 3], [4, 5, 7], [8, 9, 10]
        assert!(slice_count(&big_vector) == 3, 0);
        assert!(pop_back(&mut big_vector) == 10, 0);
        assert!(slice_count(&big_vector) == 3, 0);
        assert!(pop_back(&mut big_vector) == 9, 0);
        assert!(slice_count(&big_vector) == 3, 0);
        assert!(pop_back(&mut big_vector) == 8, 0);
        assert!(slice_count(&big_vector) == 2, 0);
        assert!(pop_back(&mut big_vector) == 7, 0);
        assert!(slice_count(&big_vector) == 2, 0);
        assert!(pop_back(&mut big_vector) == 5, 0);
        assert!(slice_count(&big_vector) == 2, 0);
        assert!(pop_back(&mut big_vector) == 4, 0);
        assert!(slice_count(&big_vector) == 1, 0);
        assert!(pop_back(&mut big_vector) == 3, 0);
        assert!(slice_count(&big_vector) == 1, 0);
        assert!(pop_back(&mut big_vector) == 2, 0);
        assert!(slice_count(&big_vector) == 1, 0);
        assert!(pop_back(&mut big_vector) == 1, 0);

        destroy_empty(big_vector);
        test_scenario::end(scenario);
    }
}