// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module defines the core components of the Typus ecosystem, including version management,
/// authority control, and a fee collection mechanism. It serves as the central point of control
/// for the entire system.
module typus::ecosystem {
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::coin;
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::vec_set::{Self, VecSet};

    // ======== Constants ========

    /// The current version of the ecosystem.
    const CVersion: u64 = 6;

    // ======== Error Code ========

    /// Error when an authority to be added already exists.
    const EAuthorityAlreadyExists: u64 = 0;
    /// Error when an authority to be removed does not exist.
    const EAuthorityDoesNotExist: u64 = 1;
    /// Error when there are no authorities left.
    const EAuthorityEmpty: u64 = 2;
    /// Error for an invalid version.
    const EInvalidVersion: u64 = 3;
    /// Error for an unauthorized action.
    const EUnauthorized: u64 = 4;

    // ======== Manager Cap ========

    /// A capability object that grants manager-level privileges for the Typus ecosystem.
    public struct ManagerCap has store { }

    /// Issues a `ManagerCap` to the transaction sender.
    /// This is an authorized function and can only be called by an existing authority.
    public fun issue_manager_cap(
        version: &Version,
        ctx: &TxContext,
    ): ManagerCap {
        version.verify(ctx);

        ManagerCap { }
    }

    /// Burns a `ManagerCap`.
    /// This is an authorized function and can only be called by an existing authority.
    public fun burn_manager_cap(
        version: &Version,
        manager_cap: ManagerCap,
        ctx: &TxContext,
    ) {
        version.verify(ctx);
        let ManagerCap { } = manager_cap;
    }

    // ======== Version ========

    /// A shared object that represents the current version of the Typus ecosystem.
    /// It holds the authority list and the fee pool.
    public struct Version has key {
        /// The unique identifier of the Version object.
        id: UID,
        /// The current version number.
        value: u64,
        /// The fee pool for collecting fees.
        fee_pool: FeePool,
        /// A set of addresses of the authorized users.
        authority: VecSet<address>,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// Checks if the current version is valid.
    /// Aborts if the version is older than the current version.
    public(package) fun version_check(version: &Version) {
        assert!(CVersion >= version.value, EInvalidVersion);
    }

    /// Borrows a mutable reference to the UID of the `Version` object.
    public(package) fun borrow_uid_mut(version: &mut Version): &mut UID {
        &mut version.id
    }

    /// Borrows an immutable reference to the UID of the `Version` object.
    public(package) fun borrow_uid(version: &Version): &UID {
        &version.id
    }

    /// Upgrades the version of the ecosystem to the latest version.
    entry fun upgrade(version: &mut Version) {
        version.version_check();
        version.value = CVersion;
    }

    // ======== Init ========

    /// Initializes the `Version` object and shares it.
    /// The initial authority is the sender of the transaction.
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

    /// Verifies if the sender of the transaction is an authorized user.
    /// Aborts if the sender is not in the authority list.
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

    /// Adds a new authorized user to the authority list.
    /// This is an authorized function and can only be called by an existing authority.
    entry fun add_authorized_user(
        version: &mut Version,
        user_address: address,
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        assert!(!version.authority.contains(&user_address), EAuthorityAlreadyExists);
        version.authority.insert(user_address);
    }

    /// Removes an authorized user from the authority list.
    /// This is an authorized function and can only be called by an existing authority.
    /// Aborts if the user to be removed does not exist or if there are no authorities left.
    entry fun remove_authorized_user(
        version: &mut Version,
        user_address: address,
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        assert!(version.authority.contains(&user_address), EAuthorityDoesNotExist);
        version.authority.remove(&user_address);
        assert!(version.authority.length() > 0, EAuthorityEmpty);
    }

    // ======== Fee Pool ========

    /// Manages the collection of fees in the ecosystem.
    public struct FeePool has key, store {
        /// The unique identifier of the FeePool object.
        id: UID,
        /// A vector of `FeeInfo` structs, one for each token type.
        fee_infos: vector<FeeInfo>,
    }

