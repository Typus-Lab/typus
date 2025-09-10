module typus_dov::tds_authorized_entry {
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::event::emit;

    use protocol::market::Market;
    use protocol::version::Version;
    use spool::rewards_pool::RewardsPool;
    use spool::spool::Spool;

    use suilend::lending_market::{Self, LendingMarket};
    use suilend::suilend::MAIN_POOL;

    use oracle::config::OracleConfig;
    use oracle::oracle::PriceOracle;

    use typus_dov::typus_dov_single::{Self, Registry, Config, VaultConfig};
    use typus_framework::authority;
    use typus_framework::dutch;
    use typus_framework::utils;
    use typus_framework::vault::TypusBidReceipt;
    use typus_oracle::oracle::Oracle;
    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::witness_lock::HotPotato;

    fun safety_check_without_token(
        registry: &Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::validate_portfolio_authority(registry, index, ctx);
    }

    fun safety_check<D_TOKEN, B_TOKEN>(
        registry: &Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::validate_portfolio_authority(registry, index, ctx);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, index);
    }


    public struct SetCurrentLendingProtocolFlag has copy, drop {
        signer: address,
        index: u64,
        lending_protocol: u64,
    }
    entry fun set_current_lending_protocol_flag(
        registry: &mut Registry,
        index: u64,
        lending_protocol: u64,
        ctx: &TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);


        // main logic
        typus_dov_single::set_current_lending_protocol_flag_(
            registry,
            index,
            lending_protocol,
        );

        // emit event
        emit(SetCurrentLendingProtocolFlag {
            signer: tx_context::sender(ctx),
            index,
            lending_protocol,
        });
    }

    public struct SetSafuVaultIndex has copy, drop {
        signer: address,
        index: u64,
        safu_index: u64,
    }
    entry fun set_safu_vault_index(
        registry: &mut Registry,
        index: u64,
        safu_index: u64,
        ctx: &TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);


        // main logic
        typus_dov_single::set_safu_vault_index_(
            registry,
            index,
            safu_index,
        );

        // emit event
        emit(SetSafuVaultIndex {
            signer: tx_context::sender(ctx),
            index,
            safu_index,
        });
    }

    public struct SetLendingProtocolFlag has copy, drop {
        signer: address,
        index: u64,
        lending_protocol: u64,
    }
    public entry fun set_lending_protocol_flag(
        registry: &mut Registry,
        index: u64,
        lending_protocol: u64,
        ctx: &TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);


        // main logic
        typus_dov_single::set_lending_protocol_flag_(
            registry,
            index,
            lending_protocol,
        );

        // emit event
        emit(SetLendingProtocolFlag {
            signer: tx_context::sender(ctx),
            index,
            lending_protocol,
        });
    }

    public struct AddPortfolioVaultAuthorizedUserEvent has copy, drop {
        signer: address,
        index: u64,
        users: vector<address>,
    }
    entry fun add_portfolio_vault_authorized_user(
        registry: &mut Registry,
        index: u64,
        mut users: vector<address>,
        ctx: &TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_mut_portfolio_vault(portfolio_vault_registry, index);
        while (!vector::is_empty(&users)) {
            let user = vector::pop_back(&mut users);
            authority::add_authorized_user(typus_dov_single::get_mut_portfolio_vault_authority(portfolio_vault), user);
        };

        // emit event
        emit(AddPortfolioVaultAuthorizedUserEvent {
            signer: tx_context::sender(ctx),
            index,
            users: authority::whitelist(typus_dov_single::get_portfolio_vault_authority(portfolio_vault)),
        });
    }

    public struct RemovePortfolioVaultAuthorizedUserEvent has copy, drop {
        signer: address,
        index: u64,
        users: vector<address>,
    }
    entry fun remove_portfolio_vault_authorized_user(
        registry: &mut Registry,
        index: u64,
        mut users: vector<address>,
        ctx: &TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_mut_portfolio_vault(portfolio_vault_registry, index);
        while (!vector::is_empty(&users)) {
            let user = vector::pop_back(&mut users);
            authority::remove_authorized_user(typus_dov_single::get_mut_portfolio_vault_authority(portfolio_vault), user);
        };

        // emit event
        emit(RemovePortfolioVaultAuthorizedUserEvent {
            signer: tx_context::sender(ctx),
            index,
            users: authority::whitelist(typus_dov_single::get_portfolio_vault_authority(portfolio_vault)),
        });
    }

    public struct UpdateConfigEvent has copy, drop {
        signer: address,
        index: u64,
        previous: Config,
        current: Config,
    }
    entry fun update_config(
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
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let (previous, current) = typus_dov_single::update_config_(
            registry,
            index,
            oracle_id,
            deposit_lot_size,
            bid_lot_size,
            min_deposit_size,
            min_bid_size,
            max_deposit_entry,
            max_bid_entry,
            deposit_fee_bp,
            deposit_fee_share_bp,
            deposit_shared_fee_pool,
            bid_fee_bp,
            deposit_incentive_bp,
            bid_incentive_bp,
            auction_delay_ts_ms,
            auction_duration_ts_ms,
            recoup_delay_ts_ms,
            capacity,
            leverage,
            risk_level,
            deposit_incentive_bp_divisor_decimal,
            incentive_fee_bp,
            ctx,
        );

        // emit event
        emit(UpdateConfigEvent {
            signer: tx_context::sender(ctx),
            index,
            previous,
            current,
        });
    }

    entry fun update_oracle(
        registry: &mut Registry,
        index: u64,
        oracle: &Oracle,
        ctx: &TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        typus_dov_single::update_oracle_(
            registry,
            index,
            oracle,
        );
    }

    #[allow(unused_field)]
    public struct UpdateActiveVaultConfigEvent has copy, drop {
        signer: address,
        index: u64,
        previous: VaultConfig,
        current: VaultConfig,
    }

    public struct UpdateWarmupVaultConfigEvent has copy, drop {
        signer: address,
        index: u64,
        previous: VaultConfig,
        current: VaultConfig,
    }
    public(package) entry fun update_warmup_vault_config(
        registry: &mut Registry,
        index: u64,
        strike_pct: vector<u64>,
        weight: vector<u64>,
        is_buyer: vector<bool>,
        strike_increment: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
        ctx: &TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let (previous, current) = typus_dov_single::update_warmup_vault_config_(
            registry,
            index,
            strike_pct,
            weight,
            is_buyer,
            strike_increment,
            decay_speed,
            initial_price,
            final_price,
        );

        // emit event
        emit(UpdateWarmupVaultConfigEvent {
            signer: tx_context::sender(ctx),
            index,
            previous,
            current,
        });
    }

    public struct UpdateStrikeEvent has copy, drop {
        signer: address,
        index: u64,
        oracle_price: u64,
        oracle_price_decimal: u64,
        vault_config: VaultConfig,
    }
    public(package) entry fun update_strike(
        registry: &mut Registry,
        index: u64,
        oracle: &Oracle,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);
        typus_dov_single::oracle_check(registry, index, oracle);

        // main logic
        let (
            oracle_price,
            oracle_price_decimal,
            active_vault_config,
        ) = typus_dov_single::update_strike_(
            registry,
            index,
            oracle,
            clock,
        );

        // emit event
        emit(UpdateStrikeEvent {
            signer: tx_context::sender(ctx),
            index,
            oracle_price,
            oracle_price_decimal,
            vault_config: active_vault_config,
        });
    }

    public struct UpdateAuctionConfigEvent has copy, drop {
        signer: address,
        index: u64,
        start_ts_ms: u64,
        end_ts_ms: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
        fee_bp: u64,
        incentive_bp: u64,
        token_decimal: u64,
        size_decimal: u64,
        able_to_remove_bid: bool,
    }
    public(package) entry fun update_auction_config(
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
        safety_check_without_token(registry, index, ctx);

        typus_dov_single::update_auction_config_(
            registry,
            index,
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

        // emit event
        emit(UpdateAuctionConfigEvent {
            signer: tx_context::sender(ctx),
            index,
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
        });
    }

    public entry fun activate<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry: &mut Registry,
        index: u64,
        oracle: &Oracle,
        d_token_price_oracle: &Oracle,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);
        typus_dov_single::oracle_check(registry, index, oracle);

        // main logic
        let (
            deposit_amount,
            contract_size,
            bp_incentive_amount,
            fixed_incentive_amount,
            total_deposit_amount
        ) = typus_dov_single::activate_<D_TOKEN, B_TOKEN, I_TOKEN>(
            registry,
            index,
            oracle,
            d_token_price_oracle,
            clock,
            ctx,
        );
        typus_dov_single::emit_activate_event(
            registry,
            index,
            deposit_amount,
            total_deposit_amount,
            contract_size,
            bp_incentive_amount,
            fixed_incentive_amount,
            ctx,
        );
    }

    public entry fun new_auction<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        auction_delay_ts_ms: Option<u64>,
        auction_duration_ts_ms: Option<u64>,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let (
            start_ts_ms,
            end_ts_ms,
            size,
        ) = typus_dov_single::new_auction_<B_TOKEN>(
            registry,
            index,
            auction_delay_ts_ms,
            auction_duration_ts_ms,
            ctx,
        );
        typus_dov_single::emit_new_auction_event(
            registry,
            index,
            start_ts_ms,
            end_ts_ms,
            size,
            ctx,
        );
    }

    public entry fun delivery<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry: &mut Registry,
        index: u64,
        early: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let delivery_log = typus_dov_single::delivery_<D_TOKEN, B_TOKEN, I_TOKEN>(
            registry,
            index,
            early,
            clock,
            ctx,
        );
        typus_dov_single::emit_delivery_event(
            registry,
            index,
            early,
            delivery_log,
            ctx,
        );
    }

    public(package) entry fun otc<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        coins: vector<Coin<B_TOKEN>>,
        delivery_price: u64,
        delivery_size: u64,
        bidder_bid_value: u64,
        bidder_fee_balance_value: u64,
        incentive_bid_value: u64,
        incentive_fee_balance_value: u64,
        depositor_incentive_value: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let (
            id,
            _num_of_vault,
            _authority,
            _fee_pool,
            portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let portfolio_vault = typus_dov_single::get_mut_portfolio_vault(portfolio_vault_registry, index);
        let mut bidder_balance = utils::extract_balance(coins, bidder_bid_value + bidder_fee_balance_value, ctx);
        let bidder_fee_balance = balance::split(&mut bidder_balance, bidder_fee_balance_value);
        let (incentive_balance, incentive_fee_balance, depositor_incentive_balance) =
            typus_dov_single::get_otc_incentive_balance(id, portfolio_vault, incentive_bid_value, incentive_fee_balance_value, depositor_incentive_value);
        typus_dov_single::otc_<D_TOKEN, B_TOKEN>(
            registry,
            index,
            option::none(),
            delivery_price,
            delivery_size,
            bidder_balance,
            bidder_fee_balance,
            incentive_balance,
            incentive_fee_balance,
            depositor_incentive_balance,
            clock,
            ctx,
        );
        typus_dov_single::emit_otc_event(
            registry,
            index,
            delivery_price,
            delivery_size,
            bidder_bid_value,
            bidder_fee_balance_value,
            incentive_bid_value,
            incentive_fee_balance_value,
            depositor_incentive_value,
            ctx,
        );
    }

    #[allow(dead_code, unused_variable, unused_type_parameter)]
    public fun safu_otc<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        delivery_price: u64,
        balance: Balance<B_TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Option<TypusBidReceipt>, Balance<B_TOKEN>, vector<u64>) {
        abort 0
    }

    public fun safu_otc_v2<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        delivery_price: u64,
        balance: Balance<B_TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Option<TypusBidReceipt>, vector<u64>) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let (receipt, log) = typus_dov_single::public_safu_otc_v2_<D_TOKEN, B_TOKEN>(
            registry,
            index,
            delivery_price,
            balance,
            clock,
            ctx,
        );
        typus_dov_single::emit_otc_event(
            registry,
            index,
            log[0],
            log[1],
            log[2],
            log[3],
            0,
            0,
            0,
            ctx,
        );

        (receipt, log)
    }

    public fun airdrop_otc<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        delivery_price: u64,
        bid_balance: Balance<B_TOKEN>,
        fee_balance: Balance<B_TOKEN>,
        users: vector<address>,
        sizes: vector<u64>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let log = typus_dov_single::airdrop_otc_<D_TOKEN, B_TOKEN>(
            registry,
            index,
            delivery_price,
            bid_balance,
            fee_balance,
            users,
            sizes,
            clock,
            ctx,
        );
        typus_dov_single::emit_otc_event(
            registry,
            index,
            log[0],
            log[1],
            log[2],
            log[3],
            0,
            0,
            0,
            ctx,
        );

        log
    }

    public entry fun recoup<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        clock: &Clock,
        ctx: & TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let (active_amount, deactivating_amount) = typus_dov_single::recoup_<D_TOKEN>(
            registry,
            index,
            clock,
            ctx,
        );
        typus_dov_single::emit_recoup_event(
            registry,
            index,
            active_amount,
            deactivating_amount,
            ctx,
        );
    }

    public entry fun settle<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        oracle: &Oracle,
        d_token_oracle: &Oracle,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);
        typus_dov_single::oracle_check(registry, index, oracle);

        // main logic
        let (
            oracle_price,
            oracle_price_decimal,
            settle_balance,
            settled_balance,
            share_price,
            skipped_rounds,
        ) = typus_dov_single::settle_<D_TOKEN, B_TOKEN>(
            registry,
            index,
            oracle,
            d_token_oracle,
            clock,
            ctx,
        );
        typus_dov_single::emit_settle_event(
            registry,
            index,
            oracle_price,
            oracle_price_decimal,
            settle_balance,
            settled_balance,
            share_price,
            ctx,
        );
        if (!skipped_rounds.is_empty()) {
            typus_dov_single::emit_skip_event(
                index,
                skipped_rounds,
                ctx,
            );
        }
    }

    public(package) entry fun skip<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let (
            _oracle_price,
            _oracle_price_decimal,
            _settle_balance,
            _settled_balance,
            _share_price,
            skipped_rounds,
        ) = typus_dov_single::skip_<D_TOKEN, B_TOKEN>(
            registry,
            index,
            clock,
            ctx,
        );
        typus_dov_single::emit_skip_event(
            index,
            skipped_rounds,
            ctx,
        );
    }

    public(package) entry fun close<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        typus_dov_single::emit_close_event(
            registry,
            index,
            ctx,
        );
        typus_dov_single::close_(registry, index);
    }

    public(package) entry fun resume<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        typus_dov_single::emit_resume_event(
            registry,
            index,
            ctx,
        );
        typus_dov_single::resume_(registry, index);
    }


    public(package) entry fun terminate_vault<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        ctx: & TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        typus_dov_single::emit_termiante_vault_event(
            registry,
            index,
            ctx,
        );
        typus_dov_single::terminate_<D_TOKEN>(registry, index, ctx);
    }

    public(package) entry fun drop_vault<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        ctx: & TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        typus_dov_single::emit_drop_vault_event(
            registry,
            index,
            ctx,
        );
        typus_dov_single::drop_<D_TOKEN, B_TOKEN>(registry, index, ctx);
    }

    public(package) entry fun terminate_auction<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        ctx: & TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        typus_dov_single::emit_terminate_auction_event(
            registry,
            index,
            ctx,
        );
        let (
            id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            auction_registry,
            _bid_vault_registry,
            refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let auction = typus_dov_single::take_auction(auction_registry, index);
        let refund_vault = typus_dov_single::get_mut_refund_vault<B_TOKEN>(refund_vault_registry);
        let incentive_refund = dutch::terminate<B_TOKEN>(
            auction,
            refund_vault,
            ctx,
        );
        if (balance::value(&incentive_refund) > 0) {
            let balance = dynamic_field::borrow_mut(id, type_name::get<B_TOKEN>());
            balance::join(balance, incentive_refund);
        } else {
            balance::destroy_zero(incentive_refund)
        };
    }

    public struct CreateScallopSpoolAccount has copy, drop {
        signer: address,
        index: u64,
        spool_id: address,
        spool_account_id: address,
    }
    public(package) entry fun create_scallop_spool_account<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        spool: &mut Spool,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let (spool_id, spool_account_id) = typus_dov_single::create_scallop_spool_account_<D_TOKEN>(
            registry,
            index,
            spool,
            clock,
            ctx,
        );

        // emit event
        emit(CreateScallopSpoolAccount {
            signer: tx_context::sender(ctx),
            index,
            spool_id,
            spool_account_id,
        });
    }

    #[allow(unused_field)]
    public struct EnableScallop has copy, drop {
        signer: address,
        index: u64,
    }
    #[allow(unused_field)]
    public struct DisableScallop has copy, drop {
        signer: address,
        index: u64,
    }

    public struct DepositScallop has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public(package) entry fun deposit_scallop<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        version: &Version,
        market: &mut Market,
        spool: &mut Spool,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::deposit_scallop_<D_TOKEN>(
            registry,
            index,
            version,
            market,
            spool,
            clock,
            ctx,
        );

        // emit event
        emit(DepositScallop {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct WithdrawScallop has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public(package) entry fun withdraw_scallop<D_TOKEN, B_TOKEN, R_TOKEN>(
        registry: &mut Registry,
        index: u64,
        version: &Version,
        market: &mut Market,
        spool: &mut Spool,
        rewards_pool: &mut RewardsPool<R_TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::withdraw_scallop_<D_TOKEN, R_TOKEN>(
            registry,
            index,
            version,
            market,
            spool,
            rewards_pool,
            clock,
            ctx,
        );

        // emit event
        emit(WithdrawScallop {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct FixedIncentiviseEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
        fixed_incentive_amount: u64,
    }
    public(package) entry fun fixed_incentivise<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry: &mut Registry,
        index: u64,
        coin: Coin<I_TOKEN>,
        fixed_incentive_amount: u64,
        ctx: &TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        let amount = typus_dov_single::fixed_incentivise_(registry, index, coin, fixed_incentive_amount);

        // emit event
        emit(FixedIncentiviseEvent {
            signer: tx_context::sender(ctx),
            token: type_name::get<I_TOKEN>(),
            amount,
            fixed_incentive_amount,
        });
    }

    public struct WithdrawFixedIncentiveEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
    }
    #[lint_allow(self_transfer)]
    public(package) entry fun withdraw_fixed_incentive<I_TOKEN>(
        registry: &mut Registry,
        index: u64,
        fixed_incentive_amount: Option<u64>,
        ctx: &mut TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        let incentive_coin = typus_dov_single::withdraw_fixed_incentive_<I_TOKEN>(registry, index, fixed_incentive_amount, ctx);
        let amount = coin::value(&incentive_coin);
        transfer::public_transfer(incentive_coin, tx_context::sender(ctx));

        // emit event
        emit(WithdrawFixedIncentiveEvent {
            signer: tx_context::sender(ctx),
            token: type_name::get<I_TOKEN>(),
            amount,
        });
    }

    // ======= scallop basic lending =======
    #[allow(unused_field)]
    public struct EnableScallopBasicLending has copy, drop {
        signer: address,
        index: u64,
    }
    #[allow(unused_field)]
    public struct DisableScallopBasicLending has copy, drop {
        signer: address,
        index: u64,
    }

    public struct DepositScallopBasicLending has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public entry fun deposit_scallop_basic_lending<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::deposit_scallop_basic_lending_<D_TOKEN>(
            registry,
            index,
            version,
            market,
            clock,
            ctx,
        );

        // emit event
        emit(DepositScallopBasicLending {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct WithdrawScallopBasicLending has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public entry fun withdraw_scallop_basic_lending<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::withdraw_scallop_basic_lending_<D_TOKEN>(
            registry,
            index,
            version,
            market,
            clock,
            ctx,
        );

        // emit event
        emit(WithdrawScallopBasicLending {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    // ======= additional lending =======
    public struct EnableAdditionalLending has copy, drop {
        signer: address,
        index: u64,
    }
    public(package) entry fun enable_additional_lending<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        ctx: & TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        typus_dov_single::set_enable_additional_lending_flag_(registry, index, true);

        // emit event
        emit(EnableAdditionalLending {
            signer: tx_context::sender(ctx),
            index,
        });
    }

    public struct DisableAdditionalLending has copy, drop {
        signer: address,
        index: u64,
    }
    public(package) entry fun disable_additional_lending<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        ctx: & TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        typus_dov_single::set_enable_additional_lending_flag_(registry, index, false);

        // emit event
        emit(DisableAdditionalLending {
            signer: tx_context::sender(ctx),
            index,
        });
    }

    #[allow(unused_field)]
    public struct DepositAdditionalLending has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    #[allow(unused_field)]
    public struct WithdrawAdditionalLending has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    #[allow(unused_field)]
    public struct EnableSuilend has copy, drop {
        signer: address,
        index: u64,
    }
    #[allow(unused_field)]
    public struct DisableSuilend has copy, drop {
        signer: address,
        index: u64,
    }

    public struct CreateSuilendObligationOwnerCap has copy, drop {
        signer: address,
        index: u64,
        lending_market_id: address,
        obligation_owner_cap_id: address,
    }
    public(package) entry fun create_suilend_obligation_owner_cap<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let (lending_market_id, obligation_owner_cap_id) = typus_dov_single::create_suilend_obligation_owner_cap_(
            registry,
            index,
            suilend_lending_market,
            ctx,
        );

        // emit event
        emit(CreateSuilendObligationOwnerCap {
            signer: tx_context::sender(ctx),
            index,
            lending_market_id,
            obligation_owner_cap_id,
        });
    }

    public struct DepositSuilend has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public(package) entry fun deposit_suilend<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::deposit_suilend_<D_TOKEN>(
            registry,
            index,
            suilend_lending_market,
            reserve_array_index,
            clock,
            ctx,
        );

        // emit event
        emit(DepositSuilend {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public(package) entry fun refresh_suilend_reserve_price(
        lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        clock: &Clock,
        price_info: &pyth::price_info::PriceInfoObject,
    ) {
        lending_market::refresh_reserve_price(lending_market, reserve_array_index, clock, price_info);
    }

    public struct WithdrawSuilend has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public(package) entry fun withdraw_suilend<D_TOKEN, B_TOKEN, R_TOKEN>(
        registry: &mut Registry,
        index: u64,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        reward_index: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::withdraw_suilend_<D_TOKEN, R_TOKEN>(
            registry,
            index,
            suilend_lending_market,
            reserve_array_index,
            reward_index,
            clock,
            ctx,
        );

        // emit event
        emit(WithdrawSuilend {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct RewardSuilend has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public(package) entry fun reward_suilend<D_TOKEN, B_TOKEN, R_TOKEN>(
        registry: &mut Registry,
        index: u64,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        reward_index: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::reward_suilend_<R_TOKEN>(
            registry,
            index,
            suilend_lending_market,
            reserve_array_index,
            reward_index,
            clock,
            ctx,
        );

        // emit event
        emit(RewardSuilend {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct CreateNaviAccountCap has copy, drop {
        signer: address,
        index: u64,
        account_cap_id: address,
    }
    public(package) entry fun create_navi_account_cap(
        registry: &mut Registry,
        index: u64,
        ctx: &mut TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let account_cap_id = typus_dov_single::create_navi_account_cap_(registry, index, ctx);

        // emit event
        emit(CreateNaviAccountCap {
            signer: tx_context::sender(ctx),
            index,
            account_cap_id,
        });
    }


    public struct DepositNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public entry fun deposit_navi<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<D_TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::deposit_navi_<D_TOKEN>(
            registry,
            index,
            storage,
            pool,
            asset,
            incentive_v2,
            incentive_v3,
            clock,
            ctx,
        );

        // emit event
        emit(DepositNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct WithdrawNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public entry fun withdraw_navi<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
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
        clock: &Clock,
        ctx: &TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::withdraw_navi_<D_TOKEN>(
            registry,
            index,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
            storage,
            pool,
            asset,
            incentive_v2,
            incentive_v3,
            clock,
        );

        // emit event
        emit(WithdrawNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }


    public struct RewardNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public fun pre_reward_navi<D_TOKEN, B_TOKEN, R_TOKEN>(
        registry: &mut Registry,
        index: u64,
        storage: &mut lending_core::storage::Storage,
        reward_fund: &mut lending_core::incentive_v3::RewardFund<R_TOKEN>,
        coin_types: vector<std::ascii::String>,
        rule_ids: vector<address>,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
        ctx: &TxContext,
    ): Balance<R_TOKEN> {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        typus_dov_single::reward_navi_<R_TOKEN>(
            registry,
            index,
            storage,
            reward_fund,
            coin_types,
            rule_ids,
            incentive_v3,
            clock,
        )
    }
    public fun post_reward_navi<D_TOKEN, B_TOKEN, R_TOKEN>(
        registry: &mut Registry,
        index: u64,
        rewards: vector<Balance<R_TOKEN>>,
        ctx: &TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::reward_from_lending_<R_TOKEN>(
            registry,
            index,
            rewards,
        );

        emit(RewardNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct BorrowNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public entry fun borrow_navi<TOKEN>(
        registry: &mut Registry,
        index: u64,
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
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::borrow_navi_<TOKEN>(
            registry,
            index,
            deposit_index,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
            storage,
            pool,
            asset,
            incentive_v2,
            incentive_v3,
            amount,
            clock,
            ctx,
        );

        // emit event
        emit(BorrowNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct UnsubscribeNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public entry fun unsubscribe_navi<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry: &mut Registry,
        index: u64,
        deposit_index: u64,
        ctx: &mut TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::unsubscribe_navi_<D_TOKEN, B_TOKEN, I_TOKEN>(
            registry,
            index,
            deposit_index,
            ctx,
        );

        // emit event
        emit(UnsubscribeNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct RepayNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public entry fun repay_navi<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry: &mut Registry,
        index: u64,
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
        coin: Coin<D_TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::repay_navi_<D_TOKEN, B_TOKEN, I_TOKEN>(
            registry,
            index,
            deposit_index,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
            storage,
            pool,
            asset,
            incentive_v2,
            incentive_v3,
            coin.into_balance(),
            clock,
            ctx,
        );

        // emit event
        emit(RepayNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct RepayNaviInterest has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    entry fun repay_navi_interest<TOKEN, I_TOKEN>(
        registry: &mut Registry,
        index: u64,
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
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::repay_navi_interest_<TOKEN, I_TOKEN>(
            registry,
            index,
            deposit_index,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
            storage,
            pool,
            asset,
            incentive_v2,
            incentive_v3,
            warmup_amount,
            clock,
            ctx,
        );

        // emit event
        emit(RepayNaviInterest {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct DepositCollateralNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public entry fun deposit_collateral_navi<TOKEN>(
        registry: &mut Registry,
        index: u64,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        coin: Coin<TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::deposit_collateral_navi_<TOKEN>(
            registry,
            index,
            storage,
            pool,
            asset,
            incentive_v2,
            incentive_v3,
            coin.into_balance(),
            clock,
            ctx,
        );

        // emit event
        emit(DepositCollateralNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct WithdrawCollateralNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public entry fun withdraw_collateral_navi<TOKEN>(
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
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::withdraw_collateral_navi_<TOKEN>(
            registry,
            index,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
            storage,
            pool,
            asset,
            incentive_v2,
            incentive_v3,
            amount,
            clock,
            ctx,
        );

        // emit event
        emit(WithdrawCollateralNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    public struct PreRepayNaviInterest has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public fun pre_repay_navi_interest<D_TOKEN, B_TOKEN, I_TOKEN>(
        version: &TypusEcosystemVersion,
        registry: &mut Registry,
        index: u64,
        deposit_index: u64,
        ctx: &mut TxContext,
    ): (HotPotato<Balance<I_TOKEN>>, vector<u64>) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let (balance, u64_padding) = typus_dov_single::pre_repay_navi_interest_<D_TOKEN, B_TOKEN, I_TOKEN>(
            version,
            registry,
            index,
            deposit_index,
            ctx,
        );

        // emit event
        emit(PreRepayNaviInterest {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });

        (balance, u64_padding)
    }


    public struct PostRepayNaviInterest has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public fun post_repay_navi_interest_<TOKEN>(
        version: &TypusEcosystemVersion,
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
        balance: HotPotato<Balance<TOKEN>>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::post_repay_navi_interest_<TOKEN>(
            version,
            registry,
            index,
            oracle_config,
            price_oracle,
            supra_oracle_holder,
            pyth_price_info,
            feed_address,
            storage,
            pool,
            asset,
            incentive_v2,
            incentive_v3,
            balance,
            clock,
            ctx,
        );

        // emit event
        emit(PostRepayNaviInterest {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }
}