/// The `error` module defines the error codes used in the `typus_perp` module.
/// The errors are grouped by the module they belong to.
module typus_perp::error {
    // ======== Errors from lp_pool ========
    // from general operation
    /// The pool is inactive.
    const EPoolInactive: u64 = 0;
    /// The pool is already active.
    const EPoolAlreadyActive: u64 = 1;
    /// The token pool is inactive.
    const ETokenPoolInactive: u64 = 2;
    /// The token pool is already active.
    const ETokenPoolAlreadyActive: u64 = 3;
    /// The LP token type is mismatched. Also used in trading.move.
    const ELpTokenTypeMismatched: u64 = 4;
    /// The liquidity token does not exist.
    const ELiquidityTokenNotExisted: u64 = 5;
    /// The deposit amount is insufficient.
    const EDepositAmountInsufficient: u64 = 6;
    /// The oracle is mismatched. Also used in trading.move.
    const EOracleMismatched: u64 = 7;
    /// The amount is insufficient for the mint fee.
    const EInsufficientAmountForMintFee: u64 = 8;
    /// The total supply is zero.
    const EZeroTotalSupply: u64 = 9;
    /// The TVL has not yet been updated.
    const ETvlNotYetUpdated: u64 = 10;
    /// The liquidity is not enough.
    const ELiquidityNotEnough: u64 = 11;
    /// The maximum capacity has been reached.
    const EReachMaxCapacity: u64 = 12;
    /// The slippage threshold has been reached.
    const EReachSlippageThreshold: u64 = 13;
    /// The friction is too large.
    const EFrictionTooLarge: u64 = 14;
    /// The token type is invalid.
    const EInvalidTokenType: u64 = 15;
    /// The deactivating shares already exist.
    const EDeactivatingSharesAlreadyExisted: u64 = 16;
    /// The user's deactivating shares do not exist.
    const EUserDeactivatingSharesNotExisted: u64 = 17;
    /// The liquidity token already exists.
    const ELiquidityTokenExisted: u64 = 18;
    /// The config range is invalid.
    const EInvalidConfigRange: u64 = 19;
    /// The pool index is mismatched.
    const EPoolIndexMismatched: u64 = 20;
    /// The bookkeeping in reserved_amount is wrong. e.g. negative number.
    const EReserveBookkeepingError: u64 = 21;
    /// The rebalance process field is mismatched.
    const ERebalanceProcessFieldMismatched: u64 = 101;
    /// The rebalance cost threshold has been exceeded.
    const EExceedRebalanceCostThreshold: u64 = 102;
    // from removing liquidity token process
    /// The process should remove the position.
    const EProcessShouldRemovePosition: u64 = 900;
    /// The process should remove the order.
    const EProcessShouldRemoveOrder: u64 = 901;
    /// The process should swap.
    const EProcessShouldSwap: u64 = 902;
    /// The process should repay the liquidity.
    const EProcessShouldRepayLiquidity: u64 = 903;
    /// The process status code is unsupported.
    const EUnsupportedProcessStatusCode: u64 = 904;

    // ======== Errors from oracle ========
    /// The price is zero.
    const EZeroPrice: u64 = 0;


    // ======== Errors from admin ========
    /// The authority already exists.
    const EAuthorityAlreadyExisted: u64 = 0;
    /// The authority does not exist.
    const EAuthorityDoesNotExist: u64 = 1;
    /// The authority is empty.
    const EAuthorityEmpty: u64 = 2;
    /// The version is invalid.
    const EInvalidVersion: u64 = 3;
    /// The user is unauthorized.
    const EUnauthorized: u64 = 4;

