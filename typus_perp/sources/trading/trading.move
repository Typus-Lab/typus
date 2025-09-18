module typus_perp::trading {
    use std::type_name::{Self, TypeName};
    use std::string::{Self, String};

    use sui::bcs;
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::object_table::{Self, ObjectTable};
    use sui::vec_map::{Self, VecMap};

    use typus_perp::admin::{Self, Version};
    use typus_perp::competition::CompetitionConfig;
    use typus_perp::error;
    use typus_perp::escrow;
    use typus_perp::lp_pool::{Self, Registry as PoolRegistry, LiquidityPool, RemoveLiquidityTokenProcess};
    use typus_perp::math::{Self, amount_to_usd, usd_to_amount};
    use typus_perp::position::{Self, TradingOrder, Position};
    use typus_perp::symbol;
    use typus_perp::user_account::{Self, UserAccount, UserAccountCap};

    use typus_framework::vault::{Self, TypusBidReceipt};
    use typus_dov::typus_dov_single::{Self, Registry as DovRegistry};
    use typus_dov::tds_user_entry;
    use typus::keyed_big_vector::{Self, KeyedBigVector};
    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::linked_object_table::{LinkedObjectTable};
    use typus::tails_staking::TailsStakingRegistry;
    use typus::leaderboard::TypusLeaderboardRegistry;
    use typus::user::TypusUserRegistry;
    use typus_oracle::oracle::Oracle;

    // ======== Constants ========
    // const C_U64_MAX: u64 = 18446744073709551615;
    // const C_MAINTENANCE_MARGIN_RATE_BP: u64 = 150;
    // const C_OPTION_MAINTENANCE_MARGIN_RATE_BP: u64 = 50;
    const C_LIQUIDATOR_FEE_BP: u64 = 100;

    // Index to Trading Fee Config
    const I_BASE_TRADING_FEE_MBP: u64 = 0;
    const I_MAX_TRADING_FEE_MBP: u64 = 1;
    const I_ALLOCATED_LP_EXPOSURE_MBP: u64 = 2;

    // Index to MarketConfig.u64_padding
    const I_MAX_BUY_OPEN_INTEREST: u64 = 0;
    const I_MAX_SELL_OPEN_INTEREST: u64 = 1;
    const I_MAINTENANCE_MARGIN_RATE_BP: u64 = 2;
    const I_OPTION_COLLATERAL_MAINTENANCE_MARGIN_RATE_BP: u64 = 3;
    const I_OPTION_COLLATERAL_BASE_TRADING_FEE_MBP: u64 = 4;
    const I_OPTION_COLLATERAL_MAX_TRADING_FEE_MBP: u64 = 5;
    const I_OPTION_COLLATERAL_ALLOCATED_LP_EXPOSURE_MBP: u64 = 6;

    // ======== Dynamic Field Key ========
    const K_LIMIT_BUY_ORDERS: vector<u8> = b"limit_buy_orders";
    const K_LIMIT_SELL_ORDERS: vector<u8> = b"limit_sell_orders";
    const K_STOP_BUY_ORDERS: vector<u8> = b"stop_buy_orders";
    const K_STOP_SELL_ORDERS: vector<u8> = b"stop_sell_orders";
    // const K_REFERRAL: vector<u8> = b"referral";
    const K_USER_ACCOUNTS: vector<u8> = b"user_accounts";

    // ======== Structs ========

    #[allow(unused_field)]
    public struct MarketRegistry has key {
        id: UID,
        referral_registry: UID,
        markets: LinkedObjectTable<u64, Markets>,
        num_market: u64,
        u64_padding: vector<u64>,
    }

    public struct Markets has key, store {
        id: UID,
        index: u64,
        lp_token_type: TypeName,
        quote_token_type: TypeName,
        is_active: bool,
        protocol_fee_share_bp: u64,
        symbols: vector<TypeName>,
        symbol_markets: ObjectTable<TypeName, SymbolMarket>,
        u64_padding: vector<u64>,
        // df:
        // user_accounts: ObjectTable<address, UserAccount>
    }

    public struct SymbolMarket has key, store {
        id: UID,
        user_positions: KeyedBigVector, // KeyedBigVector of Position
        token_collateral_orders: UID,
        option_collateral_orders: UID,
        // limit_buy_orders, limit_sell_orders, stop_buy_orders, stop_sell_orders: VecMap<vector<TradingOrder>>,
        market_info: MarketInfo,
        market_config: MarketConfig,
    }

    public struct MarketInfo has copy, drop, store {
        is_active: bool,
        size_decimal: u64,
        user_long_position_size: u64,
        user_short_position_size: u64,
        next_position_id: u64,
        user_long_order_size: u64,
        user_short_order_size: u64,
        next_order_id: u64,
        last_funding_ts_ms: u64,
        cumulative_funding_rate_index_sign: bool, // true -> longs pay fee to shorts
        cumulative_funding_rate_index: u64,
        previous_last_funding_ts_ms: u64,
        previous_cumulative_funding_rate_index_sign: bool, // true -> longs pay fee to shorts
        previous_cumulative_funding_rate_index: u64,
        u64_padding: vector<u64>,
    }

    public struct MarketConfig has copy, drop, store {
        oracle_id: address,
        max_leverage_mbp: u64,
        option_collateral_max_leverage_mbp: u64,
        min_size: u64,
        lot_size: u64,
        trading_fee_config: vector<u64>,
        basic_funding_rate: u64,
        funding_interval_ts_ms: u64,
        exp_multiplier: u64,
        u64_padding: vector<u64>,
    }

    public struct USD has drop {}

    // public struct Referrals has key, store {
    //     id: UID,
    //     referrals: Table<address, ReferralInfo>,
    //     rebates: Table<TypeName, Table<address, u64>>,
    //     u64_padding: vector<u64>,
    // }

    // public struct ReferralInfo has store {
    //     invited_from: address,
    //     fee_rebate_bp: u64, // to the user who sends invitation
    //     fee_reduction_bp: u64, // to the user who was invited
    //     u64_padding: vector<u64>,
    // }

    // ======= Functions =======

    // fun init(ctx: &mut TxContext) {
    //     let registry = MarketRegistry {
    //         id: object::new(ctx),
    //         referral_registry: object::new(ctx),
    //         markets: linked_object_table::new<u64, Markets>(ctx),
    //         num_market: 0,
    //         u64_padding: vector::empty(),
    //     };
    //     // let referrals = Referrals {
    //     //     id: object::new(ctx),
    //     //     referrals: table::new(ctx),
    //     //     rebates: table::new(ctx),
    //     //     u64_padding: vector::empty(),
    //     // };
    //     // dynamic_object_field::add(&mut registry.referral_registry, string::utf8(K_REFERRAL), referrals);
    //     transfer::share_object(registry);
    // }

    public struct NewMarketsEvent has copy, drop {
        index: u64,
        lp_token_type: TypeName,
        quote_token_type: TypeName,
        protocol_fee_share_bp: u64,
        u64_padding: vector<u64>
    }
    entry fun new_markets<LP_TOKEN, QUOTE_TOKEN>(
        version: &Version,
        registry: &mut MarketRegistry,
        protocol_fee_share_bp: u64,
        ctx: &mut TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = Markets {
            id: object::new(ctx),
            index: registry.num_market,
            lp_token_type: type_name::get<LP_TOKEN>(),
            quote_token_type: type_name::get<QUOTE_TOKEN>(),
            is_active: true,
            protocol_fee_share_bp,
            symbols: vector::empty(),
            symbol_markets: object_table::new(ctx),
            u64_padding: vector::empty(),
        };

        emit(NewMarketsEvent {
            index: market.index,
            lp_token_type: market.lp_token_type,
            quote_token_type: market.quote_token_type,
            protocol_fee_share_bp,
            u64_padding: vector::empty()
        });

        registry.markets.push_back(registry.num_market, market);

        registry.num_market = registry.num_market + 1;
    }

    public struct AddTradingSymbolEvent has copy, drop {
        index: u64,
        base_token_type: TypeName,
        market_info: MarketInfo,
        market_config: MarketConfig,
        u64_padding: vector<u64>
    }
    entry fun add_trading_symbol<BASE_TOKEN>(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        // market info
        size_decimal: u64,
        // market config
        oracle: &Oracle,
        max_leverage_mbp: u64,
        option_collateral_max_leverage_mbp: u64,
        min_size: u64,
        lot_size: u64,
        trading_fee_config: vector<u64>,
        basic_funding_rate: u64,
        funding_interval_ts_ms: u64,
        exp_multiplier: u64,
        max_buy_open_interest: u64,
        max_sell_open_interest: u64,
        maintenance_margin_rate_bp: u64,
        option_maintenance_margin_rate_bp: u64,
        option_trading_fee_config: vector<u64>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow_mut(market_index);
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(!vector::contains(&market.symbols, &base_token), error::trading_symbol_existed());

        assert!(
            trading_fee_config[I_MAX_TRADING_FEE_MBP] >= trading_fee_config[I_BASE_TRADING_FEE_MBP],
            error::invalid_trading_fee_config()
        );

        // add into market.symbols
        vector::push_back(&mut market.symbols, base_token);

        // add into market.symbol_markets
        let market_info = MarketInfo {
            is_active: true,
            size_decimal,
            user_long_position_size: 0,
            user_short_position_size: 0,
            next_position_id: 0,
            user_long_order_size: 0,
            user_short_order_size: 0,
            next_order_id: 0,
            last_funding_ts_ms: clock::timestamp_ms(clock),
            cumulative_funding_rate_index_sign: true,
            cumulative_funding_rate_index: 0,
            previous_last_funding_ts_ms: clock::timestamp_ms(clock),
            previous_cumulative_funding_rate_index_sign: true,
            previous_cumulative_funding_rate_index: 0,
            u64_padding: vector::empty(),
        };
        let market_config = MarketConfig {
            oracle_id: object::id_address(oracle),
            max_leverage_mbp,
            option_collateral_max_leverage_mbp,
            min_size,
            lot_size,
            trading_fee_config,
            basic_funding_rate,
            funding_interval_ts_ms,
            exp_multiplier,
            u64_padding: vector[
                max_buy_open_interest,
                max_sell_open_interest,
                maintenance_margin_rate_bp,
                option_maintenance_margin_rate_bp,
                option_trading_fee_config[0],
                option_trading_fee_config[1],
                option_trading_fee_config[2],
            ],
        };
        let mut symbol_market = SymbolMarket {
            id: object::new(ctx),
            user_positions: keyed_big_vector::new<u64, Position>(1000, ctx),
            token_collateral_orders: object::new(ctx),
            option_collateral_orders: object::new(ctx),
            market_info,
            market_config,
        };
        dynamic_field::add(&mut symbol_market.token_collateral_orders, string::utf8(K_LIMIT_BUY_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
        dynamic_field::add(&mut symbol_market.token_collateral_orders, string::utf8(K_LIMIT_SELL_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
        dynamic_field::add(&mut symbol_market.token_collateral_orders, string::utf8(K_STOP_BUY_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
        dynamic_field::add(&mut symbol_market.token_collateral_orders, string::utf8(K_STOP_SELL_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
        dynamic_field::add(&mut symbol_market.option_collateral_orders, string::utf8(K_LIMIT_BUY_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
        dynamic_field::add(&mut symbol_market.option_collateral_orders, string::utf8(K_LIMIT_SELL_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
        dynamic_field::add(&mut symbol_market.option_collateral_orders, string::utf8(K_STOP_BUY_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
        dynamic_field::add(&mut symbol_market.option_collateral_orders, string::utf8(K_STOP_SELL_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());

        emit(AddTradingSymbolEvent {
            index: market_index,
            base_token_type: base_token,
            market_info: symbol_market.market_info,
            market_config: symbol_market.market_config,
            u64_padding: vector::empty()
        });

        object_table::add(&mut market.symbol_markets, base_token, symbol_market);
    }

    public struct UpdateProtocolFeeShareBpEvent has copy, drop {
        index: u64,
        previous_protocol_fee_share_bp: u64,
        new_protocol_fee_share_bp: u64,
        u64_padding: vector<u64>
    }
    entry fun update_protocol_fee_share_bp(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        protocol_fee_share_bp: u64,
        ctx: &TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow_mut(market_index);
        let previous_protocol_fee_share_bp = market.protocol_fee_share_bp;
        market.protocol_fee_share_bp = protocol_fee_share_bp;

        emit(UpdateProtocolFeeShareBpEvent {
            index: market_index,
            previous_protocol_fee_share_bp,
            new_protocol_fee_share_bp: market.protocol_fee_share_bp,
            u64_padding: vector::empty()
        });
    }

    public struct UpdateMarketConfigEvent has copy, drop {
        index: u64,
        base_token_type: TypeName,
        previous_market_config: MarketConfig,
        new_market_config: MarketConfig,
        u64_padding: vector<u64>
    }
    entry fun update_market_config<BASE_TOKEN>(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        // market config
        mut oracle_id: Option<address>,
        mut max_leverage_mbp: Option<u64>,
        mut option_collateral_max_leverage_mbp: Option<u64>,
        mut min_size: Option<u64>,
        mut lot_size: Option<u64>,
        mut trading_fee_config: Option<vector<u64>>,
        mut basic_funding_rate: Option<u64>,
        mut funding_interval_ts_ms: Option<u64>,
        mut exp_multiplier: Option<u64>,
        mut max_buy_open_interest: Option<u64>, // market_config.u64_padding[0]
        mut max_sell_open_interest: Option<u64>, // market_config.u64_padding[1]
        mut maintenance_margin_rate_bp: Option<u64>, // market_config.u64_padding[2]
        mut option_collateral_maintenance_margin_rate_bp: Option<u64>, // market_config.u64_padding[3]
        mut option_collateral_trading_fee_config: Option<vector<u64>>, // market_config.u64_padding[4 ~ 6]
        ctx: &TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow_mut(market_index);
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());

        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        if (option::is_some(&oracle_id)) {
            symbol_market.market_config.oracle_id = option::extract(&mut oracle_id);
        };
        if (option::is_some(&max_leverage_mbp)) {
            symbol_market.market_config.max_leverage_mbp = option::extract(&mut max_leverage_mbp);
        };
        if (option::is_some(&option_collateral_max_leverage_mbp)) {
            symbol_market.market_config.option_collateral_max_leverage_mbp = option::extract(&mut option_collateral_max_leverage_mbp);
        };
        let previous_market_config = symbol_market.market_config;
        if (option::is_some(&min_size)) {
            symbol_market.market_config.min_size = option::extract(&mut min_size);
        };
        if (option::is_some(&lot_size)) {
            symbol_market.market_config.lot_size = option::extract(&mut lot_size);
        };
        if (option::is_some(&trading_fee_config)) {
            symbol_market.market_config.trading_fee_config = option::extract(&mut trading_fee_config);
            assert!(
                symbol_market.market_config.trading_fee_config[I_MAX_TRADING_FEE_MBP]
                    >= symbol_market.market_config.trading_fee_config[I_BASE_TRADING_FEE_MBP],
                error::invalid_trading_fee_config()
            );
        };
        if (option::is_some(&basic_funding_rate)) {
            symbol_market.market_config.basic_funding_rate = option::extract(&mut basic_funding_rate);
        };
        if (option::is_some(&funding_interval_ts_ms)) {
            symbol_market.market_config.funding_interval_ts_ms = option::extract(&mut funding_interval_ts_ms);
        };
        if (option::is_some(&exp_multiplier)) {
            symbol_market.market_config.exp_multiplier = option::extract(&mut exp_multiplier);
        };
        if (option::is_some(&max_buy_open_interest)) {
            math::set_u64_vector_value(&mut symbol_market.market_config.u64_padding, I_MAX_BUY_OPEN_INTEREST, option::extract(&mut max_buy_open_interest));
        };
        if (option::is_some(&max_sell_open_interest)) {
            math::set_u64_vector_value(&mut symbol_market.market_config.u64_padding, I_MAX_SELL_OPEN_INTEREST, option::extract(&mut max_sell_open_interest));
        };
        if (option::is_some(&maintenance_margin_rate_bp)) {
            math::set_u64_vector_value(&mut symbol_market.market_config.u64_padding, I_MAINTENANCE_MARGIN_RATE_BP, option::extract(&mut maintenance_margin_rate_bp));
        };
        if (option::is_some(&option_collateral_maintenance_margin_rate_bp)) {
            math::set_u64_vector_value(&mut symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_MAINTENANCE_MARGIN_RATE_BP, option::extract(&mut option_collateral_maintenance_margin_rate_bp));
        };
        if (option::is_some(&option_collateral_trading_fee_config)) {
            let trading_fee_config = option::extract(&mut option_collateral_trading_fee_config);
            assert!(
                trading_fee_config[I_MAX_TRADING_FEE_MBP]
                    >= trading_fee_config[I_BASE_TRADING_FEE_MBP],
                error::invalid_trading_fee_config()
            );
            math::set_u64_vector_value(&mut symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_BASE_TRADING_FEE_MBP, trading_fee_config[I_BASE_TRADING_FEE_MBP]);
            math::set_u64_vector_value(&mut symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_MAX_TRADING_FEE_MBP, trading_fee_config[I_MAX_TRADING_FEE_MBP]);
            math::set_u64_vector_value(&mut symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_ALLOCATED_LP_EXPOSURE_MBP, trading_fee_config[I_ALLOCATED_LP_EXPOSURE_MBP]);
        };
        emit(UpdateMarketConfigEvent {
            index: market_index,
            base_token_type: base_token,
            previous_market_config,
            new_market_config: symbol_market.market_config,
            u64_padding: vector::empty()
        });
    }

    public struct SuspendMarketEvent has copy, drop {
        index: u64,
        u64_padding: vector<u64>
    }
    entry fun suspend_market(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        ctx: &TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);
        let market = registry.markets.borrow_mut(market_index);
        market.is_active = false;

        emit(SuspendMarketEvent {
            index: market_index,
            u64_padding: vector::empty()
        });
    }

    public struct ResumeMarketEvent has copy, drop {
        index: u64,
        u64_padding: vector<u64>
    }
    entry fun resume_market(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        ctx: &TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);
        let market = registry.markets.borrow_mut(market_index);
        market.is_active = true;

        emit(ResumeMarketEvent {
            index: market_index,
            u64_padding: vector::empty()
        });
    }

    public struct SuspendTradingSymbolEvent has copy, drop {
        index: u64,
        suspended_base_token: TypeName,
        u64_padding: vector<u64>
    }
    entry fun suspend_trading_symbol<BASE_TOKEN>(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        ctx: &TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.is_active, error::markets_inactive());

        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        symbol_market.market_info.is_active = false;

        emit(SuspendTradingSymbolEvent {
            index: market_index,
            suspended_base_token: base_token,
            u64_padding: vector::empty()
        });
    }

    public struct ResumeTradingSymbolEvent has copy, drop {
        index: u64,
        resumed_base_token: TypeName,
        u64_padding: vector<u64>
    }
    entry fun resume_trading_symbol<BASE_TOKEN>(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        ctx: &TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.is_active, error::markets_inactive());

        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        symbol_market.market_info.is_active = true;

        emit(ResumeTradingSymbolEvent {
            index: market_index,
            resumed_base_token: base_token,
            u64_padding: vector::empty()
        });
    }

    entry fun remove_trading_symbol<BASE_TOKEN>(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        ctx: &TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow_mut(market_index);
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let mut symbol_market = object_table::remove<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        assert!(!symbol_market.market_info.is_active, error::active_trading_symbol());
        assert!(
            symbol_market.market_info.user_long_order_size == 0
            && symbol_market.market_info.user_short_order_size == 0
            && symbol_market.market_info.user_long_position_size == 0
            && symbol_market.market_info.user_short_position_size == 0,
            error::order_or_position_size_not_zero()
        );

        let limit_buy = dynamic_field::remove<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.token_collateral_orders, string::utf8(K_LIMIT_BUY_ORDERS));
        let limit_sell = dynamic_field::remove<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.token_collateral_orders, string::utf8(K_LIMIT_SELL_ORDERS));
        let stop_buy = dynamic_field::remove<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.token_collateral_orders, string::utf8(K_STOP_BUY_ORDERS));
        let stop_sell = dynamic_field::remove<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.token_collateral_orders, string::utf8(K_STOP_SELL_ORDERS));
        let option_limit_buy = dynamic_field::remove<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.option_collateral_orders, string::utf8(K_LIMIT_BUY_ORDERS));
        let option_limit_sell = dynamic_field::remove<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.option_collateral_orders, string::utf8(K_LIMIT_SELL_ORDERS));
        let option_stop_buy = dynamic_field::remove<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.option_collateral_orders, string::utf8(K_STOP_BUY_ORDERS));
        let option_stop_sell = dynamic_field::remove<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.option_collateral_orders, string::utf8(K_STOP_SELL_ORDERS));
        limit_buy.destroy_empty();
        limit_sell.destroy_empty();
        stop_buy.destroy_empty();
        stop_sell.destroy_empty();
        option_limit_buy.destroy_empty();
        option_limit_sell.destroy_empty();
        option_stop_buy.destroy_empty();
        option_stop_sell.destroy_empty();

        let SymbolMarket {
            id,
            user_positions, // KeyedBigVector of Position
            token_collateral_orders,
            option_collateral_orders,
            // limit_buy_orders, limit_sell_orders, stop_buy_orders, stop_sell_orders: VecMap<vector<TradingOrder>>,
            market_info: _,
            market_config: _,
        } = symbol_market;

        object::delete(id);
        object::delete(token_collateral_orders);
        object::delete(option_collateral_orders);
        user_positions.destroy_empty();

        let (_, symbol_index) = market.symbols.index_of(&base_token);
        market.symbols.remove(symbol_index);
    }

    // public struct SetReferralEvent has copy, drop {
    //     user: address,
    //     invited_from: address,
    //     fee_rebate_bp: u64,         // to the user who sends invitation
    //     fee_reduction_bp: u64,      // to the user who was invited
    //     u64_padding: vector<u64>
    // }
    // entry fun set_referral(
    //     // for share objects
    //     version: &Version,
    //     registry: &mut MarketRegistry,
    //     // referral parameters
    //     invited_from: address,
    //     fee_rebate_bp: u64,         // to the user who sends invitation
    //     fee_reduction_bp: u64,      // to the user who was invited
    //     ctx: &TxContext,
    // ) {
    //     // user function
    //     let user = tx_context::sender(ctx);
    //     // safety check
    //     admin::version_check(version);

    //     let referrals = dynamic_object_field::borrow_mut<String, Referrals>(&mut registry.referral_registry, string::utf8(K_REFERRAL));

    //     // only update for the user who has not been referred
    //     if (!referrals.referrals.contains(invited_from)) {
    //         let referral_info = ReferralInfo {
    //             invited_from,
    //             fee_rebate_bp,
    //             fee_reduction_bp,
    //             u64_padding: vector::empty()
    //         };
    //         referrals.referrals.add(user, referral_info);
    //         emit(SetReferralEvent {
    //             user,
    //             invited_from,
    //             fee_rebate_bp,
    //             fee_reduction_bp,
    //             u64_padding: vector::empty()
    //         });
    //     };
    // }

    public struct CreateTradingOrderEvent has copy, drop {
        user: address,
        market_index: u64,
        pool_index: u64,
        collateral_token: TypeName,
        base_token: TypeName,
        order_id: u64,
        linked_position_id: Option<u64>,
        collateral_amount: u64,
        leverage_mbp: u64,
        reduce_only: bool,
        is_long: bool,
        is_stop_order: bool,
        size: u64,
        trigger_price: u64,
        filled: bool,
        filled_price: Option<u64>,
        u64_padding: vector<u64>
    }

    public fun create_trading_order_v2<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        // order parameters
        linked_position_id: Option<u64>,
        collateral: Coin<C_TOKEN>, // collateral_amount: u64,
        reduce_only: bool,
        is_long: bool,
        is_stop_order: bool,
        size: u64,
        trigger_price: u64,
        ctx: &mut TxContext,
    ) {
        // user function
        let user = tx_context::sender(ctx);
        // safety check
        admin::version_check(version);

        // let referrals = dynamic_object_field::borrow_mut<String, Referrals>(&mut registry.referral_registry, string::utf8(K_REFERRAL));

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.is_active, error::markets_inactive());
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());
        // allow reduce_only when token pool inactive
        if (!reduce_only) { lp_pool::check_token_pool_status<C_TOKEN>(pool_registry, pool_index, true); };
        if (reduce_only) { assert!(linked_position_id.is_some(), error::position_id_needed_with_reduce_only_order()); };

        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());
        assert!(
            symbol_market.market_info.is_active
                || (!symbol_market.market_info.is_active && reduce_only),
            error::trading_symbol_inactive()
        );

        lp_pool::update_borrow_info(version, pool_registry, pool_index, clock);

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let collateral = collateral.into_balance();
        let collateral_amount = balance::value(&collateral);
        let liquidity_token_decimal = lp_pool::get_liquidity_token_decimal(pool_registry, pool_index, type_name::get<C_TOKEN>());
        let collateral_usd = amount_to_usd(
            collateral_amount,
            liquidity_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );
        let order_size_usd = amount_to_usd(
            size,
            symbol_market.market_info.size_decimal,
            trigger_price, // use order price to calculate leverage
            trading_pair_oracle_price_decimal
        );
        let leverage_mbp = if (collateral_usd > 0) {
            let leverage_mbp = ((order_size_usd as u128) * 10000000 / (collateral_usd as u128) as u64);
            assert!(symbol_market.market_config.max_leverage_mbp >= leverage_mbp, error::exceed_max_leverage());
            leverage_mbp
        } else { 100 };
        assert!(
            if (reduce_only && linked_position_id.is_some()) {
                size % symbol_market.market_config.lot_size == 0
            } else {
                size >= symbol_market.market_config.min_size
                    && size % symbol_market.market_config.lot_size == 0
            },
            error::invalid_order_size()
        );

        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
        let collateral_token = type_name::get<C_TOKEN>();
        liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));
        let mut reserve_amount
            = usd_to_amount(order_size_usd, liquidity_token_decimal, collateral_oracle_price, collateral_oracle_price_decimal);
        let linked_position_collateral_amount = if (linked_position_id.is_some()) {
            let position_id = *linked_position_id.borrow();
            let position: &Position = &symbol_market.user_positions[position_id];
            // TODO: check linked_position_id.is_some() => exceed max leverage
            position.get_position_collateral_amount<C_TOKEN>()
        } else { 0 };
        reserve_amount = if (collateral_amount + linked_position_collateral_amount >= reserve_amount) {
            0
        } else {
            reserve_amount - collateral_amount - linked_position_collateral_amount
        };
        assert!(
            if (!reduce_only) {
                lp_pool::check_trading_order_size_valid(liquidity_pool, collateral_token, reserve_amount)
            } else { true },
            error::reach_max_single_order_reserve_usage()
        );

        let order_id = symbol_market.market_info.next_order_id;

        if (linked_position_id.is_some()) {
            let position_id = *linked_position_id.borrow();
            let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];
            // edit position.linked_order_ids
            check_position_user_matched(mut_position, user);
            position::add_position_linked_order_info(mut_position, order_id, trigger_price);
        } else {
            // check open interest enough for this new position order
            if (is_long) {
                let max_buy_open_interest = math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAX_BUY_OPEN_INTEREST);
                assert!(symbol_market.market_info.user_long_position_size + size <= max_buy_open_interest, error::exceed_max_open_interest());
            } else {
                let max_sell_open_interest = math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAX_SELL_OPEN_INTEREST);
                assert!(symbol_market.market_info.user_short_position_size + size <= max_sell_open_interest, error::exceed_max_open_interest());
            };
        };

        let symbol = symbol::create(base_token, market.quote_token_type);
        let order = position::create_order(
            version,
            symbol,
            leverage_mbp,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            symbol_market.market_info.size_decimal,
            trigger_price,
            collateral,
            liquidity_token_decimal,
            linked_position_id,
            order_id,
            trading_pair_oracle_price,
            clock,
            ctx
        );

        let trading_fee_mbp = calculate_trading_fee_rate_mbp(
            // infos
            symbol_market.market_info.user_long_position_size,
            symbol_market.market_info.user_short_position_size,
            lp_pool::get_token_pool_state(liquidity_pool, collateral_token)[1],
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            is_long,
            size,
            symbol_market.market_config.trading_fee_config,
        );

        // add position or new position => original check_collateral_enough; reduce position => new check_collateral_enough (w/ unrealized pnl)
        if (reduce_only) {
            // new check_collateral_enough
            assert!(
                check_collateral_enough_when_reducing_position<C_TOKEN>(
                    symbol_market,
                        &order,
                        collateral_oracle_price,
                        collateral_oracle_price_decimal,
                        trading_pair_oracle_price,
                        trading_pair_oracle_price_decimal,
                        trading_fee_mbp,
                ),
                error::token_collateral_not_enough()
            );
        } else {
            assert!(
                check_collateral_enough_when_adding_position<C_TOKEN>(
                    symbol_market,
                    &order,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal,
                    trading_pair_oracle_price,
                    trading_pair_oracle_price_decimal,
                    trading_fee_mbp,
                ),
                error::token_collateral_not_enough()
            );
        };

        assert!(
            check_reserve_enough<C_TOKEN>(
                symbol_market,
                liquidity_pool,
                &order,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
            ),
            error::lp_pool_reserve_not_enough()
        );

        symbol_market.market_info.next_order_id = symbol_market.market_info.next_order_id + 1;

        let filled = position::check_order_filled(&order, trading_pair_oracle_price);

        emit(CreateTradingOrderEvent {
            user,
            market_index,
            pool_index,
            collateral_token: type_name::get<C_TOKEN>(),
            base_token,
            order_id,
            linked_position_id,
            collateral_amount,
            leverage_mbp,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            trigger_price,
            filled,
            filled_price: if (filled) {option::some(trading_pair_oracle_price)} else {option::none()},
            u64_padding: vector::empty()
        });

        // check order filled
        if (filled) {
            let (collateral_balance, _, _) = execute_order_<C_TOKEN>(
                version,
                // referrals,
                market_index,
                symbol_market,
                liquidity_pool,
                order,
                market.protocol_fee_share_bp,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
                typus_ecosystem_version,
                typus_user_registry,
                typus_leaderboard_registry,
                tails_staking_registry,
                competition_config,
                clock,
                ctx,
            );
            return_to_user(&mut market.id, collateral_balance, user, ctx);
        } else {
            // update market info
            adjust_market_info_user_order_size(symbol_market, is_long, false, size);

            // put order into vec map
            let order_type_tag = position::get_order_type_tag(&order);
            let active_orders_vec_map = get_mut_orders(symbol_market, true, order_type_tag); // &mut VecMap<u64, vector<TradingOrder>>
            // does not have leaf => no same trigger price order
            if (!active_orders_vec_map.contains(&trigger_price)) {
                active_orders_vec_map.insert(trigger_price, vector::singleton(order));
            } else {
                // first layer has leaf => append the order
                let active_orders = active_orders_vec_map.get_mut(&trigger_price);
                active_orders.push_back(order);
            };
        };
    }

    public struct CancelTradingOrderEvent has copy, drop {
        user: address,
        market_index: u64,
        order_id: u64,
        trigger_price: u64,
        collateral_token: TypeName,
        base_token: TypeName,
        released_collateral_amount: u64,
        u64_padding: vector<u64>
    }
    public fun cancel_trading_order<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        // order parameters
        order_id: u64,
        trigger_price: u64, // pass this for reducing network fee cost
        mut order_user: Option<address>, // if some => ctx should be a manager; none => cancel sender(ctx)'s order
        ctx: &mut TxContext,
    ): Coin<C_TOKEN> {
        // safety check
        if (order_user.is_some()) {
            admin::verify(version, ctx);
        } else {
            admin::version_check(version);
        };
        // user function
        let order_user = if (order_user.is_some()) {
            order_user.extract()
        } else {
            tx_context::sender(ctx)
        };

        let market = registry.markets.borrow_mut(market_index);

        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);

        let order_option = take_order_by_order_id_and_price(
            symbol_market,
            trigger_price,
            order_id,
            true,
            order_user
        );
        assert!(option::is_some(&order_option), error::order_not_found());
        let order = option::destroy_some(order_option);
        let order_size = position::get_order_size(&order);
        adjust_market_info_user_order_size(symbol_market, position::get_order_side(&order), true, order_size);

        // edit position.linked_order_ids
        let mut linked_position_id = position::get_order_linked_position_id(&order);
        if (linked_position_id.is_some()) {
            let position_id = linked_position_id.extract();
            let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];
            check_position_user_matched(mut_position, order_user);
            position::remove_position_linked_order_info(mut_position, position::get_order_id(&order));
        };
        let collateral = position::remove_order<C_TOKEN>(version, order);

        emit(CancelTradingOrderEvent {
            user: order_user,
            market_index,
            order_id,
            trigger_price,
            base_token,
            collateral_token: type_name::get<C_TOKEN>(),
            released_collateral_amount: balance::value(&collateral),
            u64_padding: vector::empty()
        });

        if (user_account::has_user_account(&market.id, order_user)) {
            let user_account = user_account::get_mut_user_account(&mut market.id, order_user);
            user_account.deposit(collateral);
            coin::zero<C_TOKEN>(ctx)
        } else {
            coin::from_balance(collateral, ctx)
        }
    }

    // public fun create_trading_order_with_tp_sl<C_TOKEN, BASE_TOKEN>(
    //     // for share objects
    //     version: &mut Version,
    //     registry: &mut MarketRegistry,
    //     pool_registry: &mut PoolRegistry,
    //     typus_oracle_c_token: &Oracle,
    //     typus_oracle_trading_symbol: &Oracle,
    //     clock: &Clock,
    //     market_index: u64,
    //     pool_index: u64,
    //     // tails
    //     typus_ecosystem_version: &TypusEcosystemVersion,
    //     typus_user_registry: &mut TypusUserRegistry,
    //     typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
    //     tails_staking_registry: &TailsStakingRegistry,
    //     competition_config: &CompetitionConfig,
    //     // order parameters
    //     collateral: Coin<C_TOKEN>, // collateral_amount: u64,
    //     is_long: bool,
    //     order_size: u64,
    //     trigger_price: u64,
    //     // tp sl parameters
    //     tp_price: vector<u64>,
    //     tp_size: vector<u64>,
    //     sl_price: vector<u64>,
    //     sl_size: vector<u64>,
    //     ctx: &mut TxContext,
    // ) {
    //     let linked_position_id = {
    //         // check oracle matched
    //         let market = registry.markets.borrow_mut(market_index);
    //         assert!(market.is_active, error::markets_inactive());
    //         assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());
    //         lp_pool::check_token_pool_status<C_TOKEN>(pool_registry, pool_index, true);

    //         let base_token = type_name::get<BASE_TOKEN>();
    //         assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
    //         let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
    //         assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());

    //         // check order can be filled immediately
    //         let (trading_pair_oracle_price, _) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);
    //         let filled_immediately = if (is_long) {
    //             trigger_price >= trading_pair_oracle_price
    //         } else {
    //             trigger_price <= trading_pair_oracle_price
    //         };
    //         assert!(filled_immediately, error::order_not_filled_immediately());

    //         // check tp sl order price valid
    //         let tp_sl_side = !is_long;
    //         tp_price.do_ref!(|price|{
    //             let order_price_valid = if (tp_sl_side) {
    //                 // short entry with TP/SL (TP = long)
    //                 *price < trading_pair_oracle_price && *price < trigger_price
    //             } else {
    //                 // long entry with TP/SL (TP = short)
    //                 *price > trading_pair_oracle_price && *price > trigger_price
    //             };
    //             assert!(order_price_valid, error::invalid_order_price());
    //         });
    //         sl_price.do_ref!(|price|{
    //             let order_price_valid = if (tp_sl_side) {
    //                 // short entry with TP/SL (SL = long)
    //                 *price > trading_pair_oracle_price && *price > trigger_price
    //             } else {
    //                 // long entry with TP/SL (SL = short)
    //                 *price < trading_pair_oracle_price && *price < trigger_price
    //             };
    //             assert!(order_price_valid, error::invalid_order_price());
    //         });
    //         symbol_market.market_info.next_position_id
    //     };

    //     create_trading_order_v2<C_TOKEN, BASE_TOKEN>(
    //         // for share objects
    //         version,
    //         registry,
    //         pool_registry,
    //         typus_oracle_c_token,
    //         typus_oracle_trading_symbol,
    //         clock,
    //         market_index,
    //         pool_index,
    //         // tails
    //         typus_ecosystem_version,
    //         typus_user_registry,
    //         typus_leaderboard_registry,
    //         tails_staking_registry,
    //         competition_config,
    //         // order parameters
    //         option::none(),
    //         collateral,
    //         false,
    //         is_long,
    //         false,
    //         order_size,
    //         trigger_price,
    //         ctx,
    //     );

    //     // tp orders
    //     let length = tp_price.length();
    //     let mut i = 0;
    //     while (i < length) {
    //         let price = tp_price[i];
    //         let size = tp_size[i];
    //         create_trading_order_v2<C_TOKEN, BASE_TOKEN>(
    //             // for share objects
    //             version,
    //             registry,
    //             pool_registry,
    //             typus_oracle_c_token,
    //             typus_oracle_trading_symbol,
    //             clock,
    //             market_index,
    //             pool_index,
    //             // tails
    //             typus_ecosystem_version,
    //             typus_user_registry,
    //             typus_leaderboard_registry,
    //             tails_staking_registry,
    //             competition_config,
    //             // order parameters
    //             option::some(linked_position_id),
    //             coin::zero<C_TOKEN>(ctx),
    //             true,
    //             !is_long,
    //             false,
    //             size,
    //             price,
    //             ctx,
    //         );
    //         i = i + 1;
    //     };

    //     // sl orders
    //     let length = sl_price.length();
    //     let mut i = 0;
    //     while (i < length) {
    //         let price = sl_price[i];
    //         let size = sl_size[i];
    //         create_trading_order_v2<C_TOKEN, BASE_TOKEN>(
    //             // for share objects
    //             version,
    //             registry,
    //             pool_registry,
    //             typus_oracle_c_token,
    //             typus_oracle_trading_symbol,
    //             clock,
    //             market_index,
    //             pool_index,
    //             // tails
    //             typus_ecosystem_version,
    //             typus_user_registry,
    //             typus_leaderboard_registry,
    //             tails_staking_registry,
    //             competition_config,
    //             // order parameters
    //             option::some(linked_position_id),
    //             coin::zero<C_TOKEN>(ctx),
    //             true,
    //             !is_long,
    //             true,
    //             size,
    //             price,
    //             ctx,
    //         );
    //         i = i + 1;
    //     };
    // }

    public struct ReleaseCollateralEvent has copy, drop {
        user: address,
        market_index: u64,
        pool_index: u64,
        position_id: u64,
        collateral_token: TypeName,
        base_token: TypeName,
        released_collateral_amount: u64,
        remaining_collateral_amount: u64,
        u64_padding: vector<u64>
    }
    public fun release_collateral<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // order parameters
        position_id: u64,
        release_amount: u64,
        ctx: &mut TxContext,
    ): Coin<C_TOKEN> {
        // user function
        let user = tx_context::sender(ctx);

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);
        // 1. safety checks:
        {
            // 1.a version check
            admin::version_check(version);
            let market = registry.markets.borrow_mut(market_index);
            assert!(market.is_active, error::markets_inactive());
            let collateral_token = type_name::get<C_TOKEN>();
            let base_token = type_name::get<BASE_TOKEN>();
            assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
            let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
            assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());
            let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];
            check_position_user_matched(mut_position, user);
            assert!(collateral_token == position::get_position_collateral_token_type(mut_position), error::collateral_token_type_mismatched());
            // 1.b check if exceed leverage:
            // update pool borrow info first, then update position position unrealized borrow fee and funding fee
            lp_pool::update_borrow_info(version, pool_registry, pool_index, clock);
            let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
            liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));
            let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, collateral_token);
            position::update_position_borrow_rate_and_funding_rate(
                mut_position,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
                cumulative_borrow_rate,
                symbol_market.market_info.cumulative_funding_rate_index_sign,
                symbol_market.market_info.cumulative_funding_rate_index
            );
            let max_releasing_collateral_amount = get_max_releasing_collateral_amount<C_TOKEN, BASE_TOKEN>(
                version,
                registry,
                pool_registry,
                typus_oracle_c_token,
                typus_oracle_trading_symbol,
                clock,
                market_index,
                pool_index,
                position_id,
            );
            assert!(max_releasing_collateral_amount >= release_amount, error::exceed_max_leverage());
        };

        // 2. execute releasing collateral
        let market = registry.markets.borrow_mut(market_index);
        let collateral_token = type_name::get<C_TOKEN>();
        let base_token = type_name::get<BASE_TOKEN>();
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
        let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];
        let position_collateral_amount = position::get_position_collateral_amount<C_TOKEN>(mut_position);
        assert!(position_collateral_amount >= release_amount, error::remaining_collateral_not_enough());

        let original_reserve_amount = mut_position.get_reserve_amount();
        let released_collateral = mut_position.release_collateral<C_TOKEN>(
            release_amount,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
        );
        let new_reserve_amount = mut_position.get_reserve_amount();
        liquidity_pool.update_reserve_amount<C_TOKEN>(
            new_reserve_amount > original_reserve_amount,
            std::u64::diff(new_reserve_amount, original_reserve_amount)
        );

        // 3. check if collateral reaches maintenance margin after releasing collateral (check liquidation)
        let trading_fee_mbp = calculate_trading_fee_rate_mbp(
            // infos
            symbol_market.market_info.user_long_position_size,
            symbol_market.market_info.user_short_position_size,
            lp_pool::get_token_pool_state(liquidity_pool, collateral_token)[1],
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            !mut_position.get_position_side(),
            mut_position.get_position_size(),
            symbol_market.market_config.trading_fee_config,
        );
        assert!(
            !position::check_position_liquidated(
                mut_position,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
                trading_fee_mbp,
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAINTENANCE_MARGIN_RATE_BP),
                lp_pool::get_cumulative_borrow_rate(liquidity_pool, collateral_token),
                symbol_market.market_info.cumulative_funding_rate_index_sign,
                symbol_market.market_info.cumulative_funding_rate_index,
            ),
            error::remaining_collateral_not_enough()
        );
        emit(ReleaseCollateralEvent {
            user,
            market_index,
            pool_index,
            position_id,
            collateral_token,
            base_token,
            released_collateral_amount: release_amount,
            remaining_collateral_amount: position_collateral_amount - release_amount,
            u64_padding: vector::empty(),
        });
        if (user_account::has_user_account(&market.id, user)) {
            let user_account = user_account::get_mut_user_account(&mut market.id, user);
            user_account.deposit(released_collateral);
            coin::zero<C_TOKEN>(ctx)
        } else {
            coin::from_balance(released_collateral, ctx)
        }
    }

    public struct IncreaseCollateralEvent has copy, drop {
        user: address,
        market_index: u64,
        pool_index: u64,
        position_id: u64,
        collateral_token: TypeName,
        base_token: TypeName,
        increased_collateral_amount: u64,
        remaining_collateral_amount: u64,
        u64_padding: vector<u64>
    }
    public fun increase_collateral<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // order parameters
        position_id: u64,
        collateral: Coin<C_TOKEN>,
        ctx: &mut TxContext,
    ) {
        // user function
        let user = tx_context::sender(ctx);
        // safety check
        admin::version_check(version);

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.is_active, error::markets_inactive());

        let collateral_token = type_name::get<C_TOKEN>();
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());
        assert!(symbol_market.market_info.is_active, error::trading_symbol_inactive());

        lp_pool::update_borrow_info(version, pool_registry, pool_index, clock);
        // not allowed when token pool inactive
        lp_pool::check_token_pool_status<C_TOKEN>(pool_registry, pool_index, true);

        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
        liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));
        let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, type_name::get<C_TOKEN>());

        let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];
        check_position_user_matched(mut_position, user);
        assert!(collateral_token == position::get_position_collateral_token_type(mut_position), error::collateral_token_type_mismatched());

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let position_collateral_amount = position::get_position_collateral_amount<C_TOKEN>(mut_position);
        let increased_collateral_amount = collateral.value();

        let original_reserve_amount = mut_position.get_reserve_amount();
        mut_position.increase_collateral<C_TOKEN>(
            collateral.into_balance(),
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
        );
        let new_reserve_amount = mut_position.get_reserve_amount();
        liquidity_pool.update_reserve_amount<C_TOKEN>(
            new_reserve_amount > original_reserve_amount,
            std::u64::diff(new_reserve_amount, original_reserve_amount)
        );

        position::update_position_borrow_rate_and_funding_rate(
            mut_position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate,
            symbol_market.market_info.cumulative_funding_rate_index_sign,
            symbol_market.market_info.cumulative_funding_rate_index
        );

        let trading_fee_mbp = calculate_trading_fee_rate_mbp(
            // infos
            symbol_market.market_info.user_long_position_size,
            symbol_market.market_info.user_short_position_size,
            lp_pool::get_token_pool_state(liquidity_pool, collateral_token)[1],
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            !mut_position.get_position_side(),
            mut_position.get_position_size(),
            symbol_market.market_config.trading_fee_config,
        );

        assert!(
            !position::check_position_liquidated(
                mut_position,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
                trading_fee_mbp,
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAINTENANCE_MARGIN_RATE_BP),
                cumulative_borrow_rate,
                symbol_market.market_info.cumulative_funding_rate_index_sign,
                symbol_market.market_info.cumulative_funding_rate_index
            ),
            error::remaining_collateral_not_enough()
        );
        emit(IncreaseCollateralEvent {
            user,
            market_index,
            pool_index,
            position_id,
            collateral_token,
            base_token,
            increased_collateral_amount,
            remaining_collateral_amount: position_collateral_amount + increased_collateral_amount,
            u64_padding: vector::empty(),
        });
    }

    public fun collect_position_funding_fee<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // order parameters
        position_id: u64,
        ctx: &mut TxContext,
    ) {
        // user function
        let user = tx_context::sender(ctx);
        // safety check
        admin::version_check(version);

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.is_active, error::markets_inactive());

        let collateral_token = type_name::get<C_TOKEN>();
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());
        assert!(symbol_market.market_info.is_active, error::trading_symbol_inactive());

        lp_pool::update_borrow_info(version, pool_registry, pool_index, clock);
        // not allowed when token pool inactive
        lp_pool::check_token_pool_status<C_TOKEN>(pool_registry, pool_index, true);

        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
        liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));
        let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, type_name::get<C_TOKEN>());

        let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];
        check_position_user_matched(mut_position, user);
        assert!(collateral_token == position::get_position_collateral_token_type(mut_position), error::collateral_token_type_mismatched());

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);
        position::update_position_borrow_rate_and_funding_rate(
            mut_position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate,
            symbol_market.market_info.cumulative_funding_rate_index_sign,
            symbol_market.market_info.cumulative_funding_rate_index
        );
        position::realize_funding_fee<C_TOKEN>(
            liquidity_pool,
            mut_position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            ctx
        );

        let trading_fee_mbp = calculate_trading_fee_rate_mbp(
            // infos
            symbol_market.market_info.user_long_position_size,
            symbol_market.market_info.user_short_position_size,
            lp_pool::get_token_pool_state(liquidity_pool, collateral_token)[1],
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            !mut_position.get_position_side(),
            mut_position.get_position_size(),
            symbol_market.market_config.trading_fee_config,
        );

        assert!(
            !position::check_position_liquidated(
                mut_position,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
                trading_fee_mbp,
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAINTENANCE_MARGIN_RATE_BP),
                cumulative_borrow_rate,
                symbol_market.market_info.cumulative_funding_rate_index_sign,
                symbol_market.market_info.cumulative_funding_rate_index
            ),
            error::remaining_collateral_not_enough()
        );
    }

    public struct CreateTradingOrderWithBidReceiptsEvent has copy, drop {
        user: address,
        market_index: u64,
        pool_index: u64,
        dov_index: u64,
        collateral_token: TypeName,
        base_token: TypeName,
        order_id: u64,
        collateral_in_deposit_token: u64,
        is_long: bool,
        size: u64,
        trigger_price: u64,
        filled: bool,
        filled_price: Option<u64>,
        u64_padding: vector<u64>
    }
    public fun create_trading_order_with_bid_receipt_v3<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        // order parameters: linked_position_id should always be None in this function
        collateral_bid_receipt: TypusBidReceipt, // size: u64, dov_index: u64,
        is_long: bool,
        ctx: &mut TxContext,
    ) {
        // safety check
        admin::version_check(version);
        let market = registry.markets.borrow_mut(market_index);
        assert!(market.is_active, error::markets_inactive());
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());
        assert!(symbol_market.market_info.is_active, error::trading_symbol_inactive());
        let collateral_token = type_name::get<C_TOKEN>();
        let liquidity_token_decimal = lp_pool::get_liquidity_token_decimal(pool_registry, pool_index, collateral_token);
        {
            let liquidity_pool = lp_pool::get_liquidity_pool(pool_registry, pool_index);
            liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));
        };
        lp_pool::update_borrow_info(version, pool_registry, pool_index, clock);
        // not allowed when token pool inactive
        lp_pool::check_token_pool_status<C_TOKEN>(pool_registry, pool_index, true);
        // check
        // 1. leverage available when creating order for new position
        // 2. ITM
        // 3. size <= option contract size
        // 4. C_TOKEN should be the same as D_TOKEN (checked at check_itm_v2)
        // 5. BASE_TOKEN == portoflio_vault.info.settlement_base
        // 6. call -> only open short, put -> only open long
        // 7. check lp pool reserve enough
        let (_vid, dov_index, share_u64_padding) = vault::get_bid_receipt_info(&collateral_bid_receipt);
        let verification_result = typus_dov_single::verify_bid_receipt_collateral_trading_order_v2<C_TOKEN, BASE_TOKEN>(
            dov_registry,
            typus_oracle_trading_symbol,
            typus_oracle_c_token,
            &collateral_bid_receipt,
            is_long,
            clock,
        );
        if (verification_result == b"E_BID_RECEIPT_HAS_BEEN_EXPIRED") {
            abort error::bid_receipt_has_been_expired()
        } else if (verification_result == b"E_AUCTION_NOT_YET_ENDED") {
            abort error::auction_not_yet_ended()
        } else if (verification_result == b"E_BID_RECEIPT_NOT_ITM") {
            abort error::bid_receipt_not_itm()
        } else if (verification_result == b"E_BASE_TOKEN_MISMATCHED") {
            abort error::base_token_mismatched()
        } else if (verification_result == b"E_INVALID_ORDER_SIDE") {
            abort error::invalid_order_side()
        } else if (verification_result == b"E_COLLATERAL_TOKEN_TYPE_MISMATCHED") {
            abort error::collateral_token_type_mismatched()
        };

        let collateral_amount = typus_dov_single::get_bid_receipt_intrinsic_value_v2<C_TOKEN>(
            dov_registry,
            typus_oracle_trading_symbol,
            typus_oracle_c_token,
            &collateral_bid_receipt,
            clock
        );
        let size = *share_u64_padding.borrow(0); // share
        assert!(
            size >= symbol_market.market_config.min_size
                && size % symbol_market.market_config.lot_size == 0
            ,
            error::invalid_order_size()
        );

        // check open interest enough for this new position order
        if (is_long) {
            let max_buy_open_interest = math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAX_BUY_OPEN_INTEREST);
            assert!(symbol_market.market_info.user_long_position_size + size <= max_buy_open_interest, error::exceed_max_open_interest());
        } else {
            let max_sell_open_interest = math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAX_SELL_OPEN_INTEREST);
            assert!(symbol_market.market_info.user_short_position_size + size <= max_sell_open_interest, error::exceed_max_open_interest());
        };

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let notional_size_usd
            = amount_to_usd(size, symbol_market.market_info.size_decimal, trading_pair_oracle_price, trading_pair_oracle_price_decimal);
        let notional_size_in_c_token
            = usd_to_amount(notional_size_usd, liquidity_token_decimal, collateral_oracle_price, collateral_oracle_price_decimal);
        let reserve_amount = if (collateral_amount >= notional_size_in_c_token) {
            0
        } else {
            notional_size_in_c_token - collateral_amount
        };
        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
        assert!(lp_pool::check_trading_order_size_valid(liquidity_pool, collateral_token, reserve_amount), error::reach_max_single_order_reserve_usage());
        // let referrals = dynamic_object_field::borrow_mut<String, Referrals>(&mut registry.referral_registry, string::utf8(K_REFERRAL));
        // let fee_reduction_bp = if (referrals.referrals.contains(user)) {
        //     let referral_info = referrals.referrals.borrow(user);
        //     referral_info.fee_reduction_bp
        // } else { 0 };
        // let fee_reduction_bp = 0;
        // let trading_fee_rate = ((symbol_market.market_config.trading_fee_rate as u128)
        //                             * ((10000 - fee_reduction_bp) as u128)
        //                                 / 10000 as u64);

        let trading_fee_mbp = calculate_trading_fee_rate_mbp(
            // infos
            symbol_market.market_info.user_long_position_size,
            symbol_market.market_info.user_short_position_size,
            lp_pool::get_token_pool_state(liquidity_pool, collateral_token)[1],
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            is_long,
            size,
            vector[
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_BASE_TRADING_FEE_MBP),
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_MAX_TRADING_FEE_MBP),
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_ALLOCATED_LP_EXPOSURE_MBP),
            ],
        );
        let trading_fee = ((notional_size_in_c_token as u128) * (trading_fee_mbp as u128) / 10000000 as u64);
        assert!(
            notional_size_in_c_token
                < ((collateral_amount - trading_fee as u128)
                    * (symbol_market.market_config.option_collateral_max_leverage_mbp as u128) / 10000000 as u64),
            error::exceed_max_leverage()
        );

        let symbol = symbol::create(base_token, market.quote_token_type);

        let deposit_token = typus_dov_single::get_deposit_token(dov_registry, dov_index);
        let bid_token = typus_dov_single::get_bid_token(dov_registry, dov_index);
        assert!(bid_token == type_name::get<B_TOKEN>(), error::bid_token_mismatched());

        let order_id = symbol_market.market_info.next_order_id;

        let order = position::create_order_with_bid_receipts(
            version,
            symbol,
            dov_index,
            deposit_token,
            100,
            false,
            is_long,
            false,
            size,
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            vector[collateral_bid_receipt],
            liquidity_token_decimal,
            option::none(),
            order_id,
            trading_pair_oracle_price,
            tx_context::sender(ctx),
            clock,
            ctx
        );

        assert!(
            check_option_collateral_enough<C_TOKEN>(
                dov_registry,
                typus_oracle_trading_symbol,
                typus_oracle_c_token,
                symbol_market,
                &order,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
                trading_fee_mbp,
                clock,
            ),
            error::option_collateral_not_enough()
        );

        assert!(
            check_reserve_enough<C_TOKEN>(
                symbol_market,
                liquidity_pool,
                &order,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
            ),
            error::lp_pool_reserve_not_enough()
        );

        symbol_market.market_info.next_order_id = symbol_market.market_info.next_order_id + 1;

        emit(CreateTradingOrderWithBidReceiptsEvent {
            user: tx_context::sender(ctx),
            market_index,
            pool_index,
            dov_index,
            collateral_token: type_name::get<C_TOKEN>(),
            base_token,
            order_id,
            collateral_in_deposit_token: collateral_amount,
            is_long,
            size,
            trigger_price: trading_pair_oracle_price,
            filled: true,
            filled_price: option::some(trading_pair_oracle_price),
            u64_padding: vector::empty(),
        });

        // check order filled
        assert!(position::check_order_filled(&order, trading_pair_oracle_price), error::option_collateral_order_not_filled());
        execute_option_collateral_order_<C_TOKEN, B_TOKEN>(
            version,
            // referrals,
            dov_registry,
            typus_oracle_trading_symbol,
            typus_oracle_c_token,
            symbol_market,
            liquidity_pool,
            order,
            market.protocol_fee_share_bp,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
            typus_ecosystem_version,
            typus_user_registry,
            typus_leaderboard_registry,
            tails_staking_registry,
            competition_config,
            clock,
            ctx,
        );
    }


    public fun reduce_option_collateral_position_size_v2<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        // position related arguments
        position_id: u64,
        mut order_size: Option<u64>, // in contract size decimal. if none => close position
        ctx: &mut TxContext,
    ) {
        // user function
        let user = tx_context::sender(ctx);
        // safety check
        let market = registry.markets.borrow_mut(market_index);
        assert!(market.is_active, error::markets_inactive());
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());
        if (order_size.is_some()) {
            assert!(*order_size.borrow() % symbol_market.market_config.lot_size == 0, error::invalid_order_size());
        };
        let collateral_token = type_name::get<C_TOKEN>();
        let liquidity_token_decimal = lp_pool::get_liquidity_token_decimal(pool_registry, pool_index, type_name::get<C_TOKEN>());
        {
            let liquidity_pool = lp_pool::get_liquidity_pool(pool_registry, pool_index);
            liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));
        };

        lp_pool::update_borrow_info(version, pool_registry, pool_index, clock);
        // let referrals = dynamic_object_field::borrow_mut<String, Referrals>(&mut registry.referral_registry, string::utf8(K_REFERRAL));

        let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];
        if (mut_position.get_position_user() != user) {
            admin::verify(version, ctx);
        };
        assert!(mut_position.is_option_collateral_position(), error::not_option_collateral_position());
        let (dov_index, bid_token) = mut_position.get_position_option_collateral_info();
        assert!(bid_token == type_name::get<B_TOKEN>(), error::bid_token_mismatched());

        let position_is_long = mut_position.get_position_side();
        let position_size = mut_position.get_position_size();

        if (order_size.is_some()) {
            assert!(*order_size.borrow() <= position_size, error::invalid_order_size());
        };

        // let (fee_rebate_bp, fee_reduction_bp) = if (referrals.referrals.contains(user)) {
        //     let referral_info = referrals.referrals.borrow(user);
        //     (referral_info.fee_rebate_bp, referral_info.fee_reduction_bp)
        // } else { (0, 0) };
        // let (_fee_rebate_bp, fee_reduction_bp) = (0, 0);

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
        let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, type_name::get<C_TOKEN>());
        position::update_position_borrow_rate_and_funding_rate(
            mut_position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate,
            symbol_market.market_info.cumulative_funding_rate_index_sign,
            symbol_market.market_info.cumulative_funding_rate_index
        );

        // check perp pnl valid
        let (is_cost, position_unrealized_cost) = position::calculate_unrealized_cost(mut_position);
        let unrealized_cost_in_usd = amount_to_usd(
            position_unrealized_cost,
            liquidity_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );
        let size = if (order_size.is_none()) {
            position_size
        } else {
            order_size.extract()
        };
        let trading_fee_mbp = calculate_trading_fee_rate_mbp(
            // infos
            symbol_market.market_info.user_long_position_size,
            symbol_market.market_info.user_short_position_size,
            lp_pool::get_token_pool_state(liquidity_pool, collateral_token)[1],
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            !mut_position.get_position_side(),
            size,
            vector[
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_BASE_TRADING_FEE_MBP),
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_MAX_TRADING_FEE_MBP),
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_ALLOCATED_LP_EXPOSURE_MBP),
            ],
        );
        let (has_profit, pnl_usd, _) = mut_position.calculate_unrealized_pnl(
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
        );
        let exercise_value = position::get_option_position_exercise_value<C_TOKEN>(
            dov_registry,
            typus_oracle_trading_symbol,
            typus_oracle_c_token,
            mut_position,
            clock
        );
        let exercise_value_usd = amount_to_usd(
            exercise_value,
            liquidity_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );
        let is_overall_profit = if (has_profit) {
            if (is_cost) {
                pnl_usd + exercise_value >= unrealized_cost_in_usd
            } else {
                true
            }
        } else {
            if (is_cost) {
                exercise_value_usd >= unrealized_cost_in_usd + pnl_usd
            } else {
                unrealized_cost_in_usd + exercise_value_usd >= pnl_usd
            }
        };

        assert!(is_overall_profit, error::perp_position_losses());

        // split bid receipts when the position is not fully closed
        if (size < position_size) {
            let splitted_receipt = position::split_bid_receipt(dov_registry, mut_position, size, ctx);
            transfer::public_transfer(splitted_receipt, mut_position.get_position_user());
        };
        let symbol = symbol::create(base_token, market.quote_token_type);
        // create order
        let order_id = symbol_market.market_info.next_order_id;
        let order = position::create_order_with_bid_receipts(
            version,
            // order parameters
            symbol,
            dov_index,
            collateral_token,
            100,
            true,   // is_reduce_only
            !position_is_long,
            false,
            size,
            mut_position.get_position_size_decimal(),
            trading_pair_oracle_price,
            vector::empty(),
            liquidity_token_decimal,
            // generated by entry function
            option::some(mut_position.get_position_id()),
            order_id,
            trading_pair_oracle_price,
            mut_position.get_position_user(),
            clock,
            ctx,
        );

        emit(CreateTradingOrderWithBidReceiptsEvent {
            user,
            market_index,
            pool_index,
            dov_index,
            collateral_token: type_name::get<C_TOKEN>(),
            base_token,
            order_id,
            collateral_in_deposit_token: exercise_value,
            is_long: !position_is_long,
            size,
            trigger_price: trading_pair_oracle_price,
            filled: true,
            filled_price: option::some(trading_pair_oracle_price),
            u64_padding: vector::empty(),
        });

        symbol_market.market_info.next_order_id = symbol_market.market_info.next_order_id + 1;
        // execute_option_collateral_order_
        execute_option_collateral_order_<C_TOKEN, B_TOKEN>(
            version,
            // referrals,
            dov_registry,
            typus_oracle_trading_symbol,
            typus_oracle_c_token,
            symbol_market,
            liquidity_pool,
            order,
            market.protocol_fee_share_bp,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
            // tails
            typus_ecosystem_version,
            typus_user_registry,
            typus_leaderboard_registry,
            tails_staking_registry,
            competition_config,
            clock,
            ctx,
        );
    }

    public struct MatchTradingOrderEvent has copy, drop {
        collateral_token: TypeName,
        base_token: TypeName,
        matched_order_ids: vector<u64>,
        u64_padding: vector<u64>
    }
    public fun match_trading_order_v2<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        // other parameters
        order_type_tag: u8,
        trigger_price: u64,
        max_operation_count: u64,
        ctx: &mut TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let mut operation_count = 0;
        let mut matched_order_ids = vector::empty();
        // let referrals = dynamic_object_field::borrow_mut<String, Referrals>(&mut registry.referral_registry, string::utf8(K_REFERRAL));

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let collateral_token = type_name::get<C_TOKEN>();
        {
            let liquidity_pool = lp_pool::get_liquidity_pool(pool_registry, pool_index);
            liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));
        };
        lp_pool::update_borrow_info(version, pool_registry, pool_index, clock);
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());

        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let (_, mut active_orders) = {
            let orders_vec_map = get_mut_orders(symbol_market, true, order_type_tag);
            orders_vec_map.remove(&trigger_price)
        };
        let mut remaining_orders = vector::empty<TradingOrder>();
        while (active_orders.length() > 0 && operation_count < max_operation_count) {
            let order = active_orders.pop_back();
            let is_long = order.get_order_side();
            let size = order.get_order_size();
            let order_id = order.get_order_id();
            let order_user = order.get_order_user();
            let mut linked_position_id = order.get_order_linked_position_id();
            if (linked_position_id.is_some()) {
                let position_id = linked_position_id.extract();
                if (!symbol_market.user_positions.contains(position_id)) {
                    let collateral = remove_linked_order_<C_TOKEN>(
                        version,
                        market_index,
                        symbol_market,
                        order,
                        order_user
                    );
                    return_to_user(&mut market.id, collateral, order_user, ctx);
                    continue
                };
            };

            let order_filled = position::check_order_filled(&order, trading_pair_oracle_price);
            let token_collateral_order_matched
                = position::get_order_collateral_token(&order) == type_name::get<C_TOKEN>();
            let reserve_enough = check_reserve_enough<C_TOKEN>(
                symbol_market,
                liquidity_pool,
                &order,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
            );
            // check open interest enough for this new position order
            let exceed_max_open_interest = if (position::get_order_reduce_only(&order)) {
                false
            } else {
                if (is_long) {
                    let max_buy_open_interest = math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAX_BUY_OPEN_INTEREST);
                    symbol_market.market_info.user_long_position_size + size > max_buy_open_interest
                } else {
                    let max_sell_open_interest = math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAX_SELL_OPEN_INTEREST);
                    symbol_market.market_info.user_short_position_size + size > max_sell_open_interest
                }
            };

            if (reserve_enough && token_collateral_order_matched && order_filled && !exceed_max_open_interest) {
                // skip orders not reduce only when token pool inactive
                if ((
                    !liquidity_pool.get_token_pool(&type_name::get<C_TOKEN>()).token_pool_is_active()
                    || !symbol_market.market_info.is_active)
                    && !order.get_order_reduce_only()
                ) {
                    remaining_orders.push_back(order);
                    continue
                };

                // update market info order size
                adjust_market_info_user_order_size(symbol_market, is_long, true, size);
                let (collateral_balance, _, _) = execute_order_<C_TOKEN>(
                    version,
                    // referrals,
                    market_index,
                    symbol_market,
                    liquidity_pool,
                    order,
                    market.protocol_fee_share_bp,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal,
                    trading_pair_oracle_price,
                    trading_pair_oracle_price_decimal,
                    // tails
                    typus_ecosystem_version,
                    typus_user_registry,
                    typus_leaderboard_registry,
                    tails_staking_registry,
                    competition_config,
                    clock,
                    ctx,
                );
                return_to_user(&mut market.id, collateral_balance, order_user, ctx);
                matched_order_ids.push_back(order_id);
                operation_count = operation_count + 1;
            } else {
                remaining_orders.push_back(order);
            };
        };
        if (active_orders.length() > 0) {
            remaining_orders.append(active_orders);
        } else {
            vector::destroy_empty(active_orders);
        };
        if (remaining_orders.length() > 0) {
            let orders_vec_map = get_mut_orders(symbol_market, true, order_type_tag);
            orders_vec_map.insert(trigger_price, remaining_orders);
        } else {
            vector::destroy_empty(remaining_orders);
        };

        if (operation_count > 0) {
            emit(MatchTradingOrderEvent {
                collateral_token: type_name::get<C_TOKEN>(),
                base_token,
                matched_order_ids,
                u64_padding: vector::empty()
            });
        };
    }

    public struct ManagerCancelOrdersEvent has copy, drop {
        reason: String,
        collateral_token: TypeName,
        base_token: TypeName,
        order_type_tag: u8,
        order_ids: vector<u64>,
        order_sizes: vector<u64>,
        order_prices: vector<u64>,
        u64_padding: vector<u64>
    }
    public fun manager_cancel_order_by_open_interest_limit<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // other parameters
        order_type_tag: u8,
        trigger_price: u64,
        max_operation_count: u64,
        ctx: &mut TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let mut operation_count = 0;
        // let referrals = dynamic_object_field::borrow_mut<String, Referrals>(&mut registry.referral_registry, string::utf8(K_REFERRAL));

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let collateral_token = type_name::get<C_TOKEN>();
        lp_pool::update_borrow_info(version, pool_registry, pool_index, clock);
        let symbol_market = object_table::borrow<TypeName, SymbolMarket>(&market.symbol_markets, base_token);

        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
        liquidity_pool.check_active();

        let active_orders = get_orders(symbol_market, true, order_type_tag).get(&trigger_price);
        let mut order_ids = vector::empty();
        let mut order_sizes = vector::empty();
        let mut order_prices = vector::empty();
        let mut order_users = vector::empty();
        let mut i = 0;
        let length = active_orders.length();
        while (i < length && operation_count < max_operation_count) {
            let order = &active_orders[i];
            let is_long = order.get_order_side();
            let size = order.get_order_size();
            let order_id = order.get_order_id();
            let order_user = order.get_order_user();
            let order_collateral_token = order.get_order_collateral_token();

            // check open interest enough for this new position order
            let exceed_max_open_interest = if (is_long) {
                let max_buy_open_interest = math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAX_BUY_OPEN_INTEREST);
                symbol_market.market_info.user_long_position_size + size > max_buy_open_interest
            } else {
                let max_sell_open_interest = math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAX_SELL_OPEN_INTEREST);
                symbol_market.market_info.user_short_position_size + size > max_sell_open_interest
            };

            if (exceed_max_open_interest && order_collateral_token == collateral_token) {
                order_ids.push_back(order_id);
                order_sizes.push_back(size);
                order_prices.push_back(trigger_price);
                order_users.push_back(order_user);
                operation_count = operation_count + 1;
            };
            i = i + 1;
        };

        let mut j = 0;
        let length = order_ids.length();
        while (j < length) {
            let order_id = order_ids[j];
            let trigger_price = order_prices[j];
            let order_user = order_users[j];
            let margin = cancel_trading_order<C_TOKEN, BASE_TOKEN>(
                version,
                registry,
                market_index,
                order_id,
                trigger_price,
                option::some(order_user),
                ctx,
            );
            if (margin.value() > 0) {
                let market = registry.markets.borrow_mut(market_index);
                return_to_user(&mut market.id, margin.into_balance(), order_user, ctx);
            } else {
                margin.destroy_zero();
            };
            j = j + 1;
        };

        if (operation_count > 0) {
            emit(ManagerCancelOrdersEvent {
                reason: string::utf8(b"exceed_max_open_interest"),
                collateral_token: type_name::get<C_TOKEN>(),
                base_token,
                order_type_tag,
                order_ids,
                order_sizes,
                order_prices,
                u64_padding: vector::empty()
            });
        };
    }

    public fun cancel_linked_orders<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        linked_order_ids: vector<u64>,
        linked_order_prices: vector<u64>,
        user: address,
        ctx: &mut TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow_mut(market_index);
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);

        let mut collateral_balance = balance::zero<C_TOKEN>();
        let collaterals = remove_linked_orders<C_TOKEN>(version, market_index, symbol_market, linked_order_ids, linked_order_prices, user);
        collateral_balance.join(collaterals);
        // transfer remaining balance back to user
        if (collateral_balance.value() > 0) {
            return_to_user(&mut market.id, collateral_balance, user, ctx);
        } else {
            balance::destroy_zero(collateral_balance);
        };
    }

    // only for token collateral position
    public struct ManagerReducePositionEvent has copy, drop {
        user: address,
        collateral_token: TypeName,
        base_token: TypeName,
        position_id: u64,
        reduced_size: u64,
        collateral_price: u64,
        trading_price: u64,
        cancelled_order_ids: vector<u64>,
        u64_padding: vector<u64>
    }
    public fun manager_reduce_position_v2<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        // other parameters
        position_id: u64,
        reduced_ratio_bp: u64,
        ctx: &mut TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        // let referrals = dynamic_object_field::borrow_mut<String, Referrals>(&mut registry.referral_registry, string::utf8(K_REFERRAL));

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());

        let collateral_token = type_name::get<C_TOKEN>();
        {
            let liquidity_pool = lp_pool::get_liquidity_pool(pool_registry, pool_index);
            liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));
        };
        let liquidity_token_decimal = lp_pool::get_liquidity_token_decimal(pool_registry, pool_index, type_name::get<C_TOKEN>());
        lp_pool::update_borrow_info(version, pool_registry, pool_index, clock);
        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());

        let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];
        let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, type_name::get<C_TOKEN>());

        position::update_position_borrow_rate_and_funding_rate(
            mut_position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate,
            symbol_market.market_info.cumulative_funding_rate_index_sign,
            symbol_market.market_info.cumulative_funding_rate_index
        );

        let symbol = symbol::create(base_token, market.quote_token_type);
        let user = position::get_position_user(mut_position);
        let mut order_size = ((position::get_position_size(mut_position) as u128)
                            * (reduced_ratio_bp as u128) / 10000 as u64);
        order_size = order_size / symbol_market.market_config.lot_size * symbol_market.market_config.lot_size;
        let order_id = symbol_market.market_info.next_order_id;
        let order = position::manager_create_reduce_only_order<C_TOKEN>(
            version,
            // order parameters
            symbol,
            !position::get_position_side(mut_position),
            order_size,
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            balance::zero<C_TOKEN>(),
            liquidity_token_decimal,
            // generated by entry function
            position_id,
            user,
            symbol_market.market_info.next_order_id,
            trading_pair_oracle_price,
            clock,
            ctx,
        );
        symbol_market.market_info.next_order_id = symbol_market.market_info.next_order_id + 1;

        position::add_position_linked_order_info(mut_position, order_id, trading_pair_oracle_price);

        let order_filled = position::check_order_filled(&order, trading_pair_oracle_price);
        assert!(order_filled, error::order_not_filled_immediately());
        let (collateral_balance, linked_order_ids, linked_order_prices) = execute_order_<C_TOKEN>(
            version,
            // referrals,
            market_index,
            symbol_market,
            liquidity_pool,
            order,
            market.protocol_fee_share_bp,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // tails
            typus_ecosystem_version,
            typus_user_registry,
            typus_leaderboard_registry,
            tails_staking_registry,
            competition_config,
            clock,
            ctx,
        );
        return_to_user(&mut market.id, collateral_balance, user, ctx);

        if (linked_order_ids.length() > 0) {
            cancel_linked_orders<C_TOKEN, BASE_TOKEN>(
                // for share objects
                version,
                registry,
                market_index,
                linked_order_ids,
                linked_order_prices,
                user,
                ctx,
            );
        };

        emit(ManagerReducePositionEvent {
            user,
            collateral_token,
            base_token,
            position_id,
            reduced_size: order_size,
            collateral_price: collateral_oracle_price,
            trading_price: trading_pair_oracle_price,
            cancelled_order_ids: linked_order_ids,
            u64_padding: vector::empty()
        });
    }

    public struct ManagerCloseOptionPositionEvent has copy, drop {
        user: address,
        collateral_token: TypeName,
        base_token: TypeName,
        position_id: u64,
        order_size: u64,
        collateral_price: u64,
        trading_price: u64,
        cancelled_order_ids: vector<u64>,
        u64_padding: vector<u64>
    }
    public fun manager_close_option_position_v2<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        // other parameters
        position_id: u64,
        ctx: &mut TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        // let referrals = dynamic_object_field::borrow_mut<String, Referrals>(&mut registry.referral_registry, string::utf8(K_REFERRAL));

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.is_active, error::markets_inactive());
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());

        let collateral_token = type_name::get<C_TOKEN>();
        {
            let liquidity_pool = lp_pool::get_liquidity_pool(pool_registry, pool_index);
            liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));
        };
        let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];
        assert!(mut_position.is_option_collateral_position(), error::not_option_collateral_position());
        assert!(position::option_position_bid_receipts_expired(dov_registry, mut_position), error::bid_receipt_not_expired());

        let user = mut_position.get_position_user();
        let order_size = mut_position.get_position_size();
        let linked_order_ids = mut_position.get_position_linked_order_ids();

        let (collateral_oracle_price, _collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, _trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        reduce_option_collateral_position_size_v2<C_TOKEN, B_TOKEN, BASE_TOKEN>(
            // for share objects
            version,
            registry,
            pool_registry,
            dov_registry,
            typus_oracle_c_token,
            typus_oracle_trading_symbol,
            clock,
            market_index,
            pool_index,
            // tails
            typus_ecosystem_version,
            typus_user_registry,
            typus_leaderboard_registry,
            tails_staking_registry,
            competition_config,
            // position related arguments
            position_id,
            option::none(),
            ctx,
        );

        emit(ManagerCloseOptionPositionEvent {
            user,
            collateral_token,
            base_token,
            position_id,
            order_size,
            collateral_price: collateral_oracle_price,
            trading_price: trading_pair_oracle_price,
            cancelled_order_ids: linked_order_ids,
            u64_padding: vector::empty(),
        });
    }

    // ======= Remove Liquidity Token Process =======
    // (1) * n
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun manager_remove_position_v2<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        // other parameters
        position_id: u64,
        is_option_position: bool,
        process: RemoveLiquidityTokenProcess,
        ctx: &mut TxContext
    ): RemoveLiquidityTokenProcess {
        deprecated();
        process
    }

    // (2)
    public struct ManagerUpdateProcessStatusAfterPositionEvent has copy, drop {
        market_index: u64,
        pool_index: u64,
        liquidity_token: TypeName,
        trading_base_token: TypeName,
    }
    // public(package) fun manager_update_process_status_after_position<C_TOKEN, BASE_TOKEN>(
    //     // for share objects
    //     version: &Version,
    //     registry: &MarketRegistry,
    //     pool_registry: &PoolRegistry,
    //     dov_registry: &DovRegistry,
    //     typus_oracle_c_token: &Oracle,
    //     typus_oracle_trading_symbol: &Oracle,
    //     clock: &Clock,
    //     market_index: u64,
    //     pool_index: u64,
    //     mut process: RemoveLiquidityTokenProcess,
    //     ctx: &TxContext
    // ): RemoveLiquidityTokenProcess {
    //     // safety check
    //     admin::verify(version, ctx);
    //     lp_pool::check_token_pool_status<C_TOKEN>(pool_registry, pool_index, false);
    //     lp_pool::check_remove_liquidity_token_process_status(&process, 0);
    //     let result = get_liquidation_info<C_TOKEN, BASE_TOKEN>(
    //     // for share objects
    //         version,
    //         registry,
    //         pool_registry,
    //         dov_registry,
    //         typus_oracle_c_token,
    //         typus_oracle_trading_symbol,
    //         clock,
    //         market_index,
    //         pool_index,
    //         true,
    //         ctx
    //     );
    //     emit(ManagerUpdateProcessStatusAfterPositionEvent {
    //         market_index,
    //         pool_index,
    //         liquidity_token: type_name::get<C_TOKEN>(),
    //         trading_base_token: type_name::get<BASE_TOKEN>(),
    //     });
    //     if (result.length() == 0) {
    //         lp_pool::update_remove_liquidity_token_process_token<BASE_TOKEN>(&mut process, true);
    //         let market = registry.markets.borrow(market_index);
    //         let removed_symbol_markets = lp_pool::get_remove_liquidity_token_process_token(&process, true);
    //         if (removed_symbol_markets.length() == market.symbols.length()) {
    //             lp_pool::update_remove_liquidity_token_process_status(&mut process, 1);
    //         };
    //         return process
    //     };

    //     process
    // }

    // (3) * n
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun manager_remove_order<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        market_index: u64,
        pool_index: u64,
        // other parameters
        order_user: address,
        order_id: u64,
        trigger_price: u64,
        process: RemoveLiquidityTokenProcess,
        ctx: &mut TxContext
    ): RemoveLiquidityTokenProcess {
        deprecated();
        process
    }

    // (4)
    public struct ManagerUpdateProcessStatusAfterOrderEvent has copy, drop {
        market_index: u64,
        pool_index: u64,
        liquidity_token: TypeName,
        trading_base_token: TypeName,
    }
    // public(package) fun manager_update_process_status_after_order<C_TOKEN, BASE_TOKEN>(
    //     // for share objects
    //     version: &Version,
    //     registry: &MarketRegistry,
    //     pool_registry: &PoolRegistry,
    //     market_index: u64,
    //     pool_index: u64,
    //     mut process: RemoveLiquidityTokenProcess,
    //     ctx: &TxContext
    // ): RemoveLiquidityTokenProcess {
    //     // safety check
    //     admin::verify(version, ctx);
    //     lp_pool::check_token_pool_status<C_TOKEN>(pool_registry, pool_index, false);
    //     lp_pool::check_remove_liquidity_token_process_status(&process, 1);

    //     let mut length = 0;

    //     let mut i = 0;
    //     while (i < 4) {
    //         let result = get_active_orders_by_order_tag_and_ctoken<C_TOKEN, BASE_TOKEN>(
    //             version,
    //             registry,
    //             market_index,
    //             i,
    //         );
    //         length = length + result.length();
    //         i = i + 1;
    //     };

    //     emit(ManagerUpdateProcessStatusAfterOrderEvent {
    //         market_index,
    //         pool_index,
    //         liquidity_token: type_name::get<C_TOKEN>(),
    //         trading_base_token: type_name::get<BASE_TOKEN>(),
    //     });

    //     if (length == 0) {
    //         lp_pool::update_remove_liquidity_token_process_token<BASE_TOKEN>(&mut process, false);
    //         let market = registry.markets.borrow(market_index);
    //         let removed_symbol_markets = lp_pool::get_remove_liquidity_token_process_token(&process, true);
    //         if (removed_symbol_markets.length() == market.symbols.length()) {
    //             lp_pool::update_remove_liquidity_token_process_status(&mut process, 2);
    //         };
    //         return process
    //     };

    //     process
    // }

    /// ==========================

    /// return liquidatable position_ids
    public struct LiquidationInfo has copy, drop {
        position_id: u64,
        dov_index: Option<u64>,
        bid_token: Option<TypeName>
    }
    fun get_trading_fee_config(
        market_config: &MarketConfig,
        is_option_position: bool,
    ): vector<u64> {
        if (is_option_position) {
            vector[
                math::get_u64_vector_value(&market_config.u64_padding, I_OPTION_COLLATERAL_BASE_TRADING_FEE_MBP),
                math::get_u64_vector_value(&market_config.u64_padding, I_OPTION_COLLATERAL_MAX_TRADING_FEE_MBP),
                math::get_u64_vector_value(&market_config.u64_padding, I_OPTION_COLLATERAL_ALLOCATED_LP_EXPOSURE_MBP),
            ]
        } else {
            market_config.trading_fee_config
        }
    }

    public(package) fun get_liquidation_info<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &Version,
        registry: &MarketRegistry,
        pool_registry: &PoolRegistry,
        dov_registry: &DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        get_all: bool, // get all C_TOKEN positions
        ctx: &TxContext
    ): vector<vector<u8>> {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow(market_index);
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());

        let liquidity_pool = lp_pool::get_liquidity_pool(pool_registry, pool_index);
        let collateral_token = type_name::get<C_TOKEN>();
        liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let symbol_market = object_table::borrow<TypeName, SymbolMarket>(&market.symbol_markets, base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());
        let user_positions = &symbol_market.user_positions;
        let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, type_name::get<C_TOKEN>());

        let mut result = vector::empty();
        // iter to find position
        user_positions.do_ref!<u64, Position>(|position_id, position| {
            let is_option_position = position.is_option_collateral_position();
            let position_collateral_token_type = position::get_position_collateral_token_type(position);
            if (get_all && position_collateral_token_type == collateral_token) {
                let liquidation_info = if (is_option_position) {
                    let (dov_index, bid_token) = position.get_position_option_collateral_info();
                    LiquidationInfo {
                        position_id,
                        dov_index: option::some(dov_index),
                        bid_token: option::some(bid_token),
                    }
                } else {
                    LiquidationInfo {
                        position_id,
                        dov_index: option::none(),
                        bid_token: option::none(),
                    }
                };
                result.push_back(bcs::to_bytes(&liquidation_info));
            } else {
                let trading_fee_mbp = calculate_trading_fee_rate_mbp(
                    // infos
                    symbol_market.market_info.user_long_position_size,
                    symbol_market.market_info.user_short_position_size,
                    lp_pool::get_token_pool_state(liquidity_pool, collateral_token)[1],
                    symbol_market.market_info.size_decimal,
                    trading_pair_oracle_price,
                    trading_pair_oracle_price_decimal,
                    // condition & config
                    !position.get_position_side(),
                    position.get_position_size(),
                    get_trading_fee_config(&symbol_market.market_config, is_option_position)
                );
                let liquidated = if (position_collateral_token_type == collateral_token) {
                    if (is_option_position) {
                        position::check_option_collateral_position_liquidated<C_TOKEN>(
                            dov_registry,
                            typus_oracle_trading_symbol,
                            typus_oracle_c_token,
                            position,
                            collateral_oracle_price,
                            collateral_oracle_price_decimal,
                            trading_pair_oracle_price,
                            trading_pair_oracle_price_decimal,
                            trading_fee_mbp,
                            math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_MAINTENANCE_MARGIN_RATE_BP),
                            cumulative_borrow_rate,
                            clock
                        )
                    } else {
                        position::check_position_liquidated(
                            position,
                            collateral_oracle_price,
                            collateral_oracle_price_decimal,
                            trading_pair_oracle_price,
                            trading_pair_oracle_price_decimal,
                            trading_fee_mbp,
                            math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAINTENANCE_MARGIN_RATE_BP),
                            cumulative_borrow_rate,
                            symbol_market.market_info.cumulative_funding_rate_index_sign,
                            symbol_market.market_info.cumulative_funding_rate_index
                        )
                    }
                } else {
                    false
                };
                if (liquidated) {
                    let liquidation_info = if (is_option_position) {
                        let (dov_index, bid_token) = position.get_position_option_collateral_info();
                        LiquidationInfo {
                            position_id,
                            dov_index: option::some(dov_index),
                            bid_token: option::some(bid_token),
                        }
                    } else {
                        LiquidationInfo {
                            position_id,
                            dov_index: option::none(),
                            bid_token: option::none(),
                        }
                    };
                    result.push_back(bcs::to_bytes(&liquidation_info));
                };
            };
        });
        result
    }

    public struct LiquidateEvent has copy, drop {
        user: address,
        collateral_token: TypeName,
        base_token: TypeName,
        position_id: u64,
        collateral_price: u64,
        trading_price: u64,
        realized_liquidator_fee: u64,
        realized_value_for_lp_pool: u64,
        u64_padding: vector<u64> // [position_size, estimated_liquidation_price]
    }
    public fun liquidate<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        market_index: u64,
        pool_index: u64,
        clock: &Clock,
        // other parameters
        position_id: u64,
        ctx: &mut TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());

        lp_pool::update_borrow_info(version, pool_registry, pool_index, clock);

        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
        let collateral_token = type_name::get<C_TOKEN>();
        liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));

        let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, collateral_token);

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];

        position::update_position_borrow_rate_and_funding_rate(
            mut_position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate,
            symbol_market.market_info.cumulative_funding_rate_index_sign,
            symbol_market.market_info.cumulative_funding_rate_index
        );
        let is_option_position = mut_position.is_option_collateral_position();
        let trading_fee_mbp = calculate_trading_fee_rate_mbp(
            // infos
            symbol_market.market_info.user_long_position_size,
            symbol_market.market_info.user_short_position_size,
            lp_pool::get_token_pool_state(liquidity_pool, type_name::get<C_TOKEN>())[1],
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            !mut_position.get_position_side(),
            mut_position.get_position_size(),
            get_trading_fee_config(&symbol_market.market_config, is_option_position)
        );
        // calculate estimated_liquidation_price
        let is_same_token = object::id_address(typus_oracle_c_token) == object::id_address(typus_oracle_trading_symbol);
        let estimated_liquidation_price = position::get_estimated_liquidation_price(
            mut_position,
            is_same_token,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
            if (mut_position.is_option_collateral_position()) {
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_MAINTENANCE_MARGIN_RATE_BP)
            } else {
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAINTENANCE_MARGIN_RATE_BP)
            },
        );

        let liquidated = if (is_option_position) {
            let (_, bid_token) = mut_position.get_position_option_collateral_info();
            assert!(bid_token == type_name::get<B_TOKEN>(), error::bid_token_mismatched());
            position::check_option_collateral_position_liquidated<C_TOKEN>(
                dov_registry,
                typus_oracle_trading_symbol,
                typus_oracle_c_token,
                mut_position,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
                trading_fee_mbp,
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_MAINTENANCE_MARGIN_RATE_BP),
                cumulative_borrow_rate,
                clock
            )
        } else {
            position::check_position_liquidated(
                mut_position,
                collateral_oracle_price,
                collateral_oracle_price_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal,
                trading_fee_mbp,
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAINTENANCE_MARGIN_RATE_BP),
                cumulative_borrow_rate,
                symbol_market.market_info.cumulative_funding_rate_index_sign,
                symbol_market.market_info.cumulative_funding_rate_index
            )
        };
        if (liquidated) {
            // remove position
            let position = keyed_big_vector::swap_remove_by_key<u64, Position>(&mut symbol_market.user_positions, position_id);
            let position_size = position.get_position_size();
            let user = position.get_position_user();
            let position_id = position.get_position_id();
            let is_long_position = position.get_position_side();
            let reserve_amount = position.get_reserve_amount();

            let position_notional_value_usd = amount_to_usd(
                position_size,
                position::get_position_size_decimal(&position),
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal
            );
            let liquidator_fee_usd = ((position_notional_value_usd as u128) * (C_LIQUIDATOR_FEE_BP as u128) / 10000 as u64);
            let liquidator_fee = usd_to_amount(
                liquidator_fee_usd,
                position::get_position_collateral_token_decimal(&position),
                collateral_oracle_price,
                collateral_oracle_price_decimal
            );

            // update lp pool reserve (release reserve)
            lp_pool::order_filled<C_TOKEN>(liquidity_pool, false, reserve_amount, balance::zero<C_TOKEN>());

            // update market info
            adjust_market_info_user_position_size(symbol_market, !is_long_position, true, position_size);

            // move balance to lp loop
            let mut unrealized_liquidator_fee = liquidator_fee;
            if (is_option_position) {
                let (
                    bid_receipts,
                    _linked_order_ids,
                    _linked_order_prices,
                    unrealized_loss,
                    unrealized_funding_sign,
                    unrealized_funding_fee,
                    unrealized_trading_fee,
                    unrealized_borrow_fee,
                    _rebate
                ) = position::remove_position_with_bid_receipts(version, position);

                let (mut exercise_balance, returned_bid_receipts) = exercise_bid_receipts<C_TOKEN, B_TOKEN>(
                    dov_registry,
                    bid_receipts,
                    ctx,
                );
                let charged_value = if (unrealized_liquidator_fee > 0) {
                    let charged_value = std::u64::min(exercise_balance.value(), unrealized_liquidator_fee);
                    let liquidator_fee_balance = exercise_balance.split(charged_value);
                    admin::charge_liquidator_fee(version, liquidator_fee_balance);
                    unrealized_liquidator_fee = unrealized_liquidator_fee - charged_value;
                    charged_value
                } else { 0 };
                let realized_value_for_lp_pool = exercise_balance.value();
                lp_pool::put_collateral(liquidity_pool, exercise_balance, collateral_oracle_price, collateral_oracle_price_decimal);
                if (returned_bid_receipts.length() > 0) {
                    let unsettled_bid_receipt = escrow::create_unsettled_bid_receipt(
                        returned_bid_receipts,
                        position_id,
                        user,
                        vector[type_name::get<C_TOKEN>(), type_name::get<B_TOKEN>()],
                        false,
                        unrealized_loss,
                        unrealized_trading_fee,
                        unrealized_borrow_fee,
                        unrealized_funding_sign,
                        unrealized_funding_fee,
                        unrealized_liquidator_fee,
                    );
                    lp_pool::put_receipt_collaterals(liquidity_pool, vector[unsettled_bid_receipt]);
                } else {
                    returned_bid_receipts.destroy_empty();
                };

                emit(LiquidateEvent {
                    user,
                    collateral_token: type_name::get<C_TOKEN>(),
                    base_token,
                    position_id,
                    collateral_price: collateral_oracle_price,
                    trading_price: trading_pair_oracle_price,
                    realized_liquidator_fee: charged_value,
                    realized_value_for_lp_pool,
                    u64_padding: vector[position_size, estimated_liquidation_price]
                });
            } else {
                let (mut balance, realized_cost_balance, linked_order_ids, linked_order_prices) = position::remove_position<C_TOKEN>(version, position);
                // remove orders in linked_order_ids
                let collaterals = remove_linked_orders<C_TOKEN>(version,
                    market_index,
                    symbol_market,
                    linked_order_ids,
                    linked_order_prices,
                    user
                );
                return_to_user(&mut market.id, collaterals, user, ctx);

                let charged_value = std::u64::min(balance.value(), unrealized_liquidator_fee);
                let liquidator_fee_balance = balance.split(charged_value);
                admin::charge_liquidator_fee(version, liquidator_fee_balance);

                balance.join(realized_cost_balance);
                let realized_value_for_lp_pool = balance.value();

                lp_pool::put_collateral(liquidity_pool, balance, collateral_oracle_price, collateral_oracle_price_decimal);

                emit(LiquidateEvent {
                    user,
                    collateral_token: type_name::get<C_TOKEN>(),
                    base_token,
                    position_id,
                    collateral_price: collateral_oracle_price,
                    trading_price: trading_pair_oracle_price,
                    realized_liquidator_fee: charged_value, // protocol fee
                    realized_value_for_lp_pool,
                    u64_padding: vector[position_size, estimated_liquidation_price]
                });
            };
        };
    }

    public struct SettleReceiptCollateralEvent has copy, drop {
        user: address,
        collateral_token: TypeName,
        bid_token: TypeName,
        position_id: u64,
        realized_liquidator_fee: u64,
        remaining_unrealized_sign: bool,
        remaining_unrealized_value: u64,
        remaining_value_for_lp_pool: u64,
        u64_padding: vector<u64>
    }
    public fun settle_receipt_collateral<C_TOKEN, B_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        ctx: &mut TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow_mut(market_index);
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());

        let liquidity_pool = lp_pool::get_mut_liquidity_pool(pool_registry, pool_index);
        let collateral_token = type_name::get<C_TOKEN>();
        let bid_token = type_name::get<B_TOKEN>();
        liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);

        let mut receipt_collateral = lp_pool::get_receipt_collateral(liquidity_pool);
        let mut unexpired_receipts = vector::empty();
        while (receipt_collateral.length() > 0) {
            let unsettled_bid_receipt = receipt_collateral.pop_back();
            let (
                bid_receipts,
                position_id,
                user,
                token_types,
                unrealized_pnl_sign,
                unrealized_pnl,
                unrealized_trading_fee,
                unrealized_borrow_fee,
                unrealized_funding_fee_sign,
                unrealized_funding_fee,
                unrealized_liquidator_fee
            ) = escrow::destruct_unsettled_bid_receipt(unsettled_bid_receipt);

            let expired = {
                let mut expired = true;
                bid_receipts.do_ref!(|bid_receipt|{
                    if (!typus_dov_single::check_bid_receipt_expired(dov_registry, bid_receipt)) {
                        expired = false;
                    };
                });
                expired
            };
            if (expired && collateral_token == token_types[0] && bid_token == token_types[1]) {
                let (mut exercise_balance, returned_bid_receipts) = exercise_bid_receipts<C_TOKEN, B_TOKEN>(
                    dov_registry,
                    bid_receipts,
                    ctx
                );
                returned_bid_receipts.destroy_empty();

                let liquidator_charged_value = std::u64::min(exercise_balance.value(), unrealized_liquidator_fee);
                let liquidator_fee_balance = exercise_balance.split(liquidator_charged_value);
                admin::charge_liquidator_fee(version, liquidator_fee_balance);

                let remaining_balance_value = exercise_balance.value();
                let (unrealized_sign, unrealized_value) = {
                    let mut sign = false;
                    let mut value = unrealized_trading_fee + unrealized_borrow_fee;
                    if (unrealized_pnl_sign) {
                        // if (sign) {
                        //     value = value + unrealized_pnl;
                        // } else {
                            if (value > unrealized_pnl) {
                                value = value - unrealized_pnl;
                            } else {
                                value = unrealized_pnl - value;
                                sign = true;
                            };
                        // };
                    } else {
                        // if (sign) {
                        //     if (value > unrealized_pnl) {
                        //         value = value - unrealized_pnl;
                        //     } else {
                        //         value = unrealized_pnl - value;
                        //         sign = false;
                        //     };
                        //     value = value + unrealized_pnl;
                        // } else {
                            value = value + unrealized_pnl;
                        // };
                    };
                    if (unrealized_funding_fee_sign) {
                        if (sign) {
                            value = value + unrealized_funding_fee;
                        } else {
                            if (value > unrealized_funding_fee) {
                                value = value - unrealized_funding_fee;
                            } else {
                                value = unrealized_funding_fee - value;
                                sign = true;
                            };
                        };
                    } else {
                        if (sign) {
                            if (value > unrealized_funding_fee) {
                                value = value - unrealized_funding_fee;
                            } else {
                                value = unrealized_funding_fee - value;
                                sign = false;
                            };
                            value = value + unrealized_funding_fee;
                        } else {
                            value = value + unrealized_funding_fee;
                        };
                    };
                    (sign, value)
                };
                lp_pool::put_collateral(liquidity_pool, exercise_balance, collateral_oracle_price, collateral_oracle_price_decimal);

                emit(SettleReceiptCollateralEvent {
                    user,
                    collateral_token,
                    bid_token,
                    position_id,
                    realized_liquidator_fee: liquidator_charged_value,
                    remaining_unrealized_sign: unrealized_sign,
                    remaining_unrealized_value: unrealized_value,
                    remaining_value_for_lp_pool: remaining_balance_value,
                    u64_padding: vector::empty()
                });
            } else {
                unexpired_receipts.push_back(escrow::create_unsettled_bid_receipt(
                    bid_receipts,
                    position_id,
                    user,
                    token_types,
                    unrealized_pnl_sign,
                    unrealized_pnl,
                    unrealized_trading_fee,
                    unrealized_borrow_fee,
                    unrealized_funding_fee_sign,
                    unrealized_funding_fee,
                    unrealized_liquidator_fee,
                ));
            };
        };
        lp_pool::put_receipt_collaterals(liquidity_pool, unexpired_receipts);
        receipt_collateral.destroy_empty();
    }

    // Manager account updates funding every period
    public struct UpdateFundingRateEvent has copy, drop {
        base_token: TypeName,
        new_funding_ts_ms: u64,
        intervals_count: u64,
        previous_cumulative_funding_rate_index_sign: bool,
        previous_cumulative_funding_rate_index: u64,
        cumulative_funding_rate_index_sign: bool,
        cumulative_funding_rate_index: u64,
        u64_padding: vector<u64>
    }
    public fun update_funding_rate<BASE_TOKEN>(
        // for share objects
        version: &Version,
        registry: &mut MarketRegistry,
        pool_registry: &PoolRegistry,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow_mut(market_index);
        let base_token = type_name::get<BASE_TOKEN>();
        assert!(vector::contains(&market.symbols, &base_token), error::trading_symbol_not_existed());
        let symbol_market = object_table::borrow_mut<TypeName, SymbolMarket>(&mut market.symbol_markets, base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());

        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let last_funding_ts_ms = symbol_market.market_info.last_funding_ts_ms;
        let current_ts_ms = clock::timestamp_ms(clock);
        let funding_ts_ms = current_ts_ms / symbol_market.market_config.funding_interval_ts_ms * symbol_market.market_config.funding_interval_ts_ms;
        if (funding_ts_ms > last_funding_ts_ms) {
            let previous_cumulative_funding_rate_index_sign = symbol_market.market_info.cumulative_funding_rate_index_sign;
            let previous_cumulative_funding_rate_index = symbol_market.market_info.cumulative_funding_rate_index;
            let intervals_count = (funding_ts_ms - last_funding_ts_ms) / symbol_market.market_config.funding_interval_ts_ms;
            let liquidity_pool = lp_pool::get_liquidity_pool(pool_registry, pool_index);
            let tvl_usd = lp_pool::get_tvl_usd(liquidity_pool);
            let exposure_amount = if (symbol_market.market_info.user_long_position_size > symbol_market.market_info.user_short_position_size) {
                symbol_market.market_info.user_long_position_size - symbol_market.market_info.user_short_position_size
            } else {
                symbol_market.market_info.user_short_position_size - symbol_market.market_info.user_long_position_size
            };
            let exposure_usd = amount_to_usd(
                exposure_amount,
                symbol_market.market_info.size_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal
            );
            let mut funding_increment = if (tvl_usd > 0) {
                ((symbol_market.market_config.basic_funding_rate as u128) * (exposure_usd as u128) / (tvl_usd as u128) as u64)
            } else {
                0
            };
            funding_increment = funding_increment * intervals_count;
            symbol_market.market_info.previous_last_funding_ts_ms = symbol_market.market_info.last_funding_ts_ms;
            symbol_market.market_info.previous_cumulative_funding_rate_index_sign = symbol_market.market_info.cumulative_funding_rate_index_sign;
            symbol_market.market_info.previous_cumulative_funding_rate_index = symbol_market.market_info.cumulative_funding_rate_index;
            symbol_market.market_info.last_funding_ts_ms = funding_ts_ms;
            // longs should pay funding to shorts => add index
            if (symbol_market.market_info.user_long_position_size > symbol_market.market_info.user_short_position_size) {
                if (symbol_market.market_info.cumulative_funding_rate_index_sign) {
                    symbol_market.market_info.cumulative_funding_rate_index
                        = symbol_market.market_info.cumulative_funding_rate_index + funding_increment;
                } else {
                    if (symbol_market.market_info.cumulative_funding_rate_index > funding_increment) {
                        symbol_market.market_info.cumulative_funding_rate_index
                            = symbol_market.market_info.cumulative_funding_rate_index - funding_increment;
                    } else {
                        symbol_market.market_info.cumulative_funding_rate_index = funding_increment - symbol_market.market_info.cumulative_funding_rate_index;
                        symbol_market.market_info.cumulative_funding_rate_index_sign = true;
                    };
                };
            // shorts should pay funding to longs => reduce index
            } else {
                if (symbol_market.market_info.cumulative_funding_rate_index_sign) {
                    if (symbol_market.market_info.cumulative_funding_rate_index >= funding_increment) {
                        symbol_market.market_info.cumulative_funding_rate_index
                            = symbol_market.market_info.cumulative_funding_rate_index - funding_increment;
                    } else {
                        symbol_market.market_info.cumulative_funding_rate_index
                            = funding_increment - symbol_market.market_info.cumulative_funding_rate_index;
                        symbol_market.market_info.cumulative_funding_rate_index_sign = false;
                    };
                } else {
                    symbol_market.market_info.cumulative_funding_rate_index
                        = symbol_market.market_info.cumulative_funding_rate_index + funding_increment;
                };
            };
            emit(UpdateFundingRateEvent {
                base_token,
                new_funding_ts_ms: funding_ts_ms,
                intervals_count,
                previous_cumulative_funding_rate_index_sign,
                previous_cumulative_funding_rate_index,
                cumulative_funding_rate_index_sign: symbol_market.market_info.cumulative_funding_rate_index_sign,
                cumulative_funding_rate_index: symbol_market.market_info.cumulative_funding_rate_index,
                u64_padding: vector::empty()
            });
        };
    }

    public struct ExpiredPositionInfo has copy, drop {
        position_id: u64,
        dov_index: u64,
        collateral_token: TypeName,
        bid_token: TypeName,
        base_token: TypeName
    }
    public(package) fun get_expired_position_info(
        // for share objects
        version: &Version,
        registry: &MarketRegistry,
        pool_registry: &PoolRegistry,
        dov_registry: &DovRegistry,
        market_index: u64,
        pool_index: u64,
        ctx: &TxContext
    ): vector<vector<u8>> {
        // safety check
        admin::verify(version, ctx);

        let market = registry.markets.borrow(market_index);
        assert!(market.lp_token_type == lp_pool::get_lp_token_type(pool_registry, pool_index), error::lp_token_type_mismatched());

        let mut result = vector::empty();
        market.symbols.do!(|base_token| {
            let symbol_market = object_table::borrow<TypeName, SymbolMarket>(&market.symbol_markets, base_token);
            let user_positions = &symbol_market.user_positions;
            user_positions.do_ref!<u64, Position>(|position_id, position| {
                if (position.is_option_collateral_position()) {
                    let bid_receipts_expired = position::option_position_bid_receipts_expired(dov_registry, position);
                    if (bid_receipts_expired) {
                        let (dov_index, bid_token) = position.get_position_option_collateral_info();
                        let collateral_token = position.get_position_collateral_token_type();
                        let expired_position_info = ExpiredPositionInfo {
                            position_id,
                            dov_index,
                            collateral_token,
                            bid_token,
                            base_token
                        };
                        result.push_back(bcs::to_bytes(&expired_position_info));
                    };
                };
            });
        });

        result
    }

    // authoriy function
    entry fun init_user_account_table(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        ctx: &mut TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);
        let market_id = registry.get_mut_market_id(market_index);
        dynamic_field::add(market_id, string::utf8(K_USER_ACCOUNTS), object_table::new<address, UserAccount>(ctx));
    }

    // user function
    public fun create_user_account(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        ctx: &mut TxContext,
    ): UserAccountCap {
        // safety check
        admin::version_check(version);

        let market_id = registry.get_mut_market_id(market_index);

        let user_accounts: &mut ObjectTable<address, UserAccount> = dynamic_field::borrow_mut(market_id, string::utf8(K_USER_ACCOUNTS));
        // check already exist
        assert!(!user_accounts.contains(ctx.sender()), error::invalid_user_account());

        let (user_account, user_account_cap) = user_account::new_user_account(ctx);
        object_table::add(user_accounts, ctx.sender(), user_account);

        user_account_cap
    }

    // user function
    entry fun add_delegate_user(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        user: address,
        ctx: &TxContext,
    ) {
        // safety check
        admin::version_check(version);

        let market_id = registry.get_mut_market_id(market_index);
        let user_account = user_account::get_mut_user_account(market_id, ctx.sender());
        // check only owner can deposit
        user_account.check_owner(ctx); // abort inside

        user_account.add_delegate_user(user);
    }

    // user function
    entry fun remove_user_account(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        user_account_cap: UserAccountCap,
    ) {
        // safety check
        admin::version_check(version);

        let market_id = registry.get_mut_market_id(market_index);
        // use the owner of user_account_cap to withdraw
        let owner = user_account_cap.get_user_account_owner();
        user_account::remove_user_account(market_id, owner, user_account_cap);
    }

    entry fun deposit_user_account<C_TOKEN>(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        collateral: Coin<C_TOKEN>,
        ctx: &TxContext,
    ) {
        // safety check
        admin::version_check(version);

        let market_id = registry.get_mut_market_id(market_index);
        let user_account = user_account::get_mut_user_account(market_id, ctx.sender());
        // check only owner can deposit
        user_account.check_owner(ctx); // abort inside

        user_account.deposit(collateral.into_balance());
    }

    public fun withdraw_user_account<C_TOKEN>(
        version: &Version,
        registry: &mut MarketRegistry,
        market_index: u64,
        amount: Option<u64>,
        user_account_cap: &UserAccountCap,
        ctx: &mut TxContext,
    ): Coin<C_TOKEN> {
        // safety check
        admin::version_check(version);

        let market_id = registry.get_mut_market_id(market_index);
        // use the owner of user_account_cap to withdraw
        let owner = user_account_cap.get_user_account_owner();
        let user_account = user_account::get_mut_user_account(market_id, owner);

        // check authority with user_account_cap
        let balance = user_account.withdraw(amount, user_account_cap);
        coin::from_balance(balance, ctx)
    }

    // public struct WithdrawReferralRebateEvent has copy, drop {
    //     rebate_token: TypeName,
    //     amount: u64,
    //     u64_padding: vector<u64>
    // }
    // public fun withdraw_referral_rebate<TOKEN>(
    //     version: &Version,
    //     registry: &mut MarketRegistry,
    //     ctx: &mut TxContext
    // ): Coin<TOKEN> {
    //     // user function
    //     let user = tx_context::sender(ctx);
    //     // safety check
    //     admin::version_check(version);

    //     let referrals = dynamic_object_field::borrow_mut<String, Referrals>(&mut registry.referral_registry, string::utf8(K_REFERRAL));
    //     let token_type = type_name::get<TOKEN>();
    //     let token_rebates = referrals.rebates.borrow_mut(token_type);

    //     let rebate_balance = dynamic_field::borrow_mut<TypeName, Balance<TOKEN>>(
    //         &mut referrals.id,
    //         token_type
    //     ).split(
    //         *token_rebates.borrow(user)
    //     );
    //     *token_rebates.borrow_mut(user) = 0;
    //     emit(WithdrawReferralRebateEvent {
    //         rebate_token: token_type,
    //         amount: rebate_balance.value(),
    //         u64_padding: vector::empty()
    //     });
    //     coin::from_balanc(rebate_balance, ctx)
    // }

    fun execute_order_<C_TOKEN>(
        version: &mut Version,
        // referrals: &mut Referrals,
        market_index: u64,
        symbol_market: &mut SymbolMarket,
        liquidity_pool: &mut LiquidityPool,
        order: TradingOrder,
        protocol_fee_share_bp: u64,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Balance<C_TOKEN>, vector<u64>, vector<u64>) {
        let user = position::get_order_user(&order);
        let linked_position_id = position::get_order_linked_position_id(&order);
        let is_long = position::get_order_side(&order);
        let (original_position, original_reserve) = get_linked_position(symbol_market, linked_position_id, user);
        let (original_position_size, original_position_side) = if (original_position.is_some()) {
            (option::some(original_position.borrow().get_position_size()), option::some(original_position.borrow().get_position_side()))
        } else {
            (option::none(), option::none())
        };

        let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, type_name::get<C_TOKEN>());


        let order_size = order.get_order_size();
        let actual_order_size = if (option::is_some(&original_position)) {
            let position_size = original_position.borrow().get_position_size();
            if (position_size > order_size) { order_size } else { position_size }
        } else { order_size };
        let trading_fee_mbp = calculate_trading_fee_rate_mbp(
            // infos
            symbol_market.market_info.user_long_position_size,
            symbol_market.market_info.user_short_position_size,
            lp_pool::get_token_pool_state(liquidity_pool, type_name::get<C_TOKEN>())[1],
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            is_long,
            actual_order_size,
            symbol_market.market_config.trading_fee_config,
        );

        // let (fee_rebate_bp, fee_reduction_bp) = if (referrals.referrals.contains(user)) {
        //     let referral_info = referrals.referrals.borrow(user);
        //     (referral_info.fee_rebate_bp, referral_info.fee_reduction_bp)
        // } else { (0, 0) };
        // let (_fee_rebate_bp, fee_reduction_bp) = (0, 0);

        // let trading_fee_rate = ((symbol_market.market_config.trading_fee_rate as u128)
        //                             * ((10000 - fee_reduction_bp) as u128)
        //                                 / 10000 as u64);

        let (
            mut position,
            loss_value_to_realize,
            // mut fee_balance,
            profit_value_to_realize,
            trading_fee_usd,
        ) = position::order_filled<C_TOKEN>(
            version,
            typus_ecosystem_version,
            typus_leaderboard_registry,
            tails_staking_registry,
            competition_config,
            order,
            original_position,
            symbol_market.market_info.next_position_id,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate,
            symbol_market.market_info.cumulative_funding_rate_index_sign,
            symbol_market.market_info.cumulative_funding_rate_index,
            trading_fee_mbp,
            clock,
            ctx
        );

        let mut realized_profit = position::realize_position_pnl_and_fee<C_TOKEN>(
            version,
            liquidity_pool,
            &mut position,
            profit_value_to_realize,
            loss_value_to_realize,
            original_reserve,
            protocol_fee_share_bp,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
        );

        // put referral rebate
        // let fee_balance_value = fee_balance.value();
        // let rebate_balance_value = ((fee_balance_value as u128)
        //     * (fee_rebate_bp as u128)
        //         / 10000 as u64);
        // if (rebate_balance_value > 0 ) {
        //     let referral_info = referrals.referrals.borrow(user);
        //     put_referral_rebate(referrals, fee_balance.split(rebate_balance_value), referral_info.invited_from, ctx);
        // };



        // add tails exp
        admin::add_tails_exp_and_leaderboard(
            version,
            typus_ecosystem_version,
            typus_user_registry,
            typus_leaderboard_registry,
            user,
            trading_fee_usd,
            symbol_market.market_config.exp_multiplier,
            clock,
            ctx
        );

        // update market info
        if (
            position::get_position_id(&position) == symbol_market.market_info.next_position_id
        ) {
            symbol_market.market_info.next_position_id = symbol_market.market_info.next_position_id + 1;
        };
        if (original_position_size.is_some()) {
            let original_size = *original_position_size.borrow();
            let original_side = *original_position_side.borrow();
            adjust_market_info_user_position_size(symbol_market, !original_side, true, original_size);
            let new_size = position.get_position_size();
            let new_side = position.get_position_side();
            if (new_size > 0) {
                adjust_market_info_user_position_size(symbol_market, new_side, false, new_size);
            };
        } else {
            adjust_market_info_user_position_size(symbol_market, is_long, false, order_size);
        };

        // put position into market (remove position if position.size == 0)
        let (linked_order_ids, linked_order_prices) = if (position::get_position_size(&position) == 0) {
            let (remaining_balance, realized_cost_balance, linked_order_ids, linked_order_prices) = position::remove_position<C_TOKEN>(version, position);
            // remove orders in linked_order_ids
            let collaterals = remove_linked_orders<C_TOKEN>(
                version,
                market_index,
                symbol_market,
                linked_order_ids,
                linked_order_prices,
                user
            );
            realized_profit.join(remaining_balance);
            realized_profit.join(collaterals);
            lp_pool::put_collateral(liquidity_pool, realized_cost_balance, collateral_oracle_price, collateral_oracle_price_decimal);
            (linked_order_ids, linked_order_prices)
        } else {
            // add position
            keyed_big_vector::push_back(&mut symbol_market.user_positions, position.get_position_id(), position);
            (vector::empty(), vector::empty())
        };
        (realized_profit, linked_order_ids, linked_order_prices)
    }

    public struct RealizeOptionPositionEvent has copy, drop {
        position_user: address,
        position_id: u64,
        trading_symbol: TypeName,
        realize_balance_token_type: TypeName,
        exercise_balance_value: u64, // user_remaining_value + realized_loss_value + fee_value
        user_remaining_value: u64,
        user_remaining_in_usd: u64,
        realized_loss_value: u64,
        fee_value: u64, // realized_trading_fee + realized_borrow_fee (includs protocol fee)
        realized_trading_fee: u64, // theoretical
        realized_borrow_fee: u64,  // theoretical
        u64_padding: vector<u64>
    }

    fun execute_option_collateral_order_<C_TOKEN, B_TOKEN>(
        version: &mut Version,
        // referrals: &mut Referrals,
        dov_registry: &mut DovRegistry,
        typus_oracle_trading_symbol: &Oracle,
        typus_oracle_c_token: &Oracle,
        symbol_market: &mut SymbolMarket,
        liquidity_pool: &mut LiquidityPool,
        order: TradingOrder,
        protocol_fee_share_bp: u64,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let user = position::get_order_user(&order);
        let linked_position_id = position::get_order_linked_position_id(&order);
        let size = position::get_order_size(&order);
        let is_long = position::get_order_side(&order);
        let reduce_only = position::get_order_reduce_only(&order);
        let (original_position, original_reserve) = get_linked_position(symbol_market, linked_position_id, user);

        let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, type_name::get<C_TOKEN>());

        // let (fee_rebate_bp, fee_reduction_bp) = if (referrals.referrals.contains(user)) {
        //     let referral_info = referrals.referrals.borrow(user);
        //     (referral_info.fee_rebate_bp, referral_info.fee_reduction_bp)
        // } else { (0, 0) };
        // let (fee_rebate_bp, fee_reduction_bp) = (0, 0);

        // let trading_fee_rate = ((symbol_market.market_config.trading_fee_rate as u128)
        //                             * ((10000 - fee_reduction_bp) as u128)
        //                                 / 10000 as u64);

        // let fee_usd;
        let (
            position,
            mut realized_loss_balance,
            mut realized_fee_balance,
            realized_rebate_balance,
            realized_profit,
            trading_fee_usd
        ) = position::order_filled_with_bid_receipts_collateral<C_TOKEN, B_TOKEN>(
            version,
            typus_ecosystem_version,
            typus_leaderboard_registry,
            tails_staking_registry,
            competition_config,
            liquidity_pool,
            dov_registry,
            typus_oracle_trading_symbol,
            typus_oracle_c_token,
            order,
            original_position,
            symbol_market.market_info.next_position_id,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate,
            symbol_market.market_info.cumulative_funding_rate_index_sign,
            symbol_market.market_info.cumulative_funding_rate_index,
            trading_fee_mbp,
            0,
            clock,
            ctx
        );
        realized_rebate_balance.destroy_zero();

        // option collateral position does not realized funding here due to no field for storing C_TOKEN collateral
        // and no Balance<C_TOKEN> to pay for funding

        // put referral rebate
        // let referral_info = referrals.referrals.borrow(user);
        // put_referral_rebate(referrals, realized_rebate_balance, referral_info.invited_from, ctx);

        let realized_fee_value = realized_fee_balance.value();
        let shared_balance = realized_fee_balance.split(
            ((realized_fee_value as u128)
                * (protocol_fee_share_bp as u128)
                    / 10000 as u64)
        );
        admin::charge_fee(version, shared_balance);
        realized_loss_balance.join(realized_fee_balance);

        // deal with pnl balance and update lp pool reserve
        let reserve_amount = position::get_reserve_amount(&position);
        lp_pool::order_filled<C_TOKEN>(
            liquidity_pool,
            reserve_amount > original_reserve,
            if (reserve_amount > original_reserve) {
                reserve_amount - original_reserve
            } else {
                original_reserve - reserve_amount
            },
            realized_loss_balance
        );
        // user_account not support for option collateral order
        transfer::public_transfer(
            coin::from_balance(realized_profit, ctx),
            position::get_position_user(&position)
        );

        // add tails exp
        admin::add_tails_exp_and_leaderboard(
            version,
            typus_ecosystem_version,
            typus_user_registry,
            typus_leaderboard_registry,
            user,
            trading_fee_usd,
            symbol_market.market_config.exp_multiplier,
            clock,
            ctx
        );

        // update market info
        if (
            position::get_position_id(&position) == symbol_market.market_info.next_position_id
        ) {
            symbol_market.market_info.next_position_id = symbol_market.market_info.next_position_id + 1;
        };
        adjust_market_info_user_position_size(symbol_market, is_long, reduce_only, size);

        // if size = 0 => remove_position, else if size != 0 => put position
        if (position.get_position_size() > 0) {
            keyed_big_vector::push_back(&mut symbol_market.user_positions, position.get_position_id(), position);
        } else {
            let position_collateral_token_type = position.get_position_collateral_token_type();
            let position_symbol = position.get_position_symbol();
            let position_id = position.get_position_id();
            let position_user = position.get_position_user();
            let collateral_token_decimal = position::get_position_collateral_token_decimal(&position);
            let (
                bid_receipts,
                _linked_order_ids,
                _linked_order_prices,
                unrealized_loss_value,
                unrealized_funding_sign,
                unrealized_funding_fee_value,
                unrealized_trading_fee_value,
                unrealized_borrow_fee_value,
                _unrealized_rebate
            ) = position::remove_position_with_bid_receipts(version, position);

            // exercise expired receipts and return active receipts to user
            let (mut exercise_balance, mut returned_bid_receipts) = exercise_bid_receipts<C_TOKEN, B_TOKEN>(
                dov_registry,
                bid_receipts,
                ctx,
            );
            if (returned_bid_receipts.length() > 0) {
                // not yet expired, return to user
                while (returned_bid_receipts.length() > 0) {
                    transfer::public_transfer(returned_bid_receipts.pop_back(), user);
                };
                exercise_balance.destroy_zero();
                returned_bid_receipts.destroy_empty();
            } else {
                returned_bid_receipts.destroy_empty();

                // realized funding fee
                let exercise_balance_value = exercise_balance.value();
                if (unrealized_funding_fee_value > 0) {
                    // 1. charge from exercise_balance -> put balance into lp pool liquidity
                    let realized_funding_fee = if (unrealized_funding_sign) {
                        let funding_balance = exercise_balance.split(
                            if (exercise_balance_value >= unrealized_funding_fee_value) {
                                unrealized_funding_fee_value
                            } else { exercise_balance_value }
                        );
                        let realized_funding_fee = funding_balance.value();
                        lp_pool::put_collateral<C_TOKEN>(
                            liquidity_pool,
                            funding_balance,
                            collateral_oracle_price,
                            collateral_oracle_price_decimal,
                        );
                        realized_funding_fee
                    // 2. charge from lp pool -> put balance into exercise_balance
                    } else {
                        let funding_balance = lp_pool::request_collateral<C_TOKEN>(
                            liquidity_pool,
                            unrealized_funding_fee_value,
                            collateral_oracle_price,
                            collateral_oracle_price_decimal,
                        );
                        let realized_funding_fee = funding_balance.value();
                        exercise_balance.join(funding_balance);
                        realized_funding_fee
                    };

                    let realized_value_in_usd = amount_to_usd(
                        realized_funding_fee,
                    collateral_token_decimal,
                        collateral_oracle_price,
                        collateral_oracle_price_decimal
                    );

                    position::emit_realized_funding_event(
                        user,
                        position_collateral_token_type,
                        position_symbol,
                        position_id,
                        unrealized_funding_sign,
                        realized_funding_fee,
                        realized_value_in_usd,
                        vector::empty(),
                    );
                };

                // protocol share fee splitted from exercise_balance

                // 1. split unrealized_loss_value
                assert!(exercise_balance.value() >= unrealized_loss_value,error::balance_not_enough_for_paying_fee());
                let mut user_remaining_value = exercise_balance.value() - unrealized_loss_value;

                // 2. split fee (including protocol share)
                let fee_value = if (user_remaining_value >= unrealized_trading_fee_value + unrealized_borrow_fee_value) {
                    unrealized_trading_fee_value + unrealized_borrow_fee_value
                } else {
                    user_remaining_value
                };
                user_remaining_value = user_remaining_value - fee_value;

                // 3. split protocol share
                let protocol_fee_value = ((fee_value as u128) * (protocol_fee_share_bp as u128) / 10000 as u64);
                let protocol_fee_balance = exercise_balance.split(protocol_fee_value);
                admin::charge_fee(version, protocol_fee_balance);

                // split cost_balance for lp_pool
                let user_remaining_balance = exercise_balance.split(user_remaining_value);
                lp_pool::put_collateral(liquidity_pool, exercise_balance, collateral_oracle_price, collateral_oracle_price_decimal);

                let user_remaining_in_usd = amount_to_usd(
                    user_remaining_value,
                    collateral_token_decimal,
                    collateral_oracle_price,
                    collateral_oracle_price_decimal
                );

                emit(RealizeOptionPositionEvent {
                    position_user,
                    position_id,
                    trading_symbol: position_symbol.base_token(),
                    realize_balance_token_type: position_collateral_token_type,
                    exercise_balance_value,
                    user_remaining_value,
                    user_remaining_in_usd,
                    realized_loss_value: unrealized_loss_value,
                    fee_value,
                    realized_trading_fee: unrealized_trading_fee_value,
                    realized_borrow_fee: unrealized_borrow_fee_value,
                    u64_padding: vector::empty()
                });

                // split rebate
                // let invited_from = referrals.referrals.borrow(user).invited_from;
                // let rebate_balance = exercise_balance.split(
                //     if (exercise_balance.value() >= unrealized_rebate) {
                //         unrealized_rebate
                //     } else {exercise_balance.value()}
                // );
                // put_referral_rebate(referrals, rebate_balance, invited_from, ctx);

                // transfer remaining balance back to user
                if (user_remaining_balance.value() > 0) {
                    // user_account not support for option collateral order
                    transfer::public_transfer(coin::from_balance(user_remaining_balance, ctx), user);
                } else {
                    balance::destroy_zero(user_remaining_balance);
                };
            };
        };
    }

    fun remove_linked_orders<C_TOKEN>(
        version: &Version,
        market_index: u64,
        symbol_market: &mut SymbolMarket,
        mut linked_order_ids: vector<u64>,
        mut linked_order_prices: vector<u64>,
        user: address
    ): Balance<C_TOKEN> {
        let mut balance = balance::zero<C_TOKEN>();
        while (linked_order_ids.length() > 0) {
            let order_id = linked_order_ids.pop_back();
            let order_price = linked_order_prices.pop_back();
            let mut order = take_order_by_order_id_and_price(
                symbol_market,
                order_price,
                order_id,
                true,
                user,
            );
            if (order.is_some()) {
                let collateral = remove_linked_order_<C_TOKEN>(
                    version,
                    market_index,
                    symbol_market,
                    order.extract(),
                    user
                );
                balance.join(collateral);
            };
            order.destroy_none();
        };
        balance
    }

    fun remove_linked_order_<C_TOKEN>(
        version: &Version,
        market_index: u64,
        symbol_market: &mut SymbolMarket,
        order: TradingOrder,
        user: address
    ): Balance<C_TOKEN> {
        let (base_token, _quote_token) = order.get_order_trading_symbol();
        let trigger_price = order.get_order_price();
        // update market info order size
        let is_long = order.get_order_side();
        let order_size = order.get_order_size();
        let order_id = order.get_order_id();
        adjust_market_info_user_order_size(symbol_market, is_long, true, order_size);
        // remove order and join collateral
        let collateral = position::remove_order<C_TOKEN>(version, order);
        let released_collateral_amount = collateral.value();
        emit(CancelTradingOrderEvent {
            user,
            market_index,
            order_id,
            trigger_price,
            collateral_token: type_name::get<C_TOKEN>(),
            base_token,
            released_collateral_amount,
            u64_padding: vector::empty()
        });
        collateral
    }

    fun get_mut_orders(symbol_market: &mut SymbolMarket, is_token_collateral: bool, order_type_tag: u8): &mut VecMap<u64, vector<TradingOrder>> {
        // order_type_tag: limit buy = 0, limit sell = 1, stop buy = 2, stop sell = 3
        if (is_token_collateral) {
            if (order_type_tag == 0) {
                return dynamic_field::borrow_mut<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.token_collateral_orders, string::utf8(K_LIMIT_BUY_ORDERS))
            } else if (order_type_tag == 1) {
                return dynamic_field::borrow_mut<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.token_collateral_orders, string::utf8(K_LIMIT_SELL_ORDERS))
            } else if (order_type_tag == 2) {
                return dynamic_field::borrow_mut<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.token_collateral_orders, string::utf8(K_STOP_BUY_ORDERS))
            } else if (order_type_tag == 3) {
                return dynamic_field::borrow_mut<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.token_collateral_orders, string::utf8(K_STOP_SELL_ORDERS))
            };
        } else {
            if (order_type_tag == 0) {
                return dynamic_field::borrow_mut<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.option_collateral_orders, string::utf8(K_LIMIT_BUY_ORDERS))
            } else if (order_type_tag == 1) {
                return dynamic_field::borrow_mut<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.option_collateral_orders, string::utf8(K_LIMIT_SELL_ORDERS))
            } else if (order_type_tag == 2) {
                return dynamic_field::borrow_mut<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.option_collateral_orders, string::utf8(K_STOP_BUY_ORDERS))
            } else if (order_type_tag == 3) {
                return dynamic_field::borrow_mut<String, VecMap<u64, vector<TradingOrder>>>(&mut symbol_market.option_collateral_orders, string::utf8(K_STOP_SELL_ORDERS))
            };
        };
        abort error::unsupported_order_type_tag()
    }

    fun get_orders(symbol_market: &SymbolMarket, is_token_collateral: bool, order_type_tag: u8): &VecMap<u64, vector<TradingOrder>> {
        // order_type_tag: limit buy = 0, limit sell = 1, stop buy = 2, stop sell = 3
        if (is_token_collateral) {
            if (order_type_tag == 0) {
                return dynamic_field::borrow<String, VecMap<u64, vector<TradingOrder>>>(&symbol_market.token_collateral_orders, string::utf8(K_LIMIT_BUY_ORDERS))
            } else if (order_type_tag == 1) {
                return dynamic_field::borrow<String, VecMap<u64, vector<TradingOrder>>>(&symbol_market.token_collateral_orders, string::utf8(K_LIMIT_SELL_ORDERS))
            } else if (order_type_tag == 2) {
                return dynamic_field::borrow<String, VecMap<u64, vector<TradingOrder>>>(&symbol_market.token_collateral_orders, string::utf8(K_STOP_BUY_ORDERS))
            } else if (order_type_tag == 3) {
                return dynamic_field::borrow<String, VecMap<u64, vector<TradingOrder>>>(&symbol_market.token_collateral_orders, string::utf8(K_STOP_SELL_ORDERS))
            };
        } else {
            if (order_type_tag == 0) {
                return dynamic_field::borrow<String, VecMap<u64, vector<TradingOrder>>>(&symbol_market.option_collateral_orders, string::utf8(K_LIMIT_BUY_ORDERS))
            } else if (order_type_tag == 1) {
                return dynamic_field::borrow<String, VecMap<u64, vector<TradingOrder>>>(&symbol_market.option_collateral_orders, string::utf8(K_LIMIT_SELL_ORDERS))
            } else if (order_type_tag == 2) {
                return dynamic_field::borrow<String, VecMap<u64, vector<TradingOrder>>>(&symbol_market.option_collateral_orders, string::utf8(K_STOP_BUY_ORDERS))
            } else if (order_type_tag == 3) {
                return dynamic_field::borrow<String, VecMap<u64, vector<TradingOrder>>>(&symbol_market.option_collateral_orders, string::utf8(K_STOP_SELL_ORDERS))
            };
        };
        abort error::unsupported_order_type_tag()
    }

    fun take_order_by_order_id_and_price(
        symbol_market: &mut SymbolMarket,
        trigger_price: u64,
        order_id: u64,
        is_token_collateral: bool,
        user: address,
    ): Option<TradingOrder> {
        let mut user_order = option::none();
        let mut i = 0;
        let max_order_type_tag = position::get_max_order_type_tag();
        while (i <= max_order_type_tag) {
            let active_orders_vec_map = get_mut_orders(symbol_market, is_token_collateral, i); // VecMap<u64, vector<TradingOrder>>
            if (active_orders_vec_map.contains(&trigger_price)) {
                let (_, mut active_orders) = active_orders_vec_map.remove(&trigger_price); // vector<TradingOrder>
                let mut j = 0;
                let length = active_orders.length();
                while (j < length) {
                    if (&active_orders[j].get_order_id() == order_id && &active_orders[j].get_order_user() == user) {
                        let order = active_orders.remove(j);
                        user_order.fill(order);
                        break
                    };
                    j = j + 1;
                };
                if (active_orders.length() == 0) {
                    vector::destroy_empty(active_orders);
                } else {
                    active_orders_vec_map.insert(trigger_price, active_orders);
                };
                if (user_order.is_some()) {
                    break
                };
            };
            i = i + 1;
        };

        user_order
    }

    fun get_linked_position(
        symbol_market: &mut SymbolMarket,
        mut linked_position_id: Option<u64>,
        user: address
    ): (Option<Position>, u64) {
        if (option::is_some(&linked_position_id)) {
            let position_id = linked_position_id.extract();
            let position = keyed_big_vector::swap_remove_by_key<u64, Position>(&mut symbol_market.user_positions, position_id);
            check_position_user_matched(&position, user);
            let reserve_amount = position.get_reserve_amount();
            (option::some(position), reserve_amount)
        } else { (option::none(), 0) }
    }

    fun check_collateral_enough_when_adding_position<C_TOKEN>(
        symbol_market: &SymbolMarket,
        order: &TradingOrder,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
    ): bool {
        let user = position::get_order_user(order);
        let order_collateral_amount = position::get_order_collateral_amount<C_TOKEN>(order);

        let mut linked_position_id = position::get_order_linked_position_id(order);
        let position_collateral_amount = if (linked_position_id.is_some()) {
            let position_id = linked_position_id.extract();
            let position: &Position = &symbol_market.user_positions[position_id];
            check_position_user_matched(position, user);
            let collateral_amount = position::get_position_collateral_amount<C_TOKEN>(position);
            collateral_amount
        } else { 0 };

        let order_filled_fee = position::get_order_filled_fee(
            order,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
        );
        order_collateral_amount + position_collateral_amount > order_filled_fee
    }

    fun check_collateral_enough_when_reducing_position<C_TOKEN>(
        symbol_market: &SymbolMarket,
        order: &TradingOrder,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
    ): bool {
        let user = position::get_order_user(order);
        let order_collateral_amount = position::get_order_collateral_amount<C_TOKEN>(order);

        let mut linked_position_id = position::get_order_linked_position_id(order);

        let position_id = linked_position_id.extract(); // linked_position_id should always be "some"
        let position: &Position = &symbol_market.user_positions[position_id];
        check_position_user_matched(position, user);
        let position_collateral_amount = position.get_position_collateral_amount<C_TOKEN>();
        // unrealized_pnl_sign: true => profit, false => loss
        let (unrealized_pnl_sign, unrealized_pnl_w_fee_usd, fee_usd) = position.calculate_unrealized_pnl(
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
        );
        let actual_trading_fee = position::get_order_filled_fee(
            order,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
        );
        if (unrealized_pnl_sign) {
            let unrealized_profit_usd = unrealized_pnl_w_fee_usd + fee_usd;
            let unrealized_profit = usd_to_amount(
                unrealized_profit_usd,
                position.get_position_collateral_token_decimal(),
                collateral_oracle_price,
                collateral_oracle_price_decimal
            );
            order_collateral_amount + position_collateral_amount + unrealized_profit > actual_trading_fee
        } else {
            // unrealized_pnl: loss
            if (unrealized_pnl_w_fee_usd >= fee_usd) {
                let unrealized_loss_usd = unrealized_pnl_w_fee_usd - fee_usd;
                let unrealized_loss = usd_to_amount(
                    unrealized_loss_usd,
                    position.get_position_collateral_token_decimal(),
                    collateral_oracle_price,
                    collateral_oracle_price_decimal
                );
                order_collateral_amount + position_collateral_amount > unrealized_loss + actual_trading_fee
            } else {
                // unrealized_pnl => profit, unrealized_pnl_usd - fee_usd => loss
                let unrealized_profit_usd = fee_usd - unrealized_pnl_w_fee_usd;
                let unrealized_profit = usd_to_amount(
                    unrealized_profit_usd,
                    position.get_position_collateral_token_decimal(),
                    collateral_oracle_price,
                    collateral_oracle_price_decimal
                );
                order_collateral_amount + position_collateral_amount + unrealized_profit > actual_trading_fee
            }
        }
    }

    fun check_option_collateral_enough<C_TOKEN>(
        dov_registry: &DovRegistry,
        typus_oracle_trading_symbol: &Oracle,
        typus_oracle_c_token: &Oracle,
        symbol_market: &SymbolMarket,
        order: &TradingOrder,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        trading_fee_mbp: u64,
        clock: &Clock,
    ): bool {
        let user = position::get_order_user(order);
        let order_collateral_amount = position::get_option_collateral_order_collateral_amount<C_TOKEN>(
            dov_registry,
            typus_oracle_trading_symbol,
            typus_oracle_c_token,
            order,
            clock
        );

        let mut linked_position_id = position::get_order_linked_position_id(order);
        let position_collateral_amount = if (linked_position_id.is_some()) {
            let position_id = linked_position_id.extract();
            let position: &Position = &symbol_market.user_positions[position_id];
            check_position_user_matched(position, user);
            let collateral_amount = position::get_option_position_collateral_amount<C_TOKEN>(
                dov_registry,
                typus_oracle_trading_symbol,
                typus_oracle_c_token,
                position,
                clock
            );
            collateral_amount
        } else { 0 };

        let order_filled_fee = position::get_order_filled_fee(
            order,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
        );
        order_collateral_amount + position_collateral_amount > order_filled_fee
    }

    fun check_reserve_enough<C_TOKEN>(
        symbol_market: &SymbolMarket,
        liquidity_pool: &LiquidityPool,
        order: &TradingOrder,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
    ): bool {
        if (position::get_order_reduce_only(order)) {
            true
        } else {
            let collateral_token = type_name::get<C_TOKEN>();
            let order_size = position::get_order_size(order);

            let token_pool_state = lp_pool::get_token_pool_state(liquidity_pool, collateral_token);
            let liquidity_amount = token_pool_state[0];
            let reserved_amount = token_pool_state[2];

            let mut linked_position_id = position::get_order_linked_position_id(order);
            let mut reserve_amount_before_filled = 0;

            let order_reserve_usd = if (linked_position_id.is_some()) {
                let position_id = linked_position_id.extract();
                let position: &Position = &symbol_market.user_positions[position_id];
                reserve_amount_before_filled = position::get_reserve_amount(position);
                let position_size = position::get_position_size(position);
                let position_size_decimal = position::get_position_size_decimal(position);
                amount_to_usd(
                    position_size + order_size,
                    position_size_decimal,
                    trading_pair_oracle_price,
                    trading_pair_oracle_price_decimal
                )
            } else {
                amount_to_usd(
                    order_size,
                    symbol_market.market_info.size_decimal,
                    trading_pair_oracle_price,
                    trading_pair_oracle_price_decimal
                )
            };
            let reserve_amount_after_filled = usd_to_amount(
                    order_reserve_usd,
                    position::get_order_collateral_token_decimal(order),
                    collateral_oracle_price,
                    collateral_oracle_price_decimal
                );

            if (reserve_amount_after_filled > reserve_amount_before_filled) {
                liquidity_amount >= reserved_amount + (reserve_amount_after_filled - reserve_amount_before_filled)
            } else { true }
        }
    }

    fun adjust_market_info_user_order_size(
        symbol_market: &mut SymbolMarket,
        long: bool,
        filled_or_cancelled: bool,
        size: u64,
    ) {
        if (long) {
            symbol_market.market_info.user_long_order_size = if (filled_or_cancelled) {
                symbol_market.market_info.user_long_order_size - size
            } else { symbol_market.market_info.user_long_order_size + size };
        } else {
            symbol_market.market_info.user_short_order_size = if (filled_or_cancelled) {
                symbol_market.market_info.user_short_order_size - size
            } else { symbol_market.market_info.user_short_order_size + size };
        };
    }

    fun adjust_market_info_user_position_size(
        symbol_market: &mut SymbolMarket,
        filled_order_is_long: bool,
        reducing_position: bool,
        size: u64,
    ) {
        if (reducing_position) {
            if (filled_order_is_long) {
                symbol_market.market_info.user_short_position_size = symbol_market.market_info.user_short_position_size - size;
            } else {
                symbol_market.market_info.user_long_position_size = symbol_market.market_info.user_long_position_size - size;
            };
        } else {
            if (filled_order_is_long) {
                symbol_market.market_info.user_long_position_size = symbol_market.market_info.user_long_position_size + size;
            } else {
                symbol_market.market_info.user_short_position_size = symbol_market.market_info.user_short_position_size + size;
            };
        };
    }

    fun exercise_bid_receipts<C_TOKEN, B_TOKEN>(
        dov_registry: &mut DovRegistry,
        mut bid_receipts: vector<TypusBidReceipt>,
        ctx: &mut TxContext
    ): (Balance<C_TOKEN>, vector<TypusBidReceipt>) {
        let mut exercise_balance = balance::zero<C_TOKEN>();
        let mut returned_receipts = vector::empty();
        while (bid_receipts.length() > 0) {
            let bid_receipt = bid_receipts.pop_back();
            let expired = typus_dov_single::check_bid_receipt_expired(dov_registry, &bid_receipt);
            if (expired) {
                let (_, index, _) = vault::get_bid_receipt_info(&bid_receipt);
                let (balance, _log) = tds_user_entry::exercise<C_TOKEN, B_TOKEN>(
                    dov_registry,
                    index,
                    vector::singleton(bid_receipt),
                    ctx
                );
                exercise_balance.join(balance);
            } else {
                returned_receipts.push_back(bid_receipt);
            };
        };
        bid_receipts.destroy_empty();
        (exercise_balance, returned_receipts)
    }

    fun return_to_user<TOKEN>(market_id: &mut UID, balance: Balance<TOKEN>, user: address, ctx: &mut TxContext) {
        if (user_account::has_user_account(market_id, user)) {
            let user_account = user_account::get_mut_user_account(market_id, user);
            user_account.deposit(balance);
        } else {
            transfer::public_transfer(coin::from_balance(balance, ctx), user);
        };
    }

    fun check_position_user_matched(position: &Position, user: address) {
        assert!(position.get_position_user() == user, error::user_mismatched());
    }

    // ======= View Functions =======
    public(package) fun get_user_orders(
        version: &Version,
        registry: &MarketRegistry,
        market_index: u64,
        user: address,
    ): vector<vector<u8>> {
        admin::version_check(version);
        let mut user_orders = vector::empty<vector<u8>>();

        let market = registry.markets.borrow(market_index);
        let mut base_tokens = market.symbols;
        while (base_tokens.length() > 0) {
            let base_token = base_tokens.pop_back();
            let symbol_market = market.symbol_markets.borrow(base_token);
            let mut order_type_tag = 0;
            let max_order_type_tag = position::get_max_order_type_tag();
            while (order_type_tag <= max_order_type_tag) {
                let active_orders_vec_map = get_orders(symbol_market, true, order_type_tag);
                let mut keys = active_orders_vec_map.keys();
                // iter by order prices
                while (keys.length() > 0) {
                    let trigger_price = keys.pop_back();
                    let active_orders_per_price = active_orders_vec_map.get(&trigger_price);
                    let mut k = 0;
                    let length = active_orders_per_price.length();
                    while (k < length) {
                        let order = &active_orders_per_price[k];
                        if (position::get_order_user(order) == user) {
                            user_orders.push_back(bcs::to_bytes(order));
                        };
                        k = k + 1;
                    };
                };
                let active_orders_vec_map = get_orders(symbol_market, false, order_type_tag);
                let mut keys = active_orders_vec_map.keys();
                // iter by order prices
                while (keys.length() > 0) {
                    let trigger_price = keys.pop_back();
                    let active_orders_per_price = active_orders_vec_map.get(&trigger_price);
                    let mut k = 0;
                    let length = active_orders_per_price.length();
                    while (k < length) {
                        let order = &active_orders_per_price[k];
                        if (position::get_order_user(order) == user) {
                            user_orders.push_back(bcs::to_bytes(order));
                        };
                        k = k + 1;
                    };
                };
                order_type_tag = order_type_tag + 1;
            };
        };
        user_orders
    }

    public(package) fun get_user_positions(
        version: &Version,
        registry: &MarketRegistry,
        market_index: u64,
        user: address,
    ): vector<vector<u8>> {
        admin::version_check(version);
        let mut result = vector::empty<vector<u8>>();

        let market = registry.markets.borrow(market_index);
        let mut base_tokens = market.symbols;
        while (base_tokens.length() > 0) {
            let base_token = base_tokens.pop_back();
            let symbol_market = market.symbol_markets.borrow(base_token);
            let user_positions = &symbol_market.user_positions;
            // iter to find position
            user_positions.do_ref!<u64, Position>(|_position_id, position| {
                if (position.get_position_user() == user) {
                    result.push_back(bcs::to_bytes(position));
                };
            });
        };
        result
    }

    public(package) fun get_all_positions<TOKEN>(
        version: &Version,
        registry: &MarketRegistry,
        market_index: u64,
        slice: u64, // 100
        page: u64, // start from 1
    ): vector<vector<u8>> {
        admin::version_check(version);
        let mut result = vector::empty<vector<u8>>();

        let market = registry.markets.borrow(market_index);
        let base_token = type_name::get<TOKEN>();
        let symbol_market = market.symbol_markets.borrow(base_token);
        let user_positions = &symbol_market.user_positions;
        let length = user_positions.length();
        let max_page = if (length / slice * slice == length) {
            length / slice
        } else {
            length / slice + 1
        };
        if (length == 0) {
            let max_page = 0 as u64;
            result.push_back(bcs::to_bytes(&max_page));
            return result
        };
        let mut i = (page - 1) * slice;
        let end_i = page * slice - 1;
        while (i <= end_i) {
            if (i < length) {
                let (_position_id, position) = user_positions.borrow<u64, Position>(i);
                result.push_back(bcs::to_bytes(position));
            } else {
                break
            };
          i = i + 1;
        };

        if (length > 0) {
            result.push_back(bcs::to_bytes(&max_page));
        };

        result
    }

    public(package) fun get_active_orders_by_order_tag<BASE_TOKEN>(
        version: &Version,
        registry: &MarketRegistry,
        market_index: u64,
        order_type_tag: u8,
    ): vector<vector<u8>> {
        admin::version_check(version);
        let mut active_orders = vector::empty<vector<u8>>();

        let market = registry.markets.borrow(market_index);
        let base_token = type_name::get<BASE_TOKEN>();
        let symbol_market = market.symbol_markets.borrow(base_token);

        let active_orders_vec_map = get_orders(symbol_market, true, order_type_tag); // &mut VecMap<u64, vector<TradingOrder>>
        let mut keys = active_orders_vec_map.keys();
        // iter by order prices
        while (keys.length() > 0) {
            let trigger_price = keys.pop_back();
            let active_orders_per_price = active_orders_vec_map.get(&trigger_price);
            let mut k = 0;
            let length = active_orders_per_price.length();
            while (k < length) {
                let order = &active_orders_per_price[k];
                active_orders.push_back(bcs::to_bytes(order));
                k = k + 1;
            };
        };
        active_orders
    }

    public(package) fun get_active_orders_by_order_tag_and_ctoken<C_TOKEN, BASE_TOKEN>(
        version: &Version,
        registry: &MarketRegistry,
        market_index: u64,
        order_type_tag: u8,
    ): vector<vector<u8>> {
        admin::version_check(version);
        let collateral_token = type_name::get<C_TOKEN>();
        let mut active_orders = vector::empty<vector<u8>>();

        let market = registry.markets.borrow(market_index);
        let base_token = type_name::get<BASE_TOKEN>();
        let symbol_market = market.symbol_markets.borrow(base_token);

        let active_orders_vec_map = get_orders(symbol_market, true, order_type_tag); // &mut VecMap<u64, vector<TradingOrder>>
        let mut keys = active_orders_vec_map.keys();
        // iter by order prices
        while (keys.length() > 0) {
            let trigger_price = keys.pop_back();
            let active_orders_per_price = active_orders_vec_map.get(&trigger_price);
            let mut k = 0;
            let length = active_orders_per_price.length();
            while (k < length) {
                let order = &active_orders_per_price[k];
                if (position::get_order_collateral_token(order) == collateral_token) {
                    active_orders.push_back(bcs::to_bytes(order));
                };
                k = k + 1;
            };
        };
        active_orders
    }

    public(package) fun get_max_releasing_collateral_amount<C_TOKEN, BASE_TOKEN>(
        version: &Version,
        registry: &MarketRegistry,
        pool_registry: &PoolRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        position_id: u64,
    ): u64 {
        admin::version_check(version);
        let market = registry.markets.borrow(market_index);
        let base_token = type_name::get<BASE_TOKEN>();
        let symbol_market = market.symbol_markets.borrow(base_token);
        assert!(symbol_market.market_config.oracle_id == object::id_address(typus_oracle_trading_symbol), error::oracle_mismatched());
        let position: &Position = &symbol_market.user_positions[position_id];

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let liquidity_pool = lp_pool::get_liquidity_pool(pool_registry, pool_index);
        let collateral_token = type_name::get<C_TOKEN>();
        liquidity_pool.safety_check(collateral_token, object::id_address(typus_oracle_c_token));
        let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, collateral_token);
        let trading_fee_mbp = calculate_trading_fee_rate_mbp(
            // infos
            symbol_market.market_info.user_long_position_size,
            symbol_market.market_info.user_short_position_size,
            lp_pool::get_token_pool_state(liquidity_pool, collateral_token)[1],
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            !position.get_position_side(),
            position.get_position_size(),
            symbol_market.market_config.trading_fee_config,
        );
        position::max_releasing_collateral_amount(
            position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
            cumulative_borrow_rate,
            symbol_market.market_config.max_leverage_mbp,
        )
    }

    public(package) fun get_estimated_liquidation_price_and_pnl<C_TOKEN, BASE_TOKEN>(
        version: &Version,
        registry: &mut MarketRegistry,
        pool_registry: &PoolRegistry,
        dov_registry: &DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        market_index: u64,
        pool_index: u64,
        clock: &Clock,
        position_id: u64,
    ): (u64, bool, u64, bool, u64, bool, u64, u64, u64) {
        admin::version_check(version);
        let market = registry.markets.borrow_mut(market_index);
        let base_token = type_name::get<BASE_TOKEN>();
        let symbol_market = market.symbol_markets.borrow_mut(base_token);
        let mut_position: &mut Position = &mut symbol_market.user_positions[position_id];

        let (collateral_oracle_price, collateral_oracle_price_decimal) = typus_oracle_c_token.get_price_with_interval_ms(clock, 0);
        let (trading_pair_oracle_price, trading_pair_oracle_price_decimal) = typus_oracle_trading_symbol.get_price_with_interval_ms(clock, 0);

        let liquidity_pool = lp_pool::get_liquidity_pool(pool_registry, pool_index);
        let cumulative_borrow_rate = lp_pool::get_cumulative_borrow_rate(liquidity_pool, type_name::get<C_TOKEN>());
        let is_option_position = mut_position.is_option_collateral_position();
        let trading_fee_mbp = calculate_trading_fee_rate_mbp(
            // infos
            symbol_market.market_info.user_long_position_size,
            symbol_market.market_info.user_short_position_size,
            lp_pool::get_token_pool_state(liquidity_pool, type_name::get<C_TOKEN>())[1],
            symbol_market.market_info.size_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            // condition & config
            !mut_position.get_position_side(),
            mut_position.get_position_size(),
            if (is_option_position) {
                vector[
                    math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_BASE_TRADING_FEE_MBP),
                    math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_MAX_TRADING_FEE_MBP),
                    math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_ALLOCATED_LP_EXPOSURE_MBP),
                ]
            } else {
                symbol_market.market_config.trading_fee_config
            },
        );

        if (is_option_position) {
            position::update_option_position_collateral_amount<C_TOKEN>(
                dov_registry,
                typus_oracle_trading_symbol,
                typus_oracle_c_token,
                mut_position,
                clock,
            );
        };

        let (unrealized_borrow_fee, unrealized_funding_sign, unrealized_funding_fee) = position::update_position_borrow_rate_and_funding_rate(
            mut_position,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            cumulative_borrow_rate,
            symbol_market.market_info.cumulative_funding_rate_index_sign,
            symbol_market.market_info.cumulative_funding_rate_index
        );

        let is_same_token = object::id_address(typus_oracle_c_token) == object::id_address(typus_oracle_trading_symbol);
        let estimated_liquidation_price = position::get_estimated_liquidation_price(
            mut_position,
            is_same_token,
            collateral_oracle_price,
            collateral_oracle_price_decimal,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
            if (mut_position.is_option_collateral_position()) {
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_OPTION_COLLATERAL_MAINTENANCE_MARGIN_RATE_BP)
            } else {
                math::get_u64_vector_value(&symbol_market.market_config.u64_padding, I_MAINTENANCE_MARGIN_RATE_BP)
            },
        );

        let (is_cost, position_unrealized_cost) = position::calculate_unrealized_cost(mut_position);
        let liquidity_token_decimal = lp_pool::get_liquidity_token_decimal(pool_registry, pool_index, type_name::get<C_TOKEN>());
        let unrealized_cost_in_usd = amount_to_usd(
            position_unrealized_cost,
            liquidity_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );

        let (has_profit, pnl_usd, close_fee_usd) = mut_position.calculate_unrealized_pnl(
            trading_pair_oracle_price,
            trading_pair_oracle_price_decimal,
            trading_fee_mbp,
        );

        let unrealized_borrow_fee_usd = amount_to_usd(
            unrealized_borrow_fee,
            liquidity_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );

        let unrealized_funding_fee_usd = amount_to_usd(
            unrealized_funding_fee,
            liquidity_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );

        (estimated_liquidation_price, has_profit, pnl_usd, is_cost, unrealized_cost_in_usd, unrealized_funding_sign, unrealized_funding_fee_usd, unrealized_borrow_fee_usd, close_fee_usd)
    }

    public(package) fun calculate_trading_fee_rate_mbp(
        // infos
        user_long_position_size: u64,
        user_short_position_size: u64,
        tvl_usd: u64,
        size_decimal: u64,
        trading_pair_oracle_price: u64,
        trading_pair_oracle_price_decimal: u64,
        // condition & config
        order_side: bool,
        order_size: u64,
        trading_fee_config: vector<u64>,
    ): u64 {
        let (lp_original_side, lp_original_size) = if (user_long_position_size > user_short_position_size) {
            (false, user_long_position_size - user_short_position_size)
        } else {
            (true, user_short_position_size - user_long_position_size)
        };
        let (_lp_new_side, lp_new_size) = if (lp_original_side == order_side) {
            if (lp_original_size > order_size) {
                (lp_original_side, lp_original_size - order_size)
            } else {
                (!lp_original_side, order_size - lp_original_size)
            }
        } else {
            (lp_original_side, lp_original_size + order_size)
        };
        // TODO: add fee rate into event
        if (lp_new_size <= lp_original_size) {
            trading_fee_config[I_BASE_TRADING_FEE_MBP]
        } else {
            let base_fee_mbp = trading_fee_config[I_BASE_TRADING_FEE_MBP];
            let max_fee_mbp = trading_fee_config[I_MAX_TRADING_FEE_MBP];
            let allocated_exposure_mbp = trading_fee_config[I_ALLOCATED_LP_EXPOSURE_MBP];

            let exposure_change = lp_new_size - lp_original_size;
            let exposure_change_usd = amount_to_usd(
                exposure_change,
                size_decimal,
                trading_pair_oracle_price,
                trading_pair_oracle_price_decimal
            );
            let allocated_exposure = ((tvl_usd as u128) * (allocated_exposure_mbp as u128) / 10000000 as u64);
            if (allocated_exposure > 0) {
                let exposure_change_rate_mbp = ((exposure_change_usd as u128)
                                                    * 10000000
                                                        / (allocated_exposure as u128) as u64);
                let fee_mbp = max_fee_mbp.min(
                    base_fee_mbp
                        + (((max_fee_mbp - base_fee_mbp) as u128) * (exposure_change_rate_mbp as u128) / 10000000 as u64)
                );
                fee_mbp
            } else {
                base_fee_mbp
            }
        }
    }

    // fun put_referral_rebate<TOKEN>(
    //     referrals: &mut Referrals,
    //     balance: Balance<TOKEN>,
    //     to_user: address,
    //     ctx: &mut TxContext
    // ) {
    //     let token_type = type_name::get<TOKEN>();
    //     if (!referrals.rebates.contains(token_type)) {
    //         referrals.rebates.add(token_type, table::new(ctx));
    //     };
    //     let token_rebates = referrals.rebates.borrow_mut(token_type);
    //     if (!token_rebates.contains(to_user)) {
    //         token_rebates.add(to_user, balance.value());
    //     } else {
    //         let user_rebates = token_rebates.borrow_mut(to_user);
    //         *user_rebates = *user_rebates + balance.value();
    //     };

    //     let rebate_pool_balance = dynamic_field::borrow_mut<TypeName, Balance<TOKEN>>(&mut referrals.id, token_type);
    //     rebate_pool_balance.join(balance);
    // }

    // fun map_order_price_to_fill(
    //     orders_vec_map: &VecMap<u64, vector<TradingOrder>>,
    //     max_leaf_price: u64,
    //     min_leaf_price: u64,
    //     order_type_tag: u8,
    //     trigger_price: u64,
    //     trading_pair_oracle_price: u64
    // ): (u64, u64) {
    //     let mut keys = orders_vec_map.keys();
    //     if (order_type_tag == 0) {
    //         // limit buy
    //         if (trigger_price >= trading_pair_oracle_price) {
    //             // trigger price = 100, trading_pair_oracle_price = 99 => filled at 99
    //             let (_, index) = critbit::find_leaf<vector<TradingOrder>>(orders_critbit, trigger_price);
    //             (trigger_price, index)
    //         } else {
    //             // trigger price = 98, trading_pair_oracle_price = 99 => not filled => find next (larger key)
    //             if (trigger_price < max_leaf_price) {
    //                 critbit::next_leaf<vector<TradingOrder>>(orders_critbit, trigger_price)
    //             } else {
    //                 // no orders to be filled
    //                 (0, C_U64_MAX)
    //             }
    //         }
    //     } else if (order_type_tag == 1) {
    //         // limit sell
    //         if (trigger_price <= trading_pair_oracle_price) {
    //             // trigger price = 99, trading_pair_oracle_price = 100 => filled at 100
    //             let (_, index) = critbit::find_leaf<vector<TradingOrder>>(orders_critbit, trigger_price);
    //             (trigger_price, index)
    //         } else {
    //             // trigger price = 100, trading_pair_oracle_price = 99 => not filled => find previous (smaller key)
    //             if (trigger_price > min_leaf_price) {
    //                 // trigger price = 98, trading_pair_oracle_price = 99 => filled at 99
    //                 critbit::previous_leaf<vector<TradingOrder>>(orders_critbit, trigger_price)
    //             } else {
    //                 // no orders to be filled
    //                 (0, C_U64_MAX)
    //             }
    //         }
    //     } else if (order_type_tag == 2) {
    //         // stop buy
    //         if (trigger_price <= trading_pair_oracle_price) {
    //             // trigger price = 99, trading_pair_oracle_price = 100 => filled at 100
    //             let (_, index) = critbit::find_leaf<vector<TradingOrder>>(orders_critbit, trigger_price);
    //             (trigger_price, index)
    //         } else {
    //             // trigger price = 100, trading_pair_oracle_price = 99 => not filled => find previous (smaller key)
    //             if (trigger_price > min_leaf_price) {
    //                 critbit::previous_leaf<vector<TradingOrder>>(orders_critbit, trigger_price)
    //             } else {
    //                 // no orders to be filled
    //                 (0, C_U64_MAX)
    //             }
    //         }
    //     } else if (order_type_tag == 3) {
    //         // stop sell
    //         if (trigger_price >= trading_pair_oracle_price) {
    //             // trigger price = 100, trading_pair_oracle_price = 99 => filled at 99
    //             let (_, index) = critbit::find_leaf<vector<TradingOrder>>(orders_critbit, trigger_price);
    //             (trigger_price, index)
    //         } else {
    //             // trigger price = 99, trading_pair_oracle_price = 100 => not filled => find next (larger key)
    //             if (trigger_price > max_leaf_price) {
    //                 // trigger price = 101, trading_pair_oracle_price = 100 => filled at 100
    //                 critbit::next_leaf<vector<TradingOrder>>(orders_critbit, trigger_price)
    //             } else {
    //                 // no orders to be filled
    //                 (0, C_U64_MAX)
    //             }
    //         }
    //     } else {
    //         abort error::unsupported_order_type_tag()
    //     }
    // }

    public(package) fun get_markets_bcs(
        registry: &MarketRegistry,
        indexes: vector<u64>,
    ): vector<vector<u8>> {
        let mut result = vector[];
        registry.markets.do_ref!<u64, Markets>(|index, markets| {
            if (indexes.length() == 0 || indexes.contains(&index)) {
                let bytes = bcs::to_bytes(markets);
                result.push_back(bytes);

                markets.symbols.do!(|symbol| {
                    let symbol_market = markets.symbol_markets.borrow(symbol);
                    let bytes = bcs::to_bytes(symbol_market);
                    result.push_back(bytes);
                });
            };
        });
        result
    }

    public(package) fun get_mut_market_id(
        registry: &mut MarketRegistry,
        market_index: u64,
    ): &mut UID {
        let market = registry.markets.borrow_mut(market_index);
        &mut market.id
    }

    // ======== Helper Functions ========

    public(package) fun trading_symbol_exists<BASE_TOKEN>(
        market: &Markets
    ): bool {
        market.symbol_markets.contains(type_name::get<BASE_TOKEN>())
    }

    fun deprecated() { abort 0 }
    #[allow(dead_code, unused_variable, unused_type_parameter, lint(self_transfer))]
    public fun create_trading_order<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        // order parameters
        linked_position_id: Option<u64>,
        collateral: Coin<C_TOKEN>, // collateral_amount: u64,
        reduce_only: bool,
        is_long: bool,
        is_stop_order: bool,
        size: u64,
        trigger_price: u64,
        ctx: &mut TxContext,
    ) {
        deprecated();
        transfer::public_transfer(collateral, tx_context::sender(ctx));
    }
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun match_trading_order<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        // other parameters
        order_type_tag: u8,
        trigger_price: u64,
        max_operation_count: u64,
        ctx: &mut TxContext
    ) {
        deprecated();
    }
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun manager_reduce_position<C_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        position_id: u64,
        reduced_ratio_bp: u64,
        ctx: &mut TxContext
    ) {
        deprecated();
    }
    #[allow(dead_code, unused_variable, unused_type_parameter, lint(self_transfer))]
    public fun create_trading_order_with_bid_receipt<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        // order parameters: linked_position_id should always be None in this function
        collateral_bid_receipt: TypusBidReceipt, // size: u64, dov_index: u64,
        is_long: bool,
        user: address,
        ctx: &mut TxContext,
    ) {
        deprecated();
        transfer::public_transfer(collateral_bid_receipt, tx_context::sender(ctx));
    }
    #[allow(dead_code, unused_variable, unused_type_parameter, lint(self_transfer))]
    public fun create_trading_order_with_bid_receipt_v2<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        // order parameters: linked_position_id should always be None in this function
        collateral_bid_receipt: TypusBidReceipt, // size: u64, dov_index: u64,
        is_long: bool,
        user: address,
        ctx: &mut TxContext,
    ) {
        deprecated();
        transfer::public_transfer(collateral_bid_receipt, tx_context::sender(ctx));
    }
    #[allow(dead_code, unused_variable, unused_type_parameter, unused_let_mut)]
    public fun reduce_option_collateral_position_size<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        // position related arguments
        position_id: u64,
        mut order_size: Option<u64>, // in contract size decimal. if none => close position
        ctx: &mut TxContext,
    ) {
        deprecated();
    }
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun manager_remove_position<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        // other parameters
        position_id: u64,
        is_option_position: bool,
        process: RemoveLiquidityTokenProcess,
        ctx: &mut TxContext
    ): RemoveLiquidityTokenProcess {
        deprecated();
        process
    }
    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun manager_close_option_position<C_TOKEN, B_TOKEN, BASE_TOKEN>(
        // for share objects
        version: &mut Version,
        registry: &mut MarketRegistry,
        pool_registry: &mut PoolRegistry,
        dov_registry: &mut DovRegistry,
        typus_oracle_c_token: &Oracle,
        typus_oracle_trading_symbol: &Oracle,
        clock: &Clock,
        market_index: u64,
        pool_index: u64,
        // tails
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        // other parameters
        position_id: u64,
        ctx: &mut TxContext
    ) {
        deprecated();
    }
    // ======== Test Only Functions ========

    // #[test_only]
    // public(package) fun test_init(ctx: &mut TxContext) {
    //     init(ctx);
    // }

    // #[test_only]
    // public(package) fun test_get_market(
    //     registry: &MarketRegistry,
    //     index: u64,
    // ): &Markets {
    //     registry.markets.borrow(index)
    // }

    // #[test_only]
    // public(package) fun test_add_trading_symbol<BASE_TOKEN>(
    //     registry: &mut MarketRegistry,
    //     market_index: u64,
    //     // market info
    //     size_decimal: u64,
    //     // market config
    //     max_leverage_mbp: u64,
    //     option_collateral_max_leverage_mbp: u64,
    //     min_size: u64,
    //     lot_size: u64,
    //     trading_fee_config: vector<u64>,
    //     basic_funding_rate: u64,
    //     funding_interval_ts_ms: u64,
    //     exp_multiplier: u64,
    //     clock: &Clock,
    //     ctx: &mut TxContext,
    // ) {
    //     let oracle_id = object::id_address(registry); // create a fake id
    //     let market = registry.markets.borrow_mut(market_index);
    //     let base_token = type_name::get<BASE_TOKEN>();
    //     assert!(!vector::contains(&market.symbols, &base_token), error::trading_symbol_existed());

    //     // add into market.symbols
    //     vector::push_back(&mut market.symbols, base_token);

    //     // add into market.symbol_markets
    //     let market_info = MarketInfo {
    //         is_active: true,
    //         size_decimal,
    //         user_long_position_size: 0,
    //         user_short_position_size: 0,
    //         next_position_id: 0,
    //         user_long_order_size: 0,
    //         user_short_order_size: 0,
    //         next_order_id: 0,
    //         last_funding_ts_ms: clock::timestamp_ms(clock),
    //         cumulative_funding_rate_index_sign: true,
    //         cumulative_funding_rate_index: 0,
    //         previous_last_funding_ts_ms: clock::timestamp_ms(clock),
    //         previous_cumulative_funding_rate_index_sign: true,
    //         previous_cumulative_funding_rate_index: 0,
    //         u64_padding: vector::empty(),
    //     };
    //     let market_config = MarketConfig {
    //         oracle_id,
    //         max_leverage_mbp,
    //         option_collateral_max_leverage_mbp,
    //         min_size,
    //         lot_size,
    //         trading_fee_config,
    //         basic_funding_rate,
    //         funding_interval_ts_ms,
    //         exp_multiplier,
    //         u64_padding: vector::empty(),
    //     };
    //     let mut symbol_market = SymbolMarket {
    //         id: object::new(ctx),
    //         user_positions: keyed_big_vector::new<u64, Position>(1000, ctx),
    //         token_collateral_orders: object::new(ctx),
    //         option_collateral_orders: object::new(ctx),
    //         market_info,
    //         market_config,
    //     };
    //     dynamic_field::add(&mut symbol_market.token_collateral_orders, string::utf8(K_LIMIT_BUY_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
    //     dynamic_field::add(&mut symbol_market.token_collateral_orders, string::utf8(K_LIMIT_SELL_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
    //     dynamic_field::add(&mut symbol_market.token_collateral_orders, string::utf8(K_STOP_BUY_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
    //     dynamic_field::add(&mut symbol_market.token_collateral_orders, string::utf8(K_STOP_SELL_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
    //     dynamic_field::add(&mut symbol_market.option_collateral_orders, string::utf8(K_LIMIT_BUY_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
    //     dynamic_field::add(&mut symbol_market.option_collateral_orders, string::utf8(K_LIMIT_SELL_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
    //     dynamic_field::add(&mut symbol_market.option_collateral_orders, string::utf8(K_STOP_BUY_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
    //     dynamic_field::add(&mut symbol_market.option_collateral_orders, string::utf8(K_STOP_SELL_ORDERS), vec_map::empty<u64, vector<TradingOrder>>());
    //     object_table::add(&mut market.symbol_markets, base_token, symbol_market);
    // }
}

