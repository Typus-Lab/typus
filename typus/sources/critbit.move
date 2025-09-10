// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
module typus::critbit {
    use sui::table::{Self, Table};

    // ======== Error Code ========

    const EExceedCapacity: u64 = 0;
    const ETreeNotEmpty: u64 = 1;
    const EKeyAlreadyExist: u64 = 2;
    const ELeafNotExist: u64 = 3;
    const EIndexOutOfRange: u64 = 4;
    const ENullParent: u64 = 5;

    // === Constants ===

    const PARTITION_INDEX: u64 = 0x8000000000000000; // 9223372036854775808
    const MAX_U64: u64 = 0xFFFFFFFFFFFFFFFF; // 18446744073709551615
    const MAX_CAPACITY: u64 = 0x7fffffffffffffff;

    // === Structs ===

    /// Internal leaf type
    public struct Leaf<V> has store, drop {
        key: u64,
        value: V,
        parent: u64,
    }

    /// Internal node type
    public struct InternalNode has store, drop {
        mask: u64,
        left_child: u64,
        right_child: u64,
        parent: u64,
    }

    /// Critbit tree
    public struct CritbitTree<V: store> has store {
        root: u64,
        internal_nodes: Table<u64, InternalNode>,
        leaves: Table<u64, Leaf<V>>,
        min_leaf_index: u64,
        max_leaf_index: u64,
        next_internal_node_index: u64,
        next_leaf_index: u64
    }

    // ======== Public Functions ========

    /// Create a new critbit tree
    public fun new<V: store>(ctx: &mut TxContext): CritbitTree<V> {
        CritbitTree<V>{
            root: PARTITION_INDEX,
            internal_nodes: table::new(ctx),
            leaves: table::new(ctx),
            min_leaf_index: PARTITION_INDEX,
            max_leaf_index: PARTITION_INDEX,
            next_internal_node_index: 0,
            next_leaf_index: 0
        }
    }

    /// Return size of tree
    public fun size<V: store>(tree: &CritbitTree<V>): u64 {
        tree.leaves.length()
    }

    /// Return whether tree is empty
    public fun is_empty<V: store>(tree: &CritbitTree<V>): bool {
        tree.leaves.is_empty()
    }

    /// Return whether leaf exists
    public fun has_leaf<V: store>(tree: &CritbitTree<V>, key: u64): bool {
        let (has_leaf, _) = tree.find_leaf(key);
        has_leaf
    }

    /// Return whether index exists
    public fun has_index<V: store>(tree: &CritbitTree<V>, index: u64): bool {
        tree.leaves.contains(index)
    }

    /// Return (key, index) of the leaf with minimum value
    public fun min_leaf<V: store>(tree: &CritbitTree<V>): (u64, u64) {
        assert!(!tree.is_empty(), ELeafNotExist);
        let min_leaf = tree.leaves.borrow(tree.min_leaf_index);
        (min_leaf.key, tree.min_leaf_index)
    }

    /// Return (key, index) of the leaf with maximum value
    public fun max_leaf<V: store>(tree: &CritbitTree<V>): (u64, u64) {
        assert!(!tree.is_empty(), ELeafNotExist);
        let max_leaf = tree.leaves.borrow(tree.max_leaf_index);
        (max_leaf.key, tree.max_leaf_index)
    }

    /// Return the previous leaf (key, index) from the input leaf
    public fun previous_leaf<V: store>(tree: &CritbitTree<V>, key: u64): (u64, u64) {
        let (has_leaf, mut index) = tree.find_leaf(key);
        assert!(has_leaf, ELeafNotExist);
        let mut ptr = MAX_U64 - index;
        let mut parent = tree.leaves.borrow(index).parent;
        while (parent != PARTITION_INDEX && tree.is_left_child(parent, ptr)) {
            ptr = parent;
            parent = tree.internal_nodes.borrow(ptr).parent;
        };
        if(parent == PARTITION_INDEX) {
            return (0, PARTITION_INDEX)
        };
        index = MAX_U64 - tree.right_most_leaf(tree.internal_nodes.borrow(parent).left_child);
        (tree.leaves.borrow(index).key, index)
    }