    // ======== Errors from position ========
    /// The execution is not reduce-only.
    const ENotReduceOnlyExecution: u64 = 0;
    /// The collateral type is wrong.
    const EWrongCollateralType: u64 = 1;
    /// The bid receipts input is invalid.
    const EInvalidBidReceiptsInput: u64 = 2;
    /// The deposit token is mismatched.
    const EDepositTokenMismatched: u64 = 3;
    /// The linked order ID does not exist.
    const ELinkedOrderIdNotExisted: u64 = 4;
    /// The portfolio index is mismatched.
    const EPortfolioIndexMismatched: u64 = 5;
    /// The order is not an option collateral order.
    const ENotOptionCollateralOrder: u64 = 6;
    /// The position is not an option collateral position. Also used in trading.move.
    const ENotOptionCollateralPosition: u64 = 7;
    /// The position is not a token collateral position.
    const ENotTokenCollateralPosition: u64 = 8;
    /// There are too many linked orders.
    const ETooManyLinkedOrders: u64 = 9;
    /// The position is in the cool-down period.
    const EPositionCoolDownThreshold: u64 = 10;

    // ======== Errors from trading ========
    /// The trading symbol already exists.
    const ETradingSymbolExisted: u64 = 0;
    /// The trading symbol does not exist.
    const ETradingSymbolNotExisted: u64 = 1;
    /// The markets are inactive.
    const EMarketsInactive: u64 = 2;
    /// The trading symbol is inactive.
    const ETradingSymbolInactive: u64 = 3;
    /// The trading symbol is active.
    const EActiveTradingSymbol: u64 = 4;
    /// The order was not found.
    const EOrderNotFound: u64 = 5;
    /// The order type tag is unsupported.
    const EUnsupportedOrderTypeTag: u64 = 6;
    /// The maximum leverage has been exceeded.
    const EExceedMaxLeverage: u64 = 7;
    /// The collateral token type is mismatched.
    const ECollateralTokenTypeMismatched: u64 = 8;
    /// The bid receipt has expired.
    const EBidReceiptHasBeenExpired: u64 = 9;
    /// The bid receipt has not expired.
    const EBidReceiptNotExpired: u64 = 10;
    /// The bid receipt is not in the money.
    const EBidReceiptNotItm: u64 = 11;
    /// The order side is invalid.
    const EInvalidOrderSide: u64 = 12;
    /// The order size is invalid.
    const EInvalidOrderSize: u64 = 13;
    /// Adding size is not allowed.
    const EAddSizeNotAllowed: u64 = 14;
    /// The base token is mismatched.
    const EBaseTokenMismatched: u64 = 15;
    /// The user is mismatched.
    const EUserMismatched: u64 = 16;
    /// The token collateral is not enough.
    const ETokenCollateralNotEnough: u64 = 17;
    /// The option collateral is not enough.
    const EOptionCollateralNotEnough: u64 = 18;
    /// The remaining collateral is not enough.
    const ERemainingCollateralNotEnough: u64 = 19;
    /// The maximum single order reserve usage has been reached.
    const EReachMaxSingleOrderReserveUsage: u64 = 20;
    /// The option collateral order was not filled.
    const EOptionCollateralOrderNotFilled: u64 = 21;
    /// The order was not filled immediately.
    const EOrderNotFilledImmediately: u64 = 22;
    /// The LP pool reserve is not enough.
    const ELpPoolReserveNotEnough: u64 = 23;
    /// There are losses in the perp position.
    const EPerpPositionLosses: u64 = 24;
    /// The trading fee config is invalid.
    const EInvalidTradingFeeConfig: u64 = 25;
    /// The order or position size is not zero.
    const EOrderOrPositionSizeNotZero: u64 = 26;
    /// The balance is not enough for paying the fee.
    const EBalanceNotEnoughForPayingFee: u64 = 27;
    /// A position ID is needed with a reduce-only order.
    const EPositionIdNeededWithReduceOnlyOrder: u64 = 28;
    /// The auction has not yet ended.
    const EAuctionNotYetEnded: u64 = 29;
    /// The bid token is mismatched.
    const EBidTokenMismatched: u64 = 30;
    /// The maximum open interest has been exceeded.
    const EExceedMaxOpenInterest: u64 = 31;
    /// The order price is invalid.
    const EInvalidOrderPrice: u64 = 32;
    /// The user account is invalid.
    const EUserAccount: u64 = 33;
    /// The option collateral position is not supported.
    const EOptionCollateralPositionNotSupported: u64 = 34;

