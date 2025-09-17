/// This module is deprecated. All functions within this module are no longer in use and will abort if called.
/// Use `typus/sources/tails_staking.move` instead.
module typus_dov::tails_staking {
    use std::string::String;
    use std::type_name::TypeName;

    use sui::balance::Balance;
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::kiosk::{Kiosk, KioskOwnerCap};
    use sui::object_table::ObjectTable;
    use sui::sui::SUI;
    use sui::transfer_policy::TransferPolicy;
    use sui::vec_map::VecMap;

    use typus_dov::typus_dov_single::Registry;
    use typus_framework::vault::{TypusBidReceipt, TypusDepositReceipt};
    use typus_nft::typus_nft::{Tails, ManagerCap as NftManagerCap};
    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::leaderboard::TypusLeaderboardRegistry;
    use typus::tgld::TgldRegistry;
    use typus::user::TypusUserRegistry;

    const E_DEPRECATED_FUNCTION: u64 = 999;

    #[allow(unused_field)]
    public struct NftExtension has key, store {
        id: UID,
        nft_table: ObjectTable<address, Tails>,
        nft_manager_cap: NftManagerCap,
        policy: TransferPolicy<Tails>,
        fee: Balance<SUI>,
    }
    #[allow(unused_field)]
    public struct WithdrawEvent has copy, drop {
        sender: address,
        receiver: address,
        amount: u64,
    }
    #[allow(unused_field)]
    public struct StakeNftEvent has copy, drop {
        sender: address,
        nft_id: ID,
        number: u64,
        ts_ms: u64,
    }
    #[allow(unused_field)]
    public struct UnstakeNftEvent has copy, drop {
        sender: address,
        nft_id: ID,
        number: u64,
    }
    #[allow(unused_field)]
    public struct TransferNftEvent has copy, drop {
        sender: address,
        receiver: address,
        nft_id: ID,
        number: u64,
    }
    #[allow(unused_field)]
    public struct DailyAttendEvent has copy, drop {
        sender: address,
        nft_id: ID,
        number: u64,
        ts_ms: u64,
        exp_earn: u64
    }
    #[allow(unused_field)]
    public struct UpdateDepositEvent has copy, drop {
        sender: address,
        nft_id: ID,
        number: u64,
        before: u64,
        after: u64,
    }
    #[allow(unused_field)]
    public struct SnapshotNftEvent has copy, drop {
        sender: address,
        nft_id: ID,
        number: u64,
        ts_ms: u64,
        exp_earn: u64
    }
    #[allow(unused_field)]
    public struct ClaimProfitSharingEvent has copy, drop {
        value: u64,
        token: TypeName,
        sender: address,
        nft_id: ID,
        number: u64,
        level: u64,
    }
    #[allow(unused_field)]
    public struct ClaimProfitSharingEventV2 has copy, drop {
        value: u64,
        token: TypeName,
        sender: address,
        nft_id: ID,
        number: u64,
        level: u64,
        name: String, // dice_profit, exp_profit
    }
    #[allow(unused_field)]
    public struct ProfitSharing<phantom TOKEN> has store {
        level_profits: vector<u64>,
        level_users: vector<u64>,
        total: u64, // fixed
        remaining: u64,
        pool: Balance<TOKEN>
    }
    #[allow(unused_field)]
    public struct ProfitSharingEvent has copy, drop {
        level_profits: vector<u64>,
        value: u64,
        token: TypeName,
    }
    #[allow(unused_field)]
    public struct LevelUpEvent has copy, drop {
        nft_id: ID,
        number: u64,
        sender: address,
        level: u64
    }
    #[allow(unused_field)]
    public struct UpdateUrlEvent has copy, drop {
        nft_id: ID,
        number: u64,
        level: u64,
        url: vector<u8>,
    }
    #[allow(unused_field)]
    public struct Partner has key, store {
        id: UID,
        exp_allocation: u64,
        partner_traits: VecMap<String, String>,
    }
    #[allow(unused_field)]
    public struct PartnerKey has key, store {
        id: UID,
        `for`: ID,
        partner: String,
    }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun remove_nft_extension(
        registry: &mut Registry,
        ctx: &mut TxContext
    ): (ObjectTable<address, Tails>, NftManagerCap, TransferPolicy<Tails>, Coin<SUI>) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun remove_nft_table_tails(
        registry: &Registry,
        nft_table: &mut ObjectTable<address, Tails>,
        users: vector<address>,
        ctx: &TxContext
    ): vector<Tails> { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun new_bid<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        coins: vector<Coin<B_TOKEN>>,
        size: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (TypusBidReceipt, vector<u64>) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun new_bid_v2<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        coins: vector<Coin<B_TOKEN>>,
        size: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (TypusBidReceipt, Coin<B_TOKEN>, vector<u64>) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun bid<D_TOKEN, B_TOKEN>(
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        tgld_registry: &mut TgldRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        registry: &mut Registry,
        index: u64,
        coins: vector<Coin<B_TOKEN>>,
        size: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (TypusBidReceipt, Coin<B_TOKEN>, vector<u64>) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun deposit<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        coins: vector<Coin<D_TOKEN>>,
        amount: u64,
        receipts: vector<TypusDepositReceipt>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (vector<Coin<D_TOKEN>>, TypusDepositReceipt, vector<u64>) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun withdraw<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        share: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Balance<D_TOKEN>, Option<TypusDepositReceipt>, vector<u64>) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun unsubscribe<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        share: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (TypusDepositReceipt, vector<u64>) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun compound<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (TypusDepositReceipt, vector<u64>) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun reduce_usd_in_deposit(
        registry: &mut Registry,
        user: address,
        reduce_in_usd: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun partner_add_exp(
        registry: &mut Registry,
        partner_key: &PartnerKey,
        owner: address,
        exp: u64,
    ) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun nft_exp_up(
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        registry: &mut Registry,
        amount: u64,
        ctx: &TxContext,
    ) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public entry fun stake_nft(
        registry: &mut Registry,
        kiosk: &mut Kiosk,
        kiosk_cap: &KioskOwnerCap,
        id: ID,
        clock: &Clock,
        coin: Coin<SUI>,
        ctx: &mut TxContext
    ) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public entry fun switch_nft(
        registry: &mut Registry,
        kiosk: &mut Kiosk,
        kiosk_cap: &KioskOwnerCap,
        id: ID,
        clock: &Clock,
        coin: Coin<SUI>,
        ctx: &mut TxContext
    ) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public entry fun unstake_nft(
        registry: &mut Registry,
        kiosk: &mut Kiosk,
        kiosk_cap: &KioskOwnerCap,
        ctx: & TxContext
    ) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public entry fun transfer_nft(
        registry: &mut Registry,
        from_kiosk: &mut Kiosk,
        from_kiosk_cap: &KioskOwnerCap,
        id: ID,
        receiver: address,
        coin: Coin<SUI>,
        ctx: &mut TxContext
    ) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun migrate_nft_extension(
        registry: &mut Registry,
        nft_table: ObjectTable<address, Tails>,
        nft_manager_cap: NftManagerCap,
        policy: TransferPolicy<Tails>,
        fee: Coin<SUI>,
        ctx: &mut TxContext
    ) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun migrate_typus_ecosystem_tails(
        registry: &mut Registry,
        users: vector<address>,
        ctx: &TxContext,
    ): vector<Tails> { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public entry fun consume_exp_coin_unstaked<EXP_COIN>(
        registry: &mut Registry,
        kiosk: &mut Kiosk,
        kiosk_cap: &KioskOwnerCap,
        id: ID,
        exp_coin: Coin<EXP_COIN>,
        ctx: &mut TxContext
    ) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public entry fun consume_exp_coin_staked<EXP_COIN>(
        registry: &mut Registry,
        exp_coin: Coin<EXP_COIN>,
        ctx: & TxContext
    ) { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun has_staked(
        registry: &Registry,
        owner: address,
    ): bool { abort E_DEPRECATED_FUNCTION }
    /// Deprecated.
    /// WARNING: mut inputs without authority check inside
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun snapshot(
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        registry: &mut Registry,
        amount: u64,
        ctx: &TxContext,
    ) { abort E_DEPRECATED_FUNCTION }
}