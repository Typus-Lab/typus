module typus_dov::tds_authorized_entry {
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::event::emit;
    use sui_system::sui_system::SuiSystemState;

    use protocol::market::Market;
    use protocol::version::Version;

    use oracle::config::OracleConfig;
    use oracle::oracle::PriceOracle;

    use typus_dov::typus_dov_single::{Self, Registry, Config, VaultConfig, Info};
    use typus_framework::authority;
    use typus_framework::dutch;
    use typus_framework::utils;
    use typus_framework::vault::TypusBidReceipt;
    use typus_oracle::oracle::Oracle;
    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::witness_lock::HotPotato;

    /// Performs a safety check for authorized functions that do not involve tokens.
    fun safety_check_without_index(
        registry: &Registry,
        ctx: &TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::validate_registry_authority(registry, ctx);
    }

    /// Performs a safety check for authorized functions that do not involve tokens.
    fun safety_check_without_token(
        registry: &Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::validate_portfolio_authority(registry, index, ctx);
    }

    /// Performs a safety check for authorized functions that involve tokens.
    fun safety_check<D_TOKEN, B_TOKEN>(
        registry: &Registry,
        index: u64,
        ctx: &TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::validate_portfolio_authority(registry, index, ctx);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, index);
    }


    /// Event emitted when the current lending protocol flag is set.
    public struct SetCurrentLendingProtocolFlag has copy, drop {
        signer: address,
        index: u64,
        lending_protocol: u64,
    }
    /// [Authorized Function] Sets the current lending protocol flag.
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

    /// Event emitted when the SAFU vault index is set.
    public struct SetSafuVaultIndex has copy, drop {
        signer: address,
        index: u64,
        safu_index: u64,
    }
    /// [Authorized Function] Sets the SAFU vault index.
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

    /// Event emitted when the lending protocol flag is set.
    public struct SetLendingProtocolFlag has copy, drop {
        signer: address,
        index: u64,
        lending_protocol: u64,
    }
    /// [Authorized Function] Sets the lending protocol flag.
    public fun set_lending_protocol_flag(
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

    /// Event emitted when an authorized user is added to a portfolio vault.
    public struct AddPortfolioVaultAuthorizedUserEvent has copy, drop {
        signer: address,
        index: u64,
        users: vector<address>,
    }
    /// [Authorized Function] Adds an authorized user to a portfolio vault.
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

    /// Event emitted when an authorized user is removed from a portfolio vault.
    public struct RemovePortfolioVaultAuthorizedUserEvent has copy, drop {
        signer: address,
        index: u64,
        users: vector<address>,
    }
    /// [Authorized Function] Removes an authorized user from a portfolio vault.
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

    /// Event emitted when the configuration of a portfolio vault is updated.
    public struct UpdateConfigEvent has copy, drop {
        signer: address,
        index: u64,
        previous: Config,
        current: Config,
    }
    /// [Authorized Function] Updates the configuration of a portfolio vault.
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
        shared_navi_amount: Option<u64>,
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
            shared_navi_amount,
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

    /// [Authorized Function] Updates the oracle for a portfolio vault.
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

    /// Event emitted when the warmup vault configuration is updated.
    public struct UpdateWarmupVaultConfigEvent has copy, drop {
        signer: address,
        index: u64,
        previous: VaultConfig,
        current: VaultConfig,
    }
    /// [Authorized Function] Updates the warmup vault configuration.
    public fun update_warmup_vault_config(
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

    /// Event emitted when the strike price is updated.
    public struct UpdateStrikeEvent has copy, drop {
        signer: address,
        index: u64,
        oracle_price: u64,
        oracle_price_decimal: u64,
        vault_config: VaultConfig,
    }
    /// [Authorized Function] Updates the strike price based on the oracle price.
    public fun update_strike(
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

    #[deprecated]
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
    #[deprecated, allow(unused)]
    public fun update_auction_config(
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
    ) { abort 0 }

    /// [Authorized Function] Activates a vault.
    public fun activate<D_TOKEN, B_TOKEN, I_TOKEN>(
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

    /// [Authorized Function] Creates a new auction.
    public fun new_auction<D_TOKEN, B_TOKEN>(
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

    /// [Authorized Function] Delivers the results of an auction.
    public fun delivery<D_TOKEN, B_TOKEN, I_TOKEN>(
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

    /// [Authorized Function] Handles an over-the-counter deal.
    public fun otc<D_TOKEN, B_TOKEN>(
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

    /// [Authorized Function] Handles a SAFU over-the-counter deal.
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

    /// [Authorized Function] Handles an airdrop over-the-counter deal.
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

    /// [Authorized Function] Recoups funds after an auction.
    public fun recoup<D_TOKEN, B_TOKEN>(
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

    /// [Authorized Function] Settles a vault.
    public fun settle<D_TOKEN, B_TOKEN>(
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

    /// [Authorized Function] Skips a round.
    public fun skip<D_TOKEN, B_TOKEN>(
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

    /// [Authorized Function] Closes a vault.
    public fun close<D_TOKEN, B_TOKEN>(
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

    /// [Authorized Function] Resumes a vault.
    public fun resume<D_TOKEN, B_TOKEN>(
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


    /// [Authorized Function] Terminates a vault.
    public fun terminate_vault<D_TOKEN, B_TOKEN>(
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

    /// [Authorized Function] Drops a vault.
    public fun drop_vault<D_TOKEN, B_TOKEN>(
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

    /// [Authorized Function] Terminates an auction.
    public fun terminate_auction<D_TOKEN, B_TOKEN>(
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
            let balance = dynamic_field::borrow_mut(id, type_name::with_defining_ids<B_TOKEN>());
            balance::join(balance, incentive_refund);
        } else {
            balance::destroy_zero(incentive_refund)
        };
    }

    /// Event emitted when fixed incentives are added.
    public struct FixedIncentiviseEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
        fixed_incentive_amount: u64,
    }
    /// [Authorized Function] Adds fixed incentives to a vault.
    public fun fixed_incentivise<D_TOKEN, B_TOKEN, I_TOKEN>(
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
            token: type_name::with_defining_ids<I_TOKEN>(),
            amount,
            fixed_incentive_amount,
        });
    }

    /// Event emitted when fixed incentives are withdrawn.
    public struct WithdrawFixedIncentiveEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
    }
    /// [Authorized Function] Withdraws fixed incentives from a vault.
    #[lint_allow(self_transfer)]
    public fun withdraw_fixed_incentive<I_TOKEN>(
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
            token: type_name::with_defining_ids<I_TOKEN>(),
            amount,
        });
    }

    /// Event emitted when funds are deposited to Scallop for basic lending.
    public struct DepositScallopBasicLending has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Deposits funds to Scallop for basic lending.
    public fun deposit_scallop_basic_lending<D_TOKEN, B_TOKEN>(
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

    /// Event emitted when funds are withdrawn from Scallop for basic lending.
    public struct WithdrawScallopBasicLending has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Withdraws funds from Scallop for basic lending.
    public fun withdraw_scallop_basic_lending<D_TOKEN, B_TOKEN>(
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

    /// Event emitted when additional lending is enabled.
    public struct EnableAdditionalLending has copy, drop {
        signer: address,
        index: u64,
    }
    /// [Authorized Function] Enables additional lending for a vault.
    public fun enable_additional_lending<D_TOKEN, B_TOKEN>(
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

    /// Event emitted when additional lending is disabled.
    public struct DisableAdditionalLending has copy, drop {
        signer: address,
        index: u64,
    }
    /// [Authorized Function] Disables additional lending for a vault.
    public fun disable_additional_lending<D_TOKEN, B_TOKEN>(
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

    /// Event emitted when a Navi account cap is created.
    public struct CreateNaviAccountCap has copy, drop {
        signer: address,
        index: u64,
        account_cap_id: address,
    }
    /// [Authorized Function] Creates a Navi account cap.
    public fun create_navi_account_cap(
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


    /// Event emitted when funds are deposited to Navi.
    public struct DepositNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Deposits funds to Navi.
    public fun deposit_navi<D_TOKEN, B_TOKEN>(
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
    public struct DepositSharedNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public fun deposit_shared_navi<D_TOKEN, B_TOKEN>(
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
        let u64_padding = typus_dov_single::deposit_shared_navi_<D_TOKEN>(
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
        emit(DepositSharedNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }
    public struct DepositHybridNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Deposits funds to Navi.
    public fun deposit_hybrid_navi<D_TOKEN, B_TOKEN>(
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
        let u64_padding = typus_dov_single::deposit_hybrid_navi_<D_TOKEN>(
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
        emit(DepositHybridNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    /// Event emitted when funds are withdrawn from Navi.
    public struct WithdrawNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public fun withdraw_navi_v3<D_TOKEN, B_TOKEN>(
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
        system_state: &mut SuiSystemState,
        clock: &Clock,
        ctx: &mut TxContext,
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
            system_state,
            clock,
            ctx,
        );

        // emit event
        emit(WithdrawNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }
    public struct WithdrawSharedNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public fun withdraw_shared_navi<D_TOKEN, B_TOKEN>(
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
        system_state: &mut SuiSystemState,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::withdraw_shared_navi_<D_TOKEN>(
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
            system_state,
            clock,
            ctx,
        );

        // emit event
        emit(WithdrawSharedNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }
    public struct WithdrawHybridNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public fun withdraw_hybrid_navi<D_TOKEN, B_TOKEN>(
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
        system_state: &mut SuiSystemState,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check<D_TOKEN, B_TOKEN>(registry, index, ctx);

        // main logic
        let u64_padding = typus_dov_single::withdraw_hybrid_navi_<D_TOKEN>(
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
            system_state,
            clock,
            ctx,
        );

        // emit event
        emit(WithdrawHybridNavi {
            signer: tx_context::sender(ctx),
            index,
            u64_padding,
        });
    }

    /// Event emitted when rewards are claimed from Navi.
    public struct RewardNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Pre-claims rewards from Navi. This is the first step in a two-step process.
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
    public struct RewardSharedNavi has copy, drop {
        signer: address,
        u64_padding: vector<u64>,
    }
    public fun reward_shared_navi<TOKEN>(
        registry: &mut Registry,
        storage: &mut lending_core::storage::Storage,
        reward_fund: &mut lending_core::incentive_v3::RewardFund<TOKEN>,
        coin_types: vector<std::ascii::String>,
        rule_ids: vector<address>,
        incentive_v3: &mut lending_core::incentive_v3::Incentive,
        clock: &Clock,
        ctx: &TxContext,
    ): Balance<TOKEN> {
        safety_check_without_index(registry, ctx);

        // main logic
        let balance = typus_dov_single::reward_shared_navi_<TOKEN>(
            registry,
            storage,
            reward_fund,
            coin_types,
            rule_ids,
            incentive_v3,
            clock,
        );
        emit(RewardSharedNavi {
            signer: tx_context::sender(ctx),
            u64_padding: vector[balance.value()],
        });

        balance
    }

    /// [Authorized Function] Post-claims rewards from Navi. This is the second step in a two-step process.
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

    /// Event emitted when funds are borrowed from Navi.
    public struct BorrowNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Borrows funds from Navi.
    public fun borrow_navi_v3<TOKEN>(
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
        system_state: &mut SuiSystemState,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check_without_index(registry, ctx);

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
            system_state,
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
    public struct BorrowSharedNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public fun borrow_shared_navi<TOKEN>(
        registry: &mut Registry,
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
        system_state: &mut SuiSystemState,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check_without_index(registry, ctx);

        // main logic
        let u64_padding = typus_dov_single::borrow_shared_navi_<TOKEN>(
            registry,
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
            system_state,
            amount,
            clock,
            ctx,
        );

        // emit event
        emit(BorrowSharedNavi {
            signer: tx_context::sender(ctx),
            index: deposit_index,
            u64_padding,
        });
    }

    /// Event emitted when a user unsubscribes from a Navi vault.
    public struct UnsubscribeNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Unsubscribes from a Navi vault.
    public fun unsubscribe_navi<D_TOKEN, B_TOKEN, I_TOKEN>(
        registry: &mut Registry,
        index: u64,
        deposit_index: u64,
        ctx: &mut TxContext,
    ) {
        safety_check_without_index(registry, ctx);

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

    /// Event emitted when the interest on a Navi loan is repaid.
    public struct RepayNaviInterest has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Repays the interest on a loan to Navi.
    public fun repay_navi_interest<TOKEN, I_TOKEN>(
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
        safety_check_without_index(registry, ctx);

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
    public struct RepaySharedNaviInterest has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public fun repay_shared_navi_interest<TOKEN, I_TOKEN>(
        registry: &mut Registry,
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
        safety_check_without_index(registry, ctx);

        // main logic
        let u64_padding = typus_dov_single::repay_shared_navi_interest_<TOKEN, I_TOKEN>(
            registry,
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
        emit(RepaySharedNaviInterest {
            signer: tx_context::sender(ctx),
            index: deposit_index,
            u64_padding,
        });
    }

    /// Event emitted before repaying Navi interest.
    public struct PreRepayNaviInterest has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Pre-repays Navi interest. This is the first step in a two-step process.
    public fun pre_repay_navi_interest<D_TOKEN, B_TOKEN, I_TOKEN>(
        version: &TypusEcosystemVersion,
        registry: &mut Registry,
        index: u64,
        deposit_index: u64,
        ctx: &mut TxContext,
    ): (HotPotato<Balance<I_TOKEN>>, vector<u64>) {
        safety_check_without_index(registry, ctx);

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
    public struct PreRepaySharedNaviInterest has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    public fun pre_repay_shared_navi_interest<D_TOKEN, B_TOKEN, I_TOKEN>(
        version: &TypusEcosystemVersion,
        registry: &mut Registry,
        deposit_index: u64,
        ctx: &mut TxContext,
    ): (HotPotato<Balance<I_TOKEN>>, vector<u64>) {
        safety_check_without_index(registry, ctx);

        // main logic
        let (balance, u64_padding) = typus_dov_single::pre_repay_shared_navi_interest_<D_TOKEN, B_TOKEN, I_TOKEN>(
            version,
            registry,
            deposit_index,
            ctx,
        );

        // emit event
        emit(PreRepaySharedNaviInterest {
            signer: tx_context::sender(ctx),
            index: deposit_index,
            u64_padding,
        });

        (balance, u64_padding)
    }

    /// Event emitted after repaying Navi interest.
    public struct PostRepayNaviInterest has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Post-repays Navi interest. This is the second step in a two-step process.
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
        safety_check_without_index(registry, ctx);

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
    public struct PostRepaySharedNaviInterest has copy, drop {
        signer: address,
        u64_padding: vector<u64>,
    }
    public fun post_repay_shared_navi_interest_<TOKEN>(
        version: &TypusEcosystemVersion,
        registry: &mut Registry,
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
        safety_check_without_index(registry, ctx);

        // main logic
        let u64_padding = typus_dov_single::post_repay_shared_navi_interest_<TOKEN>(
            version,
            registry,
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
        emit(PostRepaySharedNaviInterest {
            signer: tx_context::sender(ctx),
            u64_padding,
        });
    }

    /// Event emitted when collateral is deposited to Navi.
    public struct DepositCollateralNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Deposits collateral to Navi.
    public fun deposit_collateral_navi<TOKEN>(
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

    /// Event emitted when collateral is withdrawn from Navi.
    public struct WithdrawCollateralNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    /// [Authorized Function] Withdraws collateral from Navi.
    public fun withdraw_collateral_navi<TOKEN>(
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

    public struct UpdateInfoEvent has copy, drop {
        signer: address,
        index: u64,
        previous: Info,
        current: Info,
    }
    entry fun update_info(
        registry: &mut Registry,
        index: u64,
        status: Option<u64>,
        oracle_price: Option<u64>,
        settlement_price: Option<u64>,
        ctx: &TxContext,
    ) {
        safety_check_without_token(registry, index, ctx);

        // main logic
        let (previous, current) = typus_dov_single::update_info_(
            registry,
            index,
            status,
            oracle_price,
            settlement_price,
        );

        // emit event
        emit(UpdateInfoEvent {
            signer: tx_context::sender(ctx),
            index,
            previous,
            current,
        });
    }

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
    #[allow(unused_field)]
    public struct CreateSuilendObligationOwnerCap has copy, drop {
        signer: address,
        index: u64,
        lending_market_id: address,
        obligation_owner_cap_id: address,
    }
    #[allow(unused_field)]
    public struct DepositSuilend has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    #[allow(unused_field)]
    public struct WithdrawSuilend has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    #[allow(unused_field)]
    public struct RewardSuilend has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    #[allow(unused_field)]
    public struct RepayNavi has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    #[allow(unused_field)]
    public struct CreateScallopSpoolAccount has copy, drop {
        signer: address,
        index: u64,
        spool_id: address,
        spool_account_id: address,
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
    #[allow(unused_field)]
    public struct DepositScallop has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    #[allow(unused_field)]
    public struct WithdrawScallop has copy, drop {
        signer: address,
        index: u64,
        u64_padding: vector<u64>,
    }
    #[allow(unused_field)]
    public struct UpdateActiveVaultConfigEvent has copy, drop {
        signer: address,
        index: u64,
        previous: VaultConfig,
        current: VaultConfig,
    }
    #[deprecated, allow(unused_type_parameter)]
    public fun safu_otc<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _delivery_price: u64,
        _balance: Balance<B_TOKEN>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (Option<TypusBidReceipt>, Balance<B_TOKEN>, vector<u64>) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun withdraw_navi<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _oracle_config: &mut OracleConfig,
        _price_oracle: &mut PriceOracle,
        _supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        _pyth_price_info: &pyth::price_info::PriceInfoObject,
        _feed_address: address,
        _storage: &mut lending_core::storage::Storage,
        _pool: &mut lending_core::pool::Pool<D_TOKEN>,
        _asset: u8,
        _incentive_v2: &mut lending_core::incentive_v2::Incentive,
        _incentive_v3: &mut lending_core::incentive_v3::Incentive,
        _clock: &Clock,
        _ctx: &TxContext,
    ) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun repay_navi<D_TOKEN, B_TOKEN, I_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _deposit_index: u64,
        _oracle_config: &mut OracleConfig,
        _price_oracle: &mut PriceOracle,
        _supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        _pyth_price_info: &pyth::price_info::PriceInfoObject,
        _feed_address: address,
        _storage: &mut lending_core::storage::Storage,
        _pool: &mut lending_core::pool::Pool<D_TOKEN>,
        _asset: u8,
        _incentive_v2: &mut lending_core::incentive_v2::Incentive,
        _incentive_v3: &mut lending_core::incentive_v3::Incentive,
        _coin: Coin<D_TOKEN>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun withdraw_navi_v2<D_TOKEN, B_TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _oracle_config: &mut OracleConfig,
        _price_oracle: &mut PriceOracle,
        _supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        _pyth_price_info: &pyth::price_info::PriceInfoObject,
        _feed_address: address,
        _storage: &mut lending_core::storage::Storage,
        _pool: &mut lending_core::pool::Pool<D_TOKEN>,
        _asset: u8,
        _incentive_v2: &mut lending_core::incentive_v2::Incentive,
        _incentive_v3: &mut lending_core::incentive_v3::Incentive,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ) { abort 0 }
    #[deprecated, allow(unused_type_parameter)]
    public fun borrow_navi<TOKEN>(
        _registry: &mut Registry,
        _index: u64,
        _deposit_index: u64,
        _oracle_config: &mut OracleConfig,
        _price_oracle: &mut PriceOracle,
        _supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        _pyth_price_info: &pyth::price_info::PriceInfoObject,
        _feed_address: address,
        _storage: &mut lending_core::storage::Storage,
        _pool: &mut lending_core::pool::Pool<TOKEN>,
        _asset: u8,
        _incentive_v2: &mut lending_core::incentive_v2::Incentive,
        _incentive_v3: &mut lending_core::incentive_v3::Incentive,
        _amount: u64,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ) { abort 0 }
}