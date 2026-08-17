/// The `position` module defines the `Position` and `TradingOrder` structs, and the logic for creating, updating, and closing them.
/// All of the functions are inner package functions used in `trading.move`.
module typus_perp::position {
    use std::type_name::{Self, TypeName};
    use std::string::{Self, String};

    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::bcs;
    use sui::coin;

    use typus_perp::admin::{Self, Version};
    use typus_perp::competition::{Self, CompetitionConfig};
    use typus_perp::error;
    use typus_perp::math::{Self, amount_to_usd, usd_to_amount};
    use typus_perp::symbol::Symbol;
    use typus_perp::lp_pool::{Self, LiquidityPool};

    use typus::tails_staking::TailsStakingRegistry;
    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::leaderboard::TypusLeaderboardRegistry;
    use typus_framework::vault::TypusBidReceipt;
    use typus_dov::typus_dov_single::{Self, Registry as DovRegistry};
    use typus_dov::tds_user_entry;
    use typus_oracle::oracle::Oracle;

    // ======== Constants ========
    const C_MAX_ORDER_TYPE_TAG: u8 = 3;
    const C_MAX_LINKED_ORDER_AMOUNT: u64 = 5;

    // ======== Keys ========
    const K_COLLATERAL: vector<u8> = b"collateral";             // vector<TypusBidReceipt> or Balance<C_TOKEN> (TradingOrder & Position)
    const K_DEPOSIT_TOKEN: vector<u8> = b"deposit_token";       // TypeName (TradingOrder)
    const K_PORTFOLIO_INDEX: vector<u8> = b"portfolio_index";   // u64 (TradingOrder)

    // ======== Structs ========
    /// A struct that represents a trading position.
    #[allow(lint(missing_key))]
    public struct Position has store {
        id: UID,
        /// The timestamp when the position was created.
        create_ts_ms: u64,
        /// The timestamp when the position was last updated.
        update_ts_ms: u64,
        /// The ID of the position.
        position_id: u64,
        /// A vector of the linked order IDs.
        linked_order_ids: vector<u64>,
        /// A vector of the linked order prices.
        linked_order_prices: vector<u64>,
        /// The address of the user.
        user: address,
        /// Whether the position is long.
        is_long: bool,
        /// The size of the position.
        size: u64, // position size represent order.to_token_amount in USD when opening order
        /// The number of decimals for the size.
        size_decimal: u64,
        /// The type name of the collateral token.
        collateral_token: TypeName, // C_TOKEN
        /// The number of decimals for the collateral token.
        collateral_token_decimal: u64,
        /// The symbol of the trading pair.
        symbol: Symbol,
        /// The amount of collateral.
        collateral_amount: u64,// order.collateral_amount - execution_fee_amount in c_token amount
        /// The amount of reserved collateral.
        reserve_amount: u64, // position.size in collateral token amount
        /// The average price of the position.
        average_price: u64,
        /// The entry borrow index.
        entry_borrow_index: u64,
        /// The sign of the entry funding rate index.
        entry_funding_rate_index_sign: bool,
        /// The entry funding rate index.
        entry_funding_rate_index: u64,
        /// The unrealized loss.
        unrealized_loss: u64, // only option collateral position uses it
        /// The sign of the unrealized funding fee.
        unrealized_funding_sign: bool, // true -> should pay
        /// The unrealized funding fee.
        unrealized_funding_fee: u64,
        /// The unrealized trading fee.
        unrealized_trading_fee: u64,
        /// The unrealized borrow fee.
        unrealized_borrow_fee: u64, // option collateral position also uses this field to store unrealized trading fee
        /// The unrealized rebate.
        unrealized_rebate: u64,
        /// Information about the option collateral.
        option_collateral_info: Option<OptionCollateralInfo>, // if token collateral position, this field is None
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// A struct that holds information about option collateral.
    public struct OptionCollateralInfo has store, drop {
        /// The index of the portfolio.
        index: u64,
        /// The type name of the bid token.
        bid_token: TypeName, // deposit_token = collateral_token
        /// A vector of the BCS-serialized bid receipts.
        bid_receipts_bcs: vector<vector<u8>>, // vector[bcs of one bid receipt]
    }

    /// A struct that represents a trading order.
    #[allow(lint(missing_key))]
    public struct TradingOrder has store {
        id: UID,
        /// The timestamp when the order was created.
        create_ts_ms: u64,
        /// The ID of the order.
        order_id: u64,
        /// The ID of the linked position.
        linked_position_id: Option<u64>,
        /// The address of the user.
        user: address,
        // user token type
        /// The type name of the collateral token.
        collateral_token: TypeName, // C_TOKEN
        /// The number of decimals for the collateral token.
        collateral_token_decimal: u64,
        /// The symbol of the trading pair.
        symbol: Symbol,
        // order parameters
        /// The leverage in mega basis points.
        leverage_mbp: u64, // TODO: adjust for removing collateral
        /// Whether the order is reduce-only.
        reduce_only: bool,
        /// Whether the order is long.
        is_long: bool,
        /// Whether the order is a stop order.
        is_stop_order: bool,
        /// The size of the order.
        size: u64,
        /// The number of decimals for the size.
        size_decimal: u64,
        /// The trigger price of the order.
        trigger_price: u64,
        /// The oracle price when the order was placed.
        oracle_price_when_placing: u64,
        /// Padding for future use.
        u64_padding: vector<u64>, // [collateral.value]
        // record the amount user deposited into MarketCollateral<TOKEN>
        // execution_info: ExecutionInfo,
        // collateral_amount: u64, // execution_fee_amount not yet deducted
        // execution_fee_amount: u64,
    }

    /// Creates a new trading order.
    /// WARNING: no authority check inside
    public(package) fun create_order<C_TOKEN>(
        version: &Version,
        // order parameters
        symbol: Symbol,
        leverage_mbp: u64,
        reduce_only: bool,
        is_long: bool,
        is_stop_order: bool,
        size: u64,
        size_decimal: u64,
        trigger_price: u64,
        collateral: Balance<C_TOKEN>,
        collateral_token_decimal: u64,
        // generated by entry function
        linked_position_id: Option<u64>,
        order_id: u64,
        oracle_price: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): TradingOrder {
        // safety check
        admin::version_check(version);
        let mut order = TradingOrder {
            id: object::new(ctx),
            create_ts_ms: clock::timestamp_ms(clock),
            order_id,
            linked_position_id,
            user: tx_context::sender(ctx),
            collateral_token: type_name::with_defining_ids<C_TOKEN>(),
            collateral_token_decimal,
            symbol,
            leverage_mbp,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            size_decimal,
            trigger_price,
            oracle_price_when_placing: oracle_price,
            u64_padding: vector[collateral.value()],
        };
        dynamic_field::add(&mut order.id, string::utf8(K_COLLATERAL), collateral);
        order
    }

    /// Removes a trading order.
    /// WARNING: no authority check inside
    public(package) fun remove_order<C_TOKEN>(
        version: &Version,
        order: TradingOrder,
    ): Balance<C_TOKEN> {
        // safety check
        admin::version_check(version);
        let TradingOrder {
            id: mut id,
            create_ts_ms: _,
            order_id: _,
            linked_position_id: _,
            user: _,
            // user token type
            collateral_token: _, // C_TOKEN
            collateral_token_decimal: _,
            symbol: _,
            // order parameters
            leverage_mbp: _,
            reduce_only: _,
            is_long: _,
            is_stop_order: _,
            size: _,
            size_decimal: _,
            // to_token_usd_size: u64,
            trigger_price: _,
            oracle_price_when_placing: _,
            u64_padding: _,
        } = order;
        let balance = dynamic_field::remove<String, Balance<C_TOKEN>>(&mut id, string::utf8(K_COLLATERAL));
        object::delete(id);
        balance
    }

    /// [Authorized Function] Creates a reduce-only order by the manager.
    public(package) fun manager_create_reduce_only_order<C_TOKEN>(
        version: &Version,
        // order parameters
        symbol: Symbol,
        is_long: bool,
        size: u64,
        size_decimal: u64,
        trigger_price: u64,
        collateral: Balance<C_TOKEN>,
        collateral_token_decimal: u64,
        // generated by entry function
        linked_position_id: u64,
        user: address,
        order_id: u64,
        oracle_price: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): TradingOrder {
        // safety check
        admin::verify(version, ctx);
        let mut order = TradingOrder {
            id: object::new(ctx),
            create_ts_ms: clock::timestamp_ms(clock),
            order_id,
            linked_position_id: option::some(linked_position_id),
            user,
            collateral_token: type_name::with_defining_ids<C_TOKEN>(),
            collateral_token_decimal,
            symbol,
            leverage_mbp: math::get_mbp_scale(), // 1x leverage
            reduce_only: true,
            is_long,
            is_stop_order: false,
            size,
            size_decimal,
            trigger_price,
            oracle_price_when_placing: oracle_price,
            u64_padding: vector[collateral.value()],
        };
        dynamic_field::add(&mut order.id, string::utf8(K_COLLATERAL), collateral);
        order
    }

    /// Increases the collateral of a position.
    /// WARNING: no authority check inside
    public(package) fun increase_collateral<C_TOKEN>(
        position: &mut Position,
        collateral: Balance<C_TOKEN>,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
    ) {
        let balance = dynamic_field::borrow_mut<String, Balance<C_TOKEN>>(&mut position.id, string::utf8(K_COLLATERAL));
        balance.join(collateral);
        position.collateral_amount = balance.value();
        position.reserve_amount = calculate_reserve_amount(
            position.size,
            position.size_decimal,
            position.collateral_amount,
            position.collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
        );
    }

    /// Releases collateral from a position.
    /// WARNING: no authority check inside
    public(package) fun release_collateral<C_TOKEN>(
        position: &mut Position,
        release_amount: u64,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
    ): Balance<C_TOKEN> {
        let balance = dynamic_field::borrow_mut<String, Balance<C_TOKEN>>(&mut position.id, string::utf8(K_COLLATERAL));
        let released_balance = balance.split(release_amount);
        position.collateral_amount = balance.value();
        position.reserve_amount = calculate_reserve_amount(
            position.size,
            position.size_decimal,
            position.collateral_amount,
            position.collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
        );
        released_balance
    }

