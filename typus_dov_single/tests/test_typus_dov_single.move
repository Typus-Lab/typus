#[test_only]
module typus_dov::test_typus_dov_single {
    use typus_dov::typus_dov_single;

    #[test]
    #[expected_failure]
    fun test_validate_dutch_auction_settings_abort_1() {
        typus_dov_single::validate_dutch_auction_settings(1, 2, 3);
    }

    #[test]
    #[expected_failure]
    fun test_validate_dutch_auction_settings_abort_2() {
        typus_dov_single::validate_dutch_auction_settings(1, 0, 3);
    }

    #[test]
    #[expected_failure]
    fun test_validate_dutch_auction_settings_abort_3() {
        typus_dov_single::validate_dutch_auction_settings(2, 1, 3);
    }

    #[test]
    #[expected_failure]
    fun test_validate_amount_abort_1() {
        typus_dov_single::validate_amount(0);
    }

    #[test]
    #[expected_failure]
    fun test_lending_cap_key_abort() {
        typus_dov_single::lending_cap_key(5);
        typus_dov_single::lending_cap_key(4);
        typus_dov_single::lending_cap_key(3);
        typus_dov_single::lending_cap_key(1);
        typus_dov_single::lending_cap_key(0);
    }
}