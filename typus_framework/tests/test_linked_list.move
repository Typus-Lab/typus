#[test_only]
extend module typus_framework::linked_list {
    use sui::test_scenario;

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_abort() {
        new<u64, u64>(object::id_from_address(@0xA));
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_node_abort() {
        new_node<u64, u64>(0, option::none(), option::none());
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_node_exists_abort() {
        node_exists<u64, u64>(&Node {
            value: 0,
            prev: option::none(),
            next: option::none(),
            exists: false,
        });
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_node_value_abort() {
        node_value<u64, u64>(&Node {
            value: 0,
            prev: option::none(),
            next: option::none(),
            exists: false,
        });
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_first_abort() {
        first<u64, u64>(&LinkedList {
            id: object::id_from_address(@0xA),
            first: option::none(),
            last: option::none(),
            length: 0,
        });
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_last_abort() {
        last<u64, u64>(&LinkedList {
            id: object::id_from_address(@0xA),
            first: option::none(),
            last: option::none(),
            length: 0,
        });
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_length_abort() {
        length<u64, u64>(&LinkedList {
            id: object::id_from_address(@0xA),
            first: option::none(),
            last: option::none(),
            length: 0,
        });
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_is_empty_abort() {
        is_empty<u64, u64>(&LinkedList {
            id: object::id_from_address(@0xA),
            first: option::none(),
            last: option::none(),
            length: 0,
        });
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_push_front_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let mut linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        push_front(
            &mut id,
            &mut linked_list,
            0,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_push_back_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let mut linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        push_back(
            &mut id,
            &mut linked_list,
            0,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_put_front_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let mut linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        put_front(
            &mut id,
            &mut linked_list,
            0,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_put_back_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let mut linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        put_back(
            &mut id,
            &mut linked_list,
            0,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_pop_front_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let mut linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        pop_front(
            &mut id,
            &mut linked_list,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_pop_back_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let mut linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        pop_back(
            &mut id,
            &mut linked_list,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_remove_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let mut linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        remove(
            &mut id,
            &mut linked_list,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_take_front_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let mut linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        take_front(
            &mut id,
            &mut linked_list,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_take_back_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let mut linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        take_back(
            &mut id,
            &mut linked_list,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_delete_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let mut linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        delete(
            &mut id,
            &mut linked_list,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_chain_abort() {
        chain<u64, u64>(
            &mut LinkedList {
                id: object::id_from_address(@0xA),
                first: option::none(),
                last: option::none(),
                length: 0,
            },
            &mut LinkedList {
                id: object::id_from_address(@0xA),
                first: option::none(),
                last: option::none(),
                length: 0,
            },
        );
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_contains_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let id = object::new(scenario.ctx());
        let linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        contains(
            &id,
            &linked_list,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_borrow_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let id = object::new(scenario.ctx());
        let linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        borrow(
            &id,
            &linked_list,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_borrow_mut_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        let linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        borrow_mut(
            &mut id,
            &linked_list,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_prev_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let id = object::new(scenario.ctx());
        let linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        prev(
            &id,
            &linked_list,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_next_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let id = object::new(scenario.ctx());
        let linked_list = LinkedList<u64, u64> {
            id: object::uid_to_inner(&id),
            first: option::none(),
            last: option::none(),
            length: 0,
        };
        next(
            &id,
            &linked_list,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_push_node_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        push_node(
            &mut id,
            0,
            Node {
                value: 0,
                prev: option::none(),
                next: option::none(),
                exists: false,
            },
        );
        id.delete();
        scenario.end();
    }
    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_put_node_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        put_node(
            &mut id,
            0,
            Node {
                value: 0,
                prev: option::none(),
                next: option::none(),
                exists: false,
            },
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_pop_node_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        pop_node<u64, u64>(
            &mut id,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_take_node_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        take_node<u64, u64>(
            &mut id,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_prepare_node_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        prepare_node(
            &mut id,
            0,
            0,
        );
        id.delete();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_remove_node_abort() {
        let mut scenario = test_scenario::begin(@0xA);
        let mut id = object::new(scenario.ctx());
        remove_node<u64, u64>(
            &mut id,
            0,
        );
        id.delete();
        scenario.end();
    }
}