module oracle::adaptor_pyth {
    public fun get_price_info_object_id(arg0: &pyth::state::State, arg1: address) : address {
        let v0 = pyth::state::get_price_info_object_id(arg0, 0x2::address::to_bytes(arg1));
        0x2::object::id_to_address(&v0)
    }

    public fun get_identifier_to_vector(arg0: &pyth::price_info::PriceInfoObject) : vector<u8> {
        let v0 = pyth::price_info::get_price_info_from_price_info_object(arg0);
        let v1 = pyth::price_info::get_price_identifier(&v0);
        pyth::price_identifier::get_bytes(&v1)
    }

    public fun get_price_native(arg0: &0x2::clock::Clock, arg1: &pyth::state::State, arg2: &pyth::price_info::PriceInfoObject) : (u64, u64, u64) {
        let v0 = pyth::pyth::get_price(arg1, arg2, arg0);
        let v1 = pyth::price::get_price(&v0);
        let v2 = pyth::price::get_expo(&v0);
        (pyth::i64::get_magnitude_if_positive(&v1), pyth::i64::get_magnitude_if_negative(&v2), pyth::price::get_timestamp(&v0) * 1000)
    }

    public fun get_price_to_target_decimal(arg0: &0x2::clock::Clock, arg1: &pyth::state::State, arg2: &pyth::price_info::PriceInfoObject, arg3: u8) : (u256, u64) {
        let (v0, v1, v2) = get_price_native(arg0, arg1, arg2);
        (oracle::oracle_utils::to_target_decimal_value_safe(v0 as u256, v1, arg3 as u64), v2)
    }

    public fun get_price_unsafe_native(arg0: &pyth::price_info::PriceInfoObject) : (u64, u64, u64) {
        let v0 = pyth::pyth::get_price_unsafe(arg0);
        let v1 = pyth::price::get_price(&v0);
        let v2 = pyth::price::get_expo(&v0);
        (pyth::i64::get_magnitude_if_positive(&v1), pyth::i64::get_magnitude_if_negative(&v2), pyth::price::get_timestamp(&v0) * 1000)
    }

    public fun get_price_unsafe_to_target_decimal(arg0: &pyth::price_info::PriceInfoObject, arg1: u8) : (u256, u64) {
        let (v0, v1, v2) = get_price_unsafe_native(arg0);
        (oracle::oracle_utils::to_target_decimal_value_safe(v0 as u256, v1, arg1 as u64), v2)
    }

    // decompiled from Move bytecode v6
}

