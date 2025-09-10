module lending_core::dynamic_calculator {
    public fun calculate_current_index(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: u8) : (u256, u256) {
        let (v0, v1) = lending_core::storage::get_index(arg1, arg2);
        let (v2, v3) = lending_core::storage::get_current_rate(arg1, arg2);
        let v4 = ((0x2::clock::timestamp_ms(arg0) - lending_core::storage::get_last_update_timestamp(arg1, arg2)) as u256) / 1000;
        (lending_core::ray_math::ray_mul(lending_core::calculator::calculate_linear_interest(v4, v2), v0), lending_core::ray_math::ray_mul(lending_core::calculator::calculate_compounded_interest(v4, v3), v1))
    }

    public fun dynamic_caculate_utilization(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: u8, arg3: u256, arg4: u256, arg5: bool) : u256 {
        let (v0, v1) = lending_core::storage::get_total_supply(arg1, arg2);
        let mut v2 = v1;
        let mut v3 = v0;
        if (arg3 > 0) {
            if (arg5) {
                v3 = v0 + arg3;
            } else {
                v3 = v0 - arg3;
            };
        };
        if (arg4 > 0) {
            if (arg5) {
                v2 = v1 + arg4;
            } else {
                v2 = v1 - arg4;
            };
        };
        let (v4, v5) = calculate_current_index(arg0, arg1, arg2);
        let v6 = lending_core::ray_math::ray_mul(v2, v5);
        if (v6 == 0) {
            0
        } else {
            lending_core::ray_math::ray_div(v6, lending_core::ray_math::ray_mul(v3, v4))
        }
    }

    public fun dynamic_calculate_apy<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &mut lending_core::pool::Pool<T0>, arg3: u8, arg4: u64, arg5: u64, arg6: bool) : (u256, u256) {
        let v0 = arg4 > 0 && arg5 > 0;
        assert!(!v0, lending_core::error::non_single_value());
        let mut v1 = 0;
        if (arg4 > 0) {
            v1 = lending_core::pool::normal_amount<T0>(arg2, arg4);
        };
        let mut v2 = 0;
        if (arg5 > 0) {
            v2 = lending_core::pool::normal_amount<T0>(arg2, arg5);
        };
        let v3 = dynamic_calculate_borrow_rate(arg0, arg1, arg3, v1 as u256, v2 as u256, arg6);
        (v3, dynamic_calculate_supply_rate(arg0, arg1, arg3, v3, v1 as u256, v2 as u256, arg6))
    }

    public fun dynamic_calculate_borrow_rate(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: u8, arg3: u256, arg4: u256, arg5: bool) : u256 {
        let (v0, v1, v2, _, v4) = lending_core::storage::get_borrow_rate_factors(arg1, arg2);
        let v5 = dynamic_caculate_utilization(arg0, arg1, arg2, arg3, arg4, arg5);
        if (v5 < v4) {
            v0 + lending_core::ray_math::ray_mul(v5, v1)
        } else {
            v0 + lending_core::ray_math::ray_mul(v5, v1) + lending_core::ray_math::ray_mul(v5 - v4, v2)
        }
    }

    public fun dynamic_calculate_supply_rate(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: u8, arg3: u256, arg4: u256, arg5: u256, arg6: bool) : u256 {
        let (_, _, _, v3, _) = lending_core::storage::get_borrow_rate_factors(arg1, arg2);
        lending_core::ray_math::ray_mul(lending_core::ray_math::ray_mul(arg3, dynamic_caculate_utilization(arg0, arg1, arg2, arg4, arg5, arg6)), lending_core::ray_math::ray() - v3)
    }

    public fun dynamic_health_factor<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg3: &mut lending_core::pool::Pool<T0>, arg4: address, arg5: u8, arg6: u64, arg7: u64, arg8: bool) : u256 {
        let v0 = arg6 > 0 && arg7 > 0;
        assert!(!v0, lending_core::error::non_single_value());
        let mut v1 = 0;
        if (arg6 > 0) {
            v1 = lending_core::pool::normal_amount<T0>(arg3, arg6);
        };
        let mut v2 = 0;
        if (arg7 > 0) {
            v2 = lending_core::pool::normal_amount<T0>(arg3, arg7);
        };
        let v3 = dynamic_user_health_loan_value(arg0, arg2, arg1, arg4, arg5, v2 as u256, arg8);
        if (v3 > 0) {
            lending_core::ray_math::ray_mul(lending_core::ray_math::ray_div(dynamic_user_health_collateral_value(arg0, arg2, arg1, arg4, arg5, v1 as u256, arg8), v3), dynamic_liquidation_threshold(arg0, arg1, arg2, arg4, arg5, v1 as u256, arg8))
        } else {
            0x2::address::max()
        }
    }

    public fun dynamic_liquidation_threshold(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg3: address, arg4: u8, arg5: u256, arg6: bool) : u256 {
        let (v0, _) = lending_core::storage::get_user_assets(arg1, arg3);
        let v2 = v0;
        let v3 = 0x1::vector::length<u8>(&v2);
        let mut v4 = v3;
        let mut v5 = 0;
        let mut v6 = v2;
        if (!0x1::vector::contains<u8>(&v2, &arg4)) {
            0x1::vector::push_back<u8>(&mut v6, arg4);
            v4 = v3 + 1;
        };
        let mut v7 = 0;
        let mut v8 = 0;
        while (v5 < v4) {
            let v9 = 0x1::vector::borrow<u8>(&v6, v5);
            let (_, _, v12) = lending_core::storage::get_liquidation_factors(arg1, *v9);
            let mut v13 = 0;
            if (arg4 == *v9) {
                v13 = arg5;
            };
            let v14 = dynamic_user_collateral_value(arg0, arg2, arg1, *v9, arg3, v13, arg6);
            v8 = v8 + lending_core::ray_math::ray_mul(v14, v12);
            v7 = v7 + v14;
            v5 = v5 + 1;
        };
        lending_core::ray_math::ray_div(v8, v7)
    }

    public fun dynamic_user_collateral_balance(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: u8, arg3: address, arg4: u256, arg5: bool) : u256 {
        let (v0, _) = lending_core::storage::get_user_balance(arg1, arg2, arg3);
        let v2 = if (arg5) {
            v0 + arg4
        } else {
            v0 - arg4
        };
        let (v3, _) = calculate_current_index(arg0, arg1, arg2);
        lending_core::ray_math::ray_mul(v2, v3)
    }

    public fun dynamic_user_collateral_value(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: address, arg5: u256, arg6: bool) : u256 {
        lending_core::calculator::calculate_value(arg0, arg1, dynamic_user_collateral_balance(arg0, arg2, arg3, arg4, arg5, arg6), lending_core::storage::get_oracle_id(arg2, arg3))
    }

    public fun dynamic_user_health_collateral_value(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: address, arg4: u8, arg5: u256, arg6: bool) : u256 {
        let (v0, _) = lending_core::storage::get_user_assets(arg2, arg3);
        let v2 = v0;
        let v3 = 0x1::vector::length<u8>(&v2);
        let mut v4 = v3;
        let mut v5 = 0;
        let mut v6 = 0;
        let mut v7 = v2;
        if (!0x1::vector::contains<u8>(&v2, &arg4)) {
            if (arg6) {
                0x1::vector::push_back<u8>(&mut v7, arg4);
                v4 = v3 + 1;
            };
        };
        while (v6 < v4) {
            let v8 = 0x1::vector::borrow<u8>(&v7, v6);
            let mut v9 = 0;
            if (arg4 == *v8) {
                v9 = arg5;
            };
            v5 = v5 + dynamic_user_collateral_value(arg0, arg1, arg2, *v8, arg3, v9, arg6);
            v6 = v6 + 1;
        };
        v5
    }

    public fun dynamic_user_health_loan_value(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: address, arg4: u8, arg5: u256, arg6: bool) : u256 {
        let (_, v1) = lending_core::storage::get_user_assets(arg2, arg3);
        let v2 = v1;
        let v3 = 0x1::vector::length<u8>(&v2);
        let mut v4 = v3;
        let mut v5 = 0;
        let mut v6 = 0;
        let mut v7 = v2;
        if (!0x1::vector::contains<u8>(&v2, &arg4)) {
            if (arg6) {
                0x1::vector::push_back<u8>(&mut v7, arg4);
                v4 = v3 + 1;
            };
        };
        while (v6 < v4) {
            let v8 = 0x1::vector::borrow<u8>(&v7, v6);
            let mut v9 = 0;
            if (arg4 == *v8) {
                v9 = arg5;
            };
            v5 = v5 + dynamic_user_loan_value(arg0, arg1, arg2, *v8, arg3, v9, arg6);
            v6 = v6 + 1;
        };
        v5
    }

    public fun dynamic_user_loan_balance(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: u8, arg3: address, arg4: u256, arg5: bool) : u256 {
        let (_, v1) = lending_core::storage::get_user_balance(arg1, arg2, arg3);
        let v2 = if (arg5) {
            v1 + arg4
        } else {
            v1 - arg4
        };
        let (_, v4) = calculate_current_index(arg0, arg1, arg2);
        lending_core::ray_math::ray_mul(v2, v4)
    }

    public fun dynamic_user_loan_value(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: address, arg5: u256, arg6: bool) : u256 {
        lending_core::calculator::calculate_value(arg0, arg1, dynamic_user_loan_balance(arg0, arg2, arg3, arg4, arg5, arg6), lending_core::storage::get_oracle_id(arg2, arg3))
    }

    // decompiled from Move bytecode v6
}