    // ======== Errors from user_account ========
    /// The user is not the owner.
    const ENotOwner: u64 = 0;
    /// There is no balance.
    const ENoBalance: u64 = 1;
    /// The symbols are not empty.
    const ENotEmpty: u64 = 2;

    // ======== Errors from competition ========
    /// The boost bp array length is invalid.
    const EInvalidBoostBpArrayLength: u64 = 0;

    // ======== Errors from profit_vault ========
    const EInvalidIdx: u64 = 0;
    const EWhitelistAlreadyExisted: u64 = 1;
    const EWhitelistNotExisted: u64 = 2;


    // ======== Functions ========
    public(package) fun pool_inactive(): u64 { abort EPoolInactive }
    public(package) fun pool_already_active(): u64 { abort EPoolAlreadyActive }
    public(package) fun token_pool_inactive(): u64 { abort ETokenPoolInactive }
    public(package) fun token_pool_already_active(): u64 { abort ETokenPoolAlreadyActive }
    public(package) fun lp_token_type_mismatched(): u64 { abort ELpTokenTypeMismatched }
    public(package) fun liquidity_token_not_existed(): u64 { abort ELiquidityTokenNotExisted }
    public(package) fun deposit_amount_insufficient(): u64 { abort EDepositAmountInsufficient }
    public(package) fun oracle_mismatched(): u64 { abort EOracleMismatched }
    public(package) fun insufficient_amount_for_mint_fee(): u64 { abort EInsufficientAmountForMintFee }
    public(package) fun zero_total_supply(): u64 { abort EZeroTotalSupply }
    public(package) fun tvl_not_yet_updated(): u64 { abort ETvlNotYetUpdated }
    public(package) fun liquidity_not_enough(): u64 { abort ELiquidityNotEnough }
    public(package) fun reach_max_capacity(): u64 { abort EReachMaxCapacity }
    public(package) fun reach_slippage_threshold(): u64 { abort EReachSlippageThreshold }
    public(package) fun friction_too_large(): u64 { abort EFrictionTooLarge }
    public(package) fun invalid_token_type(): u64 { abort EInvalidTokenType }
    public(package) fun deactivating_shares_already_existed(): u64 { abort EDeactivatingSharesAlreadyExisted }
    public(package) fun user_deactivating_shares_not_existed(): u64 { abort EUserDeactivatingSharesNotExisted }
    public(package) fun liquidity_token_existed(): u64 { abort ELiquidityTokenExisted }
    public(package) fun invalid_config_range(): u64 { abort EInvalidConfigRange }
    public(package) fun pool_index_mismatched(): u64 { abort EPoolIndexMismatched }
    public(package) fun reserve_bookkeeping_error(): u64 { abort EReserveBookkeepingError }

    public(package) fun rebalance_process_field_mismatched(): u64 { abort ERebalanceProcessFieldMismatched }
    public(package) fun exceed_rebalance_cost_threshold(): u64 { abort EExceedRebalanceCostThreshold }

    public(package) fun process_should_remove_position(): u64 { abort EProcessShouldRemovePosition }
    public(package) fun process_should_remove_order(): u64 { abort EProcessShouldRemoveOrder }
    public(package) fun process_should_swap(): u64 { abort EProcessShouldSwap }
    public(package) fun process_should_repay_liquidity(): u64 { abort EProcessShouldRepayLiquidity }
    public(package) fun unsupported_process_status_code(): u64 { abort EUnsupportedProcessStatusCode }

    public(package) fun zero_price(): u64 { abort EZeroPrice }

    public(package) fun authority_already_existed(): u64 { abort EAuthorityAlreadyExisted }
    public(package) fun authority_doest_not_exist(): u64 { abort EAuthorityDoesNotExist }
    public(package) fun authority_empty(): u64 { abort EAuthorityEmpty }
    public(package) fun invalid_version(): u64 { abort EInvalidVersion }
    public(package) fun unauthorized(): u64 { abort EUnauthorized }

