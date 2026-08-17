/// This module defines custom error codes for the Typus ecosystem.
/// These functions are used to abort transactions with specific error codes,
/// providing more context about the reason for the failure.
module typus::error {
    /// Aborts the transaction with an error code indicating that an account was not found.
    public fun account_not_found(error_code: u64): u64 { abort error_code }
    /// Aborts the transaction with an error code indicating that an account already exists.
    public fun account_already_exists(error_code: u64): u64 { abort error_code }
}