    /// An event that is emitted when a position is removed.
    public struct RemovePositionEvent has copy, drop {
        user: address,
        collateral_token: TypeName,
        symbol: Symbol,
        linked_order_ids: vector<u64>,
        linked_order_prices: vector<u64>,
        remaining_collateral_amount: u64,
        realized_trading_fee_amount: u64,
        realized_borrow_fee_amount: u64,
        u64_padding: vector<u64>
    }
    /// Removes a position.
    /// WARNING: no authority check inside
    public(package) fun remove_position<C_TOKEN>(
        version: &Version,
        position: Position,
    ): (Balance<C_TOKEN>, Balance<C_TOKEN>, vector<u64>, vector<u64>) {
        // TODO: user pnl <-> lp pool
        // safety check
        admin::version_check(version);
        let Position {
            id: mut id,
            create_ts_ms: _,
            update_ts_ms: _,
            position_id: _,
            linked_order_ids,
            linked_order_prices,
            user,
            is_long: _,
            size: _,
            size_decimal: _,
            collateral_token,
            collateral_token_decimal: _,
            symbol,
            collateral_amount: _,
            reserve_amount: _,
            average_price: _,
            entry_borrow_index: _,
            entry_funding_rate_index_sign: _,
            entry_funding_rate_index: _,
            unrealized_loss: _, // token collateral position never uses this field
            unrealized_funding_sign: _, // funding should be realized before
            unrealized_funding_fee: _, // funding should be realized before
            unrealized_trading_fee,
            unrealized_borrow_fee,
            unrealized_rebate: _,
            option_collateral_info,
            u64_padding: _,
        } = position;
        option_collateral_info.destroy_none();
        let mut balance = dynamic_field::remove<String, Balance<C_TOKEN>>(&mut id, string::utf8(K_COLLATERAL));
        object::delete(id);
        let mut collateral_value = balance.value();
        let borrow_fee_balance = balance.split(
            if (unrealized_borrow_fee >= collateral_value) {
                collateral_value
            } else {
                unrealized_borrow_fee
            }
        );
        collateral_value = collateral_value - borrow_fee_balance.value();
        let mut trading_fee_balance = balance.split(
            if (unrealized_trading_fee >= collateral_value) {
                collateral_value
            } else {
                unrealized_trading_fee
            }
        );
        emit(RemovePositionEvent {
            user,
            collateral_token,
            symbol,
            linked_order_ids,
            linked_order_prices,
            remaining_collateral_amount: balance.value(),
            realized_trading_fee_amount: trading_fee_balance.value(),
            realized_borrow_fee_amount: borrow_fee_balance.value(),
            u64_padding: vector::empty()
        });
        trading_fee_balance.join(borrow_fee_balance);
        (balance, trading_fee_balance, linked_order_ids, linked_order_prices)
    }

    /// An event that is emitted when an order is filled.
    public struct OrderFilledEvent has copy, drop {
        user: address,
        collateral_token: TypeName,
        symbol: Symbol,
        order_id: u64,
        linked_position_id: Option<u64>, // none -> new open -> new_position_id should not be none
        new_position_id: Option<u64>, // none -> flatten
        filled_size: u64,
        filled_price: u64,
        position_side: bool,
        position_size: u64,
        position_average_price: u64,
        realized_trading_fee: u64,
        realized_borrow_fee: u64,
        realized_fee_in_usd: u64,
        realized_amount: u64,
        realized_amount_sign: bool,
        u64_padding: vector<u64>
    }
    /// Handles a filled order.
    /// WARNING: no authority check inside
    public(package) fun order_filled<C_TOKEN>(
        version: &Version,
        ecosystem_version: &TypusEcosystemVersion,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        order: TradingOrder,
        mut original_position: Option<Position>,
        next_position_id: u64,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        cumulative_borrow_rate: u64,
        cumulative_funding_rate_index_sign: bool, // true -> longs pay fee to shorts
        cumulative_funding_rate_index: u64,
        trading_fee_mbp: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Position, u64, u64, u64) {
        // safety check
        admin::version_check(version);

        let TradingOrder {
            id: mut id,
            create_ts_ms: _,
            order_id,
            linked_position_id,
            user,
            // user token type
            collateral_token, // C_TOKEN
            collateral_token_decimal,
            symbol,
            // order parameters
            leverage_mbp: _,
            reduce_only,
            is_long,
            is_stop_order: _,
            size,
            size_decimal,
            trigger_price: _,
            oracle_price_when_placing: _,
            u64_padding: _,
        } = order;

        assert!(collateral_token == type_name::with_defining_ids<C_TOKEN>(), error::wrong_collateral_type());
        let actual_order_size = if (option::is_some(&original_position)) {
            let position_size = original_position.borrow().size;
            let position_side = original_position.borrow().is_long;
            if (is_long != position_side) {
                if (position_size > size) { size } else { position_size } // flip position side not supported
            } else {
                size
            }
        } else { size };
        let balance = dynamic_field::remove<String, Balance<C_TOKEN>>(&mut id, string::utf8(K_COLLATERAL));
        let (fee_in_c_token, trading_fee_usd) = calculate_trading_fee(
            actual_order_size,
            size_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
            collateral_token_decimal,
        );

        let new_added_collateral_amount = balance.value();
        let has_new_position_id = option::is_none(&original_position);

        let (mut position, is_realized, is_profit, realized_usd, filled_size) = if (option::is_some(&original_position)) {
            let mut position = option::extract(&mut original_position);
            let original_size = position.get_position_size();
            let original_side = position.get_position_side();
            let (is_realized, is_profit, realized_usd, new_side, new_size, average_price) = calculate_filled_(
                &position,
                // order related parameters
                reduce_only,
                is_long,
                actual_order_size,
                // price
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
            );
            remove_position_linked_order_info(&mut position, order_id);
            let filled_size = if (new_side == original_side) {
                if (new_size >= original_size) {
                    new_size - original_size
                } else {
                    original_size - new_size
                }
            } else {
                new_size + original_size
            };

            update_position_borrow_rate_and_funding_rate(
                &mut position,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
                cumulative_borrow_rate,
                cumulative_funding_rate_index_sign,
                cumulative_funding_rate_index,
            );
            let collateral_amount = dynamic_field::borrow<String, Balance<C_TOKEN>>(&position.id, string::utf8(K_COLLATERAL));
            let new_collateral_amount = collateral_amount.value() + new_added_collateral_amount;
            let reserve_amount = calculate_reserve_amount(
                new_size,
                position.size_decimal,
                new_collateral_amount,
                position.collateral_token_decimal,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
            );

            position.update_ts_ms = clock.timestamp_ms();
            position.is_long = new_side;
            position.size = new_size;
            position.average_price = average_price;
            position.reserve_amount = reserve_amount;
            position.unrealized_trading_fee = position.unrealized_trading_fee + fee_in_c_token;
            (position, is_realized, is_profit, realized_usd, filled_size)
        } else {
            let reserve_amount = calculate_reserve_amount(
                size,
                size_decimal,
                new_added_collateral_amount,
                collateral_token_decimal,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
            );
            let mut position = Position {
                id: object::new(ctx),
                create_ts_ms: clock.timestamp_ms(),
                update_ts_ms: clock.timestamp_ms(),
                position_id: next_position_id,
                linked_order_ids: vector::empty(),
                linked_order_prices: vector::empty(),
                user,
                is_long,
                size,
                size_decimal,
                collateral_token,
                collateral_token_decimal,
                symbol,
                collateral_amount: new_added_collateral_amount - fee_in_c_token,// order.collateral_amount - execution_fee_amount in c_token amount
                reserve_amount, // position.size in collateral token amount
                average_price: trading_pair_oracle_price,
                entry_borrow_index: cumulative_borrow_rate,
                unrealized_loss: 0,
                entry_funding_rate_index_sign: cumulative_funding_rate_index_sign,
                entry_funding_rate_index: cumulative_funding_rate_index,
                unrealized_funding_sign: true,
                unrealized_funding_fee: 0,
                unrealized_trading_fee: fee_in_c_token,
                unrealized_borrow_fee: 0,
                unrealized_rebate: 0,
                option_collateral_info: option::none(),
                u64_padding: vector::empty(),
            };
            dynamic_field::add(&mut position.id, string::utf8(K_COLLATERAL), balance::zero<C_TOKEN>());
            (position, false, false, 0, size)
        };
        dynamic_field::borrow_mut<String, Balance<C_TOKEN>>(&mut position.id, string::utf8(K_COLLATERAL)).join(balance);

        // convert realized_usd from USD to C_TOKEN
        let realized_amount = usd_to_amount(realized_usd, position.collateral_token_decimal, collateral_oracle_price, collateral_oracle_price_decimal);

        // realized_loss_balance for lp_pool
        let realized_loss_value = if (!is_profit) {
            realized_amount
        } else {
            0
        };
        // realized_profit_value for profit request
        let realized_profit_value = if (is_realized && is_profit) { realized_amount } else { 0 };

        object::delete(id);
        option::destroy_none(original_position);

        position.collateral_amount = dynamic_field::borrow<String, Balance<C_TOKEN>>(&position.id, string::utf8(K_COLLATERAL)).value();

        let realized_fee_in_usd = amount_to_usd(
            fee_in_c_token + position.unrealized_borrow_fee,
            position.collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );

        let filled_size_in_usd = amount_to_usd(
            filled_size,
            size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal
        );

        competition::add_score(
            version,
            ecosystem_version,
            typus_leaderboard_registry,
            tails_staking_registry,
            competition_config,
            filled_size_in_usd,
            user,
            clock,
            ctx,
        );

        emit(OrderFilledEvent {
            user,
            collateral_token,
            symbol,
            order_id,
            linked_position_id, // none -> new open -> new_position_id should not be none
            new_position_id: if (has_new_position_id) { option::some(position.position_id) } else { option::none() }, // none -> flatten
            filled_size,
            filled_price: trading_pair_oracle_price,
            position_side: position.is_long,
            position_size: position.size,
            position_average_price: position.average_price,
            realized_trading_fee: fee_in_c_token,
            realized_borrow_fee: position.unrealized_borrow_fee,
            realized_fee_in_usd,
            realized_amount,
            realized_amount_sign: is_profit,
            u64_padding: vector[if (is_long) { 1 } else { 0 }] // order.is_long
        });

        (
            position,
            realized_loss_value,
            realized_profit_value,
            trading_fee_usd
        )
    }