// #[test_only]
// module typus_perp::test_trading {
//     // use std::type_name;

//     use sui::clock::{Self, Clock};
//     // use sui::coin::{Self, Coin};
//     use sui::sui::SUI;
//     use sui::test_scenario::{Scenario, begin, end, ctx, next_tx, take_shared, return_shared, sender};

//     use typus_perp::admin::{Self, Version};
//     // use typus_perp::math;
//     use typus_perp::tlp::TLP;
//     use typus_perp::trading::{Self, MarketRegistry};

//     const ADMIN: address = @0xFFFF;
//     // const USER_1: address = @0xBABE1;
//     // const USER_2: address = @0xBABE2;
//     const MARKET_INDEX: u64 = 0;
//     const TRADING_FEE_PROTOCOL_SHARE_BP: u64 = 3000;
//     // market info
//     const SIZE_DECIMAL: u64 = 9;
//     // market config
//     // const oracle: &PriceInfoObject = ;
//     const MAX_LEVERAGE_PCT: u64 = 10000;
//     const MIN_SIZE: u64 = 1_0000_00000;
//     const LOT_SIZE: u64 = 1_0000_00000;
//     const TRADING_FEE_RATE: u64 = 0_0010_00000;
//     const TRADING_FEE_DECIMAL: u64 = 9;
//     const BASIC_FUNDING_RATE: u64 = 0_0001_00000;

