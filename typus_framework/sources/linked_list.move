module typus_framework::linked_list {
    use sui::dynamic_field as field;

    // ======== Errors ========

    const E_ID_MISMATCH: u64 = 0;
    const E_KEY_NOT_EXISTS: u64 = 1;
    const E_KEY_ALREADY_EXISTS: u64 = 2;
    const E_NODE_STILL_EXISTS: u64 = 3;

    // ======== Structs ========

    /// A doubly linked list implementation using dynamic fields.
    public struct LinkedList<K: copy + drop + store, phantom V: store> has drop, store {
        /// The `ID` of the object that holds the nodes as dynamic fields.
        id: ID,
        /// The key of the first element in the list.
        first: Option<K>,
        /// The key of the last element in the list.
        last: Option<K>,
        /// The number of elements in the list.
        length: u64,
    }

    /// Represents a node in the linked list.
    public struct Node<K: copy + drop + store, V: store> has copy, drop, store {
        /// The value stored in the node.
        value: V,
        /// The key of the previous element in the list.
        prev: Option<K>,
        /// The key of the next element in the list.
        next: Option<K>,
        /// A boolean to indicate if the node is currently part of the list (for lazy deletion).
        exists: bool,
    }

    // ======== Public Functions ========

    /// Creates a new, empty `LinkedList`.
    public fun new<K: copy + drop + store, V: store>(id: ID): LinkedList<K, V> {
        LinkedList<K, V> {
            id,
            first: option::none(),
            last: option::none(),
            length: 0,
        }
    }

    /// Creates a new `Node`.
    public fun new_node<K: copy + drop + store, V: store>(
        value: V,
        prev: Option<K>,
        next: Option<K>,
    ): Node<K, V> {
        Node<K, V> {
            value,
            prev,
            next,
            exists: true,
        }
    }

    /// Checks if a node exists.
    public fun node_exists<K: copy + drop + store, V: store>(node: &Node<K, V>): bool {
        node.exists
    }

    /// Returns a reference to the value of a node.
    public fun node_value<K: copy + drop + store, V: store>(node: &Node<K, V>): &V {
        &node.value
    }

    /// Returns the key of the first element in the list.
    public fun first<K: copy + drop + store, V: store>(linked_list: &LinkedList<K, V>): Option<K> {
        linked_list.first
    }

    /// Returns the key of the last element in the list.
    public fun last<K: copy + drop + store, V: store>(linked_list: &LinkedList<K, V>): Option<K> {
        linked_list.last
    }

    /// Returns the number of elements in the list.
    public fun length<K: copy + drop + store, V: store>(linked_list: &LinkedList<K, V>): u64 {
        linked_list.length
    }

    /// Checks if the list is empty.
    public fun is_empty<K: copy + drop + store, V: store>(linked_list: &LinkedList<K, V>): bool {
        linked_list.length == 0
    }

    /// Adds an element to the front of the list.
    /// WARNING: mut inputs without authority check inside
    public fun push_front<K: copy + drop + store, V: drop + store>(
        uid: &mut UID,
        linked_list: &mut LinkedList<K, V>,
        key: K,
        value: V,
    ) {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        linked_list.length = linked_list.length + 1;
        // update last
        if (option::is_none(&linked_list.last)) {
            linked_list.last = option::some(key);
        };
        // update current first
        if (option::is_some(&linked_list.first)) {
            let next_node = field::borrow_mut<K, Node<K, V>>(uid, *option::borrow<K>(&linked_list.first));
            next_node.prev = option::some(key);
        };
        // update node
        let next = linked_list.first;
        push_node(
            uid,
            key,
            new_node(
                value,
                option::none(),
                next,
            )
        );
        // set new first
        linked_list.first = option::some(key);
    }

    /// Adds an element to the back of the list.
    /// WARNING: mut inputs without authority check inside
    public fun push_back<K: copy + drop + store, V: drop + store>(
        uid: &mut UID,
        linked_list: &mut LinkedList<K, V>,
        key: K,
        value: V,
    ) {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        linked_list.length = linked_list.length + 1;
        // update first
        if (option::is_none(&linked_list.first)) {
            linked_list.first = option::some(key);
        };
        // update current last
        if (option::is_some(&linked_list.last)) {
            let prev_node = field::borrow_mut<K, Node<K, V>>(uid, *option::borrow<K>(&linked_list.last));
            prev_node.next = option::some(key);
        };
        // update node
        let prev = linked_list.last;
        push_node(
            uid,
            key,
            new_node(
                value,
                prev,
                option::none(),
            )
        );
        // set new last
        linked_list.last = option::some(key);
    }

    /// Adds an element to the front of the list, returning the previous value if the key already existed.
    /// WARNING: mut inputs without authority check inside
    public fun put_front<K: copy + drop + store, V: store>(
        uid: &mut UID,
        linked_list: &mut LinkedList<K, V>,
        key: K,
        value: V,
    ): Option<V> {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        linked_list.length = linked_list.length + 1;
        // update last
        if (option::is_none(&linked_list.last)) {
            linked_list.last = option::some(key);
        };
        // update current first
        if (option::is_some(&linked_list.first)) {
            let next_node = field::borrow_mut<K, Node<K, V>>(uid, *option::borrow<K>(&linked_list.first));
            next_node.prev = option::some(key);
        };
        // update node
        let next = linked_list.first;
        let previous_value = put_node(
            uid,
            key,
            new_node(
                value,
                option::none(),
                next,
            )
        );
        // set new first
        linked_list.first = option::some(key);

        previous_value
    }

    /// Adds an element to the back of the list, returning the previous value if the key already existed.
    /// WARNING: mut inputs without authority check inside
    public fun put_back<K: copy + drop + store, V: store>(
        uid: &mut UID,
        linked_list: &mut LinkedList<K, V>,
        key: K,
        value: V,
    ): Option<V> {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        linked_list.length = linked_list.length + 1;
        // update first
        if (option::is_none(&linked_list.first)) {
            linked_list.first = option::some(key);
        };
        // update current last
        if (option::is_some(&linked_list.last)) {
            let prev_node = field::borrow_mut<K, Node<K, V>>(uid, *option::borrow<K>(&linked_list.last));
            prev_node.next = option::some(key);
        };
        // update node
        let prev = linked_list.last;
        let previous_value = put_node(
            uid,
            key,
            new_node(
                value,
                prev,
                option::none(),
            )
        );
        // set new last
        linked_list.last = option::some(key);

        previous_value
    }

    /// Removes and returns the element from the front of the list.
    /// WARNING: mut inputs without authority check inside
    public fun pop_front<K: copy + drop + store, V: copy + store>(
        uid: &mut UID,
        linked_list: &mut LinkedList<K, V>,
    ): (K, V) {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        linked_list.length = linked_list.length - 1;
        let key = *option::borrow(&linked_list.first);
        // update first
        let next = next(uid, linked_list, key);
        linked_list.first = next;
        // update next
        if (option::is_some(&next)) {
            field::borrow_mut<K, Node<K, V>>(uid, *option::borrow(&next)).prev = option::none();
        }
        else {
            linked_list.last = option::none();
        };
        (key, pop_node(uid, key))
    }

    /// Removes and returns the element from the back of the list.
    /// WARNING: mut inputs without authority check inside
    public fun pop_back<K: copy + drop + store, V: copy + store>(
        uid: &mut UID,
        linked_list: &mut LinkedList<K, V>,
    ): (K, V) {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        linked_list.length = linked_list.length - 1;
        let key = *option::borrow(&linked_list.last);
        // update last
        let prev = prev(uid, linked_list, key);
        linked_list.last = prev;
        // update first
        if (option::is_some(&prev)) {
            field::borrow_mut<K, Node<K, V>>(uid, *option::borrow(&prev)).next = option::none();
        }
        else {
            linked_list.first = option::none();
        };
        (key, pop_node(uid, key))
    }

    /// Removes and returns an element from the list by its key.
    /// WARNING: mut inputs without authority check inside
    public fun remove<K: copy + drop + store, V: copy + store>(
        uid: &mut UID,
        linked_list: &mut LinkedList<K, V>,
        key: K,
    ): V {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        linked_list.length = linked_list.length - 1;
        let node = field::borrow<K, Node<K, V>>(uid, key);
        let prev = node.prev;
        let next = node.next;
        // update prev
        if (option::is_none(&prev)) {
            linked_list.first = next;
        } else {
            let prev_node = field::borrow_mut<K, Node<K, V>>(uid, *option::borrow<K>(&prev));
            prev_node.next = next;
        };
        // update next
        if (option::is_none(&next)) {
            linked_list.last = prev;
        } else {
            let next_node = field::borrow_mut<K, Node<K, V>>(uid, *option::borrow<K>(&next));
            next_node.prev = prev;
        };
        pop_node(uid, key)
    }

    /// Removes and returns the element from the front of the list, consuming the node.
    /// WARNING: mut inputs without authority check inside
    public fun take_front<K: copy + drop + store, V: store>(
        uid: &mut UID,
        linked_list: &mut LinkedList<K, V>,
    ): (K, V) {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        linked_list.length = linked_list.length - 1;
        let key = *option::borrow(&linked_list.first);
        // update first
        let next = next(uid, linked_list, key);
        linked_list.first = next;
        // update next
        if (option::is_some(&next)) {
            field::borrow_mut<K, Node<K, V>>(uid, *option::borrow(&next)).prev = option::none();
        }
        else {
            linked_list.last = option::none();
        };
        (key, take_node(uid, key))
    }

    /// Removes and returns the element from the back of the list, consuming the node.
    /// WARNING: mut inputs without authority check inside
    public fun take_back<K: copy + drop + store, V: store>(
        uid: &mut UID,
        linked_list: &mut LinkedList<K, V>,
    ): (K, V) {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        linked_list.length = linked_list.length - 1;
        let key = *option::borrow(&linked_list.last);
        // update last
        let prev = prev(uid, linked_list, key);
        linked_list.last = prev;
        // update first
        if (option::is_some(&prev)) {
            field::borrow_mut<K, Node<K, V>>(uid, *option::borrow(&prev)).next = option::none();
        }
        else {
            linked_list.first = option::none();
        };
        (key, take_node(uid, key))
    }

    /// Removes and returns an element from the list by its key, consuming the node.
    /// WARNING: mut inputs without authority check inside
    public fun delete<K: copy + drop + store, V: copy + store>(
        uid: &mut UID,
        linked_list: &mut LinkedList<K, V>,
        key: K,
    ): V {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        linked_list.length = linked_list.length - 1;
        let node = field::borrow<K, Node<K, V>>(uid, key);
        let prev = node.prev;
        let next = node.next;
        // update prev
        if (option::is_none(&prev)) {
            linked_list.first = next;
        } else {
            let prev_node = field::borrow_mut<K, Node<K, V>>(uid, *option::borrow<K>(&prev));
            prev_node.next = next;
        };
        // update next
        if (option::is_none(&next)) {
            linked_list.last = prev;
        } else {
            let next_node = field::borrow_mut<K, Node<K, V>>(uid, *option::borrow<K>(&next));
            next_node.prev = prev;
        };
        take_node(uid, key)
    }

    /// Appends the elements of list `b` to the end of list `a`.
    /// WARNING: mut inputs without authority check inside
    public fun chain<K: copy + drop + store, V: store>(
        a: &mut LinkedList<K, V>,
        b: &mut LinkedList<K, V>,
    ) {
        assert!(a.id == b.id, E_ID_MISMATCH);

        if (length(b) != 0) {
            if (length(a) == 0) {
                a.first = b.first;
                a.last = b.last;
                a.length = b.length;
            }
            else {
                a.last = b.first;
                a.length = a.length + b.length;
            };
            b.first = option::none();
            b.last = option::none();
            b.length = 0;
        }
    }

    /// Checks if the list contains a given key.
    public fun contains<K: copy + drop + store, V: store>(uid: &UID, linked_list: &LinkedList<K, V>, key: K): bool {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        field::exists_(uid, key) && field::borrow<K, Node<K, V>>(uid, key).exists
    }

    /// Borrows a reference to the value of an element in the list by its key.
    public fun borrow<K: copy + drop + store, V: store>(
        uid: &UID,
        linked_list: &LinkedList<K, V>,
        key: K,
    ): &V {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        let Node {
            value,
            prev: _,
            next: _,
            exists,
        } = field::borrow<K, Node<K, V>>(uid, key);
        if (!*exists) {
            abort E_KEY_NOT_EXISTS
        };

        value
    }

    /// Borrows a mutable reference to the value of an element in the list by its key.
    /// WARNING: mut inputs without authority check inside
    public fun borrow_mut<K: copy + drop + store, V: store>(
        uid: &mut UID,
        linked_list: &LinkedList<K, V>,
        key: K,
    ): &mut V {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        let Node {
            value,
            prev: _,
            next: _,
            exists,
        } = field::borrow_mut<K, Node<K, V>>(uid, key);
        if (!*exists) {
            abort E_KEY_NOT_EXISTS
        };

        value
    }

    /// Returns the key of the previous element in the list.
    public fun prev<K: copy + drop + store, V: store>(
        uid: &UID,
        linked_list: &LinkedList<K, V>,
        key: K,
    ): Option<K> {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        let Node {
            value: _,
            prev,
            next: _,
            exists,
        } = field::borrow<K, Node<K, V>>(uid, key);
        if (!*exists) {
            abort E_KEY_NOT_EXISTS
        };

        *prev
    }

    /// Returns the key of the next element in the list.
    public fun next<K: copy + drop + store, V: store>(
        uid: &UID,
        linked_list: &LinkedList<K, V>,
        key: K,
    ): Option<K> {
        assert!(object::uid_to_inner(uid) == linked_list.id, E_ID_MISMATCH);

        let Node {
            value: _,
            prev: _,
            next,
            exists,
        } = field::borrow<K, Node<K, V>>(uid, key);
        if (!*exists) {
            abort E_KEY_NOT_EXISTS
        };

        *next
    }

    /// Pushes a new node into the list. This is a helper function.
    /// WARNING: mut inputs without authority check inside
    public fun push_node<K: copy + drop + store, V: drop + store>(
        uid: &mut UID,
        key: K,
        new_node: Node<K, V>,
    ) {
        if (field::exists_(uid, key)) {
            let node = field::borrow_mut<K, Node<K, V>>(uid, key);
            if (node.exists) {
                abort E_KEY_ALREADY_EXISTS
            };
            let Node {
                value,
                prev,
                next,
                exists,
            } = new_node;
            node.value = value;
            node.prev = prev;
            node.next = next;
            node.exists = exists;
        }
        else {
            field::add(uid, key, new_node);
        };
    }

    /// Puts a new node into the list, returning the previous value if the key already existed. This is a helper function.
    /// WARNING: mut inputs without authority check inside
    public fun put_node<K: copy + drop + store, V: store>(
        uid: &mut UID,
        key: K,
        new_node: Node<K, V>,
    ): Option<V> {
        let previous_value = if (field::exists_(uid, key)) {
            let Node {
                value,
                prev: _,
                next: _,
                exists,
            } = field::remove<K, Node<K, V>>(uid, key);
            if (exists) {
                abort E_KEY_ALREADY_EXISTS
            };
            option::some(value)
        }
        else {
            option::none()
        };
        field::add(uid, key, new_node);

        previous_value
    }

    /// Pops a node from the list. This is a helper function.
    /// WARNING: mut inputs without authority check inside
    public fun pop_node<K: copy + drop + store, V: copy + store>(
        uid: &mut UID,
        key: K,
    ): V {
        let Node {
            value,
            prev,
            next,
            exists,
        } = field::borrow_mut<K, Node<K, V>>(uid, key);
        if (!*exists) {
            abort E_KEY_NOT_EXISTS
        };
        *prev = option::none();
        *next = option::none();
        *exists = false;

        *value
    }

    /// Takes a node from the list, consuming it. This is a helper function.
    /// WARNING: mut inputs without authority check inside
    public fun take_node<K: copy + drop + store, V: store>(
        uid: &mut UID,
        key: K
    ): V {
        let Node {
            value,
            prev: _,
            next: _,
            exists,
        } = field::remove<K, Node<K, V>>(uid, key);
        if (!exists) {
            abort E_KEY_NOT_EXISTS
        };

        value
    }

    /// Prepares a node for use in the linked list. This is a helper function.
    /// WARNING: mut inputs without authority check inside
    public fun prepare_node<K: copy + drop + store, V: drop + store>(
        uid: &mut UID,
        key: K,
        value: V,
    ) {
        if (!field::exists_(uid, key)) {
            field::add(
                uid,
                key,
                Node<K, V> {
                    value,
                    prev: option::none(),
                    next: option::none(),
                    exists: false,
                }
            );
        }
    }

    /// Removes a node from the dynamic fields. This is a helper function.
    /// WARNING: mut inputs without authority check inside
    public fun remove_node<K: copy + drop + store, V: drop + store>(
        uid: &mut UID,
        key: K,
    ) {
        if (field::exists_(uid, key)) {
            let Node {
                value: _,
                prev: _,
                next: _,
                exists,
            } = field::remove<K, Node<K, V>>(uid, key);
            if (exists) {
                abort E_NODE_STILL_EXISTS
            }
        }
    }

    #[test_only]
    public fun print_list<K: copy + drop + store, V: store>(uid: &UID, linked_list: &LinkedList<K, V>) {
        let mut node = linked_list.first;
        while (option::is_some(&node)) {
            let prev_node = field::borrow<K, Node<K, V>>(uid, *option::borrow<K>(&node));
            std::debug::print(prev_node);
            node = prev_node.next;
        };
    }

    #[test_only]
    public fun verify_list<K: copy + drop + store, V: drop + store>(
        uid: &UID,
        linked_list: &LinkedList<K, V>,
        mut verification: vector<Node<K, V>>,
    ) {
        let mut node = linked_list.last;
        while (option::is_some(&node)) {
            let verification_node = std::vector::pop_back(&mut verification);
            let next_node = field::borrow<K, Node<K, V>>(uid, *option::borrow<K>(&node));
            assert!(next_node == &verification_node, 0);
            node = next_node.prev;
        };
    }
}



