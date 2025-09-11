module lending_core::calculator {
    public fun caculate_utilization(arg0: &mut lending_core::storage::Storage, arg1: u8) : u256 {
        let (v0, v1) = lending_core::storage::get_total_supply(arg0, arg1);
        let (v2, v3) = lending_core::storage::get_index(arg0, arg1);
        let v4 = lending_core::ray_math::ray_mul(v1, v3);
        if (v4 == 0) {
            0
        } else {
            lending_core::ray_math::ray_div(v4, lending_core::ray_math::ray_mul(v0, v2))
        }
    }

    public fun calculate_amount(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: u256, arg3: u8) : u256 {
        let (v0, v1, v2) = 0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::get_token_price(arg0, arg1, arg3);
        assert!(v0, lending_core::error::invalid_price());
        arg2 * (0x2::math::pow(10, v2) as u256) / v1
    }

    public fun calculate_borrow_rate(arg0: &mut lending_core::storage::Storage, arg1: u8) : u256 {
        let (v0, v1, v2, _, v4) = lending_core::storage::get_borrow_rate_factors(arg0, arg1);
        let v5 = caculate_utilization(arg0, arg1);
        if (v5 < v4) {
            v0 + lending_core::ray_math::ray_mul(v5, v1)
        } else {
            v0 + lending_core::ray_math::ray_mul(v4, v1) + lending_core::ray_math::ray_mul(v5 - v4, v2)
        }
    }

    public fun calculate_compounded_interest(arg0: u256, arg1: u256) : u256 {
        if (arg0 == 0) {
            return lending_core::ray_math::ray()
        };
        let v0 = arg0 - 1;
        let mut v1 = 0;
        if (arg0 > 2) {
            v1 = arg0 - 2;
        };
        let v2 = arg1 / lending_core::constants::seconds_per_year();
        let v3 = lending_core::ray_math::ray_mul(v2, v2);
        lending_core::ray_math::ray() + v2 * arg0 + arg0 * v0 * v3 / 2 + arg0 * v0 * v1 * lending_core::ray_math::ray_mul(v3, v2) / 6
    }

    public fun calculate_linear_interest(arg0: u256, arg1: u256) : u256 {
        lending_core::ray_math::ray() + arg1 * arg0 / lending_core::constants::seconds_per_year()
    }

    public fun calculate_supply_rate(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: u256) : u256 {
        let (_, _, _, v3, _) = lending_core::storage::get_borrow_rate_factors(arg0, arg1);
        lending_core::ray_math::ray_mul(lending_core::ray_math::ray_mul(arg2, caculate_utilization(arg0, arg1)), lending_core::ray_math::ray() - v3)
    }

    public fun calculate_value(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: u256, arg3: u8) : u256 {
        let (v0, v1, v2) = 0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::get_token_price(arg0, arg1, arg3);
        assert!(v0, lending_core::error::invalid_price());
        arg2 * v1 / (0x2::math::pow(10, v2) as u256)
    }

    // decompiled from Move bytecode v6
}

