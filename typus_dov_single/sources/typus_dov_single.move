module typus_dov::typus_dov_single {
    use std::bcs;
    use std::string::{Self, String};
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::dynamic_object_field;
    use sui::event::emit;
    use sui::sui::SUI;

    use protocol::market::Market;
    use protocol::reserve::MarketCoin;
    use protocol::version::Version;
    use spool::rewards_pool::RewardsPool;
    use spool::spool_account;
    use spool::spool_account::SpoolAccount;
    use spool::spool::Spool;

    use suilend::lending_market::LendingMarket;
    use suilend::suilend::MAIN_POOL;

    use oracle::config::OracleConfig;
    use oracle::oracle::PriceOracle;
    use oracle::oracle_pro;

    use typus_framework::authority::{Self, Authority};
    use typus_framework::balance_pool::{Self, BalancePool};
    use typus_framework::big_vector;
    use typus_framework::dutch::{Self, Auction};
    use typus_framework::i64::{Self, I64};
    use typus_framework::scallop;
    use typus_framework::suilend;
    use typus_framework::navi;
    use typus_framework::utils;
    use typus_framework::vault::{Self, DepositVault, BidVault, RefundVault, TypusBidReceipt};
    use typus_oracle::oracle::{Self, Oracle};
    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::leaderboard::{Self, TypusLeaderboardRegistry};
    use typus::linked_set;
    use typus::tgld::TgldRegistry;
    use typus::user::{Self, TypusUserRegistry};
    use typus::witness_lock::{Self, HotPotato};

    // ======== Constants ========

    const C_VERSION: u64 = 28;
    const C_LEVERAGE_DECIMAL: u64 = 2;
    const C_SHARE_PRICE_DECIMAL: u64 = 8;
    const C_U64_MAX: u64 = 18446744073709551615;
    const C_TYPUS_MOMENTUM_WITNESS: vector<u8> = b"1d58d7073a11aa9c5aa54e85ce2ff4b6199a4974579c8c4d7a89030b099a1a20::typus_momentum::VERSION";

    // ======== Status ========
    const S_ACTIVATE: u64 = 1;
    const S_NEW_AUCTION: u64 = 2;
    const S_DELIVERY: u64 = 3;
    const S_RECOUP: u64 = 4;
    const S_SETTLE: u64 = 5;

    // ======== Info u64_padding index ========
    const I_INFO_CURRENT_LENDING_PROTOCOL: u64 = 0; // 0: none, 1: scallop spool, 2: scallop, 3: suilend, 4: navi, 5: alphalend
    const I_INFO_SAFU_VAULT_INDEX_ADD_ONE_UP: u64 = 1; // 0: none, n: safu vault index = n - 1

    // ======== Config u64_padding index ========
    const I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT: u64 = 0;
    // const I_CONFIG_ENABLE_SCALLOP: u64 = 1; // scallop spool
    const I_CONFIG_FIXED_INCENTIVE_AMOUNT: u64 = 2;
    const I_CONFIG_DEPOSIT_INCENTIVE_BP_DIVISOR_DECIMAL: u64 = 3;
    // const I_CONFIG_ENABLE_SCALLOP_BASIC_LENDING: u64 = 4; // scallop basic lending
    const I_CONFIG_ENABLE_ADDITIONAL_LENDING: u64 = 5; // cranker ignore
    // const I_CONFIG_ENABLE_SUILEND: u64 = 6; // suilend
    const I_CONFIG_NEXT_LENDING_PROTOCOL: u64 = 7; // 0: none, 1: scallop spool, 2: scallop, 3: suilend, 4: navi
    const I_CONFIG_INCENTIVE_FEE_FLAGGED: u64 = 8;

    // ======== Active Vault Config u64_padding index ========
    const I_ACTIVE_VAULT_CONFIG_ROUND: u64 = 0;

    // ======== BidVault u64_padding index ========
    const I_BID_VAULT_SETTLE_PRICE: u64 = 0;
    const I_BID_VAULT_DELIVERY_PRICE: u64 = 1;
    const I_BID_VAULT_BID_INCENTIVE_BP: u64 = 2;
    const I_BID_VAULT_ROUND: u64 = 3;

    // ======== Manager Cap Key ========
    const K_TYPUS_ECOSYSTEM: vector<u8> = b"typus_ecosystem";
    const K_WITNESSES: vector<u8> = b"witnesses";

    // ======== Flag Key ========
    const K_ENABLE_TGLD: vector<u8> = b"enable_tgld";

    // ======== Additional Config Key ========
    const K_SCALLOP_SPOOL_ACCOUNT: vector<u8> = b"scallop_spool_account";
    const K_SCALLOP_MARKET_COIN: vector<u8> = b"scallop_market_coin";
    const K_DEPOSIT_SNAPSHOTS: vector<u8> = b"deposit_snapshots";
    const K_SUILEND_OBLIGATION_OWNER_CAP: vector<u8> = b"suilend_obligation_owner_cap";
    const K_NAVI_ACCOUNT_CAP: vector<u8> = b"navi_account_cap";
    const K_TYPUS_DEPOSIT_RECEIPT: vector<u8> = b"typus_deposit_receipt";
    const K_ALPHALEND_ACCOUNT_CAP: vector<u8> = b"alphalend_account_cap";

    // ======== Structs =========

    public struct TYPUS_DOV_SINGLE has drop {}

    public struct WITNESS has drop {}

    public struct Registry has key {
        id: UID,
        num_of_vault: u64,
        authority: Authority,
        fee_pool: BalancePool,
        portfolio_vault_registry: UID, // 1
        deposit_vault_registry: UID, // 1
        auction_registry: UID, // num_of_vault
        bid_vault_registry: UID, // num_of_vault * round
        refund_vault_registry: UID, // n tokens
        additional_config_registry: UID,
        version: u64,
        transaction_suspended: bool,
    }

    public struct PortfolioVault has key, store {
        id: UID,
        info: Info,
        config: Config,
        authority: Authority,
    }

    public struct Info has copy, drop, store {
        index: u64,
        option_type: u64, // 0: Call, 1: Put, 2: CallSpread, 3: PutSpread, 4: CappedCall, 5: CappedPut, 6: UsdCappedCall
        period: u8, // Daily = 0, Weekly = 1, Monthly = 2, Hourly = 3, 10 Minutes: 4
        activation_ts_ms: u64,
        expiration_ts_ms: u64,
        deposit_token: TypeName,
        bid_token: TypeName,
        settlement_base: TypeName,
        settlement_quote: TypeName,
        settlement_base_name: String,
        settlement_quote_name: String,
        d_token_decimal: u64,
        b_token_decimal: u64,
        o_token_decimal: u64,
        creator: address,
        create_ts_ms: u64,
        round: u64,
        status: u64,
        oracle_info: OracleInfo,
        delivery_infos: DeliveryInfos, // update after delivery
        settlement_info: Option<SettlementInfo>,
        u64_padding: vector<u64>,
        bcs_padding: vector<u8>,
    }

    public struct Config has copy, drop, store {
        oracle_id: address,
        deposit_lot_size: u64,
        bid_lot_size: u64,
        min_deposit_size: u64,
        min_bid_size: u64,
        max_deposit_entry: u64,
        max_bid_entry: u64,
        deposit_fee_bp: u64,
        deposit_fee_share_bp: u64,
        deposit_shared_fee_pool: Option<vector<u8>>,
        bid_fee_bp: u64,
        deposit_incentive_bp: u64,
        bid_incentive_bp: u64,
        auction_delay_ts_ms: u64,
        auction_duration_ts_ms: u64,
        recoup_delay_ts_ms: u64,
        capacity: u64,
        leverage: u64,
        risk_level: u64,
        has_next: bool, // set next round deposit vault has_next
        active_vault_config: VaultConfig,
        warmup_vault_config: VaultConfig,
        u64_padding: vector<u64>,
        bcs_padding: vector<u8>,
    }

    public struct PayoffConfig has copy, drop, store {
        strike_bp: u64,
        weight: u64,
        is_buyer: bool,
        strike: Option<u64>,
        u64_padding: vector<u64>,
    }

    public struct VaultConfig has copy, drop, store {
        payoff_configs: vector<PayoffConfig>,
        strike_increment: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
        u64_padding: vector<u64>,
    }

    public struct OracleInfo has copy, drop, store {
        price: u64,
        decimal: u64,
    }

    public struct DeliveryInfos has copy, drop, store {
        round: u64,
        max_size: u64,
        total_delivery_size: u64,
        total_bidder_bid_value: u64,
        total_bidder_fee: u64,
        total_incentive_bid_value: u64,
        total_incentive_fee: u64,
        delivery_info: vector<DeliveryInfo>,
        u64_padding: vector<u64>,
    }

    public struct DeliveryInfo has copy, drop, store {
        auction_type: u64, // 0: dutch, 1: otc
        delivery_price: u64,
        delivery_size: u64,
        bidder_bid_value: u64,
        bidder_fee: u64,
        incentive_bid_value: u64,
        incentive_fee: u64,
        ts_ms: u64,
        u64_padding: vector<u64>,
    }

    public struct SettlementInfo has copy, drop, store {
        round: u64,
        oracle_price: u64,
        oracle_price_decimal: u64,
        settle_balance: u64,
        settled_balance: u64,
        share_price: u64,
        share_price_decimal: u64,
        ts_ms: u64,
        u64_padding: vector<u64>,
    }

    public struct AdditionalConfig has key, store {
        id: UID,
    }

    public struct DepositSnapshot has store {
        snapshots: vector<u64>,
        total_deposit: u64,
        snapshot_ts_ms: u64,
    }

    // ======== Init Functions =========

    fun init(otw: TYPUS_DOV_SINGLE, ctx: &mut TxContext) {
        sui::package::claim_and_keep(otw, ctx);
        new_registry_(ctx);
    }

    entry fun adjust_premium_share_ratio<TOKEN>(registry: &mut Registry, index: u64) {
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        vault::adjust_user_share_ratio<TOKEN>(deposit_vault, vault::premium_share_tag());
    }

    entry fun adjust_incentive_share_ratio<TOKEN>(registry: &mut Registry, index: u64) {
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        vault::adjust_user_share_ratio<TOKEN>(deposit_vault, vault::incentive_share_tag());
    }

    entry fun create_deposit_snapshots_additional_config(
        registry: &mut Registry,
        ctx: &mut TxContext,
    ) {
        dynamic_object_field::add(
            &mut registry.additional_config_registry,
            K_DEPOSIT_SNAPSHOTS,
            AdditionalConfig { id: object::new(ctx) },
        );
    }

    entry fun set_enable_tgld_flag(
        registry: &mut Registry,
        enable: bool,
        ctx: &TxContext,
    ) {
        version_check(registry);
        validate_registry_authority(registry, ctx);

        if (enable) {
            dynamic_field::add(&mut registry.id, K_ENABLE_TGLD, true);
        } else {
            dynamic_field::remove<vector<u8>, bool>(&mut registry.id, K_ENABLE_TGLD);
        }

    }

    // ======== Registry Authorized Friend Functions =========

    public(package) fun new_registry_(
        ctx: &mut TxContext,
    ) {
        let vault_registry = Registry {
            id: object::new(ctx),
            num_of_vault: 0,
            authority: authority::new(vector::singleton(tx_context::sender(ctx)), ctx),
            fee_pool: balance_pool::new(vector::singleton(tx_context::sender(ctx)), ctx),
            portfolio_vault_registry: object::new(ctx),
            deposit_vault_registry: object::new(ctx),
            auction_registry: object::new(ctx),
            bid_vault_registry: object::new(ctx),
            refund_vault_registry: object::new(ctx),
            additional_config_registry: object::new(ctx),
            version: C_VERSION,
            transaction_suspended: false,
        };
        transfer::share_object(vault_registry);
    }

    public(package) fun suspend_transaction_(
        registry: &mut Registry,
    ) {
        assert!(!registry.transaction_suspended, transaction_already_suspended(0));
        registry.transaction_suspended = true;
    }

    public(package) fun resume_transaction_(
        registry: &mut Registry,
    ) {
        assert!(registry.transaction_suspended, transaction_already_resumed(0));
        registry.transaction_suspended = false;
    }

    public(package) fun incentivise_<TOKEN>(
        registry: &mut Registry,
        coin: Coin<TOKEN>,
    ): u64 {
        let amount = coin::value(&coin);
        if (dynamic_field::exists_with_type<TypeName, Balance<TOKEN>>(&registry.id, type_name::get<TOKEN>())) {
            balance::join(
                dynamic_field::borrow_mut(&mut registry.id, type_name::get<TOKEN>()),
                coin::into_balance(coin),
            );
        } else {
            dynamic_field::add(&mut registry.id, type_name::get<TOKEN>(), coin::into_balance(coin));
        };

        amount
    }

    public(package) fun withdraw_incentive_<TOKEN>(
        registry: &mut Registry,
        amount: Option<u64>,
        ctx: &mut TxContext,
    ): Coin<TOKEN> {
        if (dynamic_field::exists_with_type<TypeName, Balance<TOKEN>>(&registry.id, type_name::get<TOKEN>())) {
            let withdraw_balance = if (option::is_some(&amount)) {
                let amount = option::borrow(&amount);
                let incentive_balance = dynamic_field::borrow_mut(&mut registry.id, type_name::get<TOKEN>());
                let withdraw_amount = if (*amount > balance::value(incentive_balance)) {
                    balance::value(incentive_balance)
                } else {
                    *amount
                };
                balance::split(incentive_balance, withdraw_amount)
            } else {
                let incentive_balance = dynamic_field::borrow_mut(&mut registry.id, type_name::get<TOKEN>());
                let value = balance::value(incentive_balance);
                balance::split(incentive_balance, value)
            };
            coin::from_balance(withdraw_balance, ctx)
        } else {
            coin::zero<TOKEN>(ctx)
        }
    }

    public(package) fun fixed_incentivise_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        coin: Coin<TOKEN>,
        fixed_incentive_amount: u64,
    ): u64 {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        vault::update_deposit_vault_incentive_token<TOKEN>(deposit_vault);
        let amount = coin::value(&coin);
        if (dynamic_field::exists_with_type<TypeName, Balance<TOKEN>>(&portfolio_vault.id, type_name::get<TOKEN>())) {
            balance::join(
                dynamic_field::borrow_mut(&mut portfolio_vault.id, type_name::get<TOKEN>()),
                coin::into_balance(coin),
            );
        } else {
            dynamic_field::add(&mut portfolio_vault.id, type_name::get<TOKEN>(), coin::into_balance(coin));
        };
        let max_incentive_balance = balance::value<TOKEN>(dynamic_field::borrow(&portfolio_vault.id, type_name::get<TOKEN>()));
        utils::set_u64_padding_value(
            &mut portfolio_vault.config.u64_padding,
            I_CONFIG_FIXED_INCENTIVE_AMOUNT,
            if (fixed_incentive_amount < max_incentive_balance) { fixed_incentive_amount } else { max_incentive_balance },
        );

        amount
    }

    public(package) fun withdraw_fixed_incentive_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        amount: Option<u64>,
        ctx: &mut TxContext,
    ): Coin<TOKEN> {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        if (dynamic_field::exists_with_type<TypeName, Balance<TOKEN>>(&portfolio_vault.id, type_name::get<TOKEN>())) {
            let withdraw_balance = if (option::is_some(&amount)) {
                let amount = option::borrow(&amount);
                let incentive_balance = dynamic_field::borrow_mut(&mut portfolio_vault.id, type_name::get<TOKEN>());
                let withdraw_amount = if (*amount > balance::value(incentive_balance)) {
                    balance::value(incentive_balance)
                } else {
                    *amount
                };
                balance::split(incentive_balance, withdraw_amount)
            } else {
                let incentive_balance = dynamic_field::borrow_mut(&mut portfolio_vault.id, type_name::get<TOKEN>());
                let value = balance::value(incentive_balance);
                balance::split(incentive_balance, value)
            };
            coin::from_balance(withdraw_balance, ctx)
        } else {
            coin::zero<TOKEN>(ctx)
        }
    }

    public(package) fun set_available_incentive_amount_(
        registry: &mut Registry,
        index: u64,
        amount: u64,
    ): u64 {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let prev_amount = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT);
        utils::set_u64_padding_value(&mut portfolio_vault.config.u64_padding, I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT, amount);

        prev_amount
    }

    public(package) fun set_current_lending_protocol_flag_(
        registry: &mut Registry,
        index: u64,
        lending_protocol: u64,
    ) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        utils::set_u64_padding_value(&mut portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL, lending_protocol);
    }

    public(package) fun set_lending_protocol_flag_(
        registry: &mut Registry,
        index: u64,
        lending_protocol: u64,
    ) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        utils::set_u64_padding_value(&mut portfolio_vault.config.u64_padding, I_CONFIG_NEXT_LENDING_PROTOCOL, lending_protocol);
    }

    public(package) fun set_safu_vault_index_(
        registry: &mut Registry,
        index: u64,
        safu_index: u64,
    ) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        utils::set_u64_padding_value(&mut portfolio_vault.info.u64_padding, I_INFO_SAFU_VAULT_INDEX_ADD_ONE_UP, safu_index + 1);
    }

    public(package) fun set_enable_additional_lending_flag_(
        registry: &mut Registry,
        index: u64,
        enable: bool,
    ) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        if (enable) {
            utils::set_u64_padding_value(&mut portfolio_vault.config.u64_padding, I_CONFIG_ENABLE_ADDITIONAL_LENDING, 1);
        } else {
            utils::set_u64_padding_value(&mut portfolio_vault.config.u64_padding, I_CONFIG_ENABLE_ADDITIONAL_LENDING, 0);
        }
    }

    public(package) fun create_scallop_spool_account_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        spool: &mut Spool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (address, address) {
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let spool_account = scallop::new_spool_account<TOKEN>(
            spool,
            clock,
            ctx,
        );
        let spool_account_id = object::id_address(&spool_account);
        dynamic_field::add(&mut additional_config.id, K_SCALLOP_SPOOL_ACCOUNT, spool_account);

        (object::id_address(spool), spool_account_id)
    }

    public(package) fun deposit_scallop_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        version: &Version,
        market: &mut Market,
        spool: &mut Spool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        if (portfolio_vault.info.status == S_RECOUP) {
            return vector[portfolio_vault.info.round]
        };
        assert!(portfolio_vault.info.status != S_SETTLE, invalid_action(index));
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 1, scallop_disabled(index));
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        if (!dynamic_field::exists_(&additional_config.id, K_SCALLOP_SPOOL_ACCOUNT)) {
            let spool_account = scallop::new_spool_account<TOKEN>(
                spool,
                clock,
                ctx,
            );
            dynamic_field::add(&mut additional_config.id, K_SCALLOP_SPOOL_ACCOUNT, spool_account);
        };
        let spool_account = dynamic_field::borrow_mut(&mut additional_config.id, K_SCALLOP_SPOOL_ACCOUNT);
        let mut log = scallop::deposit<TOKEN>(
            deposit_vault,
            version,
            market,
            spool,
            spool_account,
            clock,
            ctx,
        );
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun withdraw_scallop_<D_TOKEN, R_TOKEN>(
        registry: &mut Registry,
        index: u64,
        version: &Version,
        market: &mut Market,
        spool: &mut Spool,
        rewards_pool: &mut RewardsPool<R_TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let incentive = dynamic_field::borrow_mut(&mut registry.id, type_name::get<D_TOKEN>());
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 1, scallop_disabled(index));
        utils::set_u64_padding_value(&mut portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL, 0);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let spool_account = dynamic_field::borrow_mut(&mut additional_config.id, K_SCALLOP_SPOOL_ACCOUNT);
        let additional_lending_flag = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_ENABLE_ADDITIONAL_LENDING);
        let mut log = scallop::withdraw<D_TOKEN, R_TOKEN>(
            &mut registry.fee_pool,
            deposit_vault,
            incentive,
            version,
            market,
            spool,
            rewards_pool,
            spool_account,
            additional_lending_flag != 1,
            clock,
            ctx,
        );
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun get_scallop_deposit_amount<TOKEN>(
        registry: &Registry,
        index: u64,
    ): u64 {
        let additional_config = get_additional_config(&registry.additional_config_registry, index);
        if (dynamic_field::exists_(&additional_config.id, K_SCALLOP_SPOOL_ACCOUNT)) {
            let spool_account = dynamic_field::borrow(&additional_config.id, K_SCALLOP_SPOOL_ACCOUNT);
            spool_account::stake_amount<MarketCoin<TOKEN>>(spool_account)
        } else {
            0
        }
    }

    public(package) fun get_mut_scallop_spool_account<TOKEN>(
        registry: &mut Registry,
        index: u64,
    ): &mut SpoolAccount<MarketCoin<TOKEN>> {
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        dynamic_field::borrow_mut(&mut additional_config.id, K_SCALLOP_SPOOL_ACCOUNT)
    }

    public(package) fun deposit_scallop_basic_lending_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        if (portfolio_vault.info.status == S_RECOUP) {
            return vector[portfolio_vault.info.round]
        };
        assert!(portfolio_vault.info.status != S_SETTLE, invalid_action(index));
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 2, scallop_basic_lending_disabled(index));
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);

        let (market_coin, mut log) = scallop::deposit_basic_lending<TOKEN>(
            deposit_vault,
            version,
            market,
            clock,
            ctx,
        );
        dynamic_field::add(&mut additional_config.id, K_SCALLOP_MARKET_COIN, market_coin);
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun withdraw_scallop_basic_lending_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        if (!dynamic_field::exists_(&registry.id, type_name::get<TOKEN>())) {
            dynamic_field::add(&mut registry.id, type_name::get<TOKEN>(), balance::zero<TOKEN>());
        };
        let incentive = dynamic_field::borrow_mut(&mut registry.id, type_name::get<TOKEN>());
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 2, scallop_basic_lending_disabled(index));
        utils::set_u64_padding_value(&mut portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL, 0);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let additional_lending_flag = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_ENABLE_ADDITIONAL_LENDING);
        if (dynamic_field::exists_(&additional_config.id, K_SCALLOP_MARKET_COIN)) {
            let market_coin = dynamic_field::remove(&mut additional_config.id, K_SCALLOP_MARKET_COIN);
            let mut log = scallop::withdraw_basic_lending_v2<TOKEN>(
                &mut registry.fee_pool,
                deposit_vault,
                incentive,
                version,
                market,
                market_coin,
                additional_lending_flag != 1,
                clock,
                ctx,
            );
            vector::push_back(&mut log, portfolio_vault.info.round);
            return log
        };

        vector::empty()
    }

    public(package) fun get_scallop_basic_lending_deposit_amount<TOKEN>(
        registry: &Registry,
        index: u64,
    ): u64 {
        let additional_config = get_additional_config(&registry.additional_config_registry, index);
        if (dynamic_field::exists_(&additional_config.id, K_SCALLOP_MARKET_COIN)) {
            let market_coin
                = dynamic_field::borrow<vector<u8>, Coin<MarketCoin<TOKEN>>>(&additional_config.id, K_SCALLOP_MARKET_COIN);
            coin::value(market_coin)
        } else {
            0
        }
    }

    public(package) fun create_suilend_obligation_owner_cap_(
        registry: &mut Registry,
        index: u64,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        ctx: &mut TxContext,
    ): (address, address) {
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let suilend_obligation_owner_cap = suilend::new_suilend_obligation_owner_cap(
            suilend_lending_market,
            ctx,
        );
        let suilend_obligation_owner_cap_id = object::id_address(&suilend_obligation_owner_cap);
        dynamic_field::add(&mut additional_config.id, K_SUILEND_OBLIGATION_OWNER_CAP, suilend_obligation_owner_cap);

        (object::id_address(suilend_lending_market), suilend_obligation_owner_cap_id)
    }

    public(package) fun deposit_suilend_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        if (portfolio_vault.info.status == S_RECOUP) {
            return vector[portfolio_vault.info.round]
        };
        assert!(portfolio_vault.info.status != S_SETTLE, invalid_action(index));
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 3, suilend_disabled(index));
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        if (!dynamic_field::exists_(&additional_config.id, K_SUILEND_OBLIGATION_OWNER_CAP)) {
            let suilend_obligation_owner_cap = suilend::new_suilend_obligation_owner_cap(
                suilend_lending_market,
                ctx,
            );
            dynamic_field::add(&mut additional_config.id, K_SUILEND_OBLIGATION_OWNER_CAP, suilend_obligation_owner_cap);
        };
        let suilend_obligation_owner_cap = dynamic_field::borrow_mut(&mut additional_config.id, K_SUILEND_OBLIGATION_OWNER_CAP);
        let mut log = suilend::deposit<TOKEN>(
            deposit_vault,
            suilend_lending_market,
            reserve_array_index,
            suilend_obligation_owner_cap,
            clock,
            ctx,
        );
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun withdraw_suilend_<D_TOKEN, R_TOKEN>(
        registry: &mut Registry,
        index: u64,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        reward_index: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let incentive = dynamic_field::borrow_mut(&mut registry.id, type_name::get<D_TOKEN>());
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 3, suilend_disabled(index));
        utils::set_u64_padding_value(&mut portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL, 0);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let suilend_obligation_owner_cap = dynamic_field::borrow_mut(&mut additional_config.id, K_SUILEND_OBLIGATION_OWNER_CAP);
        let additional_lending_flag = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_ENABLE_ADDITIONAL_LENDING);
        let mut log = if (reward_index.is_some()) {
            let reward_index = reward_index.destroy_some();
            suilend::withdraw<D_TOKEN, R_TOKEN>(
                &mut registry.fee_pool,
                deposit_vault,
                incentive,
                suilend_lending_market,
                reserve_array_index,
                reward_index,
                suilend_obligation_owner_cap,
                additional_lending_flag != 1,
                clock,
                ctx,
            )
        } else {
            suilend::withdraw_without_reward<D_TOKEN>(
                &mut registry.fee_pool,
                deposit_vault,
                incentive,
                suilend_lending_market,
                reserve_array_index,
                suilend_obligation_owner_cap,
                additional_lending_flag != 1,
                clock,
                ctx,
            )
        };
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun reward_suilend_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        reward_index: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 3, suilend_disabled(index));
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let suilend_obligation_owner_cap = dynamic_field::borrow_mut(&mut additional_config.id, K_SUILEND_OBLIGATION_OWNER_CAP);
        let additional_lending_flag = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_ENABLE_ADDITIONAL_LENDING);
        let mut log = suilend::reward<TOKEN>(
            &mut registry.fee_pool,
            deposit_vault,
            suilend_lending_market,
            reserve_array_index,
            reward_index,
            suilend_obligation_owner_cap,
            additional_lending_flag != 1,
            clock,
            ctx,
        );
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun create_navi_account_cap_(
        registry: &mut Registry,
        index: u64,
        ctx: &mut TxContext,
    ): address {
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let navi_account_cap = navi::new_navi_account_cap(ctx);
        let navi_account_cap_id = object::id_address(&navi_account_cap);
        dynamic_field::add(&mut additional_config.id, K_NAVI_ACCOUNT_CAP, navi_account_cap);

        navi_account_cap_id
    }

    public(package) fun deposit_navi_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        if (portfolio_vault.info.status == S_RECOUP) {
            return vector[portfolio_vault.info.round]
        };
        assert!(portfolio_vault.info.status != S_SETTLE, invalid_action(index));
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 4, navi_disabled(index));
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        if (!dynamic_field::exists_(&additional_config.id, K_NAVI_ACCOUNT_CAP)) {
            let navi_account_cap = navi::new_navi_account_cap(ctx);
            dynamic_field::add(&mut additional_config.id, K_NAVI_ACCOUNT_CAP, navi_account_cap);
        };
        let navi_account_cap = dynamic_field::borrow(&additional_config.id, K_NAVI_ACCOUNT_CAP);
        let (balance, mut log) = vault::withdraw_for_lending(deposit_vault);
        if (balance.value() == 0) {
            balance::destroy_zero(balance);
            return vector::empty()
        };
        log.push_back(balance.value());
        lending_core::incentive_v3::deposit_with_account_cap(
            clock,
            storage,
            pool,
            asset,
            coin::from_balance(balance, ctx),
            incentive_v2,
            incentive_v3,
            navi_account_cap,
        );
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun withdraw_navi_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        oracle_config: &mut OracleConfig,
        price_oracle: &mut PriceOracle,
        supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        pyth_price_info: &pyth::price_info::PriceInfoObject,
        feed_address: address,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
    ): vector<u64> {
        if (!dynamic_field::exists_(&registry.id, type_name::get<TOKEN>())) {
            dynamic_field::add(&mut registry.id, type_name::get<TOKEN>(), balance::zero<TOKEN>());
        };
        let incentive = dynamic_field::borrow_mut(&mut registry.id, type_name::get<TOKEN>());
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 4, navi_disabled(index));
        utils::set_u64_padding_value(&mut portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL, 0);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let navi_account_cap = dynamic_field::borrow_mut(&mut additional_config.id, K_NAVI_ACCOUNT_CAP);
        let additional_lending_flag = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_ENABLE_ADDITIONAL_LENDING);
        oracle_pro::update_single_price(
            clock,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
        );
        let amount = lending_core::pool::unnormal_amount(
            pool,
            (lending_core::logic::user_collateral_balance(
                storage,
                asset,
                lending_core::account::account_owner(navi_account_cap),
            ) as u64),
        );
        let balance = lending_core::incentive_v3::withdraw_with_account_cap(
            clock,
            price_oracle,
            storage,
            pool,
            asset,
            amount + 1,
            incentive_v2,
            incentive_v3,
            navi_account_cap,
        );
        let mut log = vault::deposit_from_lending(
            &mut registry.fee_pool,
            deposit_vault,
            incentive,
            balance,
            balance::zero<TOKEN>(),
            additional_lending_flag != 1,
        );
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun reward_navi_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        storage: &mut lending_core::storage::Storage,
        reward_fund: &mut lending_core::incentive_v3::RewardFund<TOKEN>,
        coin_types: vector<std::ascii::String>,
        rule_ids: vector<address>,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
    ): Balance<TOKEN> {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 4, navi_disabled(index));
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let navi_account_cap = dynamic_field::borrow_mut(&mut additional_config.id, K_NAVI_ACCOUNT_CAP);

        lending_core::incentive_v3::claim_reward_with_account_cap(
            clock,
            incentive_v3,
            storage,
            reward_fund,
            coin_types,
            rule_ids,
            navi_account_cap,
        )
    }

    public fun get_reward_navi_parameters(
        registry: &Registry,
        index: u64,
        storage: &mut lending_core::storage::Storage,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
    ): vector<lending_core::incentive_v3::ClaimableReward> {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 4, navi_disabled(index));
        let additional_config = get_additional_config(&registry.additional_config_registry, index);
        let navi_account_cap = dynamic_field::borrow(&additional_config.id, K_NAVI_ACCOUNT_CAP);

        lending_core::incentive_v3::get_user_claimable_rewards(
            clock,
            storage,
            incentive_v3,
            lending_core::account::account_owner(navi_account_cap),
        )
    }

    public(package) fun deposit_collateral_navi_<TOKEN>(
        registry: &mut Registry,
        collateral_index: u64,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        balance: Balance<TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, collateral_index);
        assert!(portfolio_vault.info.status != S_SETTLE, invalid_action(collateral_index));
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, collateral_index);
        if (!dynamic_field::exists_(&additional_config.id, K_NAVI_ACCOUNT_CAP)) {
            let navi_account_cap = navi::new_navi_account_cap(ctx);
            dynamic_field::add(&mut additional_config.id, K_NAVI_ACCOUNT_CAP, navi_account_cap);
        };
        if (balance.value() == 0) {
            balance::destroy_zero(balance);
            return vector::empty()
        };
        if (!dynamic_field::exists_(&additional_config.id, type_name::get<TOKEN>())) {
            dynamic_field::add(&mut additional_config.id, type_name::get<TOKEN>(), 0);
        };
        let balance_value = balance.value();
        let mut log = vector[balance_value];
        let navi_account_cap = dynamic_field::borrow(&additional_config.id, K_NAVI_ACCOUNT_CAP);
        lending_core::incentive_v3::deposit_with_account_cap(
            clock,
            storage,
            pool,
            asset,
            coin::from_balance(balance, ctx),
            incentive_v2,
            incentive_v3,
            navi_account_cap,
        );
        let extra_amount: &mut u64 = dynamic_field::borrow_mut(&mut additional_config.id, type_name::get<TOKEN>());
        *extra_amount = *extra_amount + balance_value;
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun withdraw_collateral_navi_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        oracle_config: &mut OracleConfig,
        price_oracle: &mut PriceOracle,
        supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        pyth_price_info: &pyth::price_info::PriceInfoObject,
        feed_address: address,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        amount: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        oracle_pro::update_single_price(
            clock,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
        );
        let amount = if (amount.is_none()) {
            dynamic_field::remove(&mut additional_config.id, type_name::get<TOKEN>())
        } else {
            let extra_amount: &mut u64 = dynamic_field::borrow_mut(&mut additional_config.id, type_name::get<TOKEN>());
            let amount = amount.destroy_some();
            let amount = if (amount > *extra_amount) {
                *extra_amount
            } else {
                amount
            };
            *extra_amount = *extra_amount - amount;
            amount
        };
        let navi_account_cap = dynamic_field::borrow_mut(&mut additional_config.id, K_NAVI_ACCOUNT_CAP);
        let balance = lending_core::incentive_v3::withdraw_with_account_cap(
            clock,
            price_oracle,
            storage,
            pool,
            asset,
            amount,
            incentive_v2,
            incentive_v3,
            navi_account_cap,
        );
        let mut log = vector[];
        log.push_back(balance.value());
        utils::transfer_balance(balance, ctx.sender(), ctx);
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun borrow_navi_<TOKEN>(
        registry: &mut Registry,
        collateral_index: u64,
        deposit_index: u64,
        oracle_config: &mut OracleConfig,
        price_oracle: &mut PriceOracle,
        supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        pyth_price_info: &pyth::price_info::PriceInfoObject,
        feed_address: address,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, collateral_index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 4, navi_disabled(collateral_index));
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, collateral_index);
        let receipts = if (dynamic_field::exists_(&additional_config.id, K_TYPUS_DEPOSIT_RECEIPT)) {
            vector[dynamic_field::remove(&mut additional_config.id, K_TYPUS_DEPOSIT_RECEIPT)]
        } else {
            vector[]
        };
        let navi_account_cap = dynamic_field::borrow_mut(&mut additional_config.id, K_NAVI_ACCOUNT_CAP);
        oracle_pro::update_single_price(
            clock,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
        );
        let balance = lending_core::incentive_v3::borrow_with_account_cap(
            clock,
            price_oracle,
            storage,
            pool,
            asset,
            amount,
            incentive_v2,
            incentive_v3,
            navi_account_cap,
        );
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, deposit_index);
        let (receipt, mut log) = vault::raise_fund<TOKEN>(
            &mut registry.fee_pool,
            deposit_vault,
            receipts,
            balance,
            false,
            false,
            ctx,
        );
        dynamic_field::add(&mut additional_config.id, K_TYPUS_DEPOSIT_RECEIPT, receipt);
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun unsubscribe_navi_<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry: &mut Registry,
        collateral_index: u64,
        deposit_index: u64,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, collateral_index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 4, navi_disabled(collateral_index));
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, collateral_index);
        let receipt = dynamic_field::remove(&mut additional_config.id, K_TYPUS_DEPOSIT_RECEIPT);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, deposit_index);
        let (receipt, d_balance, b_balance, i_balance, mut log) = vault::reduce_fund<D_TOKEN, B_TOKEN, I_TOKEN>(
            &mut registry.fee_pool,
            deposit_vault,
            vector[receipt],
            0,
            std::u64::max_value!(),
            false,
            false,
            false,
            ctx,
        );
        d_balance.destroy_zero();
        b_balance.destroy_zero();
        i_balance.destroy_zero();
        dynamic_field::add(&mut additional_config.id, K_TYPUS_DEPOSIT_RECEIPT, receipt.destroy_some());
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun repay_navi_<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry: &mut Registry,
        collateral_index: u64,
        deposit_index: u64,
        oracle_config: &mut OracleConfig,
        price_oracle: &mut PriceOracle,
        supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        pyth_price_info: &pyth::price_info::PriceInfoObject,
        feed_address: address,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<D_TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        balance: Balance<D_TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, collateral_index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 4, navi_disabled(collateral_index));
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, collateral_index);
        let receipt = dynamic_field::remove(&mut additional_config.id, K_TYPUS_DEPOSIT_RECEIPT);
        let navi_account_cap = dynamic_field::borrow_mut(&mut additional_config.id, K_NAVI_ACCOUNT_CAP);
        oracle_pro::update_single_price(
            clock,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
        );
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, deposit_index);
        let (receipt, mut d_balance, b_balance, i_balance, mut log) = vault::reduce_fund<D_TOKEN, B_TOKEN, I_TOKEN>(
            &mut registry.fee_pool,
            deposit_vault,
            vector[receipt],
            std::u64::max_value!(),
            0,
            true,
            true,
            false,
            ctx,
        );
        d_balance.join(balance);
        let balance = lending_core::incentive_v3::repay_with_account_cap(
            clock,
            price_oracle,
            storage,
            pool,
            asset,
            coin::from_balance(d_balance, ctx),
            incentive_v2,
            incentive_v3,
            navi_account_cap,
        );
        utils::transfer_balance(balance, ctx.sender(), ctx);
        utils::transfer_balance(b_balance, ctx.sender(), ctx);
        utils::transfer_balance(i_balance, ctx.sender(), ctx);
        receipt.destroy_none();
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun repay_navi_interest_<TOKEN, I_TOKEN>(
        registry: &mut Registry,
        collateral_index: u64,
        deposit_index: u64,
        oracle_config: &mut OracleConfig,
        price_oracle: &mut PriceOracle,
        supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        pyth_price_info: &pyth::price_info::PriceInfoObject,
        feed_address: address,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        warmup_amount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, collateral_index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 4, navi_disabled(collateral_index));
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, collateral_index);
        let receipt = dynamic_field::remove(&mut additional_config.id, K_TYPUS_DEPOSIT_RECEIPT);
        let navi_account_cap = dynamic_field::borrow_mut(&mut additional_config.id, K_NAVI_ACCOUNT_CAP);
        oracle_pro::update_single_price(
            clock,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
        );
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, deposit_index);
        let (receipt, mut d_balance, b_balance, i_balance, mut log) = vault::reduce_fund<TOKEN, TOKEN, I_TOKEN>(
            &mut registry.fee_pool,
            deposit_vault,
            vector[receipt],
            warmup_amount,
            0,
            true,
            true,
            false,
            ctx,
        );
        d_balance.join(b_balance);
        let balance = lending_core::incentive_v3::repay_with_account_cap(
            clock,
            price_oracle,
            storage,
            pool,
            asset,
            coin::from_balance(d_balance, ctx),
            incentive_v2,
            incentive_v3,
            navi_account_cap,
        );
        utils::transfer_balance(balance, ctx.sender(), ctx);
        i_balance.destroy_zero();
        dynamic_field::add(&mut additional_config.id, K_TYPUS_DEPOSIT_RECEIPT, receipt.destroy_some());
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun pre_repay_navi_interest_<D_TOKEN, B_TOKEN, I_TOKEN>(
        version: &TypusEcosystemVersion,
        registry: &mut Registry,
        collateral_index: u64,
        deposit_index: u64,
        ctx: &mut TxContext,
    ): (HotPotato<Balance<I_TOKEN>>, vector<u64>) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, collateral_index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 4, navi_disabled(collateral_index));
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, collateral_index);
        let receipt = dynamic_field::remove(&mut additional_config.id, K_TYPUS_DEPOSIT_RECEIPT);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, deposit_index);
        let (receipt, d_balance, b_balance, i_balance, mut log) = vault::reduce_fund<D_TOKEN, B_TOKEN, I_TOKEN>(
            &mut registry.fee_pool,
            deposit_vault,
            vector[receipt],
            0,
            0,
            false,
            false,
            true,
            ctx,
        );
        d_balance.destroy_zero();
        b_balance.destroy_zero();
        dynamic_field::add(&mut additional_config.id, K_TYPUS_DEPOSIT_RECEIPT, receipt.destroy_some());
        vector::push_back(&mut log, portfolio_vault.info.round);

        (witness_lock::wrap(version, i_balance, C_TYPUS_MOMENTUM_WITNESS.to_string()), log)
    }

    public(package) fun post_repay_navi_interest_<TOKEN>(
        version: &TypusEcosystemVersion,
        registry: &mut Registry,
        collateral_index: u64,
        oracle_config: &mut OracleConfig,
        price_oracle: &mut PriceOracle,
        supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        pyth_price_info: &pyth::price_info::PriceInfoObject,
        feed_address: address,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        balance: HotPotato<Balance<TOKEN>>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, collateral_index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 4, navi_disabled(collateral_index));
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, collateral_index);
        let navi_account_cap = dynamic_field::borrow_mut(&mut additional_config.id, K_NAVI_ACCOUNT_CAP);
        oracle_pro::update_single_price(
            clock,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
        );
        let balance = witness_lock::unwrap(version, balance, WITNESS {});
        let mut log = vector[balance.value()];
        let balance = lending_core::incentive_v3::repay_with_account_cap(
            clock,
            price_oracle,
            storage,
            pool,
            asset,
            coin::from_balance(balance, ctx),
            incentive_v2,
            incentive_v3,
            navi_account_cap,
        );
        utils::transfer_balance(balance, ctx.sender(), ctx);
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    // lending helper functions
    fun lending_cap_key(index: u64, lending_index: u64): vector<u8> {
        if (lending_index == 5) {
            K_ALPHALEND_ACCOUNT_CAP
        } else if (lending_index == 4) {
            K_NAVI_ACCOUNT_CAP
        } else if (lending_index == 3) {
            K_SUILEND_OBLIGATION_OWNER_CAP
        } else if (lending_index == 1) {
            K_SCALLOP_SPOOL_ACCOUNT
        } else {
            abort invalid_lending_index(index)
        }
    }

    public(package) fun add_lending_account_cap_<CAP: key + store>(
        registry: &mut Registry,
        index: u64,
        lending_index: u64,
        account_cap: CAP,
    ): address {
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let account_cap_id = object::id_address(&account_cap);
        dynamic_field::add(&mut additional_config.id, lending_cap_key(index, lending_index), account_cap);
        account_cap_id
    }

    // hot potato
    public struct LendingCapHotPotato {
        index: u64,
        lending_index: u64,
        account_cap_id: address,
    }

    public(package) fun borrow_lending_account_cap_<CAP: key + store>(
        registry: &mut Registry,
        index: u64,
        lending_index: u64,
    ): (CAP, LendingCapHotPotato) {
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        let account_cap = dynamic_field::remove(&mut additional_config.id, lending_cap_key(index, lending_index));
        let account_cap_id = object::id_address(&account_cap);
        let lending_cap_hot_potato = LendingCapHotPotato {
            index,
            lending_index,
            account_cap_id,
        };
        (account_cap, lending_cap_hot_potato)
    }

    public(package) fun return_lending_account_cap_<CAP: key + store>(
        registry: &mut Registry,
        account_cap: CAP,
        lending_cap_hot_potato: LendingCapHotPotato,
    ) {
        let LendingCapHotPotato {
            index,
            lending_index,
            account_cap_id,
        } = lending_cap_hot_potato;
        assert!(account_cap_id == object::id_address(&account_cap));
        let additional_config = get_mut_additional_config(&mut registry.additional_config_registry, index);
        dynamic_field::add(&mut additional_config.id, lending_cap_key(index, lending_index), account_cap);
    }

    // TODO: use these two functions to replace the similar parts in navi and scallop functions
    public(package) fun withdraw_for_lending_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        lending_index: u64,
    ): (Balance<TOKEN>, vector<u64>) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        assert!(portfolio_vault.info.status == S_NEW_AUCTION
         || portfolio_vault.info.status == S_DELIVERY, invalid_action(index));
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == lending_index, navi_disabled(index));
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let (balance, mut log) = vault::withdraw_for_lending(deposit_vault);
        log.push_back(balance.value());
        vector::push_back(&mut log, portfolio_vault.info.round);
        (balance, log)
    }

    public(package) fun deposit_from_lending_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        lending_index: u64,
        d_balance: Balance<TOKEN>,
        r_balance: Balance<TOKEN>,
    ): vector<u64> {
        let incentive = dynamic_field::borrow_mut(&mut registry.id, type_name::get<TOKEN>());
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == lending_index, navi_disabled(index));
        utils::set_u64_padding_value(&mut portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL, 0);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_lending_flag = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_ENABLE_ADDITIONAL_LENDING);
        let mut log = vault::deposit_from_lending(
            &mut registry.fee_pool,
            deposit_vault,
            incentive,
            d_balance,
            r_balance,
            additional_lending_flag != 1,
        );
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun reward_from_lending_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        rewards: vector<Balance<TOKEN>>,
    ): vector<u64> {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let additional_lending_flag = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_ENABLE_ADDITIONAL_LENDING);
        let mut reward = balance::zero();
        rewards.do!(|v| reward.join(v));
        let mut log = vault::reward_from_lending(
            &mut registry.fee_pool,
            deposit_vault,
            reward,
            additional_lending_flag != 1,
        );
        vector::push_back(&mut log, portfolio_vault.info.round);

        log
    }

    public(package) fun add_accumulated_tgld_amount(
        id: &UID,
        version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        tgld_registry: &mut TgldRegistry,
        user: address,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        if (dynamic_field::exists_(id, K_ENABLE_TGLD)) {
            user::add_accumulated_tgld_amount(
                dynamic_field::borrow(id, K_TYPUS_ECOSYSTEM),
                version,
                typus_user_registry,
                tgld_registry,
                user,
                amount,
                ctx,
            );
        }
    }

    public(package) fun add_leaderboard_score(
        id: &UID,
        version: &TypusEcosystemVersion,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        key: std::ascii::String,
        user: address,
        score: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        leaderboard::score(
            dynamic_field::borrow(id, K_TYPUS_ECOSYSTEM),
            version,
            typus_leaderboard_registry,
            key,
            user,
            score,
            clock,
            ctx,
        );
    }

    public(package) fun get_deposit_snapshot_bcs(
        id: &UID,
        user: address,
    ): vector<u8> {
        let deposit_snapshots = get_additional_config_by_key(id, K_DEPOSIT_SNAPSHOTS);
        if (dynamic_field::exists_(&deposit_snapshots.id, user)) {
            let deposit_snapshot: &DepositSnapshot = dynamic_field::borrow(&deposit_snapshots.id, user);

            bcs::to_bytes(deposit_snapshot)
        }
        else {
            let deposit_snapshot = DepositSnapshot {
                snapshots: vector[],
                total_deposit: 0,
                snapshot_ts_ms: 0,
            };
            let result = bcs::to_bytes(&deposit_snapshot);
            let DepositSnapshot {
                snapshots: _,
                total_deposit: _,
                snapshot_ts_ms: _,
            } = deposit_snapshot;

            result
        }
    }

    public(package) fun update_deposit_snapshot(
        version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        registry: &mut Registry,
        index: u64,
        user: address,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        calculate_deposit_point(
            version,
            typus_user_registry,
            typus_leaderboard_registry,
            registry,
            user,
            clock,
            ctx,
        );
        let deposit_snapshots = get_mut_additional_config_by_key(&mut registry.additional_config_registry, K_DEPOSIT_SNAPSHOTS);
        let deposit_snapshot: &mut DepositSnapshot = dynamic_field::borrow_mut(&mut deposit_snapshots.id, user);
        let snapshot = utils::get_u64_padding_value(&deposit_snapshot.snapshots, index);
        deposit_snapshot.total_deposit = deposit_snapshot.total_deposit - snapshot + amount;
        utils::set_u64_padding_value(&mut deposit_snapshot.snapshots, index, amount);
    }

    public(package) fun calculate_deposit_point(
        version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        registry: &mut Registry,
        user: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let current_ts_ms = clock::timestamp_ms(clock);
        let deposit_snapshots = get_mut_additional_config_by_key(&mut registry.additional_config_registry, K_DEPOSIT_SNAPSHOTS);
        if (!dynamic_field::exists_(&deposit_snapshots.id, user)) {
            dynamic_field::add(
                &mut deposit_snapshots.id,
                user,
                DepositSnapshot {
                    snapshots: vector[],
                    total_deposit: 0,
                    snapshot_ts_ms: current_ts_ms,
                }
            );
        };
        let deposit_snapshot: &mut DepositSnapshot = dynamic_field::borrow_mut(&mut deposit_snapshots.id, user);
        let amount = calculate_snapshot_exp_amount(
            deposit_snapshot,
            clock,
        );
        deposit_snapshot.snapshot_ts_ms = current_ts_ms;
        add_leaderboard_score(
            &registry.id,
            version,
            typus_leaderboard_registry,
            std::ascii::string(b"depositor_program"),
            user,
            amount * 15 / 10,
            clock,
            ctx,
        );
        add_user_tails_exp_amount(
            &registry.id,
            version,
            typus_user_registry,
            user,
            amount,
        );
    }

    public(package) fun update_deposit_point(
        version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        registry: &mut Registry,
        users: vector<address>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let current_ts_ms = clock::timestamp_ms(clock);
        let deposit_snapshots = get_mut_additional_config_by_key(&mut registry.additional_config_registry, K_DEPOSIT_SNAPSHOTS);
        vector::do!(users, |user| {
            let deposit_snapshot: &mut DepositSnapshot = dynamic_field::borrow_mut(&mut deposit_snapshots.id, user);
            let amount = calculate_snapshot_exp_amount(
                deposit_snapshot,
                clock,
            );
            deposit_snapshot.snapshot_ts_ms = current_ts_ms;
            add_leaderboard_score(
                &registry.id,
                version,
                typus_leaderboard_registry,
                std::ascii::string(b"depositor_program"),
                user,
                amount * 15 / 10,
                clock,
                ctx,
            );
            add_user_tails_exp_amount(
                &registry.id,
                version,
                typus_user_registry,
                user,
                amount,
            );
        });
    }

    public(package) fun calculate_snapshot_exp_amount(
        deposit_snapshot: &DepositSnapshot,
        clock: &Clock,
    ): u64 {
        let current_ts_ms = clock::timestamp_ms(clock);
        let minutes = (current_ts_ms - deposit_snapshot.snapshot_ts_ms) / 60_000;

        ((deposit_snapshot.total_deposit as u128) * (minutes as u128) / (12000 as u128) as u64)
    }

    public(package) fun add_user_tails_exp_amount(
        id: &UID,
        version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        user: address,
        amount: u64,
    ) {
        user::add_tails_exp_amount(
            dynamic_field::borrow(id, K_TYPUS_ECOSYSTEM),
            version,
            typus_user_registry,
            user,
            amount
        );
    }

    public(package) fun remove_tails_exp_amount(
        id: &UID,
        version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        user: address,
        amount: u64,
    ) {
        user::remove_tails_exp_amount(
            dynamic_field::borrow(id, K_TYPUS_ECOSYSTEM),
            version,
            typus_user_registry,
            user,
            amount
        );
    }

    public(package) fun new_portfolio_vault_<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        option_type: u64,
        period: u8,
        d_token_decimal: u64,
        b_token_decimal: u64,
        o_token_decimal: u64,
        activation_ts_ms: u64,
        expiration_ts_ms: u64,
        oracle: &Oracle,
        deposit_lot_size: u64,
        bid_lot_size: u64,
        min_deposit_size: u64,
        min_bid_size: u64,
        max_deposit_entry: u64,
        max_bid_entry: u64,
        deposit_fee_bp: u64,
        bid_fee_bp: u64,
        deposit_incentive_bp: u64,
        bid_incentive_bp: u64,
        auction_delay_ts_ms: u64,
        auction_duration_ts_ms: u64,
        recoup_delay_ts_ms: u64,
        capacity: u64,
        leverage: u64,
        risk_level: u64,
        has_next: bool,
        payoff_configs: vector<PayoffConfig>,
        strike_increment: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
        whitelist: vector<address>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, Info, Config) {
        // safety check
        let index = registry.num_of_vault;
        let current_ts_ms = clock::timestamp_ms(clock);
        assert!(activation_ts_ms >= current_ts_ms, invalid_activation_time(index));
        assert!(expiration_ts_ms > activation_ts_ms, invalid_expiration_time(index));
        validate_dutch_auction_settings(
            index,
            initial_price,
            final_price,
            auction_duration_ts_ms,
        );
        if (period == 0) {
            assert!(expiration_ts_ms - activation_ts_ms == 86400_000, invalid_expiration_time(index));
        } else if (period == 1) {
            assert!(expiration_ts_ms - activation_ts_ms == 604800_000, invalid_expiration_time(index));
        } else if (period == 2) {
            assert!((expiration_ts_ms - activation_ts_ms == 4 * 604800_000) ||
                    (expiration_ts_ms - activation_ts_ms == 5 * 604800_000), invalid_expiration_time(index));
        } else if (period == 3) {
            assert!(expiration_ts_ms - activation_ts_ms == 3600_000, invalid_expiration_time(index));
        } else if (period == 4) {
            assert!(expiration_ts_ms - activation_ts_ms == 600_000, invalid_expiration_time(index));
        } else {
            abort invalid_period(index)
        };
        assert!(deposit_lot_size > 0, invalid_deposit_lot_size(index));
        assert!(min_deposit_size >= deposit_lot_size, invalid_min_deposit_size(index));
        assert!(bid_lot_size > 0, invalid_bid_lot_size(index));
        assert!(min_bid_size >= bid_lot_size, invalid_min_bid_size(index));

        // main logic
        let (oracle_price, oracle_price_decimal) = oracle::get_price(oracle, clock);
        let (settlement_base_name, settlement_quote_name, settlement_base, settlement_quote) = oracle::get_token(oracle);
        let vault_config = VaultConfig {
            payoff_configs,
            strike_increment,
            decay_speed,
            initial_price,
            final_price,
            u64_padding: vector::empty(),
        };
        let info = Info {
            index,
            option_type,
            period,
            activation_ts_ms,
            expiration_ts_ms,
            deposit_token: type_name::get<D_TOKEN>(),
            bid_token: type_name::get<B_TOKEN>(),
            settlement_base,
            settlement_quote,
            settlement_base_name: string::from_ascii(settlement_base_name),
            settlement_quote_name: string::from_ascii(settlement_quote_name),
            d_token_decimal,
            b_token_decimal,
            o_token_decimal,
            creator: tx_context::sender(ctx),
            create_ts_ms: current_ts_ms,
            round: 0,
            status: 0,
            oracle_info: OracleInfo {
                price: oracle_price,
                decimal: oracle_price_decimal,
            },
            delivery_infos: DeliveryInfos {
                round: 0,
                max_size: 0,
                total_delivery_size: 0,
                total_bidder_bid_value: 0,
                total_bidder_fee: 0,
                total_incentive_bid_value: 0,
                total_incentive_fee: 0,
                delivery_info: vector::empty(),
                u64_padding: vector::empty(),
            },
            settlement_info: option::none(),
            u64_padding: vector::empty(),
            bcs_padding: vector::empty(),
        };
        let config = Config {
            oracle_id: object::id_address(oracle),
            deposit_lot_size,
            bid_lot_size,
            min_deposit_size,
            min_bid_size,
            max_deposit_entry,
            max_bid_entry,
            deposit_fee_bp,
            deposit_fee_share_bp: 0,
            deposit_shared_fee_pool: option::none(),
            bid_fee_bp,
            deposit_incentive_bp,
            bid_incentive_bp,
            auction_delay_ts_ms,
            auction_duration_ts_ms,
            recoup_delay_ts_ms,
            capacity,
            leverage,
            risk_level,
            has_next,
            active_vault_config: vault_config,
            warmup_vault_config: vault_config,
            u64_padding: vector::empty(),
            bcs_padding: vector::empty(),
        };

        dynamic_object_field::add(
            &mut registry.portfolio_vault_registry,
            index,
            PortfolioVault {
                id: object::new(ctx),
                info,
                config,
                authority: authority::new(whitelist, ctx),
            }
        );
        let mut deposit_vault_metadata = string::from_ascii(settlement_base_name);
        if (period == 0) {
            string::append_utf8(&mut deposit_vault_metadata, b"-Daily");
        } else if (period == 1) {
            string::append_utf8(&mut deposit_vault_metadata, b"-Weekly");
        } else if (period == 2) {
            string::append_utf8(&mut deposit_vault_metadata, b"-Monthly");
        } else if (period == 3) {
            string::append_utf8(&mut deposit_vault_metadata, b"-Hourly");
        } else if (period == 4) {
            string::append_utf8(&mut deposit_vault_metadata, b"-10 Minutely");
        };
        if (option_type == 0) {
            string::append_utf8(&mut deposit_vault_metadata, b"-Call");
        } else if (option_type == 1) {
            string::append_utf8(&mut deposit_vault_metadata, b"-Put");
        } else if (option_type == 2) {
            string::append_utf8(&mut deposit_vault_metadata, b"-CallSpread");
        } else if (option_type == 3) {
            string::append_utf8(&mut deposit_vault_metadata, b"-PutSpread");
        } else if (option_type == 4) {
            string::append_utf8(&mut deposit_vault_metadata, b"-CappedCall");
        } else if (option_type == 5) {
            string::append_utf8(&mut deposit_vault_metadata, b"-CappedPut");
        } else if (option_type == 6) {
            if (std::ascii::into_bytes(settlement_quote_name) == b"USDT") {
                string::append_utf8(&mut deposit_vault_metadata, b"-UsdtCappedCall");
            } else if (std::ascii::into_bytes(settlement_quote_name) == b"USDC"){
                string::append_utf8(&mut deposit_vault_metadata, b"-UsdcCappedCall");
            } else {
                string::append_utf8(&mut deposit_vault_metadata, b"-UsdCappedCall");
            }
        };
        dynamic_object_field::add(
            &mut registry.deposit_vault_registry,
            index,
            vault::new_deposit_vault<D_TOKEN, B_TOKEN>(
                index,
                deposit_fee_bp,
                deposit_vault_metadata,
                ctx,
            ),
        );
        dynamic_object_field::add(
            &mut registry.additional_config_registry,
            index,
            AdditionalConfig {
                id: object::new(ctx),
            },
        );
        if (!dynamic_object_field::exists_with_type<TypeName, RefundVault>(
            &registry.refund_vault_registry,
            type_name::get<B_TOKEN>(),
        )) {
            dynamic_object_field::add(
                &mut registry.refund_vault_registry,
                type_name::get<B_TOKEN>(),
                vault::new_refund_vault<B_TOKEN>(
                    ctx,
                ),
            );
        };
        registry.num_of_vault = registry.num_of_vault + 1;

        (index, info, config)
    }

    entry fun create_additional_configs(registry: &mut Registry, ctx: &mut TxContext) {
        let mut index = 0;
        while (index < registry.num_of_vault) {
            if (portfolio_vault_exists(&registry.portfolio_vault_registry, index)) {
                if (!dynamic_object_field::exists_with_type<u64, AdditionalConfig>(
                    &registry.additional_config_registry,
                    index,
                )) {
                    dynamic_object_field::add(
                        &mut registry.additional_config_registry,
                        index,
                        AdditionalConfig {
                            id: object::new(ctx),
                        },
                    );
                }
            };
            index = index + 1;
        }
    }

    // ======== Authorized Friend Functions =========

    public(package) fun update_oracle_(
        registry: &mut Registry,
        index: u64,
        oracle: &Oracle,
    ) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);

        let oracle_id = object::id_address(oracle);
        portfolio_vault.config.oracle_id = oracle_id;

        let (_settlement_base_name, settlement_quote_name, settlement_base, settlement_quote) = oracle::get_token(oracle);
        assert!(settlement_base == portfolio_vault.info.settlement_base, 0);
        portfolio_vault.info.settlement_quote = settlement_quote;
        portfolio_vault.info.settlement_quote_name = string::from_ascii(settlement_quote_name);
    }

    public(package) fun update_config_(
        registry: &mut Registry,
        index: u64,
        oracle_id: Option<address>,
        deposit_lot_size: Option<u64>,
        bid_lot_size: Option<u64>,
        min_deposit_size: Option<u64>,
        min_bid_size: Option<u64>,
        max_deposit_entry: Option<u64>,
        max_bid_entry: Option<u64>,
        deposit_fee_bp: Option<u64>,
        deposit_fee_share_bp: Option<u64>,
        deposit_shared_fee_pool: Option<Option<vector<u8>>>,
        bid_fee_bp: Option<u64>,
        deposit_incentive_bp: Option<u64>,
        bid_incentive_bp: Option<u64>,
        auction_delay_ts_ms: Option<u64>,
        auction_duration_ts_ms: Option<u64>,
        recoup_delay_ts_ms: Option<u64>,
        capacity: Option<u64>,
        leverage: Option<u64>,
        risk_level: Option<u64>,
        deposit_incentive_bp_divisor_decimal: Option<u64>,
        incentive_fee_bp: Option<u64>,
        ctx: &TxContext,
    ): (Config, Config) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);

        let previous = portfolio_vault.config;
        if (option::is_some(&deposit_fee_bp)) {
            vault::update_fee(deposit_vault, option::destroy_some(deposit_fee_bp), ctx);
        };
        if (option::is_some(&incentive_fee_bp)) {
            let incentive_fee_bp = option::destroy_some(incentive_fee_bp);
            vault::update_incentive_fee(deposit_vault, incentive_fee_bp);
            utils::set_u64_padding_value(
                &mut portfolio_vault.config.u64_padding,
                I_CONFIG_INCENTIVE_FEE_FLAGGED,
                incentive_fee_bp + (1 << 63),
            );
        };
        // TODO: update_fee_share
        if (option::is_some(&deposit_fee_share_bp)) {
            abort invalid_fee_share_setting(index)
        };
        if (option::is_some(&oracle_id)) {
            portfolio_vault.config.oracle_id = option::destroy_some(oracle_id);
        };
        if (option::is_some(&deposit_lot_size)) {
            portfolio_vault.config.deposit_lot_size = option::destroy_some(deposit_lot_size);
        };
        if (option::is_some(&bid_lot_size)) {
            portfolio_vault.config.bid_lot_size = option::destroy_some(bid_lot_size);
        };
        if (option::is_some(&min_deposit_size)) {
            portfolio_vault.config.min_deposit_size = option::destroy_some(min_deposit_size);
        };
        if (option::is_some(&min_bid_size)) {
            portfolio_vault.config.min_bid_size = option::destroy_some(min_bid_size);
        };
        if (option::is_some(&max_deposit_entry)) {
            portfolio_vault.config.max_deposit_entry = option::destroy_some(max_deposit_entry);
        };
        if (option::is_some(&max_bid_entry)) {
            portfolio_vault.config.max_bid_entry = option::destroy_some(max_bid_entry);
        };
        if (option::is_some(&deposit_fee_bp)) {
            portfolio_vault.config.deposit_fee_bp = option::destroy_some(deposit_fee_bp);
        };
        if (option::is_some(&deposit_fee_share_bp)) {
            portfolio_vault.config.deposit_fee_share_bp = option::destroy_some(deposit_fee_share_bp);
        };
        if (option::is_some(&deposit_shared_fee_pool)) {
            portfolio_vault.config.deposit_shared_fee_pool = option::destroy_some(deposit_shared_fee_pool);
        };
        if (option::is_some(&bid_fee_bp)) {
            portfolio_vault.config.bid_fee_bp = option::destroy_some(bid_fee_bp);
        };
        if (option::is_some(&deposit_incentive_bp)) {
            portfolio_vault.config.deposit_incentive_bp = option::destroy_some(deposit_incentive_bp);
        };
        if (option::is_some(&bid_incentive_bp)) {
            portfolio_vault.config.bid_incentive_bp = option::destroy_some(bid_incentive_bp);
        };
        if (option::is_some(&auction_delay_ts_ms)) {
            portfolio_vault.config.auction_delay_ts_ms = option::destroy_some(auction_delay_ts_ms);
        };
        if (option::is_some(&auction_duration_ts_ms)) {
            portfolio_vault.config.auction_duration_ts_ms = option::destroy_some(auction_duration_ts_ms);
        };
        if (option::is_some(&recoup_delay_ts_ms)) {
            portfolio_vault.config.recoup_delay_ts_ms = option::destroy_some(recoup_delay_ts_ms);
        };
        if (option::is_some(&capacity)) {
            portfolio_vault.config.capacity = option::destroy_some(capacity);
        };
        if (option::is_some(&leverage)) {
            portfolio_vault.config.leverage = option::destroy_some(leverage);
        };
        if (option::is_some(&risk_level)) {
            portfolio_vault.config.risk_level = option::destroy_some(risk_level);
        };
        if (option::is_some(&deposit_incentive_bp_divisor_decimal)) {
            utils::set_u64_padding_value(
                &mut portfolio_vault.config.u64_padding,
                I_CONFIG_DEPOSIT_INCENTIVE_BP_DIVISOR_DECIMAL,
                option::destroy_some(deposit_incentive_bp_divisor_decimal),
            );
        };

        (previous, portfolio_vault.config)
    }

    public(package) fun update_warmup_vault_config_(
        registry: &mut Registry,
        index: u64,
        strike_pct: vector<u64>,
        weight: vector<u64>,
        is_buyer: vector<bool>,
        strike_increment: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
    ): (VaultConfig, VaultConfig) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        validate_dutch_auction_settings(index, initial_price, final_price, portfolio_vault.config.auction_duration_ts_ms);
        let previous = portfolio_vault.config.warmup_vault_config;
        portfolio_vault.config.warmup_vault_config.payoff_configs = create_payoff_configs(index, strike_pct, weight, is_buyer);
        portfolio_vault.config.warmup_vault_config.strike_increment = strike_increment;
        portfolio_vault.config.warmup_vault_config.decay_speed = decay_speed;
        portfolio_vault.config.warmup_vault_config.initial_price = initial_price;
        portfolio_vault.config.warmup_vault_config.final_price = final_price;

        (previous, portfolio_vault.config.warmup_vault_config)
    }

    public(package) fun update_strike_(
        registry: &mut Registry,
        index: u64,
        oracle: &Oracle,
        clock: &Clock,
    ): (u64, u64, VaultConfig) {
        let (oracle_price, oracle_price_decimal) = oracle::get_price(oracle, clock);
        let (_, settlement_quote_name, _, _) = oracle::get_token(oracle);
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let mut strikes = vector::empty();
        let strike_increment = portfolio_vault.config.active_vault_config.strike_increment;
        if (portfolio_vault.info.option_type == 0 || portfolio_vault.info.option_type == 1) {
            let payoff_config = vector::borrow_mut(
                &mut portfolio_vault.config.active_vault_config.payoff_configs,
                0,
            );
            let mut strike = calculate_strike(oracle_price, payoff_config.strike_bp, strike_increment);
            strike = if (portfolio_vault.info.option_type % 2 == 1 && strike > strike_increment) {
                strike - strike_increment
            } else { strike };
            option::swap(&mut payoff_config.strike, strike);
            vector::push_back(&mut strikes, strike);
        } else if (portfolio_vault.info.option_type == 2 || portfolio_vault.info.option_type == 4 || portfolio_vault.info.option_type == 6) {
            let k1_payoff_config = vector::borrow_mut(
                &mut portfolio_vault.config.active_vault_config.payoff_configs,
                1,
            );
            let original_k1 = option::destroy_some(k1_payoff_config.strike);
            let k1 = calculate_strike(oracle_price, k1_payoff_config.strike_bp, strike_increment);
            option::swap(&mut k1_payoff_config.strike, k1);
            vector::push_back(&mut strikes, k1);
            let k2_payoff_config = vector::borrow_mut(
                &mut portfolio_vault.config.active_vault_config.payoff_configs,
                0,
            );
            let original_k2 = option::destroy_some(k2_payoff_config.strike);
            let k2 = k1 + (original_k2 - original_k1);
            option::swap(&mut k2_payoff_config.strike, k2);
            vector::push_back(&mut strikes, k2);
        } else if (portfolio_vault.info.option_type == 3 || portfolio_vault.info.option_type == 5) {
            let k1_payoff_config = vector::borrow_mut(
                &mut portfolio_vault.config.active_vault_config.payoff_configs,
                0,
            );
            let original_k1 = option::destroy_some(k1_payoff_config.strike);
            let mut k1 = calculate_strike(oracle_price, k1_payoff_config.strike_bp, strike_increment);
            k1 = if (k1 > strike_increment) {
                k1 - strike_increment
            } else { k1 };
            option::swap(&mut k1_payoff_config.strike, k1);
            vector::push_back(&mut strikes, k1);
            let k2_payoff_config = vector::borrow_mut(
                &mut portfolio_vault.config.active_vault_config.payoff_configs,
                1,
            );
            let original_k2 = option::destroy_some(k2_payoff_config.strike);
            let k2 = k1 - (original_k1 - original_k2);
            option::swap(&mut k2_payoff_config.strike, k2);
            vector::push_back(&mut strikes, k2);
        } else {
            let mut payoff_configs_length = vector::length(&portfolio_vault.config.active_vault_config.payoff_configs);
            while (payoff_configs_length > 0) {
                let payoff_config = vector::borrow_mut(
                    &mut portfolio_vault.config.active_vault_config.payoff_configs,
                    payoff_configs_length - 1,
                );
                let mut strike = calculate_strike(oracle_price, payoff_config.strike_bp, strike_increment);
                strike = if (portfolio_vault.info.option_type % 2 == 1 && strike > strike_increment) {
                    strike - strike_increment
                } else { strike };
                option::swap(&mut payoff_config.strike, strike);
                vector::push_back(&mut strikes, strike);
                payoff_configs_length = payoff_configs_length - 1;
            };
        };
        if (portfolio_vault.info.period == 3 || portfolio_vault.info.period == 4) {
            let bid_vault = get_mut_bid_vault(&mut registry.bid_vault_registry, index);
            let mut bid_vault_metadata = portfolio_vault.info.settlement_base_name;
            let (y, m, d) = utils::get_date_from_ts(portfolio_vault.info.expiration_ts_ms / 1000);
            string::append_utf8(&mut bid_vault_metadata, b"-");
            string::append_utf8(&mut bid_vault_metadata, utils::get_pad_2_number_string(d));
            string::append_utf8(&mut bid_vault_metadata, utils::get_month_short_string(m));
            string::append_utf8(&mut bid_vault_metadata, utils::get_pad_2_number_string(y));
            string::append_utf8(&mut bid_vault_metadata, b"-");
            string::append_utf8(&mut bid_vault_metadata, utils::get_pad_2_number_string(portfolio_vault.info.expiration_ts_ms % 86400000 / 3600000));
            string::append_utf8(&mut bid_vault_metadata, utils::get_pad_2_number_string(portfolio_vault.info.expiration_ts_ms % 3600000 / 60000));
            vector::reverse(&mut strikes);
            while (!vector::is_empty(&strikes)) {
                let strike = vector::pop_back(&mut strikes);
                string::append_utf8(&mut bid_vault_metadata, b"-");
                string::append_utf8(&mut bid_vault_metadata, utils::u64_to_bytes(strike, oracle_price_decimal));
            };
            if (portfolio_vault.info.option_type == 0) {
                string::append_utf8(&mut bid_vault_metadata, b"-Call");
            } else if (portfolio_vault.info.option_type == 1) {
                string::append_utf8(&mut bid_vault_metadata, b"-Put");
            } else if (portfolio_vault.info.option_type == 2) {
                string::append_utf8(&mut bid_vault_metadata, b"-CallSpread");
            } else if (portfolio_vault.info.option_type == 3) {
                string::append_utf8(&mut bid_vault_metadata, b"-PutSpread");
            } else if (portfolio_vault.info.option_type == 4) {
                string::append_utf8(&mut bid_vault_metadata, b"-CappedCall");
            } else if (portfolio_vault.info.option_type == 5) {
                string::append_utf8(&mut bid_vault_metadata, b"-CappedPut");
            } else if (portfolio_vault.info.option_type == 6) {
                if (std::ascii::into_bytes(settlement_quote_name) == b"USDT") {
                    string::append_utf8(&mut bid_vault_metadata, b"-UsdtCappedCall");
                } else if (std::ascii::into_bytes(settlement_quote_name) == b"USDC") {
                    string::append_utf8(&mut bid_vault_metadata, b"-UsdcCappedCall");
                } else {
                    string::append_utf8(&mut bid_vault_metadata, b"-UsdCappedCall");
                }
            };
            vault::update_bid_receipt_display(bid_vault, bid_vault_metadata);
        };
        let mut active_vault_config = portfolio_vault.config.active_vault_config;
        utils::set_u64_padding_value(&mut active_vault_config.u64_padding, I_ACTIVE_VAULT_CONFIG_ROUND, portfolio_vault.info.round);

        (oracle_price, oracle_price_decimal, active_vault_config)
    }

    public(package) fun update_auction_config_(
        registry: &mut Registry,
        index: u64,
        start_ts_ms: u64,
        end_ts_ms: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
        fee_bp: u64,
        incentive_bp: u64,
        token_decimal: u64, // bid token
        size_decimal: u64, // deposit token / contract size
        able_to_remove_bid: bool,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let auction = get_mut_auction(&mut registry.auction_registry, index);
        dutch::update_auction_config(
            auction,
            start_ts_ms,
            end_ts_ms,
            decay_speed,
            initial_price,
            final_price,
            fee_bp,
            incentive_bp,
            token_decimal,
            size_decimal,
            able_to_remove_bid,
            clock,
            ctx,
        );
    }

    public(package) fun activate_<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry: &mut Registry,
        index: u64,
        oracle: &Oracle,
        d_token_price_oracle: &Oracle,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, u64, u64, u64, u64) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);

        // safety check
        assert!(clock::timestamp_ms(clock) >= portfolio_vault.info.activation_ts_ms, not_yet_activated(index));
        assert!(portfolio_vault.info.status % 5 == 0, invalid_action(index));

        // main logic
        let next_lending_protocol = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_NEXT_LENDING_PROTOCOL);
        utils::set_u64_padding_value(&mut portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL, next_lending_protocol);
        let (oracle_price, oracle_price_decimal) = oracle::get_price(oracle, clock);
        let (_, settlement_quote_name, _, _) = oracle::get_token(oracle);
        portfolio_vault.info.round = portfolio_vault.info.round + 1;
        if (next_lending_protocol != 0) {
            portfolio_vault.config.recoup_delay_ts_ms = portfolio_vault.info.expiration_ts_ms - portfolio_vault.info.activation_ts_ms;
        };
        portfolio_vault.config.active_vault_config = portfolio_vault.config.warmup_vault_config;
        let amount = vault::activate<D_TOKEN>(
            deposit_vault,
            portfolio_vault.config.has_next,
            ctx,
        );
        let strike_increment = portfolio_vault.config.active_vault_config.strike_increment;
        let mut strikes = vector::empty();
        let mut payoff_configs_length = vector::length(&portfolio_vault.config.active_vault_config.payoff_configs);
        while (payoff_configs_length > 0) {
            let payoff_config = vector::borrow_mut(
                &mut portfolio_vault.config.active_vault_config.payoff_configs,
                payoff_configs_length - 1,
            );
            let mut strike = calculate_strike(oracle_price, payoff_config.strike_bp, strike_increment);
            strike = if (portfolio_vault.info.option_type % 2 == 1 && strike > strike_increment) {
                strike - strike_increment
            } else { strike };
            option::fill(&mut payoff_config.strike, strike);
            vector::push_back(&mut strikes, strike);
            payoff_configs_length = payoff_configs_length - 1;
        };
        let total_balance = vault::active_share_supply(deposit_vault)
                + vault::deactivating_share_supply(deposit_vault);
        let mut total_balance_ = total_balance;

        if (object::id(oracle) != object::id(d_token_price_oracle)) {
            let (d_token_price, d_token_price_decimal) = oracle::get_price(d_token_price_oracle, clock);
            // check d_token_price_oracle
            // oracle: USDC/USD price
            let (_, _, base_token_type, _) = oracle::get_token(d_token_price_oracle);
            // deposit_token: USDC, base_token_type: USDC
            assert!(portfolio_vault.info.deposit_token == base_token_type, invalid_deposit_token(index));
            // USDC -> USD
            total_balance_= ((total_balance_ as u128) * (d_token_price as u128) / (utils::multiplier(d_token_price_decimal) as u128)) as u64;
        };

        // total_balance_ in USD / collateral_per_unit in USD or total_balance_ in token / collateral_per_unit in token
        let max_size = calculate_max_auction_size(
            portfolio_vault.info.o_token_decimal,
            portfolio_vault.config.leverage,
            total_balance_,
            calculate_max_loss_per_unit(
                index,
                portfolio_vault.info.option_type,
                oracle_price,
                oracle_price_decimal,
                portfolio_vault.info.d_token_decimal,
                portfolio_vault.info.o_token_decimal,
                portfolio_vault.config.active_vault_config.payoff_configs,
                utils::multiplier(C_LEVERAGE_DECIMAL),
            ),
            portfolio_vault.config.bid_lot_size
        );
        portfolio_vault.info.oracle_info = OracleInfo {
            price: oracle_price,
            decimal: oracle_price_decimal,
        };
        portfolio_vault.info.delivery_infos = DeliveryInfos {
            round: portfolio_vault.info.round,
            max_size,
            total_delivery_size: 0,
            total_bidder_bid_value: 0,
            total_bidder_fee: 0,
            total_incentive_bid_value: 0,
            total_incentive_fee: 0,
            delivery_info: vector::empty(),
            u64_padding: vector::empty(),
        };
        let mut bid_vault_metadata = portfolio_vault.info.settlement_base_name;
        let (y, m, d) = utils::get_date_from_ts(portfolio_vault.info.expiration_ts_ms / 1000);
        string::append_utf8(&mut bid_vault_metadata, b"-");
        string::append_utf8(&mut bid_vault_metadata, utils::get_pad_2_number_string(d));
        string::append_utf8(&mut bid_vault_metadata, utils::get_month_short_string(m));
        string::append_utf8(&mut bid_vault_metadata, utils::get_pad_2_number_string(y));
        if (portfolio_vault.info.period == 3 || portfolio_vault.info.period == 4) {
            string::append_utf8(&mut bid_vault_metadata, b"-");
            string::append_utf8(&mut bid_vault_metadata, utils::get_pad_2_number_string(portfolio_vault.info.expiration_ts_ms % 86400000 / 3600000));
            string::append_utf8(&mut bid_vault_metadata, utils::get_pad_2_number_string(portfolio_vault.info.expiration_ts_ms % 3600000 / 60000));
        } else {
            vector::reverse(&mut strikes);
            while (!vector::is_empty(&strikes)) {
                let strike = vector::pop_back(&mut strikes);
                string::append_utf8(&mut bid_vault_metadata, b"-");
                string::append_utf8(&mut bid_vault_metadata, utils::u64_to_bytes(strike, oracle_price_decimal));
            };
        };
        if (portfolio_vault.info.option_type == 0) {
            string::append_utf8(&mut bid_vault_metadata, b"-Call");
        } else if (portfolio_vault.info.option_type == 1) {
            string::append_utf8(&mut bid_vault_metadata, b"-Put");
        } else if (portfolio_vault.info.option_type == 2) {
            string::append_utf8(&mut bid_vault_metadata, b"-CallSpread");
        } else if (portfolio_vault.info.option_type == 3) {
            string::append_utf8(&mut bid_vault_metadata, b"-PutSpread");
        } else if (portfolio_vault.info.option_type == 4) {
            string::append_utf8(&mut bid_vault_metadata, b"-CappedCall");
        } else if (portfolio_vault.info.option_type == 5) {
            string::append_utf8(&mut bid_vault_metadata, b"-CappedPut");
        } else if (portfolio_vault.info.option_type == 6) {
            if (std::ascii::into_bytes(settlement_quote_name) == b"USDT") {
                string::append_utf8(&mut bid_vault_metadata, b"-UsdtCappedCall");
            } else if (std::ascii::into_bytes(settlement_quote_name) == b"USDC"){
                string::append_utf8(&mut bid_vault_metadata, b"-UsdcCappedCall");
            } else {
                string::append_utf8(&mut bid_vault_metadata, b"-UsdCappedCall");
            }
        };
        let mut bid_vault = vault::new_bid_vault<D_TOKEN, B_TOKEN>(
            portfolio_vault.info.index,
            bid_vault_metadata,
            ctx,
        );
        let (mut bp_incentive_amount, mut fixed_incentive_amount) = (0, 0);
        if (max_size == 0 || clock::timestamp_ms(clock) >= portfolio_vault.info.expiration_ts_ms) {
            portfolio_vault.info.status = S_RECOUP;
            utils::set_u64_padding_value(&mut portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL, 0);
            let total_share_supply = vault::active_share_supply(deposit_vault) + vault::deactivating_share_supply(deposit_vault);
            if (total_share_supply > 0) {
                let (
                    bp,
                    fixed,
                ) = vault_delivery_<D_TOKEN, B_TOKEN, I_TOKEN>(
                    &mut registry.id,
                    portfolio_vault,
                    deposit_vault,
                    &mut bid_vault,
                    balance::zero(),
                    ctx,
                );
                bp_incentive_amount = bp;
                fixed_incentive_amount = fixed;
                vault::recoup<D_TOKEN>(
                    deposit_vault,
                    total_share_supply,
                    ctx,
                );
            };
        } else if (utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_SAFU_VAULT_INDEX_ADD_ONE_UP) != 0) {
            portfolio_vault.info.status = S_DELIVERY;
        } else {
            portfolio_vault.info.status = S_ACTIVATE;
        };
        dynamic_object_field::add(
            &mut registry.bid_vault_registry,
            index,
            bid_vault,
        );

        (
            amount,
            max_size,
            bp_incentive_amount,
            fixed_incentive_amount,
            total_balance
        )
    }

    public(package) fun new_auction_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        auction_delay_ts_ms: Option<u64>,
        auction_duration_ts_ms: Option<u64>,
        ctx: &mut TxContext,
    ): (u64, u64, u64) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        if (portfolio_vault.info.status == S_RECOUP) {
            return (0, 0, 0)
        };

        // safety check
        assert!(!auction_exists(&registry.auction_registry, index), auction_already_started(index));
        assert!(portfolio_vault.info.status == S_ACTIVATE || portfolio_vault.info.status == S_DELIVERY, invalid_action(index));

        // main logic
        let start_ts_ms = portfolio_vault.info.activation_ts_ms + option::get_with_default(&auction_delay_ts_ms, portfolio_vault.config.auction_delay_ts_ms);
        assert!(start_ts_ms < portfolio_vault.info.expiration_ts_ms, invalid_auction_delay_ts_ms(index));
        let end_ts_ms = start_ts_ms + option::get_with_default(&auction_duration_ts_ms, portfolio_vault.config.auction_duration_ts_ms);
        let size = portfolio_vault.info.delivery_infos.max_size - portfolio_vault.info.delivery_infos.total_delivery_size;
        let decay_speed = portfolio_vault.config.active_vault_config.decay_speed;
        let initial_price = portfolio_vault.config.active_vault_config.initial_price;
        let final_price = portfolio_vault.config.active_vault_config.final_price;
        let fee_bp = portfolio_vault.config.bid_fee_bp;
        let incentive_bp = portfolio_vault.config.bid_incentive_bp;
        let token_decimal = portfolio_vault.info.b_token_decimal;
        let size_decimal = portfolio_vault.info.o_token_decimal;
        dynamic_object_field::add(
            &mut registry.auction_registry,
            index,
            dutch::new<TOKEN>(
                index,
                start_ts_ms,
                end_ts_ms,
                size,
                decay_speed,
                initial_price,
                final_price,
                fee_bp,
                incentive_bp,
                token_decimal,
                size_decimal,
                false,
                ctx,
            ),
        );
        portfolio_vault.info.status = S_NEW_AUCTION;

        (
            start_ts_ms,
            end_ts_ms,
            size,
        )
    }

    /// delivery function process
    /// calculate portfolio collateral per unit by calculate_max_loss_per_unit
    /// calcualte delivery_size (contract size) => dutch::delivery
    /// store delivery_info for performance fee calculation when settlement
    /// refund unfilled - regular first (refund to refund_sub_vault)
    /// refund unfilled - rolling (refund to warmup_sub_vault if d_vault.has_next else refund to refund_sub_vault)
    /// delivery_premium (save premium & performance_fee balance and add share)
    /// delivery bidder share into bidder_sub_vault
    /// set auction as option::none()
    public(package) fun delivery_<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry: &mut Registry,
        index: u64,
        early: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let bid_vault = get_mut_bid_vault(&mut registry.bid_vault_registry, index);
        let refund_vault = get_mut_refund_vault<B_TOKEN>(&mut registry.refund_vault_registry);
        let fee_pool = &mut registry.fee_pool;
        let auction = take_auction(&mut registry.auction_registry, index);

        // safety check
        assert!(portfolio_vault.info.status == S_NEW_AUCTION, invalid_action(index));

        // main logic
        let (
            premium_balance,
            incentive_refund,
            delivery_price,
            delivery_size,
            bidder_bid_value,
            bidder_fee,
            incentive_bid_value,
            incentive_fee,
        ) = dutch::delivery(
            fee_pool,
            refund_vault,
            auction,
            early,
            clock,
            ctx
        );
        portfolio_vault.info.delivery_infos.total_delivery_size =
            portfolio_vault.info.delivery_infos.total_delivery_size + delivery_size;
        portfolio_vault.info.delivery_infos.total_bidder_bid_value =
            portfolio_vault.info.delivery_infos.total_bidder_bid_value + bidder_bid_value;
        portfolio_vault.info.delivery_infos.total_bidder_fee =
            portfolio_vault.info.delivery_infos.total_bidder_fee + bidder_fee;
        portfolio_vault.info.delivery_infos.total_incentive_bid_value =
            portfolio_vault.info.delivery_infos.total_incentive_bid_value + incentive_bid_value;
        portfolio_vault.info.delivery_infos.total_incentive_fee =
            portfolio_vault.info.delivery_infos.total_incentive_fee + incentive_fee;

        let (
            bp_incentive_amount,
            fixed_incentive_amount,
        ) = vault_delivery_<D_TOKEN, B_TOKEN, I_TOKEN>(
            &mut registry.id,
            portfolio_vault,
            deposit_vault,
            bid_vault,
            premium_balance,
            ctx,
        );

        vector::push_back(
            &mut portfolio_vault.info.delivery_infos.delivery_info,
            DeliveryInfo {
                auction_type: 0,
                delivery_price,
                delivery_size,
                bidder_bid_value,
                bidder_fee,
                incentive_bid_value,
                incentive_fee,
                ts_ms: clock::timestamp_ms(clock),
                u64_padding: vector[bp_incentive_amount, fixed_incentive_amount],
            }
        );

        if (balance::value(&incentive_refund) > 0) {
            let available_incentive_amount
                = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT);
            utils::set_u64_padding_value(
                &mut portfolio_vault.config.u64_padding,
                I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT,
                available_incentive_amount + balance::value(&incentive_refund)
            );
            let balance = dynamic_field::borrow_mut(&mut registry.id, type_name::get<B_TOKEN>());
            balance::join(balance, incentive_refund);
        } else {
            balance::destroy_zero(incentive_refund)
        };
        if (portfolio_vault.info.delivery_infos.max_size - portfolio_vault.info.delivery_infos.total_delivery_size > 0) {
            portfolio_vault.info.status = S_DELIVERY;
        } else {
            portfolio_vault.info.status = S_RECOUP;
        };

        let deposit_incentive_bp = portfolio_vault.config.deposit_incentive_bp;
        let deposit_incentive_bp_divisor = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_DEPOSIT_INCENTIVE_BP_DIVISOR_DECIMAL);
        let bid_incentive_bp = portfolio_vault.config.bid_incentive_bp;

        vector[
            delivery_price,
            delivery_size,
            bidder_bid_value,
            bidder_fee,
            incentive_bid_value,
            incentive_fee,
            bp_incentive_amount,
            fixed_incentive_amount,
            deposit_incentive_bp,
            deposit_incentive_bp_divisor,
            bid_incentive_bp
        ]
    }

    fun vault_delivery_<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry_id: &mut UID,
        portfolio_vault: &mut PortfolioVault,
        deposit_vault: &mut DepositVault,
        bid_vault: &mut BidVault,
        mut premium_balance: Balance<B_TOKEN>,
        ctx: & TxContext,
    ): (u64, u64) {
        // main logic
        let bp_incentive_amount = if (
            portfolio_vault.config.deposit_incentive_bp > 0
            && dynamic_field::exists_with_type<TypeName, Balance<B_TOKEN>>(registry_id, type_name::get<B_TOKEN>())
        ) {
            let incentive: &mut Balance<B_TOKEN> = dynamic_field::borrow_mut(registry_id, type_name::get<B_TOKEN>());
            let incentive_pool_amount = balance::value(incentive);
            let available_incentive_amount
                = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT);
            let total_share_supply =
                vault::active_share_supply(deposit_vault) + vault::deactivating_share_supply(deposit_vault);
            let incentivised_balance = (total_share_supply as u128);
            // let incentivised_balance =
                // (total_share_supply as u128) * (delivery_size as u128) / (portfolio_vault.info.delivery_infos.max_size as u128);
            let deposit_incentive_bp_divisor = utils::multiplier(utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_DEPOSIT_INCENTIVE_BP_DIVISOR_DECIMAL));
            let mut theoretical_incentive_amount = (incentivised_balance
                * (portfolio_vault.config.deposit_incentive_bp as u128)
                    / 10000
                        / (deposit_incentive_bp_divisor as u128) as u64);

            theoretical_incentive_amount = calcualte_incentive_(portfolio_vault, theoretical_incentive_amount);

            let incentive_amount = if (theoretical_incentive_amount > incentive_pool_amount) {
                if (incentive_pool_amount > available_incentive_amount) {
                    available_incentive_amount
                } else {
                    balance::value(incentive)
                }
            } else {
                if (theoretical_incentive_amount > available_incentive_amount) {
                    available_incentive_amount
                } else {
                    theoretical_incentive_amount
                }
            };
            utils::set_u64_padding_value(
                &mut portfolio_vault.config.u64_padding,
                I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT,
                available_incentive_amount - incentive_amount
            );
            incentive_amount
        } else { 0 };
        let fixed_incentive_amount
            = utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_FIXED_INCENTIVE_AMOUNT);

        if (bp_incentive_amount == 0 && fixed_incentive_amount == 0) {
            vault::delivery<D_TOKEN, B_TOKEN>(
                deposit_vault,
                bid_vault,
                premium_balance,
            );
        } else {
            if (utils::match_types<B_TOKEN, I_TOKEN>()) {
                let mut depositor_incentive = balance::zero();
                if (bp_incentive_amount > 0) {
                    let balance = dynamic_field::borrow_mut(registry_id, type_name::get<B_TOKEN>());
                    balance::join(&mut depositor_incentive, balance::split(balance, bp_incentive_amount));
                };
                if (fixed_incentive_amount > 0) {
                    let balance = dynamic_field::borrow_mut(&mut portfolio_vault.id, type_name::get<B_TOKEN>());
                    balance::join(&mut depositor_incentive, balance::split(balance, fixed_incentive_amount));
                    utils::set_u64_padding_value(
                        &mut portfolio_vault.config.u64_padding,
                        I_CONFIG_FIXED_INCENTIVE_AMOUNT,
                        if (fixed_incentive_amount < balance::value(balance)) { fixed_incentive_amount } else { balance::value(balance) },
                    );
                };
                vault::delivery_b<D_TOKEN, B_TOKEN>(
                    deposit_vault,
                    bid_vault,
                    premium_balance,
                    depositor_incentive,
                    ctx,
                );
            } else {
                if (bp_incentive_amount > 0) {
                    let balance = dynamic_field::borrow_mut(registry_id, type_name::get<B_TOKEN>());
                    balance::join(&mut premium_balance, balance::split(balance, bp_incentive_amount));
                };
                let depositor_incentive = if (fixed_incentive_amount > 0) {
                    let balance = dynamic_field::borrow_mut(&mut portfolio_vault.id, type_name::get<I_TOKEN>());
                    let depositor_incentive = balance::split(balance, fixed_incentive_amount);
                    utils::set_u64_padding_value(
                        &mut portfolio_vault.config.u64_padding,
                        I_CONFIG_FIXED_INCENTIVE_AMOUNT,
                        if (fixed_incentive_amount < balance::value(balance)) { fixed_incentive_amount } else { balance::value(balance) },
                    );
                    depositor_incentive
                } else {
                    balance::zero()
                };
                vault::delivery_i<D_TOKEN, B_TOKEN, I_TOKEN>(
                    deposit_vault,
                    bid_vault,
                    premium_balance,
                    depositor_incentive,
                    ctx,
                );
            };
        };

        (
            bp_incentive_amount,
            fixed_incentive_amount,
        )
    }

    fun calcualte_incentive_(
        portfolio_vault: &PortfolioVault,
        mut theoretical_incentive_amount: u64,
    ): u64 {
        let is_call = portfolio_vault.info.option_type % 2 == 0 && portfolio_vault.info.option_type != 6;

        let deposit_token = portfolio_vault.info.deposit_token;
        let bid_token = portfolio_vault.info.bid_token;
        // d_token -> b_token
        theoretical_incentive_amount = if (deposit_token == bid_token) {
            theoretical_incentive_amount
        } else {
            // incentive will be B_TOKEN => calculate D -> B
            // D != B => check if need price calculation: D -> AFSUI, B -> SUI no need. o.w. need calculation
            // bp_incentive_amount only use at SUI vaults
            let l = portfolio_vault.info.deposit_token.into_string().length();
            // last 3 characters of settlement_base_name should be "SUI"
            if (
                portfolio_vault.info.deposit_token.into_string().substring(l - 3, l).into_bytes() == b"SUI"
                || portfolio_vault.info.deposit_token.into_string().substring(l - 4, l).into_bytes() == b"CERT"
            ) {
                // for LST AFSUI = SUI 1:1
                // B_TOKEN = SUI, settlement_base = AFSUI, settlement_quote = USDC
                theoretical_incentive_amount
            } else {
                // bid_token == portfolio_vault.info.settlement_base || bid_token == portfolio_vault.info.settlement_quote
                let price = portfolio_vault.info.oracle_info.price;
                let decimal = portfolio_vault.info.oracle_info.decimal;
                // call: token -> usdc
                // theoretical_incentive_amount in d_token
                if (is_call) {
                    ((theoretical_incentive_amount as u128)
                        * (price as u128)
                        / (utils::multiplier(decimal) as u128)
                        * (utils::multiplier(portfolio_vault.info.b_token_decimal) as u128)
                        / (utils::multiplier(portfolio_vault.info.d_token_decimal) as u128) as u64)
                }
                // 1. put: usdc -> token 2. (U, T, U) usdc capped call: usdc -> token
                else {
                    ((theoretical_incentive_amount as u128)
                        * (utils::multiplier(decimal) as u128)
                        / (price as u128)
                        * (utils::multiplier(portfolio_vault.info.b_token_decimal) as u128)
                        / (utils::multiplier(portfolio_vault.info.d_token_decimal) as u128) as u64)
                }
            }
        };
        theoretical_incentive_amount
    }

    public fun calcualte_incentive(
        registry: &Registry,
        index: u64,
        theoretical_incentive_amount: u64,
    ): u64 {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        calcualte_incentive_(portfolio_vault, theoretical_incentive_amount)
    }

    #[allow(lint(self_transfer))]
    public(package) fun otc_<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        round: Option<u64>,
        delivery_price: u64,
        delivery_size: u64,
        mut bidder_balance: Balance<B_TOKEN>,
        bidder_fee_balance: Balance<B_TOKEN>,
        incentive_balance: Balance<B_TOKEN>,
        incentive_fee_balance: Balance<B_TOKEN>,
        depositor_incentive_balance: Balance<B_TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let bid_vault = get_mut_bid_vault(&mut registry.bid_vault_registry, index);

        // safety check
        assert!(!auction_exists(&registry.auction_registry, index), auction_already_started(index));
        assert!(portfolio_vault.info.status == S_ACTIVATE || portfolio_vault.info.status == S_DELIVERY, invalid_action(index));
        assert!(round.is_none() || option::some(portfolio_vault.info.round) == round , invalid_round(index));
        assert!(((delivery_price as u128) * (delivery_size as u128)
            / (utils::multiplier(portfolio_vault.info.o_token_decimal) as u128) as u64)
                <= balance::value(&bidder_balance) + balance::value(&incentive_balance), insufficient_balance(index));
        assert!(portfolio_vault.info.delivery_infos.total_delivery_size + delivery_size
            <= portfolio_vault.info.delivery_infos.max_size, max_size_violation(index));

        // main logic
        let bidder_fee = balance::value(&bidder_fee_balance);
        balance_pool::put(&mut registry.fee_pool, bidder_fee_balance);
        let incentive_fee = balance::value(&incentive_fee_balance);
        balance_pool::put(&mut registry.fee_pool, incentive_fee_balance);
        let bidder_bid_value = balance::value(&bidder_balance);
        let incentive_bid_value = balance::value(&incentive_balance);
        balance::join(&mut bidder_balance, incentive_balance);
        let premium_balance = bidder_balance;

        portfolio_vault.info.delivery_infos.total_delivery_size =
            portfolio_vault.info.delivery_infos.total_delivery_size + delivery_size;
        portfolio_vault.info.delivery_infos.total_bidder_bid_value =
            portfolio_vault.info.delivery_infos.total_bidder_bid_value + bidder_bid_value;
        portfolio_vault.info.delivery_infos.total_bidder_fee =
            portfolio_vault.info.delivery_infos.total_bidder_fee + bidder_fee;
        portfolio_vault.info.delivery_infos.total_incentive_bid_value =
            portfolio_vault.info.delivery_infos.total_incentive_bid_value + incentive_bid_value;
        portfolio_vault.info.delivery_infos.total_incentive_fee =
            portfolio_vault.info.delivery_infos.total_incentive_fee + incentive_fee;
        vector::push_back(
            &mut portfolio_vault.info.delivery_infos.delivery_info,
            DeliveryInfo {
                auction_type: 1,
                delivery_price,
                delivery_size,
                bidder_bid_value,
                bidder_fee,
                incentive_bid_value,
                incentive_fee,
                ts_ms: clock::timestamp_ms(clock),
                u64_padding: vector::empty(),
            }
        );
        let mut receipt = vault::public_new_bid(
            bid_vault,
            delivery_size,
            ctx,
        );
        vault::update_bid_receipt_u64_padding(
            &mut receipt,
            vector[
                delivery_price,
                delivery_size,
                bidder_bid_value,
                bidder_fee,
                incentive_bid_value,
                incentive_fee,
                clock::timestamp_ms(clock),
            ],
        );
        transfer::public_transfer(receipt, ctx.sender());
        vault::delivery_b<D_TOKEN, B_TOKEN>(
            deposit_vault,
            bid_vault,
            premium_balance,
            depositor_incentive_balance,
            ctx,
        );
        if (portfolio_vault.info.delivery_infos.total_delivery_size == portfolio_vault.info.delivery_infos.max_size) {
            portfolio_vault.info.status = S_RECOUP;
        };
    }

    public(package) fun public_safu_otc_v2_<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        price: u64,
        mut balance: Balance<B_TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Option<TypusBidReceipt>, vector<u64>) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let bid_vault = get_mut_bid_vault(&mut registry.bid_vault_registry, index);

        // safety check
        assert!(!auction_exists(&registry.auction_registry, index), auction_already_started(index));
        assert!(portfolio_vault.info.status == S_ACTIVATE || portfolio_vault.info.status == S_DELIVERY || portfolio_vault.info.status == S_RECOUP, invalid_action(index));
        if (portfolio_vault.info.status == S_RECOUP) {
            balance.destroy_zero();
            return (option::none(), vector[0, 0, 0, 0])
        };

        // main logic
        let size = dutch::calculate_bid_size(
            portfolio_vault.config.bid_fee_bp,
            portfolio_vault.info.o_token_decimal,
            price,
            balance.value(),
            0,
        );
        let delivery_size = if (portfolio_vault.info.delivery_infos.total_delivery_size + size > portfolio_vault.info.delivery_infos.max_size) {
            portfolio_vault.info.delivery_infos.max_size - portfolio_vault.info.delivery_infos.total_delivery_size
        } else {
            size
        };
        if (delivery_size == 0) {
            balance.destroy_zero();
            return (option::none(), vector[0, 0, 0, 0])
        };
        let (_, bidder_fee) = dutch::calculate_bid_value(
            portfolio_vault.config.bid_fee_bp,
            portfolio_vault.info.b_token_decimal,
            portfolio_vault.info.o_token_decimal,
            price,
            delivery_size,
            0,
        );
        let bidder_fee_balance = balance.split(bidder_fee);
        balance_pool::put(&mut registry.fee_pool, bidder_fee_balance);
        let bidder_bid_value = balance.value();
        let premium_balance = balance;
        portfolio_vault.info.delivery_infos.total_delivery_size =
            portfolio_vault.info.delivery_infos.total_delivery_size + delivery_size;
        portfolio_vault.info.delivery_infos.total_bidder_bid_value =
            portfolio_vault.info.delivery_infos.total_bidder_bid_value + bidder_bid_value;
        portfolio_vault.info.delivery_infos.total_bidder_fee =
            portfolio_vault.info.delivery_infos.total_bidder_fee + bidder_fee;
        vector::push_back(
            &mut portfolio_vault.info.delivery_infos.delivery_info,
            DeliveryInfo {
                auction_type: 1,
                delivery_price: price,
                delivery_size,
                bidder_bid_value,
                bidder_fee,
                incentive_bid_value: 0,
                incentive_fee: 0,
                ts_ms: clock::timestamp_ms(clock),
                u64_padding: vector::empty(),
            }
        );
        let receipt = vault::public_new_bid(
            bid_vault,
            delivery_size,
            ctx,
        );
        vault::delivery<D_TOKEN, B_TOKEN>(
            deposit_vault,
            bid_vault,
            premium_balance,
        );
        if (portfolio_vault.info.delivery_infos.total_delivery_size == portfolio_vault.info.delivery_infos.max_size) {
            portfolio_vault.info.status = S_RECOUP;
        };

        (option::some(receipt), vector[price, delivery_size, bidder_bid_value, bidder_fee])
    }

    public(package) fun airdrop_otc_<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        price: u64,
        bid_balance: Balance<B_TOKEN>,
        fee_balance: Balance<B_TOKEN>,
        mut users: vector<address>,
        mut sizes: vector<u64>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (vector<u64>) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let bid_vault = get_mut_bid_vault(&mut registry.bid_vault_registry, index);

        // safety check
        assert!(!auction_exists(&registry.auction_registry, index), auction_already_started(index));
        assert!(portfolio_vault.info.status == S_ACTIVATE || portfolio_vault.info.status == S_DELIVERY, invalid_action(index));
        assert!(users.length() == sizes.length(), invalid_input(index));

        // main logic
        let mut delivery_size = 0;
        while (!users.is_empty()) {
            let user = users.pop_back();
            let size = sizes.pop_back();
            let receipt = vault::public_new_bid(
                bid_vault,
                size,
                ctx,
            );
            transfer::public_transfer(receipt, user);
            delivery_size = delivery_size + size;
        };
        let bidder_fee = fee_balance.value();
        balance_pool::put(&mut registry.fee_pool, fee_balance);
        let bidder_bid_value = bid_balance.value();
        let premium_balance = bid_balance;
        portfolio_vault.info.delivery_infos.total_delivery_size =
            portfolio_vault.info.delivery_infos.total_delivery_size + delivery_size;
        portfolio_vault.info.delivery_infos.total_bidder_bid_value =
            portfolio_vault.info.delivery_infos.total_bidder_bid_value + bidder_bid_value;
        portfolio_vault.info.delivery_infos.total_bidder_fee =
            portfolio_vault.info.delivery_infos.total_bidder_fee + bidder_fee;
        vector::push_back(
            &mut portfolio_vault.info.delivery_infos.delivery_info,
            DeliveryInfo {
                auction_type: 1,
                delivery_price: price,
                delivery_size,
                bidder_bid_value,
                bidder_fee,
                incentive_bid_value: 0,
                incentive_fee: 0,
                ts_ms: clock::timestamp_ms(clock),
                u64_padding: vector::empty(),
            }
        );
        assert!(portfolio_vault.info.delivery_infos.total_delivery_size <= portfolio_vault.info.delivery_infos.max_size, max_size_violation(index));
        vault::delivery<D_TOKEN, B_TOKEN>(
            deposit_vault,
            bid_vault,
            premium_balance,
        );
        if (portfolio_vault.info.delivery_infos.total_delivery_size == portfolio_vault.info.delivery_infos.max_size) {
            portfolio_vault.info.status = S_RECOUP;
        };

        (vector[price, delivery_size, bidder_bid_value, bidder_fee])
    }

    public(package) fun witness_otc_<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        delivery_price: u64,
        mut delivery_size: u64,
        mut bidder_balance: Balance<B_TOKEN>,
        mut bidder_fee_balance: Balance<B_TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Option<TypusBidReceipt>, Option<Balance<B_TOKEN>>, vector<u64>) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let bid_vault = get_mut_bid_vault(&mut registry.bid_vault_registry, index);

        // safety check
        if (auction_exists(&registry.auction_registry, index)
            || portfolio_vault.info.status != S_DELIVERY
        ) {
            bidder_balance.join(bidder_fee_balance);
            return (option::none(), option::some(bidder_balance), vector[0, 0, 0, 0])
        };
        // assert!(!auction_exists(&registry.auction_registry, index), E_AUCTION_ALREADY_STARTED);
        // assert!(portfolio_vault.info.status == S_ACTIVATE || portfolio_vault.info.status == S_DELIVERY, E_INVALID_ACTION);

        // main logic
        let mut refund = option::none();
        let remaining_size =  portfolio_vault.info.delivery_infos.max_size - portfolio_vault.info.delivery_infos.total_delivery_size;
        if (delivery_size > remaining_size) {
            let difference = delivery_size - remaining_size;
            let bidder_balance_value = bidder_balance.value();
            let bidder_fee_balance_value = bidder_fee_balance.value();
            let mut refund_balance = balance::zero();
            refund_balance.join(bidder_balance.split(bidder_balance_value * difference / delivery_size));
            refund_balance.join(bidder_fee_balance.split(bidder_fee_balance_value * difference / delivery_size));
            refund.fill(refund_balance);
            delivery_size = remaining_size;
        };
        let bidder_fee = balance::value(&bidder_fee_balance);
        balance_pool::put(&mut registry.fee_pool, bidder_fee_balance);
        let bidder_bid_value = balance::value(&bidder_balance);
        let premium_balance = bidder_balance;

        portfolio_vault.info.delivery_infos.total_delivery_size =
            portfolio_vault.info.delivery_infos.total_delivery_size + delivery_size;
        portfolio_vault.info.delivery_infos.total_bidder_bid_value =
            portfolio_vault.info.delivery_infos.total_bidder_bid_value + bidder_bid_value;
        portfolio_vault.info.delivery_infos.total_bidder_fee =
            portfolio_vault.info.delivery_infos.total_bidder_fee + bidder_fee;
        vector::push_back(
            &mut portfolio_vault.info.delivery_infos.delivery_info,
            DeliveryInfo {
                auction_type: 1,
                delivery_price,
                delivery_size,
                bidder_bid_value,
                bidder_fee,
                incentive_bid_value: 0,
                incentive_fee: 0,
                ts_ms: clock::timestamp_ms(clock),
                u64_padding: vector::empty(),
            }
        );
        let receipt = vault::public_new_bid(
            bid_vault,
            delivery_size,
            ctx,
        );
        vault::delivery<D_TOKEN, B_TOKEN>(
            deposit_vault,
            bid_vault,
            premium_balance,
        );
        if (portfolio_vault.info.delivery_infos.total_delivery_size == portfolio_vault.info.delivery_infos.max_size) {
            portfolio_vault.info.status = S_RECOUP;
        };

        (option::some(receipt), refund, vector[delivery_price, delivery_size, bidder_bid_value, bidder_fee])
    }

    public(package) fun recoup_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        clock: &Clock,
        ctx: & TxContext,
    ): (u64, u64) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        if (portfolio_vault.info.status == S_RECOUP) {
            return (0, 0)
        };

        // safety check
        assert!(clock::timestamp_ms(clock) >=
            portfolio_vault.info.activation_ts_ms + portfolio_vault.config.recoup_delay_ts_ms, recoup_not_yet_started(index));
        assert!(portfolio_vault.info.status == S_DELIVERY, invalid_action(index));
        portfolio_vault.info.status = S_RECOUP;
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 0, lending_protocol_not_yet_withdrawn(index));

        // main logic
        let refund_amount = ((((vault::active_share_supply(deposit_vault)
            + vault::deactivating_share_supply(deposit_vault)) as u128)
            * ((portfolio_vault.info.delivery_infos.max_size - portfolio_vault.info.delivery_infos.total_delivery_size) as u128)
            / (portfolio_vault.info.delivery_infos.max_size as u128)) as u64);
        let (refund_from_active_share, refund_from_deactivating_share) = vault::recoup<TOKEN>(
            deposit_vault,
            refund_amount,
            ctx,
        );

        (refund_from_active_share, refund_from_deactivating_share)
    }

    public(package) fun settle_<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        oracle: &Oracle,
        d_token_price_oracle: &Oracle,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, u64, u64, u64, u64, vector<u64>) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let bid_vault = get_mut_bid_vault(&mut registry.bid_vault_registry, index);
        let current_ts_ms = clock::timestamp_ms(clock);

        // safety check
        assert!(current_ts_ms >= portfolio_vault.info.expiration_ts_ms, not_yet_expired(index));
        assert!(portfolio_vault.info.status == S_RECOUP, invalid_action(index));
        portfolio_vault.info.status = S_SETTLE;
        assert!(utils::get_u64_padding_value(&portfolio_vault.info.u64_padding, I_INFO_CURRENT_LENDING_PROTOCOL) == 0, lending_protocol_not_yet_withdrawn(index));

        // main logic
        let (oracle_price, oracle_price_decimal) = oracle::get_price(oracle, clock);

        let delivery_size = portfolio_vault.info.delivery_infos.total_delivery_size;
        // portfolio_payoff should be <= 0; if negative => depositor should pay
        // leverage has been considered in delivery_size => use 1x leverage to calculate portfolio payoff
        let mut portfolio_payoff = calculate_portfolio_payoff_by_price(
            index,
            portfolio_vault.info.option_type,
            oracle_price,
            oracle_price_decimal,
            portfolio_vault.info.d_token_decimal,
            portfolio_vault.config.active_vault_config.payoff_configs,
            utils::multiplier(C_LEVERAGE_DECIMAL),
            delivery_size,
            portfolio_vault.info.o_token_decimal,
        );

        // div d_token_price_oracle if oracles are not same
        if (object::id(oracle) != object::id(d_token_price_oracle)) {
            // check d_token_price_oracle
            let (_, _, base_token_type, _) = oracle::get_token(d_token_price_oracle);
            assert!(portfolio_vault.info.deposit_token == base_token_type, invalid_deposit_token(index));
            let (d_token_price, d_token_price_decimal) = oracle::get_price(d_token_price_oracle, clock);
            portfolio_payoff = i64_mul_div(portfolio_payoff, utils::multiplier(d_token_price_decimal), d_token_price);
        };

        // calculate share_price
        let settle_balance = vault::active_balance<D_TOKEN>(deposit_vault)
            + vault::deactivating_balance<D_TOKEN>(deposit_vault);
        let inactive_balance = vault::inactive_balance<D_TOKEN>(deposit_vault);
        let share_price = {
            let remained_balance = i64::add(&i64::from(settle_balance), &portfolio_payoff);
            if (settle_balance != 0) {
                ((utils::multiplier(C_SHARE_PRICE_DECIMAL) as u128)
                    * (i64::as_u64(&remained_balance) as u128)
                    / (settle_balance as u128) as u64)
            } else {
                utils::multiplier(C_SHARE_PRICE_DECIMAL)
            }
        };
        let share_price_decimal = C_SHARE_PRICE_DECIMAL;
        // settle
        vault::settle<D_TOKEN, B_TOKEN>(
            deposit_vault,
            bid_vault,
            share_price,
            share_price_decimal,
            ctx,
        );
        let settled_balance = vault::active_balance<D_TOKEN>(deposit_vault)
            + vault::inactive_balance<D_TOKEN>(deposit_vault) - inactive_balance;
        portfolio_vault.info.settlement_info = option::some(
            SettlementInfo {
                round: portfolio_vault.info.round,
                oracle_price,
                oracle_price_decimal,
                settle_balance,
                settled_balance,
                share_price,
                share_price_decimal,
                ts_ms: current_ts_ms,
                u64_padding: vector::empty(),
            }
        );
        update_portfolio_vault_activation_expiration_time(portfolio_vault);
        let mut skipped_rounds = vector[];
        while (current_ts_ms >= portfolio_vault.info.expiration_ts_ms) {
            portfolio_vault.info.round = portfolio_vault.info.round + 1;
            skipped_rounds.push_back(portfolio_vault.info.round);
            update_portfolio_vault_activation_expiration_time(portfolio_vault);
        };
        let mut bid_vault: BidVault = dynamic_object_field::remove(
            &mut registry.bid_vault_registry,
            index,
        );
        let bid_shares = vault::get_bid_shares(&bid_vault).length();
        if (bid_shares == 0) {
            vault::drop_bid_vault<D_TOKEN>(bid_vault);
        } else {
            vault::set_bid_vault_u64_padding_value(
                &mut bid_vault,
                I_BID_VAULT_SETTLE_PRICE,
                oracle_price,
            );

            let delivery_info = vector::borrow(&portfolio_vault.info.delivery_infos.delivery_info, 0);
            vault::set_bid_vault_u64_padding_value(
                &mut bid_vault,
                I_BID_VAULT_DELIVERY_PRICE,
                delivery_info.delivery_price,
            );

            vault::set_bid_vault_u64_padding_value(
                &mut bid_vault,
                I_BID_VAULT_BID_INCENTIVE_BP,
                portfolio_vault.config.bid_incentive_bp,
            );

            vault::set_bid_vault_u64_padding_value(
                &mut bid_vault,
                I_BID_VAULT_ROUND,
                portfolio_vault.info.round,
            );

            dynamic_object_field::add(
                &mut registry.bid_vault_registry,
                object::id_address(&bid_vault),
                bid_vault,
            );
        };

        (
            oracle_price,
            oracle_price_decimal,
            settle_balance,
            settled_balance,
            share_price,
            skipped_rounds,
        )
    }

    public(package) fun skip_<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, u64, u64, u64, u64, vector<u64>) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        let bid_vault = get_mut_bid_vault(&mut registry.bid_vault_registry, index);
        let current_ts_ms = clock::timestamp_ms(clock);

        // safety check
        assert!(current_ts_ms >= portfolio_vault.info.expiration_ts_ms, not_yet_expired(index));
        assert!(portfolio_vault.info.status == S_DELIVERY || portfolio_vault.info.status == S_RECOUP, invalid_action(index));
        portfolio_vault.info.status = S_SETTLE;

        // main logic
        let (oracle_price, oracle_price_decimal) = (0, 0);
        let settle_balance = vault::active_balance<D_TOKEN>(deposit_vault)
            + vault::deactivating_balance<D_TOKEN>(deposit_vault);
        let inactive_balance = vault::inactive_balance<D_TOKEN>(deposit_vault);
        let share_price = utils::multiplier(C_SHARE_PRICE_DECIMAL);
        let share_price_decimal = C_SHARE_PRICE_DECIMAL;
        // settle
        vault::settle<D_TOKEN, B_TOKEN>(
            deposit_vault,
            bid_vault,
            share_price,
            share_price_decimal,
            ctx,
        );
        let settled_balance = vault::active_balance<D_TOKEN>(deposit_vault)
            + vault::inactive_balance<D_TOKEN>(deposit_vault) - inactive_balance;
        portfolio_vault.info.settlement_info = option::some(
            SettlementInfo {
                round: portfolio_vault.info.round,
                oracle_price,
                oracle_price_decimal,
                settle_balance,
                settled_balance,
                share_price,
                share_price_decimal,
                ts_ms: current_ts_ms,
                u64_padding: vector::empty(),
            }
        );
        update_portfolio_vault_activation_expiration_time(portfolio_vault);
        let mut skipped_rounds = vector[portfolio_vault.info.round];
        while (current_ts_ms >= portfolio_vault.info.expiration_ts_ms) {
            portfolio_vault.info.round = portfolio_vault.info.round + 1;
            skipped_rounds.push_back(portfolio_vault.info.round);
            update_portfolio_vault_activation_expiration_time(portfolio_vault);
        };
        let mut bid_vault: BidVault = dynamic_object_field::remove(
            &mut registry.bid_vault_registry,
            index,
        );
        let bid_shares = vault::get_bid_shares(&bid_vault).length();
        if (bid_shares == 0) {
            vault::drop_bid_vault<D_TOKEN>(bid_vault);
        } else {
            vault::set_bid_vault_u64_padding_value(
                &mut bid_vault,
                I_BID_VAULT_SETTLE_PRICE,
                oracle_price,
            );

            let delivery_info = vector::borrow(&portfolio_vault.info.delivery_infos.delivery_info, 0);
            vault::set_bid_vault_u64_padding_value(
                &mut bid_vault,
                I_BID_VAULT_DELIVERY_PRICE,
                delivery_info.delivery_price,
            );

            vault::set_bid_vault_u64_padding_value(
                &mut bid_vault,
                I_BID_VAULT_BID_INCENTIVE_BP,
                portfolio_vault.config.bid_incentive_bp,
            );

            vault::set_bid_vault_u64_padding_value(
                &mut bid_vault,
                I_BID_VAULT_ROUND,
                portfolio_vault.info.round,
            );

            dynamic_object_field::add(
                &mut registry.bid_vault_registry,
                object::id_address(&bid_vault),
                bid_vault,
            );
        };

        (
            oracle_price,
            oracle_price_decimal,
            settle_balance,
            settled_balance,
            share_price,
            skipped_rounds,
        )
    }

    public(package) fun terminate_<TOKEN>(
        registry: &mut Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        portfolio_vault.config.has_next = false;
        portfolio_vault.info.status = 5;
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        vault::terminate<TOKEN>(deposit_vault, ctx);
    }

    public(package) fun close_(
        registry: &mut Registry,
        index: u64,
    ) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        portfolio_vault.config.has_next = false;
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        vault::close(deposit_vault);
    }

    public(package) fun resume_(
        registry: &mut Registry,
        index: u64,
    ) {
        let portfolio_vault = get_mut_portfolio_vault(&mut registry.portfolio_vault_registry, index);
        portfolio_vault.config.has_next = true;
        let deposit_vault = get_mut_deposit_vault(&mut registry.deposit_vault_registry, index);
        vault::resume(deposit_vault);
    }

    public(package) fun drop_<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        let PortfolioVault {
            id,
            info: _,
            config: _,
            mut authority,
        } = dynamic_object_field::remove<u64, PortfolioVault>(&mut registry.portfolio_vault_registry, index);
        object::delete(id);
        authority::add_authorized_user(&mut authority, tx_context::sender(ctx));
        authority::destroy(authority, ctx);
        vault::drop_deposit_vault<D_TOKEN, B_TOKEN>(dynamic_object_field::remove<u64, DepositVault>(&mut registry.deposit_vault_registry, index));
    }

    // ======== Helper Functions ========

    public(package) fun get_version(): u64 {
        C_VERSION
    }

    public(package) fun get_registry_inner(
        registry: &Registry
    ): (
        &UID,
        &u64,
        &Authority,
        &BalancePool,
        &UID,
        &UID,
        &UID,
        &UID,
        &UID,
        &UID,
        &u64,
        &bool,
    ) {
        (
            &registry.id,
            &registry.num_of_vault,
            &registry.authority,
            &registry.fee_pool,
            &registry.portfolio_vault_registry,
            &registry.deposit_vault_registry,
            &registry.auction_registry,
            &registry.bid_vault_registry,
            &registry.refund_vault_registry,
            &registry.additional_config_registry,
            &registry.version,
            &registry.transaction_suspended,
        )
    }

    public(package) fun get_mut_registry_inner(
        registry: &mut Registry
    ): (
        &mut UID,
        &mut u64,
        &mut Authority,
        &mut BalancePool,
        &mut UID,
        &mut UID,
        &mut UID,
        &mut UID,
        &mut UID,
        &mut UID,
        &mut u64,
        &mut bool,
    ) {
        (
            &mut registry.id,
            &mut registry.num_of_vault,
            &mut registry.authority,
            &mut registry.fee_pool,
            &mut registry.portfolio_vault_registry,
            &mut registry.deposit_vault_registry,
            &mut registry.auction_registry,
            &mut registry.bid_vault_registry,
            &mut registry.refund_vault_registry,
            &mut registry.additional_config_registry,
            &mut registry.version,
            &mut registry.transaction_suspended,
        )
    }

    public(package) fun portfolio_vault_exists(
        id: &UID,
        index: u64,
    ): bool {
        dynamic_object_field::exists_with_type<u64, PortfolioVault>(id, index)
    }

    public(package) fun auction_exists(
        id: &UID,
        index: u64,
    ): bool {
        dynamic_object_field::exists_with_type<u64, Auction>(id, index)
    }

    public(package) fun refund_vault_exists<TOKEN>(
        id: &UID,
    ): bool {
        dynamic_object_field::exists_with_type<TypeName, RefundVault>(id, type_name::get<TOKEN>())
    }

    public(package) fun get_portfolio_vault_authority(
        portfolio_vault: &PortfolioVault,
    ): &Authority {
        &portfolio_vault.authority
    }

    public(package) fun get_mut_portfolio_vault_authority(
        portfolio_vault: &mut PortfolioVault,
    ): &mut Authority {
        &mut portfolio_vault.authority
    }

    public(package) fun get_portfolio_vault(
        id: &UID,
        index: u64,
    ): &PortfolioVault {
        dynamic_object_field::borrow<u64, PortfolioVault>(id, index)
    }

    public(package) fun get_mut_portfolio_vault(
        id: &mut UID,
        index: u64,
    ): &mut PortfolioVault {
        dynamic_object_field::borrow_mut<u64, PortfolioVault>(id, index)
    }

    public(package) fun get_deposit_vault(
        id: &UID,
        index: u64,
    ): &DepositVault {
        dynamic_object_field::borrow<u64, DepositVault>(id, index)
    }

    public(package) fun get_mut_deposit_vault(
        id: &mut UID,
        index: u64,
    ): &mut DepositVault {
        dynamic_object_field::borrow_mut<u64, DepositVault>(id, index)
    }

    public(package) fun get_bid_vault(
        id: &UID,
        index: u64,
    ): &BidVault {
        dynamic_object_field::borrow<u64, BidVault>(id, index)
    }

    public(package) fun get_mut_bid_vault(
        id: &mut UID,
        index: u64,
    ): &mut BidVault {
        dynamic_object_field::borrow_mut<u64, BidVault>(id, index)
    }

    public(package) fun get_additional_config(
        id: &UID,
        index: u64,
    ): &AdditionalConfig {
        dynamic_object_field::borrow<u64, AdditionalConfig>(id, index)
    }

    public(package) fun get_mut_additional_config(
        id: &mut UID,
        index: u64,
    ): &mut AdditionalConfig {
        dynamic_object_field::borrow_mut<u64, AdditionalConfig>(id, index)
    }

    public(package) fun get_additional_config_by_key(
        id: &UID,
        key: vector<u8>
    ): &AdditionalConfig {
        dynamic_object_field::borrow(id, key)
    }

    public(package) fun get_mut_additional_config_by_key(
        id: &mut UID,
        key: vector<u8>
    ): &mut AdditionalConfig {
        dynamic_object_field::borrow_mut(id, key)
    }

    public(package) fun get_bid_vault_by_id_or_index(
        id: &UID,
        vid: &ID,
        index: u64,
    ): &BidVault {
        if (dynamic_object_field::exists_with_type<address, BidVault>(id, object::id_to_address(vid))) {
            dynamic_object_field::borrow<address, BidVault>(id, object::id_to_address(vid))
        } else {
            get_bid_vault(id, index)
        }
    }

    public(package) fun get_bid_vault_by_id(
        id: &UID,
        vid: &ID,
    ): &BidVault {
        dynamic_object_field::borrow<address, BidVault>(id, object::id_to_address(vid))
    }

    public(package) fun get_mut_bid_vault_by_id_or_index(
        id: &mut UID,
        vid: &ID,
        index: u64,
    ): &mut BidVault {
        if (dynamic_object_field::exists_with_type<address, BidVault>(id, object::id_to_address(vid))) {
            dynamic_object_field::borrow_mut<address, BidVault>(id, object::id_to_address(vid))
        } else {
            get_mut_bid_vault(id, index)
        }
    }

    public(package) fun get_mut_bid_vault_by_id(
        id: &mut UID,
        vid: &ID,
    ): &mut BidVault {
        dynamic_object_field::borrow_mut<address, BidVault>(id, object::id_to_address(vid))
    }

    public(package) fun get_refund_vault<TOKEN>(
        id: &UID,
    ): &RefundVault {
        dynamic_object_field::borrow<TypeName, RefundVault>(id, type_name::get<TOKEN>())
    }

    public(package) fun get_mut_refund_vault<TOKEN>(
        id: &mut UID,
    ): &mut RefundVault {
        dynamic_object_field::borrow_mut<TypeName, RefundVault>(id, type_name::get<TOKEN>())
    }

    public(package) fun get_auction(
        id: &UID,
        index: u64,
    ): &Auction {
        assert!(auction_exists(id, index), auction_not_yet_started(index));
        dynamic_object_field::borrow<u64, Auction>(id, index)
    }

    public(package) fun get_mut_auction(
        id: &mut UID,
        index: u64,
    ): &mut Auction {
        assert!(auction_exists(id, index), auction_not_yet_started(index));
        dynamic_object_field::borrow_mut<u64, Auction>(id, index)
    }

    public(package) fun take_auction(
        id: &mut UID,
        index: u64,
    ): Auction {
        assert!(auction_exists(id, index), auction_not_yet_started(index));
        dynamic_object_field::remove<u64, Auction>(id, index)
    }

    public(package) fun health_check(
        registry: &Registry,
        clock: &Clock,
    ): vector<vector<u8>> {

        let mut result = vector::empty();
        let mut index = 0;
        let current_ts_ms = clock::timestamp_ms(clock);
        vector::push_back(&mut result, bcs::to_bytes(&current_ts_ms));
        while (index < registry.num_of_vault) {
            if (portfolio_vault_exists(&registry.portfolio_vault_registry, index)) {
                let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
                if (portfolio_vault.info.expiration_ts_ms < current_ts_ms && portfolio_vault.config.has_next) {
                    vector::push_back(&mut result, bcs::to_bytes(&portfolio_vault.info));
                };
            };
            index = index + 1;
        };

        result
    }

    public(package) fun get_bid_fee_bp(
        id: &UID,
        index: u64,
    ): u64 {
        let portfolio_vault = dynamic_object_field::borrow<u64, PortfolioVault>(id, index);

        portfolio_vault.config.bid_fee_bp
    }

    public(package) fun get_size_decimal(
        id: &UID,
        index: u64,
    ): u64 {
        let portfolio_vault = dynamic_object_field::borrow<u64, PortfolioVault>(id, index);

        portfolio_vault.info.o_token_decimal
    }

    fun update_portfolio_vault_activation_expiration_time(portfolio_vault: &mut PortfolioVault) {
        portfolio_vault.info.activation_ts_ms = portfolio_vault.info.expiration_ts_ms;
        if (portfolio_vault.info.period == 0) {
            portfolio_vault.info.expiration_ts_ms = portfolio_vault.info.expiration_ts_ms + 86400_000;
        } else if (portfolio_vault.info.period == 1) {
            portfolio_vault.info.expiration_ts_ms = portfolio_vault.info.expiration_ts_ms + 604800_000;
        } else if (portfolio_vault.info.period == 2) {
            let (_, m, _) = utils::get_date_from_ts(portfolio_vault.info.expiration_ts_ms / 1000 + 4 * 604800);
            let (_, nm, _) = utils::get_date_from_ts(portfolio_vault.info.expiration_ts_ms / 1000 + 5 * 604800);
            if (m != nm) {
                // 2023/3/31 +4w => 4/28 +5w => 5/5
                portfolio_vault.info.expiration_ts_ms = portfolio_vault.info.expiration_ts_ms + 4 * 604800_000;
            } else {
                // 2023/2/24 +4w => 3/24 +5w => 3/31
                portfolio_vault.info.expiration_ts_ms = portfolio_vault.info.expiration_ts_ms + 5 * 604800_000;
            };
        } else if (portfolio_vault.info.period == 3) {
            portfolio_vault.info.expiration_ts_ms = portfolio_vault.info.expiration_ts_ms + 3600_000;
        } else if (portfolio_vault.info.period == 4) {
            portfolio_vault.info.expiration_ts_ms = portfolio_vault.info.expiration_ts_ms + 600_000;
        };
    }

    // ======== Calculation Functions ========

    public(package) fun calculate_strike(price: u64, strike_bp: u64, strike_increment: u64): u64 {
        let temp = price * strike_bp / 10000;
        if (temp % strike_increment == 0) {
            return temp
        } else {
            return temp / strike_increment * strike_increment + strike_increment
        }
    }

    // Calculate max_auction_size
    // - total_balance = 1_000_000, collateral_per_unit = 4_545_454, leverage = 100
    // - max_size = 1_000_000_000 * 1_000_000 / 4_545_454 = 220_000_026
    // - rounded max_size = 220_000_000
    public(package) fun calculate_max_auction_size(
        o_token_decimal: u64,
        leverage: u64,
        total_balance: u64,
        collateral_per_unit: u64,
        lot_size: u64,
    ): u64 {
        ((utils::multiplier(o_token_decimal) * leverage as u128) * (total_balance as u128)
            / (collateral_per_unit as u128)
            / (utils::multiplier(C_LEVERAGE_DECIMAL) as u128) as u64)
            / lot_size
            * lot_size
    }

    /// max loss per unit contract in d token
    public(package) fun calculate_max_loss_per_unit(
        index: u64,
        option_type: u64,
        price: u64,
        price_decimal: u64,
        d_token_decimal: u64,
        o_token_decimal: u64,
        payoff_configs: vector<PayoffConfig>,
        leverage: u64,
    ): u64 {
        // create vector of pivot prices
        let mut pivot_prices = vector::empty<u64>();
        let min_pivot_price = if (price / 100_000 > 0) {price / 100_000} else {1};
        let max_pivot_price = if (price < C_U64_MAX / 100) {price * 100} else {C_U64_MAX};
        vector::push_back(&mut pivot_prices, min_pivot_price);
        vector::push_back(&mut pivot_prices, max_pivot_price);

        let component_length = vector::length(&payoff_configs);
        let mut i = 0;
        while (i < component_length) {
            let payoff_config = vector::borrow(&payoff_configs, i);
            assert!(option::is_some(&payoff_config.strike), strike_required(index));
            let strike = option::borrow(&payoff_config.strike);
            if (!vector::contains(&pivot_prices, strike)) {
                vector::push_back(&mut pivot_prices, *strike);
            };
            i = i + 1;
        };

        // calculate max loss in pivot prices
        let mut max_loss = i64::zero();
        while (!vector::is_empty(&pivot_prices)) {
            let pivot_price = vector::pop_back(&mut pivot_prices);
            let payoff = calculate_portfolio_payoff_by_price(
                index,
                option_type,
                pivot_price,
                price_decimal,
                d_token_decimal,
                payoff_configs,
                leverage,
                utils::multiplier(o_token_decimal),
                o_token_decimal,  // portfolio payoff per contract,
            );
            if (i64::compare(&max_loss, &payoff) == 2) {
                // Greater Than
                max_loss = payoff;
            };
        };
        assert!(i64::is_neg(&max_loss), invalid_max_loss(index));
        let max_loss = i64::as_u64(&i64::neg(&max_loss));
        assert!(max_loss > 0, invalid_max_loss(index));
        max_loss
    }

    public(package) fun calculate_portfolio_payoff_by_price(
        index: u64,
        option_type: u64,
        price: u64,
        price_decimal: u64,
        d_token_decimal: u64,
        mut payoff_configs: vector<PayoffConfig>,
        leverage: u64,
        contract_size: u64,
        o_token_decimal: u64,
    ): I64 {
        let mut total_payoff_per_contract = i64::zero();

        while (!vector::is_empty(&payoff_configs)) {
            let payoff_config = vector::pop_back(&mut payoff_configs);
            assert!(option::is_some(&payoff_config.strike), strike_required(index));
            let strike = *option::borrow<u64>(&payoff_config.strike);

            // option payoff in price_decimal => d_token_decimal
            let mut option_settle_value = calculate_option_payoff(index, option_type, price, price_decimal, strike);

            let price_multiplier = utils::multiplier(price_decimal);
            let d_token_multiplier = utils::multiplier(d_token_decimal);

            option_settle_value = (
                (option_settle_value as u128)
                * (d_token_multiplier as u128)
                / (price_multiplier as u128) as u64
            );

            let side = if (payoff_config.is_buyer) {
                i64::from(1)
            } else {
                i64::neg_from(1)
            };

            let payoff = i64::div(
                &i64::mul(
                    &i64::mul(
                        &i64::mul(&i64::from(option_settle_value), &side),
                        &i64::from(payoff_config.weight),
                    ),
                    &i64::from(leverage),
                ),
                &i64::from(utils::multiplier(C_LEVERAGE_DECIMAL)),
            );
            total_payoff_per_contract = i64::add(&total_payoff_per_contract, &payoff);
        };
        // expect negative or zero payoff to be returned
        // payoff unit: d_token_decimal (because it is "portfolio" payoff, which is calculating whether depositor have to pay or not)
        i64_mul_div(total_payoff_per_contract, contract_size, utils::multiplier(o_token_decimal))
    }

    /// helper functio to calculate I64
    fun i64_mul_div(value: I64, mul: u64, div: u64): I64 {
        let result = (
            (i64::as_u64(&i64::abs(&value)) as u128)
                * (mul as u128)
                / (div as u128)
            ) as u64;

        if (i64::is_neg(&value)) {
            i64::neg_from(result)
        } else {
            i64::from(result)
        }
    }

    public(package) fun calculate_option_payoff(
        index: u64,
        option_type: u64,
        price: u64,
        price_decimal: u64,
        strike: u64
    ): u64 {
        let long_option_payoff = if (option_type % 2 == 0 && option_type != 6) {
            // call
            if (price >= strike) {
                ((utils::multiplier(price_decimal) as u128) * ((price - strike) as u128)
                    / (price as u128) as u64)
            } else {
                0
            }
        } else if (option_type % 2 == 1) {
            // put
            if (price <= strike) {
                strike - price
            } else {
                0
            }
        } else if (option_type == 6) {
            if (price >= strike) {
                price - strike
            } else {
                0
            }
        } else {
            abort invalid_option_type(index)
        };

        long_option_payoff
    }

    public(package) fun calculate_in_usd<TOKEN>(
        portfolio_vault: &PortfolioVault,
        amount: u64,
        round_up: bool,
    ): u64 {
        let token_decimal = if (type_name::get<TOKEN>() == portfolio_vault.info.deposit_token) {
            portfolio_vault.info.d_token_decimal
        } else if (type_name::get<TOKEN>() == portfolio_vault.info.bid_token) {
            portfolio_vault.info.b_token_decimal
        } else {
            abort invalid_token(portfolio_vault.info.index)
        };
        let benchmark_price = portfolio_vault.info.oracle_info.price;
        let price_decimal = portfolio_vault.info.oracle_info.decimal;

        let usd = if (
            type_name::get<TOKEN>() != portfolio_vault.info.settlement_base
                && type_name::get<TOKEN>() != type_name::get<SUI>()
        ) {
            // USDC, BUCK = 1 ??
            let m = utils::multiplier(token_decimal);
            if (round_up) {
                ((amount - amount % m) / m) + 1
            } else {
                amount / m
            }
        } else {
            let m = (utils::multiplier(token_decimal) as u128) * (utils::multiplier(price_decimal) as u128);
            let amount = (benchmark_price as u128) * (amount as u128);
            if (round_up) {
                (((amount - amount % m) / m) as u64) + 1
            } else {
                ((amount / m) as u64)
            }
        };

        usd
    }

    public(package) fun calculate_in_usd_with_decimal<TOKEN>(
        portfolio_vault: &PortfolioVault,
        amount: u64,
    ): u64 {
        let token_decimal = if (type_name::get<TOKEN>() == portfolio_vault.info.deposit_token) {
            portfolio_vault.info.d_token_decimal
        } else if (type_name::get<TOKEN>() == portfolio_vault.info.bid_token) {
            portfolio_vault.info.b_token_decimal
        } else {
            abort invalid_token(portfolio_vault.info.index)
        };

        if (
            type_name::get<TOKEN>() != portfolio_vault.info.settlement_base
                && type_name::get<TOKEN>() != type_name::get<SUI>()
        ) {
            ((amount as u128)
                * (utils::multiplier(6) as u128)
                / (utils::multiplier(token_decimal) as u128) as u64)
        } else {
            ((amount as u128)
                * (portfolio_vault.info.oracle_info.price as u128)
                / (utils::multiplier(token_decimal) as u128)
                * (utils::multiplier(6) as u128)
                / (utils::multiplier(portfolio_vault.info.oracle_info.decimal) as u128) as u64)
        }
    }

    public(package) fun create_payoff_configs(
        index: u64,
        mut strike_bp: vector<u64>,
        mut weight: vector<u64>,
        mut is_buyer: vector<bool>,
    ): vector<PayoffConfig> {
        assert!(vector::length(&strike_bp) > 0, invalid_payoff_config(index));
        assert!(vector::length(&strike_bp) == vector::length(&weight), invalid_payoff_config(index));
        assert!(vector::length(&weight) == vector::length(&is_buyer), invalid_payoff_config(index));
        let mut payoff_configs = vector::empty();
        while (!vector::is_empty(&strike_bp)) {
            let strike_bp_ = vector::pop_back(&mut strike_bp);
            let weight_ = vector::pop_back(&mut weight);
            let is_buyer_ = vector::pop_back(&mut is_buyer);
            vector::push_back(
                &mut payoff_configs,
                PayoffConfig {
                    strike_bp: strike_bp_,
                    weight: weight_,
                    is_buyer: is_buyer_,
                    strike: option::none(),
                    u64_padding: vector::empty(),
                }
            );
        };

        payoff_configs
    }

    public(package) fun get_new_bid_incentive_balance_value<TOKEN>(
        id: &UID,
        portfolio_vault: &PortfolioVault,
        auction: &Auction,
        size: u64,
        fee_discount: u64,
        clock: &Clock,
    ): (u64, u64) {
        let (_, _, bid_value, fee) = dutch::get_bid_info(
            auction,
            size,
            fee_discount,
            clock::timestamp_ms(clock),
        );
        if (portfolio_vault.config.bid_incentive_bp > 0) {
            let incentive_value = (((bid_value + fee) as u128)
                * (portfolio_vault.config.bid_incentive_bp as u128)
                / (10000 as u128) as u64);
            let incentive: &Balance<TOKEN> = dynamic_field::borrow(id, type_name::get<TOKEN>());
            let available_incentive_amount =
                utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT);
            // conditions to split incentive fund
            // incentive pool enough
            let incentive_usage = if (balance::value(incentive) > incentive_value) {
                // available_incentive_amount enough => split incentive_value
                if (available_incentive_amount >= incentive_value) {
                    incentive_value
                // available_incentive_amount not enough => split available_incentive_amount
                } else {
                    available_incentive_amount
                }
            }
            // incentive pool not enough
            else {
                // cap incentive usage to available_incentive_amount if available_incentive_amount < incentive pool
                if (available_incentive_amount >= balance::value(incentive)) {
                    let incentive_pool_value = balance::value(incentive);
                    incentive_pool_value
                } else {
                    available_incentive_amount
                }
            };
            return (incentive_usage, bid_value+fee-incentive_usage)
        } else {
            return (0, bid_value+fee)
        }
    }

    // get `incentive_usage` from `get_new_bid_incentive_balance_value`
    public(package) fun get_new_bid_incentive_balance<TOKEN>(
        id: &mut UID,
        portfolio_vault: &mut PortfolioVault,
        incentive_usage: u64,
    ): Balance<TOKEN> {
        let mut incentive_balance = balance::zero();

        if (dynamic_field::exists_with_type<TypeName, Balance<TOKEN>>(id, type_name::get<TOKEN>())) {
            let incentive: &mut Balance<TOKEN> = dynamic_field::borrow_mut(id, type_name::get<TOKEN>());
            balance::join(&mut incentive_balance, balance::split(incentive, incentive_usage));

            let available_incentive_amount =
                utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT);

            utils::set_u64_padding_value(
                &mut portfolio_vault.config.u64_padding,
                I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT,
                available_incentive_amount - incentive_usage
            );
        };

        incentive_balance
    }

    public(package) fun get_otc_incentive_balance<TOKEN>(
        id: &mut UID,
        portfolio_vault: &mut PortfolioVault,
        incentive_balance_value: u64,
        incentive_fee: u64,
        depositor_incentive_value: u64,
    ): (Balance<TOKEN>, Balance<TOKEN>, Balance<TOKEN>) {
        let mut incentive_balance = balance::zero();
        let mut incentive_fee_balance = balance::zero();
        let mut depositor_incentive_balance = balance::zero();
        if (dynamic_field::exists_with_type<TypeName, Balance<TOKEN>>(id, type_name::get<TOKEN>())) {
            let incentive: &mut Balance<TOKEN> = dynamic_field::borrow_mut(id, type_name::get<TOKEN>());
            let available_incentive_amount =
                utils::get_u64_padding_value(&portfolio_vault.config.u64_padding, I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT);
            let available_incentive_amount = request_incentive(
                incentive,
                available_incentive_amount,
                incentive_balance_value,
                &mut incentive_balance,
            );
            let available_incentive_amount = request_incentive(
                incentive,
                available_incentive_amount,
                incentive_fee,
                &mut incentive_fee_balance,
            );
            let available_incentive_amount = request_incentive(
                incentive,
                available_incentive_amount,
                depositor_incentive_value,
                &mut depositor_incentive_balance,
            );
            utils::set_u64_padding_value(
                &mut portfolio_vault.config.u64_padding,
                I_CONFIG_AVAILABLE_INCENTIVE_AMOUNT,
                available_incentive_amount
            );
        };

        (incentive_balance, incentive_fee_balance, depositor_incentive_balance)
    }

    public(package) fun request_incentive<TOKEN>(
        incentive: &mut Balance<TOKEN>,
        mut available_incentive_amount: u64,
        request_amount: u64,
        balance:  &mut Balance<TOKEN>,
    ): u64 {
        let available_amount = if (available_incentive_amount >= request_amount) {
            request_amount
        } else {
            available_incentive_amount
        };
        if (balance::value(incentive) > available_amount) {
            available_incentive_amount = available_incentive_amount - available_amount;
            balance::join(balance, balance::split(incentive, available_amount));
        } else {
            available_incentive_amount = available_incentive_amount - balance::value(incentive);
            balance::join(balance, balance::withdraw_all(incentive));
        };

        available_incentive_amount
    }

    public fun calculate_payoff_for_expired_bid_receipts<D_TOKEN>(
        registry: &Registry,
        bid_receipts: &vector<TypusBidReceipt>,
    ): u64 {
        let (_vid, index, _u64_padding) = vault::get_bid_receipt_info(vector::borrow(bid_receipts, 0));
        let bid_vault = get_bid_vault(&registry.bid_vault_registry, index);
        vault::calculate_exercise_value_for_receipts<D_TOKEN>(bid_vault, bid_receipts)
    }

    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun calculate_payoff_for_active_bid_receipt(
        registry: &Registry,
        oracle: &Oracle,
        bid_receipt: &TypusBidReceipt,
        clock: &Clock
    ): u64 { abort 0 }

    fun calculate_payoff_for_active_bid_receipt_v2(
        registry: &Registry,
        oracle: &Oracle,
        d_token_price_oracle: &Oracle,
        bid_receipt: &TypusBidReceipt,
        clock: &Clock
    ): u64 {
        let (vid, index, u64_padding) = vault::get_bid_receipt_info(bid_receipt);
        let share = vector::borrow(&u64_padding, 0);

        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        let bid_vault = get_bid_vault(&registry.bid_vault_registry, index);
        let current_vid = object::id(bid_vault);

        // expired receipt -> return 0 due to payoff config not available
        if (vid != current_vid) {
            return 0
        };

        let (oracle_price, oracle_price_decimal) = oracle::get_price(oracle, clock);

        let depositor_payoff = calculate_portfolio_payoff_by_price(
            index,
            portfolio_vault.info.option_type,
            oracle_price,
            oracle_price_decimal,
            portfolio_vault.info.d_token_decimal,
            portfolio_vault.config.active_vault_config.payoff_configs,
            portfolio_vault.config.leverage,
            *share,
            portfolio_vault.info.o_token_decimal,
        );

        if (i64::is_neg(&depositor_payoff)) {
            let x = i64::as_u64(&i64::abs(&depositor_payoff));
            // check is same
            if (object::id(oracle) == object::id(d_token_price_oracle)) {
                // o token (= d token)
                x
            } else {
                // check d_token_price_oracle
                let (_, _, base_token_type, _) = oracle::get_token(d_token_price_oracle);
                assert!(portfolio_vault.info.deposit_token == base_token_type, invalid_deposit_token(index));
                let (d_token_price, d_token_price_decimal) = oracle::get_price(d_token_price_oracle, clock);
                // USD -> USDC
                (x as u128  * (utils::multiplier(d_token_price_decimal) as u128) / (d_token_price as u128)) as u64
            }
        } else {
            0
        }
    }

    public fun check_bid_receipt_expired(
        registry: &Registry,
        bid_receipt: &TypusBidReceipt
    ): bool {
        let (vid, index, _u64_padding) = vault::get_bid_receipt_info(bid_receipt);
        let bid_vault = get_bid_vault(&registry.bid_vault_registry, index);
        let current_vid = object::id(bid_vault);
        vid != current_vid
    }

    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun check_itm<D_TOKEN>(
        registry: &Registry,
        oracle: &Oracle,
        bid_receipt: &TypusBidReceipt,
        clock: &Clock
    ): bool { abort 0}

    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun get_bid_receipt_intrinsic_value<D_TOKEN>(
        registry: &Registry,
        oracle: &Oracle,
        bid_receipt: &TypusBidReceipt,
        clock: &Clock
    ): u64 { abort 0}

    public fun get_bid_receipt_intrinsic_value_v2<D_TOKEN>(
        registry: &Registry,
        oracle: &Oracle,
        d_token_price_oracle: &Oracle,
        bid_receipt: &TypusBidReceipt,
        clock: &Clock
    ): u64 {
        let is_expired = check_bid_receipt_expired(
            registry,
            bid_receipt,
        );
        if (!is_expired) {
            let active_value = calculate_payoff_for_active_bid_receipt_v2(
                registry,
                oracle,
                d_token_price_oracle,
                bid_receipt,
                clock,
            );
            active_value
        } else {
            let (vid, _index, _u64_padding) = vault::get_bid_receipt_info(bid_receipt);
            let bid_vault = get_bid_vault_by_id(&registry.bid_vault_registry, &vid);
            let exercise_amount = vault::calculate_exercise_value<D_TOKEN>(bid_vault, bid_receipt);
            exercise_amount
        }
    }

    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun verify_bid_receipt_collateral_trading_order<C_TOKEN, BASE_TOKEN>(
        registry: &Registry,
        oracle: &Oracle,
        bid_receipt: &TypusBidReceipt,
        long_order: bool,
        clock: &Clock
    ): vector<u8> { abort 0 }
    // C_TOKEN = D_TOKEN = collateral token, BASE_TOKEN = base of trading symbol = settlement_base
    public fun verify_bid_receipt_collateral_trading_order_v2<C_TOKEN, BASE_TOKEN>(
        registry: &Registry,
        oracle: &Oracle,
        d_token_price_oracle: &Oracle,
        bid_receipt: &TypusBidReceipt,
        long_order: bool,
        clock: &Clock
    ): vector<u8> {
        let (vid, index, _u64_padding) = vault::get_bid_receipt_info(bid_receipt);
        {
            let bid_vault = get_bid_vault(&registry.bid_vault_registry, index);
            let current_vid = object::id(bid_vault);
            if (vid != current_vid) {
                return b"E_BID_RECEIPT_HAS_BEEN_EXPIRED"
            };
        };

        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        if (portfolio_vault.info.status == S_NEW_AUCTION) {
            return b"E_AUCTION_NOT_YET_ENDED"
        };

        let active_value = calculate_payoff_for_active_bid_receipt_v2(
            registry,
            oracle,
            d_token_price_oracle,
            bid_receipt,
            clock,
        );
        if (active_value == 0) {
            return b"E_BID_RECEIPT_NOT_ITM"
        };

        if (type_name::get<BASE_TOKEN>() != portfolio_vault.info.settlement_base) {
            return b"E_BASE_TOKEN_MISMATCHED"
        };

        let option_type = portfolio_vault.info.option_type;
        if (!(
            ((option_type == 0 || option_type == 4 || option_type == 6) && !long_order)
            || ((option_type == 1 || option_type == 5) && long_order)
        )) {
            return b"E_INVALID_ORDER_SIDE"
        };

        if (type_name::get<C_TOKEN>() != portfolio_vault.info.deposit_token) {
            return b"E_COLLATERAL_TOKEN_TYPE_MISMATCHED"
        };
        return b"OK"
    }

    public fun get_deposit_token(
        registry: &Registry,
        index: u64
    ): TypeName {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        portfolio_vault.info.deposit_token
    }

    public fun get_bid_token(
        registry: &Registry,
        index: u64
    ): TypeName {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        portfolio_vault.info.bid_token
    }

    // ======== Validation Functions =========

    public(package) fun version_check(registry: &Registry) {
        assert!(C_VERSION >= registry.version, invalid_version(0));
    }

    public(package) fun operation_check(registry: &Registry) {
        assert!(!registry.transaction_suspended, transaction_suspended(0));
    }

    public(package) fun oracle_check(
        registry: &Registry,
        index: u64,
        oracle: &Oracle,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        assert!(portfolio_vault.config.oracle_id == object::id_address(oracle), invalid_oracle(index));
    }

    public(package) fun portfolio_vault_token_check<D_TOKEN, B_TOKEN>(
        registry: &Registry,
        index: u64,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        assert!(type_name::get<D_TOKEN>() == portfolio_vault.info.deposit_token, invalid_deposit_token(index));
        assert!(type_name::get<B_TOKEN>() == portfolio_vault.info.bid_token, invalid_bid_token(index));
    }

    public(package) fun validate_registry_upgradability(registry: &Registry, ctx: &TxContext) {
        assert!(C_VERSION > registry.version, invalid_version(0));
        authority::verify(&registry.authority, ctx);
    }

    public(package) fun validate_registry_authority(registry: &Registry, ctx: &TxContext) {
        authority::verify(&registry.authority, ctx);
    }

    public(package) fun validate_portfolio_authority(registry: &Registry, index: u64, ctx: &TxContext) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        authority::double_verify(&registry.authority, &portfolio_vault.authority, ctx);
    }

    public(package) fun validate_witness<W: drop>(registry: &Registry, _witness: W, index: u64) {
        let witnesses = dynamic_field::borrow(&registry.id, K_WITNESSES.to_string());
        assert!(linked_set::contains(witnesses, type_name::get<W>()), invalid_witness(index));
    }

    public(package) fun validate_deposit_amount(portfolio_vault: &PortfolioVault, amount: u64) {
        assert!(amount >= portfolio_vault.config.deposit_lot_size
            && amount % portfolio_vault.config.deposit_lot_size == 0, lot_size_violation(portfolio_vault.info.index));
        assert!(amount >= portfolio_vault.config.min_deposit_size, min_size_violation(portfolio_vault.info.index));
    }

    public(package) fun validate_min_deposit_size(portfolio_vault: &PortfolioVault, amount: u64) {
        assert!(amount >= portfolio_vault.config.min_deposit_size, min_size_violation(portfolio_vault.info.index));
    }

    public(package) fun validate_bid(portfolio_vault: &PortfolioVault, auction: &Auction, amount: u64) {
        validate_bid_amount(portfolio_vault, amount);
        assert!(portfolio_vault.config.max_bid_entry == 0
            || dutch::bid_index(auction) < portfolio_vault.config.max_bid_entry, max_bid_entry_reached(portfolio_vault.info.index));
    }

    public(package) fun validate_bid_amount(portfolio_vault: &PortfolioVault, amount: u64) {
        assert!(amount >= portfolio_vault.config.bid_lot_size
            && amount % portfolio_vault.config.bid_lot_size == 0, lot_size_violation(portfolio_vault.info.index));
        assert!(amount >= portfolio_vault.config.min_bid_size, min_size_violation(portfolio_vault.info.index));
    }

    public(package) fun validate_amount(index: u64, amount: u64) {
        assert!(amount > 0, zero_value(index));
    }

    public(package) fun validate_dutch_auction_settings(
        index: u64,
        initial_price: u64,
        final_price: u64,
        auction_duration_ts_ms: u64,
    ) {
        assert!(initial_price >= final_price && final_price > 0, invalid_auction_price(index));
        assert!(auction_duration_ts_ms >= 60_000, invalid_auction_duration_ts_ms(index));
    }

    public(package) fun validate_capacity(
        registry: &Registry,
        index: u64
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        let deposit_vault = get_deposit_vault(&registry.deposit_vault_registry, index);
        assert!(
            vault::active_share_supply(deposit_vault)
                + vault::warmup_share_supply(deposit_vault)
                    <= portfolio_vault.config.capacity,
            max_vault_capacity_reached(index)
        );
        let deposit_shares = vault::get_deposit_shares(deposit_vault);
        assert!(
            portfolio_vault.config.max_deposit_entry == 0 ||
                big_vector::length(deposit_shares) <= portfolio_vault.config.max_deposit_entry,
            max_deposit_entry_reached(index)
        );
    }

    // ======== Authorized Events =========

    public struct ActivateEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        deposit_amount: u64,
        d_token_decimal: u64,
        contract_size: u64,
        o_token_decimal: u64,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_activate_event(
        registry: &Registry,
        index: u64,
        deposit_amount: u64,
        total_deposit_amount: u64,
        contract_size: u64,
        bp_incentive_amount: u64,
        fixed_incentive_amount: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(ActivateEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            deposit_amount,
            d_token_decimal: portfolio_vault.info.d_token_decimal,
            contract_size,
            o_token_decimal: portfolio_vault.info.o_token_decimal,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector[bp_incentive_amount, fixed_incentive_amount, total_deposit_amount],
        });
    }

    public struct NewAuctionEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        start_ts_ms: u64,
        end_ts_ms: u64,
        size: u64,
        vault_config: VaultConfig,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_new_auction_event(
        registry: &Registry,
        index: u64,
        start_ts_ms: u64,
        end_ts_ms: u64,
        size: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(NewAuctionEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            start_ts_ms,
            end_ts_ms,
            size,
            vault_config: portfolio_vault.config.active_vault_config,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector::empty(),
        });
    }

    public struct DeliveryEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        early: bool,
        delivery_price: u64,
        delivery_size: u64,
        o_token_decimal: u64,
        o_token: TypeName,
        bidder_bid_value: u64,
        bidder_fee: u64,
        incentive_bid_value: u64,
        incentive_fee: u64,
        b_token_decimal: u64,
        b_token: TypeName,
        depositor_incentive_value: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_delivery_event(
        registry: &Registry,
        index: u64,
        early: bool,
        mut delivery_log: vector<u64>,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);

        let bid_incentive_bp = vector::pop_back(&mut delivery_log);
        let deposit_incentive_bp_divisor = vector::pop_back(&mut delivery_log);
        let deposit_incentive_bp = vector::pop_back(&mut delivery_log);
        let fixed_incentive_amount = vector::pop_back(&mut delivery_log);
        let bp_incentive_amount = vector::pop_back(&mut delivery_log);
        let incentive_fee = vector::pop_back(&mut delivery_log);
        let incentive_bid_value = vector::pop_back(&mut delivery_log);
        let bidder_fee = vector::pop_back(&mut delivery_log);
        let bidder_bid_value = vector::pop_back(&mut delivery_log);
        let delivery_size = vector::pop_back(&mut delivery_log);
        let delivery_price = vector::pop_back(&mut delivery_log);

        emit(DeliveryEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            early,
            delivery_price,
            delivery_size,
            o_token_decimal: portfolio_vault.info.o_token_decimal,
            o_token: portfolio_vault.info.settlement_base,
            bidder_bid_value,
            bidder_fee,
            incentive_bid_value,
            incentive_fee,
            b_token_decimal: portfolio_vault.info.b_token_decimal,
            b_token: portfolio_vault.info.bid_token,
            depositor_incentive_value: bp_incentive_amount,
            u64_padding: vector[
                fixed_incentive_amount,
                portfolio_vault.info.delivery_infos.max_size,
                deposit_incentive_bp,
                deposit_incentive_bp_divisor,
                bid_incentive_bp
            ],
        });
    }

    public struct AddOtcConfigEvent has copy, drop {
        signer: address,
        user: address,
        index: u64,
        round: u64,
        size: u64,
        price: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_add_otc_config_event(
        user: address,
        index: u64,
        round: u64,
        size: u64,
        price: u64,
        u64_padding: vector<u64>,
        ctx: &TxContext,
    ) {
        emit(AddOtcConfigEvent {
            signer: tx_context::sender(ctx),
            user,
            index,
            round,
            size,
            price,
            u64_padding,
        });
    }

    public struct RemoveOtcConfigEvent has copy, drop {
        signer: address,
        user: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_remove_otc_config_event(
        user: address,
        index: u64,
        ctx: &TxContext,
    ) {
        emit(RemoveOtcConfigEvent {
            signer: tx_context::sender(ctx),
            user,
            index,
            u64_padding: vector::empty(),
        });
    }

    public struct OtcEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        delivery_price: u64,
        delivery_size: u64,
        o_token_decimal: u64,
        bidder_bid_value: u64,
        bidder_fee: u64,
        incentive_bid_value: u64,
        incentive_fee: u64,
        b_token_decimal: u64,
        depositor_incentive_value: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_otc_event(
        registry: &Registry,
        index: u64,
        delivery_price: u64,
        delivery_size: u64,
        bidder_bid_value: u64,
        bidder_fee: u64,
        incentive_bid_value: u64,
        incentive_fee: u64,
        depositor_incentive_value: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(OtcEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            delivery_price,
            delivery_size,
            o_token_decimal: portfolio_vault.info.o_token_decimal,
            bidder_bid_value,
            bidder_fee,
            incentive_bid_value,
            incentive_fee,
            b_token_decimal: portfolio_vault.info.b_token_decimal,
            depositor_incentive_value,
            u64_padding: vector::empty(),
        });
    }

    public struct WitnessOtcEvent has copy, drop {
        witness: TypeName,
        signer: address,
        index: u64,
        round: u64,
        delivery_price: u64,
        delivery_size: u64,
        o_token_decimal: u64,
        bidder_bid_value: u64,
        bidder_fee: u64,
        b_token_decimal: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_witness_otc_event(
        witness: TypeName,
        registry: &Registry,
        index: u64,
        delivery_price: u64,
        delivery_size: u64,
        bidder_bid_value: u64,
        bidder_fee: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(WitnessOtcEvent {
            witness,
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            delivery_price,
            delivery_size,
            o_token_decimal: portfolio_vault.info.o_token_decimal,
            bidder_bid_value,
            bidder_fee,
            b_token_decimal: portfolio_vault.info.b_token_decimal,
            u64_padding: vector::empty(),
        });
    }

    public struct RecoupEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        active_amount: u64,
        deactivating_amount: u64,
        d_token_decimal: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_recoup_event(
        registry: &Registry,
        index: u64,
        active_amount: u64,
        deactivating_amount: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(RecoupEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            active_amount,
            deactivating_amount,
            d_token_decimal: portfolio_vault.info.d_token_decimal,
            u64_padding: vector::empty(),
        });
    }

    public struct SettleEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        oracle_price: u64,
        oracle_price_decimal: u64,
        settle_balance: u64,
        settled_balance: u64,
        d_token_decimal: u64,
        d_token: TypeName,
        share_price: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_settle_event(
        registry: &Registry,
        index: u64,
        oracle_price: u64,
        oracle_price_decimal: u64,
        settle_balance: u64,
        settled_balance: u64,
        share_price: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(SettleEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            oracle_price,
            oracle_price_decimal,
            settle_balance,
            settled_balance,
            d_token_decimal: portfolio_vault.info.d_token_decimal,
            share_price,
            d_token: portfolio_vault.info.deposit_token,
            u64_padding: vector::empty(),
        });
    }

    public struct SkipEvent has copy, drop {
        signer: address,
        index: u64,
        rounds: vector<u64>,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_skip_event(
        index: u64,
        rounds: vector<u64>,
        ctx: &TxContext,
    ) {
        emit(SkipEvent {
            signer: tx_context::sender(ctx),
            index,
            rounds,
            u64_padding: vector::empty(),
        });
    }

    public struct CloseEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_close_event(
        registry: &Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(CloseEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            u64_padding: vector::empty(),
        });
    }

    public struct ResumeEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_resume_event(
        registry: &Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(ResumeEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            u64_padding: vector::empty(),
        });
    }

    public struct TerminateVaultEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_termiante_vault_event(
        registry: &Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(TerminateVaultEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            u64_padding: vector::empty(),
        });
    }

    public struct DropVaultEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_drop_vault_event(
        registry: &Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(DropVaultEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            u64_padding: vector::empty(),
        });
    }

    public struct TerminateAuctionEvent has copy, drop {
        signer: address,
        index: u64,
        round: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_terminate_auction_event(
        registry: &Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        let portfolio_vault = get_portfolio_vault(&registry.portfolio_vault_registry, index);
        emit(TerminateAuctionEvent {
            signer: tx_context::sender(ctx),
            index,
            round: portfolio_vault.info.round,
            u64_padding: vector::empty(),
        });
    }

    // ======== User Events =========

    public struct RaiseFundEvent has copy, drop {
        signer: address,
        token: TypeName,
        log: vector<u64>,
    }
    public(package) fun emit_raise_fund_event(
        portfolio_vault: &PortfolioVault,
        balance_value: u64,
        premium_value: u64,
        fee_amount: u64,
        fee_share_amount: u64,
        inactive_value: u64,
        ctx: &TxContext,
    ) {
        emit(RaiseFundEvent {
            signer: tx_context::sender(ctx),
            token: portfolio_vault.info.deposit_token,
            log: vector[
                portfolio_vault.info.index,
                portfolio_vault.info.round,
                portfolio_vault.info.oracle_info.price,
                portfolio_vault.info.oracle_info.decimal,
                balance_value, // deposit
                premium_value, // compound
                fee_amount, // compound fee
                fee_share_amount, // compound fee share 0
                inactive_value, // subscribe 0
            ],
        });
    }

    public struct ReduceFundEvent has copy, drop {
        signer: address,
        d_token: TypeName,
        b_token: TypeName,
        i_token: TypeName,
        log: vector<u64>,
    }
    public(package) fun emit_reduce_fund_event(
        portfolio_vault: &PortfolioVault,
        d_token: TypeName,
        b_token: TypeName,
        i_token: TypeName,
        warmup_value: u64,
        active_value: u64,
        premium_value: u64,
        premium_fee_amount: u64,
        premium_fee_share_amount: u64,
        inactive_value: u64,
        incentive_value: u64,
        incentive_fee_amount: u64,
        incentive_fee_share_amount: u64,
        ctx: &TxContext,
    ) {
        emit(ReduceFundEvent {
            signer: tx_context::sender(ctx),
            d_token,
            b_token,
            i_token,
            log: vector[
                portfolio_vault.info.index,
                portfolio_vault.info.round,
                portfolio_vault.info.oracle_info.price,
                portfolio_vault.info.oracle_info.decimal,
                warmup_value, // withdraw
                active_value, // unsubscribe
                premium_value, // harvest
                premium_fee_amount, // harvest fee
                premium_fee_share_amount, // harvest fee share 0
                inactive_value, // claim
                incentive_value, // redeem
                incentive_fee_amount, // redeem fee
                incentive_fee_share_amount, // redeem fee share 0
            ],
        });
    }

    public struct RefreshDepositSnapshotEvent has copy, drop {
        signer: address,
        token: TypeName,
        log: vector<u64>,
    }
    public(package) fun emit_refresh_deposit_snapshot_event(
        portfolio_vault: &PortfolioVault,
        snapshot: u64,
        ctx: &TxContext,
    ) {
        emit(RefreshDepositSnapshotEvent {
            signer: tx_context::sender(ctx),
            token: portfolio_vault.info.deposit_token,
            log: vector[
                portfolio_vault.info.index,
                portfolio_vault.info.round,
                portfolio_vault.info.oracle_info.price,
                portfolio_vault.info.oracle_info.decimal,
                snapshot,
            ],
        });
    }

    public struct DepositEvent has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        decimal: u64,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_deposit_event(
        portfolio_vault: &PortfolioVault,
        amount: u64,
        ctx: &TxContext,
    ) {
        emit(DepositEvent {
            signer: tx_context::sender(ctx),
            index: portfolio_vault.info.index,
            token: portfolio_vault.info.deposit_token,
            amount,
            decimal: portfolio_vault.info.d_token_decimal,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector::empty(),
        });
    }

    public struct WithdrawEvent has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        decimal: u64,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_withdraw_event(
        portfolio_vault: &PortfolioVault,
        amount: u64,
        ctx: &TxContext,
    ) {
        emit(WithdrawEvent {
            signer: tx_context::sender(ctx),
            index: portfolio_vault.info.index,
            token: portfolio_vault.info.deposit_token,
            amount,
            decimal: portfolio_vault.info.d_token_decimal,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector::empty(),
        });
    }

    public struct UnsubscribeEvent has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        decimal: u64,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_unsubscribe_event(
        portfolio_vault: &PortfolioVault,
        amount: u64,
        ctx: &TxContext,
    ) {
        emit(UnsubscribeEvent {
            signer: tx_context::sender(ctx),
            index: portfolio_vault.info.index,
            token: portfolio_vault.info.deposit_token,
            amount,
            decimal: portfolio_vault.info.d_token_decimal,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector::empty(),
        });
    }

    public struct ClaimEvent has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        decimal: u64,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_claim_event(
        portfolio_vault: &PortfolioVault,
        amount: u64,
        ctx: &TxContext,
    ) {
        emit(ClaimEvent {
            signer: tx_context::sender(ctx),
            index: portfolio_vault.info.index,
            token: portfolio_vault.info.deposit_token,
            amount,
            decimal: portfolio_vault.info.d_token_decimal,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector::empty(),
        });
    }

    public struct HarvestEvent has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        fee_amount: u64,
        decimal: u64,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_harvest_event(
        portfolio_vault: &PortfolioVault,
        amount: u64,
        fee_amount: u64,
        fee_share_amount: u64,
        ctx: &TxContext,
    ) {
        emit(HarvestEvent {
            signer: tx_context::sender(ctx),
            index: portfolio_vault.info.index,
            token: portfolio_vault.info.bid_token,
            amount,
            fee_amount,
            decimal: portfolio_vault.info.b_token_decimal,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector[fee_share_amount],
        });
    }

    public struct CompoundEvent has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        decimal: u64,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_compound_event(
        portfolio_vault: &PortfolioVault,
        amount: u64,
        fee_amount: u64,
        fee_share_amount: u64,
        ctx: &TxContext,
    ) {
        emit(CompoundEvent {
            signer: tx_context::sender(ctx),
            index: portfolio_vault.info.index,
            token: portfolio_vault.info.bid_token,
            amount,
            decimal: portfolio_vault.info.d_token_decimal,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector[fee_amount, fee_share_amount],
        });
    }

    public struct RedeemEvent has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_redeem_event(
        portfolio_vault: &PortfolioVault,
        token: TypeName,
        amount: u64,
        fee_amount: u64,
        fee_share_amount: u64,
        ctx: &TxContext,
    ) {
        emit(RedeemEvent {
            signer: tx_context::sender(ctx),
            index: portfolio_vault.info.index,
            token,
            amount,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector[fee_amount, fee_share_amount],
        });
    }

    public struct NewBidEvent has copy, drop {
        signer: address,
        index: u64,
        bid_index: u64,
        price: u64,
        size: u64,
        b_token: TypeName,
        o_token: TypeName,
        bidder_balance: u64,
        incentive_balance: u64,
        decimal: u64,
        ts_ms: u64,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_new_bid_event(
        portfolio_vault: &PortfolioVault,
        bid_index: u64,
        price: u64,
        size: u64,
        bidder_balance: u64,
        incentive_balance: u64,
        ts_ms: u64,
        user: address,
    ) {
        emit(NewBidEvent {
            signer: user,
            index: portfolio_vault.info.index,
            bid_index,
            price,
            size,
            b_token: portfolio_vault.info.bid_token,
            o_token: portfolio_vault.info.settlement_base,
            bidder_balance,
            incentive_balance,
            decimal: portfolio_vault.info.b_token_decimal,
            ts_ms,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector::empty(),
        });
    }

    public struct TransferBidReceiptEvent has copy, drop {
        signer: address,
        index: u64,
        amount: u64,
        decimal: u64,
        recipient: address,
        oracle_info: OracleInfo,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_transfer_bid_receipt_event(
        portfolio_vault: &PortfolioVault,
        amount: u64,
        recipient: address,
        ctx: &TxContext,
    ) {
        emit(TransferBidReceiptEvent {
            signer: tx_context::sender(ctx),
            index: portfolio_vault.info.index,
            amount,
            decimal: portfolio_vault.info.o_token_decimal,
            recipient,
            oracle_info: portfolio_vault.info.oracle_info,
            u64_padding: vector::empty(),
        });
    }

    public struct RefundEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_refund_event(
        token: TypeName,
        amount: u64,
        user: address,
    ) {
        emit(RefundEvent {
            signer: user,
            token,
            amount,
            u64_padding: vector::empty(),
        });
    }

    public struct ExerciseEvent has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        amount: u64,
        decimal: u64,
        incentive_token: Option<TypeName>,
        incentive_amount: u64,
        u64_padding: vector<u64>,
    }
    public(package) fun emit_exercise_event(
        index: u64,
        amount: u64,
        share: u64,
        deposit_token: TypeName,
        incentive_token: Option<TypeName>,
        incentive_amount: u64,
        user: address,
    ) {
        emit(ExerciseEvent {
            signer: user,
            index,
            token: deposit_token,
            amount,
            decimal: 0,
            incentive_token,
            incentive_amount,
            u64_padding: vector[share],
        });
    }

    public(package) fun get_round(portfolio_vault: &PortfolioVault): u64 {
        portfolio_vault.info.round
    }

    public(package) fun get_o_token_decimal(portfolio_vault: &PortfolioVault): u64 {
        portfolio_vault.info.o_token_decimal
    }

    public(package) fun get_auction_ts(portfolio_vault: &PortfolioVault): (u64, u64) {
        let start = portfolio_vault.info.activation_ts_ms + portfolio_vault.config.auction_delay_ts_ms;
        (start, portfolio_vault.config.auction_duration_ts_ms)
    }

    // ======== Errors ========

    fun auction_already_started(index: u64): u64 { abort index }
    fun auction_not_yet_started(index: u64): u64 { abort index }
    fun insufficient_balance(index: u64): u64 { abort index }
    fun invalid_action(index: u64): u64 { abort index }
    fun invalid_activation_time(index: u64): u64 { abort index }
    fun invalid_auction_delay_ts_ms(index: u64): u64 { abort index }
    fun invalid_auction_duration_ts_ms(index: u64): u64 { abort index }
    fun invalid_auction_price(index: u64): u64 { abort index }
    fun invalid_bid_lot_size(index: u64): u64 { abort index }
    fun invalid_bid_token(index: u64): u64 { abort index }
    fun invalid_deposit_lot_size(index: u64): u64 { abort index }
    fun invalid_deposit_token(index: u64): u64 { abort index }
    fun invalid_expiration_time(index: u64): u64 { abort index }
    fun invalid_fee_share_setting(index: u64): u64 { abort index }
    fun invalid_input(index: u64): u64 { abort index }
    fun invalid_max_loss(index: u64): u64 { abort index }
    fun invalid_min_bid_size(index: u64): u64 { abort index }
    fun invalid_min_deposit_size(index: u64): u64 { abort index }
    fun invalid_option_type(index: u64): u64 { abort index }
    fun invalid_oracle(index: u64): u64 { abort index }
    fun invalid_payoff_config(index: u64): u64 { abort index }
    fun invalid_period(index: u64): u64 { abort index }
    fun invalid_round(index: u64): u64 { abort index }
    fun invalid_token(index: u64): u64 { abort index }
    fun invalid_version(index: u64): u64 { abort index }
    fun invalid_lending_index(index: u64): u64 { abort index }
    public(package) fun invalid_witness(index: u64): u64 { abort index }
    fun lending_protocol_not_yet_withdrawn(index: u64): u64 { abort index }
    fun lot_size_violation(index: u64): u64 { abort index }
    fun max_bid_entry_reached(index: u64): u64 { abort index }
    fun max_deposit_entry_reached(index: u64): u64 { abort index }
    fun max_size_violation(index: u64): u64 { abort index }
    fun max_vault_capacity_reached(index: u64): u64 { abort index }
    fun min_size_violation(index: u64): u64 { abort index }
    fun navi_disabled(index: u64): u64 { abort index }
    fun not_yet_activated(index: u64): u64 { abort index }
    fun not_yet_expired(index: u64): u64 { abort index }
    fun recoup_not_yet_started(index: u64): u64 { abort index }
    fun scallop_basic_lending_disabled(index: u64): u64 { abort index }
    fun scallop_disabled(index: u64): u64 { abort index }
    fun strike_required(index: u64): u64 { abort index }
    fun suilend_disabled(index: u64): u64 { abort index }
    fun transaction_already_resumed(index: u64): u64 { abort index }
    fun transaction_already_suspended(index: u64): u64 { abort index }
    fun transaction_suspended(index: u64): u64 { abort index }
    fun zero_value(index: u64): u64 { abort index }
    public(package) fun deprecated(index: u64) { abort index }
}