    /// Stores the fee information for a specific token.
    public struct FeeInfo has copy, drop, store {
        /// The type name of the token.
        token: TypeName,
        /// The total amount of fees collected for this token.
        value: u64,
    }

    /// Event emitted when fees are sent from the fee pool.
    public struct SendFeeEvent has copy, drop {
        /// The type name of the token.
        token: TypeName,
        /// Log data: [sent_fee_value]
        log: vector<u64>,
        /// Padding for BCS.
        bcs_padding: vector<vector<u8>>,
    }
    /// Sends the collected fees for a specific token to a designated fee address.
    entry fun send_fee<TOKEN>(
        version: &mut Version,
        ctx: &mut TxContext,
    ) {
        version.version_check();

        let mut i = 0;
        while (i < version.fee_pool.fee_infos.length()) {
            let fee_info = version.fee_pool.fee_infos.borrow_mut(i);
            if (fee_info.token == type_name::with_defining_ids<TOKEN>()) {
                transfer::public_transfer(
                    coin::from_balance<TOKEN>(
                        balance::withdraw_all(dynamic_field::borrow_mut(&mut version.fee_pool.id, type_name::with_defining_ids<TOKEN>())),
                        ctx,
                    ),
                    @fee_address,
                );
                emit(SendFeeEvent {
                    token: type_name::with_defining_ids<TOKEN>(),
                    log: vector[fee_info.value],
                    bcs_padding: vector[],
                });
                fee_info.value = 0;
            };
            i = i + 1;
        };
    }

    /// Charges a fee for a specific token and adds it to the fee pool.
    /// If the token is not yet in the fee pool, it adds a new `FeeInfo` entry.
    public fun charge_fee<TOKEN>(
        version: &mut Version,
        balance: Balance<TOKEN>,
    ) {
        let mut i = 0;
        while (i < vector::length(&version.fee_pool.fee_infos)) {
            let fee_info = &mut version.fee_pool.fee_infos[i];
            if (fee_info.token == type_name::with_defining_ids<TOKEN>()) {
                fee_info.value = fee_info.value + balance::value(&balance);
                balance::join(
                    dynamic_field::borrow_mut(&mut version.fee_pool.id, type_name::with_defining_ids<TOKEN>()),
                    balance,
                );
                return
            };
            i = i + 1;
        };
        vector::push_back(
            &mut version.fee_pool.fee_infos,
            FeeInfo {
                token: type_name::with_defining_ids<TOKEN>(),
                value: balance::value(&balance),
            },
        );
        dynamic_field::add(&mut version.fee_pool.id, type_name::with_defining_ids<TOKEN>(), balance);
    }

    #[test_only]
    use sui::test_scenario;

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test, expected_failure(abort_code = EInvalidVersion)]
    fun test_version_check_invalid_version_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.upgrade();
        version.value = 999;
        version.version_check();
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EUnauthorized)]
    fun test_verify_unauthorized_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.authority.remove(&scenario.sender());
        version.verify(test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_add_remove_authorized_user() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.add_authorized_user(@0xFFFF, test_scenario::ctx(&mut scenario));
        version.remove_authorized_user(@0xFFFF, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EAuthorityAlreadyExists)]
    fun test_add_authorized_user_authority_already_exists_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.add_authorized_user(@0xABCD, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EAuthorityDoesNotExist)]
    fun test_remove_authorized_user_authority_does_not_exists_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.remove_authorized_user(@0xAAAA, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EAuthorityEmpty)]
    fun test_remove_authorized_user_authority_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.remove_authorized_user(@0xABCD, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }
    #[test_only]
    public struct TestToken has drop {}
    #[test]
    fun test_send_fee() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.charge_fee<TestToken>(balance::create_for_testing(10));
        version.charge_fee<sui::sui::SUI>(balance::create_for_testing(10));
        version.charge_fee<sui::sui::SUI>(balance::create_for_testing(10));
        version.send_fee<sui::sui::SUI>(test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }
}