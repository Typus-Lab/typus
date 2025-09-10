module typus::error {
    public fun account_not_found(error_code: u64): u64 { abort error_code }
    public fun account_already_exists(error_code: u64): u64 { abort error_code }
}