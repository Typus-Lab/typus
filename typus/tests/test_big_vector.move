#[test_only]
extend module typus::big_vector {

    use sui::test_scenario::{Self, Scenario};
    use sui::bcs;

    #[test]
    fun test_bv_push_pop_remove() {
        let (scenario, mut bv) = new_scenario();

        // []
        let mut count = 0;
        while (count < 5) {
            bv.pop_back<u64>();
            count = count + 1;
        };
        assert_result(
            &bv,
            bcs::to_bytes(&vector<vector<u8>>[]),
        );

        // [(0xA, 1), (0xB, 2)], [(0xC, 3)]
        bv.push_back(1);
        bv.push_back(2);
        bv.push_back(3);
        assert_result(&bv, bcs::to_bytes(&vector[
            bcs::to_bytes(&1),
            bcs::to_bytes(&2),
            bcs::to_bytes(&3),
        ]));

        // [(0xA, 1)]
        let mut count = 0;
        while (count < 2) {
            bv.pop_back<u64>();
            count = count + 1;
        };
        assert_result(&bv, bcs::to_bytes(&vector[
            bcs::to_bytes(&1),
        ]));

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        bv.push_back(4);
        bv.push_back(5);
        assert_result(&bv, bcs::to_bytes(&vector[
            bcs::to_bytes(&1),
            bcs::to_bytes(&4),
            bcs::to_bytes(&5),
        ]));


        do_mut!<u64>(&mut bv, |value| {
            // std::debug::print(&key);
            // std::debug::print(value);
            *value = *value + *value;
        });
        bv.remove<u64>(1);
        bv.pop_back<u64>();
        bv.pop_back<u64>();
        bv.destroy_empty();
        test_scenario::end(scenario);
    }

    #[test]
    fun test_bv_borrow() {
        let (scenario, mut bv) = new_scenario();

        // [(0xA, 1), (0xB, 2)], [(0xC, 3), (0xD, 4)], [(0xE, 5)]
        let v = bv.borrow<u64>(2);
        assert!(v == &3, 0);

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        let v = bv.borrow_mut<u64>(2);
        *v = *v * *v;
        assert_result(&bv, bcs::to_bytes(&vector[
            bcs::to_bytes(&1),
            bcs::to_bytes(&2),
            bcs::to_bytes(&9),
            bcs::to_bytes(&4),
            bcs::to_bytes(&5),
        ]));

        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test]
    fun test_bv_swap_remove() {
        let (scenario, mut bv) = new_scenario();

        // [(0xA, 1), (0xB, 2)], [(0xE, 5), (0xD, 4)]
        bv.swap_remove<u64>(2);
        assert_result(&bv, bcs::to_bytes(&vector[
            bcs::to_bytes(&1),
            bcs::to_bytes(&2),
            bcs::to_bytes(&5),
            bcs::to_bytes(&4),
        ]));

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        bv.swap_remove<u64>(1);
        assert_result(&bv, bcs::to_bytes(&vector[
            bcs::to_bytes(&1),
            bcs::to_bytes(&4),
            bcs::to_bytes(&5),
        ]));

        // [(0xA, 1), (0xD, 4)]
        bv.swap_remove<u64>(2);
        assert_result(&bv, bcs::to_bytes(&vector[
            bcs::to_bytes(&1),
            bcs::to_bytes(&4),
        ]));

        assert!(bv.slice_idx() == 0, 0);
        let slice = bv.borrow_slice<u64>(0);
        assert!(slice.get_slice_idx() == 0, 0);
        assert!(slice.get_slice_length() == 2, 0);

        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test_only]
    fun new_scenario(): (Scenario, BigVector) {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        // [(0xA, 1), (0xB, 2)], [(0xC, 3), (0xD, 4)], [(0xE, 5)]
        bv.push_back(1);
        bv.push_back(2);
        bv.push_back(3);
        bv.push_back(4);
        bv.push_back(5);
        assert_result(&bv, bcs::to_bytes(&vector[
            bcs::to_bytes(&1),
            bcs::to_bytes(&2),
            bcs::to_bytes(&3),
            bcs::to_bytes(&4),
            bcs::to_bytes(&5),
        ]));

        (scenario, bv)
    }

    #[test_only]
    fun assert_result(
        big_vector: &BigVector,
        expected_result: vector<u8>,
    ) {
        let mut result = vector[];
        do_ref!<u64>(big_vector, |value| {
            // std::debug::print(&key);
            // std::debug::print(value);
            result.push_back(bcs::to_bytes(value));
        });
        assert!(expected_result == bcs::to_bytes(&result), 0);
    }

    #[test_only]
    macro fun do_ref<$V>($bv: &BigVector, $f: |&$V|) {
        let bv = $bv;
        let length = bv.length();
        if (length > 0) {
            let slice_size = (bv.slice_size() as u64);
            let mut slice = bv.borrow_slice(0);
            length.do!(|i| {
                let value = slice.borrow_from_slice(i % slice_size);
                $f(value);
                // jump to next slice
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    slice = bv.borrow_slice((i + 1) / slice_size);
                };
            });
        };
    }

    #[test_only]
    macro fun do_mut<$V>($bv: &mut BigVector, $f: |&mut $V|) {
        let bv = $bv;
        let length = bv.length();
        if (length > 0) {
            let slice_size = (bv.slice_size() as u64);
            let mut slice = bv.borrow_slice_mut(0);
            length.do!(|i| {
                let value = slice.borrow_from_slice_mut(i % slice_size);
                $f(value);
                // jump to next slice
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    slice = bv.borrow_slice_mut((i + 1) / slice_size);
                };
            });
        };
    }

    #[test, expected_failure(abort_code = EInvalidSliceSize)]
    fun test_new_zero_slice_size_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let bv = new<u64>(0, test_scenario::ctx(&mut scenario));
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidSliceSize)]
    fun test_new_invalid_slice_size_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let bv = new<u64>(CMaxSliceSize + 1, test_scenario::ctx(&mut scenario));
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIsEmpty)]
    fun test_pop_back_is_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.pop_back<u64>();
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIndexOutOfBounds)]
    fun test_borrow_index_out_of_bounds_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.borrow<u64>(0);
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIndexOutOfBounds)]
    fun test_borrow_mut_index_out_of_bounds_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.borrow_mut<u64>(0);
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIndexOutOfBounds)]
    fun test_borrow_slice_index_out_of_bounds_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.borrow_slice<u64>(1);
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIsEmpty)]
    fun test_borrow_slice_is_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.borrow_slice<u64>(0);
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIndexOutOfBounds)]
    fun test_borrow_slice_mut_index_out_of_bounds_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.borrow_slice_mut<u64>(1);
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIsEmpty)]
    fun test_borrow_slice_mut_is_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.borrow_slice_mut<u64>(0);
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIndexOutOfBounds)]
    fun test_borrow_from_slice_index_out_of_bounds_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.push_back(0);
        let slice = bv.borrow_slice<u64>(0);
        slice.borrow_from_slice<u64>(1);
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIndexOutOfBounds)]
    fun test_borrow_from_slice_mut_index_out_of_bounds_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.push_back(0);
        let slice = bv.borrow_slice_mut<u64>(0);
        slice.borrow_from_slice_mut<u64>(1);
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EIndexOutOfBounds)]
    fun test_remove_index_out_of_bounds_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.remove<u64>(0);
        bv.drop<u64>();
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = ENotEmpty)]
    fun test_destroy_empty_not_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bv = new<u64>(2, test_scenario::ctx(&mut scenario));
        bv.push_back(0);
        bv.destroy_empty();
        test_scenario::end(scenario);
    }
}