//     const CURRENT_TS_MS: u64 = 1_715_212_800_000;
//     const FUNDING_INTERVAL_TS_MS: u64 = 3_600_000;

//     public struct USD has drop {}

//     fun new_registry(scenario: &mut Scenario) {
//         trading::test_init(ctx(scenario));
//         next_tx(scenario, ADMIN);
//     }

//     fun new_version(scenario: &mut Scenario) {
//         admin::test_init(ctx(scenario));
//         next_tx(scenario, ADMIN);
//     }

//     fun new_clock(scenario: &mut Scenario): Clock {
//         let mut clock = clock::create_for_testing(ctx(scenario));
//         clock::set_for_testing(&mut clock, CURRENT_TS_MS);
//         clock
//     }

//     fun registry(scenario: &Scenario): MarketRegistry {
//         take_shared<MarketRegistry>(scenario)
//     }

//     fun version(scenario: &Scenario): Version {
//         take_shared<Version>(scenario)
//     }

//     // fun mint_test_coin<T>(scenario: &mut Scenario, amount: u64): Coin<T> {
//     //     coin::mint_for_testing<T>(amount, ctx(scenario))
//     // }

//     // fun update_clock(clock: &mut Clock, ts_ms: u64) {
//     //     clock::set_for_testing(clock, ts_ms);
//     // }

