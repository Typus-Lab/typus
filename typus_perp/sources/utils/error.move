module typus_perp::error {
    // ======== Errors from lp_pool ========
    // from general operation
    const EPoolInactive: u64 = 0;
    const EPoolAlreadyActive: u64 = 1;
    const ETokenPoolInactive: u64 = 2;
    const ETokenPoolAlreadyActive: u64 = 3;
    const ELpTokenTypeMismatched: u64 = 4; // also used in trading.move
    const ELiquidityTokenNotExisted: u64 = 5;
    const EDepositAmountInsufficient: u64 = 6;
    const EOracleMismatched: u64 = 7; // also used in trading.move
    const EInsufficientAmountForMintFee: u64 = 8;
    const EZeroTotalSupply: u64 = 9;
    const ETvlNotYetUpdated: u64 = 10;
    const ELiquidityNotEnough: u64 = 11;
    const EReachMaxCapacity: u64 = 12;
    const EReachSlippageThreshold: u64 = 13;
    const EFrictionTooLarge: u64 = 14;
    const EInvalidTokenType: u64 = 15;
    const EDeactivatingSharesAlreadyExisted: u64 = 16;
    const EUserDeactivatingSharesNotExisted: u64 = 17;
    const ELiquidityTokenExisted: u64 = 18;
    const EInvalidConfigRange: u64 = 19;
    const EPoolIndexMismatched: u64 = 20;
    const ERebalanceProcessFieldMismatched: u64 = 101;
    const EExceedRebalanceCostThreshold: u64 = 102;
    // from removing liquidity token process
    const EProcessShouldRemovePosition: u64 = 900;
    const EProcessShouldRemoveOrder: u64 = 901;
    const EProcessShouldSwap: u64 = 902;
    const EProcessShouldRepayLiquidity: u64 = 903;
    const EUnsupportedProcessStatusCode: u64 = 904;

    // ======== Errors from oracle ========
    const EZeroPrice: u64 = 0;


    // ======== Errors from admin ========
    const EAuthorityAlreadyExisted: u64 = 0;
    const EAuthorityDoesNotExist: u64 = 1;
    const EAuthorityEmpty: u64 = 2;
    const EInvalidVersion: u64 = 3;
    const EUnauthorized: u64 = 4;

    // ======== Errors from position ========
    const ENotReduceOnlyExecution: u64 = 0;
    const EWrongCollateralType: u64 = 1;
    const EInvalidBidReceiptsInput: u64 = 2;
    const EDepositTokenMismatched: u64 = 3;
    const ELinkedOrderIdNotExisted: u64 = 4;
    const EPortfolioIndexMismatched: u64 = 5;
    const ENotOptionCollateralOrder: u64 = 6;
    const ENotOptionCollateralPosition: u64 = 7; // also used in trading.move
    const ENotTokenCollateralPosition: u64 = 8;
    const ETooManyLinkedOrders: u64 = 9;

    // ======== Errors from trading ========
    const ETradingSymbolExisted: u64 = 0;
    const ETradingSymbolNotExisted: u64 = 1;
    const EMarketsInactive: u64 = 2;
    const ETradingSymbolInactive: u64 = 3;
    const EActiveTradingSymbol: u64 = 4;
    const EOrderNotFound: u64 = 5;
    const EUnsupportedOrderTypeTag: u64 = 6;
    const EExceedMaxLeverage: u64 = 7;
    const ECollateralTokenTypeMismatched: u64 = 8;
    const EBidReceiptHasBeenExpired: u64 = 9;
    const EBidReceiptNotExpired: u64 = 10;
    const EBidReceiptNotItm: u64 = 11;
    const EInvalidOrderSide: u64 = 12;
    const EInvalidOrderSize: u64 = 13;
    const EAddSizeNotAllowed: u64 = 14;
    const EBaseTokenMismatched: u64 = 15;
    const EUserMismatched: u64 = 16;
    const ETokenCollateralNotEnough: u64 = 17;
    const EOptionCollateralNotEnough: u64 = 18;
    const ERemainingCollateralNotEnough: u64 = 19;
    const EReachMaxSingleOrderReserveUsage: u64 = 20;
    const EOptionCollateralOrderNotFilled: u64 = 21;
    const EOrderNotFilledImmediately: u64 = 22;
    const ELpPoolReserveNotEnough: u64 = 23;
    const EPerpPositionLosses: u64 = 24;
    const EInvalidTradingFeeConfig: u64 = 25;
    const EOrderOrPositionSizeNotZero: u64 = 26;
    const EBalanceNotEnoughForPayingFee: u64 = 27;
    const EPositionIdNeededWithReduceOnlyOrder: u64 = 28;
    const EAuctionNotYetEnded: u64 = 29;
    const EBidTokenMismatched: u64 = 30;
    const EExceedMaxOpenInterest: u64 = 31;
    const EInvalidOrderPrice: u64 = 32;
    const EUserAccount: u64 = 33;

    // ======== Errors from user_account ========
    const ENotOwner: u64 = 0;
    const ENoBalance: u64 = 1;
    const ENotEmpty: u64 = 2;

    // ======== Errors from competition ========
    const EInvalidBoostBpArrayLength: u64 = 0;


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

    public(package) fun not_user_account_owner(): u64 { abort ENotOwner }
    public(package) fun no_balance(): u64 { abort ENoBalance }
    public(package) fun not_user_account_cap(): u64 { abort ENotOwner }
    public(package) fun not_empty_symbols(): u64 { abort ENotEmpty }


    public(package) fun invalid_boost_bp_array_length(): u64 { abort EInvalidBoostBpArrayLength }
}