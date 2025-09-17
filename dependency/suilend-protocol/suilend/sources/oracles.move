/// This module contains logic for parsing pyth prices (and eventually switchboard prices)
module suilend::oracles {
    use pyth::price_info::{Self, PriceInfoObject};
    use pyth::price_feed::{Self};
    use std::vector::{Self};
    use pyth::price_identifier::{PriceIdentifier, Self};
    use pyth::price::{Self, Price};
    use pyth::i64::{Self};
    use suilend::decimal::{Decimal, Self, mul, div};
    use sui::math::{Self};
    use std::option::{Self, Option};
    use sui::clock::{Self, Clock};

    // min confidence ratio of X means that the confidence interval must be less than (100/x)% of the price
    const MIN_CONFIDENCE_RATIO: u64 = 10;
    const MAX_STALENESS_SECONDS: u64 = 60;

    /// parse the pyth price info object to get a price and identifier. This function returns an None if the
    /// price is invalid due to confidence interval checks or staleness checks. It returns None instead of aborting
    /// so the caller can handle invalid prices gracefully by eg falling back to a different oracle
    /// return type: (spot price, ema price, price identifier)
    public fun get_pyth_price_and_identifier(price_info_obj: &PriceInfoObject, clock: &Clock): (Option<Decimal>, Decimal, PriceIdentifier) {
        let price_info = price_info::get_price_info_from_price_info_object(price_info_obj);
        let price_feed = price_info::get_price_feed(&price_info);
        let price_identifier = price_feed::get_price_identifier(price_feed);

        let ema_price = parse_price_to_decimal(price_feed::get_ema_price(price_feed));

        let price = price_feed::get_price(price_feed);
        let price_mag = i64::get_magnitude_if_positive(&price::get_price(&price));
        let conf = price::get_conf(&price);

        // confidence interval check
        // we want to make sure conf / price <= x%
        // -> conf * (100 / x )<= price
        if (conf * MIN_CONFIDENCE_RATIO > price_mag) {
            return (option::none(), ema_price, price_identifier)
        };

        // check current sui time against pythnet publish time. there can be some issues that arise because the
        // timestamps are from different sources and may get out of sync, but that's why we have a fallback oracle
        let cur_time_s = clock::timestamp_ms(clock) / 1000;
        if (cur_time_s > price::get_timestamp(&price) && // this is technically possible!
            cur_time_s - price::get_timestamp(&price) > MAX_STALENESS_SECONDS) {
            return (option::none(), ema_price, price_identifier)
        };

        let spot_price = parse_price_to_decimal(price);
        (option::some(spot_price), ema_price, price_identifier)
    }

    fun parse_price_to_decimal(price: Price): Decimal {
        // suilend doesn't support negative prices
        let price_mag = i64::get_magnitude_if_positive(&price::get_price(&price));
        let expo = price::get_expo(&price);

        if (i64::get_is_negative(&expo)) {
            div(
                decimal::from(price_mag),
                decimal::from(math::pow(10, (i64::get_magnitude_if_negative(&expo) as u8)))
            )
        }
        else {
            mul(
                decimal::from(price_mag),
                decimal::from(math::pow(10, (i64::get_magnitude_if_positive(&expo) as u8)))
            )
        }
    }

}

