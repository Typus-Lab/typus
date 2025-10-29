#[allow(deprecated_usage)]
module spool::fixed_point32_empower {
    public fun add(arg0: std::fixed_point32::FixedPoint32, arg1: std::fixed_point32::FixedPoint32) : std::fixed_point32::FixedPoint32 {
        std::fixed_point32::create_from_raw_value(std::fixed_point32::get_raw_value(arg0) + std::fixed_point32::get_raw_value(arg1))
    }

    public fun div(arg0: std::fixed_point32::FixedPoint32, arg1: std::fixed_point32::FixedPoint32) : std::fixed_point32::FixedPoint32 {
        std::fixed_point32::create_from_rational(std::fixed_point32::get_raw_value(arg0), std::fixed_point32::get_raw_value(arg1))
    }

    public fun from_u64(arg0: u64) : std::fixed_point32::FixedPoint32 {
        std::fixed_point32::create_from_rational(arg0, 1)
    }

    public fun gt(arg0: std::fixed_point32::FixedPoint32, arg1: std::fixed_point32::FixedPoint32) : bool {
        std::fixed_point32::get_raw_value(arg0) > std::fixed_point32::get_raw_value(arg1)
    }

    public fun gte(arg0: std::fixed_point32::FixedPoint32, arg1: std::fixed_point32::FixedPoint32) : bool {
        std::fixed_point32::get_raw_value(arg0) >= std::fixed_point32::get_raw_value(arg1)
    }

    public fun mul(arg0: std::fixed_point32::FixedPoint32, arg1: std::fixed_point32::FixedPoint32) : std::fixed_point32::FixedPoint32 {
        std::fixed_point32::create_from_raw_value(((std::fixed_point32::get_raw_value(arg0) as u128) * (std::fixed_point32::get_raw_value(arg1) as u128) >> 32) as u64)
    }

    public fun sub(arg0: std::fixed_point32::FixedPoint32, arg1: std::fixed_point32::FixedPoint32) : std::fixed_point32::FixedPoint32 {
        std::fixed_point32::create_from_raw_value(std::fixed_point32::get_raw_value(arg0) - std::fixed_point32::get_raw_value(arg1))
    }

    public fun zero() : std::fixed_point32::FixedPoint32 {
        std::fixed_point32::create_from_rational(0, 1)
    }

    // decompiled from Move bytecode v6
}

