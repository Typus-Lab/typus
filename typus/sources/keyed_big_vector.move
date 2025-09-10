// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
module typus::keyed_big_vector {
    use std::type_name::{Self, TypeName};

    use sui::dynamic_field;
    use sui::table;

    // ======== Constants ========

    const CMaxSliceAmount: u16 = 1000;
    const CMaxSliceSize: u32 = 262144;
    const SKeyIndexTable: vector<u8> = b"key_index_table";

    // ======== Errors ========

    fun duplicate_key(): u64 { abort 0 }
    fun index_out_of_bounds(): u64 { abort 0 }
    fun invalid_slice_size(): u64 { abort 0 }
    fun key_not_found(): u64 { abort 0 }
    fun max_slice_amount_reached(): u64 { abort 0 }
    fun not_empty(): u64 { abort 0 }

    // ======== Structs ========

    public struct KeyedBigVector has key, store {
        /// the ID of the KeyedBigVector
        id: UID,
        /// the key type of the KeyedBigVector
        key_type: TypeName,
        /// the element type of the KeyedBigVector
        value_type: TypeName,
        /// the latest index of the Slice in the KeyedBigVector
        slice_idx: u16,
        /// the max size of each Slice in the KeyedBigVector
        slice_size: u32,
        /// the length of the KeyedBigVector
        length: u64,
    }

    public struct Slice<K: copy + drop + store, V: store> has store, drop {
        /// the index of the Slice
        idx: u16,
        /// the vector which stores elements
        vector: vector<Element<K, V>>,
    }

    public struct Element<K: copy + drop + store, V: store> has store, drop {
        key: K,
        value: V,
    }

    // ======== Functions ========

    /// create KeyedBigVector
    public fun new<K: copy + drop + store, V: store>(slice_size: u32, ctx: &mut TxContext): KeyedBigVector {
        // slice_size * sizeof(Element) should be below the object size limit 256000 bytes.
        assert!(slice_size > 0 && slice_size <= CMaxSliceSize, invalid_slice_size());
        let mut id = object::new(ctx);
        dynamic_field::add(&mut id, SKeyIndexTable.to_string(), table::new<K, u64>(ctx));

        KeyedBigVector {
            id,
            key_type: type_name::get<K>(),
            value_type: type_name::get<V>(),
            slice_idx: 0,
            slice_size,
            length: 0,
        }
    }

    /// return the latest index of the Slice in the KeyedBigVector
    public fun slice_idx(kbv: &KeyedBigVector): u16 {
        kbv.slice_idx
    }

    /// return the max size of each Slice in the KeyedBigVector
    public fun slice_size(kbv: &KeyedBigVector): u32 {
        kbv.slice_size
    }

    /// return the length of the KeyedBigVector
    public fun length(kbv: &KeyedBigVector): u64 {
        kbv.length
    }

    /// return true if the KeyedBigVector is empty
    public fun is_empty(kbv: &KeyedBigVector): bool {
        kbv.length == 0
    }

    /// return true if there is a value associated with the key `key: Key` in the KeyedBigVector
    public fun contains<K: copy + drop + store>(kbv: &KeyedBigVector, key: K): bool {
        table::contains<K, u64>(dynamic_field::borrow(&kbv.id, SKeyIndexTable.to_string()), key)
    }

    /// return the index of the Slice
    public fun get_slice_idx<K: copy + drop + store, V: store>(slice: &Slice<K, V>): u16 {
        slice.idx
    }

    /// return the length of the element in the Slice
    public fun get_slice_length<K: copy + drop + store, V: store>(slice: &Slice<K, V>): u64 {
        slice.vector.length()
    }

