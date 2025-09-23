module pyth::i64 {
    //use pyth::error;

    const MAX_POSITIVE_MAGNITUDE: u64 = (1 << 63) - 1;
    const MAX_NEGATIVE_MAGNITUDE: u64 = (1 << 63);

    /// As Move does not support negative numbers natively, we use our own internal
    /// representation.
    ///
    /// To consume these values, first call `get_is_negative()` to determine if the I64
    /// represents a negative or positive value. Then call `get_magnitude_if_positive()` or
    /// `get_magnitude_if_negative()` to get the magnitude of the number in unsigned u64 format.
    /// This API forces consumers to handle positive and negative numbers safely.
    struct I64 has copy, drop, store {
        negative: bool,
        magnitude: u64,
    }

    public fun new(magnitude: u64, negative: bool): I64 {
        let max_magnitude = MAX_POSITIVE_MAGNITUDE;
        if (negative) {
            max_magnitude = MAX_NEGATIVE_MAGNITUDE;
        };
        assert!(magnitude <= max_magnitude, 0); //error::magnitude_too_large()


        // Ensure we have a single zero representation: (0, false).
        // (0, true) is invalid.
        if (magnitude == 0) {
            negative = false;
        };

        I64 {
            magnitude,
            negative,
        }
    }

    public fun get_is_negative(i: &I64): bool {
        i.negative
    }

    public fun get_magnitude_if_positive(in: &I64): u64 {
        assert!(!in.negative, 0); // error::negative_value()
        in.magnitude
    }

    public fun get_magnitude_if_negative(in: &I64): u64 {
        assert!(in.negative, 0); //error::positive_value()
        in.magnitude
    }

    public fun from_u64(from: u64): I64 {
        // Use the MSB to determine whether the number is negative or not.
        let negative = (from >> 63) == 1;
        let magnitude = parse_magnitude(from, negative);

        new(magnitude, negative)
    }

    fun parse_magnitude(from: u64, negative: bool): u64 {
        // If positive, then return the input verbatamin
        if (!negative) {
            return from
        };

        // Otherwise convert from two's complement by inverting and adding 1
        let inverted = from ^ 0xFFFFFFFFFFFFFFFF;
        inverted + 1
    }
}
