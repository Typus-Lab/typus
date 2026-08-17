/// This module manages user accounts in the Typus ecosystem.
/// It provides functionalities for creating, accessing, and transferring accounts.
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

    /// A registry for all user accounts in the Typus system.
    /// This struct is a dynamic object field of the `Version` object.
    public struct AccountRegistry has key, store {
        /// The unique identifier of the AccountRegistry object.
        id: UID,
        /// A keyed big vector mapping account addresses to `Account` objects.
        accounts: KeyedBigVector, // <address, Account>
        /// A keyed big vector mapping user addresses to their corresponding account addresses.
        user_account: KeyedBigVector, // <address, address>
    }

    /// Represents a user account.
    public struct Account has key, store {
        /// The unique identifier of the Account object.
        id: UID,
        /// An optional capability object that grants access to this account.
        account_cap: Option<AccountCap>,
        /// The address of the user who created this account.
        creator: address,
    }

    /// A capability object that grants access to an account.
    /// This can be used to authorize actions on behalf of the account owner.
    public struct AccountCap has key, store {
        /// The unique identifier of the AccountCap object.
        id: UID,
        /// The address of the account this capability is for.
        `for`: address,
    }

    /// Initializes the `AccountRegistry` as a dynamic object field of the `Version` object.
    /// This function is called only once during the deployment of the contract.
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

    /// Retrieves the account address of the transaction sender.
    /// It asserts that the user has an account.
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

    /// Retrieves the account address associated with a given `AccountCap`.
    public fun get_user_account_address_with_account_cap(
        version: &Version,
        account_cap: &AccountCap,
    ): address {
        // safety check
        version.version_check();

        // return value
        account_cap.`for`
    }

    /// Borrows a mutable reference to the user's `Account` object.
    /// The user is identified by the transaction sender's address.
    /// Safe with ctx.sender as verification
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

    /// Borrows a mutable reference to an `Account` object using an `AccountCap`.
    /// This allows authorized users to access and modify an account.
    /// Safe with `AccountCap` as verification
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

    /// Creates a new `Account` and returns an `AccountCap` for it.
    /// This function can be used to create accounts that are not directly tied to a user's address.
    /// The `AccountCap` can be transferred to other users to grant them access to the account.
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
        event::emit_typus_event(
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

    /// Creates a new `Account` for the transaction sender and associates it with their address.
    /// If the user already has an account, this function does nothing.
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
        event::emit_typus_event(
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

    /// Transfers the sender's account to a new recipient address.
    /// It asserts that the sender has an account and the recipient does not have an account yet.
    /// Safe with ctx.sender as verification
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
        event::emit_typus_event(
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