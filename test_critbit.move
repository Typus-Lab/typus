#[test_only]
extend module typus::critbit {
    #[test]
    public fun test_critbit() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        insert_leaf(&mut critbit_tree, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
        insert_leaf(&mut critbit_tree, 0xFFFFFFFFFFFFFFFE, 0xFFFFFFFFFFFFFFFE);
        remove_min_leaf(&mut critbit_tree);
        remove_min_leaf(&mut critbit_tree);
        assert!(count_leading_zeros(0) == 128, 0);
        critbit_tree.destroy_empty();
        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        assert!(find_closest_key(&critbit_tree, 0) == 0, 0);
        assert!(insert_leaf(&mut critbit_tree, 0, 0) == 0, 0);
        assert!(remove_leaf_by_index(&mut critbit_tree, 0) == 0, 0);
        assert!(insert_leaf(&mut critbit_tree, 0, 0) == 0, 0);
        assert!(insert_leaf(&mut critbit_tree, 1, 1) == 1, 0);
        assert!(insert_leaf(&mut critbit_tree, 2, 2) == 2, 0);
        assert!(insert_leaf(&mut critbit_tree, 3, 3) == 3, 0);
        assert!(remove_leaf_by_index(&mut critbit_tree, 1) == 1, 0);
        assert!(remove_leaf_by_index(&mut critbit_tree, 2) == 2, 0);
        assert!(remove_leaf_by_index(&mut critbit_tree, 3) == 3, 0);
        assert!(remove_leaf_by_index(&mut critbit_tree, 0) == 0, 0);
        // insert_leaf
        if (!has_leaf(&critbit_tree, 11111)) {
            assert!(insert_leaf(&mut critbit_tree, 11111, 11111) == 0, 0);
            assert!(find_closest_key(&critbit_tree, 0) == 11111, 0);
        };
        if (!has_leaf(&critbit_tree, 22222)) {
            assert!(insert_leaf(&mut critbit_tree, 22222, 22222) == 1, 0);
        };
        assert!(insert_leaf(&mut critbit_tree, 4, 4) == 2, 0);
        assert!(insert_leaf(&mut critbit_tree, 200, 200) == 3, 0);
        assert!(insert_leaf(&mut critbit_tree, 400, 400) == 4, 0);
        // min_leaf
        let (key, index) = min_leaf(&critbit_tree);
        assert!(index == 2, 0);
        assert!(key == 4, 0);
        assert!(borrow_leaf_by_index(&critbit_tree, index) == 4, 0);
        // max_leaf
        let (key, index) = max_leaf(&critbit_tree);
        assert!(index == 1, 0);
        assert!(key == 22222, 0);
        assert!(borrow_leaf_by_index(&critbit_tree, index) == 22222, 0);
        // previous_leaf
        let (key, index) = previous_leaf(&critbit_tree, 4);
        assert!(index == PARTITION_INDEX, 0);
        assert!(key == 0, 0);
        let (key, index) = previous_leaf(&critbit_tree, 400);
        assert!(index == 3, 0);
        assert!(key == 200, 0);
        assert!(borrow_leaf_by_index(&critbit_tree, index) == 200, 0);
        // next_leaf
        let (key, index) = next_leaf(&critbit_tree, 22222);
        assert!(index == PARTITION_INDEX, 0);
        assert!(key == 0, 0);
        let (key, index) = next_leaf(&critbit_tree, 200);
        assert!(index == 4, 0);
        assert!(key == 400, 0);
        assert!(borrow_leaf_by_index(&critbit_tree, index) == 400, 0);
        // remove_leaf_by_key
        if (has_leaf(&critbit_tree, 4)) {
            assert!(remove_leaf_by_key(&mut critbit_tree, 4) == 4, 0);
        };
        if (has_leaf(&critbit_tree, 200)) {
            assert!(remove_leaf_by_key(&mut critbit_tree, 200) == 200, 0);
        };
        // insert_leaf
        assert!(insert_leaf(&mut critbit_tree, 50, 50) == 5, 0);
        assert!(insert_leaf(&mut critbit_tree, 300, 300) == 6, 0);
        assert!(insert_leaf(&mut critbit_tree, 100, 100) == 7, 0);
        assert!(insert_leaf(&mut critbit_tree, 3, 3) == 8, 0);
        assert!(insert_leaf(&mut critbit_tree, 1, 1) == 9, 0);
        // min_leaf
        let (key, index) = min_leaf(&critbit_tree);
        assert!(index == 9, 0);
        assert!(key == 1, 0);
        assert!(borrow_leaf_by_index(&critbit_tree, index) == 1, 0);
        // remove_leaf_by_index
        if (has_index(&critbit_tree, 8)){
            assert!(remove_leaf_by_index(&mut critbit_tree, 8) == 3, 0);
        };
        if (has_index(&critbit_tree, 9)){
            assert!(remove_leaf_by_index(&mut critbit_tree, 9) == 1, 0);
        };
        // insert_leaf
        assert!(insert_leaf(&mut critbit_tree, 0, 0) == 10, 0);
        assert!(insert_leaf(&mut critbit_tree, 33, 33) == 11, 0);
        // min_leaf
        let (key, index) = min_leaf(&critbit_tree);
        assert!(index == 10, 0);
        assert!(key == 0, 0);
        assert!(borrow_leaf_by_index(&critbit_tree, index) == 0, 0);
        assert!(borrow_leaf_by_key(&critbit_tree, key) == 0, 0);
        assert!(borrow_mut_leaf_by_index(&mut critbit_tree, index) == 0, 0);
        assert!(borrow_mut_leaf_by_key(&mut critbit_tree, key) == 0, 0);
        // size
        assert!(size(&critbit_tree) == 8, 0);
        // remove_min_leaf
        assert!(remove_min_leaf(&mut critbit_tree) == 0, 0);
        // remove_max_leaf
        assert!(remove_max_leaf(&mut critbit_tree) == 22222, 0);
        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    public fun test_min_leaf_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        min_leaf(&critbit_tree);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    public fun test_max_leaf_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        max_leaf(&critbit_tree);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    public fun test_previous_leaf_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        previous_leaf(&critbit_tree, 0);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    public fun test_next_leaf_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        next_leaf(&critbit_tree, 0);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EExceedCapacity)]
    public fun test_insert_leaf_max_capacity_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        critbit_tree.next_leaf_index = MAX_CAPACITY - 1;
        insert_leaf(&mut critbit_tree, 0, 0);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ETreeNotEmpty)]
    public fun test_insert_leaf_tree_not_empty_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        insert_leaf(&mut critbit_tree, 0, 0);
        critbit_tree.root = PARTITION_INDEX;
        insert_leaf(&mut critbit_tree, 0, 0);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EKeyAlreadyExist)]
    public fun test_insert_leaf_key_exist_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        insert_leaf(&mut critbit_tree, 0, 0);
        insert_leaf(&mut critbit_tree, 0, 0);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIndexOutOfRange)]
    public fun test_remove_leaf_by_index_index_out_of_range_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        assert!(insert_leaf(&mut critbit_tree, 0, 0) == 0, 0);
        critbit_tree.leaves.add(1, Leaf {
            key: 1,
            value: 1,
            parent: PARTITION_INDEX,
        });
        remove_leaf_by_index(&mut critbit_tree, 0);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ELeafNotExist)]
    public fun test_remove_leaf_by_key_leaf_not_exist_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        remove_leaf_by_key(&mut critbit_tree, 0);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ELeafNotExist)]
    public fun test_borrow_leaf_by_key_leaf_not_exist_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        borrow_leaf_by_key(&critbit_tree, 0);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ELeafNotExist)]
    public fun test_borrow_mut_leaf_by_key_leaf_not_exist_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        borrow_mut_leaf_by_key(&mut critbit_tree, 0);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ETreeNotEmpty)]
    public fun test_destroy_empty_tree_not_empty_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        insert_leaf(&mut critbit_tree, 0, 0);
        critbit_tree.destroy_empty();

        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ENullParent)]
    public fun test_update_child_null_parent_error() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        insert_leaf(&mut critbit_tree, 0, 0);
        insert_leaf(&mut critbit_tree, 1, 1);
        update_child(&mut critbit_tree, 0, PARTITION_INDEX, true);
        update_child(&mut critbit_tree, PARTITION_INDEX, 0, true);

        drop(critbit_tree);
        test_scenario::end(scenario);
    }
}