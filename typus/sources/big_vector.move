// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module implements a `BigVector`, a vector-like data structure that can store a large number of elements
/// by splitting them into smaller `Slice` objects. This allows it to overcome the object size limit in Sui.
/// Each `Slice` is a dynamic field of the `BigVector` object.
module typus::big_vector {
    use std::type_name::{Self, TypeName};
    use std::vector;

    use sui::dynamic_field;
    use sui::object::{UID, self};
    use sui::tx_context::TxContext;

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
            element_type: type_name::get<Element>(),
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
        vector::length(&slice.vector)
    }

    /// Pushes a new element to the end of the BigVector.
    /// If the current slice is full, it creates a new slice.
    public fun push_back<Element: store>(bv: &mut BigVector, element: Element) {
        if (is_empty(bv) || length(bv) % (slice_size(bv) as u64) == 0) {
            bv.slice_idx = length(bv) / (slice_size(bv) as u64);
            let new_slice = Slice {
                idx: bv.slice_idx,
                vector: vector[element]
            };
            dynamic_field::add(&mut bv.id, bv.slice_idx, new_slice);
        }
        else {
            let slice = borrow_slice_mut_(bv.id_mut(), bv.slice_idx);
            vector::push_back(&mut slice.vector, element);
        };
        bv.length = bv.length + 1;
    }

    /// Pops an element from the end of the BigVector.
    /// Aborts if the BigVector is empty.
    public fun pop_back<Element: store>(bv: &mut BigVector): Element {
        assert!(!is_empty(bv), EIsEmpty);

        let slice = borrow_slice_mut_(bv.id_mut(), bv.slice_idx);
        let element = vector::pop_back(&mut slice.vector);
        trim_slice<Element>(bv);
        bv.length = bv.length - 1;

        element
    }

    /// Borrows an element at index `i` from the BigVector.
    /// Aborts if the index is out of bounds.
    #[syntax(index)]
    public fun borrow<Element: store>(bv: &BigVector, i: u64): &Element {
        assert!(i < bv.length, EIndexOutOfBounds);
        assert!(!is_empty(bv), EIsEmpty);

        let slice = borrow_slice_(bv.id(), i / (slice_size(bv) as u64));
        vector::borrow(&slice.vector, i % (slice_size(bv) as u64))
    }

    /// Borrows a mutable element at index `i` from the BigVector.
    /// Aborts if the index is out of bounds.
    #[syntax(index)]
    public fun borrow_mut<Element: store>(bv: &mut BigVector, i: u64): &mut Element {
        assert!(i < bv.length, EIndexOutOfBounds);
        assert!(!is_empty(bv), EIsEmpty);

        let slice = borrow_slice_mut_(bv.id_mut(), i / (slice_size(bv) as u64));
        vector::borrow_mut(&mut slice.vector, i % (slice_size(bv) as u64))
    }

    /// Borrows a slice from the BigVector at `slice_idx`.
    /// Aborts if the `slice_idx` is out of bounds.
    public fun borrow_slice<Element: store>(bv: &BigVector, slice_idx: u64): &Slice<Element> {
        assert!(slice_idx <= bv.slice_idx, EIndexOutOfBounds);
        assert!(!is_empty(bv), EIsEmpty);

        borrow_slice_(bv.id(), slice_idx)
    }
    fun borrow_slice_<Element: store>(id: &UID, slice_idx: u64): &Slice<Element> {
        dynamic_field::borrow(id, slice_idx)
    }

    /// Borrows a mutable slice from the BigVector at `slice_idx`.
    /// Aborts if the `slice_idx` is out of bounds.
    public fun borrow_slice_mut<Element: store>(bv: &mut BigVector, slice_idx: u64): &mut Slice<Element> {
        assert!(slice_idx <= bv.slice_idx, EIndexOutOfBounds);
        assert!(!is_empty(bv), EIsEmpty);

        borrow_slice_mut_(bv.id_mut(), slice_idx)
    }
    fun borrow_slice_mut_<Element: store>(id: &mut UID, slice_idx: u64): &mut Slice<Element> {
        dynamic_field::borrow_mut(id, slice_idx)
    }

    /// Borrows an element at index `i` from a slice.
    /// Aborts if the index is out of bounds.
    #[syntax(index)]
    public fun borrow_from_slice<Element: store>(slice: &Slice<Element>, i: u64): &Element {
        assert!(i < vector::length(&slice.vector), EIndexOutOfBounds);

        vector::borrow(&slice.vector, i)
    }

    /// Borrows a mutable element at index `i` from a slice.
    /// Aborts if the index is out of bounds.
    #[syntax(index)]
    public fun borrow_from_slice_mut<Element: store>(slice: &mut Slice<Element>, i: u64): &mut Element {
        assert!(i < vector::length(&slice.vector), EIndexOutOfBounds);

        vector::borrow_mut(&mut slice.vector, i)
    }

    /// Swaps the element at index `i` with the last element and removes it.
    /// This is more efficient than `remove` as it does not require shifting elements.
    public fun swap_remove<Element: store>(bv: &mut BigVector, i: u64): Element {
        let result = pop_back(bv);
        if (i == length(bv)) {
            result
        } else {
            let slice = borrow_slice_mut_(bv.id_mut(), i / (slice_size(bv) as u64));
            vector::push_back(&mut slice.vector, result);
            vector::swap_remove(&mut slice.vector, i % (slice_size(bv) as u64))
        }
    }

    /// Removes the element at index `i` and shifts the rest of the elements to the left.
    /// This is a costly function, especially for large BigVectors. Use with caution.
    /// Aborts when referencing more than 1000 slices.
    public fun remove<Element: store>(bv: &mut BigVector, i: u64): Element {
        assert!(i < length(bv), EIndexOutOfBounds);

        let slice = borrow_slice_mut_(bv.id_mut(), (i / (slice_size(bv) as u64)));
        let result = vector::remove(&mut slice.vector, i % (slice_size(bv) as u64));
        let mut slice_idx = bv.slice_idx;
        while (slice_idx > i / (slice_size(bv) as u64) && slice_idx > 0) {
            let slice = borrow_slice_mut_(bv.id_mut(), slice_idx);
            let tmp: Element = vector::remove(&mut slice.vector, 0);
            let prev_slice = borrow_slice_mut_(bv.id_mut(), slice_idx - 1);
            vector::push_back(&mut prev_slice.vector, tmp);
            slice_idx = slice_idx - 1;
        };
        trim_slice<Element>(bv);
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
        if (vector::is_empty<Element>(&slice.vector)) {
            let Slice {
                idx: _,
                vector: v,
            } = dynamic_field::remove(&mut bv.id, bv.slice_idx);
            vector::destroy_empty<Element>(v);
            if (bv.slice_idx > 0) {
                bv.slice_idx = bv.slice_idx - 1;
            };
        };
    }
}