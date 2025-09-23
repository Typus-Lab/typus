 module pyth::deserialize {
    use wormhole::bytes::{Self};
    use wormhole::cursor::{Cursor};
    use pyth::i64::{Self, I64};
    #[test_only]
    use wormhole::cursor::{take_rest};

    #[test_only]
    use wormhole::cursor::{Self};

    public fun deserialize_vector(cur: &mut Cursor<u8>, n: u64): vector<u8> {
        bytes::take_bytes(cur, n)
    }

    public fun deserialize_u8(cur: &mut Cursor<u8>): u8 {
        bytes::take_u8(cur)
    }

    public fun deserialize_u16(cur: &mut Cursor<u8>): u16 {
        bytes::take_u16_be(cur)
    }

    public fun deserialize_u32(cur: &mut Cursor<u8>): u32 {
        bytes::take_u32_be(cur)
    }

    public fun deserialize_i32(cur: &mut Cursor<u8>): I64 {
        let deserialized = deserialize_u32(cur);
        // If negative, pad the value
        let negative = (deserialized >> 31) == 1;
        if (negative) {
            let padded = (0xFFFFFFFF << 32) + (deserialized as u64);
            i64::from_u64((padded as u64))
        } else {
            i64::from_u64((deserialized as u64))
        }
    }

    public fun deserialize_u64(cur: &mut Cursor<u8>): u64 {
        bytes::take_u64_be(cur)
    }

    public fun deserialize_i64(cur: &mut Cursor<u8>): I64 {
        i64::from_u64(deserialize_u64(cur))
    }
}
