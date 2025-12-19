module typus_dov::tds_registry_authorized_entry {
    use std::type_name::{Self, TypeName};

    use sui::dynamic_field;
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::event::emit;

    use typus_dov::typus_dov_single::{Self, Registry, Info, Config};
    use typus_framework::authority;
    use typus_oracle::oracle::Oracle;
    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::leaderboard::TypusLeaderboardRegistry;
    use typus::linked_set;
    use typus::user::TypusUserRegistry;

    const K_WITNESSES: vector<u8> = b"witnesses";

    /// Performs a safety check for authorized functions.
    fun safety_check(
        registry: &Registry,
        ctx: &TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::validate_registry_authority(registry, ctx);
    }

    /// Event emitted when the registry is upgraded.
    public struct UpgradeRegistryEvent has copy, drop {
        signer: address,
        prev_version: u64,
        version: u64,
    }
    /// [Authorized Function] Upgrades the registry to a new version.
    public(package) entry fun upgrade_registry(
        registry: &mut Registry,
        ctx: &TxContext,
    ) {
        typus_dov_single::validate_registry_upgradability(registry, ctx);

        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let prev_version = *version;
        *version = typus_dov_single::get_version();

        // emit event
        emit(UpgradeRegistryEvent {
                signer: tx_context::sender(ctx),
                prev_version,
                version: *version,
            }
        );
    }

    /// Event emitted when an authorized user is added to the registry.
    public struct AddAuthorizedUserEvent has copy, drop {
        signer: address,
        users: vector<address>,
    }
    /// [Authorized Function] Adds an authorized user to the registry.
    public(package) entry fun add_authorized_user(
        registry: &mut Registry,
        mut users: vector<address>,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        // main logic
        let (
            _id,
            _num_of_vault,
            authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        while (!vector::is_empty(&users)) {
            let user = vector::pop_back(&mut users);
            authority::add_authorized_user(authority, user);
        };

        // emit event
        emit(AddAuthorizedUserEvent {
                signer: tx_context::sender(ctx),
                users: authority::whitelist(authority),
            }
        );
    }

    /// Event emitted when an authorized user is removed from the registry.
    public struct RemoveAuthorizedUserEvent has copy, drop {
        signer: address,
        users: vector<address>,
    }
    /// [Authorized Function] Removes an authorized user from the registry.
    public(package) entry fun remove_authorized_user(
        registry: &mut Registry,
        mut users: vector<address>,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        // main logic
        let (
            _id,
            _num_of_vault,
            authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        while (!vector::is_empty(&users)) {
            let user = vector::pop_back(&mut users);
            authority::remove_authorized_user(authority, user);
        };

        // emit event
        emit(RemoveAuthorizedUserEvent {
                signer: tx_context::sender(ctx),
                users: authority::whitelist(authority),
            }
        );
    }

    /// Event emitted when a witness type is added to the registry.
    public struct AddWitnessEvent has copy, drop {
        signer: address,
        witness: TypeName,
    }
    /// [Authorized Function] Adds a witness type to the registry.
    public(package) entry fun add_witness<W: drop>(
        registry: &mut Registry,
        ctx: &mut TxContext,
    ) {
        safety_check(registry, ctx);

        // main logic
        let (
            id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        if (!dynamic_field::exists_(id, K_WITNESSES.to_string())) {
            dynamic_field::add(id, K_WITNESSES.to_string(), linked_set::new<TypeName>(ctx));
        };
        let witnesses = dynamic_field::borrow_mut(id, K_WITNESSES.to_string());
        linked_set::push_back(witnesses, type_name::with_defining_ids<W>());

        // emit event
        emit(AddWitnessEvent {
                signer: tx_context::sender(ctx),
                witness: type_name::with_defining_ids<W>(),
            }
        );
    }

    /// Event emitted when a witness type is removed from the registry.
    public struct RemoveWitnessEvent has copy, drop {
        signer: address,
        witness: TypeName,
    }
    /// [Authorized Function] Removes a witness type from the registry.
    public(package) entry fun remove_witness<W: drop>(
        registry: &mut Registry,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        // main logic
        let (
            id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let witnesses = dynamic_field::borrow_mut(id, K_WITNESSES.to_string());
        linked_set::remove(witnesses, type_name::with_defining_ids<W>());

        // emit event
        emit(RemoveWitnessEvent {
                signer: tx_context::sender(ctx),
                witness: type_name::with_defining_ids<W>(),
            }
        );
    }

    /// Event emitted when transactions are suspended.
    public struct SuspendTransactionEvent has copy, drop {
        signer: address,
    }
    /// [Authorized Function] Suspends transactions for the registry.
    public(package) entry fun suspend_transaction(
        registry: &mut Registry,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        typus_dov_single::suspend_transaction_(registry);

        // emit event
        emit(SuspendTransactionEvent {
            signer: tx_context::sender(ctx),
        });
    }

    /// Event emitted when transactions are resumed.
    public struct ResumeTransactionEvent has copy, drop {
        signer: address,
    }
    /// [Authorized Function] Resumes transactions for the registry.
    public(package) entry fun resume_transaction(
        registry: &mut Registry,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        typus_dov_single::resume_transaction_(registry);

        // emit event
        emit(ResumeTransactionEvent {
            signer: tx_context::sender(ctx),
        });
    }

    /// [Authorized Function] Updates the deposit points for users.
    public fun update_deposit_point(
        version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        registry: &mut Registry,
        users: vector<address>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check(registry, ctx);

        // main logic
        typus_dov_single::update_deposit_point(
            version,
            typus_user_registry,
            typus_leaderboard_registry,
            registry,
            users,
            clock,
            ctx,
        );
    }

    /// Event emitted when incentives are added to the registry.
    public struct IncentiviseEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
    }
    /// [Authorized Function] Adds incentives to the registry.
    public(package) entry fun incentivise<TOKEN>(
        registry: &mut Registry,
        coin: Coin<TOKEN>,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        let amount = typus_dov_single::incentivise_(registry, coin);

        // emit event
        emit(IncentiviseEvent {
            signer: tx_context::sender(ctx),
            token: type_name::with_defining_ids<TOKEN>(),
            amount,
        });
    }

    /// Event emitted when the available incentive amount for a vault is set.
    public struct SetAvailableIncentiveAmountEvent has copy, drop {
        signer: address,
        index: u64,
        prev_amount: u64,
        amount: u64,
    }
    /// [Authorized Function] Sets the available incentive amount for a vault.
    public(package) entry fun set_available_incentive_amount(
        registry: &mut Registry,
        index: u64,
        amount: u64,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        let prev_amount = typus_dov_single::set_available_incentive_amount_(registry, index, amount);

        // emit event
        emit(SetAvailableIncentiveAmountEvent {
            signer: tx_context::sender(ctx),
            index,
            prev_amount,
            amount,
        });
    }

    /// Event emitted when incentives are withdrawn from the registry.
    public struct WithdrawIncentiveEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
    }
    /// [Authorized Function] Withdraws incentives from the registry.
    #[lint_allow(self_transfer)]
    public(package) entry fun withdraw_incentive<TOKEN>(
        registry: &mut Registry,
        amount: Option<u64>,
        ctx: &mut TxContext,
    ) {
        safety_check(registry, ctx);

        let incentive_coin = typus_dov_single::withdraw_incentive_<TOKEN>(registry, amount, ctx);
        let amount = coin::value(&incentive_coin);
        transfer::public_transfer(incentive_coin, tx_context::sender(ctx));

        // emit event
        emit(WithdrawIncentiveEvent {
            signer: tx_context::sender(ctx),
            token: type_name::with_defining_ids<TOKEN>(),
            amount,
        });
    }

    /// Event emitted when a new portfolio vault is created.
    public struct NewPortfolioVaultEvent has copy, drop {
        signer: address,
        index: u64,
        info: Info,
        config: Config,
    }
    /// [Authorized Function] Creates a new portfolio vault.
    public(package) entry fun new_portfolio_vault<D_TOKEN, B_TOKEN>(
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
        strike_bp: vector<u64>,
        weight: vector<u64>,
        is_buyer: vector<bool>,
        strike_increment: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
        whitelist: vector<address>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        safety_check(registry, ctx);

        // main logic
        let (index, info, config) = typus_dov_single::new_portfolio_vault_<D_TOKEN, B_TOKEN>(
            registry,
            option_type,
            period,
            d_token_decimal,
            b_token_decimal,
            o_token_decimal,
            activation_ts_ms,
            expiration_ts_ms,
            oracle,
            deposit_lot_size,
            bid_lot_size,
            min_deposit_size,
            min_bid_size,
            max_deposit_entry,
            max_bid_entry,
            deposit_fee_bp,
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
            typus_dov_single::create_payoff_configs(strike_bp, weight, is_buyer),
            strike_increment,
            decay_speed,
            initial_price,
            final_price,
            whitelist,
            clock,
            ctx,
        );

        // emit event
        emit(NewPortfolioVaultEvent {
            signer: tx_context::sender(ctx),
            index,
            info,
            config,
        });
    }
}