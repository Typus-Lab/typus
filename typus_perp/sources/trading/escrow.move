module typus_perp::escrow {
    use typus_framework::vault::TypusBidReceipt;
    use std::type_name::TypeName;

    public struct UnsettledBidReceipt has store {
        receipt: vector<TypusBidReceipt>,
        position_id: u64,
        user: address,
        token_types: vector<TypeName>, // [C_TOKEN, B_TOKEN]
        unrealized_pnl_sign: bool,
        unrealized_pnl: u64,
        unrealized_trading_fee: u64,
        unrealized_borrow_fee: u64,
        unrealized_funding_fee_sign: bool,
        unrealized_funding_fee: u64,
        unrealized_liquidator_fee: u64,
    }

    public(package) fun create_unsettled_bid_receipt(
        receipt: vector<TypusBidReceipt>,
        position_id: u64,
        user: address,
        token_types: vector<TypeName>,
        unrealized_pnl_sign: bool,
        unrealized_pnl: u64,
        unrealized_trading_fee: u64,
        unrealized_borrow_fee: u64,
        unrealized_funding_fee_sign: bool,
        unrealized_funding_fee: u64,
        unrealized_liquidator_fee: u64
    ): UnsettledBidReceipt {
        UnsettledBidReceipt {
            receipt,
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
        }
    }

    public(package) fun destruct_unsettled_bid_receipt(
        unsettled_bid_receipt: UnsettledBidReceipt
    ): (
        vector<TypusBidReceipt>,
        u64,
        address,
        vector<TypeName>,
        bool,
        u64,
        u64,
        u64,
        bool,
        u64,
        u64,
    ) {
        let UnsettledBidReceipt {
            receipt,
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
        } = unsettled_bid_receipt;
        (
            receipt,
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
        )
    }
    public(package) fun get_bid_receipts(
        unsettled_bid_receipt: &UnsettledBidReceipt
    ): &vector<TypusBidReceipt> {
        &unsettled_bid_receipt.receipt
    }
}