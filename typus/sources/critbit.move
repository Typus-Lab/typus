// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module implements a Crit-bit tree, a binary trie data structure that is highly efficient
/// for searching and storing keys. This implementation uses `u64` keys and generic values.
/// The tree is composed of internal nodes and leaf nodes, stored in tables.
module typus::critbit {
    use sui::table::{Self, Table};

    // ======== Error Code ========

    /// Error when the tree's capacity is exceeded.
    const EExceedCapacity: u64 = 0;
    /// Error when trying to destroy a non-empty tree.
    const ETreeNotEmpty: u64 = 1;
    /// Error when a key to be inserted already exists in the tree.
    const EKeyAlreadyExist: u64 = 2;
    /// Error when a leaf does not exist.
    const ELeafNotExist: u64 = 3;
    /// Error for out-of-bounds access.
    const EIndexOutOfRange: u64 = 4;
    /// Error when a parent node is null.
    const ENullParent: u64 = 5;

    // === Constants ===

    /// A special value used to distinguish between internal nodes and leaves.
    const PARTITION_INDEX: u64 = 0x8000000000000000; // 9223372036854775808
    /// The maximum value of a u64 integer.
    const MAX_U64: u64 = 0xFFFFFFFFFFFFFFFF; // 18446744073709551615
    /// The maximum capacity of the tree.
    const MAX_CAPACITY: u64 = 0x7fffffffffffffff;

    // === Structs ===

    /// Represents a leaf node in the Crit-bit tree, storing a key-value pair.
    public struct Leaf<V> has store, drop {
        /// The key of the leaf.
        key: u64,
        /// The value of the leaf.
        value: V,
        /// The index of the parent node.
        parent: u64,
    }

    /// Represents an internal node in the Crit-bit tree.
    public struct InternalNode has store, drop {
        /// The mask used to determine the branching direction.
        mask: u64,
        /// The index of the left child.
        left_child: u64,
        /// The index of the right child.
        right_child: u64,
        /// The index of the parent node.
        parent: u64,
    }

    /// The main Crit-bit tree structure.
    public struct CritbitTree<V: store> has store {
        /// The index of the root node.
        root: u64,
        /// A table storing the internal nodes of the tree.
        internal_nodes: Table<u64, InternalNode>,
        /// A table storing the leaves of the tree.
        leaves: Table<u64, Leaf<V>>,
        /// The index of the leaf with the minimum key.
        min_leaf_index: u64,
        /// The index of the leaf with the maximum key.
        max_leaf_index: u64,
        /// The index to be used for the next internal node.
        next_internal_node_index: u64,
        /// The index to be used for the next leaf.
        next_leaf_index: u64
    }

    // ======== Public Functions ========

    /// Creates a new, empty Crit-bit tree.
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

    /// Returns the number of leaves in the tree.
    public fun size<V: store>(tree: &CritbitTree<V>): u64 {
        tree.leaves.length()
    }

    /// Returns `true` if the tree is empty.
    public fun is_empty<V: store>(tree: &CritbitTree<V>): bool {
        tree.leaves.is_empty()
    }

    /// Returns `true` if a leaf with the given key exists in the tree.
    public fun has_leaf<V: store>(tree: &CritbitTree<V>, key: u64): bool {
        let (has_leaf, _) = tree.find_leaf(key);
        has_leaf
    }

    /// Returns `true` if a leaf with the given index exists in the tree.
    public fun has_index<V: store>(tree: &CritbitTree<V>, index: u64): bool {
        tree.leaves.contains(index)
    }

    /// Returns the key and index of the leaf with the minimum key in the tree.
    /// Aborts if the tree is empty.
    public fun min_leaf<V: store>(tree: &CritbitTree<V>): (u64, u64) {
        assert!(!tree.is_empty(), ELeafNotExist);
        let min_leaf = tree.leaves.borrow(tree.min_leaf_index);
        (min_leaf.key, tree.min_leaf_index)
    }

    /// Returns the key and index of the leaf with the maximum key in the tree.
    /// Aborts if the tree is empty.
    public fun max_leaf<V: store>(tree: &CritbitTree<V>): (u64, u64) {
        assert!(!tree.is_empty(), ELeafNotExist);
        let max_leaf = tree.leaves.borrow(tree.max_leaf_index);
        (max_leaf.key, tree.max_leaf_index)
    }

    /// Returns the key and index of the leaf that comes before the given key in sorted order.
    /// Returns `(0, PARTITION_INDEX)` if there is no previous leaf.
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

