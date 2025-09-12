// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module implements a `KeyedBigVector`, a data structure that combines the features of a `BigVector`
/// and a `Table`. It allows for both indexed and keyed access to a large number of elements by storing
/// them in slices, while maintaining a mapping from keys to indices in a `Table`.
module typus::keyed_big_vector {
    use std::type_name::{Self, TypeName};
    use std::vector;

    use sui::dynamic_field;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::TxContext;

    // ======== Constants ========

    /// The maximum number of slices allowed in a KeyedBigVector.
    const CMaxSliceAmount: u16 = 1000;
    /// The maximum size of a slice.
    const CMaxSliceSize: u32 = 262144;
    /// The key for the dynamic field that stores the key-to-index table.
    const SKeyIndexTable: vector<u8> = b"key_index_table";

    // ======== Errors ========

    /// Error for a duplicate key.
    fun duplicate_key(): u64 { abort 0 }
    /// Error for an out-of-bounds index.
    fun index_out_of_bounds(): u64 { abort 0 }
    /// Error for an invalid slice size.
    fun invalid_slice_size(): u64 { abort 0 }
    /// Error when a key is not found.
    fun key_not_found(): u64 { abort 0 }
    /// Error when the maximum number of slices is reached.
    fun max_slice_amount_reached(): u64 { abort 0 }
    /// Error when trying to destroy a non-empty KeyedBigVector.
    fun not_empty(): u64 { abort 0 }

    // ======== Structs ========

    /// A data structure that allows for both indexed and keyed access to a large number of elements.
    public struct KeyedBigVector has key, store {
        /// The unique identifier of the KeyedBigVector object.
        id: UID,
        /// The type name of the keys.
        key_type: TypeName,
        /// The type name of the values.
        value_type: TypeName,
        /// The index of the latest slice.
        slice_idx: u16,
        /// The maximum size of each slice.
        slice_size: u32,
        /// The total number of elements in the KeyedBigVector.
        length: u64,
    }

    /// A slice of the KeyedBigVector, containing a vector of elements.
    public struct Slice<K: copy + drop + store, V: store> has store, drop {
        /// The index of the slice.
        idx: u16,
        /// The vector that stores the elements.
        vector: vector<Element<K, V>>,
    }

    /// An element in the KeyedBigVector, containing a key-value pair.
    public struct Element<K: copy + drop + store, V: store> has store, drop {
        /// The key of the element.
        key: K,
        /// The value of the element.
        value: V,
    }

    // ======== Functions ========

    /// Creates a new `KeyedBigVector`.
    /// The `slice_size` determines the maximum number of elements in each slice.
    public fun new<K: copy + drop + store, V: store>(slice_size: u32, ctx: &mut TxContext): KeyedBigVector {
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

    /// Returns the index of the latest slice in the KeyedBigVector.
    public fun slice_idx(kbv: &KeyedBigVector): u16 {
        kbv.slice_idx
    }

    /// Returns the maximum size of each slice in the KeyedBigVector.
    public fun slice_size(kbv: &KeyedBigVector): u32 {
        kbv.slice_size
    }

    /// Returns the total number of elements in the KeyedBigVector.
    public fun length(kbv: &KeyedBigVector): u64 {
        kbv.length
    }

    /// Returns `true` if the KeyedBigVector is empty.
    public fun is_empty(kbv: &KeyedBigVector): bool {
        kbv.length == 0
    }

    /// Returns `true` if there is a value associated with the key `key` in the KeyedBigVector.
    public fun contains<K: copy + drop + store>(kbv: &KeyedBigVector, key: K): bool {
        table::contains<K, u64>(dynamic_field::borrow(&kbv.id, SKeyIndexTable.to_string()), key)
    }

    /// Returns the index of the slice.
    public fun get_slice_idx<K: copy + drop + store, V: store>(slice: &Slice<K, V>): u16 {
        slice.idx
    }

    /// Returns the number of elements in the slice.
    public fun get_slice_length<K: copy + drop + store, V: store>(slice: &Slice<K, V>): u64 {
        vector::length(&slice.vector)
    }

    /// Pushes a new element to the end of the KeyedBigVector.
    /// Aborts if the key already exists or if the maximum number of slices is reached.
    public fun push_back<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, key: K, value: V) {
        assert!(!contains(kbv, key), duplicate_key());
        let element = Element { key, value };
        if (is_empty(kbv) || length(kbv) % (slice_size(kbv) as u64) == 0) {
            kbv.slice_idx = (length(kbv) / (slice_size(kbv) as u64) as u16);
            assert!(kbv.slice_idx < CMaxSliceAmount, max_slice_amount_reached());
            let new_slice = Slice {
                idx: kbv.slice_idx,
                vector: vector[element]
            };
            dynamic_field::add(&mut kbv.id, kbv.slice_idx, new_slice);
        }
        else {
            let slice = borrow_slice_mut_(kbv.id_mut(), kbv.slice_idx);
            vector::push_back(&mut slice.vector, element);
        };
        table::add(dynamic_field::borrow_mut(&mut kbv.id, SKeyIndexTable.to_string()), key, kbv.length);
        kbv.length = kbv.length + 1;
    }

