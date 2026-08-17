// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module typus_framework::i64 {

    /// @dev Maximum I64 value as a u64.
    const MAX_I64_AS_U64: u64 = (1 << 63) - 1;

    /// @dev u64 with the first bit set. An `I64` is negative if this bit is set.
    const U64_WITH_FIRST_BIT_SET: u64 = 1 << 63;

    /// @dev Represents the result of a comparison where two `I64` values are equal.
    const EQUAL: u8 = 0;

    /// @dev Represents the result of a comparison where `a` is less than `b`.
    const LESS_THAN: u8 = 1;

    /// @dev Represents the result of a comparison where `a` is greater than `b`.
    const GREATER_THAN: u8 = 2;

    /// @dev Error code for when trying to convert from a u64 > MAX_I64_AS_U64 to an I64.
    const E_CONVERSION_FROM_U64_OVERFLOW: u64 = 0;

    /// @dev Error code for when trying to convert from a negative I64 to a u64.
    const E_CONVERSION_TO_U64_UNDERFLOW: u64 = 1;

    /// @dev Error code for when an arithmetic operation results in an overflow.
    const E_ARITHMETIC_OVERFLOW: u64 = 2;

    /// @dev Error code for when an arithmetic operation results in an overflow.
    const E_ARITHMETIC_ERROR: u64 = 3;

    /// @notice Struct representing a signed 64-bit integer.
    /// @dev The most significant bit is used to represent the sign (1 for negative, 0 for positive).
    public struct I64 has copy, drop, store {
        bits: u64
    }

    /// @notice Casts a `u64` to an `I64`.
    /// @dev Aborts if the u64 value is too large to be represented as a positive I64.
    public fun from(x: u64): I64 {
        assert!(x <= MAX_I64_AS_U64, E_CONVERSION_FROM_U64_OVERFLOW);
        I64 { bits: x }
    }

    /// @notice Creates a new `I64` with value 0.
    public fun zero(): I64 {
        I64 { bits: 0 }
    }

    /// @notice Casts an `I64` to a `u64`.
    /// @dev Aborts if the I64 value is negative.
    public fun as_u64(x: &I64): u64 {
        assert!(x.bits < U64_WITH_FIRST_BIT_SET,E_CONVERSION_TO_U64_UNDERFLOW);
        x.bits
    }

    /// @notice Checks whether or not `x` is equal to 0.
    public fun is_zero(x: &I64): bool {
        x.bits == 0
    }

    /// @notice Checks whether or not `x` is negative.
    public fun is_neg(x: &I64): bool {
        x.bits > U64_WITH_FIRST_BIT_SET
    }

    /// @notice Flips the sign of `x`.
    public fun neg(x: &I64): I64 {
        if (x.bits == 0) return *x;
        I64 { bits: if (x.bits < U64_WITH_FIRST_BIT_SET) x.bits | (1 << 63) else x.bits - (1 << 63) }
    }

    /// @notice Creates a negative `I64` from a `u64` value.
    public fun neg_from(x: u64): I64 {
        let mut ret = from(x);
        if (ret.bits > 0) *&mut ret.bits = ret.bits | (1 << 63);
        ret
    }

    /// @notice Returns the absolute value of `x`.
    public fun abs(x: &I64): I64 {
        if (x.bits < U64_WITH_FIRST_BIT_SET) *x else I64 { bits: x.bits - (1 << 63) }
    }

    /// @notice Compares `a` and `b`.
    /// @return `EQUAL` if a == b, `LESS_THAN` if a < b, `GREATER_THAN` if a > b.
    public fun compare(a: &I64, b: &I64): u8 {
        if (a.bits == b.bits) return EQUAL;
        if (a.bits < U64_WITH_FIRST_BIT_SET) {
            // A is positive
            if (b.bits < U64_WITH_FIRST_BIT_SET) {
                // B is positive
                return if (a.bits > b.bits) GREATER_THAN else LESS_THAN
            } else {
                // B is negative
                return GREATER_THAN
            }
        } else {
            // A is negative
            if (b.bits < U64_WITH_FIRST_BIT_SET) {
                // B is positive
                return LESS_THAN
            } else {
                // B is negative
                return if (a.bits > b.bits) LESS_THAN else GREATER_THAN
            }
        }
    }

    /// @notice Add `a + b`.
    public fun add(a: &I64, b: &I64): I64 {
        if (a.bits >> 63 == 0) {
            // A is positive
            if (b.bits >> 63 == 0) {
                // B is positive
                let bits = a.bits + b.bits;
                assert!(bits >> 63 == 0, E_ARITHMETIC_OVERFLOW);
                return I64 { bits }
            } else {
                // B is negative
                if (b.bits - (1 << 63) <= a.bits) return I64 { bits: a.bits - (b.bits - (1 << 63)) }; // Return positive
                return I64 { bits: b.bits - a.bits } // Return negative
            }
        } else {
            // A is negative
            if (b.bits >> 63 == 0) {
                // B is positive
                if (a.bits - (1 << 63) <= b.bits) return I64 { bits: b.bits - (a.bits - (1 << 63)) }; // Return positive
                return I64 { bits: a.bits - b.bits } // Return negative
            } else {
                // B is negative
                return I64 { bits: a.bits + (b.bits - (1 << 63)) }
            }
        }
    }

    /// @notice Subtract `a - b`.
    public fun sub(a: &I64, b: &I64): I64 {
        if (a.bits >> 63 == 0) {
            // A is positive
            if (b.bits >> 63 == 0) {
                // B is positive
                if (a.bits >= b.bits) return I64 { bits: a.bits - b.bits }; // Return positive
                return I64 { bits: (1 << 63) | (b.bits - a.bits) } // Return negative
            } else {
                // B is negative
                let bits = a.bits + (b.bits - (1 << 63));
                assert!(bits >> 63 == 0, E_ARITHMETIC_OVERFLOW);
                return I64 { bits } // Return positive
            }
        } else {
            // A is negative
            if (b.bits >> 63 == 0) {
                // B is positive
                return I64 { bits: a.bits + b.bits } // Return negative
            } else {
                // B is negative
                if (b.bits >= a.bits) return I64 { bits: b.bits - a.bits }; // Return positive
                return I64 { bits: a.bits - (b.bits - (1 << 63)) } // Return negative
            }
        }
    }

    /// @notice Multiply `a * b`.
    public fun mul(a: &I64, b: &I64): I64 {
        if (a.bits == 0 || b.bits == 0) return zero();
        if (a.bits >> 63 == 0) {
            // A is positive
            if (b.bits >> 63 == 0) {
                // B is positive
                let bits = a.bits * b.bits;
                assert!(bits >> 63 == 0, E_ARITHMETIC_OVERFLOW);
                I64 { bits } // Return positive
            } else {
                // B is negative
                I64 { bits: (1 << 63) + (a.bits * (b.bits - (1 << 63))) } // Return negative
            }
        } else {
            // A is negative
            if (b.bits >> 63 == 0) {
                // B is positive
                I64 { bits: (1 << 63) + (b.bits * (a.bits - (1 << 63))) } // Return negative
            } else {
                // B is negative
                let bits = (a.bits - (1 << 63)) * (b.bits - (1 << 63));
                assert!(bits >> 63 == 0, E_ARITHMETIC_OVERFLOW);
                I64 { bits } // Return positive
            }
        }
    }

    /// @notice Divide `a / b`.
    public fun div(a: &I64, b: &I64): I64 {
        if (a.bits == 0) return zero();
        if (b.bits == 0) abort E_ARITHMETIC_ERROR;
        if (a.bits >> 63 == 0) {
            // A is positive
            if (b.bits >> 63 == 0) {
                // B is positive
                I64 { bits: a.bits / b.bits } // Return positive
            } else {
                // B is negative
                I64 { bits: (1 << 63) | (a.bits / (b.bits - (1 << 63))) } // Return negative
            }
        } else {
            // A is negative
            if (b.bits >> 63 == 0) {
                // B is positive
                I64 { bits: (1 << 63) | ((a.bits - (1 << 63)) / b.bits) } // Return negative
            } else {
                // B is negative
                I64 { bits: (a.bits - (1 << 63)) / (b.bits - (1 << 63)) } // Return positive
            }
        }
    }
}