    /// Return the next leaf (key, index) of the input leaf
    public fun next_leaf<V: store>(tree: &CritbitTree<V>, key: u64): (u64, u64) {
        let (has_leaf, mut index) = tree.find_leaf(key);
        assert!(has_leaf, ELeafNotExist);
        let mut ptr = MAX_U64 - index;
        let mut parent = tree.leaves.borrow(index).parent;
        while (parent != PARTITION_INDEX && !tree.is_left_child(parent, ptr)) {
            ptr = parent;
            parent = tree.internal_nodes.borrow(ptr).parent;
        };
        if(parent == PARTITION_INDEX) {
            return (0, PARTITION_INDEX)
        };
        index = MAX_U64 - tree.left_most_leaf(tree.internal_nodes.borrow(parent).right_child);
        (tree.leaves.borrow(index).key, index)
    }

    /// Insert new leaf to the tree, returning the index of the new leaf
    public fun insert_leaf<V: store>(tree: &mut CritbitTree<V>, key: u64, value: V): u64 {
        let new_leaf = Leaf<V>{
            key,
            value,
            parent: PARTITION_INDEX,
        };
        let new_leaf_index = tree.next_leaf_index;
        tree.next_leaf_index = tree.next_leaf_index + 1;
        assert!(new_leaf_index < MAX_CAPACITY - 1, EExceedCapacity);
        tree.leaves.add(new_leaf_index, new_leaf);

        let closest_leaf_index = tree.get_closest_leaf_index_by_key(key);

        // handle the first insertion
        if(closest_leaf_index == PARTITION_INDEX) {
            assert!(new_leaf_index == 0, ETreeNotEmpty);
            tree.root = MAX_U64 - new_leaf_index;
            tree.min_leaf_index = new_leaf_index;
            tree.max_leaf_index = new_leaf_index;
            return 0
        };

        let closest_key = tree.leaves.borrow(closest_leaf_index).key;
        assert!(closest_key != key, EKeyAlreadyExist);

        // note that we reserve count_leading_zeros of form u128 for future usage
        let critbit = 64 - (count_leading_zeros(((closest_key ^ key) as u128) ) - 64);
        let new_mask = 1u64 << (critbit - 1);

        let new_internal_node = InternalNode{
            mask: new_mask,
            left_child: PARTITION_INDEX,
            right_child: PARTITION_INDEX,
            parent: PARTITION_INDEX,
        };
        let new_internal_node_index = tree.next_internal_node_index;
        tree.next_internal_node_index = tree.next_internal_node_index + 1;
        tree.internal_nodes.add(new_internal_node_index, new_internal_node);

        let mut ptr = tree.root;
        let mut new_internal_node_parent_index = PARTITION_INDEX;
        // search position of the new internal node
        while (ptr < PARTITION_INDEX) {
            let internal_node = tree.internal_nodes.borrow(ptr);
            if (new_mask > internal_node.mask) {
                break
            };
            new_internal_node_parent_index = ptr;
            if (key & internal_node.mask == 0) {
                ptr = internal_node.left_child;
            }else {
                ptr = internal_node.right_child;
            };
        };

        // we update the child info of new internal node's parent
        if (new_internal_node_parent_index == PARTITION_INDEX) {
            // if the new internal node is root
            tree.root = new_internal_node_index;
        } else{
            // In another case, we update the child field of the new internal node's parent
            // and the parent field of the new internal node
            let is_left_child = tree.is_left_child(new_internal_node_parent_index, ptr);
            tree.update_child(new_internal_node_parent_index, new_internal_node_index, is_left_child);
        };

        // finally, we update the child filed of the new internal node
        let is_left_child = new_mask & key == 0;
        tree.update_child(new_internal_node_index, MAX_U64 - new_leaf_index, is_left_child);
        tree.update_child(new_internal_node_index, ptr, !is_left_child);

        if (tree.leaves.borrow(tree.min_leaf_index).key > key) {
            tree.min_leaf_index = new_leaf_index;
        };
        if (tree.leaves.borrow(tree.max_leaf_index).key < key) {
            tree.max_leaf_index = new_leaf_index;
        };
        new_leaf_index
    }

