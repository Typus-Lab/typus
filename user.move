// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module manages user data for the Typus ecosystem. It provides a registry for storing
/// user metadata, such as accumulated TGLD and Tails EXP amounts.
module typus::user {
    use std::bcs;

    use sui::event::emit;
    use sui::linked_table::{Self, LinkedTable};

    use typus::ecosystem::{ManagerCap, Version};
    use typus::tgld::{Self, TgldRegistry};
    use typus::utility;

    // ======== Metadata content index ========

    /// Index for the accumulated TGLD amount in the metadata content vector.
    const IAccumulatedTgldAmount: u64 = 0;
    /// Index for the Tails EXP amount in the metadata content vector.
    const ITailsExpAmount: u64 = 1;

    // ======== Typus User ========

    /// A registry for storing user metadata.
    public struct TypusUserRegistry has key {
        id: UID,
        /// A linked table mapping user addresses to their `Metadata`.
        metadata: LinkedTable<address, Metadata>,
    }

    /// Stores user-specific metadata.
    public struct Metadata has store, drop {
        /// A vector of `u64` values representing user metadata.
        content: vector<u64>,
    }

    /// Initializes the `TypusUserRegistry`.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(TypusUserRegistry {
            id: object::new(ctx),
            metadata: linked_table::new(ctx),
        });
    }

    /// Event emitted when a user's accumulated TGLD amount is increased.
    public struct AddAccumulatedTgldAmount has copy, drop {
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Increases a user's accumulated TGLD amount and mints the corresponding amount of `TGLD` tokens.
    /// This is an authorized function that requires a `ManagerCap`.
    public fun add_accumulated_tgld_amount(
        manager_cap: &ManagerCap,
        version: &Version,
        typus_user_registry: &mut TypusUserRegistry,
        tgld_registry: &mut TgldRegistry,
        user: address,
        amount: u64,
        ctx: &mut TxContext,
    ): vector<u64> {
        version.version_check();

        if (amount == 0) {
            return vector[0]
        };
        if (!typus_user_registry.metadata.contains(user)) {
            typus_user_registry.metadata.push_back(
                user,
                Metadata {
                    content: vector[],
                },
            );
        };
        let metadata = typus_user_registry.metadata.borrow_mut(user);
        utility::increase_u64_vector_value(&mut metadata.content, IAccumulatedTgldAmount, amount);
        tgld::mint(
            manager_cap,
            version,
            tgld_registry,
            user,
            amount,
            ctx,
        );
        emit(AddAccumulatedTgldAmount {
            user,
            log: vector[amount],
            bcs_padding: vector[],
        });

        vector[amount]
    }

    /// Event emitted when a user's Tails EXP amount is increased.
    public struct AddTailsExpAmount has copy, drop {
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Increases a user's Tails EXP amount.
    /// This is an authorized function that requires a `ManagerCap`.
    public fun add_tails_exp_amount(
        _manager_cap: &ManagerCap,
        version: &Version,
        typus_user_registry: &mut TypusUserRegistry,
        user: address,
        amount: u64,
    ): vector<u64> {
        add_tails_exp_amount_(
            version,
            typus_user_registry,
            user,
            amount,
        )
    }
    /// Increases a user's Tails EXP amount. This is a package-private function.
    /// WARNING: mut inputs without authority check inside
    public(package) fun add_tails_exp_amount_(
        version: &Version,
        typus_user_registry: &mut TypusUserRegistry,
        user: address,
        amount: u64,
    ): vector<u64> {
        version.version_check();

        if (amount == 0) {
            return vector[0]
        };
        if (!typus_user_registry.metadata.contains(user)) {
            typus_user_registry.metadata.push_back(
                user,
                Metadata {
                    content: vector[],
                },
            );
        };
        let metadata = typus_user_registry.metadata.borrow_mut(user);
        utility::increase_u64_vector_value(&mut metadata.content, ITailsExpAmount, amount);
        emit(AddTailsExpAmount {
            user,
            log: vector[amount],
            bcs_padding: vector[],
        });

        vector[amount]
    }


    /// Event emitted when a user's Tails EXP amount is decreased.
    public struct RemoveTailsExpAmount has copy, drop {
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Decreases a user's Tails EXP amount.
    /// This is an authorized function that requires a `ManagerCap`.
    public fun remove_tails_exp_amount(
        _manager_cap: &ManagerCap,
        version: &Version,
        typus_user_registry: &mut TypusUserRegistry,
        user: address,
        amount: u64,
    ): vector<u64> {
        remove_tails_exp_amount_(
            version,
            typus_user_registry,
            user,
            amount,
        )
    }
    /// Decreases a user's Tails EXP amount. This is a package-private function.
    /// WARNING: mut inputs without authority check inside
    public(package) fun remove_tails_exp_amount_(
        version: &Version,
        typus_user_registry: &mut TypusUserRegistry,
        user: address,
        amount: u64,
    ): vector<u64> {
        version.version_check();

        if (amount == 0 || !typus_user_registry.metadata.contains(user)) {
            return vector[0]
        };
        let metadata = typus_user_registry.metadata.borrow_mut(user);
        utility::decrease_u64_vector_value(&mut metadata.content, ITailsExpAmount, amount);
        emit(RemoveTailsExpAmount {
            user,
            log: vector[amount],
            bcs_padding: vector[],
        });

        vector[amount]
    }

    /// Retrieves the metadata for a specific user.
    public fun get_user_metadata(
        version: &Version,
        typus_user_registry: &TypusUserRegistry,
        user: address,
    ): vector<u8> {
        version.version_check();

        if (!typus_user_registry.metadata.contains(user)) {
            bcs::to_bytes(&Metadata { content: vector[] })
        } else {
            bcs::to_bytes(typus_user_registry.metadata.borrow(user))
        }

    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}