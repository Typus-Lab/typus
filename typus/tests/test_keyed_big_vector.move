#[test_only]
extend module typus::keyed_big_vector {
    use std::bcs;
    use sui::test_scenario::{Self, Scenario};

    #[test]
    fun test_kbv_do() {
        let (scenario, mut kbv) = new_scenario();

        // [(0xA, 2), (0xB, 3)], [(0xC, 4), (0xD, 5)], [(0xE, 6)]
        kbv.do_mut!<address, u64>(|_, value| {
            *value = *value + 1;
        });
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&3)],
            vector[bcs::to_bytes(&@0xC), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&5)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&6)],
        ]));

        // [(0xA, 4), (0xB, 4)], [(0xC, 8), (0xD, 6)], [(0xE, 12)]
        kbv.do_mut!<address, u64>(|_, value| {
            if (*value % 2 == 0) {
                *value = *value * 2;
            } else {
                *value = *value + 1;
            };
        });
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xC), bcs::to_bytes(&8)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&6)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&12)],
        ]));

        kbv.completely_drop<address, u64>();
        test_scenario::end(scenario);
    }

    #[test]
    fun test_kbv_push_pop() {
        let (scenario, mut kbv) = new_scenario();

        // []
        let mut count = 0;
        while (count < 5) {
            kbv.pop_back<address, u64>();
            count = count + 1;
        };
        assert_result(
            &kbv,
            bcs::to_bytes(&vector<vector<u8>>[]),
        );

        // [(0xA, 1), (0xB, 2)], [(0xC, 3)]
        kbv.push_back(@0xA, 1);
        kbv.push_back(@0xB, 2);
        kbv.push_back(@0xC, 3);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xC), bcs::to_bytes(&3)],
        ]));

        // [(0xA, 1)]
        let mut count = 0;
        while (count < 2) {
            kbv.pop_back<address, u64>();
            count = count + 1;
        };
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
        ]));

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        kbv.push_back(@0xD, 4);
        kbv.push_back(@0xE, 5);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        kbv.completely_drop<address, u64>();
        test_scenario::end(scenario);
    }

    #[test]
    fun test_kbv_borrow() {
        let (scenario, mut kbv) = new_scenario();

        // [(0xA, 1), (0xB, 2)], [(0xC, 3), (0xD, 4)], [(0xE, 5)]
        let (k, v) = kbv.borrow<address, u64>(2);
        assert!(k == @0xC && v ==&3, 0);

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        let (_, v) = kbv.borrow_mut<address, u64>(2);
        *v = *v * *v;
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xC), bcs::to_bytes(&9)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        kbv.completely_drop<address, u64>();
        test_scenario::end(scenario);
    }

    #[test]
    fun test_kbv_swap_remove() {
        let (scenario, mut kbv) = new_scenario();

        // [(0xA, 1), (0xB, 2)], [(0xE, 5), (0xD, 4)]
        kbv.swap_remove<address, u64>(2);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
        ]));

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        kbv.swap_remove<address, u64>(1);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        kbv.drop();
        test_scenario::end(scenario);
    }

    #[test]
    fun test_kbv_borrow_by_key() {
        let (scenario, mut kbv) = new_scenario();

        // [(0xA, 1), (0xB, 2)], [(0xC, 3), (0xD, 4)], [(0xE, 5)]
        assert!(kbv.borrow_by_key(@0xC) == 3, 0);

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        let v: &mut u64 = kbv.borrow_by_key_mut(@0xC);
        *v = *v * *v;
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xC), bcs::to_bytes(&9)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        kbv.completely_drop<address, u64>();
        test_scenario::end(scenario);
    }

    #[test]
    fun test_kbv_swap_remove_by_key() {
        let (scenario, mut kbv) = new_scenario();

        // [(0xA, 1), (0xB, 2)], [(0xE, 5), (0xD, 4)]
        kbv.swap_remove_by_key<address, u64>(@0xC);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
        ]));

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        kbv.swap_remove_by_key<address, u64>(@0xB);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        // [(0xA, 1), (0xD, 4)]
        kbv.swap_remove_by_key<address, u64>(@0xE);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
        ]));

        assert!(kbv.slice_idx() == 0, 0);
        let slice = kbv.borrow_slice<address, u64>(0);
        assert!(slice.get_slice_idx() == 0, 0);
        assert!(slice.get_slice_length() == 2, 0);

        kbv.pop_back<address, u64>();
        kbv.pop_back<address, u64>();
        kbv.destroy_empty();
        test_scenario::end(scenario);
    }

    #[test_only]
    fun new_scenario(): (Scenario, KeyedBigVector) {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut kbv = new<address, u64>(2, test_scenario::ctx(&mut scenario));
        // [(0xA, 1), (0xB, 2)], [(0xC, 3), (0xD, 4)], [(0xE, 5)]
        kbv.push_back(@0xA, 1);
        kbv.push_back(@0xB, 2);
        kbv.push_back(@0xC, 3);
        kbv.push_back(@0xD, 4);
        kbv.push_back(@0xE, 5);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xC), bcs::to_bytes(&3)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        (scenario, kbv)
    }

    #[test_only]
    fun assert_result(
        keyed_big_vector: &KeyedBigVector,
        expected_result: vector<u8>,
    ) {
        let mut result = vector[];
        keyed_big_vector.do_ref!<address, u64>(|key, value| {
            // std::debug::print(&key);
            // std::debug::print(value);
            result.push_back(vector[bcs::to_bytes(&key), bcs::to_bytes(value)]);
        });
        assert!(expected_result == bcs::to_bytes(&result), 0);
    }
}