#[test_only]
module typus_framework::test_linked_list {
    use sui::test_scenario;

    use typus_framework::linked_list;

    #[test]
    fun test_push_pop(){
        let admin = @0x1;
        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        let mut uid = object::new(test_scenario::ctx(scenario));

        let mut linked_list = linked_list::new<address, u64>(object::uid_to_inner(&uid));

        linked_list::push_back(&mut uid, &mut linked_list, @0x3, 3);
        assert!(linked_list::length(&linked_list) == 1, 0);
        linked_list::push_back(&mut uid, &mut linked_list, @0x5, 5);
        assert!(linked_list::length(&linked_list) == 2, 0);
        linked_list::push_front(&mut uid, &mut linked_list, @0x2, 2);
        assert!(linked_list::length(&linked_list) == 3, 0);
        linked_list::push_front(&mut uid, &mut linked_list, @0x4, 4);
        assert!(linked_list::length(&linked_list) == 4, 0);
        linked_list::push_back(&mut uid, &mut linked_list, @0x7, 7);
        assert!(linked_list::length(&linked_list) == 5, 0);
        // linked_list::print_list(&uid, &linked_list);
        linked_list::verify_list(
            &uid,
            &linked_list,
            vector[
                linked_list::new_node(4, option::none(), option::some(@0x2)),
                linked_list::new_node(2, option::some(@0x4), option::some(@0x3)),
                linked_list::new_node(3, option::some(@0x2), option::some(@0x5)),
                linked_list::new_node(5, option::some(@0x3), option::some(@0x7)),
                linked_list::new_node(7, option::some(@0x5), option::none()),
            ],
        );

        linked_list::pop_back(&mut uid, &mut linked_list);
        assert!(linked_list::length(&linked_list) == 4, 0);
        linked_list::pop_back(&mut uid, &mut linked_list);
        assert!(linked_list::length(&linked_list) == 3, 0);
        linked_list::pop_front(&mut uid, &mut linked_list);
        assert!(linked_list::length(&linked_list) == 2, 0);
        // linked_list::print_list(&uid, &linked_list);
        linked_list::verify_list(
            &uid,
            &linked_list,
            vector[
                linked_list::new_node(2, option::none(), option::some(@0x3)),
                linked_list::new_node(3, option::some(@0x2), option::none()),
            ],
        );

        linked_list::push_back(&mut uid, &mut linked_list, @0x4, 4);
        assert!(linked_list::length(&linked_list) == 3, 0);
        linked_list::push_front(&mut uid, &mut linked_list, @0x7, 7);
        assert!(linked_list::length(&linked_list) == 4, 0);
        // linked_list::print_list(&uid, &linked_list);
        linked_list::verify_list(
            &uid,
            &linked_list,
            vector[
                linked_list::new_node(7, option::none(), option::some(@0x2)),
                linked_list::new_node(2, option::some(@0x7), option::some(@0x3)),
                linked_list::new_node(3, option::some(@0x2), option::some(@0x4)),
                linked_list::new_node(4, option::some(@0x3), option::none()),
            ],
        );

        test_scenario::end(scenario_val);
        object::delete(uid);
    }