    /// Realizes the PnL and fees of a position.
    /// WARNING: no authority check inside
    public(package) fun realize_position_pnl_and_fee<C_TOKEN>(
        version: &mut Version,
        liquidity_pool: &mut LiquidityPool,
        position: &mut Position,
        profit_value_to_realize: u64,
        loss_value_to_realize: u64,
        original_reserve: u64,
        protocol_fee_share_bp: u64,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
    ): Balance<C_TOKEN> {
        let fee_value_to_realize = position.unrealized_trading_fee + position.unrealized_borrow_fee;
        // !(profit_value_to_realize != 0 && loss_value_to_realize != 0)
        // realize profit from lp_pool
        let mut realized_profit = lp_pool::request_collateral<C_TOKEN>(
            liquidity_pool,
            profit_value_to_realize,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
        );

        let collateral = dynamic_field::remove<String, Balance<C_TOKEN>>(
                    &mut position.id,
                    string::utf8(K_COLLATERAL)
                );
        let original_collateral_value = collateral.value();
        // join profit and collateral together
        realized_profit.join(collateral);

        let mut realized_loss = realized_profit.split(loss_value_to_realize);

        let mut fee = realized_profit.split(fee_value_to_realize);
        // share fee
        let shared_balance = fee.split(
            ((fee_value_to_realize as u128)
                * (protocol_fee_share_bp as u128) / (math::get_bp_scale() as u128) as u64)
        );
        admin::charge_fee(version, shared_balance);

        realized_loss.join(fee);
        // deal with pnl balance and update lp pool reserve
        let reserve_amount = position.reserve_amount;
        lp_pool::order_filled<C_TOKEN>(
            liquidity_pool,
            reserve_amount > original_reserve,
            if (reserve_amount > original_reserve) {
                reserve_amount - original_reserve
            } else {
                original_reserve - reserve_amount
            },
            realized_loss
        );

        // realized funding fee
        // 1. charge from position -> put balance into lp pool liquidity
        if (position.unrealized_funding_fee > 0) {
            // payout
            if (position.unrealized_funding_sign) {
                let funding_balance = realized_profit.split(position.unrealized_funding_fee);
                position.unrealized_funding_fee = position.unrealized_funding_fee - funding_balance.value();

                let realized_value_in_usd = amount_to_usd(
                    funding_balance.value(),
                    position.collateral_token_decimal,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal
                );
                emit_realized_funding_event(
                    position.user,
                    position.collateral_token,
                    position.symbol,
                    position.position_id,
                    position.unrealized_funding_sign,
                    funding_balance.value(),
                    realized_value_in_usd,
                    vector::empty(),
                );

                lp_pool::put_collateral<C_TOKEN>(
                    liquidity_pool,
                    funding_balance,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal,
                );
            } else {
                // request_collateral will update value_in_usd
                let funding_income = lp_pool::request_collateral<C_TOKEN>(
                    liquidity_pool,
                    position.unrealized_funding_fee,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal,
                );
                let funding_income_value = funding_income.value();
                realized_profit.join(funding_income);
                position.unrealized_funding_fee = position.unrealized_funding_fee - funding_income_value;

                let funding_income_value_in_usd = amount_to_usd(
                    funding_income_value,
                    position.collateral_token_decimal,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal
                );

                emit_realized_funding_event(
                    position.user,
                    position.collateral_token,
                    position.symbol,
                    position.position_id,
                    position.unrealized_funding_sign,
                    funding_income_value,
                    funding_income_value_in_usd,
                    vector::empty(),
                );
            };
        };

        let remaining_profit = if (realized_profit.value() > original_collateral_value) {
                realized_profit.value() - original_collateral_value
            } else { 0 };
        let profit_balance = realized_profit.split(remaining_profit);

        let collateral_amount = realized_profit.value();

        // put remaining collateral back to position
        dynamic_field::add<String, Balance<C_TOKEN>>(
                    &mut position.id,
                    string::utf8(K_COLLATERAL),
                    realized_profit
                );

        position.unrealized_trading_fee = 0;
        position.unrealized_borrow_fee = 0;
        // already updated above
        // position.unrealized_funding_fee = 0;
        position.collateral_amount = collateral_amount;

        profit_balance
    }

    /// Realizes the funding fee of a position.
    /// WARNING: no authority check inside
    public(package) fun realize_funding_fee<C_TOKEN>(
        liquidity_pool: &mut LiquidityPool,
        position: &mut Position,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        ctx: &mut TxContext,
    ) {
        if (position.unrealized_funding_fee > 0) {
            if (position.unrealized_funding_sign) {
                let collateral = dynamic_field::borrow_mut<String, Balance<C_TOKEN>>(
                    &mut position.id,
                    string::utf8(K_COLLATERAL)
                );
                let actual_realized_funding_fee = if (position.unrealized_funding_fee > collateral.value()) {
                    collateral.value()
                } else { position.unrealized_funding_fee };
                let funding_balance = collateral.split(actual_realized_funding_fee);
                position.unrealized_funding_fee = position.unrealized_funding_fee - funding_balance.value();

                let realized_value_in_usd = amount_to_usd(
                    funding_balance.value(),
                    position.collateral_token_decimal,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal
                );
                emit_realized_funding_event(
                    position.user,
                    position.collateral_token,
                    position.symbol,
                    position.position_id,
                    position.unrealized_funding_sign,
                    funding_balance.value(),
                    realized_value_in_usd,
                    vector::empty(),
                );

                lp_pool::put_collateral<C_TOKEN>(
                    liquidity_pool,
                    funding_balance,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal,
                );
            } else {
                // request_collateral will update value_in_usd
                let funding_income = lp_pool::request_collateral<C_TOKEN>(
                    liquidity_pool,
                    position.unrealized_funding_fee,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal,
                );
                let funding_income_value = funding_income.value();
                position.unrealized_funding_fee = position.unrealized_funding_fee - funding_income_value;
                transfer::public_transfer(
                    coin::from_balance(funding_income, ctx),
                    position.user
                );

                let funding_income_value_in_usd = amount_to_usd(
                    funding_income_value,
                    position.collateral_token_decimal,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal
                );

                emit_realized_funding_event(
                    position.user,
                    position.collateral_token,
                    position.symbol,
                    position.position_id,
                    position.unrealized_funding_sign,
                    funding_income_value,
                    funding_income_value_in_usd,
                    vector::empty(),
                );
            };

        };
    }

    public(package) fun check_order_filled(
        order: &TradingOrder,
        oracle_price: u64
    ): bool {
        if (order.is_long) {
            if (order.is_stop_order) {
                // stop buy: oracle price = 100, trigger price = 98 => filled at 100
                oracle_price >= order.trigger_price
            } else {
                // limit buy: trigger price = 100, oracle_price = 90 => filled at 90
                oracle_price <= order.trigger_price
            }
        } else {
            if (order.is_stop_order) {
                oracle_price <= order.trigger_price
            } else {
                oracle_price >= order.trigger_price
            }
        }
    }

    fun calculate_period_borrow_cost(
        position: &Position,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        cumulative_borrow_rate: u64
    ): (u64, u64) {
        let reserve_usd
            = amount_to_usd(position.size, position.size_decimal, trading_pair_oracle_price, trading_pair_oracle_price_decimal);
        let reserve_amount = calculate_reserve_amount(
            position.size,
            position.size_decimal,
            position.collateral_amount,
            position.collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
        );
        let period_borrow_cost = ((reserve_amount as u128)
            * ((cumulative_borrow_rate - position.entry_borrow_index) as u128)
                / (math::multiplier(lp_pool::get_borrow_rate_decimal()) as u128) as u64);

        (reserve_usd, period_borrow_cost)
    }

    public(package) fun check_position_liquidated(
        position: &Position,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
        maintenance_margin_rate_bp: u64,
        cumulative_borrow_rate: u64, // latest borrow rate
        cumulative_funding_rate_index_sign: bool,
        cumulative_funding_rate_index: u64,
    ): bool {
        let (unrealized_funding_sign, unrealized_funding_fee) = calculate_position_funding_rate(
            position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_funding_rate_index_sign,
            cumulative_funding_rate_index,
        );
        let unrealized_funding_fee_usd
            = amount_to_usd(unrealized_funding_fee, position.collateral_token_decimal, collateral_oracle_price, collateral_oracle_price_decimal);
        // remaining collateral w/ pnl
        let collateral_usd_w_pnl = collateral_with_pnl(
            position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp
        );

        // borrow fee & unpaid trading fee
        let (reserve_usd, period_borrow_cost) = calculate_period_borrow_cost(
            position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate
        );
        let unrealized_borrow_fee_in_usd = amount_to_usd(
            position.unrealized_borrow_fee + period_borrow_cost,
            position.collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );
        let maintenance_margin = ((maintenance_margin_rate_bp as u128) * (reserve_usd as u128) / (math::get_bp_scale() as u128) as u64);

        // consider unrealized borrow fee
        let remaining_collateral_usd = if (collateral_usd_w_pnl > unrealized_borrow_fee_in_usd) {
            let remaining_collateral_usd = collateral_usd_w_pnl - unrealized_borrow_fee_in_usd;
            // pay funding fee
            if (unrealized_funding_sign) {
                if (remaining_collateral_usd > unrealized_funding_fee_usd) {
                    remaining_collateral_usd - unrealized_funding_fee_usd
                } else { 0 }
            } else {
                // receive funding fee
                remaining_collateral_usd + unrealized_funding_fee_usd
            }
        } else {
            // pay funding fee => collateral not enough
            // receive funding fee => check if collateral enough after collecting funding fee
            if (unrealized_funding_sign) { 0 } else {
                if (collateral_usd_w_pnl + unrealized_funding_fee_usd > unrealized_borrow_fee_in_usd) {
                    collateral_usd_w_pnl + unrealized_funding_fee_usd - unrealized_borrow_fee_in_usd
                } else { 0 }
            }
        };
        remaining_collateral_usd <= maintenance_margin
    }

