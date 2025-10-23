module typus_framework::authority {
    use sui::linked_table::{Self, LinkedTable};

    const E_UNAUTHORIZED: u64 = 0;
    const E_EMPTY_WHITELIST: u64 = 1;

    /// A struct that holds a whitelist of authorized users.
    public struct Authority has store {
        /// A linked table mapping user addresses to a boolean `true`.
        whitelist: LinkedTable<address, bool>,
    }

    /// Verifies if the transaction sender is in the authority's whitelist.
    public fun verify(authority: &Authority, ctx: &TxContext) {
        assert!(
            linked_table::contains(&authority.whitelist, tx_context::sender(ctx)),
            E_UNAUTHORIZED
        );
    }
    /// Verifies if the transaction sender is in either of the two authorities' whitelists.
    public fun double_verify(primary_authority: &Authority, secondary_authority: &Authority, ctx: &TxContext) {
        assert!(
            linked_table::contains(&primary_authority.whitelist, tx_context::sender(ctx))
                || linked_table::contains(&secondary_authority.whitelist, tx_context::sender(ctx)),
            E_UNAUTHORIZED
        );
    }

    /// Creates a new `Authority` object with an initial whitelist.
    /// The `whitelist` vector should not be empty.
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

    /// Adds a new authorized user to the authority's whitelist.
    /// WARNING: mut inputs without authority check inside
    public fun add_authorized_user(
        authority: &mut Authority,
        user_address: address,
    ) {
        if (!linked_table::contains(&authority.whitelist, user_address)) {
            linked_table::push_back(&mut authority.whitelist, user_address, true);
        }
    }

    /// Removes an authorized user from the authority's whitelist.
    /// WARNING: mut inputs without authority check inside
    public fun remove_authorized_user(
        authority: &mut Authority,
        user_address: address,
    ) {
        if (linked_table::contains(&authority.whitelist, user_address)) {
            linked_table::remove(&mut authority.whitelist, user_address);
        }
    }

    /// Returns the list of whitelisted user addresses.
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

    /// Destroys an `Authority` object and its whitelist.
    /// This is an authorized function.
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

    #[deprecated]
    public fun remove_all(
        _authority: &mut Authority,
        _ctx: &TxContext,
    ): vector<address> { abort 0 }

    #[deprecated]
    public fun destroy_empty(
        _authority: Authority,
        _ctx: &TxContext,
    ) { abort 0 }
}