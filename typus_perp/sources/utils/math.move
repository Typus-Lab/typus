/// The `math` module provides mathematical utility functions for the Typus Perpetual Protocol.
module typus_perp::math {

    // ======== Constants ========
    /// The number of decimals for USD.
    const C_USD_DECIMAL: u64 = 9;
    /// The number of decimals for the funding rate.
    const C_FUNDING_RATE_DECIMAL: u64 = 9;
    const C_MBP_SCALE: u64 = 1_000_0000;
    const C_BP_SCALE: u64 = 1_0000;

    /// Sets a value in a `vector<u64>` at a specific index.
    /// It will extend the vector with zeros if the index is out of bounds.
    public fun set_u64_vector_value(u64_vector: &mut vector<u64>, i: u64, value: u64) {
        while (vector::length(u64_vector) < i + 1) {
            vector::push_back(u64_vector, 0);
        };
        *vector::borrow_mut(u64_vector, i) = value;
    }

    /// Gets a value from a `vector<u64>` at a specific index.
    /// It will return 0 if the index is out of bounds.
    public fun get_u64_vector_value(u64_vector: &vector<u64>, i: u64): u64 {
        if (vector::length(u64_vector) > i) {
            return *vector::borrow(u64_vector, i)
        };

        0
    }

    /// Calculates a multiplier for a given number of decimals.
    public(package) fun multiplier(decimal: u64): u64 {
        let mut i = 0;
        let mut multiplier = 1;
        while (i < decimal) {
            multiplier = multiplier * 10;
            i = i + 1;
        };
        multiplier
    }

    /// Converts an amount of a token to USD.
    public(package) fun amount_to_usd(amount: u64, amount_decimal: u64, price: u64, price_decimal: u64): u64 {
        // math::safe_mul_into_decimal(amount, amount_decimal, price, price_decimal, C_USD_DECIMAL)
        ((amount as u256)
            * (price as u256)
            * (multiplier(C_USD_DECIMAL) as u256)
            / (multiplier(price_decimal) as u256)
            / (multiplier(amount_decimal) as u256) as u64)
    }

    /// Converts an amount of USD to a token.
    public(package) fun usd_to_amount(usd: u64, amount_decimal: u64, price: u64, price_decimal: u64): u64 {
        if (price == 0) { return 0 };
        // math::safe_div_into_decimal(usd, C_USD_DECIMAL, price, price_decimal, amount_decimal)
        ((usd as u256)
            * (multiplier(price_decimal) as u256)
            * (multiplier(amount_decimal) as u256)
            / (price as u256)
            / (multiplier(C_USD_DECIMAL) as u256) as u64)
    }

    /// Returns the number of decimals for USD.
    public(package) fun get_usd_decimal(): u64 { C_USD_DECIMAL }
    /// Returns the number of decimals for the funding rate.
    public(package) fun get_funding_rate_decimal(): u64 { C_FUNDING_RATE_DECIMAL }
    public(package) fun get_mbp_scale(): u64 { C_MBP_SCALE }
    public(package) fun get_bp_scale(): u64 { C_BP_SCALE }

    #[test]
    public(package) fun test_usd_to_amount() {
        assert!(usd_to_amount(1, 9, 1_0000_0000, 8) == 1, 0);
        assert!(usd_to_amount(1, 9, 1000000_0000_0000, 8) == 0, 0);
        assert!(usd_to_amount(1000000_0000_00000, 9, 1000000_0000_0000, 8) == 1_0000_00000, 0);
        assert!(usd_to_amount(0, 9, 1_0000_0000, 8) == 0, 0);
        assert!(usd_to_amount(100000_0000_0000, 9, 0, 8) == 0, 0);
    }
}