/// No authority chech in these public functions, do not let `BalancePool` be exposed.
module typus_framework::balance_pool {
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::coin::Self;
    use sui::dynamic_field;

    use typus_framework::authority::{Self, Authority};

    const E_INVALID_TOKEN: u64 = 0;

    /// A pool that holds multiple types of token balances.
    /// It uses a main `Authority` object for access control on certain operations.
    public struct BalancePool has key, store {
        id: UID,
        /// A vector storing metadata about the balances in the pool.
        balance_infos: vector<BalanceInfo>,
        /// The `Authority` object that controls access to sensitive functions.
        authority: Authority,
    }

    /// Stores information about a specific token's balance.
    public struct BalanceInfo has copy, drop, store {
        /// The `TypeName` of the token.
        token: TypeName,
        /// The amount of the token.
        value: u64,
    }

    /// Creates a new `BalancePool`.
    public fun new(
        whitelist: vector<address>,
        ctx: &mut TxContext,
    ): BalancePool {
        let balance_pool = BalancePool {
            id: object::new(ctx),
            balance_infos: vector::empty(),
            authority: authority::new(whitelist, ctx),
        };

        balance_pool
    }

    /// Adds a user to the `BalancePool`'s authority.
    /// WARNING: mut inputs without authority check inside
    public fun add_authorized_user(
        balance_pool: &mut BalancePool,
        user_address: address,
    ) {
        authority::add_authorized_user(&mut balance_pool.authority, user_address);
    }

    /// Removes a user from the `BalancePool`'s authority.
    /// WARNING: mut inputs without authority check inside
    public fun remove_authorized_user(
        balance_pool: &mut BalancePool,
        user_address: address,
    ) {
        authority::remove_authorized_user(&mut balance_pool.authority, user_address);
    }

    /// Deposits a `Balance` of a specific `TOKEN` into the `BalancePool`.
    /// WARNING: mut inputs without authority check inside
    public fun put<TOKEN>(
        balance_pool: &mut BalancePool,
        balance: Balance<TOKEN>,
    ) {
        let mut i = 0;
        while (i < vector::length(&balance_pool.balance_infos)) {
            let balance_info = vector::borrow_mut(&mut balance_pool.balance_infos, i);
            if (balance_info.token == type_name::with_defining_ids<TOKEN>()) {
                balance_info.value = balance_info.value + balance::value(&balance);
                balance::join(
                    dynamic_field::borrow_mut(&mut balance_pool.id, type_name::with_defining_ids<TOKEN>()),
                    balance,
                );
                return
            };
            i = i + 1;
        };
        vector::push_back(
            &mut balance_pool.balance_infos,
            BalanceInfo {
                token: type_name::with_defining_ids<TOKEN>(),
                value: balance::value(&balance),
            },
        );
        dynamic_field::add(&mut balance_pool.id, type_name::with_defining_ids<TOKEN>(), balance);
    }

    /// Withdraws a specified `amount` of a `TOKEN` from the `BalancePool` and sends it to the sender.
    /// If `amount` is `None`, the entire balance of the token is withdrawn.
    /// Safe with authority check
    #[lint_allow(self_transfer)]
    public fun take<TOKEN>(
        balance_pool: &mut BalancePool,
        amount: Option<u64>,
        ctx: &mut TxContext,
    ): u64 {
        authority::verify(&balance_pool.authority, ctx);

        let mut i = 0;
        while (i < vector::length(&balance_pool.balance_infos)) {
            let balance_info = vector::borrow_mut(&mut balance_pool.balance_infos, i);
            if (balance_info.token == type_name::with_defining_ids<TOKEN>()) {
                let amount = option::destroy_with_default(amount, balance_info.value);
                balance_info.value = balance_info.value - amount;
                transfer::public_transfer(
                    coin::from_balance<TOKEN>(
                        balance::split(
                            dynamic_field::borrow_mut(&mut balance_pool.id, type_name::with_defining_ids<TOKEN>()),
                            amount,
                        ),
                        ctx,
                    ),
                    tx_context::sender(ctx),
                );
                if (balance_info.value == 0) {
                    balance_pool.balance_infos.swap_remove(i);
                    balance::destroy_zero<TOKEN>(
                        dynamic_field::remove(&mut balance_pool.id, type_name::with_defining_ids<TOKEN>()),
                    );
                };
                return amount
            };
            i = i + 1;
        };

        abort E_INVALID_TOKEN
    }