    /// Return true and the index if the leaf exists
    public fun find_leaf<V: store>(tree: & CritbitTree<V>, key: u64): (bool, u64) {
        if (tree.is_empty()) {
            return (false, PARTITION_INDEX)
        };
        let closest_leaf_index = tree.get_closest_leaf_index_by_key(key);
        let closeset_leaf = tree.leaves.borrow(closest_leaf_index);
        if (closeset_leaf.key != key) {
            (false, PARTITION_INDEX)
        } else {
            (true, closest_leaf_index)
        }
    }

    /// Return true and the index if the leaf exists
    public fun find_closest_key<V: store>(tree: & CritbitTree<V>, key: u64): u64 {
        if (tree.is_empty()) {
            return 0
        };
        let closest_leaf_index = tree.get_closest_leaf_index_by_key(key);
        let closeset_leaf = tree.leaves.borrow(closest_leaf_index);
        closeset_leaf.key
    }

    /// Remove min leaf from the tree
    public fun remove_min_leaf<V: store>(tree: &mut CritbitTree<V>): V {
        let index = tree.min_leaf_index;
        tree.remove_leaf_by_index(index)
    }

    /// Remove max leaf from the tree
    public fun remove_max_leaf<V: store>(tree: &mut CritbitTree<V>): V {
        let index = tree.max_leaf_index;
        tree.remove_leaf_by_index(index)
    }

    /// Remove leaf from the tree by index
    public fun remove_leaf_by_index<V: store>(tree: &mut CritbitTree<V>, index: u64): V {
        let key = tree.leaves.borrow(index).key;
        if(tree.min_leaf_index == index) {
            let (_, next_index) = tree.next_leaf(key);
            tree.min_leaf_index = next_index;
        };
        if(tree.max_leaf_index == index) {
            let (_, previous_index) = tree.previous_leaf(key);
            tree.max_leaf_index = previous_index;
        };

        let mut is_left_child_;
        let Leaf<V> {key: _, value, parent: removed_leaf_parent_index} = tree.leaves.remove(index);
        if (size(tree) == 0) {
            tree.root = PARTITION_INDEX;
            tree.min_leaf_index = PARTITION_INDEX;
            tree.max_leaf_index = PARTITION_INDEX;
            tree.next_internal_node_index = 0;
            tree.next_leaf_index = 0;
        } else{
            assert!(removed_leaf_parent_index != PARTITION_INDEX, EIndexOutOfRange);
            let removed_leaf_parent = tree.internal_nodes.borrow(removed_leaf_parent_index);
            let removed_leaf_grand_parent_index = removed_leaf_parent.parent;

            // note that sibling of the removed leaf can be a leaf or a internal node
            is_left_child_ = tree.is_left_child(removed_leaf_parent_index, MAX_U64 - index);
            let sibling_index = if (is_left_child_) { removed_leaf_parent.right_child }
            else { removed_leaf_parent.left_child };

            if (removed_leaf_grand_parent_index == PARTITION_INDEX) {
                // parent of the removed leaf is the tree root
                // update the parent of the sibling node and and set sibling as the tree root
                if (sibling_index < PARTITION_INDEX) {
                    // sibling is a internal node
                    tree.internal_nodes.borrow_mut(sibling_index).parent = PARTITION_INDEX;
                } else{
                    // sibling is a leaf
                    tree.leaves.borrow_mut(MAX_U64 - sibling_index).parent = PARTITION_INDEX;
                };
                tree.root = sibling_index;
            } else {
                // grand parent of the removed leaf is a internal node
                // set sibling as the child of the grand parent of the removed leaf
                is_left_child_ = tree.is_left_child(removed_leaf_grand_parent_index, removed_leaf_parent_index);
                tree.update_child(removed_leaf_grand_parent_index, sibling_index, is_left_child_);
            };
            tree.internal_nodes.remove(removed_leaf_parent_index);
        };
        value
    }

    /// Remove leaf from the tree by key
    public fun remove_leaf_by_key<V: store>(tree: &mut CritbitTree<V>, key: u64): V {
        let (is_exist, index) = tree.find_leaf(key);
        assert!(is_exist, ELeafNotExist);
        tree.remove_leaf_by_index(index)
    }

    /// Mutably borrow leaf from the tree by index
    public fun borrow_mut_leaf_by_index<V: store>(tree: &mut CritbitTree<V>, index: u64): &mut V {
        let entry = tree.leaves.borrow_mut(index);
        &mut entry.value
    }

