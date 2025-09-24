module lending_core::validation {
    public fun validate_borrow<T0>(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: u256) {
        assert!(0x1::type_name::into_string(0x1::type_name::with_defining_ids<T0>()) == lending_core::storage::get_coin_type(arg0, arg1), lending_core::error::invalid_coin_type());
        assert!(arg2 != 0, lending_core::error::invalid_amount());
        let (v0, v1) = lending_core::storage::get_total_supply(arg0, arg1);
        let (v2, v3) = lending_core::storage::get_index(arg0, arg1);
        let v4 = lending_core::ray_math::ray_mul(v0, v2);
        let v5 = lending_core::ray_math::ray_mul(v1, v3);
        assert!(v5 + arg2 < v4, lending_core::error::insufficient_balance());
        assert!(lending_core::storage::get_borrow_cap_ceiling_ratio(arg0, arg1) >= lending_core::ray_math::ray_div(v5 + arg2, v4), lending_core::error::exceeded_maximum_borrow_cap());
    }

    public fun validate_deposit<T0>(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: u256) {
        assert!(0x1::type_name::into_string(0x1::type_name::with_defining_ids<T0>()) == lending_core::storage::get_coin_type(arg0, arg1), lending_core::error::invalid_coin_type());
        assert!(arg2 != 0, lending_core::error::invalid_amount());
        let (v0, _) = lending_core::storage::get_total_supply(arg0, arg1);
        let (v2, _) = lending_core::storage::get_index(arg0, arg1);
        assert!(lending_core::storage::get_supply_cap_ceiling(arg0, arg1) >= (lending_core::ray_math::ray_mul(v0, v2) + arg2) * lending_core::ray_math::ray(), lending_core::error::exceeded_maximum_deposit_cap());
    }

    public fun validate_liquidate<T0, T1>(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: u8, arg3: u256) {
        assert!(0x1::type_name::into_string(0x1::type_name::with_defining_ids<T0>()) == lending_core::storage::get_coin_type(arg0, arg1), lending_core::error::invalid_coin_type());
        assert!(0x1::type_name::into_string(0x1::type_name::with_defining_ids<T1>()) == lending_core::storage::get_coin_type(arg0, arg2), lending_core::error::invalid_coin_type());
        assert!(arg3 != 0, lending_core::error::invalid_amount());
    }

    public fun validate_repay<T0>(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: u256) {
        assert!(0x1::type_name::into_string(0x1::type_name::with_defining_ids<T0>()) == lending_core::storage::get_coin_type(arg0, arg1), lending_core::error::invalid_coin_type());
        assert!(arg2 != 0, lending_core::error::invalid_amount());
    }

    public fun validate_withdraw<T0>(arg0: &mut lending_core::storage::Storage, arg1: u8, arg2: u256) {
        assert!(0x1::type_name::into_string(0x1::type_name::with_defining_ids<T0>()) == lending_core::storage::get_coin_type(arg0, arg1), lending_core::error::invalid_coin_type());
        assert!(arg2 != 0, lending_core::error::invalid_amount());
        let (v0, v1) = lending_core::storage::get_total_supply(arg0, arg1);
        let (v2, v3) = lending_core::storage::get_index(arg0, arg1);
        assert!(lending_core::ray_math::ray_mul(v0, v2) >= lending_core::ray_math::ray_mul(v1, v3) + arg2, lending_core::error::insufficient_balance());
    }

    // decompiled from Move bytecode v6
}

