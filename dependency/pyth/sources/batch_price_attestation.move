module pyth::batch_price_attestation {
    use std::vector::{Self};
    use sui::clock::{Self, Clock};

    use pyth::price_feed::{Self};
    use pyth::price_info::{Self, PriceInfo};
    use pyth::price_identifier::{Self};
    use pyth::price_status;
    use pyth::deserialize::{Self};

    use wormhole::cursor::{Self, Cursor};
    use wormhole::bytes::{Self};

    #[test_only]
    use pyth::price;
    #[test_only]
    use pyth::i64;

    const MAGIC: u64 = 0x50325748; // "P2WH" (Pyth2Wormhole) raw ASCII bytes
    const E_INVALID_ATTESTATION_MAGIC_VALUE: u64 = 0;
    const E_INVALID_BATCH_ATTESTATION_HEADER_SIZE: u64 = 1;

    struct BatchPriceAttestation {
        header: Header,
        attestation_size: u64,
        attestation_count: u64,
        price_infos: vector<PriceInfo>,
    }

    struct Header {
        magic: u64,
        version_major: u64,
        version_minor: u64,
        header_size: u64,
        payload_id: u8,
    }

    fun deserialize_header(cur: &mut Cursor<u8>): Header {
        let magic = (deserialize::deserialize_u32(cur) as u64);
        assert!(magic == MAGIC, E_INVALID_ATTESTATION_MAGIC_VALUE);
        let version_major = deserialize::deserialize_u16(cur);
        let version_minor = deserialize::deserialize_u16(cur);
        let header_size = deserialize::deserialize_u16(cur);
        let payload_id = deserialize::deserialize_u8(cur);

        assert!(header_size >= 1, E_INVALID_BATCH_ATTESTATION_HEADER_SIZE);
        let unknown_header_bytes = header_size - 1;
        let _unknown = bytes::take_bytes(cur, (unknown_header_bytes as u64));

        Header {
            magic,
            header_size: (header_size as u64),
            version_minor: (version_minor as u64),
            version_major: (version_major as u64),
            payload_id,
        }
    }

    public fun destroy(batch: BatchPriceAttestation): vector<PriceInfo> {
        let BatchPriceAttestation {
            header: Header {
                magic: _,
                version_major: _,
                version_minor: _,
                header_size: _,
                payload_id: _,
            },
            attestation_size: _,
            attestation_count: _,
            price_infos,
        } = batch;
        price_infos
    }

    public fun get_attestation_count(batch: &BatchPriceAttestation): u64 {
        batch.attestation_count
    }

    public fun get_price_info(batch: &BatchPriceAttestation, index: u64): &PriceInfo {
        vector::borrow(&batch.price_infos, index)
    }

    public fun deserialize(bytes: vector<u8>, clock: &Clock): BatchPriceAttestation {
        let cur = cursor::new(bytes);
        let header = deserialize_header(&mut cur);

        let attestation_count = deserialize::deserialize_u16(&mut cur);
        let attestation_size = deserialize::deserialize_u16(&mut cur);
        let price_infos = vector::empty();

        let i = 0;
        while (i < attestation_count) {
            let price_info = deserialize_price_info(&mut cur, clock);
            vector::push_back(&mut price_infos, price_info);

            // Consume any excess bytes
            let parsed_bytes = 32+32+8+8+4+8+8+1+4+4+8+8+8+8+8;
            let _excess = bytes::take_bytes(&mut cur, (attestation_size - parsed_bytes as u64));

            i = i + 1;
        };
        cursor::destroy_empty(cur);

        BatchPriceAttestation {
            header,
            attestation_count: (attestation_count as u64),
            attestation_size: (attestation_size as u64),
            price_infos,
        }
    }

    fun deserialize_price_info(cur: &mut Cursor<u8>, clock: &Clock): PriceInfo {

        // Skip obsolete field
        let _product_identifier = deserialize::deserialize_vector(cur, 32);
        let price_identifier = price_identifier::from_byte_vec(deserialize::deserialize_vector(cur, 32));
        let price = deserialize::deserialize_i64(cur);
        let conf = deserialize::deserialize_u64(cur);
        let expo = deserialize::deserialize_i32(cur);
        let ema_price = deserialize::deserialize_i64(cur);
        let ema_conf = deserialize::deserialize_u64(cur);
        let status = price_status::from_u64((deserialize::deserialize_u8(cur) as u64));

        // Skip obsolete fields
        let _num_publishers = deserialize::deserialize_u32(cur);
        let _max_num_publishers = deserialize::deserialize_u32(cur);

        let attestation_time = deserialize::deserialize_u64(cur);
        let publish_time = deserialize::deserialize_u64(cur); //
        let prev_publish_time = deserialize::deserialize_u64(cur);
        let prev_price = deserialize::deserialize_i64(cur);
        let prev_conf = deserialize::deserialize_u64(cur);

        // Handle the case where the status is not trading. This logic will soon be moved into
        // the attester.

        // If status is trading, use the current price.
        // If not, use the last known trading price.
        let current_price = pyth::price::new(price, conf, expo, publish_time);
        if (status != price_status::new_trading()) {
            current_price = pyth::price::new(prev_price, prev_conf, expo, prev_publish_time);
        };

        // If status is trading, use the timestamp of the aggregate as the timestamp for the
        // EMA price. If not, the EMA will have last been updated when the aggregate last had
        // trading status, so use prev_publish_time (the time when the aggregate last had trading status).
        let ema_timestamp = publish_time;
        if (status != price_status::new_trading()) {
            ema_timestamp = prev_publish_time;
        };

        price_info::new_price_info(
            attestation_time,
            clock::timestamp_ms(clock) / 1000, // Divide by 1000 to get timestamp in seconds
            price_feed::new(
                price_identifier,
                current_price,
                pyth::price::new(ema_price, ema_conf, expo, ema_timestamp),
            )
        )
    }
}
