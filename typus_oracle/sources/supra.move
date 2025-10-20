module typus_oracle::supra {
    // ======== Deprecated =========

    #[deprecated]
    public fun retrieve_price(
        _oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        _pair: u32
    ): (u128, u16, u128) {
        abort 0
    }

    #[deprecated]
    public struct SupraPrice has copy, drop {
        pair: u32,
        price: u128,
        decimal: u16,
        timestamp: u128,
        round: u64
    }
}