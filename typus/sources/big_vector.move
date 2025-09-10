// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
module typus::big_vector {
    use std::type_name::{Self, TypeName};

    use sui::dynamic_field;

    // ======== Constants ========

    const CMaxSliceSize: u32 = 262144;

    // ======== Errors ========

    const EInvalidSliceSize: u64 = 0;
    const ENotEmpty: u64 = 1;
    const EIsEmpty: u64 = 2;
    const EIndexOutOfBounds: u64 = 3;

    // ======== Structs ========

    public struct BigVector has key, store {
        /// the ID of the BigVector
        id: UID,
        /// the element type of the BigVector
        element_type: TypeName,
        /// the latest index of the Slice in the BigVector
        slice_idx: u64,
        /// the max size of each Slice in the BigVector
        slice_size: u32,
        /// the length of the BigVector
        length: u64,
    }

    public struct Slice<Element> has store, drop {
        /// the index of the Slice
        idx: u64,
        /// the vector which stores elements
        vector: vector<Element>,
    }

    // ======== Functions ========

    /// create BigVector
    public fun new<Element: store>(slice_size: u32, ctx: &mut TxContext): BigVector {
        // slice_size * sizeof(Element) should be below the object size limit 256000 bytes.
        assert!(slice_size > 0 && slice_size <= CMaxSliceSize, EInvalidSliceSize);

        BigVector {
            id: object::new(ctx),
            element_type: type_name::get<Element>(),
            slice_idx: 0,
            slice_size,
            length: 0,
        }
    }

    /// return the latest index of the Slice in the BigVector
    public fun slice_idx(bv: &BigVector): u64 {
        bv.slice_idx
    }

    /// return the max size of each Slice in the BigVector
    public fun slice_size(bv: &BigVector): u32 {
        bv.slice_size
    }

    /// return the length of the BigVector
    public fun length(bv: &BigVector): u64 {
        bv.length
    }

    /// return true if the BigVector is empty
    public fun is_empty(bv: &BigVector): bool {
        bv.length == 0
    }

    /// return the index of the Slice
    public fun get_slice_idx<Element>(slice: &Slice<Element>): u64 {
        slice.idx
    }

    /// return the length of the element in the Slice
    public fun get_slice_length<Element>(slice: &Slice<Element>): u64 {
        slice.vector.length()
    }

    /// push a new element at the end of the BigVector
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

    /// pop an element from the end of the BigVector
    public fun pop_back<Element: store>(bv: &mut BigVector): Element {
        assert!(!bv.is_empty(), EIsEmpty);

        let slice = borrow_slice_mut_(&mut bv.id, bv.slice_idx);
        let element = slice.vector.pop_back();
        bv.trim_slice<Element>();
        bv.length = bv.length - 1;

        element
    }

    #[syntax(index)]
    /// borrow an element at index i from the BigVector
    public fun borrow<Element: store>(bv: &BigVector, i: u64): &Element {
        assert!(i < bv.length, EIndexOutOfBounds);
        assert!(!bv.is_empty(), EIsEmpty);

        let slice = borrow_slice_(&bv.id, i / (bv.slice_size as u64));
        &slice.vector[i % (bv.slice_size as u64)]
    }

    #[syntax(index)]
    /// borrow a mutable element at index i from the BigVector
    public fun borrow_mut<Element: store>(bv: &mut BigVector, i: u64): &mut Element {
        assert!(i < bv.length, EIndexOutOfBounds);
        assert!(!bv.is_empty(), EIsEmpty);

        let slice = borrow_slice_mut_(&mut bv.id, i / (bv.slice_size as u64));
        &mut slice.vector[i % (bv.slice_size as u64)]
    }

    /// borrow a slice from the BigVector
    public fun borrow_slice<Element: store>(bv: &BigVector, slice_idx: u64): &Slice<Element> {
        assert!(slice_idx <= bv.slice_idx, EIndexOutOfBounds);
        assert!(!bv.is_empty(), EIsEmpty);

        borrow_slice_(&bv.id, slice_idx)
    }
    fun borrow_slice_<Element: store>(id: &UID, slice_idx: u64): &Slice<Element> {
        dynamic_field::borrow(id, slice_idx)
    }

    /// borrow a mutable slice from the BigVector
    public fun borrow_slice_mut<Element: store>(bv: &mut BigVector, slice_idx: u64): &mut Slice<Element> {
        assert!(slice_idx <= bv.slice_idx, EIndexOutOfBounds);
        assert!(!bv.is_empty(), EIsEmpty);

        borrow_slice_mut_(&mut bv.id, slice_idx)
    }
    fun borrow_slice_mut_<Element: store>(id: &mut UID, slice_idx: u64): &mut Slice<Element> {
        dynamic_field::borrow_mut(id, slice_idx)
    }

    #[syntax(index)]
    /// borrow an element at index i from the BigVector
    public fun borrow_from_slice<Element: store>(slice: &Slice<Element>, i: u64): &Element {
        assert!(i < slice.vector.length(), EIndexOutOfBounds);

        &slice.vector[i]
    }

    #[syntax(index)]
    /// borrow a mutable element at index i from the BigVector
    public fun borrow_from_slice_mut<Element: store>(slice: &mut Slice<Element>, i: u64): &mut Element {
        assert!(i < slice.vector.length(), EIndexOutOfBounds);

        &mut slice.vector[i]
    }

    /// swap and pop the element at index i with the last element
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

    /// remove the element at index i and shift the rest elements
    /// abort when reference more thant 1000 slices
    /// costly function, use wisely
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

    /// drop BigVector, abort if it's not empty
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

    /// drop BigVector if element has drop ability
    /// abort when the BigVector contains more thant 1000 slices
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

    /// remove empty slice after element removal
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
}