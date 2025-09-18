module typus_perp::math {

    // ======== Constants ========
    const C_USD_DECIMAL: u64 = 9;
    const C_FUNDING_RATE_DECIMAL: u64 = 9;

    public fun set_u64_vector_value(u64_vector: &mut vector<u64>, i: u64, value: u64) {
        while (vector::length(u64_vector) < i + 1) {
            vector::push_back(u64_vector, 0);
        };
        *vector::borrow_mut(u64_vector, i) = value;
    }

    public fun get_u64_vector_value(u64_vector: &vector<u64>, i: u64): u64 {
        if (vector::length(u64_vector) > i) {
            return *vector::borrow(u64_vector, i)
        };

        0
    }

    public(package) fun multiplier(decimal: u64): u64 {
        let mut i = 0;
        let mut multiplier = 1;
        while (i < decimal) {
            multiplier = multiplier * 10;
            i = i + 1;
        };
        multiplier
    }

    public(package) fun amount_to_usd(amount: u64, amount_decimal: u64, price: u64, price_decimal: u64): u64 {
        // math::safe_mul_into_decimal(amount, amount_decimal, price, price_decimal, C_USD_DECIMAL)
        ((amount as u256)
            * (price as u256)
            * (multiplier(C_USD_DECIMAL) as u256)
            / (multiplier(price_decimal) as u256)
            / (multiplier(amount_decimal) as u256) as u64)
    }

    public(package) fun usd_to_amount(usd: u64, amount_decimal: u64, price: u64, price_decimal: u64): u64 {
        if (price == 0) { return 0 };
        // math::safe_div_into_decimal(usd, C_USD_DECIMAL, price, price_decimal, amount_decimal)
        ((usd as u256)
            * (multiplier(price_decimal) as u256)
            * (multiplier(amount_decimal) as u256)
            / (price as u256)
            / (multiplier(C_USD_DECIMAL) as u256) as u64)
    }

    public(package) fun get_usd_decimal(): u64 { C_USD_DECIMAL }
    public(package) fun get_funding_rate_decimal(): u64 { C_FUNDING_RATE_DECIMAL }
}