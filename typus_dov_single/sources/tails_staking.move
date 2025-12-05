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
    #[deprecated]
    public fun remove_nft_extension(
        _registry: &mut Registry,
        _ctx: &mut TxContext
    ): (ObjectTable<address, Tails>, NftManagerCap, TransferPolicy<Tails>, Coin<SUI>) { abort 0 }
    #[deprecated]
    public fun remove_nft_table_tails(
        _registry: &Registry,
        _nft_table: &mut ObjectTable<address, Tails>,
        _users: vector<address>,
        _ctx: &TxContext
    ): vector<Tails> { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun new_bid<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _coins: vector<Coin<B_TOKEN>>,
        _size: u64,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (TypusBidReceipt, vector<u64>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun new_bid_v2<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _coins: vector<Coin<B_TOKEN>>,
        _size: u64,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (TypusBidReceipt, Coin<B_TOKEN>, vector<u64>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun bid<D_TOKEN, B_TOKEN>(
        _typus_ecosystem_version: &TypusEcosystemVersion,
        _typus_user_registry: &mut TypusUserRegistry,
        _tgld_registry: &mut TgldRegistry,
        _typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        _registry: &mut Registry,
        _index: u64,
        _coins: vector<Coin<B_TOKEN>>,
        _size: u64,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (TypusBidReceipt, Coin<B_TOKEN>, vector<u64>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun deposit<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _coins: vector<Coin<D_TOKEN>>,
        _amount: u64,
        _receipts: vector<TypusDepositReceipt>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (vector<Coin<D_TOKEN>>, TypusDepositReceipt, vector<u64>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun withdraw<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _receipts: vector<TypusDepositReceipt>,
        _share: Option<u64>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (Balance<D_TOKEN>, Option<TypusDepositReceipt>, vector<u64>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun unsubscribe<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _receipts: vector<TypusDepositReceipt>,
        _share: Option<u64>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (TypusDepositReceipt, vector<u64>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun compound<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _receipts: vector<TypusDepositReceipt>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (TypusDepositReceipt, vector<u64>) { abort 0 }
    #[deprecated]
    public fun reduce_usd_in_deposit(
        _registry: &mut Registry,
        _user: address,
        _reduce_in_usd: u64,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ) { abort 0 }
    #[deprecated]
    public fun partner_add_exp(
        _registry: &mut Registry,
        _partner_key: &PartnerKey,
        _owner: address,
        _exp: u64,
    ) { abort 0 }
    #[deprecated]
    public fun nft_exp_up(
        _typus_ecosystem_version: &TypusEcosystemVersion,
        _typus_user_registry: &mut TypusUserRegistry,
        _registry: &mut Registry,
        _amount: u64,
        _ctx: &TxContext,
    ) { abort 0 }
    #[deprecated]
    public fun stake_nft(
        _registry: &mut Registry,
        _kiosk: &mut Kiosk,
        _kiosk_cap: &KioskOwnerCap,
        _id: ID,
        _clock: &Clock,
        _coin: Coin<SUI>,
        _ctx: &mut TxContext
    ) { abort 0 }
    #[deprecated]
    public fun switch_nft(
        _registry: &mut Registry,
        _kiosk: &mut Kiosk,
        _kiosk_cap: &KioskOwnerCap,
        _id: ID,
        _clock: &Clock,
        _coin: Coin<SUI>,
        _ctx: &mut TxContext
    ) { abort 0 }
    #[deprecated]
    public fun unstake_nft(
        _registry: &mut Registry,
        _kiosk: &mut Kiosk,
        _kiosk_cap: &KioskOwnerCap,
        _ctx: &TxContext
    ) { abort 0 }
    #[deprecated]
    public fun transfer_nft(
        _registry: &mut Registry,
        _from_kiosk: &mut Kiosk,
        _from_kiosk_cap: &KioskOwnerCap,
        _id: ID,
        _receiver: address,
        _coin: Coin<SUI>,
        _ctx: &mut TxContext
    ) { abort 0 }
    #[deprecated]
    public fun migrate_nft_extension(
        _registry: &mut Registry,
        _nft_table: ObjectTable<address, Tails>,
        _nft_manager_cap: NftManagerCap,
        _policy: TransferPolicy<Tails>,
        _fee: Coin<SUI>,
        _ctx: &mut TxContext
    ) { abort 0 }
    #[deprecated]
    public fun migrate_typus_ecosystem_tails(
        _registry: &mut Registry,
        _users: vector<address>,
        _ctx: &TxContext,
    ): vector<Tails> { abort 0 }
    #[deprecated]
    public fun consume_exp_coin_unstaked<EXP_COIN>(
        _registry: &mut Registry,
        _kiosk: &mut Kiosk,
        _kiosk_cap: &KioskOwnerCap,
        _id: ID,
        _exp_coin: Coin<EXP_COIN>,
        _ctx: &mut TxContext
    ) { abort 0 }
    #[deprecated]
    public fun consume_exp_coin_staked<EXP_COIN>(
        _registry: &mut Registry,
        _exp_coin: Coin<EXP_COIN>,
        _ctx: &TxContext
    ) { abort 0 }
    #[deprecated]
    public fun has_staked(
        _registry: &Registry,
        _owner: address,
    ): bool { abort 0 }
    #[deprecated]
    public fun snapshot(
        _typus_ecosystem_version: &TypusEcosystemVersion,
        _typus_user_registry: &mut TypusUserRegistry,
        _registry: &mut Registry,
        _amount: u64,
        _ctx: &TxContext,
    ) { abort 0 }
}