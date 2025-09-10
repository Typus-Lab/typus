// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Similar to `sui::linked_table` but the values are stored by dynamic_object_field
module typus::linked_object_table {
    use sui::dynamic_field as field;
    use sui::dynamic_object_field as ofield;

    // ======== Error Code ========

    const ETableNotEmpty: u64 = 0;
    const ETableIsEmpty: u64 = 1;

    // ======== Structs ========

    public struct LinkedObjectTable<K: copy + drop + store, phantom V: key + store> has key, store {
        /// the UID for Node storage
        id: UID,
        /// the UID for value storage
        vid: UID,
        /// the number of key-value pairs in the table
        size: u64,
        /// the front of the table, i.e. the key of the first entry
        head: Option<K>,
        /// the back of the table, i.e. the key of the last entry
        tail: Option<K>,
    }

    public struct Node<K: copy + drop + store, phantom V: key + store> has store {
        /// the previous key
        prev: Option<K>,
        /// the next key
        next: Option<K>,
    }

    // ======== Public Functions ========

    /// Creates a new, empty table
    public fun new<K: copy + drop + store, V: key + store>(ctx: &mut TxContext): LinkedObjectTable<K, V> {
        LinkedObjectTable {
            id: object::new(ctx),
            vid: object::new(ctx),
            size: 0,
            head: option::none(),
            tail: option::none(),
        }
    }

