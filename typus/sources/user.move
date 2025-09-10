// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
module typus::user {
    use std::bcs;

    use sui::event::emit;
    use sui::linked_table::{Self, LinkedTable};

    use typus::ecosystem::{ManagerCap, Version};
    use typus::tgld::{Self, TgldRegistry};
    use typus::utility;

    // ======== Metadata content index ========

    const IAccumulatedTgldAmount: u64 = 0;
    const ITailsExpAmount: u64 = 1;

    // ======== Typus User ========

    public struct TypusUserRegistry has key {
        id: UID,
        metadata: LinkedTable<address, Metadata>,
    }

    public struct Metadata has store, drop {
        content: vector<u64>,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(TypusUserRegistry {
            id: object::new(ctx),
            metadata: linked_table::new(ctx),
        });
    }

    public struct AddAccumulatedTgldAmount has copy, drop {
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
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

    public struct AddTailsExpAmount has copy, drop {
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    public fun add_tails_exp_amount(
        _manager_cap: &ManagerCap,
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


    public struct RemoveTailsExpAmount has copy, drop {
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
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
    public(package) fun remove_tails_exp_amount_(
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
        utility::decrease_u64_vector_value(&mut metadata.content, ITailsExpAmount, amount);
        emit(RemoveTailsExpAmount {
            user,
            log: vector[amount],
            bcs_padding: vector[],
        });

        vector[amount]
    }

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
}