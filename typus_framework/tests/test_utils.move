#[test_only]
extend module typus_framework::utils {
    use sui::test_scenario;

    #[test]
    fun test_multiplier() {
        assert!(multiplier(8) == 100000000, 0);
    }

    #[test]
    fun test_extract_balance() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let balance = extract_balance<sui::sui::SUI>(
            vector[coin::mint_for_testing(40, scenario.ctx()), coin::mint_for_testing(30, scenario.ctx())],
            60,
            scenario.ctx(),
        );
        balance.destroy_for_testing();
        scenario.end();
    }

    #[test, expected_failure(abort_code = EInsufficientBalance)]
    fun test_extract_balance_insufficient_balance() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let balance = extract_balance<sui::sui::SUI>(
            vector[coin::mint_for_testing(50, scenario.ctx())],
            60,
            scenario.ctx(),
        );
        balance.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_merge_coins() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let coin = merge_coins<sui::sui::SUI>(
            vector[coin::mint_for_testing(40, scenario.ctx()), coin::mint_for_testing(30, scenario.ctx())],
        );
        coin.burn_for_testing();
        scenario.end();
    }

    #[test]
    fun test_transfer_coins() {
        let mut scenario = test_scenario::begin(@0xABCD);
        transfer_coins<sui::sui::SUI>(
            vector[coin::mint_for_testing(40, scenario.ctx()), coin::mint_for_testing(30, scenario.ctx())],
            @0xABCD,
        );
        scenario.end();
    }

    #[test]
    fun test_transfer_balance() {
        let mut scenario = test_scenario::begin(@0xABCD);
        transfer_balance<sui::sui::SUI>(
            balance::create_for_testing(100),
            @0xABCD,
            scenario.ctx(),
        );
        transfer_balance<sui::sui::SUI>(
            balance::create_for_testing(0),
            @0xABCD,
            scenario.ctx(),
        );
        scenario.end();
    }

    #[test]
    fun test_get_date_from_ts() {
        let (y, m, d) = get_date_from_ts(726386766);
        assert!(y == 1993, 0);
        assert!(m == 1, 0);
        assert!(d == 7, 0);
        let (y, m, d) = get_date_from_ts(1458457627);
        assert!(y == 2016, 0);
        assert!(m == 3, 0);
        assert!(d == 20, 0);
        let (y, m, d) = get_date_from_ts(1671280200);
        assert!(y == 2022, 0);
        assert!(m == 12, 0);
        assert!(d == 17, 0);
    }

    #[test]
    fun test_match_types() {
        assert!(match_types<sui::sui::SUI, sui::sui::SUI>(), 0);
    }

    #[test]
    fun test_u64_to_bytes() {
        let bytes = u64_to_bytes(165011022030, 8);
        assert!(bytes == b"1650.1102203", 0);
        let bytes = u64_to_bytes(75305129, 9);
        assert!(bytes == b"0.075305129", 0);
        let bytes = u64_to_bytes(74500, 8);
        assert!(bytes == b"0.000745", 0);
    }

    #[test, allow(implicit_const_copy)]
    fun test_get_month_short_string() {
        assert!(get_month_short_string(10) == C_MONTH_STRING[9], 0);
    }

    #[test, allow(implicit_const_copy)]
    fun test_get_pad_2_number_string() {
        assert!(get_pad_2_number_string(50) == C_NUMBER_STRING[50], 0);
    }

    #[test]
    fun test_u64_padding_operations() {
        let mut data = vector[];
        set_u64_padding_value(&mut data, 0, 10);
        set_u64_padding_value(&mut data, 1, 10 + (1 << 63));
        assert!(get_u64_padding_value(&data, 0) == 10, 0);
        assert!(get_u64_padding_value(&data, 2) == 0, 0);
        let (exists, value) = get_flagged_u64_padding_value(&data, 1);
        assert!(exists && value == 10, 0);
        let (exists, value) = get_flagged_u64_padding_value(&data, 2);
        assert!(!exists && value == 0, 0);
    }
}