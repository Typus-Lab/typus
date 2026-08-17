#[deprecated, allow(unused_type_parameter, unused_variable)]
module typus_framework::linked_list {
    #[deprecated]
    public struct LinkedList<K: copy + drop + store, phantom V: store> has drop, store {
        id: ID,
        first: Option<K>,
        last: Option<K>,
        length: u64,
    }
    #[deprecated]
    public struct Node<K: copy + drop + store, V: store> has copy, drop, store {
        value: V,
        prev: Option<K>,
        next: Option<K>,
        exists: bool,
    }
    #[deprecated]
    public fun new<K: copy + drop + store, V: store>(_id: ID): LinkedList<K, V> { abort 0 }
    #[deprecated]
    public fun new_node<K: copy + drop + store, V: store>(
        value: V,
        prev: Option<K>,
        next: Option<K>,
    ): Node<K, V> { abort 0 }
    #[deprecated]
    public fun node_exists<K: copy + drop + store, V: store>(_node: &Node<K, V>): bool { abort 0 }
    #[deprecated]
    public fun node_value<K: copy + drop + store, V: store>(_node: &Node<K, V>): &V { abort 0 }
    #[deprecated]
    public fun first<K: copy + drop + store, V: store>(_linked_list: &LinkedList<K, V>): Option<K> { abort 0 }
    #[deprecated]
    public fun last<K: copy + drop + store, V: store>(_linked_list: &LinkedList<K, V>): Option<K> { abort 0 }
    #[deprecated]
    public fun length<K: copy + drop + store, V: store>(_linked_list: &LinkedList<K, V>): u64 { abort 0 }
    #[deprecated]
    public fun is_empty<K: copy + drop + store, V: store>(_linked_list: &LinkedList<K, V>): bool { abort 0 }
    #[deprecated]
    public fun push_front<K: copy + drop + store, V: drop + store>(
        _uid: &mut UID,
        _linked_list: &mut LinkedList<K, V>,
        _key: K,
        _value: V,
    ) { abort 0 }
    #[deprecated]
    public fun push_back<K: copy + drop + store, V: drop + store>(
        _uid: &mut UID,
        _linked_list: &mut LinkedList<K, V>,
        _key: K,
        _value: V,
    ) { abort 0 }
    #[deprecated]
    public fun put_front<K: copy + drop + store, V: store>(
        _uid: &mut UID,
        _linked_list: &mut LinkedList<K, V>,
        _key: K,
        _value: V,
    ): Option<V> { abort 0 }
    #[deprecated]
    public fun put_back<K: copy + drop + store, V: store>(
        _uid: &mut UID,
        _linked_list: &mut LinkedList<K, V>,
        _key: K,
        _value: V,
    ): Option<V> { abort 0 }
    #[deprecated]
    public fun pop_front<K: copy + drop + store, V: copy + store>(
        _uid: &mut UID,
        _linked_list: &mut LinkedList<K, V>,
    ): (K, V) { abort 0 }
    #[deprecated]
    public fun pop_back<K: copy + drop + store, V: copy + store>(
        _uid: &mut UID,
        _linked_list: &mut LinkedList<K, V>,
    ): (K, V) { abort 0 }
    #[deprecated]
    public fun remove<K: copy + drop + store, V: copy + store>(
        _uid: &mut UID,
        _linked_list: &mut LinkedList<K, V>,
        _key: K,
    ): V { abort 0 }
    #[deprecated]
    public fun take_front<K: copy + drop + store, V: store>(
        _uid: &mut UID,
        _linked_list: &mut LinkedList<K, V>,
    ): (K, V) { abort 0 }
    #[deprecated]
    public fun take_back<K: copy + drop + store, V: store>(
        _uid: &mut UID,
        _linked_list: &mut LinkedList<K, V>,
    ): (K, V) { abort 0 }
    #[deprecated]
    public fun delete<K: copy + drop + store, V: copy + store>(
        _uid: &mut UID,
        _linked_list: &mut LinkedList<K, V>,
        _key: K,
    ): V { abort 0 }
    #[deprecated]
    public fun chain<K: copy + drop + store, V: store>(
        _a: &mut LinkedList<K, V>,
        _b: &mut LinkedList<K, V>,
    ) { abort 0 }
    #[deprecated]
    public fun contains<K: copy + drop + store, V: store>(
        _uid: &UID,
        _linked_list: &LinkedList<K, V>,
        _key: K,
    ): bool { abort 0 }
    #[deprecated]
    public fun borrow<K: copy + drop + store, V: store>(
        _uid: &UID,
        _linked_list: &LinkedList<K, V>,
        _key: K,
    ): &V { abort 0 }
    #[deprecated]
    public fun borrow_mut<K: copy + drop + store, V: store>(
        _uid: &mut UID,
        _linked_list: &LinkedList<K, V>,
        _key: K,
    ): &mut V { abort 0 }
    #[deprecated]
    public fun prev<K: copy + drop + store, V: store>(
        _uid: &UID,
        _linked_list: &LinkedList<K, V>,
        _key: K,
    ): Option<K> { abort 0 }
    #[deprecated]
    public fun next<K: copy + drop + store, V: store>(
        _uid: &UID,
        _linked_list: &LinkedList<K, V>,
        _key: K,
    ): Option<K> { abort 0 }
    #[deprecated]
    public fun push_node<K: copy + drop + store, V: drop + store>(
        _uid: &mut UID,
        _key: K,
        _new_node: Node<K, V>,
    ) { abort 0 }
    #[deprecated]
    public fun put_node<K: copy + drop + store, V: store>(
        _uid: &mut UID,
        _key: K,
        _new_node: Node<K, V>,
    ): Option<V> { abort 0 }
    #[deprecated]
    public fun pop_node<K: copy + drop + store, V: copy + store>(
        _uid: &mut UID,
        _key: K,
    ): V { abort 0 }
    #[deprecated]
    public fun take_node<K: copy + drop + store, V: store>(
        _uid: &mut UID,
        _key: K
    ): V { abort 0 }
    #[deprecated]
    public fun prepare_node<K: copy + drop + store, V: drop + store>(
        _uid: &mut UID,
        _key: K,
        _value: V,
    ) { abort 0 }
    #[deprecated]
    public fun remove_node<K: copy + drop + store, V: drop + store>(
        _uid: &mut UID,
        _key: K,
    ) { abort 0 }
}