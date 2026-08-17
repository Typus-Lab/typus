// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module implements a `LinkedSet`, a data structure that stores a set of keys in a doubly-linked list.
/// It is similar to `sui::linked_set` but only stores keys, not values. This is useful when you need to
/// maintain an ordered set of unique elements.
module typus::linked_set {
    use sui::dynamic_field as field;


    // ======== Error Code ========

    /// Error when trying to destroy a non-empty set.
    const ESetNotEmpty: u64 = 0;
    /// Error when trying to pop from an empty set.
    const ESetIsEmpty: u64 = 1;

    // ======== Structs ========

    /// A doubly-linked list of unique keys.
    public struct LinkedSet<K: copy + drop + store> has key, store {
        /// The UID for storing the nodes of the linked list.
        id: UID,
        /// The number of keys in the set.
        size: u64,
        /// The first key in the set.
        head: Option<K>,
        /// The last key in the set.
        tail: Option<K>,
    }

    /// A node in the linked list, containing pointers to the previous and next keys.
    public struct Node<K: copy + drop + store> has store {
        /// The previous key in the list.
        prev: Option<K>,
        /// The next key in the list.
        next: Option<K>,
    }

    // ======== Public Functions ========

    /// Creates a new, empty `LinkedSet`.
    public fun new<K: copy + drop + store>(ctx: &mut TxContext): LinkedSet<K> {
        LinkedSet {
            id: object::new(ctx),
            size: 0,
            head: option::none(),
            tail: option::none(),
        }
    }

    /// Returns the first key in the set, or `None` if the set is empty.
    public fun front<K: copy + drop + store>(set: &LinkedSet<K>): &Option<K> {
        &set.head
    }

    /// Returns the last key in the set, or `None` if the set is empty.
    public fun back<K: copy + drop + store>(set: &LinkedSet<K>): &Option<K> {
        &set.tail
    }

    /// Inserts a key at the front of the set.
    /// Aborts if the key already exists.
    public fun push_front<K: copy + drop + store>(
        set: &mut LinkedSet<K>,
        k: K,
    ) {
        let old_head = option::swap_or_fill(&mut set.head, k);
        if (option::is_none(&set.tail)) option::fill(&mut set.tail, k);
        let prev = option::none();
        let next = if (option::is_some(&old_head)) {
            let old_head_k = option::destroy_some(old_head);
            field::borrow_mut<K, Node<K>>(&mut set.id, old_head_k).prev = option::some(k);
            option::some(old_head_k)
        } else {
            option::none()
        };
        field::add(&mut set.id, k, Node<K> { prev, next });
        set.size = set.size + 1;
    }

    /// Inserts a key at the back of the set.
    /// Aborts if the key already exists.
    public fun push_back<K: copy + drop + store>(
        set: &mut LinkedSet<K>,
        k: K,
    ) {
        if (option::is_none(&set.head)) option::fill(&mut set.head, k);
        let old_tail = option::swap_or_fill(&mut set.tail, k);
        let prev = if (option::is_some(&old_tail)) {
            let old_tail_k = option::destroy_some(old_tail);
            field::borrow_mut<K, Node<K>>(&mut set.id, old_tail_k).next = option::some(k);
            option::some(old_tail_k)
        } else {
            option::none()
        };
        let next = option::none();
        field::add(&mut set.id, k, Node<K> { prev, next });
        set.size = set.size + 1;
    }

    /// Returns the previous key for the specified key.
    /// Returns `None` if there is no previous key.
    /// Aborts if the key does not exist.
    public fun prev<K: copy + drop + store>(set: &LinkedSet<K>, k: K): &Option<K> {
        &field::borrow<K, Node<K>>(&set.id, k).prev
    }

    /// Returns the next key for the specified key.
    /// Returns `None` if there is no next key.
    /// Aborts if the key does not exist.
    public fun next<K: copy + drop + store>(set: &LinkedSet<K>, k: K): &Option<K> {
        &field::borrow<K, Node<K>>(&set.id, k).next
    }

    /// Removes the key from the set.
    /// Aborts if the key does not exist.
    public fun remove<K: copy + drop + store>(set: &mut LinkedSet<K>, k: K) {
        let Node<K> { prev, next } = field::remove(&mut set.id, k);
        set.size = set.size - 1;
        if (option::is_some(&prev)) {
            field::borrow_mut<K, Node<K>>(&mut set.id, *option::borrow(&prev)).next = next
        };
        if (option::is_some(&next)) {
            field::borrow_mut<K, Node<K>>(&mut set.id, *option::borrow(&next)).prev = prev
        };
        if (option::borrow(&set.head) == &k) set.head = next;
        if (option::borrow(&set.tail) == &k) set.tail = prev;
    }

    /// Removes the first key from the set and returns it.
    /// Aborts if the set is empty.
    public fun pop_front<K: copy + drop + store>(set: &mut LinkedSet<K>): K {
        assert!(option::is_some(&set.head), ESetIsEmpty);
        let head = *option::borrow(&set.head);
        remove(set, head);
        head
    }

    /// Removes the last key from the set and returns it.
    /// Aborts if the set is empty.
    public fun pop_back<K: copy + drop + store>(set: &mut LinkedSet<K>): K {
        assert!(option::is_some(&set.tail), ESetIsEmpty);
        let tail = *option::borrow(&set.tail);
        remove(set, tail);
        tail
    }

    /// Returns `true` if the set contains the given key.
    public fun contains<K: copy + drop + store>(set: &LinkedSet<K>, k: K): bool {
        field::exists_with_type<K, Node<K>>(&set.id, k)
    }

    /// Returns the number of keys in the set.
    public fun length<K: copy + drop + store>(set: &LinkedSet<K>): u64 {
        set.size
    }

    /// Returns `true` if the set is empty.
    public fun is_empty<K: copy + drop + store>(set: &LinkedSet<K>): bool {
        set.size == 0
    }

    /// Destroys an empty set.
    /// Aborts if the set is not empty.
    public fun destroy_empty<K: copy + drop + store>(set: LinkedSet<K>) {
        let LinkedSet { id, size, head: _, tail: _ } = set;
        assert!(size == 0, ESetNotEmpty);
        object::delete(id);
    }

    /// Destroys a set, regardless of whether it is empty or not.
    public fun drop<K: copy + drop + store>(set: LinkedSet<K>) {
        let LinkedSet { id, size: _, head: _, tail: _ } = set;
        object::delete(id)
    }
}