    public(package) fun not_reduce_only_execution(): u64 { abort ENotReduceOnlyExecution }
    public(package) fun wrong_collateral_type(): u64 { abort EWrongCollateralType }
    public(package) fun invalid_bid_receipts_input(): u64 { abort EInvalidBidReceiptsInput }
    public(package) fun deposit_token_mismatched(): u64 { abort EDepositTokenMismatched }
    public(package) fun linked_order_id_not_existed(): u64 { abort ELinkedOrderIdNotExisted }
    public(package) fun portfolio_index_mismatched(): u64 { abort EPortfolioIndexMismatched }
    public(package) fun not_option_collateral_order(): u64 { abort ENotOptionCollateralOrder }
    public(package) fun not_option_collateral_position(): u64 { abort ENotOptionCollateralPosition }
    public(package) fun not_token_collateral_position(): u64 { abort ENotTokenCollateralPosition }
    public(package) fun too_many_linked_orders(): u64 { abort ETooManyLinkedOrders }
    public(package) fun position_cool_down_threshold(): u64 { abort EPositionCoolDownThreshold }

    public(package) fun trading_symbol_existed(): u64 { abort ETradingSymbolExisted }
    public(package) fun trading_symbol_not_existed(): u64 { abort ETradingSymbolNotExisted }
    public(package) fun markets_inactive(): u64 { abort EMarketsInactive }
    public(package) fun trading_symbol_inactive(): u64 { abort ETradingSymbolInactive }
    public(package) fun active_trading_symbol(): u64 { abort EActiveTradingSymbol }
    public(package) fun order_not_found(): u64 { abort EOrderNotFound }
    public(package) fun unsupported_order_type_tag(): u64 { abort EUnsupportedOrderTypeTag }
    public(package) fun exceed_max_leverage(): u64 { abort EExceedMaxLeverage }
    public(package) fun collateral_token_type_mismatched(): u64 { abort ECollateralTokenTypeMismatched }
    public(package) fun bid_receipt_has_been_expired(): u64 { abort EBidReceiptHasBeenExpired }
    public(package) fun bid_receipt_not_expired(): u64 { abort EBidReceiptNotExpired }
    public(package) fun bid_receipt_not_itm(): u64 { abort EBidReceiptNotItm }
    public(package) fun invalid_order_side(): u64 { abort EInvalidOrderSide }
    public(package) fun invalid_order_size(): u64 { abort EInvalidOrderSize }
    public(package) fun add_size_not_allowed(): u64 { abort EAddSizeNotAllowed }
    public(package) fun base_token_mismatched(): u64 { abort EBaseTokenMismatched }
    public(package) fun user_mismatched(): u64 { abort EUserMismatched }
    public(package) fun token_collateral_not_enough(): u64 { abort ETokenCollateralNotEnough }
    public(package) fun option_collateral_not_enough(): u64 { abort EOptionCollateralNotEnough }
    public(package) fun remaining_collateral_not_enough(): u64 { abort ERemainingCollateralNotEnough }
    public(package) fun reach_max_single_order_reserve_usage(): u64 { abort EReachMaxSingleOrderReserveUsage }
    public(package) fun option_collateral_order_not_filled(): u64 { abort EOptionCollateralOrderNotFilled }
    public(package) fun order_not_filled_immediately(): u64 { abort EOrderNotFilledImmediately }
    public(package) fun lp_pool_reserve_not_enough(): u64 { abort ELpPoolReserveNotEnough }
    public(package) fun perp_position_losses(): u64 { abort EPerpPositionLosses }
    public(package) fun invalid_trading_fee_config(): u64 { abort EInvalidTradingFeeConfig }
    public(package) fun order_or_position_size_not_zero(): u64 { abort EOrderOrPositionSizeNotZero }
    public(package) fun balance_not_enough_for_paying_fee(): u64 { abort EBalanceNotEnoughForPayingFee }
    public(package) fun position_id_needed_with_reduce_only_order(): u64 { abort EPositionIdNeededWithReduceOnlyOrder }
    public(package) fun auction_not_yet_ended(): u64 { abort EAuctionNotYetEnded }
    public(package) fun bid_token_mismatched(): u64 { abort EBidTokenMismatched }
    public(package) fun exceed_max_open_interest(): u64 { abort EExceedMaxOpenInterest }
    public(package) fun invalid_order_price(): u64 { abort EInvalidOrderPrice }
    public(package) fun invalid_user_account(): u64 { abort EUserAccount }
    public(package) fun option_collateral_position_not_supported(): u64 { abort EOptionCollateralPositionNotSupported }

