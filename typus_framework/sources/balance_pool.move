module typus_framework::balance_pool {
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::coin::Self;
    use sui::dynamic_field;

    use typus_framework::authority::{Self, Authority};

    const E_INVALID_TOKEN: u64 = 0;

    public struct BalancePool has key, store {
        id: UID,
        balance_infos: vector<BalanceInfo>,
        authority: Authority,
    }

    public struct BalanceInfo has copy, drop, store {
        token: TypeName,
        value: u64,
    }

    public struct SharedBalancePool has key, store {
        id: UID,
        balance_infos: vector<BalanceInfo>,
        authority: Authority,
    }

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

    public fun add_authorized_user(
        balance_pool: &mut BalancePool,
        user_address: address,
    ) {
        authority::add_authorized_user(&mut balance_pool.authority, user_address);
    }

    public fun remove_authorized_user(
        balance_pool: &mut BalancePool,
        user_address: address,
    ) {
        authority::remove_authorized_user(&mut balance_pool.authority, user_address);
    }

    public fun new_shared_balance_pool(
        balance_pool: &mut BalancePool,
        key: vector<u8>,
        whitelist: vector<address>,
        ctx: &mut TxContext,
    ) {
        authority::verify(&balance_pool.authority, ctx);

        let shared_balance_pool = SharedBalancePool {
            id: object::new(ctx),
            balance_infos: vector::empty(),
            authority: authority::new(whitelist, ctx),
        };

        dynamic_field::add(&mut balance_pool.id, key, shared_balance_pool);
    }

    public fun add_shared_authorized_user(
        balance_pool: &mut BalancePool,
        key: vector<u8>,
        user_address: address,
    ) {
        let shared_balance_pool: &mut SharedBalancePool = dynamic_field::borrow_mut(&mut balance_pool.id, key);
        authority::add_authorized_user(&mut shared_balance_pool.authority, user_address);
    }

    public fun remove_shared_authorized_user(
        balance_pool: &mut BalancePool,
        key: vector<u8>,
        user_address: address,
    ) {
        let shared_balance_pool: &mut SharedBalancePool = dynamic_field::borrow_mut(&mut balance_pool.id, key);
        authority::remove_authorized_user(&mut shared_balance_pool.authority, user_address);
    }

    public fun put<TOKEN>(
        balance_pool: &mut BalancePool,
        balance: Balance<TOKEN>,
    ) {
        let mut i = 0;
        while (i < vector::length(&balance_pool.balance_infos)) {
            let balance_info = vector::borrow_mut(&mut balance_pool.balance_infos, i);
            if (balance_info.token == type_name::get<TOKEN>()) {
                balance_info.value = balance_info.value + balance::value(&balance);
                balance::join(
                    dynamic_field::borrow_mut(&mut balance_pool.id, type_name::get<TOKEN>()),
                    balance,
                );
                return
            };
            i = i + 1;
        };
        vector::push_back(
            &mut balance_pool.balance_infos,
            BalanceInfo {
                token: type_name::get<TOKEN>(),
                value: balance::value(&balance),
            },
        );
        dynamic_field::add(&mut balance_pool.id, type_name::get<TOKEN>(), balance);
    }

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
            if (balance_info.token == type_name::get<TOKEN>()) {
                let amount = option::destroy_with_default(amount, balance_info.value);
                balance_info.value = balance_info.value - amount;
                transfer::public_transfer(
                    coin::from_balance<TOKEN>(
                        balance::split(
                            dynamic_field::borrow_mut(&mut balance_pool.id, type_name::get<TOKEN>()),
                            amount,
                        ),
                        ctx,
                    ),
                    tx_context::sender(ctx),
                );
                if (balance_info.value == 0) {
                    balance_pool.balance_infos.swap_remove(i);
                    balance::destroy_zero<TOKEN>(
                        dynamic_field::remove(&mut balance_pool.id, type_name::get<TOKEN>()),
                    );
                };
                return amount
            };
            i = i + 1;
        };

        abort E_INVALID_TOKEN
    }

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
            if (balance_info.token == type_name::get<TOKEN>()) {
                let amount = option::destroy_with_default(amount, balance_info.value);
                balance_info.value = balance_info.value - amount;
                transfer::public_transfer(
                    coin::from_balance<TOKEN>(
                        balance::split(
                            dynamic_field::borrow_mut(&mut balance_pool.id, type_name::get<TOKEN>()),
                            amount,
                        ),
                        ctx,
                    ),
                    recipient,
                );
                if (balance_info.value == 0) {
                    balance_pool.balance_infos.swap_remove(i);
                    balance::destroy_zero<TOKEN>(
                        dynamic_field::remove(&mut balance_pool.id, type_name::get<TOKEN>()),
                    );
                };
                return amount
            };
            i = i + 1;
        };

        abort E_INVALID_TOKEN
    }

    public fun put_shared<TOKEN>(
        balance_pool: &mut BalancePool,
        key: vector<u8>,
        balance: Balance<TOKEN>,
    ) {
        let shared_balance_pool: &mut SharedBalancePool = dynamic_field::borrow_mut(&mut balance_pool.id, key);
        let mut i = 0;
        while (i < vector::length(&shared_balance_pool.balance_infos)) {
            let balance_info = vector::borrow_mut(&mut shared_balance_pool.balance_infos, i);
            if (balance_info.token == type_name::get<TOKEN>()) {
                balance_info.value = balance_info.value + balance::value(&balance);
                balance::join(
                    dynamic_field::borrow_mut(&mut shared_balance_pool.id, type_name::get<TOKEN>()),
                    balance,
                );
                return
            };
            i = i + 1;
        };
        vector::push_back(
            &mut shared_balance_pool.balance_infos,
            BalanceInfo {
                token: type_name::get<TOKEN>(),
                value: balance::value(&balance),
            },
        );
        dynamic_field::add(&mut shared_balance_pool.id, type_name::get<TOKEN>(), balance);
    }

    #[lint_allow(self_transfer)]
    public fun take_shared<TOKEN>(
        balance_pool: &mut BalancePool,
        key: vector<u8>,
        amount: Option<u64>,
        ctx: &mut TxContext,
    ): u64 {
        let shared_balance_pool: &mut SharedBalancePool = dynamic_field::borrow_mut(&mut balance_pool.id, key);
        authority::verify(&shared_balance_pool.authority, ctx);

        let mut i = 0;
        while (i < vector::length(&shared_balance_pool.balance_infos)) {
            let balance_info = vector::borrow_mut(&mut shared_balance_pool.balance_infos, i);
            if (balance_info.token == type_name::get<TOKEN>()) {
                let amount = option::destroy_with_default(amount, balance_info.value);
                balance_info.value = balance_info.value - amount;
                transfer::public_transfer(
                    coin::from_balance<TOKEN>(
                        balance::split(
                            dynamic_field::borrow_mut(&mut shared_balance_pool.id, type_name::get<TOKEN>()),
                            amount,
                        ),
                        ctx,
                    ),
                    tx_context::sender(ctx),
                );
                if (balance_info.value == 0) {
                    shared_balance_pool.balance_infos.swap_remove(i);
                    balance::destroy_zero<TOKEN>(
                        dynamic_field::remove(&mut shared_balance_pool.id, type_name::get<TOKEN>()),
                    );
                };
                return amount
            };
            i = i + 1;
        };

        abort E_INVALID_TOKEN
    }

    public fun send_shared<TOKEN>(
        balance_pool: &mut BalancePool,
        key: vector<u8>,
        amount: Option<u64>,
        recipient: address,
        ctx: &mut TxContext,
    ): u64 {
        let shared_balance_pool: &mut SharedBalancePool = dynamic_field::borrow_mut(&mut balance_pool.id, key);
        authority::verify(&shared_balance_pool.authority, ctx);

        let mut i = 0;
        while (i < vector::length(&shared_balance_pool.balance_infos)) {
            let balance_info = vector::borrow_mut(&mut shared_balance_pool.balance_infos, i);
            if (balance_info.token == type_name::get<TOKEN>()) {
                let amount = option::destroy_with_default(amount, balance_info.value);
                balance_info.value = balance_info.value - amount;
                transfer::public_transfer(
                    coin::from_balance<TOKEN>(
                        balance::split(
                            dynamic_field::borrow_mut(&mut shared_balance_pool.id, type_name::get<TOKEN>()),
                            amount,
                        ),
                        ctx,
                    ),
                    recipient,
                );
                if (balance_info.value == 0) {
                    shared_balance_pool.balance_infos.swap_remove(i);
                    balance::destroy_zero<TOKEN>(
                        dynamic_field::remove(&mut shared_balance_pool.id, type_name::get<TOKEN>()),
                    );
                };
                return amount
            };
            i = i + 1;
        };

        abort E_INVALID_TOKEN
    }

    public fun authority(balance_pool: &BalancePool): &Authority {
        &balance_pool.authority
    }

    public fun shared_authority(balance_pool: &BalancePool, key: vector<u8>): &Authority {
        let shared_balance_pool: &SharedBalancePool = dynamic_field::borrow(&balance_pool.id, key);
        &shared_balance_pool.authority
    }

    public fun drop_shared_balance_pool(
        balance_pool: &mut BalancePool,
        key: vector<u8>,
        ctx: &TxContext,
    ) {
        let shared_balance_pool: SharedBalancePool = dynamic_field::remove(&mut balance_pool.id, key);
        let SharedBalancePool {
            id,
            balance_infos,
            authority,
        } = shared_balance_pool;
        object::delete(id);
        balance_infos.destroy_empty();
        authority.destroy(ctx);
    }

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

    #[test_only]
    public fun get_balance_value<TOKEN>(balance_pool: &BalancePool): u64 {
        let mut i = 0;
        let mut value = 0;
        while (i < vector::length(&balance_pool.balance_infos)) {
            let balance_info = vector::borrow(&balance_pool.balance_infos, i);
            if (balance_info.token == type_name::get<TOKEN>()) {
                value = value + balance_info.value;
                break
            };
            i = i + 1;
        };
        value
    }
}