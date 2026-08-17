#[test_only]
extend module typus_framework::i64 {
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
    fun test_as_u64() {
        assert!(as_u64(&from(123)) == 123, 0);
    }

    #[test]
    #[expected_failure(abort_code = E_CONVERSION_TO_U64_UNDERFLOW)]
    fun test_as_u64_failure() {
        assert!(as_u64(&neg_from(123)) == 123, 0);
    }

    #[test]
    fun test_is_zero() {
        assert!(is_zero(&from(0)), 0);
        assert!(!is_zero(&from(1)), 0);
    }

    #[test]
    fun test_is_neg() {
        assert!(!is_neg(&from(123)), 0);
        assert!(is_neg(&neg_from(123)), 0);
    }

    #[test]
    fun test_abs() {
        assert!(as_u64(&abs(&from(123))) == 123, 0);
        assert!(as_u64(&abs(&neg_from(123))) == 123, 0);
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