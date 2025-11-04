/// No authority chech in these public functions, do not let `BigVector` be exposed.
module typus_framework::big_vector {
    use sui::dynamic_field;

    const E_NOT_EMPTY: u64 = 0;

    /// A vector-like data structure that can grow beyond the gas limits of a single transaction
    /// by storing its elements in a series of smaller vectors (slices) as dynamic fields.
    public struct BigVector<phantom Element> has key, store {
        /// The `UID` of the object that holds the slices as dynamic fields.
        id: UID,
        /// The number of slices.
        slice_count: u64,
        /// The maximum size of each slice.
        slice_size: u64,
        /// The total number of elements in the `BigVector`.
        length: u64,
    }

    /// Creates a new `BigVector`.
    public fun new<Element: store>(slice_size: u64, ctx: &mut TxContext): BigVector<Element> {
        let mut id = object::new(ctx);
        let slice_count = 1;
        dynamic_field::add(&mut id, slice_count, vector::empty<Element>());
        BigVector<Element> {
            id,
            slice_count,
            slice_size,
            length: 0,
        }
    }

    /// Returns the number of slices.
    public fun slice_count<Element: store>(bv: &BigVector<Element>): u64 {
        bv.slice_count
    }

    /// Returns the maximum size of each slice.
    public fun slice_size<Element: store>(bv: &BigVector<Element>): u64 {
        bv.slice_size
    }

    /// Returns the total number of elements in the `BigVector`.
    public fun length<Element: store>(bv: &BigVector<Element>): u64 {
        bv.length
    }

    /// Calculates the slice id for a given index `i`.
    public fun slice_id<Element: store>(bv: &BigVector<Element>, i: u64): u64 {
        (i / bv.slice_size) + 1
    }

    /// Adds an element to the end of the `BigVector`.
    /// WARNING: mut inputs without authority check inside
    public fun push_back<Element: store>(bv: &mut BigVector<Element>, element: Element) {
        if (length(bv) / bv.slice_size == bv.slice_count) {
            bv.slice_count = bv.slice_count + 1;
            let new_slice = vector::singleton(element);
            dynamic_field::add(&mut bv.id, bv.slice_count, new_slice);
        }
        else {
            let slice = dynamic_field::borrow_mut(&mut bv.id, bv.slice_count);
            vector::push_back(slice, element);
        };
        bv.length = bv.length + 1;
    }

    /// Removes and returns the last element.
    /// WARNING: mut inputs without authority check inside
    public fun pop_back<Element: store>(bv: &mut BigVector<Element>): Element {
        let slice = dynamic_field::borrow_mut(&mut bv.id, bv.slice_count);
        let element = vector::pop_back(slice);
        trim_slice(bv);
        bv.length = bv.length - 1;

        element
    }

    /// Borrows an element at index `i`.
    public fun borrow<Element: store>(bv: &BigVector<Element>, i: u64): &Element {
        let slice_count = (i / bv.slice_size) + 1;
        let slice = dynamic_field::borrow(&bv.id, slice_count);
        vector::borrow(slice, i % bv.slice_size)
    }

    /// Mutably borrows an element at index `i`.
    /// WARNING: mut inputs without authority check inside
    public fun borrow_mut<Element: store>(bv: &mut BigVector<Element>, i: u64): &mut Element {
        let slice_count = (i / bv.slice_size) + 1;
        let slice = dynamic_field::borrow_mut(&mut bv.id, slice_count);
        vector::borrow_mut(slice, i % bv.slice_size)
    }

    /// Borrows a whole slice.
    public fun borrow_slice<Element: store>(bv: &BigVector<Element>, slice_count: u64): &vector<Element> {
        dynamic_field::borrow(&bv.id, slice_count)
    }

    /// Mutably borrows a whole slice.
    /// WARNING: mut inputs without authority check inside
    public fun borrow_slice_mut<Element: store>(bv: &mut BigVector<Element>, slice_count: u64): &mut vector<Element> {
        dynamic_field::borrow_mut(&mut bv.id, slice_count)
    }

    /// Removes an element at index `i` by swapping with the last element.
    /// WARNING: mut inputs without authority check inside
    public fun swap_remove<Element: store>(bv: &mut BigVector<Element>, i: u64): Element {
        let result = pop_back(bv);
        if (i == length(bv)) {
            result
        } else {
            let slice_count = (i / bv.slice_size) + 1;
            let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, slice_count);
            vector::push_back(slice, result);
            vector::swap_remove(slice, i % bv.slice_size)
        }
    }

    /// Removes an element at index `i` and shifts all subsequent elements.
    /// WARNING: mut inputs without authority check inside
    public fun remove<Element: store>(bv: &mut BigVector<Element>, i: u64): Element {
        let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, (i / bv.slice_size) + 1);
        let result = vector::remove(slice, i % bv.slice_size);
        let mut slice_count = bv.slice_count;
        while (slice_count > (i / bv.slice_size) + 1 && slice_count > 1) {
            let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, slice_count);
            let tmp = vector::remove(slice, 0);
            let prev_slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, slice_count - 1);
            vector::push_back(prev_slice, tmp);
            slice_count = slice_count - 1;
        };
        trim_slice(bv);
        bv.length = bv.length - 1;

        result
    }

    /// Checks if the `BigVector` is empty.
    public fun is_empty<Element: store>(bv: &BigVector<Element>): bool {
        bv.length == 0
    }

    /// Destroys an empty `BigVector`.
    public fun destroy_empty<Element: store>(mut bv: BigVector<Element>) {
        assert!(bv.length == 0, E_NOT_EMPTY);
        let empty_slice = dynamic_field::remove(&mut bv.id, 1);
        vector::destroy_empty<Element>(empty_slice);
        let BigVector {
            id,
            slice_count: _,
            slice_size: _,
            length: _,
        } = bv;
        object::delete(id);
    }

    /// An internal helper function to remove empty slices from the end.
    /// WARNING: mut inputs without authority check inside
    fun trim_slice<Element: store>(bv: &mut BigVector<Element>) {
        let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, bv.slice_count);
        if (bv.slice_count > 1 && vector::length(slice) == 0) {
            let empty_slice = dynamic_field::remove(&mut bv.id, bv.slice_count);
            vector::destroy_empty<Element>(empty_slice);
            bv.slice_count = bv.slice_count - 1;
        };
    }
}