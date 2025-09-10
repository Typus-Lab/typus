module lending_core::logic {
    public struct StateUpdated has copy, drop {
        user: address,
        asset: u8,
        user_supply_balance: u256,
        user_borrow_balance: u256,
        new_supply_index: u256,
        new_borrow_index: u256,
    }

    fun decrease_borrow_balance(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: address, arg3: u256) {
        let (_, v1) = lending_core::storage::get_index(arg0, arg1);
        lending_core::storage::decrease_borrow_balance(arg0, arg1, arg2, lending_core::ray_math::ray_div(arg3, v1));
    }

    fun decrease_supply_balance(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: address, arg3: u256) {
        let (v0, _) = lending_core::storage::get_index(arg0, arg1);
        lending_core::storage::decrease_supply_balance(arg0, arg1, arg2, lending_core::ray_math::ray_div(arg3, v0));
    }

    fun increase_borrow_balance(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: address, arg3: u256) {
        let (_, v1) = lending_core::storage::get_index(arg0, arg1);
        lending_core::storage::increase_borrow_balance(arg0, arg1, arg2, lending_core::ray_math::ray_div(arg3, v1));
    }

    fun increase_supply_balance(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: address, arg3: u256) {
        let (v0, _) = lending_core::storage::get_index(arg0, arg1);
        lending_core::storage::increase_supply_balance(arg0, arg1, arg2, lending_core::ray_math::ray_div(arg3, v0));
    }

    public(package) fun update_interest_rate(arg0: &mut lending_core::storage::Storage, arg1: u8) {
        let v0 = lending_core::calculator::calculate_borrow_rate(arg0, arg1);
        let supply_rate = lending_core::calculator::calculate_supply_rate(arg0, arg1, v0);
        lending_core::storage::update_interest_rate(arg0, arg1, v0, supply_rate);
    }

    fun update_state(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: u8) {
        let v0 = 0x2::clock::timestamp_ms(arg0);
        let v1 = ((v0 - lending_core::storage::get_last_update_timestamp(arg1, arg2)) as u256) / 1000;
        let (v2, v3) = lending_core::storage::get_index(arg1, arg2);
        let (v4, v5) = lending_core::storage::get_current_rate(arg1, arg2);
        let (_, _, _, v9, _) = lending_core::storage::get_borrow_rate_factors(arg1, arg2);
        let (_, v12) = lending_core::storage::get_total_supply(arg1, arg2);
        let v13 = lending_core::ray_math::ray_mul(lending_core::calculator::calculate_linear_interest(v1, v4), v2);
        let v14 = lending_core::ray_math::ray_mul(lending_core::calculator::calculate_compounded_interest(v1, v5), v3);
        let v15 = lending_core::ray_math::ray_div(lending_core::ray_math::ray_mul(lending_core::ray_math::ray_mul(v12, v14 - v3), v9), v13);
        lending_core::storage::update_state(arg1, arg2, v14, v13, v0, v15);
        lending_core::storage::increase_total_supply_balance(arg1, arg2, v15);
    }

    public fun calculate_avg_ltv(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: address) : u256 {
        let (v0, _) = lending_core::storage::get_user_assets(arg2, arg3);
        let v2 = v0;
        let mut v3 = 0;
        let mut v4 = 0;
        let mut v5 = 0;
        while (v3 < 0x1::vector::length<u8>(&v2)) {
            let v6 = 0x1::vector::borrow<u8>(&v2, v3);
            let v7 = user_collateral_value(arg0, arg1, arg2, *v6, arg3);
            v4 = v4 + v7;
            v5 = v5 + lending_core::ray_math::ray_mul(lending_core::storage::get_asset_ltv(arg2, *v6), v7);
            v3 = v3 + 1;
        };
        if (v4 > 0) {
            return lending_core::ray_math::ray_div(v5, v4)
        };
        0
    }

    public fun calculate_avg_threshold(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: address) : u256 {
        let (v0, _) = lending_core::storage::get_user_assets(arg2, arg3);
        let v2 = v0;
        let mut v3 = 0;
        let mut v4 = 0;
        let mut v5 = 0;
        while (v3 < 0x1::vector::length<u8>(&v2)) {
            let v6 = 0x1::vector::borrow<u8>(&v2, v3);
            let (_, _, v9) = lending_core::storage::get_liquidation_factors(arg2, *v6);
            let v10 = user_collateral_value(arg0, arg1, arg2, *v6, arg3);
            v4 = v4 + v10;
            v5 = v5 + lending_core::ray_math::ray_mul(v9, v10);
            v3 = v3 + 1;
        };
        if (v4 > 0) {
            return lending_core::ray_math::ray_div(v5, v4)
        };
        0
    }

    fun calculate_liquidation(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg3: address, arg4: u8, arg5: u8, arg6: u256) : (u256, u256, u256, u256, u256, bool) {
        let (v0, v1, _) = lending_core::storage::get_liquidation_factors(arg1, arg4);
        let v3 = user_loan_value(arg0, arg2, arg1, arg5, arg3);
        let v4 = lending_core::storage::get_oracle_id(arg1, arg4);
        let v5 = lending_core::storage::get_oracle_id(arg1, arg5);
        let v6 = lending_core::calculator::calculate_value(arg0, arg2, arg6, v5);
        let v7 = lending_core::ray_math::ray_mul(user_collateral_value(arg0, arg2, arg1, arg4, arg3), v0);
        let mut v8 = v7;
        let mut v9 = false;
        let mut v10 = if (v6 >= v7) {
            v6 - v7
        } else {
            v8 = v6;
            0
        };
        if (v8 >= v3) {
            v9 = true;
            v8 = v3;
            v10 = v6 - v3;
        };
        let v11 = lending_core::ray_math::ray_mul(v8, v1);
        let v12 = lending_core::ray_math::ray_mul(v11, lending_core::storage::get_treasury_factor(arg1, arg4));
        (lending_core::calculator::calculate_amount(arg0, arg2, v8, v4), lending_core::calculator::calculate_amount(arg0, arg2, v8, v5), lending_core::calculator::calculate_amount(arg0, arg2, v11 - v12, v4), lending_core::calculator::calculate_amount(arg0, arg2, v12, v4), lending_core::calculator::calculate_amount(arg0, arg2, v10, v5), v9)
    }

    public(package) fun cumulate_to_supply_index(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: u256) {
        let (v0, _) = lending_core::storage::get_total_supply(arg0, arg1);
        let (v2, v3) = lending_core::storage::get_index(arg0, arg1);
        let last_update_timestamp = lending_core::storage::get_last_update_timestamp(arg0, arg1);
        lending_core::storage::update_state(arg0, arg1, v3, lending_core::ray_math::ray_mul(lending_core::ray_math::ray_div(arg2, v0) + lending_core::ray_math::ray(), v2), last_update_timestamp, 0);
        emit_state_updated_event(arg0, arg1, @0x0);
    }

    public fun dynamic_liquidation_threshold(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg3: address) : u256 {
        let (v0, _) = lending_core::storage::get_user_assets(arg1, arg3);
        let v2 = v0;
        let mut v3 = 0;
        let mut v4 = 0;
        let mut v5 = 0;
        while (v3 < 0x1::vector::length<u8>(&v2)) {
            let v6 = 0x1::vector::borrow<u8>(&v2, v3);
            let (_, _, v9) = lending_core::storage::get_liquidation_factors(arg1, *v6);
            let v10 = user_collateral_value(arg0, arg2, arg1, *v6, arg3);
            v5 = v5 + lending_core::ray_math::ray_mul(v10, v9);
            v4 = v4 + v10;
            v3 = v3 + 1;
        };
        if (v4 > 0) {
            return lending_core::ray_math::ray_div(v5, v4)
        };
        0
    }

    fun emit_state_updated_event(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: address) {
        let (v0, v1) = lending_core::storage::get_index(arg0, arg1);
        let (v2, v3) = lending_core::storage::get_user_balance(arg0, arg1, arg2);
        let v4 = StateUpdated{
            user                : arg2,
            asset               : arg1,
            user_supply_balance : v2,
            user_borrow_balance : v3,
            new_supply_index    : v0,
            new_borrow_index    : v1,
        };
        0x2::event::emit<StateUpdated>(v4);
    }

    public(package) fun execute_borrow<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: address, arg5: u256) {
        update_state_of_all(arg0, arg2);
        lending_core::validation::validate_borrow<T0>(arg2, arg3, arg5);
        increase_borrow_balance(arg2, arg3, arg4, arg5);
        if (!is_loan(arg2, arg3, arg4)) {
            lending_core::storage::update_user_loans(arg2, arg3, arg4);
        };
        let v0 = calculate_avg_ltv(arg0, arg1, arg2, arg4);
        let v1 = calculate_avg_threshold(arg0, arg1, arg2, arg4);
        assert!(v0 > 0 && v1 > 0, lending_core::error::ltv_is_not_enough());
        assert!(user_health_factor(arg0, arg2, arg1, arg4) >= lending_core::ray_math::ray_div(v1, v0), lending_core::error::user_is_unhealthy());
        update_interest_rate(arg2, arg3);
        emit_state_updated_event(arg2, arg3, arg4);
    }

    public(package) fun execute_deposit<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: u8, arg3: address, arg4: u256) {
        update_state_of_all(arg0, arg1);
        lending_core::validation::validate_deposit<T0>(arg1, arg2, arg4);
        increase_supply_balance(arg1, arg2, arg3, arg4);
        if (!is_collateral(arg1, arg2, arg3)) {
            lending_core::storage::update_user_collaterals(arg1, arg2, arg3);
        };
        update_interest_rate(arg1, arg2);
        emit_state_updated_event(arg1, arg2, arg3);
    }

    public(package) fun execute_liquidate<T0, T1>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: address, arg4: u8, arg5: u8, arg6: u256) : (u256, u256, u256) {
        assert!(is_loan(arg2, arg5, arg3), lending_core::error::user_have_no_loan());
        assert!(is_collateral(arg2, arg4, arg3), lending_core::error::user_have_no_collateral());
        update_state_of_all(arg0, arg2);
        lending_core::validation::validate_liquidate<T0, T1>(arg2, arg5, arg4, arg6);
        assert!(!is_health(arg0, arg1, arg2, arg3), lending_core::error::user_is_healthy());
        let (v0, v1, v2, v3, v4, v5) = calculate_liquidation(arg0, arg2, arg1, arg3, arg4, arg5, arg6);
        decrease_borrow_balance(arg2, arg5, arg3, v1);
        decrease_supply_balance(arg2, arg4, arg3, v0 + v2 + v3);
        if (v5) {
            lending_core::storage::remove_user_loans(arg2, arg5, arg3);
        };
        update_interest_rate(arg2, arg4);
        update_interest_rate(arg2, arg5);
        emit_state_updated_event(arg2, arg4, arg3);
        emit_state_updated_event(arg2, arg5, arg3);
        (v0 + v2, v4, v3)
    }

    public(package) fun execute_repay<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: address, arg5: u256) : u256 {
        assert!(user_loan_balance(arg2, arg3, arg4) > 0, lending_core::error::user_have_no_loan());
        update_state_of_all(arg0, arg2);
        lending_core::validation::validate_repay<T0>(arg2, arg3, arg5);
        let v0 = user_loan_balance(arg2, arg3, arg4);
        let mut v1 = 0;
        let mut v2 = arg5;
        if (v0 < arg5) {
            v2 = v0;
            v1 = arg5 - v0;
        };
        decrease_borrow_balance(arg2, arg3, arg4, v2);
        if (v2 == v0) {
            lending_core::storage::remove_user_loans(arg2, arg3, arg4);
        };
        update_interest_rate(arg2, arg3);
        emit_state_updated_event(arg2, arg3, arg4);
        v1
    }

    public(package) fun execute_withdraw<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: address, arg5: u256) : u64 {
        assert!(user_collateral_balance(arg2, arg3, arg4) > 0, lending_core::error::user_have_no_collateral());
        update_state_of_all(arg0, arg2);
        lending_core::validation::validate_withdraw<T0>(arg2, arg3, arg5);
        let v0 = user_collateral_balance(arg2, arg3, arg4);
        let v1 = lending_core::safe_math::min(arg5, v0);
        decrease_supply_balance(arg2, arg3, arg4, v1);
        assert!(is_health(arg0, arg1, arg2, arg4), lending_core::error::user_is_unhealthy());
        if (v1 == v0) {
            if (is_collateral(arg2, arg3, arg4)) {
                lending_core::storage::remove_user_collaterals(arg2, arg3, arg4);
            };
        };
        if (v0 > v1) {
            if (v0 - v1 <= 1000) {
                lending_core::storage::increase_treasury_balance(arg2, arg3, v0 - v1);
                if (is_collateral(arg2, arg3, arg4)) {
                    lending_core::storage::remove_user_collaterals(arg2, arg3, arg4);
                };
            };
        };
        update_interest_rate(arg2, arg3);
        emit_state_updated_event(arg2, arg3, arg4);
        v1 as u64
    }

    public fun is_collateral(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: address) : bool {
        let (v0, _) = lending_core::storage::get_user_assets(arg0, arg2);
        let v2 = v0;
        0x1::vector::contains<u8>(&v2, &arg1)
    }

    public fun is_health(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: address) : bool {
        user_health_factor(arg0, arg2, arg1, arg3) >= lending_core::ray_math::ray()
    }

    public fun is_loan(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: address) : bool {
        let (_, v1) = lending_core::storage::get_user_assets(arg0, arg2);
        let v2 = v1;
        0x1::vector::contains<u8>(&v2, &arg1)
    }

    public(package) fun update_state_of_all(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage) {
        let mut v0 = 0;
        while (v0 < lending_core::storage::get_reserves_count(arg1)) {
            update_state(arg0, arg1, v0);
            v0 = v0 + 1;
        };
    }

    public fun user_collateral_balance(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: address) : u256 {
        let (v0, _) = lending_core::storage::get_user_balance(arg0, arg1, arg2);
        let (v2, _) = lending_core::storage::get_index(arg0, arg1);
        lending_core::ray_math::ray_mul(v0, v2)
    }

    public fun user_collateral_value(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: address) : u256 {
        lending_core::calculator::calculate_value(arg0, arg1, user_collateral_balance(arg2, arg3, arg4), lending_core::storage::get_oracle_id(arg2, arg3))
    }

    public fun user_health_collateral_value(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: address) : u256 {
        let (v0, _) = lending_core::storage::get_user_assets(arg2, arg3);
        let v2 = v0;
        let mut v3 = 0;
        let mut v4 = 0;
        while (v4 < 0x1::vector::length<u8>(&v2)) {
            v3 = v3 + user_collateral_value(arg0, arg1, arg2, *0x1::vector::borrow<u8>(&v2, v4), arg3);
            v4 = v4 + 1;
        };
        v3
    }

    public fun user_health_factor(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg3: address) : u256 {
        let v0 = user_health_loan_value(arg0, arg2, arg1, arg3);
        if (v0 > 0) {
            lending_core::ray_math::ray_mul(lending_core::ray_math::ray_div(user_health_collateral_value(arg0, arg2, arg1, arg3), v0), dynamic_liquidation_threshold(arg0, arg1, arg2, arg3))
        } else {
            0x2::address::max()
        }
    }

    public fun user_health_factor_batch(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: vector<address>) : vector<u256> {
        let mut v0 = 0;
        let mut v1 = 0x1::vector::empty<u256>();
        while (v0 < 0x1::vector::length<address>(&arg3)) {
            0x1::vector::push_back<u256>(&mut v1, user_health_factor(arg0, arg2, arg1, *0x1::vector::borrow<address>(&arg3, v0)));
            v0 = v0 + 1;
        };
        v1
    }

    public fun user_health_loan_value(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: address) : u256 {
        let (_, v1) = lending_core::storage::get_user_assets(arg2, arg3);
        let v2 = v1;
        let mut v3 = 0;
        let mut v4 = 0;
        while (v4 < 0x1::vector::length<u8>(&v2)) {
            v3 = v3 + user_loan_value(arg0, arg1, arg2, *0x1::vector::borrow<u8>(&v2, v4), arg3);
            v4 = v4 + 1;
        };
        v3
    }

    public fun user_loan_balance(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: address) : u256 {
        let (_, v1) = lending_core::storage::get_user_balance(arg0, arg1, arg2);
        let (_, v3) = lending_core::storage::get_index(arg0, arg1);
        lending_core::ray_math::ray_mul(v1, v3)
    }

    public fun user_loan_value(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: address) : u256 {
        lending_core::calculator::calculate_value(arg0, arg1, user_loan_balance(arg2, arg3, arg4), lending_core::storage::get_oracle_id(arg2, arg3))
    }

    // decompiled from Move bytecode v6
}

