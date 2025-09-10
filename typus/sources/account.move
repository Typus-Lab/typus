module typus::account {
    use std::bcs;

    use sui::dynamic_object_field;
    use sui::vec_map;

    use typus::ecosystem::Version;
    use typus::error::{
        account_not_found,
        account_already_exists,
    };
    use typus::event;
    use typus::keyed_big_vector::{Self, KeyedBigVector};

    const KAccountRegistry: vector<u8> = b"account_registry";

    public struct AccountRegistry has key, store {
        id: UID,
        accounts: KeyedBigVector, // account address, account entity
        user_account: KeyedBigVector, // user address, account address
    }

    public struct Account has key, store {
        id: UID,
        account_cap: Option<AccountCap>,
        creator: address,
    }

    public struct AccountCap has key, store {
        id: UID,
        `for`: address,
    }

    entry fun init_account_registry(version: &mut Version, ctx: &mut TxContext) {
        dynamic_object_field::add(
            version.borrow_uid_mut(),
            KAccountRegistry.to_string(),
            AccountRegistry {
                id: object::new(ctx),
                accounts: keyed_big_vector::new<address, Account>(1000, ctx),
                user_account: keyed_big_vector::new<address, address>(1000, ctx),
            }
        );
    }

    public fun get_user_account_address(
        version: &Version,
        ctx: &TxContext,
    ): address {
        // safety check
        version.version_check();

        // main logic
        let account_registry: &AccountRegistry = dynamic_object_field::borrow(
            version.borrow_uid(),
            KAccountRegistry.to_string(),
        );
        assert!(account_registry.user_account.contains(ctx.sender()), account_not_found(0));


        // return value
        *account_registry.user_account.borrow_by_key(ctx.sender())
    }

    public fun get_user_account_address_with_account_cap(
        version: &Version,
        account_cap: &AccountCap,
    ): address {
        // safety check
        version.version_check();

        // return value
        account_cap.`for`
    }

    public fun borrow_user_account(
        version: &mut Version,
        ctx: &TxContext,
    ): &mut Account {
        // safety check
        version.version_check();

        // main logic
        let account_registry: &mut AccountRegistry = dynamic_object_field::borrow_mut(
            version.borrow_uid_mut(),
            KAccountRegistry.to_string(),
        );
        assert!(account_registry.user_account.contains(ctx.sender()), account_not_found(0));


        // return value
        account_registry.accounts.borrow_by_key_mut<address, Account>(
            *account_registry.user_account.borrow_by_key(ctx.sender())
        )
    }

    public fun borrow_user_account_with_account_cap(
        version: &mut Version,
        account_cap: &AccountCap,
    ): &mut Account {
        // safety check
        version.version_check();

        // main logic
        let account_registry: &mut AccountRegistry = dynamic_object_field::borrow_mut(
            version.borrow_uid_mut(),
            KAccountRegistry.to_string(),
        );

        // return value
        account_registry.accounts.borrow_by_key_mut(account_cap.`for`)
    }

    public fun new_account(
        version: &mut Version,
        ctx: &mut TxContext,
    ): AccountCap {
        // safety check
        version.version_check();

        // main logic
        let account_registry: &mut AccountRegistry = dynamic_object_field::borrow_mut(
            version.borrow_uid_mut(),
            KAccountRegistry.to_string(),
        );
        let creator = ctx.sender();
        let account = Account {
            id: object::new(ctx),
            account_cap: option::none(),
            creator,
        };
        let account_address = object::id_address(&account);
        account_registry.accounts.push_back(account_address, account);
        let account_cap = AccountCap {
            id: object::new(ctx),
            `for`: account_address,
        };

        // emit event
        event::emit_event(
            b"new_account".to_string(),
            vec_map::empty(),
            vec_map::from_keys_values(
                vector[
                    b"account".to_string(),
                ],
                vector[
                    bcs::to_bytes(&account_address),
                ],
            ),
        );

        // return value
        account_cap
    }

    public fun create_account(
        version: &mut Version,
        ctx: &mut TxContext,
    ) {
        // safety check
        version.version_check();
        let account_registry: &mut AccountRegistry = dynamic_object_field::borrow_mut(
            version.borrow_uid_mut(),
            KAccountRegistry.to_string(),
        );
        if (account_registry.user_account.contains(ctx.sender())) { return };

        // main logic
        let creator = ctx.sender();
        let mut account = Account {
            id: object::new(ctx),
            account_cap: option::none(),
            creator,
        };
        let account_address = object::id_address(&account);
        let account_cap = AccountCap {
            id: object::new(ctx),
            `for`: account_address,
        };
        let account_cap_address = object::id_address(&account_cap);
        option::fill(&mut account.account_cap, account_cap);
        account_registry.accounts.push_back(account_address, account);
        account_registry.user_account.push_back(ctx.sender(), account_address);

        // emit event
        event::emit_event(
            b"create_account".to_string(),
            vec_map::empty(),
            vec_map::from_keys_values(
                vector[
                    b"account".to_string(),
                    b"account_cap".to_string(),
                ],
                vector[
                    bcs::to_bytes(&account_address),
                    bcs::to_bytes(&account_cap_address),
                ],
            ),
        );
    }

    public fun transfer_account(
        version: &mut Version,
        recipient: address,
        ctx: &TxContext,
    ) {
        // safety check
        version.version_check();
        let account_registry: &mut AccountRegistry = dynamic_object_field::borrow_mut(
            version.borrow_uid_mut(),
            KAccountRegistry.to_string(),
        );
        assert!(account_registry.user_account.contains(ctx.sender()), account_not_found(0));
        assert!(!account_registry.user_account.contains(recipient), account_already_exists(0));

        // main logic
        let account_address: address = account_registry.user_account.swap_remove_by_key(ctx.sender());
        account_registry.user_account.push_back(recipient, account_address);

        // emit event
        event::emit_event(
            b"transfer_account".to_string(),
            vec_map::empty(),
            vec_map::from_keys_values(
                vector[
                    b"account".to_string(),
                    b"recipient".to_string(),
                ],
                vector[
                    bcs::to_bytes(&account_address),
                    bcs::to_bytes(&recipient),
                ],
            ),
        );
    }
}