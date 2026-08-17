/// The `escrow` module defines the `UnsettledBidReceipt` struct and functions for creating and destructing it.
/// This is used to handle unsettled bids from liquidations.
module typus_perp::escrow {
    use typus_framework::vault::TypusBidReceipt;
    use std::type_name::TypeName;

    /// A struct that holds information about an unsettled bid receipt.
    public struct UnsettledBidReceipt has store {
        /// A vector of `TypusBidReceipt` structs.
        receipt: vector<TypusBidReceipt>,
        /// The ID of the position.
        position_id: u64,
        /// The address of the user.
        user: address,
        /// A vector of the token types.
        token_types: vector<TypeName>, // [C_TOKEN, B_TOKEN]
        /// The sign of the unrealized PNL.
        unrealized_pnl_sign: bool,
        /// The unrealized PNL.
        unrealized_pnl: u64,
        /// The unrealized trading fee.
        unrealized_trading_fee: u64,
        /// The unrealized borrow fee.
        unrealized_borrow_fee: u64,
        /// The sign of the unrealized funding fee.
        unrealized_funding_fee_sign: bool,
        /// The unrealized funding fee.
        unrealized_funding_fee: u64,
        /// The unrealized liquidator fee.
        unrealized_liquidator_fee: u64,
    }

    /// Creates a new `UnsettledBidReceipt`.
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

    /// Destructs an `UnsettledBidReceipt` and returns its fields.
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
    /// Gets a reference to the bid receipts in an `UnsettledBidReceipt`.
    public(package) fun get_bid_receipts(
        unsettled_bid_receipt: &UnsettledBidReceipt
    ): &vector<TypusBidReceipt> {
        &unsettled_bid_receipt.receipt
    }
}