// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module implements a `BigVector`, a vector-like data structure that can store a large number of elements
/// by splitting them into smaller `Slice` objects. This allows it to overcome the object size limit in Sui.
/// Each `Slice` is a dynamic field of the `BigVector` object.
module typus::big_vector {
    use std::type_name::{Self, TypeName};

    use sui::dynamic_field;

    // ======== Constants ========

    /// The maximum size of a slice.
    const CMaxSliceSize: u32 = 262144;

    // ======== Errors ========

    /// Error for invalid slice size.
    const EInvalidSliceSize: u64 = 0;
    /// Error when trying to destroy a non-empty BigVector.
    const ENotEmpty: u64 = 1;
    /// Error when trying to pop from an empty BigVector.
    const EIsEmpty: u64 = 2;
    /// Error for out-of-bounds access.
    const EIndexOutOfBounds: u64 = 3;

    // ======== Structs ========

    /// A vector-like data structure that can store a large number of elements.
    public struct BigVector has key, store {
        /// The unique identifier of the BigVector object.
        id: UID,
        /// The type name of the elements stored in the BigVector.
        element_type: TypeName,
        /// The index of the latest slice in the BigVector.
        slice_idx: u64,
        /// The maximum size of each slice in the BigVector.
        slice_size: u32,
        /// The total number of elements in the BigVector.
        length: u64,
    }

    /// A slice of the BigVector, containing a vector of elements.
    public struct Slice<Element> has store, drop {
        /// The index of the slice.
        idx: u64,
        /// The vector that stores the elements.
        vector: vector<Element>,
    }

    // ======== Functions ========

    /// Creates a new `BigVector`.
    /// The `slice_size` determines the maximum number of elements in each slice.
    /// `slice_size * sizeof(Element)` should be below the object size limit of 256000 bytes.
    public fun new<Element: store>(slice_size: u32, ctx: &mut TxContext): BigVector {
        assert!(slice_size > 0 && slice_size <= CMaxSliceSize, EInvalidSliceSize);

        BigVector {
            id: object::new(ctx),
            element_type: type_name::with_defining_ids<Element>(),
            slice_idx: 0,
            slice_size,
            length: 0,
        }
    }

    /// Returns the index of the latest slice in the BigVector.
    public fun slice_idx(bv: &BigVector): u64 {
        bv.slice_idx
    }

    /// Returns the maximum size of each slice in the BigVector.
    public fun slice_size(bv: &BigVector): u32 {
        bv.slice_size
    }

    /// Returns the total number of elements in the BigVector.
    public fun length(bv: &BigVector): u64 {
        bv.length
    }

    /// Returns `true` if the BigVector is empty.
    public fun is_empty(bv: &BigVector): bool {
        bv.length == 0
    }

    /// Returns the index of the slice.
    public fun get_slice_idx<Element>(slice: &Slice<Element>): u64 {
        slice.idx
    }

    /// Returns the number of elements in the slice.
    public fun get_slice_length<Element>(slice: &Slice<Element>): u64 {
        slice.vector.length()
    }

    /// Pushes a new element to the end of the BigVector.
    /// If the current slice is full, it creates a new slice.
    public fun push_back<Element: store>(bv: &mut BigVector, element: Element) {
        if (bv.is_empty() || bv.length() % (bv.slice_size as u64) == 0) {
            bv.slice_idx = bv.length() / (bv.slice_size as u64);
            let new_slice = Slice {
                idx: bv.slice_idx,
                vector: vector[element]
            };
            dynamic_field::add(&mut bv.id, bv.slice_idx, new_slice);
        }
        else {
            let slice = borrow_slice_mut_(&mut bv.id, bv.slice_idx);
            slice.vector.push_back(element);
        };
        bv.length = bv.length + 1;
    }

    /// Pops an element from the end of the BigVector.
    /// Aborts if the BigVector is empty.
    public fun pop_back<Element: store>(bv: &mut BigVector): Element {
        assert!(!bv.is_empty(), EIsEmpty);

        let slice = borrow_slice_mut_(&mut bv.id, bv.slice_idx);
        let element = slice.vector.pop_back();
        bv.trim_slice<Element>();
        bv.length = bv.length - 1;

        element
    }

    /// Borrows an element at index `i` from the BigVector.
    /// Aborts if the index is out of bounds.
    #[syntax(index)]
    public fun borrow<Element: store>(bv: &BigVector, i: u64): &Element {
        assert!(i < bv.length, EIndexOutOfBounds);

        let slice = borrow_slice_(&bv.id, i / (bv.slice_size as u64));
        &slice.vector[i % (bv.slice_size as u64)]
    }

    /// Borrows a mutable element at index `i` from the BigVector.
    /// Aborts if the index is out of bounds.
    #[syntax(index)]
    public fun borrow_mut<Element: store>(bv: &mut BigVector, i: u64): &mut Element {
        assert!(i < bv.length, EIndexOutOfBounds);

        let slice = borrow_slice_mut_(&mut bv.id, i / (bv.slice_size as u64));
        &mut slice.vector[i % (bv.slice_size as u64)]
    }

