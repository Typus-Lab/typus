/// The `lp_pool` module is the heart of the TLP (Typus Liquidity Pool) logic.
/// It defines the structures for liquidity pools, token pools, and their configurations.
/// It also contains the entry functions for creating pools, adding liquidity, swapping, and redeeming.
module typus_perp::lp_pool {
    use std::string::{Self, String};
    use std::type_name::{Self, TypeName};
    use sui::balance::{Self, Balance};
    use sui::bcs;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::dynamic_object_field;
    use sui::event::emit;
    use sui::table::{Self, Table};

    use typus_perp::admin::{Self, Version};
    use typus_perp::error;
    use typus_perp::escrow::UnsettledBidReceipt;
    use typus_perp::lending;
    use typus_perp::math;
    // use typus_perp::token_interface;
    use typus_perp::treasury_caps::{Self, TreasuryCaps};

    use typus_dov::typus_dov_single::{Self, Registry as DovRegistry};

    use typus_oracle::oracle::Oracle;

    use protocol::reserve::MarketCoin;
    use protocol::version::Version as ScallopVersion;

    // use bucket_fountain::fountain_core::{Self, Fountain, StakeProof};
    // use bucket_protocol::buck::{Self, BucketProtocol, BUCK};
    // use 0x1798f84ee72176114ddbf5525a6d964c5f8ea1b3738d08d50d0d3de4cf584884::sbuck::{Self, SBUCK};

    // ======== Constants ========
    const C_BORROW_RATE_DECIMAL: u64 = 9;
    // const C_BUCKET_HARDCODE_LOCK_TIME: u64 = 4838400000;

    const C_MIN_TARGET_WEIGHT_BP: u64 = 0;
    const C_MAX_TARGET_WEIGHT_BP: u64 = 10000;
    const C_MIN_MIN_DEPOSIT: u64 = 0;
    const C_MIN_MAX_CAPACITY: u64 = 0;
    const C_MAX_BASIC_MINT_FEE_BP: u64 = 30;
    const C_MAX_ADDITIONAL_MINT_FEE_BP: u64 = 30;
    const C_MAX_BASIC_BURN_FEE_BP: u64 = 30;
    const C_MAX_ADDITIONAL_BURN_FEE_BP: u64 = 30;
    const C_MAX_SWAP_FEE_BP: u64 = 30;
    const C_MIN_BASIC_BORROW_RATE: u64 = 0;
    const C_MIN_UTILIZATION_THRESHOLD_BP: u64 = 0;
    const C_MAX_UTILIZATION_THRESHOLD_BP: u64 = 10000;
    const C_MAX_SWAP_FEE_PROTOCOL_SHARE_BP: u64 = 10000;
    const C_MAX_LENDING_PROTOCOL_SHARE_BP: u64 = 10000;
    const C_MIN_BORROW_INTERVAL_TS_MS: u64 = 0;
    const C_MIN_MAX_ORDER_RESERVE_RATIO_BP: u64 = 0;

    // ======== Structs ========
    /// A registry for all liquidity pools.
    public struct Registry has key {
        id: UID,
        /// The number of pools in the registry.
        num_pool: u64,
        /// The UID of the liquidity pool registry.
        liquidity_pool_registry: UID,
    }

    const I_TOTAL_DEACTIVATING_SHARES: u64 = 0; // index of LiquidityPool.u64_padding
    const I_UNLOCK_COUNTDOWN_TS_MS: u64 = 1; // index of LiquidityPool.u64_padding
    const I_REBALANCE_COST_THRESHOLD_BP: u64 = 2; // index of LiquidityPool.u64_padding
    /// The main struct for a liquidity pool.
    public struct LiquidityPool has key, store {
        /// The UID of the object. Token balances are dynamic fields under this id with TypeName key.
        id: UID,
        /// The index of the pool.
        index: u64,
        /// The type name of the LP token.
        lp_token_type: TypeName,
        /// A vector of the type names of the liquidity tokens.
        liquidity_tokens: vector<TypeName>,
        /// A vector of the token pools.
        token_pools: vector<TokenPool>,
        /// Information about the liquidity pool.
        pool_info: LiquidityPoolInfo,
        /// A vector of unsettled bid receipts from liquidations.
        liquidated_unsettled_receipts: vector<UnsettledBidReceipt>,
        /// Padding for future use.
        u64_padding: vector<u64>,
        /// Padding for future use.
        bcs_padding: vector<u8>,
    }

    /// A struct for a token within a liquidity pool.
    public struct TokenPool has store {
        /// The type name of the token.
        token_type: TypeName,
        /// The configuration for the token pool.
        config: Config,
        /// The state of the token pool.
        state: State,
    }

    /// Information about a liquidity pool.
    public struct LiquidityPoolInfo has copy, drop, store {
        /// The number of decimals for the LP token.
        lp_token_decimal: u64,
        /// The total supply of LP tokens.
        total_share_supply: u64, // total TLP amount
        /// The total value locked in the pool in USD.
        tvl_usd: u64,
        /// Whether the pool is active.
        is_active: bool,
    }

    /// Configuration for a token pool.
    public struct Config has copy, drop, store {
        /// The address of the oracle.
        oracle_id: address,
        /// The number of decimals for the liquidity token.
        liquidity_token_decimal: u64,
        /// The spot-related configuration for the token pool.
        spot_config: SpotConfig,
        /// The margin-related configuration for the token pool.
        margin_config: MarginConfig,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// Spot-related configuration for a token pool.
    public struct SpotConfig has copy, drop, store {
        /// The minimum deposit amount.
        min_deposit: u64,
        /// The maximum capacity of the pool.
        max_capacity: u64,
        // use these parameters to control TLP mint / burn fee
        /// The target weight of the token in the pool in basis points.
        target_weight_bp: u64,
        /// The basic mint fee in basis points.
        basic_mint_fee_bp: u64,
        /// The additional mint fee in basis points.
        additional_mint_fee_bp: u64,
        /// The basic burn fee in basis points.
        basic_burn_fee_bp: u64,
        /// The additional burn fee in basis points.
        additional_burn_fee_bp: u64,
        // swap related parameters
        /// The swap fee in basis points.
        swap_fee_bp: u64,
        /// The protocol's share of the swap fee in basis points.
        swap_fee_protocol_share_bp: u64,
        /// The protocol's share of the lending interest in basis points.
        lending_protocol_share_bp: u64,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    // tokens to borrow for open position
    /// Margin-related configuration for a token pool.
    public struct MarginConfig has copy, drop, store {
        // borrow related parameters
        /// The basic borrow rate at utilization 0.
        basic_borrow_rate_0: u64,
        /// The basic borrow rate at utilization 1.
        basic_borrow_rate_1: u64,
        /// The basic borrow rate at utilization 2.
        basic_borrow_rate_2: u64,
        /// The utilization threshold 0 in basis points.
        utilization_threshold_bp_0: u64,
        /// The utilization threshold 1 in basis points.
        utilization_threshold_bp_1: u64,
        /// The borrow interval in milliseconds.
        borrow_interval_ts_ms: u64,
        /// The maximum order reserve ratio in basis points.
        max_order_reserve_ratio_bp: u64,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// State of a token pool.
    public struct State has copy, drop, store {
        /// The amount of liquidity in the pool.
        liquidity_amount: u64,   // balance value
        /// The value of the liquidity in USD.
        value_in_usd: u64,       // amount / decimals * price (USD)
        /// The amount of liquidity reserved for open positions.
        reserved_amount: u64,      // = being used for opening position
        /// The timestamp of the last update to the value_in_usd.
        update_ts_ms: u64, // update value_in_usd (for tvl health)
        /// Whether the token pool is active.
        is_active: bool,
        // borrow related: use for recording margin trading borrow calculation
        /// The timestamp of the last borrow rate calculation.
        last_borrow_rate_ts_ms: u64,
        /// The cumulative borrow rate.
        cumulative_borrow_rate: u64,
        /// The previous timestamp of the last borrow rate calculation.
        previous_last_borrow_rate_ts_ms: u64,
        /// The previous cumulative borrow rate.
        previous_cumulative_borrow_rate: u64,
        /// The current lending amount.
        current_lending_amount: vector<u64>, // index = I_LENDING_XXX, value = amount
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    // index of current_lending_amount
    const I_LENDING_SCALLOP_BASIC: u64 = 0;
    const I_LENDING_NAVI: u64 = 1;
    const K_NAVI_ACCOUNT_CAP: vector<u8> = b"navi_account_cap";

    // feature: redeem -> lock x ts_ms -> claim (burn)
    const K_DEACTIVATING_SHARES: vector<u8> = b"deactivating_shares";
    /// A struct for deactivating shares.
    public struct DeactivatingShares<phantom TOKEN> has store {
        /// The balance of the deactivating shares.
        balance: Balance<TOKEN>,
        /// The timestamp of the redemption.
        redeem_ts_ms: u64,
        /// The timestamp when the shares can be unlocked.
        unlock_ts_ms: u64,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    // feature: manager emergency borrow tokens to lp pool => create receipt (not record )
    // => manager uses receipt to get tokens back
    /// A receipt for a manager's emergency deposit.
    public struct ManagerDepositReceipt has key, store {
        id: UID,
        /// The index of the pool.
        index: u64, // pool_index
        /// The type name of the token.
        token_type: TypeName,
        /// The amount of the deposit.
        amount: u64,
        /// Padding for future use.
        u64_padding: vector<u64>
    }

    fun init(ctx: &mut TxContext) {
        let registry = Registry {
            id: object::new(ctx),
            num_pool: 0,
            liquidity_pool_registry: object::new(ctx),
        };

        transfer::share_object(registry);
    }

    /// An event that is emitted when a new liquidity pool is created.
    public struct NewLiquidityPoolEvent has copy, drop {
        sender: address,
        index: u64,
        lp_token_type: TypeName,
        lp_token_decimal: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Creates a new liquidity pool.
    entry fun new_liquidity_pool<LP_TOKEN>(
        version: &Version,
        registry: &mut Registry,
        lp_token_decimal: u64,
        unlock_countdown_ts_ms: u64,
        ctx: &mut TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let mut pool = LiquidityPool {
            id: object::new(ctx),
            index: registry.num_pool,
            lp_token_type: type_name::with_defining_ids<LP_TOKEN>(),
            liquidity_tokens: vector::empty(),
            token_pools: vector::empty(),
            pool_info: LiquidityPoolInfo {
                lp_token_decimal,
                total_share_supply: 0,
                tvl_usd: 0,
                is_active: true,
            },
            liquidated_unsettled_receipts: vector::empty(),
            u64_padding: vector[0, unlock_countdown_ts_ms],
            bcs_padding: vector::empty(),
        };

        dynamic_field::add(&mut pool.id, string::utf8(K_DEACTIVATING_SHARES), table::new<address, vector<DeactivatingShares<LP_TOKEN>>>(ctx));
        dynamic_object_field::add(&mut registry.liquidity_pool_registry, registry.num_pool, pool);
        registry.num_pool = registry.num_pool + 1;

        emit(NewLiquidityPoolEvent {
            sender: tx_context::sender(ctx),
            index: registry.num_pool - 1,
            lp_token_type: type_name::with_defining_ids<LP_TOKEN>(),
            lp_token_decimal,
            u64_padding: vector::empty()
        });
    }

    // entry fun create_deactivating_shares<TOKEN>(
    //     version: &Version,
    //     registry: &mut Registry,
    //     index: u64,
    //     ctx: &mut TxContext
    // ) {
        // safety check
        // admin::verify(version, ctx);

    //     let liquidity_pool = get_mut_liquidity_pool(registry, index);
    //     assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
    //     assert!(!dynamic_field::exists_(&liquidity_pool.id, string::utf8(K_DEACTIVATING_SHARES)), error::deactivating_shares_already_existed());

    //     dynamic_field::add(&mut liquidity_pool.id, string::utf8(K_DEACTIVATING_SHARES), table::new<address, vector<DeactivatingShares<TOKEN>>>(ctx));
    //     math::set_u64_vector_value(&mut liquidity_pool.u64_padding, I_TOTAL_DEACTIVATING_SHARES, 0);
    // }