//     fun test_new_markets_(scenario: &mut Scenario) {
//         let mut registry = registry(scenario);
//         let version = version(scenario);
//         trading::new_markets<TLP, USD>(
//             &version,
//             &mut registry,
//             TRADING_FEE_PROTOCOL_SHARE_BP,
//             ctx(scenario)
//         );
//         return_shared(registry);
//         return_shared(version);
//         next_tx(scenario, ADMIN);
//     }

//     fun test_add_trading_symbol_<BASE_TOKEN>(scenario: &mut Scenario) {
//         let mut registry = registry(scenario);
//         let clock = new_clock(scenario);
//         trading::test_add_trading_symbol<BASE_TOKEN>(
//             &mut registry,
//             MARKET_INDEX,
//             // market info
//             SIZE_DECIMAL,
//             // market config
//             MAX_LEVERAGE_PCT,
//             MIN_SIZE,
//             LOT_SIZE,
//             TRADING_FEE_RATE,
//             TRADING_FEE_DECIMAL,
//             BASIC_FUNDING_RATE,
//             FUNDING_INTERVAL_TS_MS,
//             &clock,
//             ctx(scenario)
//         );
//         assert!(
//             trading::trading_symbol_exists<BASE_TOKEN>(
//                 trading::test_get_market(&registry, MARKET_INDEX)
//             ),
//             0
//         );
//         return_shared(registry);
//         clock::destroy_for_testing(clock);
//         next_tx(scenario, ADMIN);
//     }

//     #[test]
//     public(package) fun test_new_markets() {
//         let mut scenario = begin(ADMIN);
//         new_registry(&mut scenario);
//         new_version(&mut scenario);
//         test_new_markets_(&mut scenario);
//         end(scenario);
//     }

//     #[test]
//     public(package) fun test_add_incentive_token() {
//         let mut scenario = begin(ADMIN);
//         new_registry(&mut scenario);
//         new_version(&mut scenario);
//         test_new_markets_(&mut scenario);
//         test_add_trading_symbol_<SUI>(&mut scenario);
//         end(scenario);
//     }
// }