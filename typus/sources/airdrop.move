// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module implements an airdrop mechanism for distributing tokens to a list of users.
/// It allows for setting up airdrops, claiming them, and removing them.
module typus::airdrop {
    use std::ascii::String;
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::coin::Coin;
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::table::{Self, Table};

    use typus::big_vector::{Self, BigVector};
    use typus::ecosystem::Version;
    use typus::utility;

    // ======== Error Code ========

    /// Error when the balance of the airdrop is insufficient.
    const EInsufficientBalance: u64 = 0;
    /// Error for invalid input parameters.
    const EInvalidInput: u64 = 1;

    const TotalValue: vector<u8> = b"total_value";
    const ClaimedTable: vector<u8> = b"claimed_table";

    // ======== Typus Airdrop ========

    /// A registry for all airdrops. This is a shared object that holds all `AirdropInfo` objects as dynamic fields.
    public struct TypusAirdropRegistry has key {
        id: UID,
    }

    /// Stores the information for a specific airdrop.
    /// The `TOKEN` type parameter indicates the type of token being airdropped.
    public struct AirdropInfo<phantom TOKEN> has key, store {
        /// The unique identifier of the AirdropInfo object.
        id: UID,
        /// The balance of tokens available for this airdrop.
        balance: Balance<TOKEN>,
        /// A big vector containing the list of `Airdrop` structs for each user.
        airdrops: BigVector,
        // df:
        //  total_value: u64,
        //  claimed_table: Table<address, u64>,
    }

    /// Represents a single airdrop for a user.
    public struct Airdrop has store, drop { // 40
        /// The address of the user who is eligible for the airdrop.
        user: address,                      // 32
        /// The amount of tokens the user will receive.
        value: u64,                         // 8
    }