    public(package) fun not_user_account_owner(): u64 { abort ENotOwner }
    public(package) fun no_balance(): u64 { abort ENoBalance }
    public(package) fun not_user_account_cap(): u64 { abort ENotOwner }
    public(package) fun not_empty_symbols(): u64 { abort ENotEmpty }


    public(package) fun invalid_boost_bp_array_length(): u64 { abort EInvalidBoostBpArrayLength }

    public(package) fun invalid_idx(): u64 { abort EInvalidIdx }
    public(package) fun whitelist_already_existed(): u64 { abort EWhitelistAlreadyExisted }
    public(package) fun whitelist_not_existed(): u64 { abort EWhitelistNotExisted }

}

#[test_only]
module typus_perp::error_tests {
    use typus_perp::error;
    // ======== LP Pool Error Tests ========

    #[test]
    #[expected_failure(abort_code = error::EPoolInactive)]
    fun test_pool_inactive() {
        error::pool_inactive();
    }

    #[test]
    #[expected_failure(abort_code = error::EPoolAlreadyActive)]
    fun test_pool_already_active() {
        error::pool_already_active();
    }

    #[test]
    #[expected_failure(abort_code = error::ETokenPoolInactive)]
    fun test_token_pool_inactive() {
        error::token_pool_inactive();
    }

    #[test]
    #[expected_failure(abort_code = error::ETokenPoolAlreadyActive)]
    fun test_token_pool_already_active() {
        error::token_pool_already_active();
    }

    #[test]
    #[expected_failure(abort_code = error::ELpTokenTypeMismatched)]
    fun test_lp_token_type_mismatched() {
        error::lp_token_type_mismatched();
    }

    #[test]
    #[expected_failure(abort_code = error::ELiquidityTokenNotExisted)]
    fun test_liquidity_token_not_existed() {
        error::liquidity_token_not_existed();
    }

    #[test]
    #[expected_failure(abort_code = error::EDepositAmountInsufficient)]
    fun test_deposit_amount_insufficient() {
        error::deposit_amount_insufficient();
    }

    #[test]
    #[expected_failure(abort_code = error::EOracleMismatched)]
    fun test_oracle_mismatched() {
        error::oracle_mismatched();
    }

    #[test]
    #[expected_failure(abort_code = error::EInsufficientAmountForMintFee)]
    fun test_insufficient_amount_for_mint_fee() {
        error::insufficient_amount_for_mint_fee();
    }

    #[test]
    #[expected_failure(abort_code = error::EZeroTotalSupply)]
    fun test_zero_total_supply() {
        error::zero_total_supply();
    }

    #[test]
    #[expected_failure(abort_code = error::ETvlNotYetUpdated)]
    fun test_tvl_not_yet_updated() {
        error::tvl_not_yet_updated();
    }

    #[test]
    #[expected_failure(abort_code = error::ELiquidityNotEnough)]
    fun test_liquidity_not_enough() {
        error::liquidity_not_enough();
    }

    #[test]
    #[expected_failure(abort_code = error::EReachMaxCapacity)]
    fun test_reach_max_capacity() {
        error::reach_max_capacity();
    }

    #[test]
    #[expected_failure(abort_code = error::EReachSlippageThreshold)]
    fun test_reach_slippage_threshold() {
        error::reach_slippage_threshold();
    }

    #[test]
    #[expected_failure(abort_code = error::EFrictionTooLarge)]
    fun test_friction_too_large() {
        error::friction_too_large();
    }

    #[test]
    #[expected_failure(abort_code = error::EInvalidTokenType)]
    fun test_invalid_token_type() {
        error::invalid_token_type();
    }

    #[test]
    #[expected_failure(abort_code = error::EDeactivatingSharesAlreadyExisted)]
    fun test_deactivating_shares_already_existed() {
        error::deactivating_shares_already_existed();
    }