    /// push a new element at the end of the KeyedBigVector
    public fun push_back<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, key: K, value: V) {
        assert!(!kbv.contains(key), duplicate_key());
        let element = Element { key, value };
        if (kbv.is_empty() || kbv.length() % (kbv.slice_size as u64) == 0) {
            kbv.slice_idx = (kbv.length() / (kbv.slice_size as u64) as u16);
            assert!(kbv.slice_idx < CMaxSliceAmount, max_slice_amount_reached());
            let new_slice = Slice {
                idx: kbv.slice_idx,
                vector: vector[element]
            };
            dynamic_field::add(&mut kbv.id, kbv.slice_idx, new_slice);
        }
        else {
            let slice = borrow_slice_mut_(&mut kbv.id, kbv.slice_idx);
            slice.vector.push_back(element);
        };
        table::add(dynamic_field::borrow_mut(&mut kbv.id, SKeyIndexTable.to_string()), key, kbv.length);
        kbv.length = kbv.length + 1;
    }

    /// pop an element from the end of the KeyedBigVector
    public fun pop_back<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector): (K, V) {
        assert!(!kbv.is_empty(), index_out_of_bounds());

        let slice = borrow_slice_mut_(&mut kbv.id, kbv.slice_idx);
        let Element { key, value } = slice.vector.pop_back();
        kbv.trim_slice<K, V>();
        table::remove<K, u64>(dynamic_field::borrow_mut(&mut kbv.id, SKeyIndexTable.to_string()), key);
        kbv.length = kbv.length - 1;

        (key, value)
    }

    /// borrow a slice from the KeyedBigVector
    public fun borrow_slice<K: copy + drop + store, V: store>(kbv: &KeyedBigVector, slice_idx: u16): &Slice<K, V> {
        assert!(slice_idx <= kbv.slice_idx, index_out_of_bounds());

        borrow_slice_(&kbv.id, slice_idx)
    }
    fun borrow_slice_<K: copy + drop + store, V: store>(id: &UID, slice_idx: u16): &Slice<K, V> {
        dynamic_field::borrow(id, slice_idx)
    }

    /// borrow a mutable slice from the KeyedBigVector
    public fun borrow_slice_mut<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, slice_idx: u16): &mut Slice<K, V> {
        assert!(slice_idx <= kbv.slice_idx, index_out_of_bounds());

        borrow_slice_mut_(&mut kbv.id, slice_idx)
    }
    fun borrow_slice_mut_<K: copy + drop + store, V: store>(id: &mut UID, slice_idx: u16): &mut Slice<K, V> {
        dynamic_field::borrow_mut(id, slice_idx)
    }

    /// borrow an element at index i from the KeyedBigVector
    public fun borrow<K: copy + drop + store, V: store>(kbv: &KeyedBigVector, i: u64): (K, &V) {
        assert!(i < kbv.length, index_out_of_bounds());

        borrow_(kbv, i)
    }
    fun borrow_<K: copy + drop + store, V: store>(kbv: &KeyedBigVector, i: u64): (K, &V) {
        let slice = borrow_slice_(&kbv.id, (i / (kbv.slice_size as u64) as u16));
        let element = &slice.vector[i % (kbv.slice_size as u64)];

        (element.key, &element.value)
    }

    /// borrow a mutable element at index i from the KeyedBigVector
    public fun borrow_mut<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, i: u64): (K, &mut V) {
        assert!(i < kbv.length, index_out_of_bounds());

        borrow_mut_(kbv, i)
    }
    fun borrow_mut_<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, i: u64): (K, &mut V) {
        let slice = borrow_slice_mut_(&mut kbv.id, (i / (kbv.slice_size as u64) as u16));
        let element = &mut slice.vector[i % (kbv.slice_size as u64)];

        (element.key, &mut element.value)
    }

    #[syntax(index)]
    /// borrow an element by key from the KeyedBigVector
    public fun borrow_by_key<K: copy + drop + store, V: store>(kbv: &KeyedBigVector, key: K): &V {
        assert!(kbv.contains(key), key_not_found());

        let i = *table::borrow<K, u64>(dynamic_field::borrow(&kbv.id, SKeyIndexTable.to_string()), key);
        let (_, v) = borrow_<K, V>(kbv, i);

        v
    }

    #[syntax(index)]
    /// borrow a mutable element by key from the KeyedBigVector
    public fun borrow_by_key_mut<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, key: K): &mut V {
        assert!(kbv.contains(key), key_not_found());

        let i = *table::borrow<K, u64>(dynamic_field::borrow(&kbv.id, SKeyIndexTable.to_string()), key);
        let (_, v) = borrow_mut_<K, V>(kbv, i);

        v
    }

    /// borrow an element at index i from the KeyedBigVector
    public fun borrow_from_slice<K: copy + drop + store, V: store>(slice: &Slice<K, V>, i: u64): (K, &V) {
        assert!(i < slice.vector.length(), index_out_of_bounds());

        let element = &slice.vector[i];

        (element.key, &element.value)
    }

    /// borrow a mutable element at index i from the KeyedBigVector
    public fun borrow_from_slice_mut<K: copy + drop + store, V: store>(slice: &mut Slice<K, V>, i: u64): (K, &mut V) {
        assert!(i < slice.vector.length(), index_out_of_bounds());

        let element = &mut slice.vector[i];

        (element.key, &mut element.value)
    }

    /// swap and pop the element at index i with the last element
    public fun swap_remove<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, i: u64): (K, V) {
        assert!(i < kbv.length, index_out_of_bounds());

        swap_remove_(kbv, i)
    }
    fun swap_remove_<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, i: u64): (K, V) {
        let (key, value) = pop_back(kbv);
        if (i == kbv.length()) {
            (key, value)
        } else {
            table::add(dynamic_field::borrow_mut(&mut kbv.id, SKeyIndexTable.to_string()), key, i);
            let slice = borrow_slice_mut_(&mut kbv.id, (i / (kbv.slice_size as u64) as u16));
            slice.vector.push_back(Element { key, value });
            let Element { key, value } = slice.vector.swap_remove(i % (kbv.slice_size as u64));
            table::remove<K, u64>(dynamic_field::borrow_mut(&mut kbv.id, SKeyIndexTable.to_string()), key);
            (key, value)
        }
    }

    /// swap and pop the element at index i with the last element
    public fun swap_remove_by_key<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, key: K): V {
        assert!(kbv.contains(key), key_not_found());

        let i = *table::borrow<K, u64>(dynamic_field::borrow(&kbv.id, SKeyIndexTable.to_string()), key);
        let (_, v) = swap_remove_<K, V>(kbv, i);

        v
    }

    /// drop KeyedBigVector, abort if it's not empty
    public fun destroy_empty(kbv: KeyedBigVector) {
        let KeyedBigVector {
            id,
            key_type: _,
            value_type: _,
            slice_idx: _,
            slice_size: _,
            length,
        } = kbv;
        assert!(length == 0, not_empty());
        id.delete();
    }

    /// drop KeyedBigVector
    public fun drop(kbv: KeyedBigVector) {
        let KeyedBigVector {
            id,
            key_type: _,
            value_type: _,
            slice_idx: _,
            slice_size: _,
            length: _,
        } = kbv;
        id.delete();
    }

    /// drop KeyedBigVector completely
    public fun completely_drop<K: copy + drop + store, V: drop + store>(kbv: KeyedBigVector) {
        let KeyedBigVector {
            mut id,
            key_type: _,
            value_type: _,
            slice_idx,
            slice_size: _,
            length,
        } = kbv;
        if (length > 0) {
            (slice_idx + 1).do!(|i| {
                dynamic_field::remove<u16, Slice<K, V>>(&mut id, slice_idx - i);
            });
        };
        id.delete();
    }

    /// remove empty slice after element removal
    fun trim_slice<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector) {
        let slice = borrow_slice_(&kbv.id, kbv.slice_idx);
        if (slice.vector.is_empty<Element<K, V>>()) {
            let Slice {
                idx: _,
                vector: v,
            } = dynamic_field::remove(&mut kbv.id, kbv.slice_idx);
            v.destroy_empty<Element<K, V>>();
            if (kbv.slice_idx > 0) {
                kbv.slice_idx = kbv.slice_idx - 1;
            };
        };
    }

    public macro fun do_ref<$K, $V>($kbv: &KeyedBigVector, $f: |$K, &$V|) {
        let kbv = $kbv;
        let length = kbv.length();
        if (length > 0) {
            let slice_size = (kbv.slice_size() as u64);
            let mut slice = kbv.borrow_slice(0);
            length.do!(|i| {
                let (key, value) = slice.borrow_from_slice(i % slice_size);
                $f(key, value);
                // jump to next slice
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    slice = kbv.borrow_slice(((i + 1) / slice_size) as u16);
                };
            });
        };
    }

    public macro fun do_mut<$K, $V>($kbv: &mut KeyedBigVector, $f: |$K, &mut $V|) {
        let kbv = $kbv;
        let length = kbv.length();
        if (length > 0) {
            let slice_size = (kbv.slice_size() as u64);
            let mut slice = kbv.borrow_slice_mut(0);
            length.do!(|i| {
                let (key, value) = slice.borrow_from_slice_mut(i % slice_size);
                $f(key, value);
                // jump to next slice
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    slice = kbv.borrow_slice_mut(((i + 1) / slice_size) as u16);
                };
            });
        };
    }
}

#[test_only]
module typus::test_keyed_big_vector {
    use std::bcs;

    use sui::test_scenario::{Self, Scenario};

    use typus::keyed_big_vector::{Self, KeyedBigVector};

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

        kbv.completely_drop<address, u64>();
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

        kbv.completely_drop<address, u64>();
        test_scenario::end(scenario);
    }

    #[test_only]
    fun new_scenario(): (Scenario, KeyedBigVector) {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut kbv = keyed_big_vector::new<address, u64>(2, test_scenario::ctx(&mut scenario));
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