    /// An event that is emitted when the unlock countdown is updated.
    public struct UpdateUnlockCountdownTsMsEvent has copy, drop {
        sender: address,
        index: u64,
        previous_unlock_countdown_ts_ms: u64,
        new_unlock_countdown_ts_ms: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Updates the unlock countdown.
    entry fun update_unlock_countdown_ts_ms(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        unlock_countdown_ts_ms: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        let previous_unlock_countdown_ts_ms = math::get_u64_vector_value(&liquidity_pool.u64_padding, I_UNLOCK_COUNTDOWN_TS_MS);
        math::set_u64_vector_value(&mut liquidity_pool.u64_padding, I_UNLOCK_COUNTDOWN_TS_MS, unlock_countdown_ts_ms);
        emit(UpdateUnlockCountdownTsMsEvent {
            sender: tx_context::sender(ctx),
            index,
            previous_unlock_countdown_ts_ms,
            new_unlock_countdown_ts_ms: unlock_countdown_ts_ms,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when the rebalance cost threshold is updated.
    public struct UpdateRebalanceCostThresholdBpEvent has copy, drop {
        sender: address,
        index: u64,
        previous_rebalance_cost_threshold_bp: u64,
        new_rebalance_cost_threshold_bp: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Updates the rebalance cost threshold.
    entry fun update_rebalance_cost_threshold_bp(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        rebalance_cost_threshold_bp: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        assert!(rebalance_cost_threshold_bp >= 0 && rebalance_cost_threshold_bp < 100, error::invalid_config_range());
        let previous_rebalance_cost_threshold_bp = math::get_u64_vector_value(&liquidity_pool.u64_padding, I_REBALANCE_COST_THRESHOLD_BP);
        math::set_u64_vector_value(&mut liquidity_pool.u64_padding, I_REBALANCE_COST_THRESHOLD_BP, rebalance_cost_threshold_bp);
        emit(UpdateRebalanceCostThresholdBpEvent {
            sender: tx_context::sender(ctx),
            index,
            previous_rebalance_cost_threshold_bp,
            new_rebalance_cost_threshold_bp: rebalance_cost_threshold_bp,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when a new liquidity token is added.
    public struct AddLiquidityTokenEvent has copy, drop {
        sender: address,
        index: u64,
        token_type: TypeName,
        config: Config,
        state: State,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Adds a new liquidity token to a pool.
    entry fun add_liquidity_token<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        oracle: &Oracle,
        token_decimal: u64,
        // spot config
        target_weight_bp: u64,
        min_deposit: u64,
        max_capacity: u64,
        basic_mint_fee_bp: u64,
        additional_mint_fee_bp: u64,
        basic_burn_fee_bp: u64,
        additional_burn_fee_bp: u64,
        swap_fee_bp: u64,
        swap_fee_protocol_share_bp: u64,
        lending_protocol_share_bp: u64,
        // margin config
        basic_borrow_rate_0: u64,
        basic_borrow_rate_1: u64,
        basic_borrow_rate_2: u64,
        utilization_threshold_bp_0: u64,
        utilization_threshold_bp_1: u64,
        borrow_interval_ts_ms: u64,
        max_order_reserve_ratio_bp: u64,
        clock: &Clock,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

        let token_type = type_name::with_defining_ids<TOKEN>();
        assert!(!vector::contains(&liquidity_pool.liquidity_tokens, &token_type), error::liquidity_token_existed());
        vector::push_back(&mut liquidity_pool.liquidity_tokens, token_type);

        assert!(
            target_weight_bp > C_MIN_TARGET_WEIGHT_BP && target_weight_bp <= C_MAX_TARGET_WEIGHT_BP,
            error::invalid_config_range()
        );
        assert!(min_deposit > C_MIN_MIN_DEPOSIT, error::invalid_config_range());
        assert!(max_capacity > C_MIN_MAX_CAPACITY, error::invalid_config_range());
        assert!(basic_mint_fee_bp <= C_MAX_BASIC_MINT_FEE_BP, error::invalid_config_range());
        assert!(additional_mint_fee_bp <= C_MAX_ADDITIONAL_MINT_FEE_BP, error::invalid_config_range());
        assert!(basic_burn_fee_bp <= C_MAX_BASIC_BURN_FEE_BP, error::invalid_config_range());
        assert!(additional_burn_fee_bp <= C_MAX_ADDITIONAL_BURN_FEE_BP, error::invalid_config_range());
        assert!(swap_fee_bp <= C_MAX_SWAP_FEE_BP, error::invalid_config_range());
        assert!(swap_fee_protocol_share_bp <= C_MAX_SWAP_FEE_PROTOCOL_SHARE_BP, error::invalid_config_range());
        assert!(lending_protocol_share_bp <= C_MAX_LENDING_PROTOCOL_SHARE_BP, error::invalid_config_range());
        assert!(
            basic_borrow_rate_0 > C_MIN_BASIC_BORROW_RATE
                && basic_borrow_rate_0 < basic_borrow_rate_1
                    && basic_borrow_rate_1 < basic_borrow_rate_2,
            error::invalid_config_range()
        );
        assert!(
            utilization_threshold_bp_0 > C_MIN_UTILIZATION_THRESHOLD_BP
                && utilization_threshold_bp_0 < utilization_threshold_bp_1
                    && utilization_threshold_bp_1 < C_MAX_UTILIZATION_THRESHOLD_BP,
            error::invalid_config_range()
        );
        assert!(borrow_interval_ts_ms > C_MIN_BORROW_INTERVAL_TS_MS, error::invalid_config_range());
        assert!(max_order_reserve_ratio_bp > C_MIN_MAX_ORDER_RESERVE_RATIO_BP, error::invalid_config_range());

        let spot_config = SpotConfig {
            min_deposit,
            max_capacity,
            target_weight_bp,
            basic_mint_fee_bp,
            additional_mint_fee_bp,
            basic_burn_fee_bp,
            additional_burn_fee_bp,
            swap_fee_bp,
            swap_fee_protocol_share_bp,
            lending_protocol_share_bp,
            u64_padding: vector::empty(),
        };

        let margin_config = MarginConfig {
            // borrow related parameters
            basic_borrow_rate_0,
            basic_borrow_rate_1,
            basic_borrow_rate_2,
            utilization_threshold_bp_0,
            utilization_threshold_bp_1,
            borrow_interval_ts_ms,
            max_order_reserve_ratio_bp,
            u64_padding: vector::empty(),
        };

        let config = Config {
            oracle_id: object::id_address(oracle),
            liquidity_token_decimal: token_decimal,
            spot_config,
            margin_config,
            u64_padding: vector::empty()
        };
        let current_ts_ms = clock::timestamp_ms(clock);
        let last_borrow_rate_ts_ms = current_ts_ms / borrow_interval_ts_ms * borrow_interval_ts_ms;
        let state = State {
            liquidity_amount: 0,   // balance value
            value_in_usd: 0,       // amount / decimals * price (USD)
            reserved_amount: 0,
            update_ts_ms: current_ts_ms,
            is_active: true,
            last_borrow_rate_ts_ms,
            cumulative_borrow_rate: 0,
            previous_last_borrow_rate_ts_ms: last_borrow_rate_ts_ms,
            previous_cumulative_borrow_rate: 0,
            current_lending_amount: vector::empty(),
            u64_padding: vector::empty()
        };

        let token_pool = TokenPool { token_type, config, state };
        vector::push_back(&mut liquidity_pool.token_pools, token_pool);

        if (!dynamic_field::exists_(&liquidity_pool.id, token_type)) {
            dynamic_field::add(&mut liquidity_pool.id, token_type, balance::zero<TOKEN>());
        };

        emit(AddLiquidityTokenEvent {
            sender: tx_context::sender(ctx),
            index,
            token_type,
            config,
            state,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when the spot configuration is updated.
    public struct UpdateSpotConfigEvent has copy, drop {
        sender: address,
        index: u64,
        liquidity_token_type: TypeName,
        previous_spot_config: SpotConfig,
        new_spot_config: SpotConfig,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Updates the spot configuration for a token.
    entry fun update_spot_config<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        target_weight_bp: Option<u64>,
        min_deposit: Option<u64>,
        max_capacity: Option<u64>,
        basic_mint_fee_bp: Option<u64>,
        additional_mint_fee_bp: Option<u64>,
        basic_burn_fee_bp: Option<u64>,
        additional_burn_fee_bp: Option<u64>,
        swap_fee_bp: Option<u64>,
        swap_fee_protocol_share_bp: Option<u64>,
        lending_protocol_share_bp: Option<u64>,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);

        let token_type = type_name::with_defining_ids<TOKEN>();
        assert!(vector::contains(&liquidity_pool.liquidity_tokens, &token_type), error::liquidity_token_not_existed());
        let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
        let previous_spot_config = token_pool.config.spot_config;

        if (option::is_some(&target_weight_bp)) {
            assert!(
                *option::borrow(&target_weight_bp) > C_MIN_TARGET_WEIGHT_BP
                    &&*option::borrow(&target_weight_bp) <= C_MAX_TARGET_WEIGHT_BP,
                error::invalid_config_range()
            );
            token_pool.config.spot_config.target_weight_bp = *option::borrow(&target_weight_bp);
        };
        if (option::is_some(&min_deposit)) {
            assert!(*option::borrow(&min_deposit) > C_MIN_MIN_DEPOSIT, error::invalid_config_range());
            token_pool.config.spot_config.min_deposit = *option::borrow(&min_deposit);
        };
        if (option::is_some(&max_capacity)) {
            assert!(*option::borrow(&max_capacity) > C_MIN_MAX_CAPACITY, error::invalid_config_range());
            token_pool.config.spot_config.max_capacity = *option::borrow(&max_capacity);
        };
        if (option::is_some(&basic_mint_fee_bp)) {
            assert!(*option::borrow(&basic_mint_fee_bp) <= C_MAX_BASIC_MINT_FEE_BP, error::invalid_config_range());
            token_pool.config.spot_config.basic_mint_fee_bp = *option::borrow(&basic_mint_fee_bp);
        };
        if (option::is_some(&additional_mint_fee_bp)) {
            assert!(*option::borrow(&additional_mint_fee_bp) <= C_MAX_ADDITIONAL_MINT_FEE_BP, error::invalid_config_range());
            token_pool.config.spot_config.additional_mint_fee_bp = *option::borrow(&additional_mint_fee_bp);
        };
        if (option::is_some(&basic_burn_fee_bp)) {
            assert!(*option::borrow(&basic_burn_fee_bp) <= C_MAX_BASIC_BURN_FEE_BP, error::invalid_config_range());
            token_pool.config.spot_config.basic_burn_fee_bp = *option::borrow(&basic_burn_fee_bp);
        };
        if (option::is_some(&additional_burn_fee_bp)) {
            assert!(*option::borrow(&additional_burn_fee_bp) <= C_MAX_ADDITIONAL_BURN_FEE_BP, error::invalid_config_range());
            token_pool.config.spot_config.additional_burn_fee_bp = *option::borrow(&additional_burn_fee_bp);
        };
        if (option::is_some(&swap_fee_bp)) {
            assert!(*option::borrow(&swap_fee_bp) <= C_MAX_SWAP_FEE_BP, error::invalid_config_range());
            token_pool.config.spot_config.swap_fee_bp = *option::borrow(&swap_fee_bp);
        };
        if (option::is_some(&swap_fee_protocol_share_bp)) {
            assert!(*option::borrow(&swap_fee_protocol_share_bp) <= C_MAX_SWAP_FEE_PROTOCOL_SHARE_BP, error::invalid_config_range());
            token_pool.config.spot_config.swap_fee_protocol_share_bp = *option::borrow(&swap_fee_protocol_share_bp);
        };
        if (option::is_some(&lending_protocol_share_bp)) {
            assert!(*option::borrow(&lending_protocol_share_bp) <= C_MAX_LENDING_PROTOCOL_SHARE_BP, error::invalid_config_range());
            token_pool.config.spot_config.lending_protocol_share_bp = *option::borrow(&lending_protocol_share_bp);
        };


        emit(UpdateSpotConfigEvent {
            sender: tx_context::sender(ctx),
            index,
            liquidity_token_type: token_type,
            previous_spot_config: previous_spot_config,
            new_spot_config: token_pool.config.spot_config,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when a manager makes an emergency deposit.
    public struct ManagerEmergencyDepositEvent has copy, drop {
        sender: address,
        index: u64,
        liquidity_token_type: TypeName,
        amount: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Allows a manager to deposit tokens in an emergency.
    entry fun manager_emergency_deposit<TOKEN, LP_TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        // coin
        coin: Coin<TOKEN>, // deposit_amount: u64,
        ctx: &mut TxContext
    ) {
        let token_type = type_name::with_defining_ids<TOKEN>();

        // coin to balance
        let balance = coin.into_balance();
        let deposit_amount = balance.value();

        // checks
        {
            // safety check
            admin::verify(version, ctx);

            // check token type correct
            let liquidity_pool = get_liquidity_pool(registry, index);
            assert!(type_name::with_defining_ids<LP_TOKEN>() == liquidity_pool.lp_token_type, error::lp_token_type_mismatched());
            // check pool active
            assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

            // check collateral token active
            let token_pool = get_token_pool(liquidity_pool, &token_type);
            assert!(token_pool.state.is_active, error::token_pool_inactive());
        };

        // deal with coin & balance
        // liquidity_amount, value_in_usd, total_share_supply -> tvl
        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        balance::join(dynamic_field::borrow_mut(&mut liquidity_pool.id, token_type), balance);

        let receipt = ManagerDepositReceipt {
            id: object::new(ctx),
            index,
            token_type,
            amount: deposit_amount,
            u64_padding: vector::empty()
        };
        transfer::public_transfer(receipt, ctx.sender());

        emit(ManagerEmergencyDepositEvent {
            sender: ctx.sender(),
            index,
            liquidity_token_type: token_type,
            amount: deposit_amount,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when a manager makes an emergency withdrawal.
    public struct ManagerEmergencyWithdrawEvent has copy, drop {
        sender: address,
        index: u64,
        liquidity_token_type: TypeName,
        amount: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Allows a manager to withdraw tokens in an emergency.
    entry fun manager_emergency_withdraw<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        receipt: ManagerDepositReceipt,
        ctx: &mut TxContext
    ) {
        let token_type = type_name::with_defining_ids<TOKEN>();

        // destruct receipt
        let ManagerDepositReceipt {
            id,
            index: receipt_pool_index,
            token_type: receipt_token_type,
            amount,
            u64_padding: _
        } = receipt;
        object::delete(id);
        // checks
        {
            // safety check
            admin::verify(version, ctx);

            // check receipt pool index matched
            assert!(receipt_pool_index == index, error::pool_index_mismatched());

            // check token type correct
            assert!(token_type == receipt_token_type, error::invalid_token_type());
            let liquidity_pool = get_liquidity_pool(registry, index);
            // check pool active
            assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

            // check collateral token active
            let token_pool = get_token_pool(liquidity_pool, &token_type);
            assert!(token_pool.state.is_active, error::token_pool_inactive());
        };

        // deal with coin & balance
        // liquidity_amount, value_in_usd, total_share_supply -> tvl
        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        let balance = balance::split(dynamic_field::borrow_mut<TypeName, Balance<TOKEN>>(&mut liquidity_pool.id, token_type), amount);
        let withdraw_amount = balance.value();
        transfer::public_transfer(coin::from_balance(balance, ctx), ctx.sender());

        emit(ManagerEmergencyWithdrawEvent {
            sender: ctx.sender(),
            index,
            liquidity_token_type: token_type,
            amount: withdraw_amount,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when the margin configuration is updated.
    public struct UpdateMarginConfigEvent has copy, drop {
        sender: address,
        index: u64,
        liquidity_token_type: TypeName,
        previous_margin_config: MarginConfig,
        new_margin_config: MarginConfig,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Updates the margin configuration for a token.
    entry fun update_margin_config<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        basic_borrow_rate_0: Option<u64>,
        basic_borrow_rate_1: Option<u64>,
        basic_borrow_rate_2: Option<u64>,
        utilization_threshold_bp_0: Option<u64>,
        utilization_threshold_bp_1: Option<u64>,
        borrow_interval_ts_ms: Option<u64>,
        max_order_reserve_ratio_bp: Option<u64>,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);

        let token_type = type_name::with_defining_ids<TOKEN>();
        assert!(vector::contains(&liquidity_pool.liquidity_tokens, &token_type), error::liquidity_token_not_existed());
        let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
        let previous_margin_config = token_pool.config.margin_config;

        if (option::is_some(&basic_borrow_rate_0)) {
            token_pool.config.margin_config.basic_borrow_rate_0 = *option::borrow(&basic_borrow_rate_0);
        };
        if (option::is_some(&basic_borrow_rate_1)) {
            token_pool.config.margin_config.basic_borrow_rate_1 = *option::borrow(&basic_borrow_rate_1);
        };
        if (option::is_some(&basic_borrow_rate_2)) {
            token_pool.config.margin_config.basic_borrow_rate_2 = *option::borrow(&basic_borrow_rate_2);
        };
        if (option::is_some(&utilization_threshold_bp_0)) {
            token_pool.config.margin_config.utilization_threshold_bp_0 = *option::borrow(&utilization_threshold_bp_0);
        };
        if (option::is_some(&utilization_threshold_bp_1)) {
            token_pool.config.margin_config.utilization_threshold_bp_1 = *option::borrow(&utilization_threshold_bp_1);
        };
        if (option::is_some(&borrow_interval_ts_ms)) {
            assert!(*option::borrow(&borrow_interval_ts_ms) > C_MIN_BORROW_INTERVAL_TS_MS, error::invalid_config_range());
            token_pool.config.margin_config.borrow_interval_ts_ms = *option::borrow(&borrow_interval_ts_ms);
        };
        if (option::is_some(&max_order_reserve_ratio_bp)) {
            assert!(*option::borrow(&max_order_reserve_ratio_bp) > C_MIN_MAX_ORDER_RESERVE_RATIO_BP, error::invalid_config_range());
            token_pool.config.margin_config.max_order_reserve_ratio_bp = *option::borrow(&max_order_reserve_ratio_bp);
        };
        assert!(
            token_pool.config.margin_config.basic_borrow_rate_0 > C_MIN_BASIC_BORROW_RATE
                && token_pool.config.margin_config.basic_borrow_rate_0 < token_pool.config.margin_config.basic_borrow_rate_1
                    && token_pool.config.margin_config.basic_borrow_rate_1 < token_pool.config.margin_config.basic_borrow_rate_2,
            error::invalid_config_range()
        );
        assert!(
            token_pool.config.margin_config.utilization_threshold_bp_0 > C_MIN_UTILIZATION_THRESHOLD_BP
                && token_pool.config.margin_config.utilization_threshold_bp_0 < token_pool.config.margin_config.utilization_threshold_bp_1
                    && token_pool.config.margin_config.utilization_threshold_bp_1 < C_MAX_UTILIZATION_THRESHOLD_BP,
            error::invalid_config_range()
        );

        emit(UpdateMarginConfigEvent {
            sender: tx_context::sender(ctx),
            index,
            liquidity_token_type: token_type,
            previous_margin_config: previous_margin_config,
            new_margin_config: token_pool.config.margin_config,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when LP tokens are minted.
    public struct MintLpEvent has copy, drop {
        sender: address,
        index: u64,
        liquidity_token_type: TypeName,
        deposit_amount: u64,
        deposit_amount_usd: u64,
        mint_fee_usd: u64,
        lp_token_type: TypeName,
        minted_lp_amount: u64,
        u64_padding: vector<u64>
    }
    /// [User Function] Mints LP tokens.
    public fun mint_lp<TOKEN, LP_TOKEN>(
        version: &mut Version,
        registry: &mut Registry,
        treasury_caps: &mut TreasuryCaps,
        oracle: &Oracle,
        index: u64,
        // coin
        coin: Coin<TOKEN>, // deposit_amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<LP_TOKEN> {
        let token_type = type_name::with_defining_ids<TOKEN>();

        // coin to balance
        let mut balance = coin.into_balance();
        let deposit_amount = balance.value();

        normal_safety_check<TOKEN, LP_TOKEN>(version, registry, index, oracle, clock);

            // check min deposit
        {
            let liquidity_pool = get_liquidity_pool(registry, index);
            let token_pool = get_token_pool(liquidity_pool, &token_type);
            assert!(deposit_amount >= token_pool.config.spot_config.min_deposit, error::deposit_amount_insufficient());
        };

        let (price, price_decimal) = oracle.get_price_with_interval_ms(clock, 0);

        update_borrow_info(version, registry, index, clock);

        // calculation
        let (deposit_amount_usd, mint_fee_usd, mint_amount) = calculate_mint_lp(registry, index, token_type, price, price_decimal, deposit_amount);
        // deal with coin & balance
        // liquidity_amount, value_in_usd, total_share_supply -> tvl
        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        liquidity_pool.pool_info.total_share_supply = liquidity_pool.pool_info.total_share_supply + mint_amount;
        let fee_balance = balance.split(
            ((deposit_amount as u128) * (mint_fee_usd as u128) / (deposit_amount_usd as u128) as u64)
            );
        let fee_amount = fee_balance.value();
        admin::charge_fee(version, fee_balance);
        balance::join(dynamic_field::borrow_mut(&mut liquidity_pool.id, token_type), balance);

        let lp_coin_treasury_cap = treasury_caps::get_mut_treasury_cap(treasury_caps);
        let lp_coin = coin::mint(lp_coin_treasury_cap, mint_amount, ctx);

        // update token_pool.state
        let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
        assert!(token_pool.state.liquidity_amount + deposit_amount - fee_amount <= token_pool.config.spot_config.max_capacity, error::reach_max_capacity());
        token_pool.state.liquidity_amount = token_pool.state.liquidity_amount + deposit_amount - fee_amount;
        update_tvl(version, liquidity_pool, token_type, oracle, clock);

        emit(MintLpEvent {
            sender: tx_context::sender(ctx),
            index,
            liquidity_token_type: token_type,
            deposit_amount,
            deposit_amount_usd,
            mint_fee_usd,
            lp_token_type: liquidity_pool.lp_token_type,
            minted_lp_amount: mint_amount,
            u64_padding: vector::empty()
        });

        lp_coin
    }

    /// An event that is emitted when the borrow information is updated.
    public struct UpdateBorrowInfoEvent has copy, drop {
        index: u64,
        liquidity_token_type: TypeName,
        previous_borrow_ts_ms: u64,
        previous_cumulative_borrow_rate: u64,
        borrow_interval_ts_ms: u64,
        last_borrow_rate_ts_ms: u64,
        last_cumulative_borrow_rate: u64,
        u64_padding: vector<u64>
    }
    /// [User Function] Updates the borrow information for all tokens in a pool.
    public fun update_borrow_info(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        clock: &Clock,
    ) {
        // safety check
        admin::version_check(version);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        let current_ts_ms = clock::timestamp_ms(clock);
        let mut liquidity_tokens = liquidity_pool.liquidity_tokens;
        while (vector::length(&liquidity_tokens) > 0) {
            let token_type = vector::pop_back(&mut liquidity_tokens);
            let token_pool = get_mut_token_pool(liquidity_pool, &token_type);

            // keep updating borrow info even if token_pool inactive

            let config = token_pool.config;
            let borrow_ts_ms = current_ts_ms / config.margin_config.borrow_interval_ts_ms * config.margin_config.borrow_interval_ts_ms;

            let previous_borrow_ts_ms = token_pool.state.last_borrow_rate_ts_ms;
            let previous_cumulative_borrow_rate = token_pool.state.cumulative_borrow_rate;

            // time difference larger than interval => should update
            if (borrow_ts_ms - token_pool.state.last_borrow_rate_ts_ms >= config.margin_config.borrow_interval_ts_ms) {
                let intervals_count = (borrow_ts_ms - token_pool.state.last_borrow_rate_ts_ms) / config.margin_config.borrow_interval_ts_ms;
                let utility_bp = if (token_pool.state.liquidity_amount == 0) {
                    0
                } else {
                    ((math::get_bp_scale() as u128) * (token_pool.state.reserved_amount as u128)
                        / (token_pool.state.liquidity_amount as u128) as u64)
                };
                let borrow_rate = if (utility_bp < config.margin_config.utilization_threshold_bp_0) {
                    ((config.margin_config.basic_borrow_rate_0 as u128)
                                    * (utility_bp as u128)
                                        / (config.margin_config.utilization_threshold_bp_0 as u128) as u64)
                } else if (utility_bp < config.margin_config.utilization_threshold_bp_1) {

                        config.margin_config.basic_borrow_rate_0
                        + ((config.margin_config.basic_borrow_rate_1 as u128)
                            * ((utility_bp - config.margin_config.utilization_threshold_bp_0) as u128)
                            / ((config.margin_config.utilization_threshold_bp_1
                                - config.margin_config.utilization_threshold_bp_0) as u128) as u64)
                } else {
                    config.margin_config.basic_borrow_rate_0
                        + config.margin_config.basic_borrow_rate_1
                        + ((config.margin_config.basic_borrow_rate_2 as u128)
                            * ((utility_bp - config.margin_config.utilization_threshold_bp_1) as u128)
                            / ((math::get_bp_scale() - config.margin_config.utilization_threshold_bp_1) as u128) as u64)
                };
                token_pool.state.previous_last_borrow_rate_ts_ms = previous_borrow_ts_ms;
                token_pool.state.previous_cumulative_borrow_rate = previous_cumulative_borrow_rate;
                token_pool.state.cumulative_borrow_rate = token_pool.state.cumulative_borrow_rate + borrow_rate * intervals_count;
                token_pool.state.last_borrow_rate_ts_ms = borrow_ts_ms;

                emit(UpdateBorrowInfoEvent {
                    index,
                    liquidity_token_type: token_type,
                    previous_borrow_ts_ms,
                    previous_cumulative_borrow_rate,
                    borrow_interval_ts_ms: config.margin_config.borrow_interval_ts_ms,
                    last_borrow_rate_ts_ms: token_pool.state.last_borrow_rate_ts_ms,
                    last_cumulative_borrow_rate: token_pool.state.cumulative_borrow_rate,
                    u64_padding: vector::empty()
                });
            };
        };
    }

    /// An event that is emitted when a swap is made.
    public struct SwapEvent has copy, drop {
        sender: address,
        index: u64,
        from_token_type: TypeName,
        from_amount: u64,
        to_token_type: TypeName,
        min_to_amount: u64,
        actual_to_amount: u64,
        fee_amount: u64,
        fee_amount_usd: u64,
        oracle_price_from_token: u64,
        oracle_price_to_token: u64,
        u64_padding: vector<u64>
    }
    /// [User Function] Swaps one token for another.
    public fun swap<F_TOKEN, T_TOKEN>(
        version: &mut Version,
        registry: &mut Registry,
        index: u64,
        oracle_from_token: &Oracle,
        oracle_to_token: &Oracle,
        from_coin: Coin<F_TOKEN>,
        min_to_amount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<T_TOKEN> {
        // safety check
        admin::version_check(version);
        update_borrow_info(version, registry, index, clock);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

        let (price_f_token_to_usd, price_f_decimal) = oracle_from_token.get_price_with_interval_ms(clock, 0);
        let (price_t_token_to_usd, price_t_decimal) = oracle_to_token.get_price_with_interval_ms(clock, 0);

        // coin to balance
        let from_amount = from_coin.value();
        let f_token_type = type_name::with_defining_ids<F_TOKEN>();
        let t_token_type = type_name::with_defining_ids<T_TOKEN>();
        assert!(f_token_type != t_token_type, error::invalid_token_type());

        let f_token_config = get_mut_token_pool(liquidity_pool, &f_token_type).config;
        let t_token_config = get_mut_token_pool(liquidity_pool, &t_token_type).config;
        // check oracle correct
        assert!(object::id_address(oracle_from_token) == f_token_config.oracle_id, error::oracle_mismatched());
        assert!(object::id_address(oracle_to_token) == t_token_config.oracle_id, error::oracle_mismatched());

        // check collateral token active
        let f_token_state = get_mut_token_pool(liquidity_pool, &f_token_type).state;
        let t_token_state = get_mut_token_pool(liquidity_pool, &t_token_type).state;
        assert!(f_token_state.is_active, error::token_pool_inactive());
        assert!(t_token_state.is_active, error::token_pool_inactive());

        // calculate to_amount_value by oracle price
        let from_amount_usd = math::amount_to_usd(
            from_amount,
            f_token_config.liquidity_token_decimal,
            price_f_token_to_usd,
            price_f_decimal
        );
        let to_amount_value = math::usd_to_amount(
            from_amount_usd,
            t_token_config.liquidity_token_decimal,
            price_t_token_to_usd,
            price_t_decimal
        );

        // use both token to calculate fee => then pick the large one => then transform into F_TOKEN unit
        let (f_token_fee, f_token_fee_usd) = calculate_swap_fee(
            liquidity_pool,
            f_token_type,
            from_amount,
            from_amount_usd,
            true,
        );
        let (_t_token_fee, t_token_fee_usd) = calculate_swap_fee(
            liquidity_pool,
            t_token_type,
            to_amount_value,
            from_amount_usd,
            false,
        );

        // real fee in F_TOKEN unit
        let (fee_amount, fee_amount_usd) = if (f_token_fee_usd > t_token_fee_usd) {
            (f_token_fee, f_token_fee_usd)
        } else {
            (
                math::usd_to_amount(
                    t_token_fee_usd,
                    f_token_config.liquidity_token_decimal,
                    price_f_token_to_usd,
                    price_f_decimal
                ),
                t_token_fee_usd
            )
        };

        let to_amount_after_fee = math::usd_to_amount(
            from_amount_usd - fee_amount_usd,
            t_token_config.liquidity_token_decimal,
            price_t_token_to_usd,
            price_t_decimal
        );

        assert!(to_amount_after_fee >= min_to_amount, error::reach_slippage_threshold());

        // deposit
        {
            let swap_fee_protocol_share_bp = {
                let token_pool = get_mut_token_pool(liquidity_pool, &f_token_type);
                token_pool.config.spot_config.swap_fee_protocol_share_bp
            };
            let mut from_balance = from_coin.into_balance();
            let protocol_fee_balance = from_balance.split(((fee_amount as u128)
                                        * (swap_fee_protocol_share_bp as u128)
                                            / (math::get_bp_scale() as u128) as u64));
            let from_balance_value_after_fee = from_balance.value();
            admin::charge_fee(version, protocol_fee_balance);
            balance::join(dynamic_field::borrow_mut(&mut liquidity_pool.id, f_token_type), from_balance);
            let token_pool = get_mut_token_pool(liquidity_pool, &f_token_type);
            assert!(token_pool.state.liquidity_amount + from_balance_value_after_fee <= token_pool.config.spot_config.max_capacity, error::reach_max_capacity());
            token_pool.state.liquidity_amount = token_pool.state.liquidity_amount + from_balance_value_after_fee;
            update_tvl(version, liquidity_pool, f_token_type, oracle_from_token, clock);
        };

        // withdraw
        let to_balance = {
            let to_balance = balance::split(
                dynamic_field::borrow_mut<TypeName, Balance<T_TOKEN>>(&mut liquidity_pool.id, t_token_type),
                to_amount_after_fee
            );
            let withdraw_amount = balance::value(&to_balance);
            let token_pool = get_mut_token_pool(liquidity_pool, &t_token_type);
            token_pool.state.liquidity_amount = token_pool.state.liquidity_amount - withdraw_amount;
            assert!(token_pool.state.liquidity_amount >= token_pool.state.reserved_amount, error::liquidity_not_enough());
            update_tvl(version, liquidity_pool, t_token_type, oracle_to_token, clock);
            to_balance
        };

        emit(SwapEvent {
            sender: tx_context::sender(ctx),
            index,
            from_token_type: f_token_type,
            from_amount,
            to_token_type: t_token_type,
            min_to_amount,
            actual_to_amount: to_amount_after_fee,
            fee_amount,
            fee_amount_usd,
            oracle_price_from_token: price_f_token_to_usd,
            oracle_price_to_token: price_t_token_to_usd,
            u64_padding: vector::empty()
        });

        coin::from_balance(to_balance, ctx)
    }

    /// An event that is emitted when LP tokens are redeemed.
    public struct RedeemEvent has copy, drop {
        sender: address,
        index: u64,
        share: u64,
        share_price: u64, // in USD decimal = 9
        timestamp_ts_ms: u64,
        unlock_ts_ms: u64,
        u64_padding: vector<u64>
    }
    /// [User Function] Redeems LP tokens for underlying assets.
    public fun redeem<LP_TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        balance: Balance<LP_TOKEN>,
        clock: &Clock,
        ctx: &TxContext
    ) {
        // safety check
        admin::version_check(version);
        update_borrow_info(version, registry, index, clock);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        assert!(check_tvl_updated(liquidity_pool, clock), error::tvl_not_yet_updated());
        assert!(type_name::with_defining_ids<LP_TOKEN>() == liquidity_pool.lp_token_type, error::lp_token_type_mismatched());

        let user = ctx.sender();
        let share = balance.value();
        let redeem_ts_ms = clock.timestamp_ms();
        let unlock_ts_ms = redeem_ts_ms + math::get_u64_vector_value(&liquidity_pool.u64_padding, I_UNLOCK_COUNTDOWN_TS_MS);

        let deactivating_shares = DeactivatingShares {
            balance,
            redeem_ts_ms,
            unlock_ts_ms,
            u64_padding: vector::empty(),
        };

        let pool_deactivating_shares = dynamic_field::borrow_mut<String, Table<address, vector<DeactivatingShares<LP_TOKEN>>>>(
            &mut liquidity_pool.id, string::utf8(K_DEACTIVATING_SHARES)
        );

        if (pool_deactivating_shares.contains(user)) {
            let user_deactivating_shares = pool_deactivating_shares.borrow_mut(user);
            user_deactivating_shares.push_back(deactivating_shares);
        } else {
            pool_deactivating_shares.add(user, vector[deactivating_shares]);
        };

        let current_shares = math::get_u64_vector_value(&liquidity_pool.u64_padding, I_TOTAL_DEACTIVATING_SHARES);
        math::set_u64_vector_value(
            &mut liquidity_pool.u64_padding,
            I_TOTAL_DEACTIVATING_SHARES,
            current_shares + share
        );

        let share_price = ((liquidity_pool.pool_info.tvl_usd as u128)
            * (math::multiplier(math::get_usd_decimal()) as u128)
            / (liquidity_pool.pool_info.total_share_supply as u128)as u64);

        emit(RedeemEvent {
            sender: user,
            index,
            share,
            share_price, // in USD decimal = 9
            timestamp_ts_ms: redeem_ts_ms,
            unlock_ts_ms,
            u64_padding: vector::empty()
        });
    }

    /// [User Function] Claims underlying assets from redeemed LP tokens.
    public fun claim<LP_TOKEN, C_TOKEN>(
        version: &mut Version,
        registry: &mut Registry,
        index: u64,
        treasury_caps: &mut TreasuryCaps,
        oracle: &Oracle,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<C_TOKEN> {
        // safety check
        normal_safety_check<C_TOKEN, LP_TOKEN>(version, registry, index, oracle, clock);

        update_borrow_info(version, registry, index, clock);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        let pool_deactivating_shares = dynamic_field::borrow_mut<String, Table<address, vector<DeactivatingShares<LP_TOKEN>>>>(
            &mut liquidity_pool.id, string::utf8(K_DEACTIVATING_SHARES)
        );

        let user = ctx.sender();
        assert!(pool_deactivating_shares.contains(user), error::user_deactivating_shares_not_existed());

        let current_ts_ms = clock.timestamp_ms();
        let mut user_deactivating_shares = pool_deactivating_shares.remove(user);
        let mut remaining_shares = vector::empty();
        let mut tlp_balance = balance::zero<LP_TOKEN>();
        while (user_deactivating_shares.length() > 0) {
            let deactivating_shares = user_deactivating_shares.pop_back();
            if (current_ts_ms >= deactivating_shares.unlock_ts_ms) {
                let DeactivatingShares {
                    balance,
                    redeem_ts_ms: _,
                    unlock_ts_ms: _,
                    u64_padding: _,
                } = deactivating_shares;
                tlp_balance.join(balance);
            } else {
                remaining_shares.push_back(deactivating_shares);
            };
        };
        user_deactivating_shares.destroy_empty();

        if (remaining_shares.length() > 0) {
            pool_deactivating_shares.add(user, remaining_shares);
        } else {
            remaining_shares.destroy_empty();
        };

        if (tlp_balance.value() > 0) {
            let tlp_balance_value = tlp_balance.value();
            let current_shares = math::get_u64_vector_value(&liquidity_pool.u64_padding, I_TOTAL_DEACTIVATING_SHARES);
            math::set_u64_vector_value(
                &mut liquidity_pool.u64_padding,
                I_TOTAL_DEACTIVATING_SHARES,
                current_shares - tlp_balance_value
            );
        };

        burn_lp_<LP_TOKEN, C_TOKEN>(
            version,
            registry,
            index,
            treasury_caps,
            oracle,
            tlp_balance,
            clock,
            ctx,
        )
    }

    /// An event that is emitted when a pool is suspended.
    public struct SuspendPoolEvent has copy, drop {
        sender: address,
        index: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Suspends a liquidity pool.
    entry fun suspend_pool(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        liquidity_pool.pool_info.is_active = false;
        emit(SuspendPoolEvent {
            sender: tx_context::sender(ctx),
            index,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when a pool is resumed.
    public struct ResumePoolEvent has copy, drop {
        sender: address,
        index: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Resumes a liquidity pool.
    entry fun resume_pool(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(!liquidity_pool.pool_info.is_active, error::pool_already_active());
        liquidity_pool.pool_info.is_active = true;
        emit(ResumePoolEvent {
            sender: tx_context::sender(ctx),
            index,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when a token pool is suspended.
    public struct SuspendTokenPoolEvent has copy, drop {
        sender: address,
        index: u64,
        liquidity_token: TypeName,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Suspends a token pool.
    entry fun suspend_token_pool<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

        let token_pool = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<TOKEN>());
        assert!(token_pool.state.is_active, error::token_pool_inactive());
        token_pool.state.is_active = false;

        emit(SuspendTokenPoolEvent {
            sender: tx_context::sender(ctx),
            index,
            liquidity_token: type_name::with_defining_ids<TOKEN>(),
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when a token pool is resumed.
    public struct ResumeTokenPoolEvent has copy, drop {
        sender: address,
        index: u64,
        liquidity_token: TypeName,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Resumes a token pool.
    entry fun resume_token_pool<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

        let token_pool = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<TOKEN>());
        assert!(!token_pool.state.is_active, error::token_pool_already_active());
        token_pool.state.is_active = true;

        emit(ResumeTokenPoolEvent {
            sender: tx_context::sender(ctx),
            index,
            liquidity_token: type_name::with_defining_ids<TOKEN>(),
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when a manager deposits to a lending protocol.
    public struct DepositLendingEvent has copy, drop {
        index: u64,
        lending_index: u64, // index of current_lending_amount
        c_token_type: TypeName,
        deposit_amount: u64,
        minted_market_coin_amount: u64, // minted_s_token_amount
        latest_lending_amount: u64,
        latest_market_coin_amount: u64, // latest_s_token_amount
        latest_reserved_amount: u64,
        latest_liquidity_amount: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Manager deposits to Scallop.
    entry fun manager_deposit_scallop<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        scallop_version: &ScallopVersion,
        scallop_market: &mut protocol::market::Market,
        clock: &Clock,
        lending_amount: Option<u64>, // none => deposit all
        ctx: &mut TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        let token_pool = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<TOKEN>());
        assert!(token_pool.state.is_active, error::token_pool_already_active());

        let real_lending_amount = calculate_lending_amount_capped(token_pool, lending_amount);

        if (real_lending_amount > 0) {
            let log = deposit_scallop_basic<TOKEN>(
                liquidity_pool,
                scallop_version,
                scallop_market,
                clock,
                real_lending_amount,
                ctx,
            );
            emit(DepositLendingEvent {
                index,
                lending_index: I_LENDING_SCALLOP_BASIC,
                c_token_type: type_name::with_defining_ids<TOKEN>(),
                deposit_amount: log[0],
                minted_market_coin_amount: log[1],
                latest_lending_amount: log[2],
                latest_market_coin_amount: log[3],
                latest_reserved_amount: log[4],
                latest_liquidity_amount: log[5],
                u64_padding: vector::empty()
            });
        };
    }

    entry fun manager_deposit_navi<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
        lending_amount: Option<u64>, // none => deposit all
        ctx: &mut TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        let token_pool = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<TOKEN>());
        assert!(token_pool.state.is_active, error::token_pool_already_active());

        let real_lending_amount = calculate_lending_amount_capped(token_pool, lending_amount);

        if (real_lending_amount > 0) {
            let log = deposit_navi<TOKEN>(
                liquidity_pool,
                storage,
                pool,
                asset,
                incentive_v2,
                incentive_v3,
                clock,
                real_lending_amount,
                ctx,
            );
            emit(DepositLendingEvent {
                index,
                lending_index: I_LENDING_NAVI,
                c_token_type: type_name::with_defining_ids<TOKEN>(),
                deposit_amount: real_lending_amount,
                minted_market_coin_amount: 0,
                latest_lending_amount: log[0],
                latest_market_coin_amount: 0,
                latest_reserved_amount: log[1],
                latest_liquidity_amount: log[2],
                u64_padding: vector::empty()
            });
        };
    }

    /// An event that is emitted when a manager withdraws from a lending protocol.
    public struct WithdrawLendingEvent has copy, drop {
        index: u64,
        lending_index: u64,
        c_token_type: TypeName,
        r_token_type: TypeName,
        withdraw_amount: u64, // market coin amount
        withdrawn_collateral_amount: u64, // all balance from lending protocol
        latest_lending_amount: u64,
        latest_market_coin_amount: u64,
        latest_reserved_amount: u64,
        latest_liquidity_amount: u64,
        lending_interest: u64, // interest before deducted by fee
        protocol_share: u64, // charged fee
        lending_reward: u64, // reward before deducted by fee
        reward_protocol_share: u64, // charged fee
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Manager withdraws from Scallop.
    entry fun manager_withdraw_scallop<TOKEN>(
        version: &mut Version,
        registry: &mut Registry,
        index: u64,
        scallop_version: &ScallopVersion,
        scallop_market: &mut protocol::market::Market,
        clock: &Clock,
        mut withdraw_amount: Option<u64>, // none => withdraw all
        ctx: &mut TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        let token_pool = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<TOKEN>());
        assert!(token_pool.state.is_active, error::token_pool_already_active());

        let market_coin_type = type_name::with_defining_ids<MarketCoin<TOKEN>>();
        let real_withdraw_amount = if (withdraw_amount.is_none()) {
            dynamic_field::borrow<TypeName, Balance<MarketCoin<TOKEN>>>(&liquidity_pool.id, market_coin_type).value()
        } else {
            withdraw_amount.extract()
        };

        if (real_withdraw_amount > 0) {
            let log = withdraw_scallop_basic<TOKEN>(
                version,
                liquidity_pool,
                scallop_version,
                scallop_market,
                clock,
                real_withdraw_amount,
                ctx,
            );
            emit(WithdrawLendingEvent {
                index,
                lending_index: I_LENDING_SCALLOP_BASIC,
                c_token_type: type_name::with_defining_ids<TOKEN>(),
                r_token_type: type_name::with_defining_ids<TOKEN>(),
                withdraw_amount: log[0], // market coin amount
                withdrawn_collateral_amount: log[1], // all balance from lending protocol
                latest_lending_amount: log[2],
                latest_market_coin_amount: log[3],
                latest_reserved_amount: log[4],
                latest_liquidity_amount: log[5],
                lending_interest: log[6], // interest before deducted by fee
                protocol_share: log[7], // charged fee
                lending_reward: 0,
                reward_protocol_share: 0,
                u64_padding: vector::empty()
            });
        };
    }

    entry fun manager_withdraw_navi<TOKEN>(
        version: &mut Version,
        registry: &mut Registry,
        index: u64,
        oracle_config: &mut oracle::config::OracleConfig,
        price_oracle: &mut oracle::oracle::PriceOracle,
        supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        pyth_price_info: &pyth::price_info::PriceInfoObject,
        feed_address: address,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        let token_pool = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<TOKEN>());
        assert!(token_pool.state.is_active, error::token_pool_already_active());

        let current_lending_amount = {
            let navi_account_cap = dynamic_field::borrow_mut(&mut liquidity_pool.id, K_NAVI_ACCOUNT_CAP);
            lending_core::pool::unnormal_amount(
                pool,
                (lending_core::logic::user_collateral_balance(
                    storage,
                    asset,
                    lending_core::account::account_owner(navi_account_cap),
                ) as u64),
            )
        };

        if (current_lending_amount > 0) {
            let log = withdraw_navi<TOKEN>(
                version,
                liquidity_pool,
                oracle_config,
                price_oracle,
                supra_oracle_holder,
                pyth_price_info,
                feed_address,
                storage,
                pool,
                asset,
                incentive_v2,
                incentive_v3,
                clock,
            );
            emit(WithdrawLendingEvent {
                index,
                lending_index: I_LENDING_NAVI,
                c_token_type: type_name::with_defining_ids<TOKEN>(),
                r_token_type: type_name::with_defining_ids<TOKEN>(),
                withdraw_amount: 0, // market coin amount
                withdrawn_collateral_amount: current_lending_amount, // all balance from lending protocol
                latest_lending_amount: log[0],
                latest_market_coin_amount: 0,
                latest_reserved_amount: log[1],
                latest_liquidity_amount: log[2],
                lending_interest: log[3], // interest before deducted by fee
                protocol_share: log[4], // charged fee
                lending_reward: 0,
                reward_protocol_share: 0,
                u64_padding: vector::empty()
            });
        };
    }

    entry fun manager_reward_navi<R_TOKEN>(
        version: &mut Version,
        registry: &mut Registry,
        index: u64,
        storage: &mut lending_core::storage::Storage,
        reward_fund: &mut lending_core::incentive_v3::RewardFund<R_TOKEN>,
        coin_types: vector<std::ascii::String>,
        rule_ids: vector<address>,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // safety check
        admin::verify(version, ctx);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

        let log = reward_navi<R_TOKEN>(
            version,
            liquidity_pool,
            storage,
            reward_fund,
            coin_types,
            rule_ids,
            incentive_v3,
            clock,
        );
        emit(WithdrawLendingEvent {
            index,
            lending_index: I_LENDING_NAVI,
            c_token_type: type_name::with_defining_ids<R_TOKEN>(),
            r_token_type: type_name::with_defining_ids<R_TOKEN>(),
            withdraw_amount: 0,
            withdrawn_collateral_amount: 0,
            latest_lending_amount: 0,
            latest_market_coin_amount: 0,
            latest_reserved_amount: 0,
            latest_liquidity_amount: 0,
            lending_interest: 0,
            protocol_share: 0,
            lending_reward: log[0],
            reward_protocol_share: log[1],
            u64_padding: vector::empty()
        });
    }

    // entry fun manager_deposit_buck_fountain<C_TOKEN, R_TOKEN>(
    //     version: &Version,
    //     registry: &mut Registry,
    //     index: u64,
    //     bucket_protocol: &mut BucketProtocol,
    //     flask: &mut sbuck::Flask<BUCK>,
    //     fountain: &mut Fountain<SBUCK, R_TOKEN>,
    //     clock: &Clock,
    //     mut lending_amount: Option<u64>, // none => deposit all
    //     ctx: &mut TxContext,
    // ) {
    //     // safety check
    //     admin::verify(version, ctx);

    //     let liquidity_pool = get_mut_liquidity_pool(registry, index);
    //     assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
    //     let token_pool = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<C_TOKEN>());
    //     assert!(token_pool.state.is_active, error::token_pool_already_active());
    //     assert!(
    //         math::get_u64_vector_value(&token_pool.config.spot_config.enable_lending, I_LENDING_BUCK_FOUNTAIN) == 1,
    //         error::token_not_available_for_lending()
    //     );

    //     let max_lending_amount = token_pool.state.liquidity_amount - token_pool.state.reserved_amount;
    //     let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_SCALLOP_BASIC) +
    //     math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_BUCK_FOUNTAIN);
    //     let capacity = if (max_lending_amount >= current_lending_amount) {
    //         max_lending_amount - current_lending_amount
    //     } else { 0 };

    //     let real_lending_amount = if (lending_amount.is_none()) {
    //         capacity
    //     } else {
    //         let lending_amount = lending_amount.extract();
    //         if (capacity >= lending_amount) { lending_amount } else { capacity }
    //     };

    //     if (real_lending_amount > 0) {
    //         let log = deposit_buck_fountain<C_TOKEN, R_TOKEN>(
    //             liquidity_pool,
    //             bucket_protocol,
    //             flask,
    //             fountain,
    //             clock,
    //             real_lending_amount,
    //             ctx,
    //         );
    //         emit(DepositLendingEvent {
    //             index,
    //             c_token_type: type_name::with_defining_ids<C_TOKEN>(),
    //             s_token_type: type_name::with_defining_ids<SBUCK>(),
    //             r_token_type: type_name::with_defining_ids<R_TOKEN>(),
    //             deposit_amount: log[0],
    //             minted_s_token_amount: log[1],
    //             latest_lending_amount: log[2],
    //             latest_s_token_amount: log[3],
    //             latest_reserved_amount: log[4],
    //             latest_liquidity_amount: log[5],
    //             u64_padding: vector::empty()
    //         });
    //     };
    // }

    // entry fun manager_withdraw_buck_fountain<C_TOKEN, R_TOKEN>(
    //     version: &mut Version,
    //     registry: &mut Registry,
    //     index: u64,
    //     bucket_protocol: &mut BucketProtocol,
    //     flask: &mut sbuck::Flask<BUCK>,
    //     fountain: &mut Fountain<SBUCK, R_TOKEN>,
    //     clock: &Clock,
    //     mut withdraw_amount: Option<u64>, // none => withdraw all
    //     ctx: &mut TxContext,
    // ) {
    //     // safety check
    //     admin::verify(version, ctx);

    //     let liquidity_pool = get_mut_liquidity_pool(registry, index);
    //     assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
    //     let token_pool = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<C_TOKEN>());
    //     assert!(token_pool.state.is_active, error::token_pool_already_active());
    //     assert!(
    //         math::get_u64_vector_value(&token_pool.config.spot_config.enable_lending, I_LENDING_BUCK_FOUNTAIN) == 1,
    //         error::token_not_available_for_lending()
    //     );

    //     let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_BUCK_FOUNTAIN);
    //     let (d_amount, final_lending_amount) = if (withdraw_amount.is_none()) {
    //         (current_lending_amount, 0)
    //     } else {
    //         let amount = withdraw_amount.extract();
    //         if (amount >= current_lending_amount) {
    //             (current_lending_amount, 0)
    //         } else {
    //             (amount, current_lending_amount - amount)
    //         }
    //     };

    //     // step 1: withdraw all
    //     if (d_amount > 0) {
    //         let log = withdraw_buck_fountain<C_TOKEN, R_TOKEN>(
    //             version,
    //             liquidity_pool,
    //             bucket_protocol,
    //             flask,
    //             fountain,
    //             clock,
    //         );
    //         emit(WithdrawLendingEvent {
    //             index,
    //             c_token_type: type_name::with_defining_ids<C_TOKEN>(),
    //             s_token_type: type_name::with_defining_ids<SBUCK>(),
    //             r_token_type: type_name::with_defining_ids<R_TOKEN>(),
    //             withdraw_amount: log[0], // s token amount
    //             withdrawn_collateral_amount: log[1], // all balance from lending protocol
    //             latest_lending_amount: log[2], // should be zero (due to withdrawing all)
    //             latest_reserved_amount: log[3],
    //             latest_liquidity_amount: log[4],
    //             lending_interest: log[5], // interest before deducted by fee
    //             protocol_share: log[6], // charged fee
    //             lending_reward: log[7], // reward before deducted by fee
    //             reward_protocol_share: log[8], // charged fee
    //             u64_padding: vector::empty()
    //         });
    //     };

    //     // step 2: deposit to target amount
    //     if (final_lending_amount > 0) {
    //         manager_deposit_buck_fountain<C_TOKEN, R_TOKEN>(
    //             version,
    //             registry,
    //             index,
    //             bucket_protocol,
    //             flask,
    //             fountain,
    //             clock,
    //             option::some(final_lending_amount),
    //             ctx,
    //         );
    //     }
    // }


    /// An event that is emitted when a manager removes a liquidity token.
    public struct ManagerRemoveLiquidityTokenEvent has copy, drop {
        index: u64,
        liquidity_token: TypeName,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Manager removes a liquidity token.
    entry fun manager_remove_liquidity_token<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);
        check_token_pool_status<TOKEN>(registry, index, false);
        let token_type = type_name::with_defining_ids<TOKEN>();
        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        let zero_balance = dynamic_field::remove<TypeName, Balance<TOKEN>>(&mut liquidity_pool.id, type_name::with_defining_ids<TOKEN>());
        zero_balance.destroy_zero();

        let (_, i) = liquidity_pool.liquidity_tokens.index_of(&token_type);
        liquidity_pool.liquidity_tokens.remove(i);

        let mut i = 0;
        let length = vector::length(&liquidity_pool.token_pools);
        while (i < length) {
            if (vector::borrow(&liquidity_pool.token_pools, i).token_type == token_type) {
                break
            };
            i = i + 1;
        };
        let token_pool = vector::remove(&mut liquidity_pool.token_pools, i);
        let TokenPool {
            token_type: _,
            config: _,
            state: _,
        } = token_pool;
        emit(ManagerRemoveLiquidityTokenEvent {
            index,
            liquidity_token: token_type,
            u64_padding: vector::empty()
        });
    }

    public(package) fun check_token_pool_status<TOKEN>(
        registry: &Registry,
        index: u64,
        assert_active: bool
    ) {
        // safety check
        let liquidity_pool = get_liquidity_pool(registry, index);
        let token_pool = get_token_pool(liquidity_pool, &type_name::with_defining_ids<TOKEN>());
        if (assert_active) {
            assert!(token_pool.state.is_active, error::token_pool_inactive());
        } else {
            assert!(!token_pool.state.is_active, error::token_pool_already_active());
        }
    }

    public(package) fun token_pool_is_active(token_pool: &TokenPool): bool {
        token_pool.state.is_active
    }

    // ====== Rebalance Process ======
    // hot potato for controlling rebalance process
    public struct RebalanceProcess {
        index: u64,
        // a = token reducing liquidity, b = token adding liquidity
        // => swap = a to b
        token_type_a: TypeName,
        token_decimal_a: u64,
        token_amount_a: u64,
        oracle_price_a: u64,
        reduced_usd: u64, // in C_USD_DECIMAL
        token_type_b: TypeName,
        token_decimal_b: u64,
        oracle_price_b: u64,
    }
    public struct RebalanceEvent has copy, drop {
        index: u64,
        from_token: TypeName,
        to_token: TypeName,
        rebalance_amount: u64,
        from_token_oracle_price: u64,
        to_token_oracle_price: u64,
        reduced_usd: u64,
        tvl_usd: u64,
        from_token_liquidity_amount: u64,
        to_token_liquidity_amount: u64,
        u64_padding: vector<u64>
    }

    /// [Authorized Function] Manager take the liquidity token A to swap.
    public fun rebalance<A_TOKEN, B_TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        oracle_token_a: &Oracle,
        oracle_token_b: &Oracle,
        rebalance_amount: u64, // amount of A_TOKEN (to be swapped)
        clock: &Clock,
        ctx: &TxContext
    ): (RebalanceProcess, Balance<A_TOKEN>) {
        // safety check
        admin::verify(version, ctx);
        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        let liquidity_token_decimal_a = get_token_pool(liquidity_pool, &type_name::with_defining_ids<A_TOKEN>()).config.liquidity_token_decimal;
        let liquidity_token_decimal_b = get_token_pool(liquidity_pool, &type_name::with_defining_ids<B_TOKEN>()).config.liquidity_token_decimal;

        let (price_token_a_to_usd, price_a_decimal) = oracle_token_a.get_price_with_interval_ms(clock, 0);
        let (price_token_b_to_usd, _price_b_decimal) = oracle_token_b.get_price_with_interval_ms(clock, 0);

        let (balance, from_token_liquidity_amount) = {
            let balance = dynamic_field::borrow_mut<TypeName, Balance<A_TOKEN>>(
                &mut liquidity_pool.id,
                type_name::with_defining_ids<A_TOKEN>()
            ).split(rebalance_amount);
            let token_pool_a = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<A_TOKEN>());
            assert!(token_pool_a.state.is_active, error::token_pool_already_active());
            assert!(object::id_address(oracle_token_a) == token_pool_a.config.oracle_id, error::oracle_mismatched());
            // update liquidity_amount
            token_pool_a.state.liquidity_amount = token_pool_a.state.liquidity_amount - balance.value();
            // check liquidity_amount >= reserved_amount
            assert!(token_pool_a.state.liquidity_amount >= token_pool_a.state.reserved_amount, error::liquidity_not_enough());
            (balance, token_pool_a.state.liquidity_amount)
        };

        let reduced_usd = math::amount_to_usd(
            rebalance_amount,
            liquidity_token_decimal_a,
            price_token_a_to_usd,
            price_a_decimal
        );

        let to_token_liquidity_amount = {
            let token_pool_b = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<B_TOKEN>());
            assert!(token_pool_b.state.is_active, error::token_pool_already_active());
            assert!(object::id_address(oracle_token_b) == token_pool_b.config.oracle_id, error::oracle_mismatched());
            token_pool_b.state.liquidity_amount
        };
        let rebalance_process = RebalanceProcess {
            index,
            token_type_a: type_name::with_defining_ids<A_TOKEN>(),
            token_decimal_a: liquidity_token_decimal_a,
            token_amount_a: rebalance_amount,
            oracle_price_a: price_token_a_to_usd,
            reduced_usd,
            token_type_b: type_name::with_defining_ids<B_TOKEN>(),
            token_decimal_b: liquidity_token_decimal_b,
            oracle_price_b: price_token_b_to_usd,
        };

        // update tvl
        update_tvl(version, liquidity_pool, type_name::with_defining_ids<A_TOKEN>(), oracle_token_a, clock);
        let tvl_usd = liquidity_pool.pool_info.tvl_usd;

        emit(RebalanceEvent {
            index,
            from_token: type_name::with_defining_ids<A_TOKEN>(),
            to_token: type_name::with_defining_ids<B_TOKEN>(),
            rebalance_amount,
            from_token_oracle_price: price_token_a_to_usd,
            to_token_oracle_price: price_token_b_to_usd,
            reduced_usd,
            tvl_usd,
            from_token_liquidity_amount, // after withdrawing balance
            to_token_liquidity_amount,
            u64_padding: vector::empty(),
        });

        (rebalance_process, balance)
    }

    public struct CompleteRebalancingEvent has copy, drop {
        index: u64,
        from_token: TypeName,
        to_token: TypeName,
        from_token_oracle_price: u64,
        to_token_oracle_price: u64,
        swapped_back_usd: u64,
        tvl_usd: u64,
        from_token_liquidity_amount: u64,
        to_token_liquidity_amount: u64,
        u64_padding: vector<u64>
    }

    /// [Authorized Function] Manager swap back the liquidity token from A to B.
    public fun complete_rebalancing<A_TOKEN, B_TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        oracle_token_a: &Oracle,
        oracle_token_b: &Oracle,
        swapped_back_balance: Balance<B_TOKEN>,
        rebalance_process: RebalanceProcess,
        clock: &Clock,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);
        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        let rebalance_cost_threshold_bp = math::get_u64_vector_value(&liquidity_pool.u64_padding, I_REBALANCE_COST_THRESHOLD_BP);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        let liquidity_token_decimal_a = get_token_pool(liquidity_pool, &type_name::with_defining_ids<A_TOKEN>()).config.liquidity_token_decimal;
        let liquidity_token_decimal_b = get_token_pool(liquidity_pool, &type_name::with_defining_ids<B_TOKEN>()).config.liquidity_token_decimal;
        let (price_token_a_to_usd, _price_a_decimal) = oracle_token_a.get_price_with_interval_ms(clock, 0);
        let (price_token_b_to_usd, price_b_decimal) = oracle_token_b.get_price_with_interval_ms(clock, 0);

        let from_token_liquidity_amount = {
            let token_pool_a = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<A_TOKEN>());
            assert!(token_pool_a.state.is_active, error::token_pool_already_active());
            assert!(object::id_address(oracle_token_a) == token_pool_a.config.oracle_id, error::oracle_mismatched());
            token_pool_a.state.liquidity_amount
        };

        let (swapped_back_usd, to_token_liquidity_amount) = {
            let token_pool_b = get_mut_token_pool(liquidity_pool, &type_name::with_defining_ids<B_TOKEN>());
            assert!(token_pool_b.state.is_active, error::token_pool_already_active());
            assert!(object::id_address(oracle_token_b) == token_pool_b.config.oracle_id, error::oracle_mismatched());
            let swapped_back_usd = math::amount_to_usd(
                swapped_back_balance.value(),
                token_pool_b.config.liquidity_token_decimal,
                price_token_b_to_usd,
                price_b_decimal
            );
            let RebalanceProcess {
                index: pool_index,
                token_type_a,
                token_decimal_a,
                token_amount_a: _,
                oracle_price_a,
                reduced_usd,
                token_type_b,
                token_decimal_b,
                oracle_price_b,
            } = rebalance_process;

            assert!(index == pool_index, error::rebalance_process_field_mismatched());
            assert!(token_type_a == type_name::with_defining_ids<A_TOKEN>(), error::rebalance_process_field_mismatched());
            assert!(token_decimal_a == liquidity_token_decimal_a, error::rebalance_process_field_mismatched());
            assert!(oracle_price_a == price_token_a_to_usd, error::rebalance_process_field_mismatched());
            assert!(token_type_b == type_name::with_defining_ids<B_TOKEN>(), error::rebalance_process_field_mismatched());
            assert!(token_decimal_b == liquidity_token_decimal_b, error::rebalance_process_field_mismatched());
            assert!(oracle_price_b == price_token_b_to_usd, error::rebalance_process_field_mismatched());
            let bp_scale = math::get_bp_scale();
            assert!(
                ((swapped_back_usd as u128) * ((bp_scale + rebalance_cost_threshold_bp) as u128) / (bp_scale as u128) as u64) >= reduced_usd,
                error::exceed_rebalance_cost_threshold()
            );

            // update liquidity_amount
            token_pool_b.state.liquidity_amount = token_pool_b.state.liquidity_amount + swapped_back_balance.value();
            (swapped_back_usd, token_pool_b.state.liquidity_amount)
        };

        dynamic_field::borrow_mut<TypeName, Balance<B_TOKEN>>(&mut liquidity_pool.id, type_name::with_defining_ids<B_TOKEN>()).join(swapped_back_balance);

        // update tvl
        update_tvl(version, liquidity_pool, type_name::with_defining_ids<B_TOKEN>(), oracle_token_b, clock);
        let tvl_usd = liquidity_pool.pool_info.tvl_usd;

        emit(CompleteRebalancingEvent {
            index,
            from_token: type_name::with_defining_ids<A_TOKEN>(),
            to_token: type_name::with_defining_ids<B_TOKEN>(),
            from_token_oracle_price: price_token_a_to_usd,
            to_token_oracle_price: price_token_b_to_usd,
            swapped_back_usd,
            tvl_usd,
            from_token_liquidity_amount,
            to_token_liquidity_amount, // after putting balance
            u64_padding: vector::empty(),
        });

    }

    /// Only for current contract sunset purpose. Will be removed in new contract
    /// [Authorized Function] Manager remove all liquidity of a token.
    public fun manager_remove_all_liquidity<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        ctx: &TxContext
    ): Balance<TOKEN> {
        // safety check
        admin::verify(version, ctx);
        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        let balance = dynamic_field::remove<TypeName, Balance<TOKEN>>(
            &mut liquidity_pool.id,
            type_name::with_defining_ids<TOKEN>()
        );

        balance
    }

    public struct UpdateLiquidityValueEvent has copy, drop {
        sender: address,
        index: u64,
        liquidity_token: TypeName,
        price: u64,
        value_in_usd: u64,
        lp_pool_tvl_usd: u64,
        u64_padding: vector<u64>
    }

    /// [User Function] Update the liquidity value with oracle.
    public fun update_liquidity_value<TOKEN>(
        version: &Version,
        registry: &mut Registry,
        index: u64,
        oracle: &Oracle,
        clock: &Clock,
        ctx: &TxContext
    ) {
        // safety check
        admin::version_check(version);

        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

        let liquidity_token = type_name::with_defining_ids<TOKEN>();
        {
            // check collateral token active
            let token_pool = get_token_pool(liquidity_pool, &liquidity_token);
            assert!(token_pool.state.is_active, error::token_pool_inactive());
        };

        let mut log = update_tvl(
            version,
            liquidity_pool,
            liquidity_token,
            oracle,
            clock,
        );

        let lp_pool_tvl_usd = log.pop_back();
        let value_in_usd = log.pop_back();
        let price = log.pop_back();

        emit(UpdateLiquidityValueEvent {
            sender: tx_context::sender(ctx),
            index,
            liquidity_token,
            price,
            value_in_usd,
            lp_pool_tvl_usd,
            u64_padding: vector::empty()
        });
    }

    /// [View Function] Get the liquidity pool token amounts.
    /// Return [total_share_supply, tvl_usd, token_types, amounts, usds]
    public fun get_pool_liquidity(
        version: &Version,
        registry: &Registry,
        index: u64,
    ): (u64, u64, vector<TypeName>, vector<u64>, vector<u64>) {
        // safety check
        admin::version_check(version);

        let liquidity_pool = get_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

        // iter token_pools
        let mut i = 0;
        let length = vector::length(&liquidity_pool.token_pools);
        let mut token_types = vector::empty<TypeName>();
        let mut amounts = vector::empty<u64>();
        let mut usds = vector::empty<u64>();
        while (i < length) {
            let token_pool = vector::borrow(&liquidity_pool.token_pools, i);
            token_types.push_back(token_pool.token_type);
            amounts.push_back(token_pool.state.liquidity_amount);
            usds.push_back(token_pool.state.value_in_usd);
            i = i + 1;
        };

        (
            liquidity_pool.pool_info.total_share_supply,
            liquidity_pool.pool_info.tvl_usd, // in decimal 9
            token_types,
            amounts,
            usds
        )
    }

    fun update_tvl(
        version: &Version,
        liquidity_pool: &mut LiquidityPool,
        token_type: TypeName,
        oracle: &Oracle,
        clock: &Clock,
    ): vector<u64> {
        let mut log = vector::empty<u64>();
        // safety check
        admin::version_check(version);

        // update state.value_in_usd
        let (previous_value_in_usd, new_value_in_usd) = {
            let (price, decimal) = oracle.get_price_with_interval_ms(clock, 0);
            let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
            let config = token_pool.config;
            assert!(config.oracle_id == object::id_address(oracle), error::oracle_mismatched());
            let previous_value_in_usd = token_pool.state.value_in_usd;
            token_pool.state.value_in_usd = math::amount_to_usd(
                token_pool.state.liquidity_amount,
                config.liquidity_token_decimal,
                price,
                decimal
            );
            token_pool.state.update_ts_ms = clock::timestamp_ms(clock);
            log.push_back(price);
            log.push_back(token_pool.state.value_in_usd);
            (previous_value_in_usd, token_pool.state.value_in_usd)
        };

        // collect state.value_in_usd and update tvl
        liquidity_pool.pool_info.tvl_usd = liquidity_pool.pool_info.tvl_usd + new_value_in_usd - previous_value_in_usd;
        log.push_back(liquidity_pool.pool_info.tvl_usd);
        log
    }

    public(package) fun order_filled<C_TOKEN>(
        liquidity_pool: &mut LiquidityPool,
        add_reserve: bool,
        d_reserve: u64,
        fee_balance: Balance<C_TOKEN>
    ) {
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

        update_reserve_amount<C_TOKEN>(liquidity_pool, add_reserve, d_reserve);

        let token_type = type_name::with_defining_ids<C_TOKEN>();
        let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
        token_pool.state.liquidity_amount = token_pool.state.liquidity_amount + fee_balance.value();
        balance::join(dynamic_field::borrow_mut(&mut liquidity_pool.id, token_type), fee_balance);
    }

    public(package) fun update_reserve_amount<C_TOKEN>(
        liquidity_pool: &mut LiquidityPool,
        add_reserve: bool,
        d_reserve: u64
    ) {
        // assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

        let token_type = type_name::with_defining_ids<C_TOKEN>();
        let token_pool = get_mut_token_pool(liquidity_pool, &token_type);

        if (add_reserve) {
            token_pool.state.reserved_amount = token_pool.state.reserved_amount + d_reserve;
        } else {
            assert!(token_pool.state.reserved_amount >= d_reserve, error::reserve_bookkeeping_error());
            token_pool.state.reserved_amount = token_pool.state.reserved_amount - d_reserve;
        };
    }

    public(package) fun put_collateral<TOKEN>(
        liquidity_pool: &mut LiquidityPool,
        collateral: Balance<TOKEN>,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
    ) {
        let token_type = type_name::with_defining_ids<TOKEN>();
        let deposit_amount = collateral.value();
        balance::join(
            dynamic_field::borrow_mut(&mut liquidity_pool.id, token_type),
            collateral
        );
        // update token_pool.state
        let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
        let config = token_pool.config;
        token_pool.state.liquidity_amount = token_pool.state.liquidity_amount + deposit_amount;
        let liquidity_value_in_usd = math::amount_to_usd(
            token_pool.state.liquidity_amount,
            config.liquidity_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );
        token_pool.state.value_in_usd = liquidity_value_in_usd;
        let mut tvl = 0;
        let mut i = 0;
        let length = vector::length(&liquidity_pool.token_pools);
        while (i < length) {
            let token_pool = vector::borrow(&liquidity_pool.token_pools, i);
            tvl = tvl + token_pool.state.value_in_usd;
            i = i + 1;
        };
        liquidity_pool.pool_info.tvl_usd = tvl;
    }

    public(package) fun request_collateral<TOKEN>(
        liquidity_pool: &mut LiquidityPool,
        collateral_amount: u64,
        collateral_oracle_price: u64,
        collateral_oracle_price_decimal: u64,
    ): Balance<TOKEN> {
        let token_type = type_name::with_defining_ids<TOKEN>();
        let balance
            = dynamic_field::borrow_mut<TypeName, Balance<TOKEN>>(&mut liquidity_pool.id, token_type).split(collateral_amount);

        // update token_pool.state
        let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
        let config = token_pool.config;
        token_pool.state.liquidity_amount = token_pool.state.liquidity_amount - collateral_amount;
        let liquidity_value_in_usd = math::amount_to_usd(
            token_pool.state.liquidity_amount,
            config.liquidity_token_decimal,
            collateral_oracle_price,
            collateral_oracle_price_decimal
        );
        token_pool.state.value_in_usd = liquidity_value_in_usd;
        let mut tvl = 0;
        let mut i = 0;
        let length = vector::length(&liquidity_pool.token_pools);
        while (i < length) {
            let token_pool = vector::borrow(&liquidity_pool.token_pools, i);
            tvl = tvl + token_pool.state.value_in_usd;
            i = i + 1;
        };
        liquidity_pool.pool_info.tvl_usd = tvl;
        balance
    }

    public(package) fun put_receipt_collaterals(
        liquidity_pool: &mut LiquidityPool,
        unsettled_bid_receipts: vector<UnsettledBidReceipt>,
    ) {
        liquidity_pool.liquidated_unsettled_receipts.append(unsettled_bid_receipts);
    }

    public(package) fun get_receipt_collateral(
        liquidity_pool: &mut LiquidityPool,
    ): vector<UnsettledBidReceipt> {
        let mut r = vector::empty<UnsettledBidReceipt>();
        while (liquidity_pool.liquidated_unsettled_receipts.length() > 0) {
            let u = liquidity_pool.liquidated_unsettled_receipts.pop_back();
            r.push_back(u);
        };
        r
    }

    public(package) fun calculate_mint_lp(
        registry: &Registry,
        index: u64,
        token_type: TypeName,
        price: u64,
        price_decimal: u64,
        deposit_amount: u64,
    ): (u64, u64, u64) {
        let liquidity_pool = get_liquidity_pool(registry, index);
        let token_pool = get_token_pool(liquidity_pool, &token_type);

        let deposit_amount_usd = math::amount_to_usd(deposit_amount, token_pool.config.liquidity_token_decimal, price, price_decimal);

        let (_mint_fee, mint_fee_usd) = calculate_lp_fee(
            liquidity_pool,
            token_type,
            deposit_amount,
            deposit_amount_usd,
            true
        );
        assert!(deposit_amount_usd >= mint_fee_usd, error::insufficient_amount_for_mint_fee());

        let mint_amount = if (liquidity_pool.pool_info.tvl_usd > 0) {
            (((deposit_amount_usd - mint_fee_usd) as u128)
                * (liquidity_pool.pool_info.total_share_supply as u128)
                    / (liquidity_pool.pool_info.tvl_usd as u128) as u64)
        } else {
            deposit_amount_usd - mint_fee_usd
        };
        (deposit_amount_usd, mint_fee_usd, mint_amount) // (deposit usd w/o fee deduction, usd fee, lp amount after fee)
    }

    public(package) fun calculate_burn_lp(
        registry: &Registry,
        index: u64,
        token_type: TypeName,
        price: u64,
        price_decimal: u64,
        burn_amount: u64, // LP amount
    ): (u64, u64, u64, u64) {
        let liquidity_pool = get_liquidity_pool(registry, index);
        let token_pool = get_token_pool(liquidity_pool, &token_type);

        assert!(liquidity_pool.pool_info.total_share_supply > 0, error::zero_total_supply());

        let burn_amount_usd = ((burn_amount as u128)
                                    * (liquidity_pool.pool_info.tvl_usd as u128)
                                        / (liquidity_pool.pool_info.total_share_supply as u128) as u64);

        // collateral token amount
        let mut withdraw_token_amount = math::usd_to_amount(burn_amount_usd, token_pool.config.liquidity_token_decimal, price, price_decimal);

        let (burn_fee, burn_fee_usd) = calculate_lp_fee(
            liquidity_pool,
            token_type,
            withdraw_token_amount,
            burn_amount_usd,
            false
        );
        withdraw_token_amount = withdraw_token_amount - burn_fee;
        // (withdraw usd w/o fee, usd fee, collateral token amount after fee, fee)
        (burn_amount_usd, burn_fee_usd, withdraw_token_amount, burn_fee)
    }

    public(package) fun calculate_lp_fee(
        liquidity_pool: &LiquidityPool,
        token_type: TypeName,
        deposit_amount: u64,
        deposit_amount_usd: u64,
        is_mint: bool,
    ): (u64, u64) {
        let spot_config = get_token_pool(liquidity_pool, &token_type).config.spot_config;
        let (basic_fee_bp, additional_fee_bp) = if (is_mint) {
            (spot_config.basic_mint_fee_bp, spot_config.additional_mint_fee_bp)
        } else {
            (spot_config.basic_burn_fee_bp, spot_config.additional_burn_fee_bp)
        };
        calculate_fee_(
            liquidity_pool,
            token_type,
            deposit_amount,
            deposit_amount_usd,
            is_mint,
            basic_fee_bp,
            additional_fee_bp,
        )
    }

    public(package) fun calculate_fee_(
        liquidity_pool: &LiquidityPool,
        token_type: TypeName,
        deposit_amount: u64,
        deposit_amount_usd: u64,
        flow_in: bool,
        basic_fee_bp: u64,
        additional_fee_bp: u64
    ): (u64, u64) {
        let token_pool = get_token_pool(liquidity_pool, &token_type);
        let spot_config = token_pool.config.spot_config;
        let value_in_usd = token_pool.state.value_in_usd;

        let target_amount_to_usd = if (liquidity_pool.pool_info.tvl_usd > 0) {
            ((liquidity_pool.pool_info.tvl_usd as u128)
                * (spot_config.target_weight_bp as u128)
                    / (math::get_bp_scale() as u128) as u64)
        } else {
            0
        };

        let original_usd_diff = if (target_amount_to_usd > value_in_usd) {
            target_amount_to_usd - value_in_usd
        } else {
            value_in_usd - target_amount_to_usd
        };

        let new_value_in_usd = if (flow_in) {
            value_in_usd + deposit_amount_usd
        } else {
            assert!(value_in_usd >= deposit_amount_usd, error::liquidity_not_enough());
            value_in_usd - deposit_amount_usd
        };

        let new_usd_diff = if (target_amount_to_usd > new_value_in_usd) {
            target_amount_to_usd - new_value_in_usd
        } else {
            new_value_in_usd - target_amount_to_usd
        };

        let additional_precision_9 = 1_000_000_000;
        // additional fee:
        // if new deposit will make amount_to_usd further from target_amount_to_usd
        // high_precision = bp + 9 = 13
        let mut additional_fee_high_precision = if (new_usd_diff > original_usd_diff) {
            if (spot_config.target_weight_bp == 0) {
                (basic_fee_bp as u256) * (additional_precision_9 as u256)
            } else if (liquidity_pool.pool_info.tvl_usd == 0) {
                0
            } else {
                let numerator = (additional_fee_bp as u256) * ((new_usd_diff + original_usd_diff) as u256) * (additional_precision_9 as u256);
                let denominator = 2 * (target_amount_to_usd as u256);
                let fee_high_precision = if (numerator / denominator * denominator == numerator) {
                    numerator / denominator
                } else {
                    numerator / denominator + 1
                };
                fee_high_precision
            }
        } else {
            0
        };
        // clip additional_fee_bp to spot_config.basic_mint_fee_bp
        additional_fee_high_precision = if (additional_fee_high_precision > (basic_fee_bp as u256) * (additional_precision_9 as u256)) {
            (basic_fee_bp as u256) * (additional_precision_9 as u256)
        } else {
            additional_fee_high_precision
        };

        // fee bp summation:
        let overall_fee_high_precision = (basic_fee_bp as u256) * (additional_precision_9 as u256) + additional_fee_high_precision;

        let high_precision_scale = (math::get_bp_scale() as u256) * (additional_precision_9 as u256);
        // ceiling to avoid 0 fee
        let fee = (((deposit_amount as u256)
            * overall_fee_high_precision + high_precision_scale - 1)
                / high_precision_scale as u64);
        let fee_usd = (((deposit_amount_usd as u256)
            * overall_fee_high_precision + high_precision_scale - 1)
                / high_precision_scale as u64);

        (fee, fee_usd)
    }

    fun normal_safety_check<TOKEN, LP_TOKEN>(
        version: &Version,
        registry: &Registry,
        index: u64,
        oracle: &Oracle,
        clock: &Clock,
    ) {
        // safety check
        admin::version_check(version);

        // check token type correct
        let liquidity_pool = get_liquidity_pool(registry, index);
        assert!(type_name::with_defining_ids<LP_TOKEN>() == liquidity_pool.lp_token_type, error::lp_token_type_mismatched());
        // check pool active
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());
        // check token pool tvl all updated
        assert!(check_tvl_updated(liquidity_pool, clock), error::tvl_not_yet_updated());

        let collateral_token_type = type_name::with_defining_ids<TOKEN>();
        let token_pool = get_token_pool(liquidity_pool, &collateral_token_type);
        // check collateral token active
        assert!(token_pool.state.is_active, error::token_pool_inactive());
        // check oracle correct
        assert!(object::id_address(oracle) == token_pool.config.oracle_id, error::oracle_mismatched());
    }

    fun calculate_swap_fee(
        liquidity_pool: &LiquidityPool,
        token_type: TypeName,
        amount: u64,
        amount_usd: u64,
        swap_in: bool,
    ): (u64, u64) {
        let spot_config = get_token_pool(liquidity_pool, &token_type).config.spot_config;
        calculate_fee_(
            liquidity_pool,
            token_type,
            amount,
            amount_usd,
            swap_in,
            spot_config.swap_fee_bp,
            spot_config.swap_fee_bp,
        )
    }

    fun check_tvl_updated(
        liquidity_pool: &LiquidityPool,
        clock: &Clock,
    ): bool {
        let current_ts_ms = clock::timestamp_ms(clock);
        let mut liquidity_tokens = liquidity_pool.liquidity_tokens;
        while (vector::length(&liquidity_tokens) > 0) {
            let liquidity_token = vector::pop_back(&mut liquidity_tokens);
            let token_pool = get_token_pool(liquidity_pool, &liquidity_token);
            if (token_pool.state.update_ts_ms < current_ts_ms) {
                return false
            };
        };
        true
    }

    fun calculate_lending_amount_capped(token_pool: &TokenPool, mut lending_amount: Option<u64>): u64 {
        let max_lending_amount = token_pool.state.liquidity_amount - token_pool.state.reserved_amount;
        let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_SCALLOP_BASIC) +
            math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_NAVI);
        let capacity = if (max_lending_amount >= current_lending_amount) {
            max_lending_amount - current_lending_amount
        } else { 0 };

        let real_lending_amount = if (lending_amount.is_none()) {
            capacity
        } else {
            let lending_amount = lending_amount.extract();
            if (capacity >= lending_amount) { lending_amount } else { capacity }
        };
        real_lending_amount
    }

    fun deposit_scallop_basic<C_TOKEN>(
        liquidity_pool: &mut LiquidityPool,
        scallop_version: &ScallopVersion,
        scallop_market: &mut protocol::market::Market,
        clock: &Clock,
        deposit_amount: u64,
        ctx: &mut TxContext,
    ): vector<u64> {
        let token_type = type_name::with_defining_ids<C_TOKEN>();
        let balance
            = dynamic_field::borrow_mut<TypeName, Balance<C_TOKEN>>(&mut liquidity_pool.id, token_type).split(deposit_amount);

        {
            let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
            let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_SCALLOP_BASIC);
            math::set_u64_vector_value(&mut token_pool.state.current_lending_amount, I_LENDING_SCALLOP_BASIC, current_lending_amount + balance.value());
        };

        let (market_coin, mut log) = lending::deposit_scallop_basic<C_TOKEN>(
            balance,
            scallop_version,
            scallop_market,
            clock,
            ctx,
        );

        let market_coin_type = type_name::with_defining_ids<MarketCoin<C_TOKEN>>();
        if (dynamic_field::exists_with_type<TypeName, Balance<MarketCoin<C_TOKEN>>>(
            &liquidity_pool.id, market_coin_type
        )) {
            dynamic_field::borrow_mut<TypeName, Balance<MarketCoin<C_TOKEN>>>(&mut liquidity_pool.id, market_coin_type).join(market_coin.into_balance());
        } else {
            dynamic_field::add<TypeName, Balance<MarketCoin<C_TOKEN>>>(&mut liquidity_pool.id, market_coin_type, market_coin.into_balance());
        };

        let token_pool = get_token_pool(liquidity_pool, &token_type);
        log.append(vector[
            math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_SCALLOP_BASIC),
            dynamic_field::borrow<TypeName, Balance<MarketCoin<C_TOKEN>>>(&liquidity_pool.id, market_coin_type).value(),
            token_pool.state.reserved_amount,
            token_pool.state.liquidity_amount,
        ]);

        log
    }


    fun withdraw_scallop_basic<C_TOKEN>(
        version: &mut Version,
        liquidity_pool: &mut LiquidityPool,
        scallop_version: &ScallopVersion,
        scallop_market: &mut protocol::market::Market,
        clock: &Clock,
        withdraw_amount: u64, // market coin amount
        ctx: &mut TxContext,
    ): vector<u64> {
        let market_coin_type = type_name::with_defining_ids<MarketCoin<C_TOKEN>>();
        let original_value = dynamic_field::borrow<TypeName, Balance<MarketCoin<C_TOKEN>>>(&liquidity_pool.id, market_coin_type).value();
        let market_coin_balance
            = dynamic_field::borrow_mut<TypeName, Balance<MarketCoin<C_TOKEN>>>(&mut liquidity_pool.id, market_coin_type).split(withdraw_amount);

        let (mut balance, mut log) = lending::withdraw_scallop_basic<C_TOKEN>(
            coin::from_balance(market_coin_balance, ctx),
            scallop_version,
            scallop_market,
            clock,
            ctx,
        );

        let token_type = type_name::with_defining_ids<C_TOKEN>();

        let (d_lending_amount, profit, protocol_share) = {
            let token_pool = get_token_pool(liquidity_pool, &token_type);
            let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_SCALLOP_BASIC);
            let d_lending_amount = ((current_lending_amount as u128) * (withdraw_amount as u128) / (original_value as u128) as u64);
            let profit = if (balance.value() >= d_lending_amount) { balance.value() - d_lending_amount } else { 0 };
            let protocol_share = ((profit as u128) * (token_pool.config.spot_config.lending_protocol_share_bp as u128) / (math::get_bp_scale() as u128) as u64);
            (d_lending_amount, profit, protocol_share)
        };

        version.charge_fee(balance.split(protocol_share));
        let value_w_interest_to_lp = balance.value();
        dynamic_field::borrow_mut<TypeName, Balance<C_TOKEN>>(&mut liquidity_pool.id, token_type).join(balance);

        let market_coin_value = dynamic_field::borrow<TypeName, Balance<MarketCoin<C_TOKEN>>>(&liquidity_pool.id, market_coin_type).value();

        let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
        let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_SCALLOP_BASIC);
        math::set_u64_vector_value(&mut token_pool.state.current_lending_amount, I_LENDING_SCALLOP_BASIC, current_lending_amount - d_lending_amount);
        token_pool.state.liquidity_amount = token_pool.state.liquidity_amount + value_w_interest_to_lp - d_lending_amount; // update realized interest into lp pool

        log.append(vector[
            math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_SCALLOP_BASIC),
            market_coin_value,
            token_pool.state.reserved_amount,
            token_pool.state.liquidity_amount,
            profit,
            protocol_share, // charged fee
        ]);

        log
    }

    fun deposit_navi<C_TOKEN>(
        liquidity_pool: &mut LiquidityPool,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<C_TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
        deposit_amount: u64,
        ctx: &mut TxContext,
    ): vector<u64> {
        let token_type = type_name::with_defining_ids<C_TOKEN>();
        let balance
            = dynamic_field::borrow_mut<TypeName, Balance<C_TOKEN>>(&mut liquidity_pool.id, token_type).split(deposit_amount);
        if (balance.value() == 0) {
            balance::destroy_zero(balance);
            return vector::empty()
        };

        {
            let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
            let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_NAVI);
            math::set_u64_vector_value(&mut token_pool.state.current_lending_amount, I_LENDING_NAVI, current_lending_amount + balance.value());
        };

        if (!dynamic_field::exists_(&liquidity_pool.id, K_NAVI_ACCOUNT_CAP)) {
            let navi_account_cap = lending_core::lending::create_account(ctx);
            dynamic_field::add(&mut liquidity_pool.id, K_NAVI_ACCOUNT_CAP, navi_account_cap);
        };
        let navi_account_cap = dynamic_field::borrow(&liquidity_pool.id, K_NAVI_ACCOUNT_CAP);

        lending_core::incentive_v3::deposit_with_account_cap(
            clock,
            storage,
            pool,
            asset,
            coin::from_balance(balance, ctx),
            incentive_v2,
            incentive_v3,
            navi_account_cap,
        );

        let token_pool = get_token_pool(liquidity_pool, &token_type);
        let log = vector[
            math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_NAVI),
            token_pool.state.reserved_amount,
            token_pool.state.liquidity_amount,
        ];

        log
    }

    fun withdraw_navi<C_TOKEN>(
        version: &mut Version,
        liquidity_pool: &mut LiquidityPool,
        oracle_config: &mut oracle::config::OracleConfig,
        price_oracle: &mut oracle::oracle::PriceOracle,
        supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        pyth_price_info: &pyth::price_info::PriceInfoObject,
        feed_address: address,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<C_TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
    ): vector<u64> {
        let navi_account_cap = dynamic_field::borrow_mut(&mut liquidity_pool.id, K_NAVI_ACCOUNT_CAP);
        oracle::oracle_pro::update_single_price(
            clock,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
        );
        let amount = lending_core::pool::unnormal_amount(
            pool,
            (lending_core::logic::user_collateral_balance(
                storage,
                asset,
                lending_core::account::account_owner(navi_account_cap),
            ) as u64),
        );
        let mut balance = lending_core::incentive_v3::withdraw_with_account_cap(
            clock,
            price_oracle,
            storage,
            pool,
            asset,
            amount + 1,
            incentive_v2,
            incentive_v3,
            navi_account_cap,
        );

        let token_type = type_name::with_defining_ids<C_TOKEN>();
        let (d_lending_amount, profit, protocol_share) = {
            let token_pool = get_token_pool(liquidity_pool, &token_type);
            let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_NAVI);
            let d_lending_amount = current_lending_amount - 0; // withdraw all
            let profit = if (balance.value() >= d_lending_amount) { balance.value() - d_lending_amount } else { 0 };
            let protocol_share = ((profit as u128) * (token_pool.config.spot_config.lending_protocol_share_bp as u128) / (math::get_bp_scale() as u128) as u64);
            (d_lending_amount, profit, protocol_share)
        };
        version.charge_fee(balance.split(protocol_share));
        let value_w_interest_to_lp = balance.value();
        dynamic_field::borrow_mut<TypeName, Balance<C_TOKEN>>(&mut liquidity_pool.id, token_type).join(balance);

        let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
        let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_NAVI);
        math::set_u64_vector_value(&mut token_pool.state.current_lending_amount, I_LENDING_NAVI, current_lending_amount - d_lending_amount);
        token_pool.state.liquidity_amount = token_pool.state.liquidity_amount + value_w_interest_to_lp - d_lending_amount; // update realized interest into lp pool

        let log = vector[
            math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_NAVI),
            token_pool.state.reserved_amount,
            token_pool.state.liquidity_amount,
            profit,
            protocol_share, // charged fee
        ];

        log
    }

    fun reward_navi<R_TOKEN>(
        version: &mut Version,
        liquidity_pool: &mut LiquidityPool,
        storage: &mut lending_core::storage::Storage,
        reward_fund: &mut lending_core::incentive_v3::RewardFund<R_TOKEN>,
        coin_types: vector<std::ascii::String>,
        rule_ids: vector<address>,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
    ): vector<u64> {
        let navi_account_cap = dynamic_field::borrow_mut(&mut liquidity_pool.id, K_NAVI_ACCOUNT_CAP);
        let mut reward_balance = lending_core::incentive_v3::claim_reward_with_account_cap(
            clock,
            incentive_v3,
            storage,
            reward_fund,
            coin_types,
            rule_ids,
            navi_account_cap,
        );
        let reward_token_type = type_name::with_defining_ids<R_TOKEN>();

        let (profit, protocol_share) = if (liquidity_pool.liquidity_tokens.contains(&reward_token_type)) {
            let profit = reward_balance.value();
            let protocol_share = {
                let token_pool = get_token_pool(liquidity_pool, &reward_token_type);
                ((profit as u128) * (token_pool.config.spot_config.lending_protocol_share_bp as u128) / (math::get_bp_scale() as u128) as u64)
            };
            let balance_for_lp_pool = reward_balance.split(profit - protocol_share);
            dynamic_field::borrow_mut<TypeName, Balance<R_TOKEN>>(&mut liquidity_pool.id, reward_token_type).join(balance_for_lp_pool);
            let token_pool = get_mut_token_pool(liquidity_pool, &reward_token_type);
            token_pool.state.liquidity_amount = token_pool.state.liquidity_amount + profit - protocol_share;

            (profit, protocol_share)
        } else {
            (0, reward_balance.value())
        };
        version.charge_fee(reward_balance);

        let log = vector[
            profit,
            protocol_share, // charged fee
        ];

        log
    }

    /// An event that is emitted when LP tokens are burned.
    public struct BurnLpEvent has copy, drop {
        sender: address,
        index: u64,
        lp_token_type: TypeName,
        burn_lp_amount: u64,
        burn_amount_usd: u64,
        burn_fee_usd: u64,
        liquidity_token_type: TypeName,
        withdraw_token_amount: u64,
        u64_padding: vector<u64>
    }
    fun burn_lp_<LP_TOKEN, C_TOKEN>(
        version: &mut Version,
        registry: &mut Registry,
        index: u64,
        treasury_caps: &mut TreasuryCaps,
        oracle: &Oracle,
        burn_lp_balance: Balance<LP_TOKEN>, // burn_amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<C_TOKEN> {
        let token_type = type_name::with_defining_ids<C_TOKEN>();
        let (price, price_decimal) = oracle.get_price_with_interval_ms(clock, 0);

        // coin to balance
        let burn_amount = burn_lp_balance.value(); // burn_amount is always <= liquidity_pool.pool_info.total_share_supply

        // calculation
        let (burn_amount_usd, burn_fee_usd, withdraw_token_amount, burn_fee_token_amount)
            = calculate_burn_lp(registry, index, token_type, price, price_decimal, burn_amount);

        // update token_pool.state & liquidity_pool.
        // liquidity_amount -> value_in_usd -> total_share_supply -> tvl
        {
            let liquidity_pool = get_mut_liquidity_pool(registry, index);
            let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
            token_pool.state.liquidity_amount = token_pool.state.liquidity_amount - withdraw_token_amount - burn_fee_token_amount;
            assert!(token_pool.state.liquidity_amount >= token_pool.state.reserved_amount, error::liquidity_not_enough());
        };
        let liquidity_pool = get_mut_liquidity_pool(registry, index);
        liquidity_pool.pool_info.total_share_supply = liquidity_pool.pool_info.total_share_supply - burn_amount;
        update_tvl(version, liquidity_pool, token_type, oracle, clock);

        // burn lp token
        let lp_coin_treasury_cap = treasury_caps::get_mut_treasury_cap(treasury_caps);
        let _lp_coin_amount = coin::burn<LP_TOKEN>(lp_coin_treasury_cap, coin::from_balance(burn_lp_balance, ctx));

        let withdraw_balance = balance::split(
            dynamic_field::borrow_mut<TypeName, Balance<C_TOKEN>>(&mut liquidity_pool.id, token_type),
            withdraw_token_amount
        );
        let fee_balance = balance::split(
            dynamic_field::borrow_mut<TypeName, Balance<C_TOKEN>>(&mut liquidity_pool.id, token_type),
            burn_fee_token_amount
        );
        admin::charge_fee(version, fee_balance);

        emit(BurnLpEvent {
            sender: tx_context::sender(ctx),
            index,
            lp_token_type: liquidity_pool.lp_token_type,
            burn_lp_amount: burn_amount,
            burn_amount_usd,
            burn_fee_usd,
            liquidity_token_type: token_type,
            withdraw_token_amount,
            u64_padding: vector::empty()
        });
        coin::from_balance(withdraw_balance, ctx)
    }

    // fun deposit_buck_fountain<C_TOKEN, R_TOKEN>(
    //     liquidity_pool: &mut LiquidityPool,
    //     bucket_protocol: &mut BucketProtocol,
    //     flask: &mut sbuck::Flask<BUCK>,
    //     fountain: &mut Fountain<SBUCK, R_TOKEN>,
    //     clock: &Clock,
    //     deposit_amount: u64,
    //     ctx: &mut TxContext,
    // ): vector<u64> {
    //     let token_type = type_name::with_defining_ids<C_TOKEN>();
    //     assert!(token_type == type_name::with_defining_ids<BUCK>(), error::unsupported_token_type_for_fountain());
    //     let balance
    //         = dynamic_field::borrow_mut<TypeName, Balance<BUCK>>(&mut liquidity_pool.id, token_type).split(deposit_amount);
    //     {
    //         let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
    //         let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_BUCK_FOUNTAIN);
    //         math::set_u64_vector_value(&mut token_pool.state.current_lending_amount, I_LENDING_BUCK_FOUNTAIN, current_lending_amount + balance.value());
    //     };

    //     let sbuck_balance = buck::buck_to_sbuck(
    //         bucket_protocol,
    //         flask,
    //         clock,
    //         balance,
    //     );
    //     let s_token_value = sbuck_balance.value();
    //     let stake_proof = fountain_core::stake<SBUCK, R_TOKEN>(
    //         clock,
    //         fountain,
    //         sbuck_balance,
    //         C_BUCKET_HARDCODE_LOCK_TIME,
    //         ctx,
    //     );

    //     let stake_proof_type = type_name::with_defining_ids<StakeProof<SBUCK, R_TOKEN>>();
    //     if (dynamic_field::exists_with_type<TypeName, vector<StakeProof<SBUCK, R_TOKEN>>>(
    //         &liquidity_pool.id, stake_proof_type
    //     )) {
    //         dynamic_field::borrow_mut<TypeName, vector<StakeProof<SBUCK, R_TOKEN>>>(&mut liquidity_pool.id, stake_proof_type).push_back(stake_proof);
    //     } else {
    //         dynamic_field::add<TypeName, vector<StakeProof<SBUCK, R_TOKEN>>>(&mut liquidity_pool.id, stake_proof_type, vector[stake_proof]);
    //     };

    //     let mut s_token_amount = 0;
    //     dynamic_field::borrow<TypeName, vector<StakeProof<SBUCK, R_TOKEN>>>(&liquidity_pool.id, stake_proof_type).do_ref!(|stake_proof|{
    //         s_token_amount = s_token_amount + stake_proof.get_proof_stake_amount();
    //     });

    //     let token_pool = get_token_pool(liquidity_pool, &token_type);

    //     vector[
    //         deposit_amount,
    //         s_token_value,
    //         math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_BUCK_FOUNTAIN),
    //         s_token_amount,
    //         token_pool.state.reserved_amount,
    //         token_pool.state.liquidity_amount,
    //     ]
    // }

    // fun withdraw_buck_fountain<C_TOKEN, R_TOKEN>(
    //     version: &mut Version,
    //     liquidity_pool: &mut LiquidityPool,
    //     bucket_protocol: &mut BucketProtocol,
    //     flask: &mut sbuck::Flask<BUCK>,
    //     fountain: &mut Fountain<SBUCK, R_TOKEN>,
    //     clock: &Clock,
    // ): vector<u64> {
    //     let token_type = type_name::with_defining_ids<C_TOKEN>();
    //     assert!(token_type == type_name::with_defining_ids<BUCK>(), error::unsupported_token_type_for_fountain());

    //     let stake_proof_type = type_name::with_defining_ids<StakeProof<SBUCK, R_TOKEN>>();
    //     let stake_proofs = dynamic_field::borrow_mut<TypeName, vector<StakeProof<SBUCK, R_TOKEN>>>(&mut liquidity_pool.id, stake_proof_type);
    //     let mut withdrawn_s_token_amount = 0;
    //     let mut c_token_balance = balance::zero<BUCK>();
    //     let mut r_token_balance = balance::zero<R_TOKEN>();
    //     while (stake_proofs.length() > 0) {
    //         let stake_proof = stake_proofs.pop_back();
    //         let (s_token, r_token) = fountain_core::force_unstake<SBUCK, R_TOKEN>(clock, fountain, stake_proof);
    //         withdrawn_s_token_amount = withdrawn_s_token_amount + s_token.value();
    //         let buck_balance = buck::sbuck_to_buck(
    //             bucket_protocol,
    //             flask,
    //             clock,
    //             s_token,
    //         );
    //         c_token_balance.join(buck_balance);
    //         r_token_balance.join(r_token);
    //     };

    //     let c_token_value = c_token_balance.value();

    //     // c_token
    //     let (profit, protocol_share) = {
    //         let token_pool = get_token_pool(liquidity_pool, &token_type);
    //         let current_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_BUCK_FOUNTAIN);
    //         let profit = c_token_balance.value() - current_lending_amount;
    //         let protocol_share = ((profit as u128) * (token_pool.config.spot_config.lending_protocol_share_bp as u128) / 10000 as u64);
    //         (profit, protocol_share)
    //     };

    //     version.charge_fee(c_token_balance.split(protocol_share));
    //     dynamic_field::borrow_mut<TypeName, Balance<BUCK>>(&mut liquidity_pool.id, token_type).join(c_token_balance);

    //     let collateral_amount = dynamic_field::borrow<TypeName, Balance<C_TOKEN>>(&liquidity_pool.id, token_type).value();

    //     // r_token: exists in c token => share, not existed => all charged
    //     let r_token_type = type_name::with_defining_ids<R_TOKEN>();
    //     let r_token_value = r_token_balance.value();
    //     let (r_token_profit, r_token_protocol_share) = if (liquidity_pool.liquidity_tokens.contains(&r_token_type)) {
    //         let protocol_share = {
    //             let token_pool = get_token_pool(liquidity_pool, &r_token_type);
    //             ((profit as u128) * (token_pool.config.spot_config.lending_protocol_share_bp as u128) / 10000 as u64)
    //         };
    //         version.charge_fee(r_token_balance.split(protocol_share));
    //         dynamic_field::borrow_mut<TypeName, Balance<R_TOKEN>>(&mut liquidity_pool.id, r_token_type).join(r_token_balance);
    //         (r_token_value, protocol_share)
    //     } else {
    //         version.charge_fee(r_token_balance);
    //         (r_token_value, r_token_value)
    //     };

    //     // record state: c token
    //     {
    //         let token_pool = get_mut_token_pool(liquidity_pool, &token_type);
    //         math::set_u64_vector_value(&mut token_pool.state.current_lending_amount, I_LENDING_BUCK_FOUNTAIN, 0);
    //         let current_all_lending_amount = math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_SCALLOP_BASIC)
    //             + math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_BUCK_FOUNTAIN);
    //         token_pool.state.liquidity_amount = collateral_amount + current_all_lending_amount;
    //     };
    //     // record state: r token
    //     if (liquidity_pool.liquidity_tokens.contains(&r_token_type)) {
    //         let token_pool = get_mut_token_pool(liquidity_pool, &r_token_type);
    //         token_pool.state.liquidity_amount = token_pool.state.liquidity_amount + (r_token_profit - r_token_protocol_share);
    //     };

    //     let token_pool = get_token_pool(liquidity_pool, &token_type);
    //     vector[
    //         withdrawn_s_token_amount,
    //         c_token_value,
    //         math::get_u64_vector_value(&token_pool.state.current_lending_amount, I_LENDING_BUCK_FOUNTAIN),
    //         token_pool.state.reserved_amount,
    //         token_pool.state.liquidity_amount,
    //         profit,
    //         protocol_share, // charged fee
    //         r_token_profit,
    //         r_token_protocol_share
    //     ]
    // }

    // ======= View Functions =======
    public(package) fun view_swap_result<F_TOKEN, T_TOKEN>(
        version: &Version,
        registry: &Registry,
        index: u64,
        oracle_from_token: &Oracle,
        oracle_to_token: &Oracle,
        from_amount: u64,
        clock: &Clock,
    ): vector<u64> {
        // safety check
        admin::version_check(version);

        let liquidity_pool = get_liquidity_pool(registry, index);
        assert!(liquidity_pool.pool_info.is_active, error::pool_inactive());

        let (price_f_token_to_usd, price_f_decimal) = oracle_from_token.get_price_with_interval_ms(clock, 0);
        let (price_t_token_to_usd, price_t_decimal) = oracle_to_token.get_price_with_interval_ms(clock, 0);

        // coin to balance
        let f_token_type = type_name::with_defining_ids<F_TOKEN>();
        let t_token_type = type_name::with_defining_ids<T_TOKEN>();
        let f_token_config = get_token_pool(liquidity_pool, &f_token_type).config;
        let t_token_config = get_token_pool(liquidity_pool, &t_token_type).config;
        // check oracle correct
        assert!(object::id_address(oracle_from_token) == f_token_config.oracle_id, error::oracle_mismatched());
        assert!(object::id_address(oracle_to_token) == t_token_config.oracle_id, error::oracle_mismatched());

        // check collateral token active
        let f_token_state = get_token_pool(liquidity_pool, &f_token_type).state;
        let t_token_state = get_token_pool(liquidity_pool, &t_token_type).state;
        assert!(f_token_state.is_active, error::token_pool_inactive());
        assert!(t_token_state.is_active, error::token_pool_inactive());

        // calculate to_amount_value by oracle price
        let from_amount_usd = math::amount_to_usd(
            from_amount,
            f_token_config.liquidity_token_decimal,
            price_f_token_to_usd,
            price_f_decimal
        );
        let to_amount_value = math::usd_to_amount(
            from_amount_usd,
            t_token_config.liquidity_token_decimal,
            price_t_token_to_usd,
            price_t_decimal
        );

        // use both token to calculate fee => then pick the large one => then transform into F_TOKEN unit
        let (f_token_fee, f_token_fee_usd) = calculate_swap_fee(
            liquidity_pool,
            f_token_type,
            from_amount,
            from_amount_usd,
            true,
        );
        let (_t_token_fee, t_token_fee_usd) = calculate_swap_fee(
            liquidity_pool,
            t_token_type,
            to_amount_value,
            from_amount_usd,
            false,
        );

        // real fee in F_TOKEN unit
        let (fee_amount, fee_amount_usd) = if (f_token_fee_usd > t_token_fee_usd) {
            (f_token_fee, f_token_fee_usd)
        } else {
            (
                math::usd_to_amount(
                    t_token_fee_usd,
                    f_token_config.liquidity_token_decimal,
                    price_f_token_to_usd,
                    price_f_decimal
                ),
                t_token_fee_usd
            )
        };

        let to_amount_after_fee = math::usd_to_amount(
            from_amount_usd - fee_amount_usd,
            t_token_config.liquidity_token_decimal,
            price_t_token_to_usd,
            price_t_decimal
        );

        vector[
            to_amount_after_fee,
            fee_amount, // in F_TOKEN
            fee_amount_usd
        ]
    }

    public(package) fun get_receipt_collateral_bcs(
        registry: &Registry,
        index: u64,
    ): vector<vector<u8>> {
        let liquidity_pool = get_liquidity_pool(registry, index);
        let mut result = vector::empty();
        liquidity_pool.liquidated_unsettled_receipts.do_ref!(|unsettled_bid_receipt| {
            let bytes = bcs::to_bytes(unsettled_bid_receipt);
            result.push_back(bytes);
        });
        result
    }

    public(package) fun get_expired_receipt_collateral_bcs(
        registry: &Registry,
        dov_registry: &DovRegistry,
        index: u64, // pool index
    ): vector<vector<u8>> {
        let liquidity_pool = get_liquidity_pool(registry, index);
        let mut result = vector::empty();
        liquidity_pool.liquidated_unsettled_receipts.do_ref!(|unsettled_bid_receipt| {
            let expired = {
                let mut expired = true;
                let bid_receipts = unsettled_bid_receipt.get_bid_receipts();
                bid_receipts.do_ref!(|bid_receipt|{
                    if (!typus_dov_single::check_bid_receipt_expired(dov_registry, bid_receipt)) {
                        expired = false;
                    };
                });
                expired
            };
            if (expired) {
                let bytes = bcs::to_bytes(unsettled_bid_receipt);
                result.push_back(bytes);
            };
        });
        result
    }

    // ======= Helper Functions =======

    public(package) fun get_liquidity_pool(
        registry: &Registry,
        index: u64,
    ): &LiquidityPool {
        dynamic_object_field::borrow<u64, LiquidityPool>(&registry.liquidity_pool_registry, index)
    }

    public(package) fun get_mut_liquidity_pool(
        registry: &mut Registry,
        index: u64,
    ): &mut LiquidityPool {
        dynamic_object_field::borrow_mut<u64, LiquidityPool>(&mut registry.liquidity_pool_registry, index)
    }

    public(package) fun safety_check(
        liquidity_pool: &LiquidityPool,
        token_type: TypeName,
        oracle_id: address
    ) {
        assert!(liquidity_pool.check_active(), error::pool_inactive());
        assert!(liquidity_pool.oracle_matched(token_type, oracle_id), error::oracle_mismatched());
    }

    public(package) fun check_active(liquidity_pool: &LiquidityPool): bool {
        liquidity_pool.pool_info.is_active
    }

    public(package) fun oracle_matched(
        liquidity_pool: &LiquidityPool,
        token_type: TypeName,
        oracle_id: address
    ): bool {
        let mut i = 0;
        let length = liquidity_pool.token_pools.length();
        while (i < length) {
            let token_pool = &liquidity_pool.token_pools[i];
            if (token_pool.token_type == token_type && token_pool.config.oracle_id == oracle_id) {
                return true
            };
            i = i + 1;
        };
        false
    }

    public(package) fun get_token_pool(liquidity_pool: &LiquidityPool, token_type: &TypeName): &TokenPool {
        let mut i = 0;
        let length = vector::length(&liquidity_pool.token_pools);
        while (i < length) {
            if (vector::borrow(&liquidity_pool.token_pools, i).token_type == *token_type) {
                return vector::borrow(&liquidity_pool.token_pools, i)
            };
            i = i + 1;
        };
        abort error::liquidity_token_not_existed()
    }

    public(package) fun get_mut_token_pool(liquidity_pool: &mut LiquidityPool, token_type: &TypeName): &mut TokenPool {
        let mut i = 0;
        let length = vector::length(&liquidity_pool.token_pools);
        while (i < length) {
            if (vector::borrow(&liquidity_pool.token_pools, i).token_type == *token_type) {
                return vector::borrow_mut(&mut liquidity_pool.token_pools, i)
            };
            i = i + 1;
        };
        abort error::liquidity_token_not_existed()
    }

    public(package) fun get_lp_token_type(
        registry: &Registry,
        index: u64,
    ): TypeName {
        let liquidity_pool = get_liquidity_pool(registry, index);
        liquidity_pool.lp_token_type
    }

    public(package) fun get_liquidity_token_decimal(
        registry: &Registry,
        index: u64,
        liquidity_token: TypeName,
    ): u64 {
        let liquidity_pool = get_liquidity_pool(registry, index);
        let token_pool = get_token_pool(liquidity_pool, &liquidity_token);
        token_pool.config.liquidity_token_decimal
    }

    public(package) fun get_token_pool_state(
        liquidity_pool: &LiquidityPool,
        liquidity_token: TypeName,
    ): vector<u64> {
        let token_pool = get_token_pool(liquidity_pool, &liquidity_token);
        vector[
            token_pool.state.liquidity_amount,
            token_pool.state.value_in_usd,
            token_pool.state.reserved_amount,
            token_pool.state.update_ts_ms,
            token_pool.state.last_borrow_rate_ts_ms,
            token_pool.state.cumulative_borrow_rate,
        ]
    }

    public(package) fun check_trading_order_size_valid(
        liquidity_pool: &LiquidityPool,
        liquidity_token: TypeName,
        reserve_amount: u64,
    ): bool {
        let token_pool = get_token_pool(liquidity_pool, &liquidity_token);
        let max_single_order_reserve_amount = ((token_pool.state.liquidity_amount as u128)
            * (token_pool.config.margin_config.max_order_reserve_ratio_bp as u128)
                / (math::get_bp_scale() as u128) as u64);
        max_single_order_reserve_amount >= reserve_amount
    }

    public(package) fun get_cumulative_borrow_rate(
        liquidity_pool: &LiquidityPool,
        liquidity_token: TypeName
    ): u64 {
        let token_pool = get_token_pool(liquidity_pool, &liquidity_token);
        token_pool.state.cumulative_borrow_rate
    }

    public(package) fun get_tvl_usd(
        liquidity_pool: &LiquidityPool,
    ): u64 {
        liquidity_pool.pool_info.tvl_usd
    }

    public(package) fun get_borrow_rate_decimal(): u64 { C_BORROW_RATE_DECIMAL }

    fun deprecated() { abort 0 }

    public(package) fun get_user_deactivating_shares<LP_TOKEN>(
        registry: &Registry,
        index: u64,
        user: address,
    ): vector<vector<u8>> {
        let liquidity_pool = get_liquidity_pool(registry, index);
        assert!(type_name::with_defining_ids<LP_TOKEN>() == liquidity_pool.lp_token_type, error::lp_token_type_mismatched());
        let pool_deactivating_shares = dynamic_field::borrow<String, Table<address, vector<DeactivatingShares<LP_TOKEN>>>>(
            &liquidity_pool.id, string::utf8(K_DEACTIVATING_SHARES)
        );

        let mut result = vector::empty();
        if (pool_deactivating_shares.contains(user)) {
            let user_deactivating_shares = pool_deactivating_shares.borrow(user);
            user_deactivating_shares.do_ref!(|share| {
                let bytes = bcs::to_bytes(share);
                result.push_back(bytes);
            });
        };
        result
    }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public(package) fun test_get_mut_liquidity_pool(registry: &mut Registry, index: u64): &mut LiquidityPool {
        get_mut_liquidity_pool(registry, index)
    }

    #[test_only]
    public(package) fun test_get_spot_config<TOKEN>(registry: &Registry, index: u64): SpotConfig {
        let token_type = type_name::with_defining_ids<TOKEN>();
        let liquidity_pool = get_liquidity_pool(registry, index);
        let token_pool = get_token_pool(liquidity_pool, &token_type);
        token_pool.config.spot_config
    }

    #[test_only]
    public(package) fun test_get_margin_config<TOKEN>(registry: &Registry, index: u64): MarginConfig {
        let token_type = type_name::with_defining_ids<TOKEN>();
        let liquidity_pool = get_liquidity_pool(registry, index);
        let token_pool = get_token_pool(liquidity_pool, &token_type);
        token_pool.config.margin_config
    }

    #[test_only]
    public(package) fun test_check_target_weight_bp<TOKEN>(registry: &Registry, index: u64, target_weight_bp: u64): bool {
        let token_type = type_name::with_defining_ids<TOKEN>();
        let liquidity_pool = get_liquidity_pool(registry, index);
        let token_pool = get_token_pool(liquidity_pool, &token_type);
        token_pool.config.spot_config.target_weight_bp == target_weight_bp
    }

    #[test_only]
    public(package) fun test_check_basic_borrow_rate<TOKEN>(registry: &Registry, index: u64, basic_borrow_rate: u64): bool {
        let token_type = type_name::with_defining_ids<TOKEN>();
        let liquidity_pool = get_liquidity_pool(registry, index);
        let token_pool = get_token_pool(liquidity_pool, &token_type);
        std::debug::print(&token_pool.config.margin_config.basic_borrow_rate_0);
        std::debug::print(&basic_borrow_rate);
        token_pool.config.margin_config.basic_borrow_rate_0 == basic_borrow_rate
    }

    // ======= Deprecated =======
}