    #[test]
    #[expected_failure(abort_code = error::EUserDeactivatingSharesNotExisted)]
    fun test_user_deactivating_shares_not_existed() {
        error::user_deactivating_shares_not_existed();
    }

    #[test]
    #[expected_failure(abort_code = error::ELiquidityTokenExisted)]
    fun test_liquidity_token_existed() {
        error::liquidity_token_existed();
    }

    #[test]
    #[expected_failure(abort_code = error::EInvalidConfigRange)]
    fun test_invalid_config_range() {
        error::invalid_config_range();
    }

    #[test]
    #[expected_failure(abort_code = error::EPoolIndexMismatched)]
    fun test_pool_index_mismatched() {
        error::pool_index_mismatched();
    }

    #[test]
    #[expected_failure(abort_code = error::ERebalanceProcessFieldMismatched)]
    fun test_rebalance_process_field_mismatched() {
        error::rebalance_process_field_mismatched();
    }

    #[test]
    #[expected_failure(abort_code = error::EExceedRebalanceCostThreshold)]
    fun test_exceed_rebalance_cost_threshold() {
        error::exceed_rebalance_cost_threshold();
    }

    #[test]
    #[expected_failure(abort_code = error::EProcessShouldRemovePosition)]
    fun test_process_should_remove_position() {
        error::process_should_remove_position();
    }

    #[test]
    #[expected_failure(abort_code = error::EProcessShouldRemoveOrder)]
    fun test_process_should_remove_order() {
        error::process_should_remove_order();
    }

    #[test]
    #[expected_failure(abort_code = error::EProcessShouldSwap)]
    fun test_process_should_swap() {
        error::process_should_swap();
    }

    #[test]
    #[expected_failure(abort_code = error::EProcessShouldRepayLiquidity)]
    fun test_process_should_repay_liquidity() {
        error::process_should_repay_liquidity();
    }

    #[test]
    #[expected_failure(abort_code = error::EUnsupportedProcessStatusCode)]
    fun test_unsupported_process_status_code() {
        error::unsupported_process_status_code();
    }

    // ======== Oracle Error Tests ========

    #[test]
    #[expected_failure(abort_code = error::EZeroPrice)]
    fun test_zero_price() {
        error::zero_price();
    }

    // ======== Admin Error Tests ========

    #[test]
    #[expected_failure(abort_code = error::EAuthorityAlreadyExisted)]
    fun test_authority_already_existed() {
        error::authority_already_existed();
    }

    #[test]
    #[expected_failure(abort_code = error::EAuthorityDoesNotExist)]
    fun test_authority_doest_not_exist() {
        error::authority_doest_not_exist();
    }

    #[test]
    #[expected_failure(abort_code = error::EAuthorityEmpty)]
    fun test_authority_empty() {
        error::authority_empty();
    }

    #[test]
    #[expected_failure(abort_code = error::EInvalidVersion)]
    fun test_invalid_version() {
        error::invalid_version();
    }

    #[test]
    #[expected_failure(abort_code = error::EUnauthorized)]
    fun test_unauthorized() {
        error::unauthorized();
    }

    // ======== Position Error Tests ========

    #[test]
    #[expected_failure(abort_code = error::ENotReduceOnlyExecution)]
    fun test_not_reduce_only_execution() {
        error::not_reduce_only_execution();
    }

    #[test]
    #[expected_failure(abort_code = error::EWrongCollateralType)]
    fun test_wrong_collateral_type() {
        error::wrong_collateral_type();
    }

    #[test]
    #[expected_failure(abort_code = error::EInvalidBidReceiptsInput)]
    fun test_invalid_bid_receipts_input() {
        error::invalid_bid_receipts_input();
    }

    #[test]
    #[expected_failure(abort_code = error::EDepositTokenMismatched)]
    fun test_deposit_token_mismatched() {
        error::deposit_token_mismatched();
    }

    #[test]
    #[expected_failure(abort_code = error::ELinkedOrderIdNotExisted)]
    fun test_linked_order_id_not_existed() {
        error::linked_order_id_not_existed();
    }

    #[test]
    #[expected_failure(abort_code = error::EPortfolioIndexMismatched)]
    fun test_portfolio_index_mismatched() {
        error::portfolio_index_mismatched();
    }

