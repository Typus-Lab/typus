/// This module implements a generic oracle that can be updated from different sources.
/// It supports Switchboard, Pyth, and Supra oracles.
/// The oracle can be used to get the price of a token pair.
module typus_oracle::oracle {
    use sui::event::emit;
    use sui::clock::{Self, Clock};
    use sui::dynamic_field;

    use std::string;
    use std::type_name::{Self, TypeName};
    use std::ascii::{Self, String};

    // ======== Structs =========

    /// A capability that allows the owner to manage the oracle.
    public struct ManagerCap has key {
        id: UID,
    }

    /// The oracle object.
    public struct Oracle has key {
        id: UID,
        /// The base token of the token pair.
        base_token: String,
        /// The quote token of the token pair.
        quote_token: String,
        /// The type name of the base token.
        base_token_type: TypeName,
        /// The type name of the quote token.
        quote_token_type: TypeName,
        /// The number of decimals of the price.
        decimal: u64,
        /// The latest price.
        price: u64,
        /// The time-weighted average price.
        twap_price: u64,
        /// The timestamp of the latest price update in milliseconds.
        ts_ms: u64,
        /// The epoch of the latest price update.
        epoch: u64,
        /// The time interval for which the oracle price is considered valid.
        time_interval: u64,
        /// The ID of the Switchboard feed if it is used.
        switchboard: Option<ID>,
        /// The ID of the Pyth feed if it is used.
        pyth: Option<ID>,
    }

    // ======== Functions =========