    /// Withdraws a specified `amount` of a `TOKEN` from the `BalancePool` and sends it to a `recipient`.
    /// If `amount` is `None`, the entire balance of the token is withdrawn.
    /// Safe with authority check
    public fun send<TOKEN>(
        balance_pool: &mut BalancePool,
        amount: Option<u64>,
        recipient: address,
        ctx: &mut TxContext,
    ): u64 {
        authority::verify(&balance_pool.authority, ctx);

        let mut i = 0;
        while (i < vector::length(&balance_pool.balance_infos)) {
            let balance_info = vector::borrow_mut(&mut balance_pool.balance_infos, i);
            if (balance_info.token == type_name::with_defining_ids<TOKEN>()) {
                let amount = option::destroy_with_default(amount, balance_info.value);
                balance_info.value = balance_info.value - amount;
                transfer::public_transfer(
                    coin::from_balance<TOKEN>(
                        balance::split(
                            dynamic_field::borrow_mut(&mut balance_pool.id, type_name::with_defining_ids<TOKEN>()),
                            amount,
                        ),
                        ctx,
                    ),
                    recipient,
                );
                if (balance_info.value == 0) {
                    balance_pool.balance_infos.swap_remove(i);
                    balance::destroy_zero<TOKEN>(
                        dynamic_field::remove(&mut balance_pool.id, type_name::with_defining_ids<TOKEN>()),
                    );
                };
                return amount
            };
            i = i + 1;
        };

        abort E_INVALID_TOKEN
    }

    /// Returns a reference to the `BalancePool`'s authority.
    public fun authority(balance_pool: &BalancePool): &Authority {
        &balance_pool.authority
    }

    /// Drops a `BalancePool`.
    /// The authority of the `BalancePool` is destroyed, which requires the sender to be in its whitelist.
    public fun drop_balance_pool(balance_pool: BalancePool, ctx: &TxContext) {
        let BalancePool {
            id,
            balance_infos,
            authority,
        } = balance_pool;
        balance_infos.destroy_empty();
        object::delete(id);
        authority.destroy(ctx);
    }


    #[deprecated]
    public struct SharedBalancePool has key, store {
        id: UID,
        balance_infos: vector<BalanceInfo>,
        authority: Authority,
    }
    #[deprecated]
    public fun new_shared_balance_pool(
        _balance_pool: &mut BalancePool,
        _key: vector<u8>,
        _whitelist: vector<address>,
        _ctx: &mut TxContext,
    ) { abort 0 }
    #[deprecated]
    public fun add_shared_authorized_user(
        _balance_pool: &mut BalancePool,
        _key: vector<u8>,
        _user_address: address,
    ) { abort 0 }
    #[deprecated]
    public fun remove_shared_authorized_user(
        _balance_pool: &mut BalancePool,
        _key: vector<u8>,
        _user_address: address,
    ) { abort 0 }
    #[deprecated]
    public fun put_shared<TOKEN>(
        _balance_pool: &mut BalancePool,
        _key: vector<u8>,
        _balance: Balance<TOKEN>,
    ) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun take_shared<TOKEN>(
        _balance_pool: &mut BalancePool,
        _key: vector<u8>,
        _amount: Option<u64>,
        _ctx: &mut TxContext,
    ): u64 { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun send_shared<TOKEN>(
        _balance_pool: &mut BalancePool,
        _key: vector<u8>,
        _amount: Option<u64>,
        _recipient: address,
        _ctx: &mut TxContext,
    ): u64 { abort 0 }
    #[deprecated]
    public fun shared_authority(
        _balance_pool: &BalancePool,
        _key: vector<u8>,
    ): &Authority { abort 0 }
    #[deprecated]
    public fun drop_shared_balance_pool(
        _balance_pool: &mut BalancePool,
        _key: vector<u8>,
        _ctx: &TxContext,
    ) { abort 0 }
}