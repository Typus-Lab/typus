/// The `admin` module provides administrative functionalities for the Typus Stake Pool.
/// It includes version management, authority control, and fee handling.
module typus_stake_pool::admin {
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::coin;
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::vec_set::{Self, VecSet};

    // ======== Errors ========
    const EAuthorityAlreadyExists: u64 = 0;
    const EAuthorityDoesNotExist: u64 = 1;
    const EAuthorityEmpty: u64 = 2;
    const EInvalidVersion: u64 = 3;
    const EUnauthorized: u64 = 4;

    // ======== Constants ========
    const CVersion: u64 = 2;

    // ======== Version ========

    /// A shared object that holds the version of the contract, the fee pools, and the authority list.
    public struct Version has key {
        id: UID,
        /// The version number.
        value: u64,
        /// The list of authorized addresses.
        authority: VecSet<address>,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// Checks if the contract version is valid.
    public(package) fun version_check(version: &Version) {
        assert!(CVersion >= version.value, EInvalidVersion);
    }

    /// Upgrades the contract version.
    /// WARNING: no authority check inside
    entry fun upgrade(version: &mut Version) {
        version_check(version);
        version.value = CVersion;
    }

    // ======== Init ========

    /// Initializes the contract.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(Version {
            id: object::new(ctx),
            value: CVersion,
            authority: vec_set::singleton(tx_context::sender(ctx)),
            u64_padding: vector[],
        });
    }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    // ======== Authority ========

    /// [Authorized Function] Verifies if the sender is an authorized user.
    public(package) fun verify(
        version: &Version,
        ctx: &TxContext,
    ) {
        version_check(version);

        assert!(
            vec_set::contains(&version.authority, &tx_context::sender(ctx)),
            EUnauthorized
        );
    }

    /// [Authorized Function] Adds an authorized user.
    entry fun add_authorized_user(
        version: &mut Version,
        user_address: address,
        ctx: &TxContext,
    ) {
        verify(version, ctx);

        assert!(!vec_set::contains(&version.authority, &user_address), EAuthorityAlreadyExists);
        vec_set::insert(&mut version.authority, user_address);
    }

    /// [Authorized Function] Removes an authorized user.
    entry fun remove_authorized_user(
        version: &mut Version,
        user_address: address,
        ctx: &TxContext,
    ) {
        verify(version, ctx);

        assert!(vec_set::contains(&version.authority, &user_address), EAuthorityDoesNotExist);
        vec_set::remove(&mut version.authority, &user_address);
        assert!(vec_set::length(&version.authority) > 0, EAuthorityEmpty);
    }

    // ======== Tails Exp & Leaderboard ========
    use typus::ecosystem::{Self, Version as TypusEcosystemVersion};
    use typus::user::{Self, TypusUserRegistry};

    /// [Authorized Function] Installs the ecosystem manager cap.
    /// TODO: can be remove after install
    entry fun install_ecosystem_manager_cap_entry(
        version: &mut Version,
        typus_ecosystem_version: &TypusEcosystemVersion,
        ctx: &TxContext,
    ) {
        verify(version, ctx);
        let manager_cap = ecosystem::issue_manager_cap(typus_ecosystem_version, ctx);
        dynamic_field::add(&mut version.id, std::string::utf8(b"ecosystem_manager_cap"), manager_cap);
    }

    /// Adds tails experience points to a user.
    public(package) fun add_tails_exp_amount(
        version: &Version,
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        user: address,
        amount: u64,
    ) {
        user::add_tails_exp_amount(
            dynamic_field::borrow(&version.id, std::string::utf8(b"ecosystem_manager_cap")),
            typus_ecosystem_version,
            typus_user_registry,
            user,
            amount
        );
    }
}