    /// Initializes the `TypusAirdropRegistry` and shares it.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(TypusAirdropRegistry {
            id: object::new(ctx),
        });
    }

    /// Event emitted when an airdrop is set or updated.
    public struct SetAirdropEvent has copy, drop {
        /// The type name of the token being airdropped.
        token: TypeName,
        /// The key identifying the airdrop.
        key: String,
        /// Log data: [total_value, spent_value]
        log: vector<u64>,
        /// Padding for BCS.
        bcs_padding: vector<vector<u8>>,
    }
    /// Sets up or updates an airdrop.
    /// This function is authorized and can only be called by the admin.
    /// It takes a list of users and corresponding values to be airdropped.
    /// It also takes a vector of coins to fund the airdrop.
    public fun set_airdrop<TOKEN>(
        version: &Version,
        typus_airdrop_registry: &mut TypusAirdropRegistry,
        key: String,
        mut coins: vector<Coin<TOKEN>>,
        mut users: vector<address>,
        mut values: vector<u64>,
        ctx: &mut TxContext,
    ) {
        // This is an authorized function
        version.verify(ctx);
        assert!(users.length() == values.length(), EInvalidInput);

        let token = type_name::with_defining_ids<TOKEN>();
        let mut airdrop_info = if(dynamic_field::exists_(&typus_airdrop_registry.id, key)) {
            dynamic_field::remove(&mut typus_airdrop_registry.id, key)
        } else {
            AirdropInfo<TOKEN> {
                id: object::new(ctx),
                balance: balance::zero(),
                airdrops: big_vector::new<Airdrop>(2500, ctx),
            }
        };
        let mut total_value = airdrop_info.balance.value();

        while (!users.is_empty()) {
            let user = users.pop_back();
            let value = values.pop_back();
            total_value = total_value + value;
            airdrop_info.airdrops.push_back(
                Airdrop {
                    user,
                    value,
                },
            );
        };

        if (dynamic_field::exists_(& airdrop_info.id, TotalValue.to_string())) {
            let v: &mut u64 = dynamic_field::borrow_mut(&mut airdrop_info.id, TotalValue.to_string());
            *v = total_value;
        } else {
            dynamic_field::add(&mut airdrop_info.id, TotalValue.to_string(), total_value);
        };

        if (!dynamic_field::exists_(& airdrop_info.id, ClaimedTable.to_string())) {
            let claimed_table = table::new<address, u64>(ctx);
            dynamic_field::add(&mut airdrop_info.id, ClaimedTable.to_string(), claimed_table);
        };

        // add insufficient balance from coins to airdrop_info.balance
        let airdrop_value = airdrop_info.balance.value();
        let mut spent_value = 0;
        if (airdrop_value < total_value) {
            let mut insufficient_airdrop_value = total_value - airdrop_value;
            spent_value = insufficient_airdrop_value;
            while (!coins.is_empty()) {
                if (insufficient_airdrop_value > 0) {
                    let mut coin = coins.pop_back();
                    if (coin.value() > insufficient_airdrop_value) {
                        airdrop_info.balance.join(coin.balance_mut().split(insufficient_airdrop_value));
                        coins.push_back(coin);
                        insufficient_airdrop_value = 0;
                        break
                    }
                    else {
                        insufficient_airdrop_value = insufficient_airdrop_value - coin.value();
                        airdrop_info.balance.join(coin.into_balance());
                    };
                }
                else {
                    break
                }
            };
            assert!(insufficient_airdrop_value == 0, EInsufficientBalance);
        };
        utility::transfer_coins(coins, ctx.sender());

        dynamic_field::add(&mut typus_airdrop_registry.id, key, airdrop_info);


        emit(SetAirdropEvent {
            token,
            key,
            log : vector[total_value, spent_value],
            bcs_padding: vector[],
        });
    }

    /// Event emitted when an airdrop is removed.
    public struct RemoveAirdropEvent has copy, drop {
        /// The type name of the token being airdropped.
        token: TypeName,
        /// The key identifying the airdrop.
        key: String,
        /// Log data: [balance_value]
        log: vector<u64>,
        /// Padding for BCS.
        bcs_padding: vector<vector<u8>>,
    }
    /// Removes an airdrop and returns the remaining balance to the admin.
    /// This function is authorized and can only be called by the admin.
    public fun remove_airdrop<TOKEN>(
        version: &Version,
        typus_airdrop_registry: &mut TypusAirdropRegistry,
        key: String,
        ctx: &mut TxContext,
    ): Balance<TOKEN> {
        // This is an authorized function
        version.verify(ctx);

        let AirdropInfo {
            mut id,
            balance,
            airdrops,
        } = dynamic_field::remove(&mut typus_airdrop_registry.id, key);

        if (dynamic_field::exists_(& id, TotalValue.to_string())) {
            let _: u64 = dynamic_field::remove(&mut id, TotalValue.to_string());
        };

        if (dynamic_field::exists_(& id, ClaimedTable.to_string())) {
            let t: Table<address, u64> = dynamic_field::remove(&mut id, ClaimedTable.to_string());
            t.drop();
        };

        object::delete(id);
        big_vector::drop<Airdrop>(airdrops);

        emit(RemoveAirdropEvent {
            token: type_name::with_defining_ids<TOKEN>(),
            key,
            log: vector[balance.value()],
            bcs_padding: vector[],
        });

        balance
    }

    /// Event emitted when a user claims an airdrop.
    public struct ClaimAirdropEvent has copy, drop {
        /// The type name of the token being airdropped.
        token: TypeName,
        /// The key identifying the airdrop.
        key: String,
        /// The address of the user claiming the airdrop.
        user: address,
        /// Log data: [claimed_value]
        log: vector<u64>,
        /// Padding for BCS.
        bcs_padding: vector<vector<u8>>,
    }
    /// Allows a user to claim their airdrop.
    /// It iterates through the airdrop list to find the user's entry and sends them the tokens.
    /// If the user has already claimed, the value will be 0, and they won't receive anything.
    /// Safe with ctx.sender as verification
    public fun claim_airdrop<TOKEN>(
        version: &Version,
        typus_airdrop_registry: &mut TypusAirdropRegistry,
        key: String,
        ctx: &TxContext,
    ): Option<Balance<TOKEN>> {
        version.version_check();

        if (!dynamic_field::exists_with_type<String, AirdropInfo<TOKEN>>(&typus_airdrop_registry.id, key)) {
            abort EInvalidInput
        };
        let airdrop_info = dynamic_field::borrow_mut<String, AirdropInfo<TOKEN>>(&mut typus_airdrop_registry.id, key);
        let user = ctx.sender();
        let length = airdrop_info.airdrops.length();
        let slice_size = (airdrop_info.airdrops.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = airdrop_info.airdrops.borrow_slice_mut(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            let airdrop: &mut Airdrop = &mut slice[i % slice_size];
            if (airdrop.user == user) {
                let balance = airdrop_info.balance.split(airdrop.value);
                emit(ClaimAirdropEvent {
                    token: type_name::with_defining_ids<TOKEN>(),
                    key,
                    user,
                    log: vector[airdrop.value],
                    bcs_padding: vector[],
                });

                // update claimed_table
                if (dynamic_field::exists_(& airdrop_info.id, ClaimedTable.to_string())) {
                    let claimed_table: &mut Table<address, u64> = dynamic_field::borrow_mut(&mut airdrop_info.id, ClaimedTable.to_string());
                    if (claimed_table.contains(user)) {
                        let claimed = claimed_table.borrow_mut(user);
                        *claimed = *claimed + airdrop.value;
                    } else {
                        claimed_table.add(user, airdrop.value);
                    };
                };

                airdrop.value = 0;
                return option::some(balance)
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = airdrop_info.airdrops.borrow_slice_mut(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };

        option::none()
    }

    /// Allows a user to claim their airdrop by providing the index of their airdrop entry.
    /// This is more efficient than `claim_airdrop` if the user knows their index.
    /// Safe with ctx.sender as verification
    public fun claim_airdrop_by_index<TOKEN>(
        version: &Version,
        typus_airdrop_registry: &mut TypusAirdropRegistry,
        key: String,
        i: u64,
        ctx: &TxContext,
    ): Option<Balance<TOKEN>> {
        version.version_check();

        if (!dynamic_field::exists_with_type<String, AirdropInfo<TOKEN>>(&typus_airdrop_registry.id, key)) {
            abort EInvalidInput
        };
        let airdrop_info = dynamic_field::borrow_mut<String, AirdropInfo<TOKEN>>(&mut typus_airdrop_registry.id, key);
        let user = ctx.sender();
        let airdrop: &mut Airdrop = &mut airdrop_info.airdrops[i];
        if (airdrop.user == user) {
            let balance = airdrop_info.balance.split(airdrop.value);
            emit(ClaimAirdropEvent {
                token: type_name::with_defining_ids<TOKEN>(),
                key,
                user,
                log: vector[airdrop.value],
                bcs_padding: vector[],
            });

            // update claimed_table
            if (dynamic_field::exists_(& airdrop_info.id, ClaimedTable.to_string())) {
                let claimed_table: &mut Table<address, u64> = dynamic_field::borrow_mut(&mut airdrop_info.id, ClaimedTable.to_string());
                if (claimed_table.contains(user)) {
                    let claimed = claimed_table.borrow_mut(user);
                    *claimed = *claimed + airdrop.value;
                } else {
                    claimed_table.add(user, airdrop.value);
                };
            };

            airdrop.value = 0;
            return option::some(balance)
        };

        option::none()
    }

    /// Retrieves the airdrop information for a specific user.
    /// Returns a vector containing the index and value of the airdrop.
    /// If the user is not found, it returns `[0, 0]`.
    public(package) fun get_airdrop<TOKEN>(
        version: &Version,
        typus_airdrop_registry: &TypusAirdropRegistry,
        key: String,
        user: address,
    ): vector<u64> {
        version.version_check();

        if (!dynamic_field::exists_with_type<String, AirdropInfo<TOKEN>>(&typus_airdrop_registry.id, key)) {
            abort EInvalidInput
        };
        let airdrop_info = dynamic_field::borrow<String, AirdropInfo<TOKEN>>(&typus_airdrop_registry.id, key);

        let mut total_value = 0;
        if (dynamic_field::exists_(& airdrop_info.id, TotalValue.to_string())) {
            total_value = *dynamic_field::borrow(& airdrop_info.id, TotalValue.to_string());
        };

        let length = airdrop_info.airdrops.length();
        let slice_size = (airdrop_info.airdrops.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = airdrop_info.airdrops.borrow_slice(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            let airdrop: &Airdrop = &slice[i % slice_size];
            if (airdrop.user == user) {
                // get claimed_table
                let mut claimed = 0;
                if (dynamic_field::exists_(& airdrop_info.id, ClaimedTable.to_string())) {
                    let claimed_table: & Table<address, u64> = dynamic_field::borrow(&airdrop_info.id, ClaimedTable.to_string());
                    if (claimed_table.contains(user)) {
                        claimed = *claimed_table.borrow(user);
                    };
                };

                return vector[i, airdrop.value, claimed, total_value]
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = airdrop_info.airdrops.borrow_slice(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };

        vector[0, 0, 0, total_value]
    }
}