    // price diff. pnl & fee for unwinding position
    public(package) fun calculate_unrealized_pnl(
        position: &Position,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
    ): (bool, u64, u64) {
        let filled_usd = amount_to_usd(
            position.size,
            position.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal
        );
        let fee_usd = ((filled_usd as u128) * (trading_fee_mbp as u128) / (math::get_mbp_scale() as u128) as u64);

        let d_price = std::u64::diff(trading_pair_oracle_price, position.average_price);
        let mut pnl_usd = ((position.size as u128) * (d_price as u128)
                / (math::multiplier(position.size_decimal + trading_pair_oracle_price_decimal - math::get_usd_decimal()) as u128) as u64);

        let mut has_profit = if (position.is_long) {
            trading_pair_oracle_price > position.average_price
        } else {
            trading_pair_oracle_price < position.average_price
        };

        // fee adjusted
        if (has_profit) {
            if (pnl_usd < fee_usd) {
                has_profit = false;
                pnl_usd = fee_usd - pnl_usd;
            } else {
                pnl_usd = pnl_usd - fee_usd;
            };
        } else {
            pnl_usd = pnl_usd + fee_usd;
        };

        (has_profit, pnl_usd, fee_usd)
    }

    public(package) fun max_releasing_collateral_amount(
        position: &Position,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
        cumulative_borrow_rate: u64,
        max_entry_leverage_mbp: u64,
    ): u64 {
        // remaining collateral w/ pnl
        let collateral_usd_w_pnl = collateral_with_pnl(
            position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp
        );
        // borrow fee & unpaid trading fee
        let (reserve_usd, period_borrow_cost) = calculate_period_borrow_cost(
            position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate
        );
        let unrealized_borrow_fee_in_usd = amount_to_usd(
            position.unrealized_borrow_fee + period_borrow_cost,
            position.collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );
        let min_remaining_collateral_usd = ((math::get_mbp_scale() as u128) * (reserve_usd as u128) / (max_entry_leverage_mbp as u128) as u64);

        if (collateral_usd_w_pnl >= unrealized_borrow_fee_in_usd) {
            let adjusted_collateral_usd = collateral_usd_w_pnl - unrealized_borrow_fee_in_usd;
            if (adjusted_collateral_usd > min_remaining_collateral_usd) {
                usd_to_amount(
                    adjusted_collateral_usd - min_remaining_collateral_usd,
                    position.collateral_token_decimal,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal
                )
            } else {
                0
            }
        } else {
            0
        }
    }

    public(package) fun get_estimated_liquidation_price(
        position: &Position,
        is_same_token: bool,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
        maintenance_margin_rate_bp: u64,
    ): u64 {
        // returned value should be in "trading_oracle_price_decimal"
        let is_long = position.get_position_side();
        if (is_same_token) {
            if (is_long) {
                // numerator in collateral_token_decimal
                let numerator = ((position.size as u256)
                                        * (position.average_price as u256)
                                            * (math::multiplier(position.collateral_token_decimal) as u256)
                                                / (math::multiplier(position.size_decimal) as u256)
                                                    / (math::multiplier(trading_oracle_price_decimal) as u256) as u128);
                // denominator_plus in collateral_token_decimal
                let mut denominator_plus = (position.collateral_amount as u128)
                                                    + (position.size as u128)
                                                        * (math::multiplier(position.collateral_token_decimal) as u128)
                                                            / (math::multiplier(position.size_decimal) as u128);
                // denominator_minus in collateral_token_decimal
                let mut denominator_minus = (position.unrealized_borrow_fee as u128)
                    + ((position.size as u128) * (trading_fee_mbp as u128) / (math::get_mbp_scale() as u128)
                        + (position.size as u128) * (maintenance_margin_rate_bp as u128) / (math::get_bp_scale() as u128))
                            * (math::multiplier(position.collateral_token_decimal) as u128)
                                / (math::multiplier(position.size_decimal) as u128);

                if (position.unrealized_funding_sign) {
                    denominator_minus = denominator_minus + (position.unrealized_funding_fee as u128);
                } else {
                    denominator_plus = denominator_plus + (position.unrealized_funding_fee as u128);
                };

                if (denominator_plus > denominator_minus) {
                    ((math::multiplier(trading_oracle_price_decimal) as u128)
                        * numerator / (denominator_plus - denominator_minus) as u64)
                } else { 0 }

            } else {
                // numerator in collateral_token_decimal
                let numerator = ((position.size as u256)
                                        * (position.average_price as u256)
                                            * (math::multiplier(position.collateral_token_decimal) as u256)
                                                    / (math::multiplier(position.size_decimal) as u256)
                                                        / (math::multiplier(trading_oracle_price_decimal) as u256) as u128);
                // denominator_plus in collateral_token_decimal
                let mut denominator_plus = (position.unrealized_borrow_fee as u128)
                    + ((position.size as u128)
                        + (position.size as u128) * (trading_fee_mbp as u128) / (math::get_mbp_scale() as u128)
                            + (position.size as u128) * (maintenance_margin_rate_bp as u128) / (math::get_bp_scale() as u128))
                                * (math::multiplier(position.collateral_token_decimal) as u128)
                                    / (math::multiplier(position.size_decimal) as u128);
                // denominator_minus in collateral_token_decimal
                let mut denominator_minus = (position.collateral_amount as u128);

                if (position.unrealized_funding_sign) {
                    denominator_plus = denominator_plus + (position.unrealized_funding_fee as u128);
                } else {
                    denominator_minus = denominator_minus + (position.unrealized_funding_fee as u128);
                };

                if (denominator_plus > denominator_minus) {
                    ((math::multiplier(trading_oracle_price_decimal) as u128)
                        * numerator / (denominator_plus - denominator_minus) as u64)
                } else { 0 }
            }
        } else {
            let collateral_usd = amount_to_usd(
                position.collateral_amount,
                position.collateral_token_decimal,
                collateral_oracle_price,
                collateral_oracle_price_decimal
            );
            let borrow_fee_usd = amount_to_usd(
                position.unrealized_borrow_fee,
                position.collateral_token_decimal,
                collateral_oracle_price,
                collateral_oracle_price_decimal
            );
            let funding_fee_usd = amount_to_usd(
                position.unrealized_funding_fee,
                position.collateral_token_decimal,
                collateral_oracle_price,
                collateral_oracle_price_decimal
            );
            if (is_long) {
                // numerator_plus in usd_decimal
                let mut numerator_plus = (borrow_fee_usd as u128)
                                                + ((position.size as u256)
                                                    * (position.average_price as u256)
                                                        * (math::multiplier(math::get_usd_decimal()) as u256)
                                                            / (math::multiplier(position.size_decimal) as u256)
                                                                / (math::multiplier(trading_oracle_price_decimal) as u256) as u128);
                // numerator_minus in usd_decimal
                let mut numerator_minus = (collateral_usd as u128);
                if (position.unrealized_funding_sign) {
                    numerator_plus = numerator_plus + (funding_fee_usd as u128);
                } else {
                    numerator_minus = numerator_minus + (funding_fee_usd as u128);
                };
                // denominator_plus in size_decimal
                let denominator_plus = (position.size as u128);
                // denominator_minus in size_decimal
                let denominator_minus = (position.size as u128) * (trading_fee_mbp as u128) / (math::get_mbp_scale() as u128)
                    + (position.size as u128) * (maintenance_margin_rate_bp as u128) / (math::get_bp_scale() as u128);

                if (numerator_plus > numerator_minus && denominator_plus > denominator_minus) {
                    // denominator in usd_decimal
                    let mut denominator = denominator_plus - denominator_minus;
                    denominator = ((denominator as u256)
                                    * (math::multiplier(math::get_usd_decimal()) as u256)
                                        / (math::multiplier(position.size_decimal) as u256) as u128);
                    ((math::multiplier(trading_oracle_price_decimal) as u128) * (numerator_plus - numerator_minus) / denominator as u64)
                } else { 0 }

            } else {
                // numerator_plus in usd_decimal
                let mut numerator_plus = (collateral_usd as u128)
                                                + ((position.size as u256)
                                                    * (position.average_price as u256)
                                                        * (math::multiplier(math::get_usd_decimal()) as u256)
                                                            / (math::multiplier(position.size_decimal) as u256)
                                                                / (math::multiplier(trading_oracle_price_decimal) as u256) as u128);
                // numerator_minus in usd_decimal
                let mut numerator_minus = (borrow_fee_usd as u128);
                if (position.unrealized_funding_sign) {
                    numerator_minus = numerator_minus + (funding_fee_usd as u128);
                } else {
                    numerator_plus = numerator_plus + (funding_fee_usd as u128);
                };
                // denominator in usd_decimal
                let mut denominator = (position.size as u128)
                    + (position.size as u128) * (trading_fee_mbp as u128) / (math::get_mbp_scale() as u128)
                    + (position.size as u128) * (maintenance_margin_rate_bp as u128) / (math::get_bp_scale() as u128);
                denominator = ((denominator as u256)
                                * (math::multiplier(math::get_usd_decimal()) as u256)
                                    / (math::multiplier(position.size_decimal) as u256) as u128);

                if (numerator_plus > numerator_minus) {
                    ((math::multiplier(trading_oracle_price_decimal) as u128) * (numerator_plus - numerator_minus) / denominator as u64)
                } else { 0 }
            }
        }
    }

    // ======= Functions for Option collateral ======
    public(package) fun create_order_with_bid_receipts(
        version: &Version,
        // order parameters
        symbol: Symbol,
        portfolio_index: u64,
        deposit_token: TypeName,
        leverage_mbp: u64,
        reduce_only: bool,
        is_long: bool,
        is_stop_order: bool,
        size: u64,
        size_decimal: u64,
        trigger_price: u64,
        collateral_bid_receipts: vector<TypusBidReceipt>, // should be empty when reduce_only
        deposit_token_decimal: u64,
        // generated by entry function
        linked_position_id: Option<u64>,
        order_id: u64,
        oracle_price: u64,
        user: address,
        clock: &Clock,
        ctx: &mut TxContext
    ): TradingOrder {
        // safety check
        admin::version_check(version);
        assert!(
            (reduce_only && collateral_bid_receipts.length() == 0) || !reduce_only,
            error::invalid_bid_receipts_input()
        );

        let mut order = TradingOrder {
            id: object::new(ctx),
            create_ts_ms: clock::timestamp_ms(clock),
            order_id,
            linked_position_id,
            user,
            collateral_token: type_name::with_defining_ids<TypusBidReceipt>(),
            collateral_token_decimal: deposit_token_decimal,
            symbol,
            leverage_mbp,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            size_decimal,
            trigger_price,
            oracle_price_when_placing: oracle_price,
            u64_padding: vector[0],
        };
        dynamic_field::add(&mut order.id, string::utf8(K_COLLATERAL), collateral_bid_receipts);
        dynamic_field::add(&mut order.id, string::utf8(K_DEPOSIT_TOKEN), deposit_token);
        dynamic_field::add(&mut order.id, string::utf8(K_PORTFOLIO_INDEX), portfolio_index);
        order
    }