    /// Returns the key for the first element in the table, or None if the table is empty
    public fun front<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>): &Option<K> {
        &table.head
    }

    /// Returns the key for the last element in the table, or None if the table is empty
    public fun back<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>): &Option<K> {
        &table.tail
    }

    /// Inserts a key-value pair at the front of the table, i.e. the newly inserted pair will be
    /// the first element in the table
    /// Aborts with `sui::dynamic_field::EFieldAlreadyExists` if the table already has an entry with
    /// that key `k: K`.
    public fun push_front<K: copy + drop + store, V: key + store>(
        table: &mut LinkedObjectTable<K, V>,
        k: K,
        v: V,
    ) {
        let old_head = option::swap_or_fill(&mut table.head, k);
        if (option::is_none(&table.tail)) option::fill(&mut table.tail, k);
        let prev = option::none();
        let next = if (option::is_some(&old_head)) {
            let old_head_k = option::destroy_some(old_head);
            field::borrow_mut<K, Node<K, V>>(&mut table.id, old_head_k).prev = option::some(k);
            option::some(old_head_k)
        } else {
            option::none()
        };
        field::add(&mut table.id, k, Node<K, V> { prev, next });
        ofield::add(&mut table.vid, k, v);
        table.size = table.size + 1;
    }

    /// Inserts a key-value pair at the back of the table, i.e. the newly inserted pair will be
    /// the last element in the table
    /// Aborts with `sui::dynamic_field::EFieldAlreadyExists` if the table already has an entry with
    /// that key `k: K`.
    public fun push_back<K: copy + drop + store, V: key + store>(
        table: &mut LinkedObjectTable<K, V>,
        k: K,
        v: V,
    ) {
        if (option::is_none(&table.head)) option::fill(&mut table.head, k);
        let old_tail = option::swap_or_fill(&mut table.tail, k);
        let prev = if (option::is_some(&old_tail)) {
            let old_tail_k = option::destroy_some(old_tail);
            field::borrow_mut<K, Node<K, V>>(&mut table.id, old_tail_k).next = option::some(k);
            option::some(old_tail_k)
        } else {
            option::none()
        };
        let next = option::none();
        field::add(&mut table.id, k, Node<K, V> { prev, next });
        ofield::add(&mut table.vid, k, v);
        table.size = table.size + 1;
    }

    #[syntax(index)]
    /// Immutable borrows the value associated with the key in the table `table: &LinkedObjectTable<K, V>`.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the table does not have an entry with
    /// that key `k: K`.
    public fun borrow<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>, k: K): &V {
        ofield::borrow<K, V>(&table.vid, k)
    }

    #[syntax(index)]
    /// Mutably borrows the value associated with the key in the table `table: &mut LinkedObjectTable<K, V>`.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the table does not have an entry with
    /// that key `k: K`.
    public fun borrow_mut<K: copy + drop + store, V: key + store>(
        table: &mut LinkedObjectTable<K, V>,
        k: K,
    ): &mut V {
        ofield::borrow_mut<K, V>(&mut table.vid, k)
    }

    /// Borrows the key for the previous entry of the specified key `k: K` in the table
    /// `table: &LinkedObjectTable<K, V>`. Returns None if the entry does not have a predecessor.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the table does not have an entry with
    /// that key `k: K`
    public fun prev<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>, k: K): &Option<K> {
        &field::borrow<K, Node<K, V>>(&table.id, k).prev
    }

    /// Borrows the key for the next entry of the specified key `k: K` in the table
    /// `table: &LinkedObjectTable<K, V>`. Returns None if the entry does not have a predecessor.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the table does not have an entry with
    /// that key `k: K`
    public fun next<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>, k: K): &Option<K> {
        &field::borrow<K, Node<K, V>>(&table.id, k).next
    }

    /// Removes the key-value pair in the table `table: &mut LinkedObjectTable<K, V>` and returns the value.
    /// This splices the element out of the ordering.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the table does not have an entry with
    /// that key `k: K`. Note: this is also what happens when the table is empty.
    public fun remove<K: copy + drop + store, V: key + store>(table: &mut LinkedObjectTable<K, V>, k: K): V {
        let Node<K, V> { prev, next } = field::remove(&mut table.id, k);
        let v = ofield::remove(&mut table.vid, k);
        table.size = table.size - 1;
        if (option::is_some(&prev)) {
            field::borrow_mut<K, Node<K, V>>(&mut table.id, *option::borrow(&prev)).next = next
        };
        if (option::is_some(&next)) {
            field::borrow_mut<K, Node<K, V>>(&mut table.id, *option::borrow(&next)).prev = prev
        };
        if (option::borrow(&table.head) == &k) table.head = next;
        if (option::borrow(&table.tail) == &k) table.tail = prev;
        v
    }

    /// Removes the front of the table `table: &mut LinkedObjectTable<K, V>` and returns the value.
    /// Aborts with `ETableIsEmpty` if the table is empty
    public fun pop_front<K: copy + drop + store, V: key + store>(table: &mut LinkedObjectTable<K, V>): (K, V) {
        assert!(option::is_some(&table.head), ETableIsEmpty);
        let head = *option::borrow(&table.head);
        (head, remove(table, head))
    }

    /// Removes the back of the table `table: &mut LinkedObjectTable<K, V>` and returns the value.
    /// Aborts with `ETableIsEmpty` if the table is empty
    public fun pop_back<K: copy + drop + store, V: key + store>(table: &mut LinkedObjectTable<K, V>): (K, V) {
        assert!(option::is_some(&table.tail), ETableIsEmpty);
        let tail = *option::borrow(&table.tail);
        (tail, remove(table, tail))
    }

    /// Returns true iff there is a value associated with the key `k: K` in table
    /// `table: &LinkedObjectTable<K, V>`
    public fun contains<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>, k: K): bool {
        field::exists_with_type<K, Node<K, V>>(&table.id, k)
    }

    /// Returns the size of the table, the number of key-value pairs
    public fun length<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>): u64 {
        table.size
    }

    /// Returns true iff the table is empty (if `length` returns `0`)
    public fun is_empty<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>): bool {
        table.size == 0
    }

    /// Destroys an empty table
    public fun destroy_empty<K: copy + drop + store, V: key + store>(table: LinkedObjectTable<K, V>) {
        let LinkedObjectTable { id, vid, size, head: _, tail: _ } = table;
        assert!(size == 0, ETableNotEmpty);
        object::delete(id);
        object::delete(vid);
    }

    public macro fun do_ref<$K, $V>($lot: &LinkedObjectTable<$K, $V>, $f: |$K, &$V|) {
        let lot = $lot;
        let mut front = lot.front();
        while (front.is_some()) {
            let key = *front.borrow();
            let value = lot.borrow(key);
            $f(key, value);
            front = lot.next(key);
        };
    }

    public macro fun do_mut<$K, $V>($lot: &mut LinkedObjectTable<$K, $V>, $f: |$K, &mut $V|) {
        let lot = $lot;
        let mut front = lot.front();
        while (front.is_some()) {
            let key = *front.borrow();
            let value = lot.borrow_mut(key);
            $f(key, value);
            front = lot.next(key);
        };
    }
}
