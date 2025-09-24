module typus_oracle::switchboard_feed_parser {
    // use switchboard_std::aggregator::{Self, Aggregator}; // For reading aggregators
    // use switchboard_std::math;

    // use sui::event::emit;

    // const EAGGREGATOR_INFO_EXISTS:u64 = 0;
    // const ENO_AGGREGATOR_INFO_EXISTS:u64 = 1;

    /*
      Num
      {
        neg: bool,   // sign
        dec: u8,     // scaling factor
        value: u128, // value
      }

      where decimal = neg * value * 10^(-1 * dec)
    */
    #[deprecated]
    public struct AggregatorInfo has copy, drop {
        aggregator_addr: address,
        latest_result: u128,
        latest_result_scaling_factor: u8,
        latest_timestamp: u64,
        negative: bool
    }

    // /* friend typus_oracle::oracle; */

    // // add AggregatorInfo resource with latest value + aggregator address
    // // @return (value, decimal)
    // public(package) fun log_aggregator_info(
    //     feed: &Aggregator
    // ): (u128, u8) {
    //     let (latest_result, latest_timestamp) = aggregator::latest_value(feed);

    //     // get latest value
    //     let (value, scaling_factor, negative) = math::unpack(latest_result);
    //     emit(
    //         AggregatorInfo {
    //             latest_result: value,
    //             latest_result_scaling_factor: scaling_factor,
    //             aggregator_addr: aggregator::aggregator_address(feed),
    //             latest_timestamp,
    //             negative
    //         }
    //     );
    //     (value, scaling_factor)
    // }
}