    // public(package) fun remove_order_with_bid_receipts(
    //     version: &Version,
    //     order: TradingOrder,
    // ): vector<TypusBidReceipt> {
    //     // safety check
    //     admin::version_check(version);
    //     let TradingOrder {
    //         id: mut id,
    //         create_ts_ms: _,
    //         order_id: _,
    //         linked_position_id: _,
    //         user: _,
    //         // user token type
    //         collateral_token, // TypusBidReceipt
    //         collateral_token_decimal: _,
    //         symbol: _,
    //         // order parameters
    //         leverage_mbp: _,
    //         reduce_only: _,
    //         is_long: _,
    //         is_stop_order: _,
    //         size: _,
    //         size_decimal: _,
    //         // to_token_usd_size: u64,
    //         trigger_price: _,
    //         oracle_price_when_placing: _,
    //         u64_padding: _,
    //     } = order;
    //     assert!(collateral_token == type_name::with_defining_ids<TypusBidReceipt>(), error::wrong_collateral_type());
    //     let bid_receipts = if (dynamic_field::exists_<String>(&id, string::utf8(K_COLLATERAL))) {
    //         dynamic_field::remove<String, vector<TypusBidReceipt>>(&mut id, string::utf8(K_COLLATERAL))
    //     } else {
    //         vector::empty()
    //     };
    //     let _ = dynamic_field::remove<String, TypeName>(&mut id, string::utf8(K_DEPOSIT_TOKEN));
    //     let _ = dynamic_field::remove<String, u64>(&mut id, string::utf8(K_PORTFOLIO_INDEX));
    //     object::delete(id);
    //     bid_receipts
    // }

    public(package) fun remove_position_with_bid_receipts(
        version: &Version,
        position: Position,
    ): (vector<TypusBidReceipt>, vector<u64>, vector<u64>, u64, bool, u64, u64, u64, u64) {
        // safety check
        admin::version_check(version);

        let Position {
            id: mut id,
            create_ts_ms: _,
            update_ts_ms: _,
            position_id: _,
            linked_order_ids,
            linked_order_prices,
            user: _,
            is_long: _,
            size: _,
            size_decimal: _,
            collateral_token: _,
            collateral_token_decimal: _,
            symbol: _,
            collateral_amount: _,
            reserve_amount: _,
            average_price: _,
            entry_borrow_index: _,
            entry_funding_rate_index_sign: _,
            entry_funding_rate_index: _,
            unrealized_loss, // only option collateral position uses it
            unrealized_funding_sign, // true -> should pay
            unrealized_funding_fee,
            unrealized_trading_fee,
            unrealized_borrow_fee,
            unrealized_rebate,
            option_collateral_info: _,
            u64_padding: _,
        } = position;

        let bid_receipts = dynamic_field::remove<String, vector<TypusBidReceipt>>(&mut id, string::utf8(K_COLLATERAL));
        object::delete(id);
        (
            bid_receipts,
            linked_order_ids,
            linked_order_prices,
            unrealized_loss,
            unrealized_funding_sign,
            unrealized_funding_fee,
            unrealized_trading_fee,
            unrealized_borrow_fee,
            unrealized_rebate
        )
    }

    public(package) fun order_filled_with_bid_receipts_collateral<C_TOKEN, B_TOKEN>(
        version: &Version,
        ecosystem_version: &TypusEcosystemVersion,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        liquidity_pool: &mut LiquidityPool,
        dov_registry: &DovRegistry,
        typus_oracle_trading_symbol: &Oracle,
        typus_oracle_c_token: &Oracle,
        order: TradingOrder,
        mut original_position: Option<Position>,
        next_position_id: u64,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        cumulative_borrow_rate: u64,
        cumulative_funding_rate_index_sign: bool,
        cumulative_funding_rate_index: u64,
        trading_fee_mbp: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Position, Balance<C_TOKEN>, Balance<C_TOKEN>, Balance<C_TOKEN>, Balance<C_TOKEN>, u64) {
        // safety check
        admin::version_check(version);

        let TradingOrder {
            id: mut id,
            create_ts_ms: _,
            order_id,
            linked_position_id,
            user,
            // user token type
            collateral_token, // TypeName: TypusBidReceipt
            collateral_token_decimal, // should be token decimal of string::utf8(K_DEPOSIT_TOKEN)
            symbol,
            // order parameters
            leverage_mbp: _,
            reduce_only,
            is_long,
            is_stop_order: _,
            size,
            size_decimal,
            trigger_price: _,
            oracle_price_when_placing: _,
            u64_padding: _,
        } = order;

        assert!(collateral_token == type_name::with_defining_ids<TypusBidReceipt>(), error::wrong_collateral_type());

        let deposit_token = dynamic_field::remove<String, TypeName>(&mut id, string::utf8(K_DEPOSIT_TOKEN));
        let portfolio_index = dynamic_field::remove<String, u64>(&mut id, string::utf8(K_PORTFOLIO_INDEX));

        let (fee_in_d_token, trading_fee_usd) = calculate_trading_fee(
            size,
            size_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
            collateral_token_decimal,
        );

        // let rebate = ((fee_in_d_token as u128) * (referral_fee_rebate_bp as u128) / 10000 as u64);
        // fee_in_d_token = fee_in_d_token - rebate;

        let (mut bid_receipts, collateral_amount) = if (!reduce_only) {
            let receipts = dynamic_field::remove<String, vector<TypusBidReceipt>>(&mut id, string::utf8(K_COLLATERAL));
            let collateral_amount = calculate_intrinsic_value<C_TOKEN>(dov_registry, typus_oracle_trading_symbol, typus_oracle_c_token, &receipts, clock);
            (
                option::some(receipts),
                collateral_amount
            )
        } else {
            (option::none(), 0)
        };

        let (mut position, is_realized, is_profit, realized_usd, filled_size) = if (option::is_some(&original_position)) {
            let mut position = option::extract(&mut original_position);
            let original_size = position.get_position_size();
            let original_side = position.get_position_side();
            let position_deposit_token = position.collateral_token;
            let position_portfolio_index = position.option_collateral_info.borrow().index;
            assert!(deposit_token == position_deposit_token, error::deposit_token_mismatched());
            assert!(portfolio_index == position_portfolio_index, error::portfolio_index_mismatched());
            let (is_realized, is_profit, realized_usd, new_side, new_size, average_price) = calculate_filled_(
                &position,
                // order related parameters
                reduce_only,
                is_long,
                size,
                // price
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
            );
            let filled_size = if (new_side == original_side) {
                if (new_size >= original_size) {
                    new_size - original_size
                } else {
                    original_size - new_size
                }
            } else {
                new_size + original_size
            };

            let original_collateral
                = dynamic_field::borrow<String, vector<TypusBidReceipt>>(&position.id, string::utf8(K_COLLATERAL));
            let collateral_amount_from_original_collateral = calculate_intrinsic_value<C_TOKEN>(dov_registry, typus_oracle_trading_symbol, typus_oracle_c_token, original_collateral, clock);
            let new_collateral_amount = collateral_amount_from_original_collateral + collateral_amount;

            update_position_borrow_rate_and_funding_rate(
                &mut position,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
                cumulative_borrow_rate,
                cumulative_funding_rate_index_sign,
                cumulative_funding_rate_index,
            );
            let reserve_amount = calculate_reserve_amount(
                position.size,
                position.size_decimal,
                new_collateral_amount,
                position.collateral_token_decimal,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
            );
            position.update_ts_ms = clock.timestamp_ms();
            position.is_long = new_side;
            position.size = new_size;
            position.average_price = average_price;
            position.reserve_amount = reserve_amount;
            position.collateral_amount = new_collateral_amount;
            position.unrealized_trading_fee = position.unrealized_trading_fee + fee_in_d_token;
            // position.unrealized_rebate = position.unrealized_rebate + rebate;
            (position, is_realized, is_profit, realized_usd, filled_size)
        } else {
            let reserve_amount = calculate_reserve_amount(
                size,
                size_decimal,
                collateral_amount,
                collateral_token_decimal,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
            );
            let mut bid_receipts_bcs = vector::empty<vector<u8>>();
            let receipts = bid_receipts.borrow();
            receipts.do_ref!(|receipt|{
                bid_receipts_bcs.push_back(bcs::to_bytes(receipt));
            });
            let mut position = Position {
                id: object::new(ctx),
                create_ts_ms: clock.timestamp_ms(),
                update_ts_ms: clock.timestamp_ms(),
                position_id: next_position_id,
                linked_order_ids: vector::empty(),
                linked_order_prices: vector::empty(),
                user,
                is_long,
                size,
                size_decimal,
                collateral_token: deposit_token, // D_TOKEN
                collateral_token_decimal,
                symbol,
                collateral_amount,// receipts collateral in D_TOKEN
                reserve_amount, // position.size in D_TOKEN unit
                average_price: trading_pair_oracle_price,
                entry_borrow_index: cumulative_borrow_rate,
                unrealized_loss: 0,
                entry_funding_rate_index_sign: cumulative_funding_rate_index_sign,
                entry_funding_rate_index: cumulative_funding_rate_index,
                unrealized_funding_sign: true,
                unrealized_funding_fee: 0,
                unrealized_trading_fee: fee_in_d_token,
                unrealized_borrow_fee: 0,
                unrealized_rebate: 0, // rebate,
                option_collateral_info: option::some(OptionCollateralInfo {
                    index: portfolio_index,
                    bid_token: type_name::with_defining_ids<B_TOKEN>(),
                    bid_receipts_bcs,
                }),
                u64_padding: vector::empty(),
            };
            dynamic_field::add(&mut position.id, string::utf8(K_COLLATERAL), vector::empty<TypusBidReceipt>());
            (position, false, false, 0, size)
        };
        // convert realized_usd from USD to C_TOKEN
        let realized_amount = usd_to_amount(realized_usd, position.collateral_token_decimal, collateral_oracle_price, collateral_oracle_price_decimal);
        if (is_realized && !is_profit) {
            position.unrealized_loss = position.unrealized_loss + realized_amount; // realized loss been put in the field
        };
        let mut realized_profit = if (is_realized && is_profit) {
            lp_pool::request_collateral<C_TOKEN>(
                liquidity_pool,
                realized_amount,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
            )
        } else { balance::zero<C_TOKEN>() };

        let realized_profit_value = realized_profit.value();
        let realized_loss_balance = realized_profit.split(
            if (position.unrealized_loss > realized_profit_value) {
                realized_profit_value
            } else {
                position.unrealized_loss
            }
        );
        position.unrealized_loss = position.unrealized_loss - realized_loss_balance.value();

        let realized_profit_value = realized_profit.value();
        let mut realized_trading_fee_balance = realized_profit.split(
            if (position.unrealized_trading_fee > realized_profit_value) {
                realized_profit_value
            } else {
                position.unrealized_trading_fee
            }
        );
        let realized_trading_fee = realized_trading_fee_balance.value();
        position.unrealized_trading_fee = position.unrealized_trading_fee - realized_trading_fee_balance.value();
        let realized_borrow_fee_balance = realized_profit.split(
            if (position.unrealized_borrow_fee > realized_profit_value) {
                realized_profit_value
            } else {
                position.unrealized_borrow_fee
            }
        );
        position.unrealized_borrow_fee = position.unrealized_borrow_fee - realized_borrow_fee_balance.value();
        let realized_borrow_fee = realized_borrow_fee_balance.value();

        realized_trading_fee_balance.join(realized_borrow_fee_balance);

        let realized_profit_value = realized_profit.value();
        let realized_rebate_balance = realized_profit.split(
            if (position.unrealized_rebate > realized_profit_value) {
                realized_profit_value
            } else {
                position.unrealized_rebate
            }
        );
        position.unrealized_rebate = position.unrealized_rebate - realized_rebate_balance.value();

        if (bid_receipts.is_some()) {
            let collateral
                = dynamic_field::borrow_mut<String, vector<TypusBidReceipt>>(&mut position.id, string::utf8(K_COLLATERAL));
            collateral.append(bid_receipts.extract());
            bid_receipts.destroy_none();
        } else {
            bid_receipts.destroy_none();
        };

        let realized_fee_in_usd = amount_to_usd(
            realized_trading_fee + realized_borrow_fee,
            position.collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );

        let filled_size_in_usd = amount_to_usd(
            filled_size,
            size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal
        );

        competition::add_score(
            version,
            ecosystem_version,
            typus_leaderboard_registry,
            tails_staking_registry,
            competition_config,
            filled_size_in_usd,
            user,
            clock,
            ctx,
        );

        emit(OrderFilledEvent {
            user,
            collateral_token: position.collateral_token,
            symbol,
            order_id,
            linked_position_id, // none -> new open -> new_position_id should not be none
            new_position_id: if (position.size != 0) { option::some(position.position_id) } else { option::none() }, // none -> flatten
            filled_size,
            filled_price: trading_pair_oracle_price,
            position_side: position.is_long,
            position_size: position.size,
            position_average_price: position.average_price,
            realized_trading_fee,
            realized_borrow_fee,
            realized_fee_in_usd,
            realized_amount,
            realized_amount_sign: is_profit,
            u64_padding: vector[if (is_long) { 1 } else { 0 }] // order.is_long
        });

        object::delete(id);
        option::destroy_none(original_position);
        (
            position,
            realized_loss_balance,
            realized_trading_fee_balance, // trading fee + borrow fee merged
            realized_rebate_balance,
            realized_profit,
            trading_fee_usd
        )
    }

