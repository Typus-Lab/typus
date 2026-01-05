/// No authority chech in these public functions, do not let `DepositVault` `BidVault` and `RefundVault` be exposed.
module typus_framework::vault {
    use std::string::{Self, String};
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::coin::Coin;
    use sui::display;
    use sui::dynamic_field;

    use typus_framework::balance_pool::{Self, BalancePool};
    use typus_framework::big_vector::{Self, BigVector};
    use typus_framework::utils;

    #[test_only]
    use sui::test_scenario;

    // ======== Errors ========

    #[error]
    const EZeroValue: vector<u8> = b"zero_value";
    #[error]
    const EInvalidToken: vector<u8> = b"invalid_token";
    #[error]
    const EInvalidShareTag: vector<u8> = b"invalid_share_tag";
    #[error]
    const EInvalidDepositReceipt: vector<u8> = b"invalid_deposit_receipt";
    #[error]
    const EInvalidBidReceipt: vector<u8> = b"invalid_bid_receipt";
    #[error]
    const EDepositDisabled: vector<u8> = b"deposit_disabled";
    #[error]
    const EInvalidBalanceValue: vector<u8> = b"invalid_balance_value";

    // ======== DepositVault u64_padding Index ========

    const I_INCENTIVE_FEE: u64 = 0;

    // ======== Dynamic Field Key ========

    const K_ACTIVE_BALANCE: vector<u8> = b"active_balance";
    const K_DEACTIVATING_BALANCE: vector<u8> = b"deactivating_balance";
    const K_INACTIVE_BALANCE: vector<u8> = b"inactive_balance";
    const K_WARMUP_BALANCE: vector<u8> = b"warmup_balance";
    const K_PREMIUM_BALANCE: vector<u8> = b"premium_balance";
    const K_BID_BALANCE: vector<u8> = b"bid_balance";
    const K_INCENTIVE_BALANCE: vector<u8> = b"incentive_balance";
    const K_REFUND_BALANCE: vector<u8> = b"refund_balance";
    const K_DEPOSIT_SHARES: vector<u8> = b"deposit_shares";
    const K_BID_SHARES: vector<u8> = b"bid_shares";
    const K_REFUND_SHARES: vector<u8> = b"refund_shares";

    // ======== Tag ========

    const T_ACTIVE_SHARE: u8 = 0;
    const T_DEACTIVATING_SHARE: u8 = 1;
    const T_INACTIVE_SHARE: u8 = 2;
    const T_WARMUP_SHARE: u8 = 3;
    const T_PREMIUM_SHARE: u8 = 4;
    const T_INCENTIVE_SHARE: u8 = 5;

    // ======== Structs ========

    /// One-time witness for the vault module.
    public struct VAULT has drop {}

    /// The main vault for user deposits. It manages different sub-vaults (active, deactivating, inactive, warmup, premium, incentive)
    /// as balances and tracks user shares in a `BigVector`.
    ///
    /// The lifecycle of funds in the vault is as follows:
    /// 1. **Deposit**: User deposits funds, which go into the `warmup` sub-vault.
    /// 2. **Activate**: A manager activates the vault, moving funds from `warmup` to `active`.
    /// 3. **Unsubscribe**: A user unsubscribes, moving their share from `active` to `deactivating`.
    /// 4. **Recoup/Settle/Delivery**: These are manager-only functions that handle the outcome of the strategy.
    ///    - Unfilled portions are refunded.
    ///    - Premiums are collected.
    ///    - Funds are moved between sub-vaults based on the outcome and whether there is a next round.
    /// 5. **Claim/Harvest**: Users claim their funds from the `inactive` sub-vault or harvest premiums.
    public struct DepositVault has key, store {
        id: UID,
        /// The type of the token that is deposited into the vault.
        deposit_token: TypeName,
        /// The type of the token that is used for bidding/premiums.
        bid_token: TypeName,
        /// The type of the incentive token, if any.
        incentive_token: Option<TypeName>,
        /// An index for the vault, often corresponding to an auction.
        index: u64,
        /// The fee in basis points.
        fee_bp: u64,
        /// The portion of the fee that is shared, in basis points.
        fee_share_bp: u64,
        /// The key for the shared fee pool, if any.
        shared_fee_pool: Option<vector<u8>>,
        /// The total supply of shares in the active sub-vault.
        active_share_supply: u64,
        /// The total supply of shares in the deactivating sub-vault (for users who have unsubscribed).
        deactivating_share_supply: u64, // unsubscribe
        /// The total supply of shares in the inactive sub-vault (for users to claim).
        inactive_share_supply: u64, // claim
        /// The total supply of shares in the warmup sub-vault (for new deposits).
        warmup_share_supply: u64, // deposit / withdraw
        /// The total supply of shares in the premium sub-vault (for harvesting).
        premium_share_supply: u64, // harvest
        /// The total supply of shares in the incentive sub-vault (for redeeming).
        incentive_share_supply: u64, // redeem
        /// A flag indicating if there is a next round for the vault.
        has_next: bool,
        /// Metadata for display purposes.
        metadata: String,
        /// Padding for additional u64 fields.
        u64_padding: vector<u64>,
        /// Padding for additional BCS-encoded fields.
        bcs_padding: vector<u8>,
    }

    /// Holds the funds from bidders.
    public struct BidVault has key, store {
        id: UID,
        /// The type of the token that is deposited into the vault.
        deposit_token: TypeName,
        /// The type of the token that is used for bidding.
        bid_token: TypeName,
        /// The type of the incentive token, if any.
        incentive_token: Option<TypeName>,
        /// An index for the vault.
        index: u64,
        /// The total supply of shares in the vault.
        share_supply: u64,
        /// Metadata for display purposes.
        metadata: String,
        /// Padding for additional u64 fields.
        u64_padding: vector<u64>,
        /// Padding for additional BCS-encoded fields.
        bcs_padding: vector<u8>,
    }

    /// Holds funds to be refunded to users.
    public struct RefundVault has key, store {
        id: UID,
        /// The type of the token being refunded.
        token: TypeName,
        /// The total supply of shares in the vault.
        share_supply: u64,
        /// Padding for additional u64 fields.
        u64_padding: vector<u64>,
        /// Padding for additional BCS-encoded fields.
        bcs_padding: vector<u8>,
    }

    /// Represents a user's shares in the `DepositVault`.
    public struct DepositShare has copy, store {
        /// The address of the user's receipt NFT.
        receipt: address,
        /// The user's share in the active sub-vault.
        active_share: u64,
        /// The user's share in the deactivating sub-vault.
        deactivating_share: u64,
        /// The user's share in the inactive sub-vault.
        inactive_share: u64,
        /// The user's share in the warmup sub-vault.
        warmup_share: u64,
        /// The user's share in the premium sub-vault.
        premium_share: u64,
        /// The user's share in the incentive sub-vault.
        incentive_share: u64,
        /// Padding for additional u64 fields.
        u64_padding: vector<u64>,
    }

    /// An NFT that represents a user's deposit.
    public struct TypusDepositReceipt has key, store {
        id: UID,
        /// The ID of the `DepositVault`.
        vid: ID,
        /// The index of the vault.
        index: u64,
        /// Metadata for display purposes.
        metadata: String,
        /// Padding for additional u64 fields.
        u64_padding: vector<u64>,
    }

    /// Represents a bidder's shares in the `BidVault`.
    public struct BidShare has copy, store {
        /// The address of the bidder's receipt NFT.
        receipt: address,
        /// The bidder's share.
        share: u64,
        /// Padding for additional u64 fields.
        u64_padding: vector<u64>,
    }

    /// An NFT that represents a bid.
    public struct TypusBidReceipt has key, store {
        id: UID,
        /// The ID of the `BidVault`.
        vid: ID,
        /// The index of the vault.
        index: u64,
        /// Metadata for display purposes.
        metadata: String,
        /// Padding for additional u64 fields.
        u64_padding: vector<u64>,
    }

    /// Represents a user's share in the `RefundVault`.
    public struct RefundShare has copy, store {
        /// The address of the user.
        user: address,
        /// The user's share.
        share: u64,
        /// Padding for additional u64 fields.
        u64_padding: vector<u64>,
    }

    // ======== DepositVault Functions ========

    /// Creates a new `DepositVault`.
    public fun new_deposit_vault<D_TOKEN, B_TOKEN>(
        index: u64,
        fee_bp: u64,
        metadata: String,
        ctx: &mut TxContext,
    ): DepositVault {
        let mut id = object::new(ctx);
        let deposit_token = type_name::with_defining_ids<D_TOKEN>();
        let bid_token = type_name::with_defining_ids<B_TOKEN>();
        dynamic_field::add(&mut id, K_ACTIVE_BALANCE, balance::zero<D_TOKEN>());
        dynamic_field::add(&mut id, K_DEACTIVATING_BALANCE, balance::zero<D_TOKEN>());
        dynamic_field::add(&mut id, K_INACTIVE_BALANCE, balance::zero<D_TOKEN>());
        dynamic_field::add(&mut id, K_WARMUP_BALANCE, balance::zero<D_TOKEN>());
        dynamic_field::add(&mut id, K_PREMIUM_BALANCE, balance::zero<B_TOKEN>());
        dynamic_field::add(&mut id, K_DEPOSIT_SHARES, big_vector::new<DepositShare>(1000, ctx));

        let deposit_vault = DepositVault {
            id,
            deposit_token,
            bid_token,
            incentive_token: option::none(),
            index,
            fee_bp: fee_bp,
            fee_share_bp: 0,
            shared_fee_pool: option::none(),
            active_share_supply: 0,
            deactivating_share_supply: 0,
            inactive_share_supply: 0,
            warmup_share_supply: 0,
            premium_share_supply: 0,
            incentive_share_supply: 0,
            has_next: true,
            metadata,
            u64_padding: vector::empty(),
            bcs_padding: vector::empty()
        };

        deposit_vault
    }

    /// Creates a new `TypusDepositReceipt` NFT.
    public fun new_typus_deposit_receipt(
        deposit_vault: &DepositVault,
        ctx: &mut TxContext,
    ): TypusDepositReceipt {
        TypusDepositReceipt {
            id: object::new(ctx),
            vid: object::id(deposit_vault),
            index: deposit_vault.index,
            metadata: deposit_vault.metadata,
            u64_padding: vector::empty(),
        }
    }

    /// Updates the incentive token for a `DepositVault`.
    /// WARNING: mut inputs without authority check inside
    public fun update_deposit_vault_incentive_token<TOKEN>(
        deposit_vault: &mut DepositVault,
    ) {
        if (deposit_vault.incentive_token != option::some(type_name::with_defining_ids<TOKEN>())) {
            option::fill(&mut deposit_vault.incentive_token, type_name::with_defining_ids<TOKEN>());
            dynamic_field::add(&mut deposit_vault.id, K_INCENTIVE_BALANCE, balance::zero<TOKEN>());
        };
    }

    /// Updates the display metadata for a `DepositVault`.
    /// WARNING: mut inputs without authority check inside
    public fun update_deposit_receipt_display(
        deposit_vault: &mut DepositVault,
        metadata: String,
    ) {
        deposit_vault.metadata = metadata;
    }

    /// Transfers a `TypusDepositReceipt` to a user.
    public fun transfer_deposit_receipt(receipt: Option<TypusDepositReceipt>, user: address) {
        if (option::is_some(&receipt)) {
            transfer::public_transfer(option::destroy_some(receipt), user);
        } else {
            option::destroy_none(receipt);
        }
    }

    /// Updates the incentive fee for a `DepositVault`.
    /// WARNING: mut inputs without authority check inside
    public fun update_incentive_fee(
        deposit_vault: &mut DepositVault,
        incentive_fee_bp: u64,
    ) {
        // main logic
        utils::set_u64_padding_value(&mut deposit_vault.u64_padding, I_INCENTIVE_FEE, incentive_fee_bp + (1 << 63));
    }

    /// Updates the fee for a `DepositVault`.
    /// WARNING: mut inputs without authority check inside
    public fun update_fee(
        deposit_vault: &mut DepositVault,
        fee_bp: u64,
        _ctx: &TxContext,
    ) {
        // main logic
        deposit_vault.fee_bp = fee_bp;
    }