    #[test]
    fun test_put_take(){
        let admin = @0x1;
        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        let mut uid = object::new(test_scenario::ctx(scenario));

        let mut linked_list = linked_list::new<address, u64>(object::uid_to_inner(&uid));

        linked_list::put_back(&mut uid, &mut linked_list, @0x3, 3);
        assert!(linked_list::length(&linked_list) == 1, 0);
        linked_list::put_back(&mut uid, &mut linked_list, @0x5, 5);
        assert!(linked_list::length(&linked_list) == 2, 0);
        linked_list::put_front(&mut uid, &mut linked_list, @0x2, 2);
        assert!(linked_list::length(&linked_list) == 3, 0);
        linked_list::put_front(&mut uid, &mut linked_list, @0x4, 4);
        assert!(linked_list::length(&linked_list) == 4, 0);
        linked_list::put_back(&mut uid, &mut linked_list, @0x7, 7);
        assert!(linked_list::length(&linked_list) == 5, 0);
        // linked_list::print_list(&uid, &linked_list);
        linked_list::verify_list(
            &uid,
            &linked_list,
            vector[
                linked_list::new_node(4, option::none(), option::some(@0x2)),
                linked_list::new_node(2, option::some(@0x4), option::some(@0x3)),
                linked_list::new_node(3, option::some(@0x2), option::some(@0x5)),
                linked_list::new_node(5, option::some(@0x3), option::some(@0x7)),
                linked_list::new_node(7, option::some(@0x5), option::none()),
            ],
        );

        linked_list::take_back(&mut uid, &mut linked_list);
        assert!(linked_list::length(&linked_list) == 4, 0);
        linked_list::take_back(&mut uid, &mut linked_list);
        assert!(linked_list::length(&linked_list) == 3, 0);
        linked_list::take_front(&mut uid, &mut linked_list);
        assert!(linked_list::length(&linked_list) == 2, 0);
        // linked_list::print_list(&uid, &linked_list);
        linked_list::verify_list(
            &uid,
            &linked_list,
            vector[
                linked_list::new_node(2, option::none(), option::some(@0x3)),
                linked_list::new_node(3, option::some(@0x2), option::none()),
            ],
        );

        linked_list::put_back(&mut uid, &mut linked_list, @0x4, 4);
        assert!(linked_list::length(&linked_list) == 3, 0);
        linked_list::put_front(&mut uid, &mut linked_list, @0x7, 7);
        assert!(linked_list::length(&linked_list) == 4, 0);
        // linked_list::print_list(&uid, &linked_list);
        linked_list::verify_list(
            &uid,
            &linked_list,
            vector[
                linked_list::new_node(7, option::none(), option::some(@0x2)),
                linked_list::new_node(2, option::some(@0x7), option::some(@0x3)),
                linked_list::new_node(3, option::some(@0x2), option::some(@0x4)),
                linked_list::new_node(4, option::some(@0x3), option::none()),
            ],
        );

        test_scenario::end(scenario_val);
        object::delete(uid);
    }
}