    /// Borrows a slice from the BigVector at `slice_idx`.
    /// Aborts if the `slice_idx` is out of bounds.
    public fun borrow_slice<Element: store>(bv: &BigVector, slice_idx: u64): &Slice<Element> {
        assert!(slice_idx <= bv.slice_idx, EIndexOutOfBounds);
        assert!(!bv.is_empty(), EIsEmpty);

        borrow_slice_(&bv.id, slice_idx)
    }
    fun borrow_slice_<Element: store>(id: &UID, slice_idx: u64): &Slice<Element> {
        dynamic_field::borrow(id, slice_idx)
    }

    /// Borrows a mutable slice from the BigVector at `slice_idx`.
    /// Aborts if the `slice_idx` is out of bounds.
    public fun borrow_slice_mut<Element: store>(bv: &mut BigVector, slice_idx: u64): &mut Slice<Element> {
        assert!(slice_idx <= bv.slice_idx, EIndexOutOfBounds);
        assert!(!bv.is_empty(), EIsEmpty);

        borrow_slice_mut_(&mut bv.id, slice_idx)
    }
    fun borrow_slice_mut_<Element: store>(id: &mut UID, slice_idx: u64): &mut Slice<Element> {
        dynamic_field::borrow_mut(id, slice_idx)
    }

    /// Borrows an element at index `i` from a slice.
    /// Aborts if the index is out of bounds.
    #[syntax(index)]
    public fun borrow_from_slice<Element: store>(slice: &Slice<Element>, i: u64): &Element {
        assert!(i < slice.vector.length(), EIndexOutOfBounds);

        &slice.vector[i]
    }

    /// Borrows a mutable element at index `i` from a slice.
    /// Aborts if the index is out of bounds.
    #[syntax(index)]
    public fun borrow_from_slice_mut<Element: store>(slice: &mut Slice<Element>, i: u64): &mut Element {
        assert!(i < slice.vector.length(), EIndexOutOfBounds);

        &mut slice.vector[i]
    }

    /// Swaps the element at index `i` with the last element and removes it.
    /// This is more efficient than `remove` as it does not require shifting elements.
    public fun swap_remove<Element: store>(bv: &mut BigVector, i: u64): Element {
        let result = pop_back(bv);
        if (i == bv.length()) {
            result
        } else {
            let slice = borrow_slice_mut_(&mut bv.id, i / (bv.slice_size as u64));
            slice.vector.push_back(result);
            slice.vector.swap_remove(i % (bv.slice_size as u64))
        }
    }

    /// Removes the element at index `i` and shifts the rest of the elements to the left.
    /// This is a costly function, especially for large BigVectors. Use with caution.
    /// Aborts when referencing more than 1000 slices.
    public fun remove<Element: store>(bv: &mut BigVector, i: u64): Element {
        assert!(i < bv.length(), EIndexOutOfBounds);

        let slice = borrow_slice_mut_(&mut bv.id, (i / (bv.slice_size as u64)));
        let result = slice.vector.remove(i % (bv.slice_size as u64));
        let mut slice_idx = bv.slice_idx;
        while (slice_idx > i / (bv.slice_size as u64) && slice_idx > 0) {
            let slice = borrow_slice_mut_(&mut bv.id, slice_idx);
            let tmp: Element = slice.vector.remove(0);
            let prev_slice = borrow_slice_mut_(&mut bv.id, slice_idx - 1);
            prev_slice.vector.push_back(tmp);
            slice_idx = slice_idx - 1;
        };
        bv.trim_slice<Element>();
        bv.length = bv.length - 1;

        result
    }

    /// Destroys an empty BigVector.
    /// Aborts if the BigVector is not empty.
    public fun destroy_empty(bv: BigVector) {
        let BigVector {
            id,
            element_type: _,
            slice_idx: _,
            slice_size: _,
            length,
        } = bv;
        assert!(length == 0, ENotEmpty);
        id.delete();
    }

    /// Destroys a BigVector and its elements.
    /// The element type must have the `drop` ability.
    /// Aborts when the BigVector contains more than 1000 slices.
    public fun drop<Element: store + drop>(bv: BigVector) {
        let BigVector {
            mut id,
            element_type: _,
            mut slice_idx,
            slice_size: _,
            length: _,
        } = bv;
        while (slice_idx > 0) {
            dynamic_field::remove<u64, Slice<Element>>(&mut id, slice_idx);
            slice_idx = slice_idx - 1;
        };
        dynamic_field::remove<u64, Slice<Element>>(&mut id, slice_idx);
        id.delete();
    }

    /// Removes an empty slice after an element has been removed from it.
    fun trim_slice<Element: store>(bv: &mut BigVector) {
        let slice = borrow_slice_(&bv.id, bv.slice_idx);
        if (slice.vector.is_empty<Element>()) {
            let Slice {
                idx: _,
                vector: v,
            } = dynamic_field::remove(&mut bv.id, bv.slice_idx);
            v.destroy_empty<Element>();
            if (bv.slice_idx > 0) {
                bv.slice_idx = bv.slice_idx - 1;
            };
        };
    }


    #[test_only]
    use sui::test_scenario::{Self, Scenario};
    #[test_only]
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