    /// Mutably borrow leaf from the tree by key
    public fun borrow_mut_leaf_by_key<V: store>(tree: &mut CritbitTree<V>, key: u64): &mut V {
        let (is_exist, index) = tree.find_leaf(key);
        assert!(is_exist, ELeafNotExist);
        tree.borrow_mut_leaf_by_index(index)
    }

    /// Borrow leaf from the tree by index
    public fun borrow_leaf_by_index<V: store>(tree: & CritbitTree<V>, index: u64): &V {
        let entry = tree.leaves.borrow(index);
        &entry.value
    }

    /// Borrow leaf from the tree by key
    public fun borrow_leaf_by_key<V: store>(tree: & CritbitTree<V>, key: u64): &V {
        let (is_exist, index) = tree.find_leaf(key);
        assert!(is_exist, ELeafNotExist);
        tree.borrow_leaf_by_index(index)
    }

    /// Destroy tree dropping all the entries within
    public fun drop<V: store + drop>(tree: CritbitTree<V>) {
        let CritbitTree<V> {
            root: _,
            internal_nodes,
            leaves,
            min_leaf_index: _,
            max_leaf_index: _,
            next_internal_node_index: _,
            next_leaf_index: _,

        } = tree;
        internal_nodes.drop();
        leaves.drop();
    }

    /// Destroy empty tree
    public fun destroy_empty<V: store>(tree: CritbitTree<V>) {
        assert!(tree.leaves.length() == 0, 0);

        let CritbitTree<V> {
            root: _,
            leaves,
            internal_nodes,
            min_leaf_index: _,
            max_leaf_index: _,
            next_internal_node_index: _,
            next_leaf_index: _,
        } = tree;
        leaves.destroy_empty();
        internal_nodes.destroy_empty();
    }

    // === Helper functions ===

    fun left_most_leaf<V: store>(tree: &CritbitTree<V>, root: u64): u64 {
        let mut ptr = root;
        while (ptr < PARTITION_INDEX) {
            ptr = tree.internal_nodes.borrow(ptr).left_child;
        };
        ptr
    }

    fun right_most_leaf<V: store>(tree: &CritbitTree<V>, root: u64): u64 {
        let mut ptr = root;
        while (ptr < PARTITION_INDEX) {
            ptr = tree.internal_nodes.borrow(ptr).right_child;
        };
        ptr
    }

    fun get_closest_leaf_index_by_key<V: store>(tree: &CritbitTree<V>, key: u64): u64 {
        let mut ptr = tree.root;
        // if tree is empty, return the patrition index
        if(ptr == PARTITION_INDEX) return PARTITION_INDEX;
        while (ptr < PARTITION_INDEX) {
            let node = tree.internal_nodes.borrow(ptr);
            if (key & node.mask == 0) {
                ptr = node.left_child;
            } else {
                ptr = node.right_child;
            }
        };
        MAX_U64 - ptr
    }

    fun update_child<V: store>(tree: &mut CritbitTree<V>, parent_index: u64, new_child: u64, is_left_child: bool) {
        assert!(parent_index != PARTITION_INDEX, ENullParent);
        if (is_left_child) {
            tree.internal_nodes.borrow_mut(parent_index).left_child = new_child;
        } else{
            tree.internal_nodes.borrow_mut(parent_index).right_child = new_child;
        };
        if (new_child != PARTITION_INDEX) {
            if (new_child > PARTITION_INDEX) {
                tree.leaves.borrow_mut(MAX_U64 - new_child).parent = parent_index;
            }else{
                tree.internal_nodes.borrow_mut(new_child).parent = parent_index;
            }
        };
    }

    fun is_left_child<V: store>(tree: &CritbitTree<V>, parent_index: u64, index: u64): bool {
        tree.internal_nodes.borrow(parent_index).left_child == index
    }