    #[test]
    #[expected_failure(abort_code = error::ENotOptionCollateralOrder)]
    fun test_not_option_collateral_order() {
        error::not_option_collateral_order();
    }

    #[test]
    #[expected_failure(abort_code = error::ENotOptionCollateralPosition)]
    fun test_not_option_collateral_position() {
        error::not_option_collateral_position();
    }

    #[test]
    #[expected_failure(abort_code = error::ENotTokenCollateralPosition)]
    fun test_not_token_collateral_position() {
        error::not_token_collateral_position();
    }

    #[test]
    #[expected_failure(abort_code = error::ETooManyLinkedOrders)]
    fun test_too_many_linked_orders() {
        error::too_many_linked_orders();
    }

    // ======== Trading Error Tests ========

    #[test]
    #[expected_failure(abort_code = error::ETradingSymbolExisted)]
    fun test_trading_symbol_existed() {
        error::trading_symbol_existed();
    }

    #[test]
    #[expected_failure(abort_code = error::ETradingSymbolNotExisted)]
    fun test_trading_symbol_not_existed() {
        error::trading_symbol_not_existed();
    }

    #[test]
    #[expected_failure(abort_code = error::EMarketsInactive)]
    fun test_markets_inactive() {
        error::markets_inactive();
    }

    #[test]
    #[expected_failure(abort_code = error::ETradingSymbolInactive)]
    fun test_trading_symbol_inactive() {
        error::trading_symbol_inactive();
    }

    #[test]
    #[expected_failure(abort_code = error::EActiveTradingSymbol)]
    fun test_active_trading_symbol() {
        error::active_trading_symbol();
    }

    #[test]
    #[expected_failure(abort_code = error::EOrderNotFound)]
    fun test_order_not_found() {
        error::order_not_found();
    }

    #[test]
    #[expected_failure(abort_code = error::EUnsupportedOrderTypeTag)]
    fun test_unsupported_order_type_tag() {
        error::unsupported_order_type_tag();
    }

    #[test]
    #[expected_failure(abort_code = error::EExceedMaxLeverage)]
    fun test_exceed_max_leverage() {
        error::exceed_max_leverage();
    }

    #[test]
    #[expected_failure(abort_code = error::ECollateralTokenTypeMismatched)]
    fun test_collateral_token_type_mismatched() {
        error::collateral_token_type_mismatched();
    }

    #[test]
    #[expected_failure(abort_code = error::EBidReceiptHasBeenExpired)]
    fun test_bid_receipt_has_been_expired() {
        error::bid_receipt_has_been_expired();
    }

    #[test]
    #[expected_failure(abort_code = error::EBidReceiptNotExpired)]
    fun test_bid_receipt_not_expired() {
        error::bid_receipt_not_expired();
    }

    #[test]
    #[expected_failure(abort_code = error::EBidReceiptNotItm)]
    fun test_bid_receipt_not_itm() {
        error::bid_receipt_not_itm();
    }

    #[test]
    #[expected_failure(abort_code = error::EInvalidOrderSide)]
    fun test_invalid_order_side() {
        error::invalid_order_side();
    }

    #[test]
    #[expected_failure(abort_code = error::EInvalidOrderSize)]
    fun test_invalid_order_size() {
        error::invalid_order_size();
    }

    #[test]
    #[expected_failure(abort_code = error::EAddSizeNotAllowed)]
    fun test_add_size_not_allowed() {
        error::add_size_not_allowed();
    }

    #[test]
    #[expected_failure(abort_code = error::EBaseTokenMismatched)]
    fun test_base_token_mismatched() {
        error::base_token_mismatched();
    }

    #[test]
    #[expected_failure(abort_code = error::EUserMismatched)]
    fun test_user_mismatched() {
        error::user_mismatched();
    }

    #[test]
    #[expected_failure(abort_code = error::ETokenCollateralNotEnough)]
    fun test_token_collateral_not_enough() {
        error::token_collateral_not_enough();
    }

