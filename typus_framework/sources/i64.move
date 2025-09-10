// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module typus_framework::i64 {

    /// @dev Maximum I64 value as a u64.
    const MAX_I64_AS_U64: u64 = (1 << 63) - 1;

    /// @dev u64 with the first bit set. An `I64` is negative if this bit is set.
    const U64_WITH_FIRST_BIT_SET: u64 = 1 << 63;

    /// When both `U256` equal.
    const EQUAL: u8 = 0;

    /// When `a` is less than `b`.
    const LESS_THAN: u8 = 1;

    /// When `a` is greater than `b`.
    const GREATER_THAN: u8 = 2;

    /// @dev When trying to convert from a u64 > MAX_I64_AS_U64 to an I64.
    const E_CONVERSION_FROM_U64_OVERFLOW: u64 = 0;

    /// @dev When trying to convert from an negative I64 to a u64.
    const E_CONVERSION_TO_U64_UNDERFLOW: u64 = 1;

    /// @dev When trying to convert from a u64 > MAX_I64_AS_U64 to an I64.
    const E_ARITHMETIC_OVERFLOW: u64 = 2;

    /// @notice Struct representing a signed 64-bit integer.
    public struct I64 has copy, drop, store {
        bits: u64
    }

    /// @notice Casts a `u64` to an `I64`.
    public fun from(x: u64): I64 {
        assert!(x <= MAX_I64_AS_U64, E_CONVERSION_FROM_U64_OVERFLOW);
        I64 { bits: x }
    }

    /// @notice Creates a new `I64` with value 0.
    public fun zero(): I64 {
        I64 { bits: 0 }
    }

    /// @notice Casts an `I64` to a `u64`.
    public fun as_u64(x: &I64): u64 {
        assert!(x.bits < U64_WITH_FIRST_BIT_SET,E_CONVERSION_TO_U64_UNDERFLOW);
        x.bits
    }

    /// @notice Whether or not `x` is equal to 0.
    public fun is_zero(x: &I64): bool {
        x.bits == 0
    }

    /// @notice Whether or not `x` is negative.
    public fun is_neg(x: &I64): bool {
        x.bits > U64_WITH_FIRST_BIT_SET
    }

    /// @notice Flips the sign of `x`.
    public fun neg(x: &I64): I64 {
        if (x.bits == 0) return *x;
        I64 { bits: if (x.bits < U64_WITH_FIRST_BIT_SET) x.bits | (1 << 63) else x.bits - (1 << 63) }
    }

    /// @notice Flips the sign of `x`.
    public fun neg_from(x: u64): I64 {
        let mut ret = from(x);
        if (ret.bits > 0) *&mut ret.bits = ret.bits | (1 << 63);
        ret
    }

    /// @notice Absolute value of `x`.
    public fun abs(x: &I64): I64 {
        if (x.bits < U64_WITH_FIRST_BIT_SET) *x else I64 { bits: x.bits - (1 << 63) }
    }

    /// @notice Compare `a` and `b`.
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
        if (a.bits >> 63 == 0) {
            // A is positive
            if (b.bits >> 63 == 0) {
                // B is positive
                let bits = a.bits * b.bits;
                assert!(bits >> 63 == 0, E_ARITHMETIC_OVERFLOW);
                return I64 { bits } // Return positive
            } else {
                // B is negative
                return I64 { bits: (1 << 63) + (a.bits * (b.bits - (1 << 63))) } // Return negative
            }
        } else {
            // A is negative
            if (b.bits >> 63 == 0) {
                // B is positive
                return I64 { bits: (1 << 63) + (b.bits * (a.bits - (1 << 63))) } // Return negative
            } else {
                // B is negative
                let bits = (a.bits - (1 << 63)) * (b.bits - (1 << 63));
                assert!(bits >> 63 == 0, E_ARITHMETIC_OVERFLOW);
                return I64 { bits } // Return positive
            }
        }
    }

    /// @notice Divide `a / b`.
    public fun div(a: &I64, b: &I64): I64 {
        if (a.bits >> 63 == 0) {
            // A is positive
            if (b.bits >> 63 == 0) {
                // B is positive
                return I64 { bits: a.bits / b.bits } // Return positive
            } else {
                // B is negative
                return I64 { bits: (1 << 63) | (a.bits / (b.bits - (1 << 63))) } // Return negative
            }
        } else {
            // A is negative
            if (b.bits >> 63 == 0) {
                // B is positive
                return I64 { bits: (1 << 63) | ((a.bits - (1 << 63)) / b.bits) } // Return negative
            } else {
                // B is negative
                return I64 { bits: (a.bits - (1 << 63)) / (b.bits - (1 << 63)) } // Return positive
            }
        }
    }

    #[test]
    fun test_compare() {
        assert!(compare(&from(123), &from(123)) == EQUAL, 0);
        assert!(compare(&neg_from(123), &neg_from(123)) == EQUAL, 0);
        assert!(compare(&from(234), &from(123)) == GREATER_THAN, 0);
        assert!(compare(&from(123), &from(234)) == LESS_THAN, 0);
        assert!(compare(&neg_from(234), &neg_from(123)) == LESS_THAN, 0);
        assert!(compare(&neg_from(123), &neg_from(234)) == GREATER_THAN, 0);
        assert!(compare(&from(123), &neg_from(234)) == GREATER_THAN, 0);
        assert!(compare(&neg_from(123), &from(234)) == LESS_THAN, 0);
        assert!(compare(&from(234), &neg_from(123)) == GREATER_THAN, 0);
        assert!(compare(&neg_from(234), &from(123)) == LESS_THAN, 0);
    }

    #[test]
    fun test_add() {
        assert!(add(&from(123), &from(234)) == from(357), 0);
        assert!(add(&from(123), &neg_from(234)) == neg_from(111), 0);
        assert!(add(&from(234), &neg_from(123)) == from(111), 0);
        assert!(add(&neg_from(123), &from(234)) == from(111), 0);
        assert!(add(&neg_from(123), &neg_from(234)) == neg_from(357), 0);
        assert!(add(&neg_from(234), &neg_from(123)) == neg_from(357), 0);

        assert!(add(&from(123), &neg_from(123)) == zero(), 0);
        assert!(add(&neg_from(123), &from(123)) == zero(), 0);

        assert!(add(&from(111), &from(0)) == from(111), 0);
        assert!(add(&from(111), &neg_from(0)) == from(111), 0);
        assert!(add(&from(0), &neg_from(111)) == neg_from(111), 0);
        assert!(add(&neg_from(111), &from(0)) == neg_from(111), 0);
        assert!(add(&neg_from(111), &neg_from(0)) == neg_from(111), 0);
        assert!(add(&neg_from(0), &neg_from(111)) == neg_from(111), 0);

        assert!(add(&from(0), &neg_from(0)) == zero(), 0);
        assert!(add(&neg_from(0), &from(0)) == zero(), 0);
    }

    #[test]
    fun test_sub() {
        assert!(sub(&from(123), &from(234)) == neg_from(111), 0);
        assert!(sub(&from(234), &from(123)) == from(111), 0);
        assert!(sub(&from(123), &neg_from(234)) == from(357), 0);
        assert!(sub(&neg_from(123), &from(234)) == neg_from(357), 0);
        assert!(sub(&neg_from(123), &neg_from(234)) == from(111), 0);
        assert!(sub(&neg_from(234), &neg_from(123)) == neg_from(111), 0);

        assert!(sub(&from(123), &from(123)) == zero(), 0);
        assert!(sub(&neg_from(123), &neg_from(123)) == zero(), 0);

        assert!(sub(&from(111), &from(0)) == from(111), 0);
        assert!(sub(&from(111), &neg_from(0)) == from(111), 0);
        assert!(sub(&from(0), &neg_from(111)) == from(111), 0);
        assert!(sub(&neg_from(111), &from(0)) == neg_from(111), 0);
        assert!(sub(&neg_from(111), &neg_from(0)) == neg_from(111), 0);
        assert!(sub(&neg_from(0), &neg_from(111)) == from(111), 0);

        assert!(sub(&from(0), &neg_from(0)) == zero(), 0);
        assert!(sub(&neg_from(0), &from(0)) == zero(), 0);
    }

    #[test]
    fun test_mul() {
        assert!(mul(&from(123), &from(234)) == from(28782), 0);
        assert!(mul(&from(123), &neg_from(234)) == neg_from(28782), 0);
        assert!(mul(&neg_from(123), &from(234)) == neg_from(28782), 0);
        assert!(mul(&neg_from(123), &neg_from(234)) == from(28782), 0);

        assert!(mul(&from(0), &from(123)) == zero(), 0);
        assert!(mul(&from(123), &from(0)) == zero(), 0);

        let neg_zero = &mul(&from(0), &neg_from(123));
        assert!(add(&from(111), neg_zero) == from(111), 0);
        assert!(add(&from(111), &neg_from(0)) == from(111), 0);
        assert!(add(neg_zero, &neg_from(111)) == neg_from(111), 0);
        assert!(add(&neg_from(111), neg_zero) == neg_from(111), 0);
        assert!(add(&neg_from(111), &neg_from(0)) == neg_from(111), 0);
        assert!(add(&neg_from(0), &neg_from(111)) == neg_from(111), 0);
        assert!(add(neg_zero, &neg_from(0)) == zero(), 0);
        assert!(add(&neg_from(0), neg_zero) == zero(), 0);

        assert!(abs(neg_zero) == zero(), 0);
        assert!(mul(&neg_from(123), neg_zero) == zero(), 0);

        assert!(sub(&from(111), neg_zero) == from(111), 0);
        assert!(sub(&from(111), neg_zero) == from(111), 0);
        assert!(sub(neg_zero, &neg_from(111)) == from(111), 0);
        assert!(sub(&neg_from(111), neg_zero) == neg_from(111), 0);
        assert!(sub(&neg_from(111), neg_zero) == neg_from(111), 0);
        assert!(sub(neg_zero, &neg_from(111)) == from(111), 0);

        assert!(sub(neg_zero, neg_zero) == zero(), 0);
        assert!(sub(neg_zero, &from(0)) == neg_zero, 0);
    }

    #[test]
    fun test_div() {
        assert!(div(&from(28781), &from(123)) == from(233), 0);
        assert!(div(&from(28781), &neg_from(123)) == neg_from(233), 0);
        assert!(div(&neg_from(28781), &from(123)) == neg_from(233), 0);
        assert!(div(&neg_from(28781), &neg_from(123)) == from(233), 0);

        assert!(div(&from(0), &from(123)) == zero(), 0);
    }

    #[test]
    #[expected_failure(abort_code = E_ARITHMETIC_OVERFLOW)]
    fun test_add_failure() {
        add(&from(1 << 62), &from(1 << 62));
    }

    #[test]
    #[expected_failure(abort_code = E_ARITHMETIC_OVERFLOW)]
    fun test_sub_failure() {
        sub(&from(1 << 62), &neg_from(1 << 62));
    }

    #[test]
    #[expected_failure(abort_code = E_ARITHMETIC_OVERFLOW)]
    fun test_mul_failure_1() {
        mul(&from(1 << 30), &from(1 << 33));
    }

    #[test]
    #[expected_failure]
    fun test_mul_failure_2() {
        mul(&from(1 << 30), &neg_from(1 << 33));
    }

    #[test]
    #[expected_failure]
    fun test_mul_failure_3() {
        mul(&neg_from(1 << 30), &from(1 << 33));
    }

    #[test]
    #[expected_failure(abort_code = E_ARITHMETIC_OVERFLOW)]
    fun test_mul_failure_4() {
        mul(&neg_from(1 << 30), &neg_from(1 << 33));
    }

    #[test]
    #[expected_failure(abort_code = E_CONVERSION_FROM_U64_OVERFLOW)]
    fun test_neg_overflow() {
       neg_from(1 << 63);
    }

    #[test]
    fun test_neg_neg_identity() {
        let test_vals = vector[
            0u64,
            1u64,
            123u64,
            987654321u64,
            1 << 30,
            (1 << 63) - 1, // i64::MAX
        ];

        let len = vector::length(&test_vals);
        let mut i = 0;

        while (i < len) {
            let x = vector::borrow(&test_vals, i);
            let i64_x = from(*x);
            let neg_neg_x = neg(&neg(&i64_x));
            assert!(compare(&i64_x, &neg_neg_x) == EQUAL, 100 + i); // 100+i as abort code
            i = i + 1;
        };
    }

}