    /// Returns the key and index of the leaf that comes after the given key in sorted order.
    /// Returns `(0, PARTITION_INDEX)` if there is no next leaf.
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

    /// Inserts a new leaf with the given key and value into the tree.
    /// Returns the index of the new leaf.
    /// Aborts if the key already exists or if the tree exceeds its capacity.
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

    /// Finds a leaf with the given key and returns a boolean indicating if it was found,
    /// along with the index of the leaf if found.
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

    /// Finds the key of the leaf that is closest to the given key.
    /// Returns 0 if the tree is empty.
    public fun find_closest_key<V: store>(tree: & CritbitTree<V>, key: u64): u64 {
        if (tree.is_empty()) {
            return 0
        };
        let closest_leaf_index = tree.get_closest_leaf_index_by_key(key);
        let closeset_leaf = tree.leaves.borrow(closest_leaf_index);
        closeset_leaf.key
    }

    /// Removes the leaf with the minimum key from the tree and returns its value.
    public fun remove_min_leaf<V: store>(tree: &mut CritbitTree<V>): V {
        let index = tree.min_leaf_index;
        tree.remove_leaf_by_index(index)
    }

    /// Removes the leaf with the maximum key from the tree and returns its value.
    public fun remove_max_leaf<V: store>(tree: &mut CritbitTree<V>): V {
        let index = tree.max_leaf_index;
        tree.remove_leaf_by_index(index)
    }

    /// Removes a leaf from the tree by its index and returns its value.
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
                } else {
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

    /// Removes a leaf from the tree by its key and returns its value.
    /// Aborts if the key does not exist.
    public fun remove_leaf_by_key<V: store>(tree: &mut CritbitTree<V>, key: u64): V {
        let (is_exist, index) = tree.find_leaf(key);
        assert!(is_exist, ELeafNotExist);
        tree.remove_leaf_by_index(index)
    }

    /// Borrows a mutable reference to the value of a leaf by its index.
    public fun borrow_mut_leaf_by_index<V: store>(tree: &mut CritbitTree<V>, index: u64): &mut V {
        let entry = tree.leaves.borrow_mut(index);
        &mut entry.value
    }

    /// Borrows a mutable reference to the value of a leaf by its key.
    /// Aborts if the key does not exist.
    public fun borrow_mut_leaf_by_key<V: store>(tree: &mut CritbitTree<V>, key: u64): &mut V {
        let (is_exist, index) = tree.find_leaf(key);
        assert!(is_exist, ELeafNotExist);
        tree.borrow_mut_leaf_by_index(index)
    }

    /// Borrows an immutable reference to the value of a leaf by its index.
    public fun borrow_leaf_by_index<V: store>(tree: & CritbitTree<V>, index: u64): &V {
        let entry = tree.leaves.borrow(index);
        &entry.value
    }

    /// Borrows an immutable reference to the value of a leaf by its key.
    /// Aborts if the key does not exist.
    public fun borrow_leaf_by_key<V: store>(tree: & CritbitTree<V>, key: u64): &V {
        let (is_exist, index) = tree.find_leaf(key);
        assert!(is_exist, ELeafNotExist);
        tree.borrow_leaf_by_index(index)
    }

    /// Destroys the tree, dropping all the entries within.
    /// The value type must have the `drop` ability.
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

    /// Destroys an empty tree.
    /// Aborts if the tree is not empty.
    public fun destroy_empty<V: store>(tree: CritbitTree<V>) {
        assert!(tree.leaves.length() == 0, ETreeNotEmpty);

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

    /// Finds the leftmost leaf starting from a given root.
    fun left_most_leaf<V: store>(tree: &CritbitTree<V>, root: u64): u64 {
        let mut ptr = root;
        while (ptr < PARTITION_INDEX) {
            ptr = tree.internal_nodes.borrow(ptr).left_child;
        };
        ptr
    }

    /// Finds the rightmost leaf starting from a given root.
    fun right_most_leaf<V: store>(tree: &CritbitTree<V>, root: u64): u64 {
        let mut ptr = root;
        while (ptr < PARTITION_INDEX) {
            ptr = tree.internal_nodes.borrow(ptr).right_child;
        };
        ptr
    }

    /// Finds the index of the leaf that is closest to the given key.
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

    /// Updates the child of a parent node.
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

    /// Returns `true` if the node at `index` is the left child of the node at `parent_index`.
    fun is_left_child<V: store>(tree: &CritbitTree<V>, parent_index: u64, index: u64): bool {
        tree.internal_nodes.borrow(parent_index).left_child == index
    }

    /// Counts the number of leading zeros in a u128 integer.
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
}