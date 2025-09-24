module typus_oracle::supra {
    use sui::event::emit;
    use SupraOracle::SupraSValueFeed::{get_price, OracleHolder};

    public fun retrieve_price(
        oracle_holder: &OracleHolder,
        pair: u32
    ): (u128, u16, u128) {
        let (price, decimal, timestamp, round) = get_price(oracle_holder, pair);
        emit(SupraPrice { pair, price, decimal, timestamp, round });
        (price, decimal, timestamp)
    }

    public struct SupraPrice has copy, drop {
        pair: u32,
        price: u128,
        decimal: u16,
        timestamp: u128,
        round: u64
    }
}