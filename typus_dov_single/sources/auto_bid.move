module typus_dov::auto_bid {
    use std::bcs;
    use std::string::{Self, String};
    use std::type_name;

    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::table_vec::{Self, TableVec};
    use sui::vec_map::{Self, VecMap};

    use typus_dov::tds_view_function::{get_my_bids_bcs};
    use typus_dov::typus_dov_single::{Self, Registry};
    use typus_framework::dutch;
    use typus_framework::utils;
    use typus_framework::vault::{Self, TypusBidReceipt};
    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::leaderboard::TypusLeaderboardRegistry;
    use typus::tgld::TgldRegistry;
    use typus::user::TypusUserRegistry;

    // const LT_LEVEL: u64 = 0;

    // Error
    const E_INVALID_USER: u64 = 0;
    // const E_LOW_LEVEL: u64 = 1;
    const E_NO_VALID_RECEIPT: u64 = 2;
    const E_INVALID_AUTH: u64 = 3;
    const E_INVALID_INDEX: u64 = 4;
    const E_DEPRECATED: u64 = 999;

    public struct StrategyPoolV3 has key, store {
        id: UID,
        /// A map from vault index to a map of signal indices to a table of strategies.
        strategies: VecMap<u64, VecMap<u64, TableVec<StrategyV2>>>,
        /// A list of addresses authorized to manage the strategy pool.
        authority: vector<address>
    }

    /// Represents a single automated bidding strategy for a user.
    public struct StrategyV2 has key, store {
        id: UID,
        /// The index of the vault this strategy is for.
        vault_index: u64,
        /// The index of the signal this strategy is for.
        signal_index: u64,
        /// The address of the user who owns this strategy.
        user: address,
        // balance: Balance<B_TOKEN>,
        // profit: Balance<D_TOKEN>,
        /// The price percentage at which to bid.
        price_percentage: u64,
        /// The size of each bid.
        size: u64,
        /// The maximum number of times this strategy can bid.
        max_times: u64,
        /// A list of specific rounds this strategy should bid in. An empty vector means bid in all rounds.
        target_rounds: vector<u64>,
        /// A list of bid receipts from successful bids.
        receipts: vector<TypusBidReceipt>,
        /// Whether the strategy is currently active.
        active: bool,
        /// Padding for additional u64 fields. [balance, profit, accumulated_cost]
        u64_padding: vector<u64>,
        // log
        /// The number of times this strategy has bid.
        bid_times: u64,
        /// The last round this strategy bid in.
        bid_round: u64,
        /// The timestamp of the last bid.
        bid_ts_ms: u64,
        /// A list of rounds this strategy has bid in.
        bid_rounds: vector<u64>,
        /// The accumulated profit from this strategy.
        accumulated_profit: u64,
    }

    entry fun migrate_v3(registry: & Registry, strategy_pool_v2: StrategyPoolV2, ctx: &mut TxContext) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        typus_dov_single::validate_registry_authority(registry, ctx);

        let StrategyPoolV2 {
            id,
            strategies,
            authority,
        } = strategy_pool_v2;
        id.delete();

        let strategy_pool = StrategyPoolV3 {
            id: object::new(ctx),
            strategies,
            authority,
        };

        let event = NewStrategyPoolEvent {
            id: object::id(&strategy_pool),
            signer: tx_context::sender(ctx),
        };
        emit(event);

        transfer::public_share_object(strategy_pool);
    }

    #[test_only]
    public fun new_strategy_pool(scenario: &mut sui::test_scenario::Scenario) {
        let strategy_pool = StrategyPoolV3 {
            id: object::new(scenario.ctx()),
            strategies: vec_map::empty(),
            authority: vector[scenario.sender()],
        };
        transfer::public_share_object(strategy_pool);
    }

    /// Event emitted when a new strategy pool is created.
    public struct NewStrategyPoolEvent has copy, drop {
        id: ID,
        signer: address,
    }

    entry fun add_authority(registry: & Registry, strategy_pool: &mut StrategyPoolV3, new_authority: address, ctx: & TxContext) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        // check authority
        assert!(vector::contains(&strategy_pool.authority, &tx_context::sender(ctx)), E_INVALID_AUTH);

        vector::push_back(&mut strategy_pool.authority, new_authority);
        let event = AddAuthorutyEvent {
            new_authority,
            signer: tx_context::sender(ctx),
        };
        emit(event);
    }

    /// Event emitted when a new authority is added.
    public struct AddAuthorutyEvent has copy, drop {
        new_authority: address,
        signer: address,
    }

    entry fun new_strategy_vault(registry: & Registry, strategy_pool: &mut StrategyPoolV3, vault_index: u64, ctx: & TxContext) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        // check authority
        assert!(vector::contains(&strategy_pool.authority, &tx_context::sender(ctx)), E_INVALID_AUTH);

        assert!(!strategy_pool.strategies.contains(&vault_index), E_INVALID_INDEX);
        vec_map::insert(&mut strategy_pool.strategies, vault_index, vec_map::empty());

        let event = NewStrategyVaultEvent {
            id: object::id(strategy_pool),
            vault_index,
            signer: tx_context::sender(ctx),
        };
        emit(event);
    }

    /// Event emitted when a new strategy vault is created.
    public struct NewStrategyVaultEvent has copy, drop {
        id: ID,
        vault_index: u64,
        signer: address,
    }

    entry fun remove_strategy_vault(registry: & Registry, strategy_pool: &mut StrategyPoolV3, vault_index: u64, ctx: & TxContext) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        // check authority
        assert!(vector::contains(&strategy_pool.authority, &tx_context::sender(ctx)), E_INVALID_AUTH);

        assert!(strategy_pool.strategies.contains(&vault_index), E_INVALID_INDEX);
        let (_, mut vault) = vec_map::remove<u64, VecMap<u64, TableVec<StrategyV2>>>(&mut strategy_pool.strategies, &vault_index);

        while (!vec_map::is_empty(&vault)) {
            let (_, signal) = vec_map::pop(&mut vault);
            table_vec::destroy_empty(signal);
        };

        vec_map::destroy_empty(vault);

        let event = RemoveStrategyVaultEvent {
            id: object::id(strategy_pool),
            vault_index,
            signer: tx_context::sender(ctx),
        };
        emit(event);
    }

    entry fun close_strategy_vault<D_TOKEN, B_TOKEN>(
        registry: & Registry,
        strategy_pool: &mut StrategyPoolV3,
        vault_index: u64,
        ctx: &mut TxContext,
    ) {
        // check authority
        assert!(vector::contains(&strategy_pool.authority, &tx_context::sender(ctx)), E_INVALID_AUTH);
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, vault_index);

        let (_, mut vault) = vec_map::remove(&mut strategy_pool.strategies, &vault_index);
        let mut signal_keys = vec_map::keys(&vault);
        while (!vector::is_empty(&signal_keys)) {
            let signal_index = vector::pop_back(&mut signal_keys);
            let (_, mut signal) = vec_map::remove(&mut vault, &signal_index);
            while (signal.length() > 0) {
                // pop back
                let i = signal.length() - 1;
                let (coin_profit, coin_balance, user) = close_strategy_<D_TOKEN, B_TOKEN>(&mut signal, i, ctx);
                transfer::public_transfer(coin_profit, user);
                transfer::public_transfer(coin_balance, user);
            };
            // drop signal
            table_vec::destroy_empty(signal);
        };
        // drop vault
        vec_map::destroy_empty(vault);
    }

    public struct RemoveStrategyVaultEvent has copy, drop {
        id: ID,
        vault_index: u64,
        signer: address,
    }

    entry fun new_strategy_signal(registry: & Registry, strategy_pool: &mut StrategyPoolV3, vault_index: u64, signal_index: u64, ctx: &mut TxContext) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        // check authority
        assert!(vector::contains(&strategy_pool.authority, &tx_context::sender(ctx)), E_INVALID_AUTH);

        let vault = vec_map::get_mut(&mut strategy_pool.strategies, &vault_index);
        vec_map::insert(vault, signal_index, table_vec::empty<StrategyV2>(ctx));

        let event = NewStrategySignalEvent {
            id: object::id(strategy_pool),
            vault_index,
            signal_index,
            signer: tx_context::sender(ctx),
        };
        emit(event);
    }

    /// Event emitted when a new strategy signal is created.
    public struct NewStrategySignalEvent has copy, drop {
        id: ID,
        vault_index: u64,
        signal_index: u64,
        signer: address,
    }

    /// Event emitted when a new strategy is created.
    public struct NewStrategyEventV2 has copy, drop {
        vault_index: u64,
        signal_index: u64,
        user: address,
        price_percentage: u64,
        size: u64,
        max_times: u64,
        target_rounds: vector<u64>,
        deposit_amount: u64,
    }

    public fun new_strategy_v3<D_TOKEN, B_TOKEN>(
        registry: & Registry,
        strategy_pool: &mut StrategyPoolV3,
        vault_index: u64,
        signal_index: u64,
        size: u64,
        price_percentage: u64,
        max_times: u64,
        target_rounds: vector<u64>,
        coin: Coin<B_TOKEN>,
        ctx: &mut TxContext
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, vault_index);

        let user = tx_context::sender(ctx);
        // let staked_level = tails_staking::get_staked_level(registry, user);
        // assert!(staked_level > LT_LEVEL, E_LOW_LEVEL);

        let (_,_,_,_, portfolio_vault_registry,_, _, _,_,_,_,_) = typus_dov_single::get_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, vault_index);
        typus_dov_single::validate_bid_amount(portfolio_vault, size);

        let deposit_amount = coin::value(&coin);

        let mut strategy = StrategyV2 {
            id: object::new(ctx),
            vault_index,
            signal_index,
            user,
            size,
            price_percentage, // 100 (%) = 1
            max_times,
            target_rounds,
            receipts: vector::empty(),
            active: true,
            u64_padding: vector[deposit_amount, 0, 0],
            bid_times: 0,
            bid_round: 0,
            bid_ts_ms: 0,
            bid_rounds: vector::empty(),
            accumulated_profit: 0,
        };


        dynamic_field::add(&mut strategy.id, string::utf8(b"balance"), coin::into_balance(coin));
        dynamic_field::add(&mut strategy.id, string::utf8(b"profit"), balance::zero<D_TOKEN>());

        let vault = vec_map::get_mut(&mut strategy_pool.strategies, &vault_index);
        let signal = vec_map::get_mut(vault, &signal_index);
        table_vec::push_back(signal, strategy);

        let event = NewStrategyEventV2 {
            vault_index,
            signal_index,
            user,
            price_percentage,
            size,
            max_times,
            target_rounds,
            deposit_amount
        };
        emit(event);
    }

    /// Event emitted when a strategy is updated.
    public struct UpdateStrategyEvent has copy, drop {
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        user: address,
        price_percentage: u64,
        size: u64,
        max_times: u64,
        target_rounds: vector<u64>,
        deposit_amount: u64,
    }

    public fun update_strategy_v3<D_TOKEN, B_TOKEN>(
        registry: & Registry,
        strategy_pool: &mut StrategyPoolV3,
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        size: Option<u64>,
        price_percentage: Option<u64>,
        max_times: Option<u64>,
        target_rounds: vector<u64>,
        coins: vector<Coin<B_TOKEN>>,
        ctx: & TxContext
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, vault_index);

        let vault = vec_map::get_mut(&mut strategy_pool.strategies, &vault_index);
        let signal = vec_map::get_mut(vault, &signal_index);
        let strategy = table_vec::borrow_mut(signal, strategy_index);

        let user = tx_context::sender(ctx);
        assert!(strategy.user == user, E_INVALID_USER);
        // let staked_level = tails_staking::get_staked_level(registry, user);
        // assert!(staked_level > LT_LEVEL, E_LOW_LEVEL);

        if (option::is_some<u64>(&size)) {
            let (_,_,_,_, portfolio_vault_registry,_, _, _,_,_,_,_) = typus_dov_single::get_registry_inner(registry);
            let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, vault_index);
            let size = option::destroy_some<u64>(size);
            typus_dov_single::validate_bid_amount(portfolio_vault, size);
            strategy.size = size;
        };

        if (option::is_some<u64>(&price_percentage)) {
            strategy.price_percentage = option::destroy_some<u64>(price_percentage);
        };

        if (option::is_some<u64>(&max_times)) {
            strategy.max_times = option::destroy_some<u64>(max_times);
        };

        strategy.target_rounds = target_rounds;

        strategy.active = true;

        let c = utils::merge_coins(coins);
        let b = coin::into_balance(c);
        let deposit_amount = balance::value(&b);
        let balance_mut = dynamic_field::borrow_mut(&mut strategy.id, string::utf8(b"balance"));
        balance::join(balance_mut, b);

        update_u64_padding<D_TOKEN, B_TOKEN>(strategy);

        let event = UpdateStrategyEvent {
            vault_index,
            signal_index,
            strategy_index,
            user: strategy.user,
            price_percentage: strategy.price_percentage,
            size: strategy.size,
            max_times: strategy.max_times,
            target_rounds: strategy.target_rounds,
            deposit_amount
        };
        emit(event);
    }

    /// A helper function to update the padding field of a strategy.
    fun update_u64_padding<D_TOKEN, B_TOKEN>(strategy: &mut StrategyV2) {
        let ref_balance = dynamic_field::borrow<String, Balance<B_TOKEN>>(& strategy.id, string::utf8(b"balance"));
        let u64_padding_balance = balance::value(ref_balance);

        let ref_profit = dynamic_field::borrow<String, Balance<D_TOKEN>>(& strategy.id, string::utf8(b"profit"));
        let u64_padding_profit = balance::value(ref_profit);

        let mut accumulated_cost = 0;
        if (vector::length(&strategy.u64_padding) > 2) {
            accumulated_cost = *vector::borrow(&strategy.u64_padding, 2);
        };

        strategy.u64_padding = vector[u64_padding_balance, u64_padding_profit, accumulated_cost];
    }

    /// Event emitted when a strategy is closed.
    public struct CloseStrategyEventV2 has copy, drop {
        vault_index: u64,
        signal_index: u64,
        user: address,
        price_percentage: u64,
        size: u64,
        max_times: u64,
        target_rounds: vector<u64>,
        u64_padding: vector<u64>,
        bid_times: u64,
        bid_round: u64,
        bid_ts_ms: u64,
        bid_rounds: vector<u64>,
        accumulated_profit: u64,
    }

    public fun close_strategy_v3<D_TOKEN, B_TOKEN>(
        registry: & Registry,
        strategy_pool: &mut StrategyPoolV3,
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        ctx: &mut TxContext
    ): (Coin<D_TOKEN>, Coin<B_TOKEN>) {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, vault_index);

        let vault = vec_map::get_mut(&mut strategy_pool.strategies, &vault_index);
        let signal = vec_map::get_mut(vault, &signal_index);
        let (coin_profit, coin_balance, user) = close_strategy_<D_TOKEN, B_TOKEN>(signal, strategy_index, ctx);

        assert!(user == tx_context::sender(ctx), E_INVALID_USER);
        // let staked_level = tails_staking::get_staked_level(registry, user);
        // assert!(staked_level > LT_LEVEL, E_LOW_LEVEL);

        (coin_profit, coin_balance)
    }

    /// The internal logic for closing a strategy.
    fun close_strategy_<D_TOKEN, B_TOKEN>(
        signal: &mut TableVec<StrategyV2>,
        strategy_index: u64,
        ctx: &mut TxContext
    ): (Coin<D_TOKEN>, Coin<B_TOKEN>, address) {
        let mut strategy = table_vec::swap_remove(signal, strategy_index);

        update_u64_padding<D_TOKEN, B_TOKEN>(&mut strategy);
        let balance = dynamic_field::remove(&mut strategy.id, string::utf8(b"balance"));
        let profit = dynamic_field::remove(&mut strategy.id, string::utf8(b"profit"));

        let StrategyV2 {
            id,
            vault_index,
            signal_index,
            user,
            size,
            price_percentage,
            max_times,
            target_rounds,
            mut receipts,
            active:_,
            u64_padding,
            bid_times,
            bid_round,
            bid_ts_ms,
            bid_rounds,
            accumulated_profit,
        } = strategy;

        while (!vector::is_empty(&receipts)) {
            let receipt = vector::pop_back(&mut receipts);
            transfer::public_transfer(receipt, user);
        };
        vector::destroy_empty(receipts);
        object::delete(id);

        let event = CloseStrategyEventV2 {
            vault_index,
            signal_index,
            user,
            price_percentage,
            size,
            max_times,
            target_rounds,
            u64_padding,
            bid_times,
            bid_round,
            bid_ts_ms,
            bid_rounds,
            accumulated_profit
        };
        emit(event);

        let coin_profit = coin::from_balance<D_TOKEN>(profit, ctx);
        let coin_balance = coin::from_balance<B_TOKEN>(balance, ctx);
        (coin_profit, coin_balance, user)
    }

    /// Event emitted when a bid receipt is withdrawn from a strategy.
    public struct WithdrawBidReceiptEvent has copy, drop {
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        user: address,
    }

    public fun withdraw_bid_receipt_v3(
        registry: &mut Registry,
        strategy_pool: &mut StrategyPoolV3,
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        ctx: &mut TxContext
    ): TypusBidReceipt {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);

        let vault = vec_map::get_mut(&mut strategy_pool.strategies, &vault_index);
        let signal = vec_map::get_mut(vault, &signal_index);
        let strategy = table_vec::borrow_mut(signal, strategy_index);
        let user = tx_context::sender(ctx);
        assert!(strategy.user == user, E_INVALID_USER);

        let (_,_,_,_,_,_,_, bid_vault_registry,_,_,_,_) = typus_dov_single::get_mut_registry_inner(registry);
        let bid_vault = typus_dov_single::get_bid_vault(bid_vault_registry, vault_index);
        let current_vid = object::id(bid_vault);

        let mut j = 0;
        let mut found = false;

        if (!vector::is_empty(&strategy.receipts)) {
            let receipts_length = vector::length(&strategy.receipts);
            while (j < receipts_length) {
                let receipt = vector::borrow(&strategy.receipts, j);
                let vid = vault::get_bid_receipt_vid(receipt);
                if (vid == current_vid) {
                    // found the active receipt and return
                    found = true;
                    break
                };
                j = j + 1;
            };
        };
        if (!found) { abort E_NO_VALID_RECEIPT };

        let receipt = vector::swap_remove(&mut strategy.receipts, j);

        let event = WithdrawBidReceiptEvent {
            vault_index,
            signal_index,
            strategy_index,
            user: strategy.user,
        };
        emit(event);

        receipt
    }

    /// Event emitted when profit is withdrawn from a strategy.
    public struct WithdrawProfitEvent has copy, drop {
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        user: address,
        profit: u64,
    }

    public fun withdraw_profit_v3<D_TOKEN, B_TOKEN>(
        registry: & Registry,
        strategy_pool: &mut StrategyPoolV3,
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        ctx: &mut TxContext
    ): Coin<D_TOKEN> {
        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, vault_index);

        let vault = vec_map::get_mut(&mut strategy_pool.strategies, &vault_index);
        let signal = vec_map::get_mut(vault, &signal_index);
        let strategy = table_vec::borrow_mut(signal, strategy_index);
        let user = tx_context::sender(ctx);
        assert!(strategy.user == user, E_INVALID_USER);
        // let staked_level = tails_staking::get_staked_level(registry, user);
        // assert!(staked_level > LT_LEVEL, E_LOW_LEVEL);

        let profit = dynamic_field::borrow_mut<String, Balance<D_TOKEN>>(&mut strategy.id, string::utf8(b"profit"));
        let value = balance::value(profit);
        let coin_profit = coin::take<D_TOKEN>(profit, value, ctx);
        update_u64_padding<D_TOKEN, B_TOKEN>(strategy);

        let event = WithdrawProfitEvent {
            vault_index,
            signal_index,
            strategy_index,
            user: strategy.user,
            profit: value
        };
        emit(event);

        coin_profit
    }

    /// [Authorized Function] The core logic for placing automated bids based on the defined strategies.
    entry fun new_bid<D_TOKEN, B_TOKEN>(
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        tgld_registry: &mut TgldRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        registry: &mut Registry,
        strategy_pool: &mut StrategyPoolV3,
        vault_index: u64,
        signal_index: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        // check authority
        assert!(vector::contains(&strategy_pool.authority, &tx_context::sender(ctx)), E_INVALID_AUTH);

        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, vault_index);

        let (registry_mut_uid,_,_,_, portfolio_vault_registry,_, auction_registry, bid_vault_registry, refund_vault_registry,_,_,_) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_mut_portfolio_vault(portfolio_vault_registry, vault_index);
        let bid_vault = typus_dov_single::get_mut_bid_vault(bid_vault_registry, vault_index);
        let auction = typus_dov_single::get_mut_auction(auction_registry, vault_index);
        let refund_vault = typus_dov_single::get_mut_refund_vault<B_TOKEN>(refund_vault_registry);
        let round = typus_dov_single::get_round(portfolio_vault);
        let ts_ms = clock::timestamp_ms(clock);
        let fee_discount = 0;
        let max_size = dutch::size(auction);
        let (auction_start, auction_duration) = typus_dov_single::get_auction_ts(portfolio_vault);
        let pct = 100 - ((ts_ms - auction_start) * 100 / auction_duration);

        let vault = vec_map::get_mut(&mut strategy_pool.strategies, &vault_index);
        let signal = vec_map::get_mut(vault, &signal_index);

        let length = table_vec::length(signal);
        let mut i = 0;

        while (i < length) {
            let strategy = table_vec::borrow_mut(signal, i);
            if (
                (   vector::contains(&strategy.target_rounds, &round) || vector::length(&strategy.target_rounds) == 0) &&
                (
                    (strategy.bid_times < strategy.max_times) &&
                    (strategy.bid_round < round) &&
                    (pct <= strategy.price_percentage) &&
                    (strategy.active)
                )
            ) {
                let bidder = strategy.user;
                let size = strategy.size;
                let b = dynamic_field::borrow_mut<String, Balance<B_TOKEN>>(&mut strategy.id, string::utf8(b"balance"));

                typus_dov_single::validate_bid(portfolio_vault, auction, size);
                let total_bid_size = dutch::total_bid_size(auction);
                let size = if (total_bid_size + size > max_size) { max_size - total_bid_size } else { size };
                let (incentive_usage, total_cost) = typus_dov_single::get_new_bid_incentive_balance_value<B_TOKEN>(registry_mut_uid, portfolio_vault, auction, size, fee_discount, clock);

                if (balance::value(b) >= total_cost) {
                    if (size > 0) {
                        let temp_b = balance::withdraw_all(b);
                        let coins = vector[coin::from_balance(temp_b, ctx)];

                        let incentive_balance = typus_dov_single::get_new_bid_incentive_balance<B_TOKEN>(registry_mut_uid, portfolio_vault, incentive_usage);
                        let (bid_index, price, size, bidder_balance, incentive_balance, ts_ms, _, coin) = dutch::public_new_bid_v2<B_TOKEN>(refund_vault, auction, bidder, size, coins, incentive_balance, fee_discount, clock, ctx);

                        balance::join(b, coin::into_balance(coin));
                        if (balance::value(b) < total_cost) {
                            // insufficient balance
                            strategy.active = false;
                        };
                        let receipt = vault::public_new_bid(bid_vault, size, ctx);
                        vector::push_back(&mut strategy.receipts, receipt);

                        typus_dov_single::emit_new_bid_event(portfolio_vault, bid_index, price, size, bidder_balance, incentive_balance, ts_ms, bidder);

                        let premium_in_usd = typus_dov_single::calculate_in_usd<B_TOKEN>(portfolio_vault, bidder_balance, false);
                        let premium_in_usd_with_decimal = typus_dov_single::calculate_in_usd_with_decimal<B_TOKEN>(portfolio_vault, bidder_balance);
                        let point = premium_in_usd * 200;
                        typus_dov_single::add_accumulated_tgld_amount(
                            registry_mut_uid,
                            typus_ecosystem_version,
                            typus_user_registry,
                            tgld_registry,
                            strategy.user,
                            point,
                            ctx,
                        );
                        typus_dov_single::add_leaderboard_score(
                            registry_mut_uid,
                            typus_ecosystem_version,
                            typus_leaderboard_registry,
                            std::ascii::string(b"bidding_leaderboard"),
                            strategy.user,
                            premium_in_usd_with_decimal,
                            clock,
                            ctx,
                        );
                        typus_dov_single::add_user_tails_exp_amount(
                            registry_mut_uid,
                            typus_ecosystem_version,
                            typus_user_registry,
                            strategy.user,
                            point,
                        );

                        strategy.bid_times = strategy.bid_times + 1;
                        strategy.bid_round = round;
                        strategy.bid_ts_ms = ts_ms;
                        vector::push_back(&mut strategy.bid_rounds, round);
                        update_u64_padding<D_TOKEN, B_TOKEN>(strategy);
                    } else {
                        // sold  out
                        break
                    }
                } else {
                    // insufficient balance
                    strategy.active = false;
                };
            };

            // next
            i = i + 1;
        };
    }

    /// [Authorized Function] Exercises the options won from the automated bids.
    entry fun exercise<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        strategy_pool: &mut StrategyPoolV3,
        vault_index: u64,
        signal_index: u64,
        ctx: & TxContext,
    ) {
        // check authority
        assert!(vector::contains(&strategy_pool.authority, &tx_context::sender(ctx)), E_INVALID_AUTH);

        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, vault_index);

        let (_,_,_,_, portfolio_vault_registry,_,_, bid_vault_registry,_,_,_,_) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, vault_index);

        let vault = vec_map::get_mut(&mut strategy_pool.strategies, &vault_index);
        let signal = vec_map::get_mut(vault, &signal_index);

        let length = table_vec::length(signal);

        let bid_vault = typus_dov_single::get_bid_vault(bid_vault_registry, vault_index);
        let current_vid = object::id(bid_vault);
        let mut vid_exercisable = current_vid;

        let mut i = 0;
        while (i < length) {
            let strategy = table_vec::borrow(signal, i);
            if (!vector::is_empty(&strategy.receipts)) {
                let mut j = 0;
                let receipts_length = vector::length(&strategy.receipts);
                while (j < receipts_length) {
                    let receipt = vector::borrow(&strategy.receipts, j);
                    let vid = vault::get_bid_receipt_vid(receipt);
                    if (vid != current_vid) {
                        vid_exercisable = vid;
                        // inside while loop
                        break
                    };
                    j = j + 1;
                };
                if (vid_exercisable != current_vid) {
                    // outside while loop
                    break
                };
            };
            // next
            i = i + 1;
        };

        let bid_vault = typus_dov_single::get_mut_bid_vault_by_id(bid_vault_registry, &vid_exercisable);
        let mut i = 0;
        while (i < length) {
            let strategy = table_vec::borrow_mut(signal, i);
            if (!vector::is_empty(&strategy.receipts)) {
                let mut receipts =  vector::empty<TypusBidReceipt>();
                //  remove same vid receipts
                let mut j = 0;
                let receipts_length = vector::length(&strategy.receipts);
                while (j < receipts_length) {
                    let receipt_vid = vault::get_bid_receipt_vid(vector::borrow(& strategy.receipts, j));
                    if (vid_exercisable == receipt_vid) {
                        let receipt = vector::remove(&mut strategy.receipts, j);
                        vector::push_back(&mut receipts, receipt);
                        // receipts_length = receipts_length - 1;
                        // contains only one
                        break
                    } else {
                        // next
                        j = j + 1;
                    };
                };

                if (!vector::is_empty(&receipts)) {
                    let (amount, share, balance) = vault::delegate_exercise<D_TOKEN>(bid_vault, receipts);
                    // transfer::public_transfer(coin::from_balance(balance, ctx), strategy.user);
                    if (!dynamic_field::exists_(&strategy.id, string::utf8(b"profit"))) {
                        dynamic_field::add(&mut strategy.id, string::utf8(b"profit"), balance::zero<D_TOKEN>());
                    };
                    let b = dynamic_field::borrow_mut<String, Balance<D_TOKEN>>(&mut strategy.id, string::utf8(b"profit"));
                    balance::join(b, balance);
                    strategy.accumulated_profit = strategy.accumulated_profit + amount;

                    typus_dov_single::emit_exercise_event(vault_index, amount, share, type_name::with_defining_ids<D_TOKEN>(), option::none(), 0, strategy.user);
                    // update after exercise
                    update_u64_padding<D_TOKEN, B_TOKEN>(strategy);
                    let accumulated_cost = vector::borrow_mut(&mut strategy.u64_padding, 2);
                    let delivery_price = vault::get_bid_vault_u64_padding_value(bid_vault, 1);
                    let bid_incentive_bp = vault::get_bid_vault_u64_padding_value(bid_vault, 2);
                    let o_token_decimal = typus_dov_single::get_o_token_decimal(portfolio_vault);
                    let cost = (((delivery_price as u128)
                                * (share as u128) / (utils::multiplier(o_token_decimal) as u128)) as u64)
                                * 11000 / 10000
                                * (10000 - bid_incentive_bp) / 10000;
                    *accumulated_cost = *accumulated_cost + cost;
                } else {
                    // no receipts to exercise
                    vector::destroy_empty(receipts);
                };
            };

            // next
            i = i + 1;
        }
    }

    /// [Authorized Function] Exercises a single strategy's options.
    entry fun exercise_single<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        strategy_pool: &mut StrategyPoolV3,
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        ctx: & TxContext,
    ) {
        // check authority
        assert!(vector::contains(&strategy_pool.authority, &tx_context::sender(ctx)), E_INVALID_AUTH);

        typus_dov_single::version_check(registry);
        typus_dov_single::operation_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, vault_index);

        let (_,_,_,_, portfolio_vault_registry,_,_, bid_vault_registry,_,_,_,_) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, vault_index);

        let vault = vec_map::get_mut(&mut strategy_pool.strategies, &vault_index);
        let signal = vec_map::get_mut(vault, &signal_index);

        let bid_vault = typus_dov_single::get_bid_vault(bid_vault_registry, vault_index);
        let current_vid = object::id(bid_vault);

        let strategy = table_vec::borrow_mut(signal, strategy_index);
        if (!vector::is_empty(&strategy.receipts)) {
            let mut j = 0;
            let mut receipts_length = vector::length(&strategy.receipts);
            while (j < receipts_length) {
                let receipt = vector::borrow(&strategy.receipts, j);
                let vid = vault::get_bid_receipt_vid(receipt);
                if (vid != current_vid) {
                    // exercisable
                    let bid_vault = typus_dov_single::get_mut_bid_vault_by_id(bid_vault_registry, &vid);
                    let receipt = vector::remove(&mut strategy.receipts, j);

                    let (amount, share, balance) = vault::delegate_exercise<D_TOKEN>(bid_vault, vector[receipt]);
                    // transfer::public_transfer(coin::from_balance(balance, ctx), strategy.user);
                    if (!dynamic_field::exists_(&strategy.id, string::utf8(b"profit"))) {
                        dynamic_field::add(&mut strategy.id, string::utf8(b"profit"), balance::zero<D_TOKEN>());
                    };
                    let b = dynamic_field::borrow_mut<String, Balance<D_TOKEN>>(&mut strategy.id, string::utf8(b"profit"));
                    balance::join(b, balance);
                    strategy.accumulated_profit = strategy.accumulated_profit + amount;

                    typus_dov_single::emit_exercise_event(vault_index, amount, share, type_name::with_defining_ids<D_TOKEN>(), option::none(), 0, strategy.user);
                    // update after exercise
                    update_u64_padding<D_TOKEN, B_TOKEN>(strategy);
                    let accumulated_cost = vector::borrow_mut(&mut strategy.u64_padding, 2);
                    let delivery_price = vault::get_bid_vault_u64_padding_value(bid_vault, 1);
                    let bid_incentive_bp = vault::get_bid_vault_u64_padding_value(bid_vault, 2);
                    let o_token_decimal = typus_dov_single::get_o_token_decimal(portfolio_vault);
                    let cost = (((delivery_price as u128)
                                * (share as u128) / (utils::multiplier(o_token_decimal) as u128)) as u64)
                                * 11000 / 10000
                                * (10000 - bid_incentive_bp) / 10000;
                    *accumulated_cost = *accumulated_cost + cost;

                    receipts_length = receipts_length - 1;
                } else {
                    // next
                    j = j + 1;
                };
            };
        };
    }

    // WARNING: for dry_run only!
    public(package) fun view_user_strategies(
        registry: & Registry,
        strategy_pool: &mut StrategyPoolV3,
        user: address,
    ): vector<vector<u8>> {
        let mut result = vector::empty();

        let mut vault_keys = vec_map::keys(&strategy_pool.strategies);
        while (!vector::is_empty(&vault_keys)) {
            let vault_index = vector::pop_back(&mut vault_keys);
            let vault = vec_map::get_mut(&mut strategy_pool.strategies, &vault_index);
            let mut signal_keys = vec_map::keys(vault);
            while (!vector::is_empty(&signal_keys)) {
                let signal_index = vector::pop_back(&mut signal_keys);
                let signal = vec_map::get_mut(vault, &signal_index);
                let length = table_vec::length(signal);
                let mut i = 0;
                while (i < length) {
                    let strategy = table_vec::borrow_mut(signal, i);
                    if (strategy.user == user) {
                        let mut data = bcs::to_bytes(strategy);
                        vector::append(&mut data, bcs::to_bytes(&i));

                        let mut receipts = vector::empty<TypusBidReceipt>();
                        while (!vector::is_empty(&strategy.receipts)) {
                            let receipt = vector::pop_back(&mut strategy.receipts);
                            vector::push_back(&mut receipts, receipt);
                        };

                        let my_bids_bcs = get_my_bids_bcs(registry, receipts);
                        vector::append(&mut data, bcs::to_bytes(&my_bids_bcs));

                        vector::push_back(&mut result, data);
                    };
                    // next
                    i = i + 1;
                };
            };
            vector::destroy_empty(signal_keys);
        };
        vector::destroy_empty(vault_keys);

        result
    }

    // Deprecated
    #[allow(unused_field)]
    public struct Strategy has key, store {
        id: UID,
        vault_index: u64,
        signal_index: u64,
        user: address,
        // balance: Balance<B_TOKEN>,
        // profit: Balance<D_TOKEN>,
        price_percentage: u64,
        size: u64,
        max_times: u64,
        target_rounds: vector<u64>,
        receipts: vector<TypusBidReceipt>,
        active: bool,
        u64_padding: vector<u64>,
        // bid_rounds: vector<u64>,
        // acc_profit: u64,
        // log
        bid_times: u64,
        bid_round: u64,
        bid_ts_ms: u64,
    }

    #[allow(unused_field)]
    public struct StrategyPool has key, store {
        id: UID,
        strategies: VecMap<u64, VecMap<u64, TableVec<Strategy>>>,
        authority: vector<address>
    }

    #[allow(unused_field)]
    public struct CloseStrategyEvent has copy, drop {
        vault_index: u64,
        signal_index: u64,
        user: address,
        price_percentage: u64,
        size: u64,
        max_times: u64,
        target_rounds: vector<u64>,
        u64_padding: vector<u64>,
        bid_times: u64,
        bid_round: u64,
        bid_ts_ms: u64,
    }

    #[allow(unused_field)]
    public struct NewStrategyEvent has copy, drop {
        vault_index: u64,
        signal_index: u64,
        user: address,
        price_percentage: u64,
        size: u64,
        max_times: u64,
        target_rounds: vector<u64>,
    }

    /// [Deprecated] Use StrategyPoolV3 instead.
    #[allow(unused)]
    public struct StrategyPoolV2 has key, store {
        id: UID,
        strategies: VecMap<u64, VecMap<u64, TableVec<StrategyV2>>>,
        authority: vector<address>
    }

    #[allow(unused)]
    public fun new_strategy<D_TOKEN, B_TOKEN>(
        registry: & Registry,
        strategy_pool: &mut StrategyPoolV2,
        vault_index: u64,
        signal_index: u64,
        size: u64,
        price_percentage: u64,
        max_times: u64,
        target_rounds: vector<u64>,
        coin: Coin<B_TOKEN>,
        ctx: &mut TxContext
    ) {
        abort E_DEPRECATED
    }

    #[allow(unused)]
    public fun update_strategy<D_TOKEN, B_TOKEN>(
        registry: & Registry,
        strategy_pool: &mut StrategyPoolV2,
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        size: Option<u64>,
        price_percentage: Option<u64>,
        max_times: Option<u64>,
        target_rounds: vector<u64>,
        coins: vector<Coin<B_TOKEN>>,
        ctx: & TxContext
    ) {
        abort E_DEPRECATED
    }

    #[allow(unused)]
    public fun close_strategy<D_TOKEN, B_TOKEN>(
        registry: & Registry,
        strategy_pool: &mut StrategyPoolV2,
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        ctx: &mut TxContext
    ): (Coin<D_TOKEN>, Coin<B_TOKEN>) {
        abort E_DEPRECATED
    }

    #[allow(unused)]
    public fun withdraw_bid_receipt(
        registry: &mut Registry,
        strategy_pool: &mut StrategyPoolV2,
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        ctx: &mut TxContext
    ): TypusBidReceipt {
        abort E_DEPRECATED
    }

    #[allow(unused)]
    public fun withdraw_profit<D_TOKEN, B_TOKEN>(
        registry: & Registry,
        strategy_pool: &mut StrategyPoolV2,
        vault_index: u64,
        signal_index: u64,
        strategy_index: u64,
        ctx: &mut TxContext
    ): Coin<D_TOKEN> {
        abort E_DEPRECATED
    }

    #[allow(unused)]
    public struct AutoBidEvent has copy, drop {}
}