    /// Activates the vault, moving funds from the warmup sub-vault to the active sub-vault.
    /// WARNING: mut inputs without authority check inside
    public fun activate<TOKEN>(
        deposit_vault: &mut DepositVault,
        has_next: bool,
        _ctx: &TxContext,
    ): u64 {
        // safety check
        assert!(type_name::with_defining_ids<TOKEN>() == deposit_vault.deposit_token, EInvalidToken);

        // main logic
        let amount = balance::value(get_deposit_vault_balance<TOKEN>(deposit_vault, T_WARMUP_SHARE));
        if (amount > 0) {
            // update share supply
            let from_share_supply = get_mut_deposit_vault_share_supply(deposit_vault, T_WARMUP_SHARE);
            let from_share_supply_value = *from_share_supply;
            *from_share_supply = 0;
            let to_share_supply = get_mut_deposit_vault_share_supply(deposit_vault, T_ACTIVE_SHARE);
            *to_share_supply = *to_share_supply + from_share_supply_value;
            // merge balance
            let from_balance = balance::split(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_WARMUP_SHARE), amount);
            balance::join(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_ACTIVE_SHARE), from_balance);
            // update receipt share
            let deposit_shares = get_mut_deposit_shares(deposit_vault);
            let length = big_vector::length(deposit_shares);
            let slice_size = big_vector::slice_size(deposit_shares);
            let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
            let mut i = 0;
            while (i < length) {
                let deposit_share = vector::borrow_mut(slice, i % slice_size);
                let from_share = get_mut_deposit_share_inner(deposit_share, T_WARMUP_SHARE);
                if (*from_share > 0) {
                    let from_share_value = *from_share;
                    *from_share = 0;
                    let to_share = get_mut_deposit_share_inner(deposit_share, T_ACTIVE_SHARE);
                    *to_share = *to_share + from_share_value;
                };
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                    slice = big_vector::borrow_slice_mut(
                        deposit_shares,
                        slice_id,
                    );
                };
                i = i + 1;
            };
        };
        deposit_vault.has_next = has_next;

        amount
    }

    /// Recoups unfilled amounts after a round.
    /// - Refunds unfilled amount from deactivating_sub_vault to inactive_sub_vault.
    /// - Refunds unfilled amount from active_sub_vault.
    ///   - If `has_next` is true, funds are moved to the warmup_sub_vault.
    ///   - Otherwise, funds are moved to the inactive_sub_vault.
    /// WARNING: mut inputs without authority check inside
    public fun recoup<TOKEN>(
        deposit_vault: &mut DepositVault,
        mut refund_amount: u64,
        _ctx: &TxContext,
    ): (u64, u64) {
        // safety check
        assert!(type_name::with_defining_ids<TOKEN>() == deposit_vault.deposit_token, EInvalidToken);

        // main logic
        let has_next = deposit_vault.has_next;
        let mut refund_from_active_share = 0;
        let mut refund_from_deactivating_share = 0;
        let mut total_share_supply = active_balance<TOKEN>(deposit_vault)
                                    + deactivating_balance<TOKEN>(deposit_vault);
        if (total_share_supply > 0 && refund_amount > 0) {
            let deposit_shares = get_mut_deposit_shares(deposit_vault);
            let length = big_vector::length(deposit_shares);
            let slice_size = big_vector::slice_size(deposit_shares);
            let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
            let mut i = 0;
            while (i < length) {
                let deposit_share = vector::borrow_mut(slice, i % slice_size);
                let valid_share = deposit_share.active_share + deposit_share.deactivating_share;
                if (valid_share > 0) {
                    let refund_share = ((valid_share as u128) * (refund_amount as u128) / (total_share_supply as u128) as u64);
                    if (deposit_share.deactivating_share >= refund_share) {
                        deposit_share.deactivating_share = deposit_share.deactivating_share - refund_share;
                        deposit_share.inactive_share = deposit_share.inactive_share + refund_share;
                        refund_from_deactivating_share = refund_from_deactivating_share + refund_share;
                    } else {
                        deposit_share.active_share = deposit_share.active_share - (refund_share - deposit_share.deactivating_share);
                        if (has_next) {
                            deposit_share.warmup_share = deposit_share.warmup_share + (refund_share - deposit_share.deactivating_share);
                        } else {
                            deposit_share.inactive_share = deposit_share.inactive_share + (refund_share - deposit_share.deactivating_share);
                        };
                        refund_from_active_share = refund_from_active_share + (refund_share - deposit_share.deactivating_share);
                        deposit_share.inactive_share = deposit_share.inactive_share + deposit_share.deactivating_share;
                        refund_from_deactivating_share = refund_from_deactivating_share + deposit_share.deactivating_share;
                        deposit_share.deactivating_share = 0;
                    };
                    refund_amount = refund_amount - refund_share;
                    total_share_supply = total_share_supply - valid_share;
                };
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                    slice = big_vector::borrow_slice_mut(
                        deposit_shares,
                        slice_id,
                    );
                };
                i = i + 1;
            };
        };
        let refund_active_balance = balance::split(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_ACTIVE_SHARE), refund_from_active_share);
        if (has_next) {
            balance::join(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_WARMUP_SHARE), refund_active_balance);
        } else {
            balance::join(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_INACTIVE_SHARE), refund_active_balance);
        };
        let refund_deactivating_balance = balance::split(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_DEACTIVATING_SHARE), refund_from_deactivating_share);
        balance::join(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_INACTIVE_SHARE), refund_deactivating_balance);
        deposit_vault.active_share_supply = deposit_vault.active_share_supply - refund_from_active_share;
        if (has_next) {
            deposit_vault.warmup_share_supply = deposit_vault.warmup_share_supply + refund_from_active_share;
        } else {
            deposit_vault.inactive_share_supply = deposit_vault.inactive_share_supply + refund_from_active_share;
        };
        deposit_vault.deactivating_share_supply = deposit_vault.deactivating_share_supply - refund_from_deactivating_share;
        deposit_vault.inactive_share_supply = deposit_vault.inactive_share_supply + refund_from_deactivating_share;

        (refund_from_active_share, refund_from_deactivating_share)
    }

    /// Settles the vault based on the final share price.
    /// If the share price is less than the base (i.e., there was a loss), a payoff is transferred
    /// from the active and deactivating sub-vaults to the bid vault.
    /// The shares of depositors are adjusted accordingly.
    /// WARNING: mut inputs without authority check inside
    public fun settle<D_TOKEN, B_TOKEN>(
        deposit_vault: &mut DepositVault,
        bid_vault: &mut BidVault,
        share_price: u64,
        share_price_decimal: u64,
        _ctx: &mut TxContext,
    ) {
        // safety check
        assert!(share_price > 0, EZeroValue);
        assert!(type_name::with_defining_ids<D_TOKEN>() == deposit_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == deposit_vault.bid_token, EInvalidToken);
        assert!(type_name::with_defining_ids<D_TOKEN>() == bid_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == bid_vault.bid_token, EInvalidToken);

        // main logic
        let multiplier = utils::multiplier(share_price_decimal);
        let total_share_supply = active_balance<D_TOKEN>(deposit_vault)
                                    + deactivating_balance<D_TOKEN>(deposit_vault);
        if (total_share_supply != 0 && bid_vault.share_supply != 0) {
            // settle deposit vault
            if (share_price < multiplier) {
                let total_share_supply = active_share_supply(deposit_vault) + deactivating_share_supply(deposit_vault);
                // bidder receives balance from users
                let payoff = (total_share_supply as u256) * ((multiplier - share_price) as u256) / (multiplier as u256);
                // split balance from active users
                let active_balance_value = ((payoff * ( deposit_vault.active_share_supply as u256) / (total_share_supply as u256)) as u64);
                let active_balance = balance::split(get_mut_deposit_vault_balance<D_TOKEN>(deposit_vault, T_ACTIVE_SHARE), active_balance_value);
                // split balance from deactivating users
                let deactivating_balance_value = ((payoff * (deposit_vault.deactivating_share_supply as u256) / (total_share_supply as u256)) as u64);
                let deactivating_balance = balance::split(get_mut_deposit_vault_balance<D_TOKEN>(deposit_vault, T_DEACTIVATING_SHARE), deactivating_balance_value);
                // transfer balance to bid vault
                balance::join(get_mut_bid_vault_balance(bid_vault), active_balance);
                balance::join(get_mut_bid_vault_balance(bid_vault), deactivating_balance);
            };
            let mut active_balance_value = active_balance<D_TOKEN>(deposit_vault);
            let mut active_share_supply_value = deposit_vault.active_share_supply;
            let mut deactivating_balance_value = deactivating_balance<D_TOKEN>(deposit_vault);
            let mut deactivating_share_supply_value = deposit_vault.deactivating_share_supply;
            let has_next = deposit_vault.has_next;
            let deposit_shares = get_mut_deposit_shares(deposit_vault);
            let length = big_vector::length(deposit_shares);
            let slice_size = big_vector::slice_size(deposit_shares);
            let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
            let mut i = 0;
            while (i < length) {
                let deposit_share = vector::borrow_mut(slice, i % slice_size);
                if (deposit_share.active_share > 0) {
                    let adjusted_share = ((active_balance_value as u128)
                                            * (deposit_share.active_share as u128)
                                                / (active_share_supply_value as u128) as u64);
                    active_balance_value = active_balance_value - adjusted_share;
                    active_share_supply_value = active_share_supply_value - deposit_share.active_share;
                    if (!has_next) {
                        deposit_share.inactive_share = deposit_share.inactive_share + adjusted_share;
                        deposit_share.active_share = 0;
                    } else {
                        deposit_share.active_share = adjusted_share;
                    };
                };
                if (deposit_share.deactivating_share > 0) {
                    let adjusted_share = ((deactivating_balance_value as u128)
                                            * (deposit_share.deactivating_share as u128)
                                                / (deactivating_share_supply_value as u128) as u64);
                    deactivating_balance_value = deactivating_balance_value - adjusted_share;
                    deactivating_share_supply_value = deactivating_share_supply_value - deposit_share.deactivating_share;
                    deposit_share.inactive_share = deposit_share.inactive_share + adjusted_share;
                    deposit_share.deactivating_share = 0;
                };
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                    slice = big_vector::borrow_slice_mut(
                        deposit_shares,
                        slice_id,
                    );
                };
                i = i + 1;
            };
            // move balance
            if (!has_next) {
                let active_balance_value = active_balance<D_TOKEN>(deposit_vault);
                if (active_balance_value > 0) {
                    let active_balance = balance::split(
                        get_mut_deposit_vault_balance<D_TOKEN>(deposit_vault, T_ACTIVE_SHARE),
                        active_balance_value
                    );
                    balance::join(
                        get_mut_deposit_vault_balance<D_TOKEN>(deposit_vault, T_INACTIVE_SHARE),
                        active_balance
                    );
                };
            };
            let deactivating_balance_value = deactivating_balance<D_TOKEN>(deposit_vault);
            if (deactivating_balance_value > 0) {
                let deactivating_balance = balance::split(
                    get_mut_deposit_vault_balance<D_TOKEN>(deposit_vault, T_DEACTIVATING_SHARE),
                    deactivating_balance_value
                );
                balance::join(
                    get_mut_deposit_vault_balance<D_TOKEN>(deposit_vault, T_INACTIVE_SHARE),
                    deactivating_balance
                );
            };
            deposit_vault.active_share_supply = active_balance<D_TOKEN>(deposit_vault);
            deposit_vault.deactivating_share_supply = 0;
            deposit_vault.inactive_share_supply = inactive_balance<D_TOKEN>(deposit_vault);

        };
    }

    /// Closes the vault, preventing new activations.
    /// WARNING: mut inputs without authority check inside
    public fun close(
        deposit_vault: &mut DepositVault
    ) {
        deposit_vault.has_next = false;
    }

    /// Resumes the vault, allowing new activations.
    /// WARNING: mut inputs without authority check inside
    public fun resume(
        deposit_vault: &mut DepositVault
    ) {
        deposit_vault.has_next = true;
    }

    /// Terminates the vault, moving all funds to the inactive sub-vault.
    /// WARNING: mut inputs without authority check inside
    public fun terminate<TOKEN>(
        deposit_vault: &mut DepositVault,
        _ctx: &TxContext,
    ) {
        // safety check
        assert!(type_name::with_defining_ids<TOKEN>() == deposit_vault.deposit_token, EInvalidToken);

        // main logic
        // merge balance
        let active_balance = dynamic_field::remove<vector<u8>, Balance<TOKEN>>(&mut deposit_vault.id, K_ACTIVE_BALANCE);
        let deactivating_balance = dynamic_field::remove<vector<u8>, Balance<TOKEN>>(&mut deposit_vault.id, K_DEACTIVATING_BALANCE);
        let warmup_balance = dynamic_field::remove<vector<u8>, Balance<TOKEN>>(&mut deposit_vault.id, K_WARMUP_BALANCE);
        balance::join(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_INACTIVE_SHARE), active_balance);
        balance::join(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_INACTIVE_SHARE), deactivating_balance);
        balance::join(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_INACTIVE_SHARE), warmup_balance);
        // update share supply
        deposit_vault.inactive_share_supply =  deposit_vault.inactive_share_supply
            + deposit_vault.active_share_supply
            + deposit_vault.deactivating_share_supply
            + deposit_vault.warmup_share_supply;
        deposit_vault.active_share_supply = 0;
        deposit_vault.deactivating_share_supply = 0;
        deposit_vault.warmup_share_supply = 0;
        // update receipt share
        let deposit_shares = get_mut_deposit_shares(deposit_vault);
        let length = big_vector::length(deposit_shares);
        let slice_size = big_vector::slice_size(deposit_shares);
        let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
        let mut i = 0;
        while (i < length) {
            let deposit_share = vector::borrow_mut(slice, i % slice_size);
            deposit_share.inactive_share = deposit_share.inactive_share
                + deposit_share.active_share
                + deposit_share.deactivating_share
                + deposit_share.warmup_share;
            deposit_share.active_share = 0;
            deposit_share.deactivating_share = 0;
            deposit_share.warmup_share = 0;
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                slice = big_vector::borrow_slice_mut(
                    deposit_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };
        deposit_vault.has_next = false;
    }

    /// Destroys an empty `DepositVault`.
    public fun drop_deposit_vault<D_TOKEN, B_TOKEN>(deposit_vault: DepositVault) {
        let DepositVault {
            mut id,
            deposit_token: _,
            bid_token: _,
            incentive_token: _,
            index: _,
            fee_bp: _,
            fee_share_bp: _,
            shared_fee_pool: _,
            active_share_supply: _,
            deactivating_share_supply: _,
            inactive_share_supply: _,
            warmup_share_supply: _,
            premium_share_supply: _,
            incentive_share_supply: _,
            has_next: _,
            metadata: _,
            u64_padding: _,
            bcs_padding: _,
        } = deposit_vault;
        if (dynamic_field::exists_(&id, K_ACTIVE_BALANCE)) {
            balance::destroy_zero<D_TOKEN>(dynamic_field::remove(&mut id, K_ACTIVE_BALANCE));
        };
        if (dynamic_field::exists_(&id, K_DEACTIVATING_BALANCE)) {
            balance::destroy_zero<D_TOKEN>(dynamic_field::remove(&mut id, K_DEACTIVATING_BALANCE));
        };
        if (dynamic_field::exists_(&id, K_INACTIVE_BALANCE)) {
            balance::destroy_zero<D_TOKEN>(dynamic_field::remove(&mut id, K_INACTIVE_BALANCE));
        };
        if (dynamic_field::exists_(&id, K_WARMUP_BALANCE)) {
            balance::destroy_zero<D_TOKEN>(dynamic_field::remove(&mut id, K_WARMUP_BALANCE));
        };
        if (dynamic_field::exists_(&id, K_PREMIUM_BALANCE)) {
            balance::destroy_zero<B_TOKEN>(dynamic_field::remove(&mut id, K_PREMIUM_BALANCE));
        };
        big_vector::destroy_empty<DepositShare>(dynamic_field::remove(&mut id, K_DEPOSIT_SHARES));
        object::delete(id);
    }

    // ======== BidVault Functions ========

    /// Creates a new `BidVault`.
    public fun new_bid_vault<D_TOKEN, B_TOKEN>(
        index: u64,
        metadata: String,
        ctx: &mut TxContext,
    ): BidVault {
        let mut id = object::new(ctx);
        let deposit_token = type_name::with_defining_ids<D_TOKEN>();
        let bid_token = type_name::with_defining_ids<B_TOKEN>();
        dynamic_field::add(&mut id, K_BID_BALANCE, balance::zero<D_TOKEN>());
        dynamic_field::add(&mut id, K_BID_SHARES, big_vector::new<BidShare>(4500, ctx));

        let bid_vault = BidVault {
            id,
            deposit_token,
            bid_token,
            incentive_token: option::none(),
            index,
            share_supply: 0,
            metadata,
            u64_padding: vector::empty(),
            bcs_padding: vector::empty(),
        };

        bid_vault
    }

    /// Updates the display metadata for a `BidVault`.
    /// WARNING: mut inputs without authority check inside
    public fun update_bid_receipt_display(
        bid_vault: &mut BidVault,
        metadata: String,
    ) {
        bid_vault.metadata = metadata;
    }

    /// Updates the u64 padding for a `TypusBidReceipt`.
    /// WARNING: mut inputs without authority check inside
    public fun update_bid_receipt_u64_padding(
        bid_receipt: &mut TypusBidReceipt,
        u64_padding: vector<u64>,
    ) {
        bid_receipt.u64_padding = u64_padding;
    }

    /// Transfers a `TypusBidReceipt` to a user.
    public fun transfer_bid_receipt(receipt: Option<TypusBidReceipt>, user: address) {
        if (option::is_some(&receipt)) {
            transfer::public_transfer(option::destroy_some(receipt), user);
        } else {
            option::destroy_none(receipt);
        }
    }

    /// Creates a new bid in the `BidVault`.
    /// WARNING: mut inputs without authority check inside
    public fun public_new_bid(
        bid_vault: &mut BidVault,
        share: u64,
        ctx: &mut TxContext,
    ): TypusBidReceipt {
        bid_vault.share_supply = bid_vault.share_supply + share;
        let receipt = new_typus_bid_receipt(bid_vault, share, ctx);
        let bid_shares = get_mut_bid_shares(bid_vault);
        big_vector::push_back(
            bid_shares,
            BidShare {
                receipt: object::id_address(&receipt),
                share,
                u64_padding: vector::empty(),
            }
        );

        receipt
    }

    /// Exercises a bid, claiming the underlying assets.
    /// WARNING: mut inputs without authority check inside
    public fun public_exercise<TOKEN>(
        bid_vault: &mut BidVault,
        receipts: vector<TypusBidReceipt>,
    ): (Balance<TOKEN>, vector<u64>) {
        // safety check
        assert!(type_name::with_defining_ids<TOKEN>() == bid_vault.deposit_token, EInvalidToken);
        assert!(option::is_none(&bid_vault.incentive_token), EInvalidToken);

        // main logic
        let (share, _) = extract_bid_shares(bid_vault, receipts);
        let original_bid_vault_share_supply = bid_vault.share_supply;
        bid_vault.share_supply = bid_vault.share_supply - share;
        let bid_vault_balance = get_mut_bid_vault_balance(bid_vault);
        let amount = ((balance::value<TOKEN>(bid_vault_balance) as u128)
            * (share as u128) / (original_bid_vault_share_supply as u128) as u64);
        let balance: Balance<TOKEN> = balance::split(bid_vault_balance, amount);

        (
            balance,
            vector[amount, share],
        )
    }

    /// A delegated version of `public_exercise`.
    /// WARNING: mut inputs without authority check inside
    public fun delegate_exercise<TOKEN>(
        bid_vault: &mut BidVault,
        receipts: vector<TypusBidReceipt>,
    ): (u64, u64, Balance<TOKEN>) {
        let (b, v) = public_exercise(bid_vault, receipts);
        (*vector::borrow(&v, 0), *vector::borrow(&v, 1), b)
    }

    /// Calculates the value of exercising a set of bid receipts.
    public fun calculate_exercise_value_for_receipts<TOKEN>(
        bid_vault: &BidVault,
        receipts: &vector<TypusBidReceipt>
    ): u64 {
        // safety check
        assert!(type_name::with_defining_ids<TOKEN>() == bid_vault.deposit_token, EInvalidToken);
        assert!(option::is_none(&bid_vault.incentive_token), EInvalidToken);
        let mut share = 0;
        let mut i = 0;
        let length = vector::length(receipts);
        while (i < length) {
            let (_vid, _index, u64_padding) = get_bid_receipt_info(vector::borrow(receipts, i));
            share = share + *vector::borrow(&u64_padding, 0);
            i = i + 1;
        };
        let original_bid_vault_share_supply = bid_vault.share_supply;
        let bid_vault_balance = get_bid_vault_balance(bid_vault);
        let amount = ((balance::value<TOKEN>(bid_vault_balance) as u128)
            * (share as u128) / (original_bid_vault_share_supply as u128) as u64);
        amount
    }

    /// Calculates the value of exercising a single bid receipt.
    public fun calculate_exercise_value<TOKEN>(
        bid_vault: &BidVault,
        receipt: &TypusBidReceipt
    ): u64 {
        // safety check
        assert!(type_name::with_defining_ids<TOKEN>() == bid_vault.deposit_token, EInvalidToken);
        assert!(option::is_none(&bid_vault.incentive_token), EInvalidToken);
        let (_vid, _index, u64_padding) = get_bid_receipt_info(receipt);
        let share = *vector::borrow(&u64_padding, 0);
        let original_bid_vault_share_supply = bid_vault.share_supply;
        let bid_vault_balance = get_bid_vault_balance(bid_vault);
        let amount = ((balance::value<TOKEN>(bid_vault_balance) as u128)
            * (share as u128) / (original_bid_vault_share_supply as u128) as u64);
        amount
    }

    /// Splits a bid receipt into two, or merges multiple receipts.
    /// If `share` is `Some`, it splits the receipts into a new receipt with the specified share and a remainder receipt.
    /// If `share` is `None`, it merges all receipts into one.
    /// WARNING: mut inputs without authority check inside
    public fun split_bid_receipt(
        bid_vault: &mut BidVault,
        receipts: vector<TypusBidReceipt>,
        share: Option<u64>,     // if None, return (amount, Some(receipt), None)
        ctx: &mut TxContext,
    ): (u64, Option<TypusBidReceipt>, Option<TypusBidReceipt>) {
        // main logic
        let (
            mut bid_share,
            _,
        ) = extract_bid_shares(bid_vault, receipts);
        let mut amount = bid_share;
        if (option::is_some(&share)) {
            let share = option::destroy_some(share);
            if (share < bid_share) {
                amount = share;
            }
        };
        let split_receipt = if (amount > 0) {
            let receipt = new_typus_bid_receipt(bid_vault, amount, ctx);
            let bid_shares = get_mut_bid_shares(bid_vault);
            big_vector::push_back(
                bid_shares,
                BidShare {
                    receipt: object::id_address(&receipt),
                    share: amount,
                    u64_padding: vector::empty(),
                }
            );
            bid_share = bid_share - amount;
            option::some(receipt)
        } else {
            option::none()
        };
        let remain_receipt = if (bid_share > 0) {
            let receipt = new_typus_bid_receipt(bid_vault, bid_share, ctx);
            let bid_shares = get_mut_bid_shares(bid_vault);
            big_vector::push_back(
                bid_shares,
                BidShare {
                    receipt: object::id_address(&receipt),
                    share: bid_share,
                    u64_padding: vector::empty(),
                }
            );
            option::some(receipt)
        } else {
            option::none()
        };

        (amount, split_receipt, remain_receipt)
    }

    /// Delivers premium from a successful round to the deposit vault.
    /// The premium is distributed to depositors based on their share of the active and deactivating sub-vaults.
    /// WARNING: mut inputs without authority check inside
    public fun delivery<D_TOKEN, B_TOKEN>(
        deposit_vault: &mut DepositVault,
        bid_vault: &mut BidVault,
        premium_balance: Balance<B_TOKEN>,
    ) {
        // safety check
        assert!(type_name::with_defining_ids<D_TOKEN>() == deposit_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == deposit_vault.bid_token, EInvalidToken);
        assert!(type_name::with_defining_ids<D_TOKEN>() == bid_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == bid_vault.bid_token, EInvalidToken);

        // main logic
        let mut premium_balance_value = balance::value(&premium_balance);
        balance::join(
            get_mut_deposit_vault_balance(deposit_vault, T_PREMIUM_SHARE),
            premium_balance,
        );
        deposit_vault.premium_share_supply = deposit_vault.premium_share_supply + premium_balance_value;
        // update deposit shares
        let mut total_share_supply = active_share_supply(deposit_vault)
                                    + deactivating_share_supply(deposit_vault);
        let deposit_shares = get_mut_deposit_shares(deposit_vault);
        let length = big_vector::length(deposit_shares);
        let slice_size = big_vector::slice_size(deposit_shares);
        let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
        let mut i = 0;
        while (i < length) {
            let deposit_share = vector::borrow_mut(slice, i % slice_size);
            if (deposit_share.active_share > 0) {
                let adjusted_premium_share = ((premium_balance_value as u128) * (deposit_share.active_share as u128) / (total_share_supply as u128) as u64);
                deposit_share.premium_share = deposit_share.premium_share + adjusted_premium_share;
                premium_balance_value = premium_balance_value - adjusted_premium_share;
                total_share_supply = total_share_supply - deposit_share.active_share;
            };
            if (deposit_share.deactivating_share > 0) {
                let adjusted_premium_share = ((premium_balance_value as u128) * (deposit_share.deactivating_share as u128) / (total_share_supply as u128) as u64);
                deposit_share.premium_share = deposit_share.premium_share + adjusted_premium_share;
                premium_balance_value = premium_balance_value - adjusted_premium_share;
                total_share_supply = total_share_supply - deposit_share.deactivating_share;
            };
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                slice = big_vector::borrow_slice_mut(
                    deposit_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };
    }

    /// Delivers premium and incentives (of deposit token type) to the deposit vault.
    /// WARNING: mut inputs without authority check inside
    public fun delivery_d<D_TOKEN, B_TOKEN>(
        deposit_vault: &mut DepositVault,
        bid_vault: &mut BidVault,
        premium_balance: Balance<B_TOKEN>,
        incentive_balance: Balance<D_TOKEN>,
        _ctx: &TxContext,
    ) {
        // safety check
        assert!(type_name::with_defining_ids<D_TOKEN>() == deposit_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == deposit_vault.bid_token, EInvalidToken);
        assert!(type_name::with_defining_ids<D_TOKEN>() == bid_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == bid_vault.bid_token, EInvalidToken);

        let mut premium_balance_value = balance::value(&premium_balance);
        let mut incentive_balance_value = balance::value(&incentive_balance);
        // main logic
        balance::join(
            get_mut_deposit_vault_balance(deposit_vault, T_PREMIUM_SHARE),
            premium_balance,
        );
        deposit_vault.premium_share_supply = deposit_vault.premium_share_supply + premium_balance_value;
        balance::join(
            get_mut_deposit_vault_balance(deposit_vault, T_WARMUP_SHARE),
            incentive_balance,
        );
        deposit_vault.warmup_share_supply = deposit_vault.warmup_share_supply + incentive_balance_value;
        // update deposit shares
        let mut total_share_supply = active_share_supply(deposit_vault)
                                    + deactivating_share_supply(deposit_vault);
        let deposit_shares = get_mut_deposit_shares(deposit_vault);
        let length = big_vector::length(deposit_shares);
        let slice_size = big_vector::slice_size(deposit_shares);
        let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
        let mut i = 0;
        while (i < length) {
            let deposit_share = vector::borrow_mut(slice, i % slice_size);
            if (deposit_share.active_share > 0) {
                let adjusted_premium_share = ((premium_balance_value as u128) * (deposit_share.active_share as u128) / (total_share_supply as u128) as u64);
                let adjusted_incentive_share = ((incentive_balance_value as u128) * (deposit_share.active_share as u128) / (total_share_supply as u128) as u64);
                deposit_share.premium_share = deposit_share.premium_share + adjusted_premium_share;
                deposit_share.warmup_share = deposit_share.warmup_share + adjusted_incentive_share;
                premium_balance_value = premium_balance_value - adjusted_premium_share;
                incentive_balance_value = incentive_balance_value - adjusted_incentive_share;
                total_share_supply = total_share_supply - deposit_share.active_share;
            };
            if (deposit_share.deactivating_share > 0) {
                let adjusted_premium_share = ((premium_balance_value as u128) * (deposit_share.deactivating_share as u128) / (total_share_supply as u128) as u64);
                let adjusted_incentive_share = ((incentive_balance_value as u128) * (deposit_share.deactivating_share as u128) / (total_share_supply as u128) as u64);
                deposit_share.premium_share = deposit_share.premium_share + adjusted_premium_share;
                deposit_share.warmup_share = deposit_share.warmup_share + adjusted_incentive_share;
                premium_balance_value = premium_balance_value - adjusted_premium_share;
                incentive_balance_value = incentive_balance_value - adjusted_incentive_share;
                total_share_supply = total_share_supply - deposit_share.deactivating_share;
            };
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                slice = big_vector::borrow_slice_mut(
                    deposit_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };
    }

    /// Delivers premium and incentives (of bid token type) to the deposit vault.
    /// WARNING: mut inputs without authority check inside
    public fun delivery_b<D_TOKEN, B_TOKEN>(
        deposit_vault: &mut DepositVault,
        bid_vault: &mut BidVault,
        mut premium_balance: Balance<B_TOKEN>,
        incentive_balance: Balance<B_TOKEN>,
        _ctx: &TxContext,
    ) {
        // safety check
        assert!(type_name::with_defining_ids<D_TOKEN>() == deposit_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == deposit_vault.bid_token, EInvalidToken);
        assert!(type_name::with_defining_ids<D_TOKEN>() == bid_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == bid_vault.bid_token, EInvalidToken);

        // main logic
        balance::join(
            &mut premium_balance,
            incentive_balance,
        );
        let mut premium_balance_value = balance::value(&premium_balance);
        balance::join(
            get_mut_deposit_vault_balance(deposit_vault, T_PREMIUM_SHARE),
            premium_balance,
        );
        deposit_vault.premium_share_supply = deposit_vault.premium_share_supply + premium_balance_value;
        // update deposit shares
        let mut total_share_supply = active_share_supply(deposit_vault)
                                    + deactivating_share_supply(deposit_vault);
        let deposit_shares = get_mut_deposit_shares(deposit_vault);
        let length = big_vector::length(deposit_shares);
        let slice_size = big_vector::slice_size(deposit_shares);
        let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
        let mut i = 0;
        while (i < length) {
            let deposit_share = vector::borrow_mut(slice, i % slice_size);
            if (deposit_share.active_share > 0) {
                let adjusted_premium_share = ((premium_balance_value as u128) * (deposit_share.active_share as u128) / (total_share_supply as u128) as u64);
                deposit_share.premium_share = deposit_share.premium_share + adjusted_premium_share;
                premium_balance_value = premium_balance_value - adjusted_premium_share;
                total_share_supply = total_share_supply - deposit_share.active_share;
            };
            if (deposit_share.deactivating_share > 0) {
                let adjusted_premium_share = ((premium_balance_value as u128) * (deposit_share.deactivating_share as u128) / (total_share_supply as u128) as u64);
                deposit_share.premium_share = deposit_share.premium_share + adjusted_premium_share;
                premium_balance_value = premium_balance_value - adjusted_premium_share;
                total_share_supply = total_share_supply - deposit_share.deactivating_share;
            };
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                slice = big_vector::borrow_slice_mut(
                    deposit_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };
    }

    /// Delivers premium and incentives (of a third token type) to the deposit vault.
    /// WARNING: mut inputs without authority check inside
    public fun delivery_i<D_TOKEN, B_TOKEN, I_TOKEN>(
        deposit_vault: &mut DepositVault,
        bid_vault: &mut BidVault,
        premium_balance: Balance<B_TOKEN>,
        incentive_balance: Balance<I_TOKEN>,
        _ctx: &TxContext,
    ) {
        // safety check
        assert!(type_name::with_defining_ids<D_TOKEN>() == deposit_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == deposit_vault.bid_token, EInvalidToken);
        assert!(option::some(type_name::with_defining_ids<I_TOKEN>()) == deposit_vault.incentive_token, EInvalidToken);
        assert!(type_name::with_defining_ids<D_TOKEN>() == bid_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == bid_vault.bid_token, EInvalidToken);

        let mut premium_balance_value = balance::value(&premium_balance);
        let mut incentive_balance_value = balance::value(&incentive_balance);
        // main logic
        balance::join(
            get_mut_deposit_vault_balance(deposit_vault, T_PREMIUM_SHARE),
            premium_balance,
        );
        deposit_vault.premium_share_supply = deposit_vault.premium_share_supply + premium_balance_value;
        balance::join(
            get_mut_deposit_vault_balance(deposit_vault, T_INCENTIVE_SHARE),
            incentive_balance,
        );
        deposit_vault.incentive_share_supply = deposit_vault.incentive_share_supply + incentive_balance_value;
        // update deposit shares
        let mut total_share_supply = active_share_supply(deposit_vault)
                                    + deactivating_share_supply(deposit_vault);
        let deposit_shares = get_mut_deposit_shares(deposit_vault);
        let length = big_vector::length(deposit_shares);
        let slice_size = big_vector::slice_size(deposit_shares);
        let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
        let mut i = 0;
        while (i < length) {
            let deposit_share = vector::borrow_mut(slice, i % slice_size);
            if (deposit_share.active_share > 0) {
                let adjusted_premium_share = ((premium_balance_value as u128) * (deposit_share.active_share as u128) / (total_share_supply as u128) as u64);
                let adjusted_incentive_share = ((incentive_balance_value as u128) * (deposit_share.active_share as u128) / (total_share_supply as u128) as u64);
                deposit_share.premium_share = deposit_share.premium_share + adjusted_premium_share;
                deposit_share.incentive_share = deposit_share.incentive_share + adjusted_incentive_share;
                premium_balance_value = premium_balance_value - adjusted_premium_share;
                incentive_balance_value = incentive_balance_value - adjusted_incentive_share;
                total_share_supply = total_share_supply - deposit_share.active_share;
            };
            if (deposit_share.deactivating_share > 0) {
                let adjusted_premium_share = ((premium_balance_value as u128) * (deposit_share.deactivating_share as u128) / (total_share_supply as u128) as u64);
                let adjusted_incentive_share = ((incentive_balance_value as u128) * (deposit_share.deactivating_share as u128) / (total_share_supply as u128) as u64);
                deposit_share.premium_share = deposit_share.premium_share + adjusted_premium_share;
                deposit_share.incentive_share = deposit_share.incentive_share + adjusted_incentive_share;
                premium_balance_value = premium_balance_value - adjusted_premium_share;
                incentive_balance_value = incentive_balance_value - adjusted_incentive_share;
                total_share_supply = total_share_supply - deposit_share.deactivating_share;
            };
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                slice = big_vector::borrow_slice_mut(
                    deposit_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };
    }

    /// Sets a value in the u64 padding of a `BidVault`.
    /// WARNING: mut inputs without authority check inside
    public fun set_bid_vault_u64_padding_value(bid_vault: &mut BidVault, i: u64, value: u64) {
        utils::set_u64_padding_value(&mut bid_vault.u64_padding, i, value);
    }

    /// Gets a value from the u64 padding of a `BidVault`.
    public fun get_bid_vault_u64_padding_value(bid_vault: &BidVault, i: u64): u64 {
        utils::get_u64_padding_value(&bid_vault.u64_padding, i)
    }

    /// Destroys an empty `BidVault`.
    public fun drop_bid_vault<TOKEN>(bid_vault: BidVault) {
        let BidVault {
            mut id,
            deposit_token: _,
            bid_token: _,
            incentive_token: _,
            index: _,
            share_supply: _,
            metadata: _,
            u64_padding: _,
            bcs_padding: _,
        } = bid_vault;
        let balance: Balance<TOKEN> = dynamic_field::remove(&mut id, K_BID_BALANCE);
        let shares: BigVector<BidShare> = dynamic_field::remove(&mut id, K_BID_SHARES);
        balance::destroy_zero(balance);
        big_vector::destroy_empty(shares);
        object::delete(id);
    }

    // ======== RefundVault Functions ========

    /// Creates a new `RefundVault`.
    public fun new_refund_vault<TOKEN>(
        ctx: &mut TxContext,
    ): RefundVault {
        let mut id = object::new(ctx);
        let token = type_name::with_defining_ids<TOKEN>();
        dynamic_field::add(&mut id, K_REFUND_BALANCE, balance::zero<TOKEN>());
        dynamic_field::add(&mut id, K_REFUND_SHARES, big_vector::new<RefundShare>(4500, ctx));

        let refund_vault = RefundVault {
            id,
            token,
            share_supply: 0,
            u64_padding: vector::empty(),
            bcs_padding: vector::empty(),
        };

        refund_vault
    }

    /// Registers a user for a refund, returning their index in the refund shares vector.
    /// If the user is already registered, it returns their existing index.
    /// WARNING: mut inputs without authority check inside
    public fun register_refund<TOKEN>(
        refund_vault: &mut RefundVault,
        user: address
    ): u64 {
        // safety check
        assert!(type_name::with_defining_ids<TOKEN>() == refund_vault.token, EInvalidToken);

        // main logic
        let refund_shares: &mut BigVector<RefundShare> = dynamic_field::borrow_mut(&mut refund_vault.id, K_REFUND_SHARES);
        let length = big_vector::length(refund_shares);
        let slice_size = big_vector::slice_size(refund_shares);
        let mut slice = big_vector::borrow_slice_mut(refund_shares, 1);
        let mut i = 0;
        while (i < length) {
            let refund_share = vector::borrow_mut(slice, i % slice_size);
            if (refund_share.user == user) {
                return i
            };
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(refund_shares, i + 1);
                slice = big_vector::borrow_slice_mut(
                    refund_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };
        big_vector::push_back(
            refund_shares,
            RefundShare {
                user,
                share: 0,
                u64_padding: vector::empty(),
            }
        );

        i
    }

    /// Puts a refund into the `RefundVault` for a specific user.
    /// WARNING: mut inputs without authority check inside
    public fun put_refund<TOKEN>(
        refund_vault: &mut RefundVault,
        balance: Balance<TOKEN>,
        user: address
    ) {
        // safety check
        assert!(type_name::with_defining_ids<TOKEN>() == refund_vault.token, EInvalidToken);

        // main logic
        let amount = balance::value(&balance);
        refund_vault.share_supply = refund_vault.share_supply + amount;
        balance::join(
            dynamic_field::borrow_mut(&mut refund_vault.id, K_REFUND_BALANCE),
            balance,
        );
        let refund_shares: &mut BigVector<RefundShare> = dynamic_field::borrow_mut(&mut refund_vault.id, K_REFUND_SHARES);
        let length = big_vector::length(refund_shares);
        let slice_size = big_vector::slice_size(refund_shares);
        let mut slice = big_vector::borrow_slice_mut(refund_shares, 1);
        let mut i = 0;
        while (i < length) {
            let refund_share = vector::borrow_mut(slice, i % slice_size);
            if (refund_share.user == user) {
                refund_share.share = refund_share.share + amount;
                return
            };
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(refund_shares, i + 1);
                slice = big_vector::borrow_slice_mut(
                    refund_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };
        big_vector::push_back(
            refund_shares,
            RefundShare {
                user,
                share: amount,
                u64_padding: vector::empty(),
            }
        );
    }

    /// Puts refunds into the `RefundVault` for multiple users.
    /// WARNING: mut inputs without authority check inside
    public fun put_refunds<TOKEN>(
        refund_vault: &mut RefundVault,
        balance: Balance<TOKEN>,
        mut users: vector<u64>,
        mut shares: vector<u64>,
    ) {
        // safety check
        assert!(type_name::with_defining_ids<TOKEN>() == refund_vault.token, EInvalidToken);

        // main logic
        let amount = balance::value(&balance);
        refund_vault.share_supply = refund_vault.share_supply + amount;
        balance::join(
            dynamic_field::borrow_mut(&mut refund_vault.id, K_REFUND_BALANCE),
            balance,
        );
        let refund_shares: &mut BigVector<RefundShare> = dynamic_field::borrow_mut(&mut refund_vault.id, K_REFUND_SHARES);
        while (!vector::is_empty(&users) || !vector::is_empty(&shares)) {
            let user = vector::pop_back(&mut users);
            let share = vector::pop_back(&mut shares);
            let refund_share = big_vector::borrow_mut(refund_shares, user);
            refund_share.share = refund_share.share + share;
        };
    }

    /// Destroys an empty `RefundVault`.
    public fun drop_refund_vault<TOKEN>(refund_vault: RefundVault) {
        let RefundVault {
            mut id,
            token: _,
            share_supply: _,
            u64_padding: _,
            bcs_padding: _,
        } = refund_vault;
        let balance: Balance<TOKEN> = dynamic_field::remove(&mut id, K_REFUND_BALANCE);
        let shares: BigVector<RefundShare> = dynamic_field::remove(&mut id, K_REFUND_SHARES);
        balance::destroy_zero(balance);
        big_vector::destroy_empty(shares);
        object::delete(id);
    }

    // ======== Public Functions ========

    /// Merges multiple `TypusDepositReceipt` NFTs into a single one.
    /// WARNING: mut inputs without authority check inside
    public fun merge_deposit_receipts(
        deposit_vault: &mut DepositVault,
        receipts: vector<TypusDepositReceipt>,
        ctx: &mut TxContext,
    ): (Option<TypusDepositReceipt>, vector<u64>) {
        // main logic
        let (
            active_share,
            deactivating_share,
            inactive_share,
            warmup_share,
            premium_share,
            incentive_share,
            u64_padding,
        ) = extract_deposit_shares(deposit_vault, receipts);
        let receipt = add_deposit_share(
            deposit_vault,
            active_share,
            deactivating_share,
            inactive_share,
            warmup_share,
            premium_share,
            incentive_share,
            u64_padding,
            ctx,
        );
        (receipt, vector[active_share, deactivating_share, inactive_share, warmup_share, premium_share, incentive_share])
    }

    /// Splits a `TypusDepositReceipt` into two.
    /// WARNING: mut inputs without authority check inside
    public fun split_deposit_receipt(
        deposit_vault: &mut DepositVault,
        receipt: TypusDepositReceipt,
        split_active_share: u64,
        split_warmup_share: u64,
        ctx: &mut TxContext,
    ): (Option<TypusDepositReceipt>, Option<TypusDepositReceipt>) {
        // main logic
        let (
            active_share,
            deactivating_share,
            inactive_share,
            warmup_share,
            premium_share,
            incentive_share,
            u64_padding,
        ) = extract_deposit_shares(deposit_vault, vector[receipt]);
        let receipt_0 = add_deposit_share(
            deposit_vault,
            active_share - split_active_share,
            deactivating_share,
            inactive_share,
            warmup_share - split_warmup_share,
            premium_share,
            incentive_share,
            u64_padding,
            ctx,
        );
        let receipt_1 = add_deposit_share(
            deposit_vault,
            split_active_share,
            0,
            0,
            split_warmup_share,
            0,
            0,
            vector[],
            ctx,
        );

        (receipt_0, receipt_1)
    }

    /// Raises funds for a deposit, using a new balance and optionally existing premium and inactive shares.
    /// WARNING: mut inputs without authority check inside
    public fun raise_fund<TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        receipts: vector<TypusDepositReceipt>,
        raise_balance: Balance<TOKEN>,
        raise_from_premium: bool,
        raise_from_inactive: bool,
        ctx: &mut TxContext,
    ): (TypusDepositReceipt, vector<u64>) {
        // safety check
        assert!(deposit_vault.has_next, EDepositDisabled);
        assert!(type_name::with_defining_ids<TOKEN>() == deposit_vault.deposit_token, EInvalidToken);

        // main logic
        let (
            active_share,
            deactivating_share,
            mut inactive_share,
            mut warmup_share,
            mut premium_share,
            incentive_share,
            u64_padding,
        ) = extract_deposit_shares(deposit_vault, receipts);
        // raise from balance
        let balance_value = balance::value(&raise_balance);
        warmup_share = warmup_share + balance_value;
        deposit_vault.warmup_share_supply = deposit_vault.warmup_share_supply + balance_value;
        balance::join(get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_WARMUP_SHARE), raise_balance);
        // raise from premium
        let mut premium_value = if (raise_from_premium) { premium_share } else { 0 };
        let mut fee_amount = 0;
        let mut fee_share_amount = 0;
        if (premium_value > 0) {
            let mut premium_balance = balance::split(
                get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_PREMIUM_SHARE),
                premium_value,
            );
            premium_share = premium_share - premium_value;
            deposit_vault.premium_share_supply = deposit_vault.premium_share_supply - premium_value;
            let (
                charged_fee_amount,
                charged_fee_share_amount,
            ) = charge_fee(fee_pool, deposit_vault, &mut premium_balance);
            fee_amount = charged_fee_amount;
            fee_share_amount = charged_fee_share_amount;
            premium_value = balance::value(&premium_balance);
            balance::join(
                get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_WARMUP_SHARE),
                premium_balance,
            );
            warmup_share = warmup_share + premium_value;
            deposit_vault.warmup_share_supply = deposit_vault.warmup_share_supply + premium_value;
        };
        // raise from inactive
        let inactive_value = if (raise_from_inactive) { inactive_share } else { 0 };
        if (inactive_value > 0) {
            let inactive_balance = balance::split(
                get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_INACTIVE_SHARE),
                inactive_value,
            );
            inactive_share = inactive_share - inactive_value;
            deposit_vault.inactive_share_supply = deposit_vault.inactive_share_supply - inactive_value;
            balance::join(
                get_mut_deposit_vault_balance<TOKEN>(deposit_vault, T_WARMUP_SHARE),
                inactive_balance,
            );
            warmup_share = warmup_share + inactive_value;
            deposit_vault.warmup_share_supply = deposit_vault.warmup_share_supply + inactive_value;
        };
        let receipt = add_deposit_share(
            deposit_vault,
            active_share,
            deactivating_share,
            inactive_share,
            warmup_share,
            premium_share,
            incentive_share,
            u64_padding,
            ctx,
        );

        (
            option::destroy_some(receipt),
            vector[
                balance_value,
                premium_value,
                fee_amount,
                fee_share_amount,
                inactive_value,
                active_share + warmup_share,
            ]
        )
    }

    /// Reduces funds from a deposit, withdrawing from various sub-vaults.
    /// WARNING: mut inputs without authority check inside
    public fun reduce_fund<D_TOKEN, B_TOKEN, I_TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        receipts: vector<TypusDepositReceipt>,
        reduce_from_warmup: u64,
        reduce_from_active: u64,
        reduce_from_premium: bool,
        reduce_from_inactive: bool,
        reduce_from_incentive: bool,
        ctx: &mut TxContext,
    ): (Option<TypusDepositReceipt>, Balance<D_TOKEN>, Balance<B_TOKEN>, Balance<I_TOKEN>, vector<u64>) {
        // safety check
        assert!(type_name::with_defining_ids<D_TOKEN>() == deposit_vault.deposit_token, EInvalidToken);
        assert!(type_name::with_defining_ids<B_TOKEN>() == deposit_vault.bid_token, EInvalidToken);
        assert!(!reduce_from_incentive || option::some(type_name::with_defining_ids<I_TOKEN>()) == deposit_vault.incentive_token, EInvalidToken);

        // main logic
        let (
            mut active_share,
            mut deactivating_share,
            mut inactive_share,
            mut warmup_share,
            mut premium_share,
            mut incentive_share,
            u64_padding,
        ) = extract_deposit_shares(deposit_vault, receipts);
        let mut d_balance = balance::zero();
        let mut b_balance = balance::zero();
        let mut i_balance = balance::zero();
        let mut log = vector[];
        // reduce from warmup
        if (reduce_from_warmup > 0) {
            let amount = if (reduce_from_warmup > warmup_share) { warmup_share } else { reduce_from_warmup };
            balance::join(
                &mut d_balance,
                balance::split(
                    get_mut_deposit_vault_balance(deposit_vault, T_WARMUP_SHARE),
                    amount,
                )
            );
            warmup_share = warmup_share - amount;
            deposit_vault.warmup_share_supply = deposit_vault.warmup_share_supply - amount;
            vector::push_back(&mut log, amount);
        } else {
            vector::push_back(&mut log, 0);
        };
        // reduce from active
        if (reduce_from_active > 0) {
            let amount = if (reduce_from_active > active_share) { active_share } else { reduce_from_active };
            active_share = active_share - amount;
            deposit_vault.active_share_supply = deposit_vault.active_share_supply - amount;
            deactivating_share = deactivating_share + amount;
            deposit_vault.deactivating_share_supply = deposit_vault.deactivating_share_supply + amount;
            if (active_balance<D_TOKEN>(deposit_vault) > 0) {
                let balance = balance::split(
                    get_mut_deposit_vault_balance<D_TOKEN>(deposit_vault, T_ACTIVE_SHARE),
                    amount,
                );
                balance::join(
                    get_mut_deposit_vault_balance<D_TOKEN>(deposit_vault, T_DEACTIVATING_SHARE),
                    balance,
                );
            };
            vector::push_back(&mut log, amount);
        } else {
            vector::push_back(&mut log, 0);
        };
        // reduce from premium
        if (reduce_from_premium) {
            let mut amount = premium_share;
            let mut premium_balance = balance::split(
                get_mut_deposit_vault_balance<B_TOKEN>(deposit_vault, T_PREMIUM_SHARE),
                amount,
            );
            premium_share = premium_share - amount;
            deposit_vault.premium_share_supply = deposit_vault.premium_share_supply - amount;
            let (
                charged_fee_amount,
                charged_fee_share_amount,
            ) = charge_fee(fee_pool, deposit_vault, &mut premium_balance);
            amount = amount - charged_fee_amount - charged_fee_share_amount;
            balance::join(&mut b_balance, premium_balance);
            vector::append(&mut log, vector[amount, charged_fee_amount, charged_fee_share_amount]);
        } else {
            vector::append(&mut log, vector[0, 0, 0]);
        };
        // reduce from inactive
        if (reduce_from_inactive) {
            let amount = inactive_share;
            balance::join(
                &mut d_balance,
                balance::split(
                    get_mut_deposit_vault_balance(deposit_vault, T_INACTIVE_SHARE),
                    amount,
                )
            );
            inactive_share = inactive_share - amount;
            deposit_vault.inactive_share_supply = deposit_vault.inactive_share_supply - amount;
            vector::push_back(&mut log, amount);
        } else {
            vector::push_back(&mut log, 0);
        };
        // reduce from incentive
        if (reduce_from_incentive) {
            let mut amount = incentive_share;
            let mut incentive_balance = balance::split(
                get_mut_deposit_vault_balance<I_TOKEN>(deposit_vault, T_INCENTIVE_SHARE),
                amount,
            );
            incentive_share = incentive_share - amount;
            deposit_vault.incentive_share_supply = deposit_vault.incentive_share_supply - amount;
            let (exists, incentive_fee_bp) = utils::get_flagged_u64_padding_value(&deposit_vault.u64_padding, I_INCENTIVE_FEE);
            let (
                charged_fee_amount,
                charged_fee_share_amount,
            ) = if (!exists) {
                charge_fee(fee_pool, deposit_vault, &mut incentive_balance)
            } else {
                (charge_fee_by_bp(fee_pool, incentive_fee_bp, &mut incentive_balance), 0)
            };
            amount = amount - charged_fee_amount - charged_fee_share_amount;
            balance::join(&mut i_balance, incentive_balance);
            vector::append(&mut log, vector[amount, charged_fee_amount, charged_fee_share_amount]);
        } else {
            vector::append(&mut log, vector[0, 0, 0]);
        };

        let receipt = add_deposit_share(
            deposit_vault,
            active_share,
            deactivating_share,
            inactive_share,
            warmup_share,
            premium_share,
            incentive_share,
            u64_padding,
            ctx,
        );
        vector::push_back(&mut log, active_share + warmup_share);

        (
            receipt,
            d_balance,
            b_balance,
            i_balance,
            log,
        )
    }

    /// Allows a user to claim their rebate from the `RefundVault`.
    /// WARNING: mut inputs without authority check inside
    public fun public_rebate<TOKEN>(
        refund_vault: &mut RefundVault,
        user: address,
    ): (Option<Balance<TOKEN>>, vector<u64>) {
        // safety check
        assert!(type_name::with_defining_ids<TOKEN>() == refund_vault.token, EInvalidToken);

        // main logic
        let refund_shares: &mut BigVector<RefundShare> = dynamic_field::borrow_mut(&mut refund_vault.id, K_REFUND_SHARES);
        let length = big_vector::length(refund_shares);
        let slice_size = big_vector::slice_size(refund_shares);
        let mut slice = big_vector::borrow_slice(refund_shares, 1);
        let mut i = 0;
        while (i < length) {
            let refund_share = vector::borrow(slice, i % slice_size);
            if (refund_share.user == user) {
                break
            };
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(refund_shares, i + 1);
                slice = big_vector::borrow_slice(
                    refund_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };
        if (i == length) {
            return (option::none(), vector[0])
        };
        let refund_share = big_vector::borrow_mut(
            refund_shares,
            i,
        );
        let share = refund_share.share;
        refund_share.share = 0;
        refund_vault.share_supply = refund_vault.share_supply - share;

        (
            option::some(
                balance::split(
                    dynamic_field::borrow_mut(&mut refund_vault.id, K_REFUND_BALANCE),
                    share,
                )
            ),
            vector[share],
        )
    }

    /// Adjusts the user share ratio for a given share tag to match the actual balance.
    /// This is used to correct any rounding errors or discrepancies.
    /// WARNING: mut inputs without authority check inside
    public fun adjust_user_share_ratio<TOKEN>(
        deposit_vault: &mut DepositVault,
        share_tag: u8,
    ) {
        // update real share supply
        let mut balance_value = balance::value(get_deposit_vault_balance<TOKEN>(deposit_vault, share_tag));
        *get_mut_deposit_vault_share_supply(deposit_vault, share_tag) = balance_value;
        // calculate real share supply
        let mut share_supply_value = 0;
        let deposit_shares = get_deposit_shares(deposit_vault);
        let length = big_vector::length(deposit_shares);
        let slice_size = big_vector::slice_size(deposit_shares);
        let mut slice = big_vector::borrow_slice(deposit_shares, 1);
        let mut i = 0;
        while (i < length) {
            let deposit_share = vector::borrow(slice, i % slice_size);
            share_supply_value = share_supply_value + get_deposit_share_inner(deposit_share, share_tag);
            // switch slice
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                slice = big_vector::borrow_slice(
                    deposit_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };
        // update receipt share
        let deposit_shares = get_mut_deposit_shares(deposit_vault);
        let length = big_vector::length(deposit_shares);
        let slice_size = big_vector::slice_size(deposit_shares);
        let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
        let mut i = 0;
        while (i < length) {
            let deposit_share = vector::borrow_mut(slice, i % slice_size);
            let share = get_mut_deposit_share_inner(deposit_share, share_tag);
            if (*share > 0) {
                let adjusted_share = ((balance_value as u128) * (*share as u128) / (share_supply_value as u128) as u64);
                balance_value = balance_value - adjusted_share;
                share_supply_value = share_supply_value - *share;
                *share = adjusted_share;
            };
            // switch slice
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                slice = big_vector::borrow_slice_mut(
                    deposit_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };
        assert!(balance_value == 0, 0);
        assert!(share_supply_value == 0, 1);
        assert!(balance::value(get_deposit_vault_balance<TOKEN>(deposit_vault, share_tag)) ==
            get_deposit_vault_share_supply(deposit_vault, share_tag), 2);
    }

    // ======== Helper Functions ========

    /// Returns true if the vault has a next round.
    public fun has_next(vault: &DepositVault): bool {
        vault.has_next
    }

    /// Returns the deposit and bid token types for a `DepositVault`.
    public fun get_deposit_vault_token_types(
        deposit_vault: &DepositVault,
    ): (TypeName, TypeName) {
        (
            deposit_vault.deposit_token,
            deposit_vault.bid_token,
        )
    }

    /// Returns the bid and deposit token types for a `BidVault`.
    public fun get_bid_vault_token_types(
        bid_vault: &BidVault,
    ): (TypeName, TypeName) {
        (
            bid_vault.deposit_token,
            bid_vault.bid_token,
        )
    }

    /// Returns a reference to a balance in a `DepositVault` sub-vault.
    public fun get_deposit_vault_balance<TOKEN>(
        deposit_vault: &DepositVault,
        share_tag: u8,
    ): &Balance<TOKEN> {
        if (share_tag == T_ACTIVE_SHARE) {
            dynamic_field::borrow<vector<u8>, Balance<TOKEN>>(&deposit_vault.id, K_ACTIVE_BALANCE)
        } else if (share_tag == T_DEACTIVATING_SHARE) {
            dynamic_field::borrow<vector<u8>, Balance<TOKEN>>(&deposit_vault.id, K_DEACTIVATING_BALANCE)
        } else if (share_tag == T_INACTIVE_SHARE) {
            dynamic_field::borrow<vector<u8>, Balance<TOKEN>>(&deposit_vault.id, K_INACTIVE_BALANCE)
        } else if (share_tag == T_WARMUP_SHARE) {
            dynamic_field::borrow<vector<u8>, Balance<TOKEN>>(&deposit_vault.id, K_WARMUP_BALANCE)
        } else if (share_tag == T_PREMIUM_SHARE) {
            dynamic_field::borrow<vector<u8>, Balance<TOKEN>>(&deposit_vault.id, K_PREMIUM_BALANCE)
        } else if (share_tag == T_INCENTIVE_SHARE) {
            dynamic_field::borrow<vector<u8>, Balance<TOKEN>>(&deposit_vault.id, K_INCENTIVE_BALANCE)
        } else {
            abort EInvalidShareTag
        }
    }

    /// Returns a mutable reference to a balance in a `DepositVault` sub-vault.
    /// WARNING: mut inputs without authority check inside
    public fun get_mut_deposit_vault_balance<TOKEN>(
        deposit_vault: &mut DepositVault,
        share_tag: u8,
    ): &mut Balance<TOKEN> {
        if (share_tag == T_ACTIVE_SHARE) {
            dynamic_field::borrow_mut<vector<u8>, Balance<TOKEN>>(&mut deposit_vault.id, K_ACTIVE_BALANCE)
        } else if (share_tag == T_DEACTIVATING_SHARE) {
            dynamic_field::borrow_mut<vector<u8>, Balance<TOKEN>>(&mut deposit_vault.id, K_DEACTIVATING_BALANCE)
        } else if (share_tag == T_INACTIVE_SHARE) {
            dynamic_field::borrow_mut<vector<u8>, Balance<TOKEN>>(&mut deposit_vault.id, K_INACTIVE_BALANCE)
        } else if (share_tag == T_WARMUP_SHARE) {
            dynamic_field::borrow_mut<vector<u8>, Balance<TOKEN>>(&mut deposit_vault.id, K_WARMUP_BALANCE)
        } else if (share_tag == T_PREMIUM_SHARE) {
            dynamic_field::borrow_mut<vector<u8>, Balance<TOKEN>>(&mut deposit_vault.id, K_PREMIUM_BALANCE)
        } else if (share_tag == T_INCENTIVE_SHARE) {
            dynamic_field::borrow_mut<vector<u8>, Balance<TOKEN>>(&mut deposit_vault.id, K_INCENTIVE_BALANCE)
        } else {
            abort EInvalidShareTag
        }
    }

    /// Returns the tag for the active share type.
    public fun active_share_tag(): u8 {
        T_ACTIVE_SHARE
    }

    /// Returns the tag for the deactivating share type.
    public fun deactivating_share_tag(): u8 {
        T_DEACTIVATING_SHARE
    }

    /// Returns the tag for the inactive share type.
    public fun inactive_share_tag(): u8 {
        T_INACTIVE_SHARE
    }

    /// Returns the tag for the warmup share type.
    public fun warmup_share_tag(): u8 {
        T_WARMUP_SHARE
    }

    /// Returns the tag for the premium share type.
    public fun premium_share_tag(): u8 {
        T_PREMIUM_SHARE
    }

    /// Returns the tag for the incentive share type.
    public fun incentive_share_tag(): u8 {
        T_INCENTIVE_SHARE
    }

    /// Returns the balance of the active sub-vault.
    public fun active_balance<TOKEN>(vault: &DepositVault): u64 {
        balance::value(get_deposit_vault_balance<TOKEN>(vault, T_ACTIVE_SHARE))
    }

    /// Returns the balance of the deactivating sub-vault.
    public fun deactivating_balance<TOKEN>(vault: &DepositVault): u64 {
        balance::value(get_deposit_vault_balance<TOKEN>(vault, T_DEACTIVATING_SHARE))
    }

    /// Returns the balance of the inactive sub-vault.
    public fun inactive_balance<TOKEN>(vault: &DepositVault): u64 {
        balance::value(get_deposit_vault_balance<TOKEN>(vault, T_INACTIVE_SHARE))
    }

    /// Returns the balance of the warmup sub-vault.
    public fun warmup_balance<TOKEN>(vault: &DepositVault): u64 {
        balance::value(get_deposit_vault_balance<TOKEN>(vault, T_WARMUP_SHARE))
    }

    /// Returns the balance of the premium sub-vault.
    public fun premium_balance<TOKEN>(vault: &DepositVault): u64 {
        balance::value(get_deposit_vault_balance<TOKEN>(vault, T_PREMIUM_SHARE))
    }

    /// Returns the balance of the incentive sub-vault.
    public fun incentive_balance<TOKEN>(vault: &DepositVault): u64 {
        balance::value(get_deposit_vault_balance<TOKEN>(vault, T_INCENTIVE_SHARE))
    }

    /// Returns the balance of the `BidVault`.
    public fun bid_vault_balance<TOKEN>(vault: &BidVault): u64 {
        balance::value(get_bid_vault_balance<TOKEN>(vault))
    }

    /// Returns the balance of the `RefundVault`.
    public fun refund_vault_balance<TOKEN>(refund_vault: &RefundVault): u64 {
        balance::value(dynamic_field::borrow<vector<u8>, Balance<TOKEN>>(&refund_vault.id, K_REFUND_BALANCE))
    }

    /// Returns a reference to the balance of the `BidVault`.
    public fun get_bid_vault_balance<TOKEN>(
        bid_vault: &BidVault,
    ): &Balance<TOKEN> {
        dynamic_field::borrow<vector<u8>, Balance<TOKEN>>(&bid_vault.id, K_BID_BALANCE)
    }

    /// Returns the share supply for a given sub-vault in the `DepositVault`.
    public fun get_deposit_vault_share_supply(
        deposit_vault: &DepositVault,
        share_tag: u8,
    ): u64 {
        if (share_tag == T_ACTIVE_SHARE) {
            deposit_vault.active_share_supply
        } else if (share_tag == T_DEACTIVATING_SHARE) {
            deposit_vault.deactivating_share_supply
        } else if (share_tag == T_INACTIVE_SHARE) {
            deposit_vault.inactive_share_supply
        } else if (share_tag == T_WARMUP_SHARE) {
            deposit_vault.warmup_share_supply
        } else if (share_tag == T_PREMIUM_SHARE) {
            deposit_vault.premium_share_supply
        } else if (share_tag == T_INCENTIVE_SHARE) {
            deposit_vault.incentive_share_supply
        } else {
            abort EInvalidShareTag
        }
    }

    /// Returns a mutable reference to the share supply for a given sub-vault in the `DepositVault`.
    /// WARNING: mut inputs without authority check inside
    public fun get_mut_deposit_vault_share_supply(
        deposit_vault: &mut DepositVault,
        share_tag: u8,
    ): &mut u64 {
        if (share_tag == T_ACTIVE_SHARE) {
            &mut deposit_vault.active_share_supply
        } else if (share_tag == T_DEACTIVATING_SHARE) {
            &mut deposit_vault.deactivating_share_supply
        } else if (share_tag == T_INACTIVE_SHARE) {
            &mut deposit_vault.inactive_share_supply
        } else if (share_tag == T_WARMUP_SHARE) {
            &mut deposit_vault.warmup_share_supply
        } else if (share_tag == T_PREMIUM_SHARE) {
            &mut deposit_vault.premium_share_supply
        } else if (share_tag == T_INCENTIVE_SHARE) {
            &mut deposit_vault.incentive_share_supply
        } else {
            abort EInvalidShareTag
        }
    }

    /// Returns the active share supply.
    public fun active_share_supply(vault: &DepositVault): u64 {
        vault.active_share_supply
    }

    /// Returns a mutable reference to the active share supply.
    /// WARNING: mut inputs without authority check inside
    public fun get_mut_active_share_supply(vault: &mut DepositVault): &mut u64 {
        &mut vault.active_share_supply
    }

    /// Returns the deactivating share supply.
    public fun deactivating_share_supply(vault: &DepositVault): u64 {
        vault.deactivating_share_supply
    }

    /// Returns a mutable reference to the deactivating share supply.
    /// WARNING: mut inputs without authority check inside
    public fun get_mut_deactivating_share_supply(vault: &mut DepositVault): &mut u64 {
        &mut vault.deactivating_share_supply
    }

    /// Returns the inactive share supply.
    public fun inactive_share_supply(vault: &DepositVault): u64 {
        vault.inactive_share_supply
    }

    /// Returns a mutable reference to the inactive share supply.
    /// WARNING: mut inputs without authority check inside
    public fun get_mut_inactive_share_supply(vault: &mut DepositVault): &mut u64 {
        &mut vault.inactive_share_supply
    }

    /// Returns the warmup share supply.
    public fun warmup_share_supply(vault: &DepositVault): u64 {
        vault.warmup_share_supply
    }

    /// Returns a mutable reference to the warmup share supply.
    /// WARNING: mut inputs without authority check inside
    public fun get_mut_warmup_share_supply(vault: &mut DepositVault): &mut u64 {
        &mut vault.warmup_share_supply
    }

    /// Returns a mutable reference to the premium share supply.
    /// WARNING: mut inputs without authority check inside
    public fun get_mut_premium_share_supply(vault: &mut DepositVault): &mut u64 {
        &mut vault.premium_share_supply
    }

    /// Returns a mutable reference to the incentive share supply.
    /// WARNING: mut inputs without authority check inside
    public fun get_mut_incentive_share_supply(vault: &mut DepositVault): &mut u64 {
        &mut vault.incentive_share_supply
    }

    /// Returns the premium share supply.
    public fun premium_share_supply(vault: &DepositVault): u64 {
        vault.premium_share_supply
    }

    /// Returns the bid share supply.
    public fun bid_share_supply(vault: &BidVault): u64 {
        vault.share_supply
    }

    /// Returns the refund vault share supply.
    public fun refund_vault_share_supply(refund_vault: &RefundVault): u64 {
        refund_vault.share_supply
    }

    /// Returns a reference to the `BigVector` of deposit shares.
    public fun get_deposit_shares(deposit_vault: &DepositVault): &BigVector<DepositShare> {
        dynamic_field::borrow<vector<u8>, BigVector<DepositShare>>(&deposit_vault.id, K_DEPOSIT_SHARES)
    }

    /// Returns a mutable reference to the `BigVector` of deposit shares.
    /// WARNING: mut inputs without authority check inside
    public fun get_mut_deposit_shares(deposit_vault: &mut DepositVault): &mut BigVector<DepositShare> {
        dynamic_field::borrow_mut<vector<u8>, BigVector<DepositShare>>(&mut deposit_vault.id, K_DEPOSIT_SHARES)
    }

    /// Returns a reference to the `BigVector` of bid shares.
    public fun get_bid_shares(bid_vault: &BidVault): &BigVector<BidShare> {
        dynamic_field::borrow<vector<u8>, BigVector<BidShare>>(&bid_vault.id, K_BID_SHARES)
    }

    /// Returns a reference to the `BigVector` of refund shares.
    public fun get_refund_shares(refund_vault: &RefundVault): &BigVector<RefundShare> {
        dynamic_field::borrow<vector<u8>, BigVector<RefundShare>>(&refund_vault.id, K_REFUND_SHARES)
    }

    /// Returns a reference to a specific `DepositShare`.
    public fun get_deposit_share(deposit_vault: &DepositVault, i: u64): &DepositShare {
        let deposit_shares = get_deposit_shares(deposit_vault);
        big_vector::borrow(deposit_shares, i)
    }

    /// Returns a mutable reference to a specific `DepositShare`.
    public fun get_mut_deposit_share(deposit_vault: &mut DepositVault, i: u64): &mut DepositShare {
        let deposit_shares = get_mut_deposit_shares(deposit_vault);
        big_vector::borrow_mut(deposit_shares, i)
    }

    /// Returns the share value for a given tag from a `DepositShare`.
    public fun get_deposit_share_inner(
        deposit_share_inner: &DepositShare,
        share_tag: u8,
    ): u64 {
        if (share_tag == T_ACTIVE_SHARE) {
            deposit_share_inner.active_share
        } else if (share_tag == T_DEACTIVATING_SHARE) {
            deposit_share_inner.deactivating_share
        } else if (share_tag == T_INACTIVE_SHARE) {
            deposit_share_inner.inactive_share
        } else if (share_tag == T_WARMUP_SHARE) {
            deposit_share_inner.warmup_share
        } else if (share_tag == T_PREMIUM_SHARE) {
            deposit_share_inner.premium_share
        } else if (share_tag == T_INCENTIVE_SHARE) {
            deposit_share_inner.incentive_share
        } else {
            abort EInvalidShareTag
        }
    }

    /// Returns a mutable reference to the share value for a given tag from a `DepositShare`.
    /// WARNING: mut inputs without authority check inside
    public fun get_mut_deposit_share_inner(
        deposit_share_inner: &mut DepositShare,
        share_tag: u8,
    ): &mut u64 {
        if (share_tag == T_ACTIVE_SHARE) {
            &mut deposit_share_inner.active_share
        } else if (share_tag == T_DEACTIVATING_SHARE) {
            &mut deposit_share_inner.deactivating_share
        } else if (share_tag == T_INACTIVE_SHARE) {
            &mut deposit_share_inner.inactive_share
        } else if (share_tag == T_WARMUP_SHARE) {
            &mut deposit_share_inner.warmup_share
        } else if (share_tag == T_PREMIUM_SHARE) {
            &mut deposit_share_inner.premium_share
        } else if (share_tag == T_INCENTIVE_SHARE) {
            &mut deposit_share_inner.incentive_share
        } else {
            abort EInvalidShareTag
        }
    }

    /// Returns the fee in basis points.
    public fun fee_bp(vault: &DepositVault): u64 {
        vault.fee_bp
    }

    /// Returns the fee share in basis points.
    public fun fee_share_bp(vault: &DepositVault): u64 {
        vault.fee_share_bp
    }

    /// Gets the bid share for a given receipt address.
    public fun get_bid_share(
        vault: &BidVault,
        receipt: address
    ): u64 {
        let bid_shares = get_bid_shares(vault);
        let length = big_vector::length(bid_shares);
        let slice_size = big_vector::slice_size(bid_shares);
        let mut slice = big_vector::borrow_slice(bid_shares, 1);
        let mut i = 0;
        while (i < length) {
            let bid_share = vector::borrow(slice, i % slice_size);
            if (bid_share.receipt == receipt) {
                return bid_share.share
            };
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(bid_shares, i + 1);
                slice = big_vector::borrow_slice(
                    bid_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };

        0
    }

    /// Gets the refund share for a given user address.
    public fun get_refund_share(
        vault: &RefundVault,
        user: address
    ): u64 {
        let refund_shares = get_refund_shares(vault);
        let length = big_vector::length(refund_shares);
        let slice_size = big_vector::slice_size(refund_shares);
        let mut slice = big_vector::borrow_slice(refund_shares, 1);
        let mut i = 0;
        while (i < length) {
            let refund_share = vector::borrow(slice, i % slice_size);
            if (refund_share.user == user) {
                return refund_share.share
            };
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(refund_shares, i + 1);
                slice = big_vector::borrow_slice(
                    refund_shares,
                    slice_id,
                );
            };
            i = i + 1;
        };

        0
    }

    /// Summarizes the shares from multiple deposit receipts.
    public fun summarize_deposit_shares(
        deposit_vault: &DepositVault,
        mut receipts: vector<TypusDepositReceipt>,
    ): (u64, u64, u64, u64, u64, u64) {
        let mut total_active_share = 0;
        let mut total_deactivating_share = 0;
        let mut total_inactive_share = 0;
        let mut total_warmup_share = 0;
        let mut total_premium_share = 0;
        let mut total_incentive_share = 0;
        while (!vector::is_empty(&receipts)) {
            let typus_deposit_receipt = vector::pop_back(&mut receipts);
            verify_deposit_receipt(deposit_vault, &typus_deposit_receipt);
            let TypusDepositReceipt {
                id,
                vid: _,
                index: _,
                metadata: _,
                u64_padding: _,
            } = typus_deposit_receipt;
            let receipt = object::uid_to_address(&id);
            object::delete(id);
            let deposit_shares = get_deposit_shares(deposit_vault);
            let length = big_vector::length(deposit_shares);
            let slice_size = big_vector::slice_size(deposit_shares);
            let mut slice = big_vector::borrow_slice(deposit_shares, 1);
            let mut i = 0;
            while (i < length) {
                let deposit_share = vector::borrow(slice, i % slice_size);
                if (deposit_share.receipt == receipt) {
                    total_active_share = total_active_share + deposit_share.active_share;
                    total_deactivating_share = total_deactivating_share + deposit_share.deactivating_share;
                    total_inactive_share = total_inactive_share + deposit_share.inactive_share;
                    total_warmup_share = total_warmup_share + deposit_share.warmup_share;
                    total_premium_share = total_premium_share + deposit_share.premium_share;
                    total_incentive_share = total_incentive_share + deposit_share.incentive_share;
                    break
                };
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                    slice = big_vector::borrow_slice(
                        deposit_shares,
                        slice_id,
                    );
                };
                i = i + 1;
            };
        };
        vector::destroy_empty(receipts);

        (
            total_active_share,
            total_deactivating_share,
            total_inactive_share,
            total_warmup_share,
            total_premium_share,
            total_incentive_share,
        )
    }

    /// Summarizes the shares from multiple bid receipts.
    public fun summarize_bid_shares(
        bid_vault: &BidVault,
        mut receipts: vector<TypusBidReceipt>,
    ): u64 {
        let mut total_share = 0;
        while (!vector::is_empty(&receipts)) {
            let typus_bid_receipt = vector::pop_back(&mut receipts);
            verify_bid_receipt(bid_vault, &typus_bid_receipt);
            let TypusBidReceipt {
                id,
                vid: _,
                index: _,
                metadata: _,
                u64_padding: _,
            } = typus_bid_receipt;
            let receipt = object::uid_to_address(&id);
            object::delete(id);
            let bid_shares = get_bid_shares(bid_vault);
            let length = big_vector::length(bid_shares);
            let slice_size = big_vector::slice_size(bid_shares);
            let mut slice = big_vector::borrow_slice(bid_shares, 1);
            let mut i = 0;
            while (i < length) {
                let bid_share = vector::borrow(slice, i % slice_size);
                if (bid_share.receipt == receipt) {
                    total_share = total_share + bid_share.share;
                    break
                };
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    let slice_id = big_vector::slice_id(bid_shares, i + 1);
                    slice = big_vector::borrow_slice(
                        bid_shares,
                        slice_id,
                    );
                };
                i = i + 1;
            };
        };
        vector::destroy_empty(receipts);

        total_share
    }

    /// Gets the index from a `TypusDepositReceipt`.
    public fun get_deposit_receipt_index(receipt: &TypusDepositReceipt): u64 {
        receipt.index
    }

    /// Gets the vault ID from a `TypusDepositReceipt`.
    public fun get_deposit_receipt_vid(receipt: &TypusDepositReceipt): ID {
        receipt.vid
    }

    /// Gets the index from a `TypusBidReceipt`.
    public fun get_bid_receipt_index(receipt: &TypusBidReceipt): u64 {
        receipt.index
    }

    /// Gets the vault ID from a `TypusBidReceipt`.
    public fun get_bid_receipt_vid(receipt: &TypusBidReceipt): ID {
        receipt.vid
    }

    /// Gets the vault ID, index, and padding from a `TypusBidReceipt`.
    public fun get_bid_receipt_info(receipt: &TypusBidReceipt): (ID, u64, vector<u64>) {
        (receipt.vid, receipt.index, receipt.u64_padding)
    }

    // ======== Private Functions ========

    /// Initializes the display information for the vault receipts.
    fun init(otw: VAULT, ctx: &mut TxContext) {
        let publisher = sui::package::claim(otw, ctx);

        let mut deposit_receipt_display = display::new<TypusDepositReceipt>(&publisher, ctx);
        display::add(&mut deposit_receipt_display, string::utf8(b"name"), string::utf8(b"Typus Deposit Receipt | {metadata}"));
        display::add(&mut deposit_receipt_display, string::utf8(b"description"), string::utf8(b"Typus Option Position"));
        display::add(&mut deposit_receipt_display, string::utf8(b"image_url"), string::utf8(b"https://raw.githubusercontent.com/Typus-Lab/typus-asset/main/receipt/deposit/{index}.jpg"));
        display::update_version(&mut deposit_receipt_display);

        let mut bid_receipt_display = display::new<TypusBidReceipt>(&publisher, ctx);
        display::add(&mut bid_receipt_display, string::utf8(b"name"), string::utf8(b"Typus Bid Receipt | {metadata}"));
        display::add(&mut bid_receipt_display, string::utf8(b"description"), string::utf8(b"Typus Option Position"));
        display::add(&mut bid_receipt_display, string::utf8(b"image_url"), string::utf8(b"https://raw.githubusercontent.com/Typus-Lab/typus-asset/main/receipt/bid/{index}.jpg"));
        display::update_version(&mut bid_receipt_display);

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(deposit_receipt_display, sender);
        transfer::public_transfer(bid_receipt_display, sender);
    }

    /// Creates a new `TypusBidReceipt` NFT.
    fun new_typus_bid_receipt(
        bid_vault: &BidVault,
        share: u64,
        ctx: &mut TxContext,
    ): TypusBidReceipt {
        TypusBidReceipt {
            id: object::new(ctx),
            vid: object::id(bid_vault),
            index: bid_vault.index,
            metadata: bid_vault.metadata,
            u64_padding: vector[share],
        }
    }

    /// Gets a mutable reference to the bid vault's balance.
    fun get_mut_bid_vault_balance<TOKEN>(
        bid_vault: &mut BidVault,
    ): &mut Balance<TOKEN> {
        dynamic_field::borrow_mut<vector<u8>, Balance<TOKEN>>(&mut bid_vault.id, K_BID_BALANCE)
    }

    /// Gets a mutable reference to the `BigVector` of bid shares.
    fun get_mut_bid_shares(bid_vault: &mut BidVault): &mut BigVector<BidShare> {
        dynamic_field::borrow_mut<vector<u8>, BigVector<BidShare>>(&mut bid_vault.id, K_BID_SHARES)
    }

    /// Adds a new deposit share and returns a new `TypusDepositReceipt` if the total share is greater than zero.
    fun add_deposit_share(
        deposit_vault: &mut DepositVault,
        active_share: u64,
        deactivating_share: u64,
        inactive_share: u64,
        warmup_share: u64,
        premium_share: u64,
        incentive_share: u64,
        u64_padding: vector<u64>,
        ctx: &mut TxContext,
    ): Option<TypusDepositReceipt> {
        if (active_share != 0
            || deactivating_share != 0
            || inactive_share != 0
            || warmup_share != 0
            || premium_share != 0
            || incentive_share != 0
        ) {
            let receipt = new_typus_deposit_receipt(deposit_vault, ctx);
            big_vector::push_back(
                get_mut_deposit_shares(deposit_vault),
                DepositShare {
                    receipt: object::id_address(&receipt),
                    active_share,
                    deactivating_share,
                    inactive_share,
                    warmup_share,
                    premium_share,
                    incentive_share,
                    u64_padding
                }
            );
            return option::some(receipt)
        };

        option::none()
    }

    /// Charges a fee from a balance and deposits it into the fee pool.
    /// WARNING: mut inputs without authority check inside
    public fun charge_fee<TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &DepositVault,
        balance: &mut Balance<TOKEN>,
    ): (u64, u64) {
        let fee_amount = ((balance::value(balance) as u128) * (deposit_vault.fee_bp as u128) / (10000 as u128) as u64);
        let fee_balance = balance::split(balance, fee_amount);
        let fee_share_amount = ((balance::value(&fee_balance) as u128) * (deposit_vault.fee_share_bp as u128) / (10000 as u128) as u64);
        // if (fee_share_amount > 0 && option::is_some(&deposit_vault.shared_fee_pool)) {
        //     let key = *option::borrow(&deposit_vault.shared_fee_pool);
        //     let fee_share_balance = balance::split(&mut fee_balance, fee_share_amount);
        //     balance_pool::put_shared(fee_pool, key, fee_share_balance);
        // };
        balance_pool::put(fee_pool, fee_balance);

        (
            fee_amount - fee_share_amount,
            fee_share_amount,
        )
    }

    /// Charges a fee from a balance based on a given basis point and deposits it into the fee pool.
    /// WARNING: mut inputs without authority check inside
    public fun charge_fee_by_bp<TOKEN>(
        fee_pool: &mut BalancePool,
        fee_bp: u64,
        balance: &mut Balance<TOKEN>,
    ): u64 {
        let fee_amount = ((balance.value() as u128) * (fee_bp as u128) / (10000 as u128) as u64);
        let fee_balance = balance.split(fee_amount);
        balance_pool::put(fee_pool, fee_balance);

        fee_amount
    }

    /// Extracts and summarizes shares from multiple deposit receipts, removing them from the vault.
    /// WARNING: mut inputs without authority check inside
    fun extract_deposit_shares(
        deposit_vault: &mut DepositVault,
        mut receipts: vector<TypusDepositReceipt>,
    ): (u64, u64, u64, u64, u64, u64, vector<u64>) {
        let mut total_active_share = 0;
        let mut total_deactivating_share = 0;
        let mut total_inactive_share = 0;
        let mut total_warmup_share = 0;
        let mut total_premium_share = 0;
        let mut total_incentive_share = 0;
        let mut total_u64_padding = vector::empty<u64>();
        while (!vector::is_empty(&receipts)) {
            let typus_deposit_receipt = vector::pop_back(&mut receipts);
            verify_deposit_receipt(deposit_vault, &typus_deposit_receipt);
            let TypusDepositReceipt {
                id,
                vid: _,
                index: _,
                metadata: _,
                u64_padding: _,
            } = typus_deposit_receipt;
            let receipt = object::uid_to_address(&id);
            object::delete(id);
            let deposit_shares = get_mut_deposit_shares(deposit_vault);
            let length = big_vector::length(deposit_shares);
            let slice_size = big_vector::slice_size(deposit_shares);
            let mut slice = big_vector::borrow_slice(deposit_shares, 1);
            let mut i = 0;
            while (i < length) {
                let deposit_share = vector::borrow(slice, i % slice_size);
                if (deposit_share.receipt == receipt) {
                    let DepositShare {
                        receipt: _,
                        active_share,
                        deactivating_share,
                        inactive_share,
                        warmup_share,
                        premium_share,
                        incentive_share,
                        mut u64_padding
                    } = big_vector::swap_remove(deposit_shares, i);
                    total_active_share = total_active_share + active_share;
                    total_deactivating_share = total_deactivating_share + deactivating_share;
                    total_inactive_share = total_inactive_share + inactive_share;
                    total_warmup_share = total_warmup_share + warmup_share;
                    total_premium_share = total_premium_share + premium_share;
                    total_incentive_share = total_incentive_share + incentive_share;
                    if (vector::length(&u64_padding) > 0) {
                        if (vector::is_empty(&total_u64_padding)) {
                            total_u64_padding = u64_padding;
                        } else {
                            let mut j = 0;
                            while (vector::length(&u64_padding) > 0) {
                                let v = vector::pop_back(&mut u64_padding);
                                let total = vector::borrow_mut(&mut total_u64_padding, j);
                                *total = *total + v;
                                j = j + 1;
                            }
                        }
                    };
                    break
                };
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                    slice = big_vector::borrow_slice(
                        deposit_shares,
                        slice_id,
                    );
                };
                i = i + 1;
            };
        };
        vector::destroy_empty(receipts);
        (
            total_active_share,
            total_deactivating_share,
            total_inactive_share,
            total_warmup_share,
            total_premium_share,
            total_incentive_share,
            total_u64_padding
        )
    }

    /// Extracts and summarizes shares from multiple bid receipts, removing them from the vault.
    /// WARNING: mut inputs without authority check inside
    public fun extract_bid_shares(
        bid_vault: &mut BidVault,
        mut receipts: vector<TypusBidReceipt>,
    ): (u64, vector<u64>) {
        let mut total_share = 0;
        let mut total_u64_padding = vector::empty<u64>();
        while (!vector::is_empty(&receipts)) {
            let typus_bid_receipt = vector::pop_back(&mut receipts);
            verify_bid_receipt(bid_vault, &typus_bid_receipt);
            let TypusBidReceipt {
                id,
                vid: _,
                index: _,
                metadata: _,
                u64_padding: _,
            } = typus_bid_receipt;
            let receipt = object::uid_to_address(&id);
            object::delete(id);
            let bid_shares = get_mut_bid_shares(bid_vault);
            let length = big_vector::length(bid_shares);
            let slice_size = big_vector::slice_size(bid_shares);
            let mut slice = big_vector::borrow_slice(bid_shares, 1);
            let mut i = 0;
            while (i < length) {
                let bid_share = vector::borrow(slice, i % slice_size);
                if (bid_share.receipt == receipt) {
                    let BidShare {
                        receipt: _,
                        share,
                        mut u64_padding
                    } = big_vector::swap_remove(bid_shares, i);
                    total_share = total_share + share;
                    if (vector::length(&u64_padding) > 0) {
                        if (vector::is_empty(&total_u64_padding)) {
                            total_u64_padding = u64_padding;
                        } else {
                            let mut j = 0;
                            while (vector::length(&u64_padding) > 0) {
                                let v = vector::pop_back(&mut u64_padding);
                                let total = vector::borrow_mut(&mut total_u64_padding, j);
                                *total = *total + v;
                                j = j + 1;
                            }
                        }
                    };
                    break
                };
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    let slice_id = big_vector::slice_id(bid_shares, i + 1);
                    slice = big_vector::borrow_slice(
                        bid_shares,
                        slice_id,
                    );
                };
                i = i + 1;
            };
        };
        vector::destroy_empty(receipts);

        (total_share, total_u64_padding)
    }

    /// Verifies that a `TypusDepositReceipt` belongs to a given `DepositVault`.
    fun verify_deposit_receipt(
        deposit_vault: &DepositVault,
        deposit_receipt: &TypusDepositReceipt,
    ) {
        assert!(object::id(deposit_vault) == deposit_receipt.vid
            && deposit_vault.index == deposit_receipt.index, EInvalidDepositReceipt);
    }

    /// Verifies that a `TypusBidReceipt` belongs to a given `BidVault`.
    fun verify_bid_receipt(
        bid_vault: &BidVault,
        bid_receipt: &TypusBidReceipt,
    ) {
        assert!(object::id(bid_vault) == bid_receipt.vid
            && bid_vault.index == bid_receipt.index, EInvalidBidReceipt);
    }

    /// Withdraws funds from the active and deactivating sub-vaults for lending.
    /// WARNING: mut inputs without authority check inside
    public fun withdraw_for_lending<TOKEN>(
        deposit_vault: &mut DepositVault,
    ): (Balance<TOKEN>, vector<u64>) {
        let mut balance = balance::zero();
        let active_balance = balance::withdraw_all(get_mut_deposit_vault_balance(deposit_vault, T_ACTIVE_SHARE));
        let active_balance_value = balance::value(&active_balance);
        balance::join(&mut balance, active_balance);
        let deactivating_balance = balance::withdraw_all(get_mut_deposit_vault_balance(deposit_vault, T_DEACTIVATING_SHARE));
        let deactivating_balance_value = balance::value(&deactivating_balance);
        balance::join(&mut balance, deactivating_balance);

        (
            balance,
            vector[
                active_balance_value,
                deactivating_balance_value,
            ],
        )
    }
    /// Deposits funds from a lending protocol back into the vault.
    /// It handles the distribution of principal and rewards, and charges fees.
    /// WARNING: mut inputs without authority check inside
    public fun deposit_from_lending<D_TOKEN, R_TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        incentive: &mut Balance<D_TOKEN>,
        mut balance: Balance<D_TOKEN>,
        mut reward: Balance<R_TOKEN>,
        distribute: bool,
    ): vector<u64> {
        // move balance & charge fee
        let balance_value = balance::value(&balance);
        let reward_value = balance::value(&reward);
        let active_share_supply = deposit_vault.active_share_supply;
        let deactivating_share_supply = deposit_vault.deactivating_share_supply;
        if (balance_value < active_share_supply + deactivating_share_supply) {
            let difference = active_share_supply + deactivating_share_supply - balance_value;
            assert!(difference <= 2, EInvalidBalanceValue);
            balance::join(&mut balance, balance::split(incentive, difference));
        };
        balance::join(get_mut_deposit_vault_balance(deposit_vault, T_ACTIVE_SHARE), balance::split(&mut balance, active_share_supply));
        balance::join(get_mut_deposit_vault_balance(deposit_vault, T_DEACTIVATING_SHARE), balance::split(&mut balance, deactivating_share_supply));
        if (!distribute) {
            let log = vector[
                balance_value,
                reward_value,
                active_share_supply,
                deactivating_share_supply,
                balance.value(),
                0,
                reward.value(),
                0,
            ];
            fee_pool.put(balance);
            fee_pool.put(reward);
            return log
        };
        let (deposit_token, bid_token) = get_deposit_vault_token_types(deposit_vault);
        let reward_token = type_name::with_defining_ids<R_TOKEN>();
        if (reward_token != deposit_token && reward_token != bid_token) {
            update_deposit_vault_incentive_token<R_TOKEN>(deposit_vault);
        };
        let (fee_amount, fee_share_amount) = charge_fee(fee_pool, deposit_vault, &mut balance);
        let (reward_fee_amount, reward_fee_share_amount) = if (reward_token == deposit_token) {
            charge_fee(fee_pool, deposit_vault, &mut reward)
        } else {
            (0, 0)
        };

        // adjust share
        let mut warmup_balance = 0;
        let mut inactive_balance = 0;
        let mut warmup_reward = 0;
        let mut inactive_reward = 0;
        if (balance_value > active_share_supply + deactivating_share_supply || balance::value(&reward) != 0) {
            let mut share_supply = deposit_vault.active_share_supply + deposit_vault.deactivating_share_supply;
            let mut remaining_balance_value = balance::value(&balance);
            let mut reward_balance_value = balance::value(&reward);
            let deposit_shares = get_mut_deposit_shares(deposit_vault);
            let length = big_vector::length(deposit_shares);
            let slice_size = big_vector::slice_size(deposit_shares);
            let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
            let mut i = 0;
            while (i < length) {
                let deposit_share = vector::borrow_mut(slice, i % slice_size);
                let active_share = deposit_share.active_share;
                let deactivating_share = deposit_share.deactivating_share;
                let share = active_share + deactivating_share;
                if (share > 0) {
                    if (remaining_balance_value > 0) {
                        let adjusted_share = ((remaining_balance_value as u128) * (share as u128) / (share_supply as u128) as u64);
                        let adjusted_active_share = ((adjusted_share as u128) * (active_share as u128) / (share as u128) as u64);
                        let adjested_deactivating_share = adjusted_share - adjusted_active_share;
                        deposit_share.warmup_share = deposit_share.warmup_share + adjusted_active_share;
                        warmup_balance = warmup_balance + adjusted_active_share;
                        deposit_share.inactive_share = deposit_share.inactive_share + adjested_deactivating_share;
                        inactive_balance = inactive_balance + adjested_deactivating_share;
                        remaining_balance_value = remaining_balance_value - adjusted_share;
                    };
                    if (reward_balance_value > 0) {
                        let adjusted_share = ((reward_balance_value as u128) * (share as u128) / (share_supply as u128) as u64);
                        if (reward_token == deposit_token) {
                            let adjusted_active_share = ((adjusted_share as u128) * (active_share as u128) / (share as u128) as u64);
                            let adjested_deactivating_share = adjusted_share - adjusted_active_share;
                            deposit_share.warmup_share = deposit_share.warmup_share + adjusted_active_share;
                            warmup_reward = warmup_reward + adjusted_active_share;
                            deposit_share.inactive_share = deposit_share.inactive_share + adjested_deactivating_share;
                            inactive_reward = inactive_reward + adjested_deactivating_share;
                        } else if (reward_token == bid_token) {
                            deposit_share.premium_share = deposit_share.premium_share + adjusted_share;
                        } else {
                            deposit_share.incentive_share = deposit_share.incentive_share + adjusted_share;
                        };
                        reward_balance_value = reward_balance_value - adjusted_share;
                    };
                    share_supply = share_supply - share;
                };
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                    slice = big_vector::borrow_slice_mut(
                        deposit_shares,
                        slice_id,
                    );
                };
                i = i + 1;
            };
        };

        // allocate balance
        balance::join(get_mut_deposit_vault_balance(deposit_vault, T_WARMUP_SHARE), balance.split(warmup_balance));
        balance::join(get_mut_deposit_vault_balance(deposit_vault, T_INACTIVE_SHARE), balance.split(inactive_balance));
        deposit_vault.warmup_share_supply = warmup_balance<D_TOKEN>(deposit_vault);
        deposit_vault.inactive_share_supply = inactive_balance<D_TOKEN>(deposit_vault);
        balance.destroy_zero();
        if (reward_token == deposit_token) {
            balance::join(get_mut_deposit_vault_balance(deposit_vault, T_WARMUP_SHARE), reward.split(warmup_reward));
            balance::join(get_mut_deposit_vault_balance(deposit_vault, T_INACTIVE_SHARE), reward.split(inactive_reward));
            deposit_vault.warmup_share_supply = warmup_balance<D_TOKEN>(deposit_vault);
            deposit_vault.inactive_share_supply = inactive_balance<D_TOKEN>(deposit_vault);
            reward.destroy_zero();
        } else if (reward_token == bid_token) {
            balance::join(get_mut_deposit_vault_balance(deposit_vault, T_PREMIUM_SHARE), reward);
            deposit_vault.premium_share_supply = premium_balance<R_TOKEN>(deposit_vault);
        } else {
            balance::join(get_mut_deposit_vault_balance(deposit_vault, T_INCENTIVE_SHARE), reward);
            deposit_vault.incentive_share_supply = incentive_balance<R_TOKEN>(deposit_vault);
        };

        vector[
            balance_value,
            reward_value,
            active_share_supply,
            deactivating_share_supply,
            fee_amount,
            fee_share_amount,
            reward_fee_amount,
            reward_fee_share_amount,
        ]
    }
    /// Deposits rewards from a lending protocol into the vault.
    /// WARNING: mut inputs without authority check inside
    public fun reward_from_lending<TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        mut reward: Balance<TOKEN>,
        distribute: bool,
    ): vector<u64> {
        let reward_value = balance::value(&reward);
        if (!distribute) {
            let log = vector[
                reward_value,
                reward_value,
                0,
            ];
            fee_pool.put(reward);
            return log
        };
        let (deposit_token, bid_token) = get_deposit_vault_token_types(deposit_vault);
        let reward_token = type_name::with_defining_ids<TOKEN>();
        if (reward_token != deposit_token && reward_token != bid_token) {
            update_deposit_vault_incentive_token<TOKEN>(deposit_vault);
        };
        let (reward_fee_amount, reward_fee_share_amount) = if (reward_token == deposit_token) {
            charge_fee(fee_pool, deposit_vault, &mut reward)
        } else {
            (0, 0)
        };

        // adjust share
        let mut warmup_reward = 0;
        let mut inactive_reward = 0;
        if (reward.value() > 0) {
            let mut share_supply = deposit_vault.active_share_supply + deposit_vault.deactivating_share_supply;
            let mut reward_balance_value = balance::value(&reward);
            let deposit_shares = get_mut_deposit_shares(deposit_vault);
            let length = big_vector::length(deposit_shares);
            let slice_size = big_vector::slice_size(deposit_shares);
            let mut slice = big_vector::borrow_slice_mut(deposit_shares, 1);
            let mut i = 0;
            while (i < length) {
                let deposit_share = vector::borrow_mut(slice, i % slice_size);
                let active_share = deposit_share.active_share;
                let deactivating_share = deposit_share.deactivating_share;
                let share = active_share + deactivating_share;
                if (share > 0) {
                    if (reward_balance_value > 0) {
                        let adjusted_share = ((reward_balance_value as u128) * (share as u128) / (share_supply as u128) as u64);
                        if (reward_token == deposit_token) {
                            let adjusted_active_share = ((adjusted_share as u128) * (active_share as u128) / (share as u128) as u64);
                            let adjested_deactivating_share = adjusted_share - adjusted_active_share;
                            deposit_share.warmup_share = deposit_share.warmup_share + adjusted_active_share;
                            warmup_reward = warmup_reward + adjusted_active_share;
                            deposit_share.inactive_share = deposit_share.inactive_share + adjested_deactivating_share;
                            inactive_reward = inactive_reward + adjested_deactivating_share;
                        } else if (reward_token == bid_token) {
                            deposit_share.premium_share = deposit_share.premium_share + adjusted_share;
                        } else {
                            deposit_share.incentive_share = deposit_share.incentive_share + adjusted_share;
                        };
                        reward_balance_value = reward_balance_value - adjusted_share;
                    };
                    share_supply = share_supply - share;
                };
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    let slice_id = big_vector::slice_id(deposit_shares, i + 1);
                    slice = big_vector::borrow_slice_mut(
                        deposit_shares,
                        slice_id,
                    );
                };
                i = i + 1;
            };
        };

        // allocate balance
        if (reward_token == deposit_token) {
            balance::join(get_mut_deposit_vault_balance(deposit_vault, T_WARMUP_SHARE), reward.split(warmup_reward));
            balance::join(get_mut_deposit_vault_balance(deposit_vault, T_INACTIVE_SHARE), reward.split(inactive_reward));
            deposit_vault.warmup_share_supply = warmup_balance<TOKEN>(deposit_vault);
            deposit_vault.inactive_share_supply = inactive_balance<TOKEN>(deposit_vault);
            reward.destroy_zero();
        } else if (reward_token == bid_token) {
            balance::join(get_mut_deposit_vault_balance(deposit_vault, T_PREMIUM_SHARE), reward);
            deposit_vault.premium_share_supply = premium_balance<TOKEN>(deposit_vault);
        } else {
            balance::join(get_mut_deposit_vault_balance(deposit_vault, T_INCENTIVE_SHARE), reward);
            deposit_vault.incentive_share_supply = incentive_balance<TOKEN>(deposit_vault);
        };

        vector[
            reward_value,
            reward_fee_amount,
            reward_fee_share_amount,
        ]
    }

    #[test]
    fun test_init() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(VAULT {}, scenario.ctx());
        scenario.end();
    }

    // ======== Deprecated =========

    #[deprecated]
    public fun public_deposit<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _coins: vector<Coin<TOKEN>>,
        _amount: u64,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (vector<Coin<TOKEN>>, Option<TypusDepositReceipt>, vector<u64>) { abort 0 }
    #[deprecated]
    public fun public_withdraw<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _share: Option<u64>,
        _ctx: &mut TxContext,
    ): (Option<Balance<TOKEN>>, Option<TypusDepositReceipt>, vector<u64>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun withdraw_to_inactive<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext
    ): (Option<TypusDepositReceipt>, vector<u64>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun public_unsubscribe<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _share: Option<u64>,
        _ctx: &mut TxContext
    ): (Option<TypusDepositReceipt>, vector<u64>) { abort 0 }
    #[deprecated]
    public fun public_unsubscribe_share(
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _share: Option<u64>,
        _ctx: &mut TxContext
    ): (Option<TypusDepositReceipt>, vector<u64>) { abort 0 }
    #[deprecated]
    public fun public_claim<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (Option<Balance<TOKEN>>, Option<TypusDepositReceipt>, vector<u64>) { abort 0 }
    #[deprecated]
    public fun public_harvest<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (Option<Balance<TOKEN>>, Option<TypusDepositReceipt>, vector<u64>) { abort 0 }
    #[deprecated]
    public fun public_redeem<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (Option<Balance<TOKEN>>, Option<TypusDepositReceipt>, vector<u64>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun public_compound<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (Option<TypusDepositReceipt>, vector<u64>) { abort 0 }
    #[deprecated]
    public fun deposit<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _coins: vector<Coin<TOKEN>>,
        _amount: u64,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): u64 { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun withdraw<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _share: Option<u64>,
        _ctx: &mut TxContext,
    ): u64 { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun unsubscribe<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _share: Option<u64>,
        _ctx: &mut TxContext
    ): u64 { abort 0 }
    #[deprecated]
    public fun unsubscribe_share(
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _share: Option<u64>,
        _ctx: &mut TxContext
    ): u64 { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun claim<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): u64 { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun harvest<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (u64, u64) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun harvest_v2<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (u64, u64, u64, Option<vector<u8>>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun compound<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): u64 { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun compound_v2<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (u64, u64, u64, Option<vector<u8>>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun redeem<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): u64 { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun redeem_v2<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (u64, u64, u64, Option<vector<u8>>) { abort 0 }
    #[deprecated]
    public fun new_bid(
        _bid_vault: &mut BidVault,
        _share: u64,
        _ctx: &mut TxContext,
    ) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun exercise<TOKEN>(
        _bid_vault: &mut BidVault,
        _receipts: vector<TypusBidReceipt>,
        _ctx: &mut TxContext,
    ): u64 { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun exercise_v2<TOKEN>(
        _bid_vault: &mut BidVault,
        _receipts: vector<TypusBidReceipt>,
        _ctx: &mut TxContext,
    ): (u64, u64) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun exercise_i<D_TOKEN, I_TOKEN>(
        _bid_vault: &mut BidVault,
        _receipts: vector<TypusBidReceipt>,
        _ctx: &mut TxContext,
    ): (u64, u64) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun take_refund<TOKEN>(
        _refund_vault: &mut RefundVault,
        _ctx: &mut TxContext,
    ): u64 { abort 0 }
    #[deprecated]
    public fun delegate_take_refund<TOKEN>(
        _refund_vault: &mut RefundVault,
        _user: address,
        _ctx: &mut TxContext,
    ): Coin<TOKEN> { abort 0 }
    #[deprecated]
    public fun is_active_user(
        _vault: &DepositVault,
        _receipt: address
    ): bool { abort 0 }
    #[deprecated]
    public fun is_deactivating_user(
        _vault: &DepositVault,
        _receipt: address
    ): bool { abort 0 }
    #[deprecated]
    public fun is_inactive_user(
        _vault: &DepositVault,
        _receipt: address
    ): bool { abort 0 }
    #[deprecated]
    public fun is_warmup_user(
        _vault: &DepositVault,
        _receipt: address
    ): bool { abort 0 }
    #[deprecated]
    public fun get_active_deposit_share(
        _vault: &DepositVault,
        _receipt: address
    ): u64 { abort 0 }
    #[deprecated]
    public fun get_deactivating_deposit_share(
        _vault: &DepositVault,
        _receipt: address
    ): u64 { abort 0 }
    #[deprecated]
    public fun get_inactive_deposit_share(
        _vault: &DepositVault,
        _receipt: address
    ): u64 { abort 0 }
    #[deprecated]
    public fun get_warmup_deposit_share(
        _vault: &DepositVault,
        _receipt: address
    ): u64 { abort 0 }
    #[deprecated]
    public fun get_premium_deposit_share(
        _vault: &DepositVault,
        _receipt: address
    ): u64 { abort 0 }
    #[deprecated]
    public fun incentivise_bidder<TOKEN>(
        _bid_vault: &mut BidVault,
        _incentive_balance: Balance<TOKEN>,
        _ctx: &TxContext,
    ) { abort 0 }
    #[deprecated]
    public fun update_fee_share(
        _deposit_vault: &mut DepositVault,
        _fee_share_bp: u64,
        _shared_fee_pool: Option<vector<u8>>,
        _ctx: &TxContext,
    ) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun bid_vault_incentive_balance<TOKEN>(
        _vault: &BidVault
    ): u64 { abort 0 }
    #[deprecated]
    public fun get_bid_vault_incentive_balance<TOKEN>(
        _bid_vault: &BidVault
    ): &Balance<TOKEN> { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun charge_deposit_vault_inactive_token<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _balance: Balance<TOKEN>,
    ) { abort 0 }
    #[deprecated]
    public fun deprecated() { abort 0 }
    #[deprecated]
    public struct NewDepositVault has copy, drop {
        signer: address,
        index: u64,
        deposit_token: TypeName,
        bid_token: TypeName,
    }
    #[deprecated]
    public struct NewBidVault has copy, drop {
        signer: address,
        index: u64,
        bid_token: TypeName,
    }
    #[deprecated]
    public struct NewRefundVault has copy, drop {
        signer: address,
        token: TypeName,
    }
    #[deprecated]
    public struct UpdateFeeConfig has copy, drop{
        signer: address,
        index: u64,
        prev_fee_bp: u64,
        fee_bp: u64,
    }
    #[deprecated]
    public struct UpdateFeeShareConfig has copy, drop {
        signer: address,
        index: u64,
        prev_fee_bp: u64,
        prev_shared_fee_pool: Option<vector<u8>>,
        fee_bp: u64,
        shared_fee_pool: Option<vector<u8>>,
    }
    #[deprecated]
    public struct Deposit has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
    }
    #[deprecated]
    public struct Withdraw has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
    }
    #[deprecated]
    public struct Unsubscribe has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
    }
    #[deprecated]
    public struct Claim has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
    }
    #[deprecated]
    public struct Harvest has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        fee_amount: u64,
        fee_share_amount: u64,
        shared_fee_pool: Option<vector<u8>>,
    }
    #[deprecated]
    public struct Compound has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        fee_amount: u64,
        fee_share_amount: u64,
        shared_fee_pool: Option<vector<u8>>,
    }
    #[deprecated]
    public struct Redeem has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
    }
    #[deprecated]
    public struct Exercise has copy, drop {
        signer: address,
        index: u64,
        deposit_token: TypeName,
        incentive_token: Option<TypeName>,
        amount: u64,
    }
    #[deprecated]
    public struct Activate has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        has_next: bool,
    }
    #[deprecated]
    public struct Delivery has copy, drop {
        signer: address,
        index: u64,
        premium_token: TypeName,
        incentive_token: TypeName,
        premium: u64,
        incentive: u64,
    }
    #[deprecated]
    public struct Recoup has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        active: u64,
        deactivating: u64,
    }
    #[deprecated]
    public struct Settle has copy, drop {
        signer: address,
        index: u64,
        deposit_token: TypeName,
        bid_token: TypeName,
        share_price: u64,
        share_price_decimal: u64,
    }
    #[deprecated]
    public struct Terminate has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
    }
    #[deprecated]
    public struct IncentiviseBidder has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
    }
}