    public(package) fun check_option_collateral_position_liquidated<C_TOKEN>(
        dov_registry: &DovRegistry,
        typus_oracle_trading_symbol: &Oracle,
        typus_oracle_c_token: &Oracle,
        position: &Position,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
        maintenance_margin_rate_bp: u64,
        cumulative_borrow_rate: u64,
        cumulative_funding_rate_index_sign: bool,
        cumulative_funding_rate_index: u64,
        clock: &Clock
    ): bool {
        let (unrealized_funding_sign, unrealized_funding_fee) = calculate_position_funding_rate(
            position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_funding_rate_index_sign,
            cumulative_funding_rate_index,
        );
        let unrealized_funding_fee_usd
            = amount_to_usd(unrealized_funding_fee, position.collateral_token_decimal, collateral_oracle_price, collateral_oracle_price_decimal);

        let collateral_amount = {
            let receipts = dynamic_field::borrow<String, vector<TypusBidReceipt>>(&position.id, string::utf8(K_COLLATERAL));
            let collateral_amount = calculate_intrinsic_value<C_TOKEN>(dov_registry, typus_oracle_trading_symbol, typus_oracle_c_token, receipts, clock);
            collateral_amount
        };

        let collateral_usd = amount_to_usd(
            collateral_amount,
            position.collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );

        let (has_profit, pnl_usd, _) = calculate_unrealized_pnl(
            position,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp
        );

        // borrow fee & unpaid trading fee
        let (reserve_usd, period_borrow_cost) = calculate_period_borrow_cost(
            position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate
        );
        let unrealized_cost_in_usd = amount_to_usd(
            position.unrealized_loss + position.unrealized_trading_fee + position.unrealized_borrow_fee + period_borrow_cost,
            position.collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );

        let maintenance_margin = ((maintenance_margin_rate_bp as u128) * (reserve_usd as u128) / (math::get_bp_scale() as u128) as u64);

        let remaining_collateral_usd = if (unrealized_funding_sign) {
            if (has_profit) {
                if (collateral_usd + pnl_usd > unrealized_cost_in_usd + unrealized_funding_fee_usd) {
                    collateral_usd + pnl_usd - unrealized_cost_in_usd - unrealized_funding_fee_usd
                } else { 0 }
            } else {
                if (collateral_usd > pnl_usd + unrealized_cost_in_usd + unrealized_funding_fee_usd) {
                    collateral_usd - pnl_usd - unrealized_cost_in_usd - unrealized_funding_fee_usd
                } else { 0 }
            }
        } else {
            if (has_profit) {
                if (collateral_usd + unrealized_funding_fee_usd + pnl_usd > unrealized_cost_in_usd) {
                    collateral_usd + unrealized_funding_fee_usd + pnl_usd - unrealized_cost_in_usd
                } else { 0 }
            } else {
                if (collateral_usd + unrealized_funding_fee_usd > pnl_usd + unrealized_cost_in_usd) {
                    collateral_usd + unrealized_funding_fee_usd - pnl_usd - unrealized_cost_in_usd
                } else { 0 }
            }
        };
        remaining_collateral_usd <= maintenance_margin
    }

    /// Adds linked order info to a position.
    /// WARNING: no authority check inside
    public(package) fun add_position_linked_order_info(
        position: &mut Position,
        linked_order_id: u64,
        linked_order_price: u64,
    ) {
        position.linked_order_ids.push_back(linked_order_id);
        position.linked_order_prices.push_back(linked_order_price);
        assert!(position.linked_order_ids.length() <= C_MAX_LINKED_ORDER_AMOUNT, error::too_many_linked_orders());
    }

    /// Removes linked order info from a position.
    /// WARNING: no authority check inside
    public(package) fun remove_position_linked_order_info(
        position: &mut Position,
        linked_order_id: u64,
    ) {
        let (exists, index) = position.linked_order_ids.index_of(&linked_order_id);
        assert!(exists, error::linked_order_id_not_existed());
        position.linked_order_ids.remove(index);
        position.linked_order_prices.remove(index);
    }

    /// Updates the borrow rate and funding rate of a position.
    /// WARNING: no authority check inside
    public(package) fun update_position_borrow_rate_and_funding_rate(
        position: &mut Position,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        cumulative_borrow_rate: u64,
        cumulative_funding_rate_index_sign: bool,
        cumulative_funding_rate_index: u64
    ): (u64, bool, u64) {
        let (_reserve_usd, period_borrow_cost) = calculate_period_borrow_cost(
            position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate
        );
        position.unrealized_borrow_fee = position.unrealized_borrow_fee + period_borrow_cost;
        position.entry_borrow_index = cumulative_borrow_rate;

        let (unrealized_funding_sign, unrealized_funding_fee) = calculate_position_funding_rate(
            position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_funding_rate_index_sign,
            cumulative_funding_rate_index,
        );
        position.unrealized_funding_sign = unrealized_funding_sign;
        position.unrealized_funding_fee = unrealized_funding_fee;
        position.entry_funding_rate_index_sign = cumulative_funding_rate_index_sign;
        position.entry_funding_rate_index = cumulative_funding_rate_index;

        (position.unrealized_borrow_fee, unrealized_funding_sign, unrealized_funding_fee)
    }

    // only token collateral positions can use this
    // input funding_income from lp pool, and return balance for funding payout
    /// An event that is emitted when a funding fee is realized.
    public struct RealizeFundingEvent has copy, drop {
        user: address,
        collateral_token: TypeName,
        symbol: Symbol,
        position_id: u64,
        realized_funding_sign: bool, // true => user paid to pool
        realized_funding_fee: u64,
        realized_funding_fee_usd: u64,
        u64_padding: vector<u64>
    }

    /// Updates the collateral amount of an option position.
    /// WARNING: no authority check inside
    public(package) fun update_option_position_collateral_amount<C_TOKEN>(
        dov_registry: &DovRegistry,
        typus_oracle_trading_symbol: &Oracle,
        typus_oracle_c_token: &Oracle,
        position: &mut Position,
        clock: &Clock
    ) {
        let receipts = dynamic_field::borrow(&position.id, string::utf8(K_COLLATERAL));
        position.collateral_amount = calculate_intrinsic_value<C_TOKEN>(dov_registry, typus_oracle_trading_symbol, typus_oracle_c_token, receipts, clock);
    }