    /// Initializes the oracle module.
    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );
    }

    /// Initializes the oracle module for testing.
    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    /// Creates a new oracle.
    /// Safe with `ManagerCap` check
    public entry fun new_oracle<B_TOKEN, Q_TOKEN>(
        _manager_cap: &ManagerCap,
        base_token: String,
        quote_token: String,
        decimal: u64,
        ctx: &mut TxContext
    ) {

        let id = object::new(ctx);

        let mut oracle = Oracle {
            id,
            base_token,
            quote_token,
            base_token_type: type_name::get<B_TOKEN>(),
            quote_token_type: type_name::get<Q_TOKEN>(),
            decimal,
            price: 0,
            twap_price: 0,
            ts_ms: 0,
            epoch: tx_context::epoch(ctx),
            time_interval: 300 * 1000,
            switchboard: option::none(),
            pyth: option::none(),
        };
        // add version
        dynamic_field::add(&mut oracle.id, string::utf8(b"VERSION"), VERSION);

        transfer::share_object(oracle);
    }

    /// A capability that allows the owner to update the oracle.
    public struct UpdateAuthority has key {
        id: UID,
        authority: vector<address>,
    }

    /// Creates a new update authority.
    /// Safe with `ManagerCap` check
    entry fun new_update_authority(
        _manager_cap: &ManagerCap,
        ctx: &mut TxContext
    ) {
        let update_authority = UpdateAuthority {id: object::new(ctx), authority: vector[ tx_context::sender(ctx) ]};
        transfer::share_object(update_authority);
    }

    /// Adds new addresses to the update authority.
    /// Safe with `ManagerCap` check
    entry fun add_update_authority(
        _manager_cap: &ManagerCap,
        update_authority: &mut UpdateAuthority,
        mut addresses: vector<address>,
    ) {
        while (vector::length(&addresses) > 0) {
            let a: address = vector::pop_back(&mut addresses);
            vector::push_back(&mut update_authority.authority, a);
        }
    }

    /// Removes addresses from the update authority.
    /// Safe with `ManagerCap` check
    entry fun remove_update_authority(
        _manager_cap: &ManagerCap,
        update_authority: &mut UpdateAuthority,
        mut addresses: vector<address>,
    ) {
        while (vector::length(&addresses) > 0) {
            let a: address = vector::pop_back(&mut addresses);
            let (find, i) = vector::index_of(&update_authority.authority, &a);
            if (find) {
                vector::remove(&mut update_authority.authority, i);
            }
        }
    }

    const VERSION: u64 = 1;

    /// Updates the version of the oracle.
    /// Safe with `ManagerCap` check
    entry fun update_version(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
    ) {
        if (dynamic_field::exists_(&oracle.id, string::utf8(b"VERSION"))) {
            *dynamic_field::borrow_mut(&mut oracle.id, string::utf8(b"VERSION")) = VERSION;
        } else {
            dynamic_field::add(&mut oracle.id, string::utf8(b"VERSION"), VERSION);
        }
    }

    /// Checks the version of the oracle.
    fun version_check(oracle: &Oracle,) {
        if (dynamic_field::exists_(&oracle.id, string::utf8(b"VERSION"))) {
            let v: u64 = *dynamic_field::borrow(&oracle.id, string::utf8(b"VERSION"));
            assert!(VERSION >= v, E_INVALID_VERSION);
        } else {
            abort(E_INVALID_VERSION)
        }
    }

    /// Updates the oracle price with the given price and TWAP price.
    /// This function can only be called by the update authority.
    /// Safe with `UpdateAuthority` check
    public entry fun update_v2(
        oracle: &mut Oracle,
        update_authority: & UpdateAuthority,
        price: u64,
        twap_price: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // check authority
        vector::contains(&update_authority.authority, &tx_context::sender(ctx));
        version_check(oracle);

        update_(oracle, price, twap_price, clock, ctx);
    }

    /// Updates the oracle price with the given price and TWAP price.
    /// This function can only be called by the manager.
    /// Safe with `ManagerCap` check
    public entry fun update(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        price: u64,
        twap_price: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        version_check(oracle);
        update_(oracle, price, twap_price, clock, ctx);
    }

    /// Internal function to update the oracle price.
    fun update_(
        oracle: &mut Oracle,
        price: u64,
        twap_price: u64,
        clock: &Clock,
        ctx: & TxContext
    ) {
        assert!(price > 0, E_INVALID_PRICE);
        assert!(twap_price > 0, E_INVALID_PRICE);

        let ts_ms = clock::timestamp_ms(clock);

        oracle.price = price;
        oracle.twap_price = twap_price;
        oracle.ts_ms = ts_ms;
        oracle.epoch = tx_context::epoch(ctx);

        emit(PriceEvent {id: object::id(oracle), price, ts_ms});
    }

    use switchboard_std::aggregator::{Aggregator};
    use typus_oracle::switchboard_feed_parser;

    /// Updates the Switchboard oracle feed ID.
    /// Safe with `ManagerCap` check
    entry fun update_switchboard_oracle(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        feed: &Aggregator,
    ) {
        version_check(oracle);
        let id = object::id(feed);
        oracle.switchboard = option::some(id);
    }

    /// Updates the oracle price with the Switchboard feed.
    /// Safe without authority check
    entry fun update_with_switchboard(
        oracle: &mut Oracle,
        feed: &Aggregator,
        clock: &Clock,
        ctx: & TxContext
    ) {
        version_check(oracle);
        assert!(option::is_some(&oracle.switchboard), E_NOT_SWITCHBOARD);
        assert!(option::borrow(&oracle.switchboard) == &object::id(feed), E_INVALID_SWITCHBOARD);

        let ts_ms = clock::timestamp_ms(clock);

        let (mut price_u128, decimal_u8) = switchboard_feed_parser::log_aggregator_info(feed);
        assert!(price_u128 > 0, E_INVALID_PRICE);

        let decimal = (decimal_u8 as u64);
        if (decimal > oracle.decimal) {
            price_u128 = price_u128 / (10u64.pow((decimal - oracle.decimal) as u8) as u128);
        } else {
            price_u128 = price_u128 * (10u64.pow((oracle.decimal - decimal) as u8) as u128);
        };

        let price = (price_u128 as u64);
        oracle.price = price;
        oracle.twap_price = price;
        oracle.ts_ms = ts_ms;
        oracle.epoch = tx_context::epoch(ctx);

        emit(PriceEvent {id: object::id(oracle), price, ts_ms});
    }

    use typus_oracle::pyth_parser;
    use pyth::state::{State as PythState};
    use pyth::price_info::{PriceInfoObject};

    /// Updates the Pyth oracle feed ID.
    /// Safe with `ManagerCap` check
    entry fun update_pyth_oracle(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        base_price_info_object: &PriceInfoObject,
        quote_price_info_object: &PriceInfoObject,
    ) {
        version_check(oracle);
        let id = object::id(base_price_info_object);
        oracle.pyth = option::some(id);
        // add quote
        let id = object::id(quote_price_info_object);
        dynamic_field::add(&mut oracle.id, string::utf8(b"quote_price_info_object"), id);
    }

    /// Updates the oracle price with the Pyth feed.
    /// Safe without authority check
    public fun update_with_pyth(
        oracle: &mut Oracle,
        state: &PythState,
        base_price_info_object: &PriceInfoObject,
        quote_price_info_object: &PriceInfoObject,
        clock: &Clock,
        ctx: & TxContext
    ) {
        version_check(oracle);
        assert!(option::is_some(&oracle.pyth), E_NOT_PYTH);
        assert!(option::borrow(&oracle.pyth) == &object::id(base_price_info_object), E_INVALID_PYTH);
        assert!(dynamic_field::borrow(&oracle.id, string::utf8(b"quote_price_info_object"))== &object::id(quote_price_info_object), E_INVALID_PYTH);

        let (mut base_price, decimal) = pyth_parser::get_price(state, base_price_info_object, clock);
        assert!(base_price > 0, E_INVALID_PRICE);

        if (decimal > oracle.decimal) {
            base_price = base_price / 10u64.pow((decimal - oracle.decimal) as u8);
        } else {
            base_price = base_price * 10u64.pow((oracle.decimal - decimal) as u8);
        };

        let (quote_price, decimal) = pyth_parser::get_price(state, quote_price_info_object, clock);
        assert!(quote_price > 0, E_INVALID_PRICE);

        let price = (((base_price as u128) * (10u64.pow(decimal as u8) as u128) / (quote_price as u128)) as u64);
        oracle.price = price;
        let ts_ms = clock::timestamp_ms(clock);
        oracle.ts_ms = ts_ms;
        oracle.epoch = tx_context::epoch(ctx);

        let (mut base_price, decimal, pyth_ts) = pyth_parser::get_ema_price(base_price_info_object);
        assert!(base_price > 0, E_INVALID_PRICE);
        assert!(ts_ms/1000 - pyth_ts < oracle.time_interval, E_ORACLE_EXPIRED);

        if (decimal > oracle.decimal) {
            base_price = base_price / 10u64.pow((decimal - oracle.decimal) as u8);
        } else {
            base_price = base_price * 10u64.pow((oracle.decimal - decimal) as u8);
        };

        let (quote_price, decimal, pyth_ts) = pyth_parser::get_ema_price(quote_price_info_object);
        assert!(quote_price > 0, E_INVALID_PRICE);
        assert!(ts_ms/1000 - pyth_ts < oracle.time_interval, E_ORACLE_EXPIRED);

        oracle.twap_price = (((base_price as u128) * (10u64.pow(decimal as u8) as u128) / (quote_price as u128)) as u64);

        emit(PriceEvent {id: object::id(oracle), price, ts_ms});
    }

    /// Updates the Pyth oracle feed ID for USD pairs.
    /// Safe with `ManagerCap` check
    entry fun update_pyth_oracle_usd(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        base_price_info_object: &PriceInfoObject,
    ) {
        version_check(oracle);
        // only quote token is USD
        assert!(oracle.quote_token == ascii::string(b"USD") || oracle.base_token == ascii::string(b"USD"), E_NOT_PYTH);
        let id = object::id(base_price_info_object);
        oracle.pyth = option::some(id);
    }

    /// Updates the Pyth oracle feed ID for reciprocal USD pairs.
    /// Safe with `ManagerCap` check
    entry fun update_pyth_oracle_usd_reciprocal(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        base_price_info_object: &PriceInfoObject,
    ) {
        version_check(oracle);
        // only quote token is USD
        assert!(oracle.quote_token == ascii::string(b"USD"), E_NOT_PYTH);
        let id = object::id(base_price_info_object);
        oracle.pyth = option::none();
        dynamic_field::add(&mut oracle.id, string::utf8(b"reciprocal_pyth"), id);
    }

    /// Updates the oracle price with the Pyth feed for USD pairs.
    /// Safe without authority check
    public fun update_with_pyth_usd(
        oracle: &mut Oracle,
        state: &PythState,
        base_price_info_object: &PriceInfoObject,
        clock: &Clock,
        ctx: & TxContext
    ) {
        version_check(oracle);
        // only quote token is USD
        assert!(oracle.quote_token == ascii::string(b"USD") || oracle.base_token == ascii::string(b"USD"), E_NOT_PYTH);

        let mut reciprocal = false;
        if (dynamic_field::exists_(&oracle.id, string::utf8(b"reciprocal_pyth"))) {
            reciprocal = true;
            let pyth = *dynamic_field::borrow(&oracle.id, string::utf8(b"reciprocal_pyth"));
            assert!(pyth == &object::id(base_price_info_object), E_INVALID_PYTH);
        } else {
            // normal situation
            assert!(option::is_some(&oracle.pyth), E_NOT_PYTH);
            assert!(option::borrow(&oracle.pyth) == &object::id(base_price_info_object), E_INVALID_PYTH);
        };

        let (mut base_price, decimal) = pyth_parser::get_price(state, base_price_info_object, clock);
        assert!(base_price > 0, E_INVALID_PRICE);

        if (decimal > oracle.decimal) {
            base_price = base_price / 10u64.pow((decimal - oracle.decimal) as u8);
        } else {
            base_price = base_price * 10u64.pow((oracle.decimal - decimal) as u8);
        };

        let price = if (reciprocal) {
            10u64.pow((oracle.decimal * 2) as u8) / base_price
        } else {
            base_price
        };

        oracle.price = price;
        let ts_ms = clock::timestamp_ms(clock);
        oracle.ts_ms = ts_ms;
        oracle.epoch = tx_context::epoch(ctx);

        let (mut base_price, decimal, pyth_ts) = pyth_parser::get_ema_price(base_price_info_object);
        assert!(base_price > 0, E_INVALID_PRICE);
        assert!(ts_ms/1000 - pyth_ts < oracle.time_interval, E_ORACLE_EXPIRED);

        if (decimal > oracle.decimal) {
            base_price = base_price / 10u64.pow((decimal - oracle.decimal) as u8);
        } else {
            base_price = base_price * 10u64.pow((oracle.decimal - decimal) as u8);
        };

        if (reciprocal) {
            oracle.twap_price = 10u64.pow((oracle.decimal * 2) as u8) / base_price
        } else {
            oracle.twap_price = base_price
        };

        emit(PriceEvent {id: object::id(oracle), price, ts_ms});
    }

    use typus_oracle::supra;
    use SupraOracle::SupraSValueFeed::OracleHolder;

    /// Updates the Supra oracle pair ID.
    /// Safe with `ManagerCap` check
    entry fun update_supra_oracle(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        pair: u32
    ) {
        version_check(oracle);
        if (dynamic_field::exists_(& oracle.id, string::utf8(b"supra_pair"))) {
            let supra_pair: &mut u32 = dynamic_field::borrow_mut(&mut oracle.id, string::utf8(b"supra_pair"));
            *supra_pair = pair;
        } else {
            dynamic_field::add(&mut oracle.id, string::utf8(b"supra_pair"), pair);
        };
    }

    /// Updates the oracle price with the Supra feed.
    /// Safe with `ManagerCap` check
    entry fun update_with_supra(
        oracle: &mut Oracle,
        oracle_holder: &OracleHolder,
        clock: &Clock,
        ctx: & TxContext
    ) {
        version_check(oracle);
        let pair: u32 = *dynamic_field::borrow(&oracle.id, string::utf8(b"supra_pair"));

        let (mut price_u128, decimal, timestamp_ms_u128) = supra::retrieve_price(oracle_holder, pair);
        assert!(price_u128 > 0, E_INVALID_PRICE);

        let ts_ms = clock::timestamp_ms(clock);
        assert!(ts_ms - (timestamp_ms_u128 as u64) < oracle.time_interval, E_ORACLE_EXPIRED);

        let oracle_decimal = (oracle.decimal as u16);

        if (decimal > oracle_decimal) {
            price_u128 = price_u128 / (10u64.pow(((decimal - oracle_decimal) as u8)) as u128);
        } else {
            price_u128 = price_u128 * (10u64.pow(((oracle_decimal - decimal) as u8)) as u128);
        };

        let price_u64 = (price_u128 as u64);

        oracle.price = price_u64;
        oracle.twap_price = price_u64;
        oracle.ts_ms = ts_ms;
        oracle.epoch = tx_context::epoch(ctx);

        emit(PriceEvent {id: object::id(oracle), price: price_u64, ts_ms});
    }

    /// Copies the manager capability.
    /// Safe with `ManagerCap` check
    public entry fun copy_manager_cap(
        _manager_cap: &ManagerCap,
        recipient: address,
        ctx: &mut TxContext
    ) {
        transfer::transfer(ManagerCap {id: object::new(ctx)}, recipient);
    }

    /// Burns the manager capability.
    public entry fun burn_manager_cap(
        manager_cap: ManagerCap,
    ) {
        let ManagerCap {
            id
        } = manager_cap;
        id.delete();
    }

    /// getter function Returns the oracle data.
    public fun get_oracle(
        oracle: &Oracle
    ): (u64, u64, u64, u64) {
        (oracle.price, oracle.decimal, oracle.ts_ms, oracle.epoch)
    }

    /// getter function Returns the token data.
    public fun get_token(
        oracle: &Oracle
    ): (String, String, TypeName, TypeName) {
        (oracle.base_token, oracle.quote_token, oracle.base_token_type, oracle.quote_token_type)
    }

    /// getter function Returns the price and decimals of the oracle.
    public fun get_price(
        oracle: &Oracle,
        clock: &Clock,
    ): (u64, u64) {
        let ts_ms = clock::timestamp_ms(clock);
        assert!(ts_ms - oracle.ts_ms < oracle.time_interval, E_ORACLE_EXPIRED);
        (oracle.price, oracle.decimal)
    }

    /// getter function Returns the TWAP price and decimals of the oracle.
    public fun get_twap_price(
        oracle: &Oracle,
        clock: &Clock,
    ): (u64, u64) {
        let ts_ms = clock::timestamp_ms(clock);
        assert!(ts_ms - oracle.ts_ms < oracle.time_interval, E_ORACLE_EXPIRED);
        (oracle.twap_price, oracle.decimal)
    }

    /// getter function Returns the price and decimals of the oracle with a custom time interval.
    public fun get_price_with_interval_ms(
        oracle: &Oracle,
        clock: &Clock,
        interval_ms: u64,
    ): (u64, u64) {
        let ts_ms = clock::timestamp_ms(clock);
        assert!(ts_ms - oracle.ts_ms < oracle.time_interval && ts_ms - oracle.ts_ms <= interval_ms, E_ORACLE_EXPIRED);
        (oracle.price, oracle.decimal)
    }

    /// Updates the time interval of the oracle.
    /// Safe with `ManagerCap` check
    public entry fun update_time_interval(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        time_interval: u64,
    ) {
        version_check(oracle);
        oracle.time_interval = time_interval;
    }

    /// Updates the token names of the oracle.
    /// Safe with `ManagerCap` check
    public entry fun update_token(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        quote_token: String,
        base_token: String,
    ) {
        version_check(oracle);
        oracle.quote_token = quote_token;
        oracle.base_token = base_token;
    }


    const E_ORACLE_EXPIRED: u64 = 1;
    const E_INVALID_PRICE: u64 = 2;
    const E_NOT_SWITCHBOARD: u64 = 3;
    const E_INVALID_SWITCHBOARD: u64 = 4;
    const E_NOT_PYTH: u64 = 5;
    const E_INVALID_PYTH: u64 = 6;
    const E_INVALID_VERSION: u64 = 7;

    /// Event emitted when the price is updated.
    public struct PriceEvent has copy, drop { id: ID, price: u64, ts_ms: u64 }
}