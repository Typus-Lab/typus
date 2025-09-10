// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
module typus::airdrop {
    use std::ascii::String;
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::coin::Coin;
    use sui::dynamic_field;
    use sui::event::emit;

    use typus::big_vector::{Self, BigVector};
    use typus::ecosystem::Version;
    use typus::utility;

    // ======== Error Code ========

    const EInsufficientBalance: u64 = 0;
    const EInvalidInput: u64 = 1;

    // ======== Typus Airdrop ========

    public struct TypusAirdropRegistry has key {
        id: UID,
    }

    public struct AirdropInfo<phantom TOKEN> has key, store {
        id: UID,
        balance: Balance<TOKEN>,
        airdrops: BigVector,
    }

    public struct Airdrop has store, drop { // 40
        user: address,                      // 32
        value: u64,                         // 8
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(TypusAirdropRegistry {
            id: object::new(ctx),
        });
    }

    public struct SetAirdropEvent has copy, drop {
        token: TypeName,
        key: String,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    public fun set_airdrop<TOKEN>(
        version: &Version,
        typus_airdrop_registry: &mut TypusAirdropRegistry,
        key: String,
        mut coins: vector<Coin<TOKEN>>,
        mut users: vector<address>,
        mut values: vector<u64>,
        ctx: &mut TxContext,
    ) {
        version.verify(ctx);
        assert!(users.length() == values.length(), EInvalidInput);

        let token = type_name::get<TOKEN>();
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

    public struct RemoveAirdropEvent has copy, drop {
        token: TypeName,
        key: String,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    public fun remove_airdrop<TOKEN>(
        version: &Version,
        typus_airdrop_registry: &mut TypusAirdropRegistry,
        key: String,
        ctx: &mut TxContext,
    ): Balance<TOKEN> {
        version.verify(ctx);

        let AirdropInfo {
            id,
            balance,
            airdrops,
        } = dynamic_field::remove(&mut typus_airdrop_registry.id, key);
        object::delete(id);
        big_vector::drop<Airdrop>(airdrops);

        emit(RemoveAirdropEvent {
            token: type_name::get<TOKEN>(),
            key,
            log: vector[balance.value()],
            bcs_padding: vector[],
        });

        balance
    }

    public struct ClaimAirdropEvent has copy, drop {
        token: TypeName,
        key: String,
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
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
                    token: type_name::get<TOKEN>(),
                    key,
                    user,
                    log: vector[airdrop.value],
                    bcs_padding: vector[],
                });
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
                token: type_name::get<TOKEN>(),
                key,
                user,
                log: vector[airdrop.value],
                bcs_padding: vector[],
            });
            airdrop.value = 0;
            return option::some(balance)
        };

        option::none()
    }

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
        let length = airdrop_info.airdrops.length();
        let slice_size = (airdrop_info.airdrops.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = airdrop_info.airdrops.borrow_slice(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            let airdrop: &Airdrop = &slice[i % slice_size];
            if (airdrop.user == user) {
                return vector[i, airdrop.value]
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = airdrop_info.airdrops.borrow_slice(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };

        vector[0, 0]
    }
}