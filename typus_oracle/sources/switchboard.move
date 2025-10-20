module typus_oracle::switchboard_feed_parser {
    // ======== Deprecated =========

    #[deprecated]
    public struct AggregatorInfo has copy, drop {
        aggregator_addr: address,
        latest_result: u128,
        latest_result_scaling_factor: u8,
        latest_timestamp: u64,
        negative: bool
    }
}