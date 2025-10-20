// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
module version::version {
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::coin;
    use sui::dynamic_field;
    use sui::types;
    use sui::vec_set::{Self, VecSet};

    // ======== Error Code ========

    const EInvalidOneTimeWitness: u64 = 0;
    const EInvalidVersion: u64 = 1;
    const EInvalidWitness: u64 = 2;
    const EUnauthorized: u64 = 3;
    const EAuthorityEmpty: u64 = 4;
    const EAuthorityAlreadyExists: u64 = 5;
    const EAuthorityDoesNotExist: u64 = 6;

    // ======== Version ========

    public struct Version has key {
        id: UID,
        value: u64,
        fee_pool: FeePool,
        authority: VecSet<address>,
        witness: TypeName,
        u64_padding: vector<u64>,
    }

    public fun issue_version<OTW: drop, W: drop>(otw: &OTW, _: W, ctx: &mut TxContext) {
        assert!(types::is_one_time_witness(otw), EInvalidOneTimeWitness);
        transfer::share_object(Version {
            id: object::new(ctx),
            value: 1,
            fee_pool: FeePool {
                id: object::new(ctx),
                fee_infos: vector[],
            },
            authority: vec_set::singleton(ctx.sender()),
            witness: type_name::get<W>(),
            u64_padding: vector[],
        });
    }

    entry fun upgrade(version: &mut Version, value: u64, ctx: &TxContext) {
        version.verify_version(value);
        version.verify_authority(ctx);
        version.value = value;
    }

    // ======== Authority & Witness ========

    public fun verify_version(version: &Version, value: u64) {
        assert!(value >= version.value, EInvalidVersion);
    }

    public fun verify_witness<W: drop>(version: &Version, _: W) {
        assert!(type_name::get<W>() == version.witness, EInvalidWitness);
    }

    public fun verify_authority(
        version: &Version,
        ctx: &TxContext,
    ) {
        assert!(version.authority.contains(&ctx.sender()), EUnauthorized);
    }

    entry fun add_authorized_user(
        version: &mut Version,
        user_address: address,
        ctx: &TxContext,
    ) {
        version.verify_authority(ctx);

        assert!(!version.authority.contains(&user_address), EAuthorityAlreadyExists);
        version.authority.insert(user_address);
    }

    entry fun remove_authorized_user(
        version: &mut Version,
        user_address: address,
        ctx: &TxContext,
    ) {
        version.verify_authority(ctx);

        assert!(version.authority.contains(&user_address), EAuthorityDoesNotExist);
        version.authority.remove(&user_address);
        assert!(version.authority.size() > 0, EAuthorityEmpty);
    }

    // ======== Fee Pool ========

    public struct FeePool has key, store {
        id: UID,
        fee_infos: vector<FeeInfo>,
    }

    public struct FeeInfo has copy, drop, store {
        token: TypeName,
        value: u64,
    }

    entry fun send_fee<TOKEN>(
        version: &mut Version,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        version.verify_authority(ctx);

        let mut i = 0;
        while (i < version.fee_pool.fee_infos.length()) {
            let fee_info = version.fee_pool.fee_infos.borrow_mut(i);
            if (fee_info.token == type_name::get<TOKEN>()) {
                transfer::public_transfer(
                    coin::from_balance<TOKEN>(
                        balance::withdraw_all(dynamic_field::borrow_mut(&mut version.fee_pool.id, type_name::get<TOKEN>())),
                        ctx,
                    ),
                    recipient,
                );
                fee_info.value = 0;
                return
            };
            i = i + 1;
        };
    }

    public fun charge_fee<TOKEN>(
        version: &mut Version,
        balance: Balance<TOKEN>,
    ) {
        let mut i = 0;
        while (i < version.fee_pool.fee_infos.length()) {
            let fee_info = &mut version.fee_pool.fee_infos[i];
            if (fee_info.token == type_name::get<TOKEN>()) {
                fee_info.value = fee_info.value + balance::value(&balance);
                balance::join(
                    dynamic_field::borrow_mut(&mut version.fee_pool.id, type_name::get<TOKEN>()),
                    balance,
                );
                return
            };
            i = i + 1;
        };
        version.fee_pool.fee_infos.push_back(
            FeeInfo {
                token: type_name::get<TOKEN>(),
                value: balance::value(&balance),
            },
        );
        dynamic_field::add(&mut version.fee_pool.id, type_name::get<TOKEN>(), balance);
    }
}