    /// Pops an element from the end of the KeyedBigVector and returns its key and value.
    /// Aborts if the KeyedBigVector is empty.
    public fun pop_back<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector): (K, V) {
        assert!(!is_empty(kbv), index_out_of_bounds());

        let slice = borrow_slice_mut_(kbv.id_mut(), kbv.slice_idx);
        let Element { key, value } = vector::pop_back(&mut slice.vector);
        trim_slice<K, V>(kbv);
        table::remove<K, u64>(dynamic_field::borrow_mut(&mut kbv.id, SKeyIndexTable.to_string()), key);
        kbv.length = kbv.length - 1;

        (key, value)
    }

    /// Borrows a slice from the KeyedBigVector at `slice_idx`.
    public fun borrow_slice<K: copy + drop + store, V: store>(kbv: &KeyedBigVector, slice_idx: u16): &Slice<K, V> {
        assert!(slice_idx <= kbv.slice_idx, index_out_of_bounds());

        borrow_slice_(&kbv.id, slice_idx)
    }
    fun borrow_slice_<K: copy + drop + store, V: store>(id: &UID, slice_idx: u16): &Slice<K, V> {
        dynamic_field::borrow(id, slice_idx)
    }

    /// Borrows a mutable slice from the KeyedBigVector at `slice_idx`.
    public fun borrow_slice_mut<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, slice_idx: u16): &mut Slice<K, V> {
        assert!(slice_idx <= kbv.slice_idx, index_out_of_bounds());

        borrow_slice_mut_(kbv.id_mut(), slice_idx)
    }
    fun borrow_slice_mut_<K: copy + drop + store, V: store>(id: &mut UID, slice_idx: u16): &mut Slice<K, V> {
        dynamic_field::borrow_mut(id, slice_idx)
    }

    /// Borrows an element at index `i` from the KeyedBigVector.
    public fun borrow<K: copy + drop + store, V: store>(kbv: &KeyedBigVector, i: u64): (K, &V) {
        assert!(i < kbv.length, index_out_of_bounds());

        borrow_(kbv, i)
    }
    fun borrow_<K: copy + drop + store, V: store>(kbv: &KeyedBigVector, i: u64): (K, &V) {
        let slice = borrow_slice_(&kbv.id, (i / (kbv.slice_size as u64) as u16));
        let element = &slice.vector[i % (kbv.slice_size as u64)];

        (element.key, &element.value)
    }

    /// Borrows a mutable element at index `i` from the KeyedBigVector.
    public fun borrow_mut<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, i: u64): (K, &mut V) {
        assert!(i < kbv.length, index_out_of_bounds());

        borrow_mut_(kbv, i)
    }
    fun borrow_mut_<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, i: u64): (K, &mut V) {
        let slice = borrow_slice_mut_(&mut kbv.id, (i / (kbv.slice_size as u64) as u16));
        let element = &mut slice.vector[i % (kbv.slice_size as u64)];

        (element.key, &mut element.value)
    }

    /// Borrows an element by its key from the KeyedBigVector.
    #[syntax(index)]
    public fun borrow_by_key<K: copy + drop + store, V: store>(kbv: &KeyedBigVector, key: K): &V {
        assert!(contains(kbv, key), key_not_found());

        let i = *table::borrow<K, u64>(dynamic_field::borrow(&kbv.id, SKeyIndexTable.to_string()), key);
        let (_, v) = borrow_<K, V>(kbv, i);

        v
    }

    /// Borrows a mutable element by its key from the KeyedBigVector.
    #[syntax(index)]
    public fun borrow_by_key_mut<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, key: K): &mut V {
        assert!(contains(kbv, key), key_not_found());

        let i = *table::borrow<K, u64>(dynamic_field::borrow(&kbv.id, SKeyIndexTable.to_string()), key);
        let (_, v) = borrow_mut_<K, V>(kbv, i);

        v
    }

    /// Borrows an element at index `i` from a slice.
    public fun borrow_from_slice<K: copy + drop + store, V: store>(slice: &Slice<K, V>, i: u64): (K, &V) {
        assert!(i < vector::length(&slice.vector), index_out_of_bounds());

        let element = &slice.vector[i];

        (element.key, &element.value)
    }

    /// Borrows a mutable element at index `i` from a slice.
    public fun borrow_from_slice_mut<K: copy + drop + store, V: store>(slice: &mut Slice<K, V>, i: u64): (K, &mut V) {
        assert!(i < vector::length(&slice.vector), index_out_of_bounds());

        let element = &mut slice.vector[i];

        (element.key, &mut element.value)
    }

    /// Swaps the element at index `i` with the last element and removes it.
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
            vector::push_back(&mut slice.vector, Element { key, value });
            let Element { key, value } = vector::swap_remove(&mut slice.vector, i % (kbv.slice_size as u64));
            table::remove<K, u64>(dynamic_field::borrow_mut(&mut kbv.id, SKeyIndexTable.to_string()), key);
            (key, value)
        }
    }

    /// Swaps the element with the given key with the last element and removes it.
    public fun swap_remove_by_key<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector, key: K): V {
        assert!(contains(kbv, key), key_not_found());

        let i = *table::borrow<K, u64>(dynamic_field::borrow(&kbv.id, SKeyIndexTable.to_string()), key);
        let (_, v) = swap_remove_<K, V>(kbv, i);

        v
    }

    /// Destroys an empty KeyedBigVector.
    /// Aborts if the KeyedBigVector is not empty.
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

    /// Destroys a KeyedBigVector.
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

    /// Destroys a KeyedBigVector and its elements completely.
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

    /// Removes an empty slice after an element has been removed from it.
    fun trim_slice<K: copy + drop + store, V: store>(kbv: &mut KeyedBigVector) {
        let slice = borrow_slice_(&kbv.id, kbv.slice_idx);
        if (vector::is_empty<Element<K, V>>(&slice.vector)) {
            let Slice {
                idx: _,
                vector: v,
            } = dynamic_field::remove(&mut kbv.id, kbv.slice_idx);
            vector::destroy_empty<Element<K, V>>(v);
            if (kbv.slice_idx > 0) {
                kbv.slice_idx = kbv.slice_idx - 1;
            };
        };
    }

    /// A macro for iterating over the elements of a KeyedBigVector with immutable references.
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

    /// A macro for iterating over the elements of a KeyedBigVector with mutable references.
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
    use std::vector;

    use sui::test_scenario::{Self, Scenario};

    use typus::keyed_big_vector::{Self, KeyedBigVector, completely_drop, new, push_back, pop_back, borrow, borrow_mut, swap_remove, borrow_by_key, borrow_by_key_mut, swap_remove_by_key};

    #[test]
    fun test_kbv_do() {
        let (scenario, mut kbv) = new_scenario();

        // [(0xA, 2), (0xB, 3)], [(0xC, 4), (0xD, 5)], [(0xE, 6)]
        do_mut!<address, u64>(&mut kbv, |_, value| {
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
        do_mut!<address, u64>(&mut kbv, |_, value| {
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

        completely_drop<address, u64>(kbv);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_kbv_push_pop() {
        let (scenario, mut kbv) = new_scenario();

        // []
        let mut count = 0;
        while (count < 5) {
            pop_back<address, u64>(&mut kbv);
            count = count + 1;
        };
        assert_result(
            &kbv,
            bcs::to_bytes(&vector<vector<u8>>[]),
        );

        // [(0xA, 1), (0xB, 2)], [(0xC, 3)]
        push_back(&mut kbv, @0xA, 1);
        push_back(&mut kbv, @0xB, 2);
        push_back(&mut kbv, @0xC, 3);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xC), bcs::to_bytes(&3)],
        ]));

        // [(0xA, 1)]
        let mut count = 0;
        while (count < 2) {
            pop_back<address, u64>(&mut kbv);
            count = count + 1;
        };
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
        ]));

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        push_back(&mut kbv, @0xD, 4);
        push_back(&mut kbv, @0xE, 5);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        completely_drop<address, u64>(kbv);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_kbv_borrow() {
        let (scenario, mut kbv) = new_scenario();

        // [(0xA, 1), (0xB, 2)], [(0xC, 3), (0xD, 4)], [(0xE, 5)]
        let (k, v) = borrow<address, u64>(&kbv, 2);
        assert!(k == @0xC && v ==&3, 0);

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        let (_, v) = borrow_mut<address, u64>(&mut kbv, 2);
        *v = *v * *v;
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xC), bcs::to_bytes(&9)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        completely_drop<address, u64>(kbv);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_kbv_swap_remove() {
        let (scenario, mut kbv) = new_scenario();

        // [(0xA, 1), (0xB, 2)], [(0xE, 5), (0xD, 4)]
        swap_remove<address, u64>(&mut kbv, 2);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
        ]));

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        swap_remove<address, u64>(&mut kbv, 1);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        completely_drop<address, u64>(kbv);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_kbv_borrow_by_key() {
        let (scenario, mut kbv) = new_scenario();

        // [(0xA, 1), (0xB, 2)], [(0xC, 3), (0xD, 4)], [(0xE, 5)]
        assert!(*borrow_by_key(&kbv, @0xC) == 3, 0);

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        let v: &mut u64 = borrow_by_key_mut(&mut kbv, @0xC);
        *v = *v * *v;
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xC), bcs::to_bytes(&9)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        completely_drop<address, u64>(kbv);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_kbv_swap_remove_by_key() {
        let (scenario, mut kbv) = new_scenario();

        // [(0xA, 1), (0xB, 2)], [(0xE, 5), (0xD, 4)]
        swap_remove_by_key<address, u64>(&mut kbv, @0xC);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xB), bcs::to_bytes(&2)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
        ]));

        // [(0xA, 1), (0xD, 4)], [(0xE, 5)]
        swap_remove_by_key<address, u64>(&mut kbv, @0xB);
        assert_result(&kbv, bcs::to_bytes(&vector[
            vector[bcs::to_bytes(&@0xA), bcs::to_bytes(&1)],
            vector[bcs::to_bytes(&@0xD), bcs::to_bytes(&4)],
            vector[bcs::to_bytes(&@0xE), bcs::to_bytes(&5)],
        ]));

        completely_drop<address, u64>(kbv);
        test_scenario::end(scenario);
    }

    #[test_only]
    fun new_scenario(): (Scenario, KeyedBigVector) {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut kbv = new<address, u64>(2, test_scenario::ctx(&mut scenario));
        // [(0xA, 1), (0xB, 2)], [(0xC, 3), (0xD, 4)], [(0xE, 5)]
        push_back(&mut kbv, @0xA, 1);
        push_back(&mut kbv, @0xB, 2);
        push_back(&mut kbv, @0xC, 3);
        push_back(&mut kbv, @0xD, 4);
        push_back(&mut kbv, @0xE, 5);
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
        do_ref!<address, u64>(keyed_big_vector, |key, value| {
            // std::debug::print(&key);
            // std::debug::print(value);
            vector::push_back(&mut result, vector[bcs::to_bytes(&key), bcs::to_bytes(value)]);
        });
        assert!(expected_result == bcs::to_bytes(&result), 0);
    }
}