module typus_dov::tds_user_entry {
    use std::type_name;

    use sui::balance::{Self, Balance};
    use sui::clock::Clock;
    use sui::coin::Coin;

    use typus_dov::typus_dov_single::{Self, Registry};
    use typus_framework::dutch;
    use typus_framework::vault::{Self, TypusDepositReceipt, TypusBidReceipt};
    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::leaderboard::TypusLeaderboardRegistry;
    use typus::tgld::TgldRegistry;
    use typus::user::TypusUserRegistry;

    const E_DEPRECATED_FUNCTION: u64 = 999;

    /// Performs a safety check for user entry functions.
    fun safety_check<D_TOKEN, B_TOKEN>(
        registry: &Registry,
        index: u64,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, index);
    }

    /// [User Function] Allows a user to raise funds for a deposit.
    public fun public_raise_fund<D_TOKEN, B_TOKEN>(
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        raise_balance: Balance<D_TOKEN>,
        raise_from_premium: bool,
        raise_from_inactive: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (TypusDepositReceipt, vector<u64>) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index);

        // main logic
        let user = tx_context::sender(ctx);
        let (
            _id,
            _num_of_vault,
            _authority,
            fee_pool,
            portfolio_vault_registry,
            deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, index);
        let deposit_vault = typus_dov_single::get_mut_deposit_vault(deposit_vault_registry, index);
        let (receipt, log) = vault::raise_fund<D_TOKEN>(
            fee_pool,
            deposit_vault,
            receipts,
            raise_balance,
            raise_from_premium,
            raise_from_inactive,
            ctx,
        );
        let balance_value = *vector::borrow(&log, 0);
        let premium_value = *vector::borrow(&log, 1);
        let fee_amount = *vector::borrow(&log, 2);
        let fee_share_amount = *vector::borrow(&log, 3);
        let inactive_value = *vector::borrow(&log, 4);
        let snapshot = typus_dov_single::calculate_in_usd<D_TOKEN>(portfolio_vault, *vector::borrow(&log, 5), false);
        typus_dov_single::validate_amount(balance_value + premium_value + inactive_value);
        typus_dov_single::validate_capacity(registry, index);
        typus_dov_single::emit_raise_fund_event(
            portfolio_vault,
            balance_value,
            premium_value,
            fee_amount,
            fee_share_amount,
            inactive_value,
            ctx,
        );
        typus_dov_single::update_deposit_snapshot(
            typus_ecosystem_version,
            typus_user_registry,
            typus_leaderboard_registry,
            registry,
            index,
            user,
            snapshot,
            clock,
            ctx,
        );

        (receipt, log)
    }

    /// [User Function] Allows a user to reduce their funds from a deposit.
    public fun public_reduce_fund<D_TOKEN, B_TOKEN, I_TOKEN>(
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        reduce_from_warmup: u64,
        reduce_from_active: u64,
        reduce_from_premium: bool,
        reduce_from_inactive: bool,
        reduce_from_incentive: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Option<TypusDepositReceipt>, Balance<D_TOKEN>, Balance<B_TOKEN>, Balance<I_TOKEN>, vector<u64>) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index);

        // main logic
        let user = tx_context::sender(ctx);
        let (
            _id,
            _num_of_vault,
            _authority,
            fee_pool,
            portfolio_vault_registry,
            deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, index);
        let deposit_vault = typus_dov_single::get_mut_deposit_vault(deposit_vault_registry, index);
        let (receipt, d_balance, b_balance, i_balance, log) = vault::reduce_fund<D_TOKEN, B_TOKEN, I_TOKEN>(
            fee_pool,
            deposit_vault,
            receipts,
            reduce_from_warmup,
            reduce_from_active,
            reduce_from_premium,
            reduce_from_inactive,
            reduce_from_incentive,
            ctx,
        );
        let warmup_value = *vector::borrow(&log, 0);
        let active_value = *vector::borrow(&log, 1);
        let premium_value = *vector::borrow(&log, 2);
        let premium_fee_amount = *vector::borrow(&log, 3);
        let premium_fee_share_amount = *vector::borrow(&log, 4);
        let inactive_value = *vector::borrow(&log, 5);
        let incentive_value = *vector::borrow(&log, 6);
        let incentive_fee_amount = *vector::borrow(&log, 7);
        let incentive_fee_share_amount = *vector::borrow(&log, 8);
        let snapshot = typus_dov_single::calculate_in_usd<D_TOKEN>(portfolio_vault, *vector::borrow(&log, 9), false);
        typus_dov_single::emit_reduce_fund_event(
            portfolio_vault,
            type_name::with_defining_ids<D_TOKEN>(),
            type_name::with_defining_ids<B_TOKEN>(),
            type_name::with_defining_ids<I_TOKEN>(),
            warmup_value,
            active_value,
            premium_value,
            premium_fee_amount,
            premium_fee_share_amount,
            inactive_value,
            incentive_value,
            incentive_fee_amount,
            incentive_fee_share_amount,
            ctx,
        );
        typus_dov_single::update_deposit_snapshot(
            typus_ecosystem_version,
            typus_user_registry,
            typus_leaderboard_registry,
            registry,
            index,
            user,
            snapshot,
            clock,
            ctx,
        );

        (receipt, d_balance, b_balance, i_balance, log)
    }

    /// [User Function] Refreshes a user's deposit snapshot.
    public fun public_refresh_deposit_snapshot<D_TOKEN, B_TOKEN>(
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (TypusDepositReceipt, vector<u64>) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index);

        // main logic
        let user = tx_context::sender(ctx);
        let (
            _id,
            _num_of_vault,
            _authority,
            fee_pool,
            portfolio_vault_registry,
            deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, index);
        let deposit_vault = typus_dov_single::get_mut_deposit_vault(deposit_vault_registry, index);
        let (receipt, log) = vault::raise_fund<D_TOKEN>(
            fee_pool,
            deposit_vault,
            receipts,
            balance::zero(),
            false,
            false,
            ctx,
        );
        let snapshot = typus_dov_single::calculate_in_usd<D_TOKEN>(portfolio_vault, *vector::borrow(&log, 5), false);
        typus_dov_single::emit_refresh_deposit_snapshot_event(
            portfolio_vault,
            snapshot,
            ctx,
        );
        typus_dov_single::update_deposit_snapshot(
            typus_ecosystem_version,
            typus_user_registry,
            typus_leaderboard_registry,
            registry,
            index,
            user,
            snapshot,
            clock,
            ctx,
        );

        (receipt, log)
    }

    /// [User Function] Allows a user to place a bid.
    public fun public_bid<D_TOKEN, B_TOKEN>(
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
    ): (TypusBidReceipt, Coin<B_TOKEN>, vector<u64>) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index);

        // safety check
        let user = tx_context::sender(ctx);
        let (
            id,
            _num_of_vault,
            _authority,
            _fee_pool,
            portfolio_vault_registry,
            _deposit_vault_registry,
            auction_registry,
            bid_vault_registry,
            refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_mut_portfolio_vault(portfolio_vault_registry, index);
        let bid_vault = typus_dov_single::get_mut_bid_vault(bid_vault_registry, index);
        let auction = typus_dov_single::get_mut_auction(auction_registry, index);
        let refund_vault = typus_dov_single::get_mut_refund_vault<B_TOKEN>(refund_vault_registry);
        typus_dov_single::validate_bid(portfolio_vault, auction, size);

        let max_size = dutch::size(auction);
        let total_bid_size = dutch::total_bid_size(auction);
        let size = if (total_bid_size + size > max_size) {
            max_size - total_bid_size
        } else { size };

        // main logic
        let bidder = tx_context::sender(ctx);
        let fee_discount = 0;
        let (incentive_usage, _total_cost) = typus_dov_single::get_new_bid_incentive_balance_value<B_TOKEN>(id, portfolio_vault, auction, size, fee_discount, clock);
        let incentive_balance = typus_dov_single::get_new_bid_incentive_balance<B_TOKEN>(
            id,
            portfolio_vault,
            incentive_usage
        );
        let (
            bid_index,
            price,
            size,
            bidder_balance,
            incentive_balance,
            ts_ms,
            _,
            coin,
        ) = dutch::public_new_bid_v2<B_TOKEN>(
            refund_vault,
            auction,
            bidder,
            size,
            coins,
            incentive_balance,
            fee_discount,
            clock,
            ctx,
        );
        let receipt = vault::public_new_bid(
            bid_vault,
            size,
            ctx,
        );
        let point = typus_dov_single::calculate_in_usd<B_TOKEN>(portfolio_vault, bidder_balance, false) * 200;
        let score = typus_dov_single::calculate_in_usd_with_decimal<B_TOKEN>(portfolio_vault, bidder_balance);
        typus_dov_single::emit_new_bid_event(
            portfolio_vault,
            bid_index,
            price,
            size,
            bidder_balance,
            incentive_balance,
            ts_ms,
            tx_context::sender(ctx),
        );
        typus_dov_single::add_accumulated_tgld_amount(
            id,
            typus_ecosystem_version,
            typus_user_registry,
            tgld_registry,
            user,
            point,
            ctx,
        );
        typus_dov_single::add_leaderboard_score(
            id,
            typus_ecosystem_version,
            typus_leaderboard_registry,
            std::ascii::string(b"bidding_leaderboard"),
            user,
            score * 15 / 10,
            clock,
            ctx,
        );
        typus_dov_single::add_user_tails_exp_amount(
            id,
            typus_ecosystem_version,
            typus_user_registry,
            user,
            point,
        );

        (
            receipt,
            coin,
            vector[],
        )
    }

    /// [User Function] Transfers a bid receipt to another user.
    #[lint_allow(self_transfer)]
    public(package) entry fun transfer_bid_receipt<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusBidReceipt>,
        share: Option<u64>,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index);

        // main logic
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, index);
        let bid_vault = typus_dov_single::get_mut_bid_vault(bid_vault_registry, index);
        let (amount, split_receipt, remain_receipt) = vault::split_bid_receipt(
            bid_vault,
            receipts,
            share,
            ctx,
        );
        typus_dov_single::validate_amount(amount);
        transfer::public_transfer(option::destroy_some(split_receipt), recipient);
        if (option::is_some(&remain_receipt)) {
            transfer::public_transfer(option::destroy_some(remain_receipt), tx_context::sender(ctx));
        } else {
            option::destroy_none(remain_receipt);
        };
        typus_dov_single::emit_transfer_bid_receipt_event(
            portfolio_vault,
            amount,
            recipient,
            ctx,
        );
    }

    /// [User Function] A public version of `transfer_bid_receipt`.
    public fun public_transfer_bid_receipt<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusBidReceipt>,
        share: Option<u64>,
        recipient: address,
        ctx: &mut TxContext,
    ): (Option<TypusBidReceipt>, vector<u64>) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index);

        // main logic
        let (split_receipt, remain_receipt, log) = simple_split_bid_receipt(registry, index, receipts, share, ctx);
        transfer::public_transfer(option::destroy_some(split_receipt), recipient);

        // emit event
         let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, index);
        let amount = *vector::borrow(&log, 0);
        typus_dov_single::emit_transfer_bid_receipt_event(
            portfolio_vault,
            amount,
            recipient,
            ctx,
        );

        (remain_receipt, log)
    }

    /// [User Function] Splits a bid receipt. If `share` is `None`, it merges the receipts.
    public fun simple_split_bid_receipt(
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusBidReceipt>,
        share: Option<u64>, // if None, return (amount, Some(receipt), None)
        ctx: &mut TxContext,
    ): (Option<TypusBidReceipt>, Option<TypusBidReceipt>, vector<u64>) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);

        // main logic
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let vid = vault::get_bid_receipt_vid(vector::borrow(&receipts, 0));
        let bid_vault = typus_dov_single::get_mut_bid_vault_by_id_or_index(bid_vault_registry, &vid, index);
        let (amount, split_receipt, remain_receipt) = vault::split_bid_receipt(
            bid_vault,
            receipts,
            share,
            ctx,
        );
        typus_dov_single::validate_amount(amount);
        (split_receipt, remain_receipt, vector[amount])
    }

    /// [User Function] Exercises a bid.
    #[allow(unused_type_parameter)]
    public fun exercise<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusBidReceipt>,
        ctx: &mut TxContext,
    ): (Balance<D_TOKEN>, vector<u64>) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);

        // main logic
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let bid_vault = typus_dov_single::get_mut_bid_vault_by_id(
            bid_vault_registry,
            &vault::get_bid_receipt_vid(vector::borrow(&receipts, 0)),
        );
        let (balance, log) = vault::public_exercise<D_TOKEN>(
            bid_vault,
            receipts,
        );
        let amount = *vector::borrow(&log, 0);
        let share = *vector::borrow(&log, 1);
        typus_dov_single::emit_exercise_event(
            index,
            amount,
            share,
            type_name::with_defining_ids<D_TOKEN>(),
            option::none(),
            0,
            tx_context::sender(ctx),
        );

        (balance, log)
    }

    /// [User Function] Claims a rebate.
    public fun rebate<TOKEN>(
        registry: &mut Registry,
        ctx: &mut TxContext,
    ): (Option<Balance<TOKEN>>, vector<u64>) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);

        // main logic
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let refund_vault = typus_dov_single::get_mut_refund_vault<TOKEN>(refund_vault_registry);
        let (balance, log) = vault::public_rebate<TOKEN>(
            refund_vault,
            tx_context::sender(ctx),
        );
        let amount = *vector::borrow(&log, 0);
        typus_dov_single::validate_amount(amount);
        typus_dov_single::emit_refund_event(
            type_name::with_defining_ids<TOKEN>(),
            amount,
            tx_context::sender(ctx),
        );

        (balance, log)
    }

    /// [User Function] Merges deposit receipts.
    public fun merge_deposit_receipts(
        registry: &mut Registry,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        ctx: &mut TxContext,
    ): (TypusDepositReceipt, vector<u64>) {
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let deposit_vault = typus_dov_single::get_mut_deposit_vault(deposit_vault_registry, index);
        let (receipt, log) = vault::merge_deposit_receipts(
            deposit_vault,
            receipts,
            ctx,
        );

        (option::destroy_some(receipt), log)
    }

    /// [User Function] Splits a deposit receipt.
    public fun split_deposit_receipt_v2(
        registry: &mut Registry,
        index: u64,
        receipt: TypusDepositReceipt,
        split_active_share: u64,
        split_warmup_share: u64,
        ctx: &mut TxContext,
    ): (Option<TypusDepositReceipt>, Option<TypusDepositReceipt>) {
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            portfolio_vault_registry,
            deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let deposit_vault = typus_dov_single::get_mut_deposit_vault(deposit_vault_registry, index);
        let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, index);
        typus_dov_single::validate_min_deposit_size(portfolio_vault, split_active_share + split_warmup_share);
        let (receipt_0, receipt_1) = vault::split_deposit_receipt(
            deposit_vault,
            receipt,
            split_active_share,
            split_warmup_share,
            ctx,
        );

        (receipt_0, receipt_1)
    }

    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun split_deposit_receipt(
        registry: &mut Registry,
        index: u64,
        receipt: TypusDepositReceipt,
        split_active_share: u64,
        split_warmup_share: u64,
        ctx: &mut TxContext,
    ): (TypusDepositReceipt, TypusDepositReceipt) { abort E_DEPRECATED_FUNCTION }
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun split_bid_receipt<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _receipts: vector<TypusBidReceipt>,
        _share: Option<u64>,
        _ctx: &mut TxContext,
    ): (u64, Option<TypusBidReceipt>, Option<TypusBidReceipt>) { abort E_DEPRECATED_FUNCTION }
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun claim<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (Balance<D_TOKEN>, Option<TypusDepositReceipt>, vector<u64>) { abort E_DEPRECATED_FUNCTION }
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun harvest<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (Balance<B_TOKEN>, Option<TypusDepositReceipt>, vector<u64>) { abort E_DEPRECATED_FUNCTION }
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun redeem<D_TOKEN, B_TOKEN, I_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _receipts: vector<TypusDepositReceipt>,
        _ctx: &mut TxContext,
    ): (Balance<I_TOKEN>, Option<TypusDepositReceipt>, vector<u64>) { abort E_DEPRECATED_FUNCTION }
}