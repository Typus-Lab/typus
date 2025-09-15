// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module implements a `LinkedObjectTable`, which is similar to `sui::linked_table` but stores
/// its values as dynamic object fields. This allows the values to be objects themselves, which can be
/// useful for storing complex data structures. The table maintains a doubly-linked list of its entries,
/// allowing for efficient iteration in both forward and reverse order.
module typus::linked_object_table {
    use sui::dynamic_field as field;
    use sui::dynamic_object_field as ofield;

    // ======== Error Code ========

    /// Error when trying to destroy a non-empty table.
    const ETableNotEmpty: u64 = 0;
    /// Error when trying to pop from an empty table.
    const ETableIsEmpty: u64 = 1;

    // ======== Structs ========

    /// A doubly-linked list of key-value pairs where values are stored as dynamic object fields.
    public struct LinkedObjectTable<K: copy + drop + store, phantom V: key + store> has key, store {
        /// The UID for storing the nodes of the linked list.
        id: UID,
        /// The UID for storing the values as dynamic object fields.
        vid: UID,
        /// The number of key-value pairs in the table.
        size: u64,
        /// The key of the first entry in the table.
        head: Option<K>,
        /// The key of the last entry in the table.
        tail: Option<K>,
    }

    /// A node in the linked list, containing pointers to the previous and next keys.
    public struct Node<K: copy + drop + store, phantom V: key + store> has store {
        /// The key of the previous entry.
        prev: Option<K>,
        /// The key of the next entry.
        next: Option<K>,
    }

    // ======== Public Functions ========

    /// Creates a new, empty `LinkedObjectTable`.
    public fun new<K: copy + drop + store, V: key + store>(ctx: &mut TxContext): LinkedObjectTable<K, V> {
        LinkedObjectTable {
            id: object::new(ctx),
            vid: object::new(ctx),
            size: 0,
            head: option::none(),
            tail: option::none(),
        }
    }

    /// Returns the key of the first element in the table, or `None` if the table is empty.
    public fun front<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>): &Option<K> {
        &table.head
    }

    /// Returns the key of the last element in the table, or `None` if the table is empty.
    public fun back<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>): &Option<K> {
        &table.tail
    }

    /// Inserts a key-value pair at the front of the table.
    /// Aborts if the key already exists.
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

    /// Inserts a key-value pair at the back of the table.
    /// Aborts if the key already exists.
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

    /// Borrows an immutable reference to the value associated with the given key.
    /// Aborts if the key does not exist.
    #[syntax(index)]
    public fun borrow<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>, k: K): &V {
        ofield::borrow<K, V>(&table.vid, k)
    }

    /// Borrows a mutable reference to the value associated with the given key.
    /// Aborts if the key does not exist.
    #[syntax(index)]
    public fun borrow_mut<K: copy + drop + store, V: key + store>(
        table: &mut LinkedObjectTable<K, V>,
        k: K,
    ): &mut V {
        ofield::borrow_mut<K, V>(&mut table.vid, k)
    }

    /// Returns the key of the previous entry for the specified key.
    /// Returns `None` if there is no previous entry.
    /// Aborts if the key does not exist.
    public fun prev<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>, k: K): &Option<K> {
        &field::borrow<K, Node<K, V>>(&table.id, k).prev
    }

    /// Returns the key of the next entry for the specified key.
    /// Returns `None` if there is no next entry.
    /// Aborts if the key does not exist.
    public fun next<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>, k: K): &Option<K> {
        &field::borrow<K, Node<K, V>>(&table.id, k).next
    }

    /// Removes the key-value pair with the given key from the table and returns the value.
    /// Aborts if the key does not exist.
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

    /// Removes the first entry from the table and returns its key and value.
    /// Aborts if the table is empty.
    public fun pop_front<K: copy + drop + store, V: key + store>(table: &mut LinkedObjectTable<K, V>): (K, V) {
        assert!(option::is_some(&table.head), ETableIsEmpty);
        let head = *option::borrow(&table.head);
        (head, remove(table, head))
    }

    /// Removes the last entry from the table and returns its key and value.
    /// Aborts if the table is empty.
    public fun pop_back<K: copy + drop + store, V: key + store>(table: &mut LinkedObjectTable<K, V>): (K, V) {
        assert!(option::is_some(&table.tail), ETableIsEmpty);
        let tail = *option::borrow(&table.tail);
        (tail, remove(table, tail))
    }

    /// Returns `true` if the table contains an entry with the given key.
    public fun contains<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>, k: K): bool {
        field::exists_with_type<K, Node<K, V>>(&table.id, k)
    }

    /// Returns the number of key-value pairs in the table.
    public fun length<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>): u64 {
        table.size
    }

    /// Returns `true` if the table is empty.
    public fun is_empty<K: copy + drop + store, V: key + store>(table: &LinkedObjectTable<K, V>): bool {
        table.size == 0
    }

    /// Destroys an empty table.
    /// Aborts if the table is not empty.
    public fun destroy_empty<K: copy + drop + store, V: key + store>(table: LinkedObjectTable<K, V>) {
        let LinkedObjectTable { id, vid, size, head: _, tail: _ } = table;
        assert!(size == 0, ETableNotEmpty);
        object::delete(id);
        object::delete(vid);
    }

    /// A macro for iterating over the elements of a `LinkedObjectTable` with immutable references.
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

    /// A macro for iterating over the elements of a `LinkedObjectTable` with mutable references.
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
