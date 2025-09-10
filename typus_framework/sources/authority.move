module typus_framework::authority {
    use sui::linked_table::{Self, LinkedTable};

    const E_UNAUTHORIZED: u64 = 0;
    const E_EMPTY_WHITELIST: u64 = 1;

    public struct Authority has store {
        whitelist: LinkedTable<address, bool>,
    }

    public fun verify(authority: &Authority, ctx: &TxContext) {
        assert!(
            linked_table::contains(&authority.whitelist, tx_context::sender(ctx)),
            E_UNAUTHORIZED
        );
    }
    public fun double_verify(primary_authority: &Authority, secondary_authority: &Authority, ctx: &TxContext) {
        assert!(
            linked_table::contains(&primary_authority.whitelist, tx_context::sender(ctx))
                || linked_table::contains(&secondary_authority.whitelist, tx_context::sender(ctx)),
            E_UNAUTHORIZED
        );
    }

    public fun new(
        mut whitelist: vector<address>,
        ctx: &mut TxContext
    ): Authority {
        let mut wl = linked_table::new(ctx);
        if (vector::is_empty(&whitelist)) {
            abort E_EMPTY_WHITELIST
        };
        while (!vector::is_empty(&whitelist)) {
            let user_address = vector::pop_back(&mut whitelist);
            if (!linked_table::contains(&wl, user_address)) {
                linked_table::push_back(&mut wl, user_address, true);
            }
        };
        Authority {
            whitelist: wl,
        }
    }

    public fun add_authorized_user(
        authority: &mut Authority,
        user_address: address,
    ) {
        if (!linked_table::contains(&authority.whitelist, user_address)) {
            linked_table::push_back(&mut authority.whitelist, user_address, true);
        }
    }

    public fun remove_authorized_user(
        authority: &mut Authority,
        user_address: address,
    ) {
        if (linked_table::contains(&authority.whitelist, user_address)) {
            linked_table::remove(&mut authority.whitelist, user_address);
        }
    }

    public fun whitelist(authority: &Authority): vector<address> {
        let mut whitelist = vector::empty();
        let mut key = linked_table::front(&authority.whitelist);
        while (option::is_some(key)) {
            let user_address = option::borrow(key);
            vector::push_back(
                &mut whitelist,
                *user_address,
            );
            key = linked_table::next(&authority.whitelist, *user_address);
        };
        whitelist
    }

    public fun remove_all(
        authority: &mut Authority,
        ctx: &TxContext,
    ): vector<address> {
        verify(authority, ctx);
        let mut whitelist = vector::empty();
        while (linked_table::length(&authority.whitelist) > 0) {
            let (user_address, _) = linked_table::pop_front(&mut authority.whitelist);
            vector::push_back(
                &mut whitelist,
                user_address,
            );
        };
        whitelist
    }

    public fun destroy_empty(
        authority: Authority,
        ctx: &TxContext,
    ) {
        verify(&authority, ctx);
        let Authority { whitelist } = authority;
        linked_table::destroy_empty(whitelist);
    }

    public fun destroy(
        authority: Authority,
        ctx: &TxContext,
    ) {
        verify(&authority, ctx);
        let Authority { mut whitelist } = authority;
        while (linked_table::length(&whitelist) > 0) {
            linked_table::pop_front(&mut whitelist);
        };
        linked_table::destroy_empty(whitelist);
    }
}