    fun count_leading_zeros(mut x: u128): u8 {
        if (x == 0) {
            128
        } else {
            let mut n: u8 = 0;
            if (x & 0xFFFFFFFFFFFFFFFF0000000000000000 == 0) {
                // x's higher 64 is all zero, shift the lower part over
                x = x << 64;
                n = n + 64;
            };
            if (x & 0xFFFFFFFF000000000000000000000000 == 0) {
                // x's higher 32 is all zero, shift the lower part over
                x = x << 32;
                n = n + 32;
            };
            if (x & 0xFFFF0000000000000000000000000000 == 0) {
                // x's higher 16 is all zero, shift the lower part over
                x = x << 16;
                n = n + 16;
            };
            if (x & 0xFF000000000000000000000000000000 == 0) {
                // x's higher 8 is all zero, shift the lower part over
                x = x << 8;
                n = n + 8;
            };
            if (x & 0xF0000000000000000000000000000000 == 0) {
                // x's higher 4 is all zero, shift the lower part over
                x = x << 4;
                n = n + 4;
            };
            if (x & 0xC0000000000000000000000000000000 == 0) {
                // x's higher 2 is all zero, shift the lower part over
                x = x << 2;
                n = n + 2;
            };
            if (x & 0x80000000000000000000000000000000 == 0) {
                n = n + 1;
            };
            n
        }
    }

    #[test]
    public fun test_cribit() {
        use sui::test_scenario;

        let address = @0x1;
        let mut scenario = test_scenario::begin(address);

        let mut critbit_tree = new<u64>(test_scenario::ctx(&mut scenario));
        std::debug::print(&std::string::utf8(b"insert_leaf"));
        std::debug::print(&insert_leaf(&mut critbit_tree, 11111, 11111));
        std::debug::print(&insert_leaf(&mut critbit_tree, 22222, 22222));
        std::debug::print(&insert_leaf(&mut critbit_tree, 4, 4));
        std::debug::print(&insert_leaf(&mut critbit_tree, 200, 200));
        std::debug::print(&insert_leaf(&mut critbit_tree, 400, 400));
        std::debug::print(&std::string::utf8(b"min_leaf"));
        let (key, index) = min_leaf(&critbit_tree);
        std::debug::print(&index);
        std::debug::print(&key);
        std::debug::print(borrow_leaf_by_index(&critbit_tree, index));
        std::debug::print(&std::string::utf8(b"remove_leaf_by_key"));
        std::debug::print(&remove_leaf_by_key(&mut critbit_tree, 4));
        std::debug::print(&remove_leaf_by_key(&mut critbit_tree, 200));
        std::debug::print(&std::string::utf8(b"insert_leaf"));
        std::debug::print(&insert_leaf(&mut critbit_tree, 50, 50));
        std::debug::print(&insert_leaf(&mut critbit_tree, 300, 300));
        std::debug::print(&insert_leaf(&mut critbit_tree, 100, 100));
        std::debug::print(&insert_leaf(&mut critbit_tree, 3, 3));
        std::debug::print(&insert_leaf(&mut critbit_tree, 1, 1));
        std::debug::print(&std::string::utf8(b"min_leaf"));
        let (key, index) = min_leaf(&critbit_tree);
        std::debug::print(&index);
        std::debug::print(&key);
        std::debug::print(borrow_leaf_by_index(&critbit_tree, index));
        std::debug::print(&std::string::utf8(b"remove_leaf_by_index"));
        std::debug::print(&remove_leaf_by_index(&mut critbit_tree, 8));
        std::debug::print(&remove_leaf_by_index(&mut critbit_tree, 9));
        std::debug::print(&std::string::utf8(b"insert_leaf"));
        std::debug::print(&insert_leaf(&mut critbit_tree, 0, 0));
        std::debug::print(&insert_leaf(&mut critbit_tree, 33, 33));
        std::debug::print(&std::string::utf8(b"min_leaf"));
        let (key, index) = min_leaf(&critbit_tree);
        std::debug::print(&index);
        std::debug::print(&key);
        std::debug::print(borrow_leaf_by_index(&critbit_tree, index));
        std::debug::print(&std::string::utf8(b"size"));
        std::debug::print(&size(&critbit_tree));
        std::debug::print(&std::string::utf8(b"iteration"));
        let (mut key, mut index) = min_leaf(&critbit_tree);
        std::debug::print(borrow_leaf_by_index(&critbit_tree, index));
        let mut i = 1;
        while (i < size(&critbit_tree)) {
            (key, index) = next_leaf(&critbit_tree, key);
            std::debug::print(borrow_leaf_by_index(&critbit_tree, index));
            i = i + 1;
        };

        drop(critbit_tree);
        test_scenario::end(scenario);
    }
}