    fun calculate_realized_pnl_usd(
        side: bool, // position side
        size: u64, // realized size
        entry_price: u64,
        exit_price: u64,
        size_decimal: u64,
        price_decimal: u64,
    ): (bool, u64) {
        let is_profit = if (side) {
            exit_price > entry_price
        } else {
            exit_price < entry_price
        };
        let (d_price) = if (exit_price > entry_price) {
            exit_price - entry_price
        } else {
            entry_price - exit_price
        };
        let mut pnl_usd = ((size as u128)
                            * (d_price as u128)
                                / (math::multiplier(size_decimal) as u128) as u64);
        pnl_usd = ((pnl_usd as u128)
                    * (math::multiplier(math::get_usd_decimal()) as u128)
                        / (math::multiplier(price_decimal) as u128) as u64);
        (is_profit, pnl_usd)
    }

    fun calculate_filled_(
        position: &Position,
        // order related parameters
        reduce_only: bool,
        order_side: bool,
        order_size: u64,
        // price
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
    ): (bool, bool, u64, bool, u64, u64) {
        let mut is_realized = false;
        let (mut is_profit, mut realized_amount) = (false, 0);
        let (new_side, new_size, average_price) = if (order_side) {
            if (position.is_long) {
                // add long position
                assert!(!reduce_only, error::not_reduce_only_execution());
                let original_position_value = (position.average_price as u128) * (position.size as u128);
                let added_position_value = (trading_pair_oracle_price as u128) * (order_size as u128);
                let new_size = position.size + order_size;
                let mut new_average_price = ((original_position_value + added_position_value)
                                                / (new_size as u128) as u64);
                // ceil
                if ((original_position_value + added_position_value) > (new_average_price as u128) * (new_size as u128)) {
                    new_average_price = new_average_price + 1;
                };
                (true, new_size, new_average_price)
            } else {
                if (reduce_only || (!reduce_only && order_size <= position.size)) {
                    is_realized = true;
                    let filled_size = if (order_size > position.size) { position.size } else { order_size };
                    (is_profit, realized_amount) = calculate_realized_pnl_usd(
                        position.is_long,
                        filled_size,
                        position.average_price,
                        trading_pair_oracle_price,
                        position.size_decimal,
                        trading_pair_oracle_price_decimal
                    );
                    (false, position.size - filled_size, position.average_price)
                } else {
                    // flip to long
                    is_realized = true;
                    (is_profit, realized_amount) = calculate_realized_pnl_usd(
                        position.is_long,
                        position.size,
                        position.average_price,
                        trading_pair_oracle_price,
                        position.size_decimal,
                        trading_pair_oracle_price_decimal
                    );
                    (true, order_size - position.size, trading_pair_oracle_price)
                }
            }
        } else {
            if (!position.is_long) {
                // add short position
                assert!(!reduce_only, error::not_reduce_only_execution());
                let original_position_value = (position.average_price as u128) * (position.size as u128);
                let added_position_value = (trading_pair_oracle_price as u128) * (order_size as u128);
                let new_average_price = ((original_position_value + added_position_value)
                    / ((position.size + order_size) as u128) as u64);
                (false, position.size + order_size, new_average_price)
            } else {
                if (reduce_only || (!reduce_only && order_size <= position.size)) {
                    is_realized = true;
                    let filled_size = if (order_size > position.size) { position.size } else { order_size };
                    (is_profit, realized_amount) = calculate_realized_pnl_usd(
                        position.is_long,
                        filled_size,
                        position.average_price,
                        trading_pair_oracle_price,
                        position.size_decimal,
                        trading_pair_oracle_price_decimal
                    );
                    (true, position.size - filled_size, position.average_price)
                } else {
                    // flip to short
                    is_realized = true;
                    (is_profit, realized_amount) = calculate_realized_pnl_usd(
                        position.is_long,
                        position.size,
                        position.average_price,
                        trading_pair_oracle_price,
                        position.size_decimal,
                        trading_pair_oracle_price_decimal
                    );
                    (false, order_size - position.size, trading_pair_oracle_price)
                }
            }
        };
        (is_realized, is_profit, realized_amount, new_side, new_size, average_price)
    }

    fun calculate_intrinsic_value<C_TOKEN>(
        dov_registry: &DovRegistry,
        typus_oracle_trading_symbol: &Oracle,
        typus_oracle_c_token: &Oracle,
        receipts: &vector<TypusBidReceipt>,
        clock: &Clock
    ): u64 {
        let length = receipts.length();
        let mut i = 0;
        let mut collateral_amount = 0;
        while (i < length) {
            collateral_amount = collateral_amount + typus_dov_single::get_bid_receipt_intrinsic_value_v2<C_TOKEN>(
                dov_registry,
                typus_oracle_trading_symbol,
                typus_oracle_c_token,
                &receipts[i],
                clock
            );
            i = i + 1;
        };
        collateral_amount
    }

    fun collateral_with_pnl(
        position: &Position,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
    ): u64 {
        let collateral_usd = amount_to_usd(
            position.collateral_amount,
            position.collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );

        let (has_profit, pnl_usd, _) = calculate_unrealized_pnl(
            position,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
        );

        if (has_profit) {
            collateral_usd + pnl_usd
        } else {
            if (collateral_usd > pnl_usd) {
                collateral_usd - pnl_usd
            } else {
                0
            }
        }
    }

    fun calculate_position_funding_rate(
        position: &Position,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        cumulative_funding_rate_index_sign: bool,
        cumulative_funding_rate_index: u64
    ): (bool, u64) {
        let notional_size_usd
            = amount_to_usd(position.size, position.size_decimal, trading_pair_oracle_price, trading_pair_oracle_price_decimal);
        let notional_size_in_c_token
            = usd_to_amount(notional_size_usd, position.collateral_token_decimal, collateral_oracle_price, collateral_oracle_price_decimal);

        let (d_index_side, d_funding_rate) = if (cumulative_funding_rate_index_sign && position.entry_funding_rate_index_sign) {
            if (cumulative_funding_rate_index > position.entry_funding_rate_index) {
                (true, cumulative_funding_rate_index - position.entry_funding_rate_index)
            } else {
                (false, position.entry_funding_rate_index - cumulative_funding_rate_index)
            }
        } else if (cumulative_funding_rate_index_sign && !position.entry_funding_rate_index_sign) {
            (true, cumulative_funding_rate_index + position.entry_funding_rate_index)
        } else if (!cumulative_funding_rate_index_sign && position.entry_funding_rate_index_sign) {
            (false, cumulative_funding_rate_index + position.entry_funding_rate_index)
        } else {
            if (cumulative_funding_rate_index > position.entry_funding_rate_index) {
                (false, cumulative_funding_rate_index - position.entry_funding_rate_index)
            } else {
                (true, position.entry_funding_rate_index - cumulative_funding_rate_index)
            }
        };
        let period_funding_fee = ((notional_size_in_c_token as u128)
                                    * (d_funding_rate as u128)
                                        / (math::multiplier(math::get_funding_rate_decimal()) as u128) as u64);
        let mut unrealized_funding_sign = position.unrealized_funding_sign;
        let mut unrealized_funding_fee = position.unrealized_funding_fee;
        if (position.is_long) {
            if (d_index_side) {
                // long position with unrealized funding cost, add funding index (pay more)
                if (unrealized_funding_sign) {
                    unrealized_funding_fee = unrealized_funding_fee + period_funding_fee;
                // long position with unrealized funding income, add funding index (receive less)
                } else {
                    // flip to "funding cost" side
                    if (period_funding_fee > unrealized_funding_fee) {
                        unrealized_funding_sign = true;
                        unrealized_funding_fee = period_funding_fee - unrealized_funding_fee;
                    } else {
                        unrealized_funding_fee = unrealized_funding_fee - period_funding_fee;
                    };
                };
            } else {
                // long position with unrealized funding cost, reduce funding index (pay less)
                if (unrealized_funding_sign) {
                    // flip to "funding income" side
                    if (period_funding_fee > unrealized_funding_fee) {
                        unrealized_funding_sign = false;
                        unrealized_funding_fee = period_funding_fee - unrealized_funding_fee;
                    } else {
                        unrealized_funding_fee = unrealized_funding_fee - period_funding_fee;
                    };
                // long position with unrealized funding income, reduce funding index (receive more)
                } else {
                    unrealized_funding_fee = unrealized_funding_fee + period_funding_fee;
                };
            };
        } else {
            if (d_index_side) {
                // short position with unrealized funding cost, add funding index (pay less)
                if (unrealized_funding_sign) {
                    // flip to "funding income" side
                    if (period_funding_fee > unrealized_funding_fee) {
                        unrealized_funding_sign = false;
                        unrealized_funding_fee = period_funding_fee - unrealized_funding_fee;
                    } else {
                        unrealized_funding_fee = unrealized_funding_fee - period_funding_fee;
                    };
                // short position with unrealized funding income, add funding index (receive more)
                } else {
                    unrealized_funding_fee = unrealized_funding_fee + period_funding_fee;
                };
            } else {
                // short position with unrealized funding cost, reduce funding index (pay more)
                if (unrealized_funding_sign) {
                    unrealized_funding_fee = unrealized_funding_fee + period_funding_fee;
                // short position with unrealized funding income, reduce funding index (receive less)
                } else {
                    // flip to "funding cost" side
                    if (period_funding_fee > unrealized_funding_fee) {
                        unrealized_funding_sign = true;
                        unrealized_funding_fee = period_funding_fee - unrealized_funding_fee;
                    } else {
                        unrealized_funding_fee = unrealized_funding_fee - period_funding_fee;
                    };
                };
            };
        };
        (unrealized_funding_sign, unrealized_funding_fee)
    }

    fun calculate_reserve_amount(
        new_size: u64,
        size_decimal: u64,
        collateral_amount: u64,
        collateral_token_decimal: u64,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
    ): u64 {
        let notional_size_usd = amount_to_usd(
            new_size,
            size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal
        );
        let reserve_amount = usd_to_amount(
            notional_size_usd,
            collateral_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );

        if (collateral_amount >= reserve_amount) {
            0
        } else {
            reserve_amount - collateral_amount
        }
    }

    // ======= Helper Functions =======
    public(package) fun is_option_collateral_order(
        order: &TradingOrder
    ): bool {
        dynamic_field::exists_(&order.id, string::utf8(K_DEPOSIT_TOKEN))
    }

    public(package) fun get_order_collateral_token(
        order: &TradingOrder
    ): TypeName {
        if (is_option_collateral_order(order)) {
            *dynamic_field::borrow(&order.id, string::utf8(K_DEPOSIT_TOKEN))
        } else {
            order.collateral_token
        }
    }