    #[test]
    #[expected_failure(abort_code = error::EOptionCollateralNotEnough)]
    fun test_option_collateral_not_enough() {
        error::option_collateral_not_enough();
    }

    #[test]
    #[expected_failure(abort_code = error::ERemainingCollateralNotEnough)]
    fun test_remaining_collateral_not_enough() {
        error::remaining_collateral_not_enough();
    }

    #[test]
    #[expected_failure(abort_code = error::EReachMaxSingleOrderReserveUsage)]
    fun test_reach_max_single_order_reserve_usage() {
        error::reach_max_single_order_reserve_usage();
    }

    #[test]
    #[expected_failure(abort_code = error::EOptionCollateralOrderNotFilled)]
    fun test_option_collateral_order_not_filled() {
        error::option_collateral_order_not_filled();
    }

    #[test]
    #[expected_failure(abort_code = error::EOrderNotFilledImmediately)]
    fun test_order_not_filled_immediately() {
        error::order_not_filled_immediately();
    }

    #[test]
    #[expected_failure(abort_code = error::ELpPoolReserveNotEnough)]
    fun test_lp_pool_reserve_not_enough() {
        error::lp_pool_reserve_not_enough();
    }

    #[test]
    #[expected_failure(abort_code = error::EPerpPositionLosses)]
    fun test_perp_position_losses() {
        error::perp_position_losses();
    }

    #[test]
    #[expected_failure(abort_code = error::EInvalidTradingFeeConfig)]
    fun test_invalid_trading_fee_config() {
        error::invalid_trading_fee_config();
    }

    #[test]
    #[expected_failure(abort_code = error::EOrderOrPositionSizeNotZero)]
    fun test_order_or_position_size_not_zero() {
        error::order_or_position_size_not_zero();
    }

    #[test]
    #[expected_failure(abort_code = error::EBalanceNotEnoughForPayingFee)]
    fun test_balance_not_enough_for_paying_fee() {
        error::balance_not_enough_for_paying_fee();
    }

    #[test]
    #[expected_failure(abort_code = error::EPositionIdNeededWithReduceOnlyOrder)]
    fun test_position_id_needed_with_reduce_only_order() {
        error::position_id_needed_with_reduce_only_order();
    }

    #[test]
    #[expected_failure(abort_code = error::EAuctionNotYetEnded)]
    fun test_auction_not_yet_ended() {
        error::auction_not_yet_ended();
    }

    #[test]
    #[expected_failure(abort_code = error::EBidTokenMismatched)]
    fun test_bid_token_mismatched() {
        error::bid_token_mismatched();
    }

    #[test]
    #[expected_failure(abort_code = error::EExceedMaxOpenInterest)]
    fun test_exceed_max_open_interest() {
        error::exceed_max_open_interest();
    }

    #[test]
    #[expected_failure(abort_code = error::EInvalidOrderPrice)]
    fun test_invalid_order_price() {
        error::invalid_order_price();
    }

    #[test]
    #[expected_failure(abort_code = error::EUserAccount)]
    fun test_invalid_user_account() {
        error::invalid_user_account();
    }
    #[test]
    #[expected_failure(abort_code = error::EOptionCollateralPositionNotSupported)]
    fun test_option_collateral_position_not_supported() {
        error::option_collateral_position_not_supported();
    }

    // ======== User Account Error Tests ========

    #[test]
    #[expected_failure(abort_code = error::ENotOwner)]
    fun test_not_user_account_owner() {
        error::not_user_account_owner();
    }

    #[test]
    #[expected_failure(abort_code = error::ENoBalance)]
    fun test_no_balance() {
        error::no_balance();
    }

    #[test]
    #[expected_failure(abort_code = error::ENotOwner)]
    fun test_not_user_account_cap() {
        error::not_user_account_cap();
    }

    #[test]
    #[expected_failure(abort_code = error::ENotEmpty)]
    fun test_not_empty_symbols() {
        error::not_empty_symbols();
    }

    // ======== Competition Error Tests ========

    #[test]
    #[expected_failure(abort_code = error::EInvalidBoostBpArrayLength)]
    fun test_invalid_boost_bp_array_length() {
        error::invalid_boost_bp_array_length();
    }
}