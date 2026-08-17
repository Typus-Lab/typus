module typus_oracle::oracle {
    use sui::bcs;
    use sui::bls12381::bls12381_min_pk_verify;
    use sui::clock::{Self, Clock};
    use sui::dynamic_field;
    use sui::event::emit;

    use std::ascii::{Self, String};
    use std::string;
    use std::type_name::{Self, TypeName};

    use pyth::price_info::PriceInfoObject;
    use pyth::state::State;

    use typus_oracle::pyth_parser;

    // ======== Constants =========

    const CVersion: u64 = 2;

    // ======== Errors =========

    #[error]
    const EInvalidPrice: vector<u8> = b"Invalid Price";
    #[error]
    const EInvalidPyth: vector<u8> = b"Invalid Pyth";
    #[error]
    const EInvalidUpdateCap: vector<u8> = b"Invalid Update Cap";
    #[error]
    const EInvalidVersion: vector<u8> = b"Invalid Version";
    #[error]
    const ENotPyth: vector<u8> = b"Not Pyth";
    #[error]
    const EOracleExpired: vector<u8> = b"Oracle Expired";
    #[error]
    const EInvalidMessage: vector<u8> = b"Invalid Message";
    #[error]
    const EInvalidSignature: vector<u8> = b"Invalid Signature";
    #[error]
    const ETokenTypeMismatched: vector<u8> = b"Token Type Mismatched";
    #[error]
    const ETimestampMsTooOld: vector<u8> = b"Timestamp Ms Too Old";


    // ======== Structs =========

    public struct ManagerCap has key {
        id: UID,
    }

    public struct UpdateCap has key {
        id: UID,
        `for`: address,
    }

    public struct UpdateCaps has key {
        id: UID,
        `for`: vector<address>,
    }

    public struct Oracle has key {
        id: UID,
        base_token: String,
        quote_token: String,
        base_token_type: TypeName,
        quote_token_type: TypeName,
        decimal: u64,
        price: u64,
        twap_price: u64,
        ts_ms: u64,
        epoch: u64,
        time_interval: u64, // in ms!
        switchboard: Option<ID>,
        pyth: Option<ID>,
    }

    public struct PriceEvent has copy, drop {
        id: ID,
        price: u64,
        ts_ms: u64,
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            ManagerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );
    }

    // ======== Manager Functions =========

    #[allow(deprecated_usage)]
    public fun burn_update_authority(
        update_authority: UpdateAuthority,
    ) {
        let UpdateAuthority {
            id,
            authority: _,
        } = update_authority;
        id.delete();
    }

    public fun copy_manager_cap(
        _manager_cap: &ManagerCap,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        transfer::transfer(ManagerCap {id: object::new(ctx)}, recipient);
    }

    public fun burn_manager_cap(
        manager_cap: ManagerCap,
    ) {
        let ManagerCap {
            id
        } = manager_cap;
        id.delete();
    }

    entry fun create_update_cap(
        _manager_cap: &ManagerCap,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        transfer::share_object(
            UpdateCap {
                id: object::new(ctx),
                `for`: recipient,
            }
        );
    }

    entry fun burn_update_cap(
        _manager_cap: &ManagerCap,
        update_cap: UpdateCap,
    ) {
        let UpdateCap {
            id,
            `for`: _,
        } = update_cap;
        id.delete();
    }

    entry fun create_update_caps(
        _manager_cap: &ManagerCap,
        ctx: &mut TxContext,
    ) {
        transfer::share_object(
            UpdateCaps {
                id: object::new(ctx),
                `for`: vector[],
            }
        );
    }

    entry fun burn_update_caps(
        _manager_cap: &ManagerCap,
        update_caps: UpdateCaps,
    ) {
        let UpdateCaps {
            id,
            `for`: _,
        } = update_caps;
        id.delete();
    }

    entry fun add_update_caps_user(
        _manager_cap: &ManagerCap,
        update_caps: &mut UpdateCaps,
        user: address,
    ) {
        if (!update_caps.`for`.contains(&user)) {
            update_caps.`for`.push_back(user);
        };
    }

    entry fun remove_update_caps_user(
        _manager_cap: &ManagerCap,
        update_caps: &mut UpdateCaps,
        user: address,
    ) {
        let (user_exists, index) = update_caps.`for`.index_of(&user);
        if (user_exists) {
            update_caps.`for`.remove(index);
        };
    }

    entry fun update_version(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
    ) {
        if (dynamic_field::exists_(&oracle.id, string::utf8(b"VERSION"))) {
            *dynamic_field::borrow_mut(&mut oracle.id, string::utf8(b"VERSION")) = CVersion;
        } else {
            dynamic_field::add(&mut oracle.id, string::utf8(b"VERSION"), CVersion);
        }
    }

    entry fun update_bls_public_key(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        public_key: vector<u8>,
    ) {
        version_check(oracle);

        if (dynamic_field::exists_(&oracle.id, string::utf8(b"bls_public_key"))) {
            *dynamic_field::borrow_mut(&mut oracle.id, string::utf8(b"bls_public_key")) = public_key;
        } else {
            dynamic_field::add(&mut oracle.id, string::utf8(b"bls_public_key"), public_key);
        };
    }

    public fun new_oracle<B_TOKEN, Q_TOKEN>(
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
            base_token_type: type_name::with_defining_ids<B_TOKEN>(),
            quote_token_type: type_name::with_defining_ids<Q_TOKEN>(),
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
        dynamic_field::add(&mut oracle.id, string::utf8(b"VERSION"), CVersion);

        transfer::share_object(oracle);
    }

    public fun update(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        price: u64,
        twap_price: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version_check(oracle);
        update_(oracle, price, twap_price, clock, ctx);
    }

    public fun update_with_update_cap(
        oracle: &mut Oracle,
        update_cap: &UpdateCap,
        price: u64,
        twap_price: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        version_check(oracle);
        assert!(update_cap.`for` == ctx.sender(), EInvalidUpdateCap);
        update_(oracle, price, twap_price, clock, ctx);
    }

    public fun update_with_update_caps(
        oracle: &mut Oracle,
        update_cap: &UpdateCaps,
        price: u64,
        twap_price: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        version_check(oracle);
        assert!(update_cap.`for`.contains(&ctx.sender()), EInvalidUpdateCap);
        update_(oracle, price, twap_price, clock, ctx);
    }

    public fun update_time_interval(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        time_interval: u64,
    ) {
        version_check(oracle);
        oracle.time_interval = time_interval;
        emit(UpdateTimeIntervalEvent{
            oracle_id: object::id(oracle),
            time_interval,
        })
    }

    public struct UpdateTimeIntervalEvent has copy, drop {
        oracle_id: ID,
        time_interval: u64,
    }

    public fun update_token(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        quote_token: String,
        base_token: String,
    ) {
        version_check(oracle);
        oracle.quote_token = quote_token;
        oracle.base_token = base_token;
        emit(UpdateTokenNameEvent{
            oracle_id: object::id(oracle),
            quote_token,
            base_token,
        })
    }

    public struct UpdateTokenNameEvent has copy, drop {
        oracle_id: ID,
        quote_token: String,
        base_token: String,
    }

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
        emit(UpdatePythOracleEvent {
            oracle_id: object::id(oracle),
            base_price_info_object: option::some(object::id(base_price_info_object)),
            quote_price_info_object: option::some(object::id(quote_price_info_object)),
        })
    }

    public struct UpdatePythOracleEvent has copy, drop {
        oracle_id: ID,
        base_price_info_object: Option<ID>,
        quote_price_info_object: Option<ID>,
    }

    entry fun update_pyth_oracle_usd(
        oracle: &mut Oracle,
        _manager_cap: &ManagerCap,
        base_price_info_object: &PriceInfoObject,
    ) {
        version_check(oracle);
        // only quote token is USD
        assert!(oracle.quote_token == ascii::string(b"USD") || oracle.base_token == ascii::string(b"USD"), ENotPyth);
        let id = object::id(base_price_info_object);
        oracle.pyth = option::some(id);
        emit(UpdatePythOracleEvent {
            oracle_id: object::id(oracle),
            base_price_info_object: option::some(object::id(base_price_info_object)),
            quote_price_info_object: option::none(),
        })
    }

    // ======== Permissionless Functions =========

    public fun update_with_pyth(
        oracle: &mut Oracle,
        state: &State,
        base_price_info_object: &PriceInfoObject,
        quote_price_info_object: &PriceInfoObject,
        clock: &Clock,
        ctx: & TxContext
    ) {
        version_check(oracle);
        assert!(option::is_some(&oracle.pyth), ENotPyth);
        assert!(option::borrow(&oracle.pyth) == &object::id(base_price_info_object), EInvalidPyth);
        assert!(dynamic_field::borrow(&oracle.id, string::utf8(b"quote_price_info_object"))== &object::id(quote_price_info_object), EInvalidPyth);

        let (base_price, base_decimal, _) = pyth_parser::get_price(state, base_price_info_object, clock);
        let (quote_price, quote_decimal, _) = pyth_parser::get_price(state, quote_price_info_object, clock);
        assert!(base_price > 0, EInvalidPrice);
        assert!(quote_price > 0, EInvalidPrice);
        let price = (((base_price as u256)
            * (10u64.pow(oracle.decimal as u8) as u256)
            * (10u64.pow(quote_decimal as u8) as u256)
            / (10u64.pow(base_decimal as u8) as u256)
            / (quote_price as u256)) as u64);
        let (base_price, base_decimal, _) = pyth_parser::get_ema_price(base_price_info_object);
        let (quote_price, quote_decimal, _) = pyth_parser::get_ema_price(quote_price_info_object);
        assert!(base_price > 0, EInvalidPrice);
        assert!(quote_price > 0, EInvalidPrice);
        let twap_price = (((base_price as u256)
            * (10u64.pow(oracle.decimal as u8) as u256)
            * (10u64.pow(quote_decimal as u8) as u256)
            / (10u64.pow(base_decimal as u8) as u256)
            / (quote_price as u256)) as u64);

        update_(oracle, price, twap_price, clock, ctx);
    }

    public fun update_with_pyth_usd(
        oracle: &mut Oracle,
        state: &State,
        base_price_info_object: &PriceInfoObject,
        clock: &Clock,
        ctx: & TxContext
    ) {
        version_check(oracle);
        // quote token is USD or special case USD/JPY
        assert!(oracle.quote_token == ascii::string(b"USD") ||
            (oracle.base_token == ascii::string(b"USD") && oracle.quote_token == ascii::string(b"JPY")), ENotPyth);
        // double check for USD quote
        assert!(!dynamic_field::exists_(&oracle.id, string::utf8(b"quote_price_info_object")), EInvalidPyth);

        assert!(oracle.pyth == option::some(object::id(base_price_info_object)), EInvalidPyth);

        let (base_price, base_decimal, _) = pyth_parser::get_price(state, base_price_info_object, clock);
        assert!(base_price > 0, EInvalidPrice);
        let price = (((base_price as u256)
            * (10u64.pow(oracle.decimal as u8) as u256)
            / (10u64.pow(base_decimal as u8) as u256)) as u64);

        let (base_price, base_decimal, _) = pyth_parser::get_ema_price(base_price_info_object);
        assert!(base_price > 0, EInvalidPrice);
        let twap_price = (((base_price as u256)
            * (10u64.pow(oracle.decimal as u8) as u256)
            / (10u64.pow(base_decimal as u8) as u256)) as u64);

        update_(oracle, price, twap_price, clock, ctx);
    }

    public fun update_with_signature(
        oracle: &mut Oracle,
        signature: vector<u8>,
        message: vector<u8>,
        token_type: vector<u8>,
        price: u64,
        twap_price: u64,
        timestamp_ms: u64,
        clock: &Clock,
        ctx: & TxContext
    ) {
        version_check(oracle);

        let mut message_bytes = vector[];

        message_bytes.append(object::id_to_bytes(&oracle.id.uid_to_inner()));
        message_bytes.append(token_type);
        message_bytes.append( bcs::to_bytes(&price));
        message_bytes.append( bcs::to_bytes(&twap_price));
        message_bytes.append( bcs::to_bytes(&timestamp_ms));
        assert!(message_bytes == message, EInvalidMessage);

        let clock_ms = clock.timestamp_ms();

        let public_key = dynamic_field::borrow(&oracle.id, string::utf8(b"bls_public_key"));
        assert!(bls12381_min_pk_verify(&signature, public_key, &message), EInvalidSignature);
        assert!(oracle.base_token_type.as_string() == ascii::string(token_type), ETokenTypeMismatched);
        assert!(clock_ms.diff(timestamp_ms) < oracle.time_interval, EOracleExpired);
        assert!(oracle.ts_ms < timestamp_ms, ETimestampMsTooOld);

        update_(oracle, price, twap_price, clock, ctx);
    }

    // ======== Utility =========

    fun version_check(
        oracle: &Oracle,
    ) {
        if (dynamic_field::exists_(&oracle.id, string::utf8(b"VERSION"))) {
            let v: u64 = *dynamic_field::borrow(&oracle.id, string::utf8(b"VERSION"));
            assert!(CVersion >= v, EInvalidVersion);
            return
        };

        abort EInvalidVersion
    }

    fun update_(
        oracle: &mut Oracle,
        price: u64,
        twap_price: u64,
        clock: &Clock,
        ctx: &TxContext
    ) {
        assert!(price > 0, EInvalidPrice);
        assert!(twap_price > 0, EInvalidPrice);

        let ts_ms = clock::timestamp_ms(clock);

        oracle.price = price;
        oracle.twap_price = twap_price;
        oracle.ts_ms = ts_ms;
        oracle.epoch = tx_context::epoch(ctx);

        emit(PriceEvent {id: object::id(oracle), price, ts_ms});
    }

    public fun get_oracle(
        oracle: &Oracle,
    ): (u64, u64, u64, u64) {
        (oracle.price, oracle.decimal, oracle.ts_ms, oracle.epoch)
    }

    public fun get_token(
        oracle: &Oracle,
    ): (String, String, TypeName, TypeName) {
        (oracle.base_token, oracle.quote_token, oracle.base_token_type, oracle.quote_token_type)
    }

    public fun get_price(
        oracle: &Oracle,
        clock: &Clock,
    ): (u64, u64) {
        let ts_ms = clock::timestamp_ms(clock);
        assert!(ts_ms - oracle.ts_ms < oracle.time_interval, EOracleExpired);
        (oracle.price, oracle.decimal)
    }

    public fun get_twap_price(
        oracle: &Oracle,
        clock: &Clock,
    ): (u64, u64) {
        let ts_ms = clock::timestamp_ms(clock);
        assert!(ts_ms - oracle.ts_ms < oracle.time_interval, EOracleExpired);
        (oracle.twap_price, oracle.decimal)
    }

    public fun get_price_with_interval_ms(
        oracle: &Oracle,
        clock: &Clock,
        interval_ms: u64,
    ): (u64, u64) {
        let ts_ms = clock::timestamp_ms(clock);
        assert!(ts_ms - oracle.ts_ms < oracle.time_interval && ts_ms - oracle.ts_ms <= interval_ms, EOracleExpired);
        (oracle.price, oracle.decimal)
    }

    // ======== Tests =========

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    // ======== Deprecated =========

    #[deprecated]
    public struct UpdateAuthority has key {
        id: UID,
        authority: vector<address>,
    }

    #[deprecated]
    public fun update_v2(
        _oracle: &mut Oracle,
        _update_authority: & UpdateAuthority,
        _price: u64,
        _twap_price: u64,
        _clock: &Clock,
        _ctx: &mut TxContext
    ) {
        abort 0
    }
}