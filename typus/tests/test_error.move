#[test_only]
module typus::test_error {
    use typus::error;

    #[test, expected_failure]
    fun test_account_not_found() {
        error::account_not_found(0);
    }
    #[test, expected_failure]
    fun test_account_already_exists() {
        error::account_already_exists(0);
    }
}