    public(package) fun get_order_collateral_token_decimal(
        order: &TradingOrder
    ): u64 {
        order.collateral_token_decimal
    }

    // public(package) fun get_order_portfolio_index(
    //     order: &TradingOrder
    // ): u64 {
    //     if (is_option_collateral_order(order)) {
    //         *dynamic_field::borrow(&order.id, string::utf8(K_PORTFOLIO_INDEX))
    //     } else {
    //         error::not_option_collateral_order()
    //     }
    // }

    public(package) fun get_order_trading_symbol(
        order: &TradingOrder
    ): (TypeName, TypeName) {
        (order.symbol.base_token(), order.symbol.quote_token())
    }

    public(package) fun get_order_price(
        order: &TradingOrder,
    ): u64 {
        order.trigger_price
    }

    public(package) fun get_order_user(
        order: &TradingOrder,
    ): address {
        order.user
    }

    public(package) fun get_order_id(
        order: &TradingOrder,
    ): u64 {
        order.order_id
    }

    public(package) fun get_order_size(
        order: &TradingOrder,
    ): u64 {
        order.size
    }

    public(package) fun get_order_side(
        order: &TradingOrder,
    ): bool {
        order.is_long
    }

    public(package) fun get_order_reduce_only(
        order: &TradingOrder,
    ): bool {
        order.reduce_only
    }

    public(package) fun get_order_linked_position_id(
        order: &TradingOrder,
    ): Option<u64> {
        order.linked_position_id
    }

    public(package) fun get_order_type_tag(
        order: &TradingOrder,
    ): u8 {
        if (order.is_long && !order.is_stop_order) { return 0 }
        else if (!order.is_long && !order.is_stop_order) { return 1 }
        else if (order.is_long && order.is_stop_order) { return 2 }
        else if (!order.is_long && order.is_stop_order) { return 3 };
        return 255 // unsupported order type tag
    }

    public(package) fun get_order_collateral_amount<C_TOKEN>(
        order: &TradingOrder,
    ): u64 {
        if (dynamic_field::exists_with_type<String, Balance<C_TOKEN>>(&order.id, string::utf8(K_COLLATERAL))) {
            let balance = dynamic_field::borrow<String, Balance<C_TOKEN>>(&order.id, string::utf8(K_COLLATERAL));
            balance.value()
        } else {
            0
        }
    }

    public(package) fun get_option_collateral_order_collateral_amount<C_TOKEN>(
        dov_registry: &DovRegistry,
        typus_oracle_trading_symbol: &Oracle,
        typus_oracle_c_token: &Oracle,
        order: &TradingOrder,
        clock: &Clock
    ): u64 {
        if (dynamic_field::exists_with_type<String, vector<TypusBidReceipt>>(&order.id, string::utf8(K_COLLATERAL))) {
            let receipts = dynamic_field::borrow<String, vector<TypusBidReceipt>>(&order.id, string::utf8(K_COLLATERAL));
            let collateral_amount = calculate_intrinsic_value<C_TOKEN>(dov_registry, typus_oracle_trading_symbol, typus_oracle_c_token, receipts, clock);
            collateral_amount
        } else {
            0
        }
    }

    // fee in collateral token, fee in usd
    public(package) fun calculate_trading_fee(
        size: u64,
        size_decimal: u64,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
        collateral_token_decimal: u64,
    ): (u64, u64) {
        let filled_usd
                = amount_to_usd(size, size_decimal, trading_pair_oracle_price, trading_pair_oracle_price_decimal);
        let trading_fee_usd = ((filled_usd as u128) * (trading_fee_mbp as u128) / (math::get_mbp_scale() as u128) as u64);

        let fee_in_c_token
            = usd_to_amount(trading_fee_usd, collateral_token_decimal, collateral_oracle_price, collateral_oracle_price_decimal);
        (fee_in_c_token, trading_fee_usd)
    }

    public(package) fun split_bid_receipt(
        dov_registry: &mut DovRegistry,
        position: &mut Position,
        size: u64,
        ctx: &mut TxContext
    ): TypusBidReceipt {
        let bid_receipts = dynamic_field::remove<String, vector<TypusBidReceipt>>(&mut position.id, string::utf8(K_COLLATERAL));
        let share = option::some(size); // closed positon size
        let portfolio_index = position.option_collateral_info.borrow().index;
        let (split_receipt, remain_receipt, _log) = tds_user_entry::simple_split_bid_receipt(dov_registry, portfolio_index, bid_receipts, share, ctx);
        // store remain_receipt in position
        dynamic_field::add<String, vector<TypusBidReceipt>>(&mut position.id, string::utf8(K_COLLATERAL), vector[option::destroy_some(remain_receipt)]);
        // return split_receipt to user
        option::destroy_some(split_receipt)
    }

    public(package) fun is_option_collateral_position(
        position: &Position
    ): bool {
        position.option_collateral_info.is_some()
    }

    public(package) fun emit_realized_funding_event(
        user: address,
        collateral_token: TypeName,
        symbol: Symbol,
        position_id: u64,
        realized_funding_sign: bool,
        realized_funding_fee: u64,
        realized_funding_fee_usd: u64,
        u64_padding: vector<u64>,
    ) {
        emit(RealizeFundingEvent {
            user,
            collateral_token,
            symbol,
            position_id,
            realized_funding_sign,
            realized_funding_fee,
            realized_funding_fee_usd,
            u64_padding,
        });
    }

    public(package) fun check_position_update_timestamp(
        position: &Position,
        clock: &Clock,
        threshold_ts_ms: u64
    ) {
        assert!(check_position_update_timestamp_(position, clock, threshold_ts_ms), error::position_cool_down_threshold());
    }

    public(package) fun check_position_update_timestamp_(
        position: &Position,
        clock: &Clock,
        threshold_ts_ms: u64
    ): bool {
        clock.timestamp_ms() >= position.update_ts_ms + threshold_ts_ms
    }

    public(package) fun get_position_id(
        position: &Position,
    ): u64 {
        position.position_id
    }

    public(package) fun get_position_size(
        position: &Position,
    ): u64 {
        position.size
    }

    public(package) fun get_position_side(
        position: &Position,
    ): bool {
        position.is_long
    }

    public(package) fun get_position_user(
        position: &Position,
    ): address {
        position.user
    }

    public(package) fun get_position_symbol(
        position: &Position,
    ): Symbol {
        position.symbol
    }

    public(package) fun get_position_option_collateral_info(
        position: &Position,
    ): (u64, TypeName) {
        let option_collateral_info = position.option_collateral_info.borrow();
        (option_collateral_info.index, option_collateral_info.bid_token)
    }

    public(package) fun get_reserve_amount(
        position: &Position,
    ): u64 {
        position.reserve_amount
    }

    public(package) fun get_position_size_decimal(
        position: &Position,
    ): u64 {
        position.size_decimal
    }

    public(package) fun get_position_collateral_token_decimal(
        position: &Position,
    ): u64 {
        position.collateral_token_decimal
    }

    public(package) fun calculate_unrealized_cost(
        position: &Position
    ): (bool, u64) {
        let cost = position.unrealized_loss + position.unrealized_trading_fee + position.unrealized_borrow_fee;
        if (position.unrealized_funding_sign) {
            (true, cost + position.unrealized_funding_fee)
        } else {
            if (cost > position.unrealized_funding_fee) {
                (true, cost - position.unrealized_funding_fee)
            } else {
                (false, position.unrealized_funding_fee - cost)
            }
        }
    }

    public(package) fun get_position_linked_order_ids(
        position: &Position,
    ): vector<u64> {
        position.linked_order_ids
    }

    public(package) fun get_position_collateral_token_type(
        position: &Position,
    ): TypeName {
        position.collateral_token
    }

    public(package) fun get_position_collateral_amount<C_TOKEN>(
        position: &Position,
    ): u64 {
        assert!(!is_option_collateral_position(position), error::not_token_collateral_position());
        let balance = dynamic_field::borrow<String, Balance<C_TOKEN>>(&position.id, string::utf8(K_COLLATERAL));
        balance.value()
    }

    public(package) fun get_option_position_collateral_amount<C_TOKEN>(
        dov_registry: &DovRegistry,
        typus_oracle_trading_symbol: &Oracle,
        typus_oracle_c_token: &Oracle,
        position: &Position,
        clock: &Clock
    ): u64 {
        assert!(is_option_collateral_position(position), error::not_option_collateral_position());
        let receipts = dynamic_field::borrow<String, vector<TypusBidReceipt>>(&position.id, string::utf8(K_COLLATERAL));
        let collateral_amount = calculate_intrinsic_value<C_TOKEN>(dov_registry, typus_oracle_trading_symbol, typus_oracle_c_token, receipts, clock);
        collateral_amount
    }

    public(package) fun option_position_bid_receipts_expired(
        dov_registry: &DovRegistry,
        position: &Position,
    ): bool {
        let mut expired = true;
        let receipts = dynamic_field::borrow<String, vector<TypusBidReceipt>>(&position.id, string::utf8(K_COLLATERAL));
        receipts.do_ref!(|receipt| {
            if (!typus_dov_single::check_bid_receipt_expired(dov_registry, receipt)) {
                expired = false;
            }
        });
        expired
    }

    public(package) fun get_option_position_exercise_value<C_TOKEN>(
        dov_registry: &DovRegistry,
        typus_oracle_trading_symbol: &Oracle,
        typus_oracle_c_token: &Oracle,
        position: &Position,
        clock: &Clock
    ): u64 {
        let receipts = dynamic_field::borrow<String, vector<TypusBidReceipt>>(&position.id, string::utf8(K_COLLATERAL));
        let length = receipts.length();
        let mut i = 0;
        let mut collateral_amount = 0;
        while (i < length) {
            let is_expired = typus_dov_single::check_bid_receipt_expired(
                dov_registry,
                &receipts[i],
            );
            if (is_expired) {
                collateral_amount = collateral_amount + typus_dov_single::get_bid_receipt_intrinsic_value_v2<C_TOKEN>(
                    dov_registry,
                    typus_oracle_trading_symbol,
                    typus_oracle_c_token,
                    &receipts[i],
                    clock
                );
            };
            i = i + 1;
        };
        collateral_amount
    }

    public(package) fun get_max_order_type_tag(): u8 { C_MAX_ORDER_TYPE_TAG }
}