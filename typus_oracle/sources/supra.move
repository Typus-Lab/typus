/// This module provides a function to retrieve prices from the Supra oracle.
module typus_oracle::supra {
    use sui::event::emit;
    use SupraOracle::SupraSValueFeed::{get_price, OracleHolder};

    /// Retrieves the price for a given pair from the Supra oracle.
    public fun retrieve_price(
        oracle_holder: &OracleHolder,
        pair: u32
    ): (u128, u16, u128) {
        let (price, decimal, timestamp, round) = get_price(oracle_holder, pair);
        emit(SupraPrice { pair, price, decimal, timestamp, round });
        (price, decimal, timestamp)
    }

    /// Event emitted when a Supra price is retrieved.
    public struct SupraPrice has copy, drop {
        pair: u32,
        price: u128,
        decimal: u16,
        timestamp: u128,
        round: u64
    }
}