module typus_framework::big_vector {
    use sui::dynamic_field;

    const E_NOT_EMPTY: u64 = 0;

    public struct BigVector<phantom Element> has key, store {
        id: UID,
        slice_count: u64,
        slice_size: u64,
        length: u64,
    }

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

    public fun slice_count<Element: store>(bv: &BigVector<Element>): u64 {
        bv.slice_count
    }

    public fun slice_size<Element: store>(bv: &BigVector<Element>): u64 {
        bv.slice_size
    }

    public fun length<Element: store>(bv: &BigVector<Element>): u64 {
        bv.length
    }

    public fun slice_id<Element: store>(bv: &BigVector<Element>, i: u64): u64 {
        (i / bv.slice_size) + 1
    }

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

    public fun pop_back<Element: store>(bv: &mut BigVector<Element>): Element {
        let slice = dynamic_field::borrow_mut(&mut bv.id, bv.slice_count);
        let element = vector::pop_back(slice);
        trim_slice(bv);
        bv.length = bv.length - 1;

        element
    }

    public fun borrow<Element: store>(bv: &BigVector<Element>, i: u64): &Element {
        let slice_count = (i / bv.slice_size) + 1;
        let slice = dynamic_field::borrow(&bv.id, slice_count);
        vector::borrow(slice, i % bv.slice_size)
    }

    public fun borrow_mut<Element: store>(bv: &mut BigVector<Element>, i: u64): &mut Element {
        let slice_count = (i / bv.slice_size) + 1;
        let slice = dynamic_field::borrow_mut(&mut bv.id, slice_count);
        vector::borrow_mut(slice, i % bv.slice_size)
    }

    public fun borrow_slice<Element: store>(bv: &BigVector<Element>, slice_count: u64): &vector<Element> {
        dynamic_field::borrow(&bv.id, slice_count)
    }

    public fun borrow_slice_mut<Element: store>(bv: &mut BigVector<Element>, slice_count: u64): &mut vector<Element> {
        dynamic_field::borrow_mut(&mut bv.id, slice_count)
    }

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

    public fun is_empty<Element: store>(bv: &BigVector<Element>): bool {
        bv.length == 0
    }

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

    fun trim_slice<Element: store>(bv: &mut BigVector<Element>) {
        let slice = dynamic_field::borrow_mut<u64, vector<Element>>(&mut bv.id, bv.slice_count);
        if (bv.slice_count > 1 && vector::length(slice) == 0) {
            let empty_slice = dynamic_field::remove(&mut bv.id, bv.slice_count);
            vector::destroy_empty<Element>(empty_slice);
            bv.slice_count = bv.slice_count - 1;
        };
    }
}

#[test_only]
module typus_framework::test_big_vector {
    use sui::test_scenario;

    use typus_framework::big_vector;

    #[test]
    fun test_big_vector_push_pop() {
        let mut scenario = test_scenario::begin(@0xAAAA);

        let tmp = 10;
        let mut big_vector = big_vector::new<u64>(3, test_scenario::ctx(&mut scenario));
        let mut count = 1;
        while (count <= tmp) {
            big_vector::push_back(&mut big_vector, count);
            count = count + 1;
        };
        // [1, 2, 3], [4, 5, 6], [7, 8, 9], [10]
        let mut count = tmp;
        while (count > 0) {
            // assert!(pop_back(&mut big_vector) == count, 0);
            std::debug::print(&big_vector::slice_count(&big_vector));
            std::debug::print(&big_vector::pop_back(&mut big_vector));
            count = count - 1;
        };

        big_vector::destroy_empty(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_big_vector_swap_remove() {
        let mut scenario = test_scenario::begin(@0xAAAA);

        let tmp = 10;
        let mut big_vector = big_vector::new<u64>(3, test_scenario::ctx(&mut scenario));
        let mut count = 1;
        while (count <= tmp) {
            big_vector::push_back(&mut big_vector, count);
            count = count + 1;
        };
        // [1, 2, 3], [4, 5, 6], [7, 8, 9], [10]
        big_vector::swap_remove(&mut big_vector, 5);
        // [1, 2, 3], [4, 5, 10], [7, 8, 9]
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 9, 0);
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 8, 0);
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 7, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 10, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 5, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 4, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 3, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 2, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 1, 0);

        big_vector::destroy_empty(big_vector);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_big_vector_remove() {
        let mut scenario = test_scenario::begin(@0xAAAA);

        let tmp = 10;
        let mut big_vector = big_vector::new<u64>(3, test_scenario::ctx(&mut scenario));
        let mut count = 1;
        while (count <= tmp) {
            big_vector::push_back(&mut big_vector, count);
            count = count + 1;
        };
        // [1, 2, 3], [4, 5, 6], [7, 8, 9], [10]
        big_vector::remove(&mut big_vector, 5);
        // [1, 2, 3], [4, 5, 7], [8, 9, 10]
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 10, 0);
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 9, 0);
        assert!(big_vector::slice_count(&big_vector) == 3, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 8, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 7, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 5, 0);
        assert!(big_vector::slice_count(&big_vector) == 2, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 4, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 3, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 2, 0);
        assert!(big_vector::slice_count(&big_vector) == 1, 0);
        assert!(big_vector::pop_back(&mut big_vector) == 1, 0);

        big_vector::destroy_empty(big_vector);
        test_scenario::end(scenario);
    }
}