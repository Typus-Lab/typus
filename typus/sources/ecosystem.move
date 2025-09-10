// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
module typus::ecosystem {
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::coin;
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::vec_set::{Self, VecSet};

    // ======== Constants ========

    const CVersion: u64 = 6;

    // ======== Error Code ========

    const EAuthorityAlreadyExists: u64 = 0;
    const EAuthorityDoesNotExist: u64 = 1;
    const EAuthorityEmpty: u64 = 2;
    const EInvalidVersion: u64 = 3;
    const EUnauthorized: u64 = 4;

    // ======== Manager Cap ========

    public struct ManagerCap has store { }

    public fun issue_manager_cap(
        version: &Version,
        ctx: &TxContext,
    ): ManagerCap {
        version.verify(ctx);

        ManagerCap { }
    }

    public fun burn_manager_cap(
        version: &Version,
        manager_cap: ManagerCap,
        ctx: &TxContext,
    ) {
        version.verify(ctx);
        let ManagerCap { } = manager_cap;
    }

    // ======== Version ========

    public struct Version has key {
        id: UID,
        value: u64,
        fee_pool: FeePool,
        authority: VecSet<address>,
        u64_padding: vector<u64>,
    }

    public(package) fun version_check(version: &Version) {
        assert!(CVersion >= version.value, EInvalidVersion);
    }

    public(package) fun borrow_uid_mut(version: &mut Version): &mut UID {
        &mut version.id
    }

    public(package) fun borrow_uid(version: &Version): &UID {
        &version.id
    }

    entry fun upgrade(version: &mut Version) {
        version.version_check();
        version.value = CVersion;
    }

    // ======== Init ========

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Version {
            id: object::new(ctx),
            value: CVersion,
            fee_pool: FeePool {
                id: object::new(ctx),
                fee_infos: vector[],
            },
            authority: vec_set::singleton(ctx.sender()),
            u64_padding: vector[],
        });
    }

    // ======== Authority ========

    public(package) fun verify(
        version: &Version,
        ctx: &TxContext,
    ) {
        version.version_check();

        assert!(
            version.authority.contains(&ctx.sender()),
            EUnauthorized
        );
    }

    entry fun add_authorized_user(
        version: &mut Version,
        user_address: address,
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        assert!(!version.authority.contains(&user_address), EAuthorityAlreadyExists);
        version.authority.insert(user_address);
    }

    entry fun remove_authorized_user(
        version: &mut Version,
        user_address: address,
        ctx: &TxContext,
    ) {
        version.verify(ctx);

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

    public struct SendFeeEvent has copy, drop {
        token: TypeName,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    entry fun send_fee<TOKEN>(
        version: &mut Version,
        ctx: &mut TxContext,
    ) {
        version.version_check();

        let mut i = 0;
        while (i < version.fee_pool.fee_infos.length()) {
            let fee_info = version.fee_pool.fee_infos.borrow_mut(i);
            if (fee_info.token == type_name::get<TOKEN>()) {
                transfer::public_transfer(
                    coin::from_balance<TOKEN>(
                        balance::withdraw_all(dynamic_field::borrow_mut(&mut version.fee_pool.id, type_name::get<TOKEN>())),
                        ctx,
                    ),
                    @fee_address,
                );
                emit(SendFeeEvent {
                    token: type_name::get<TOKEN>(),
                    log: vector[fee_info.value],
                    bcs_padding: vector[],
                });
                fee_info.value = 0;
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

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}