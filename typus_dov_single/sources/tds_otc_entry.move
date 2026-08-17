module typus_dov::tds_otc_entry {
    use std::bcs;

    use sui::balance::{Self, Balance};
    use sui::clock::Clock;
    use sui::table::{Self, Table};
    use sui::dynamic_object_field;

    use typus_dov::typus_dov_single::{Self, Registry};
    use typus_framework::utils;

    const KOtcConfigs: vector<u8> = b"otc_configs";

    /// A struct that holds the configuration for an OTC deal.
    public struct OtcConfig has drop, store {
        round: u64,
        size: u64,
        price: u64,
        fee_bp: u64,
        expiration_ts_ms: u64,
        u64_padding: vector<u64>,
    }

    /// [Authorized Function] Adds a new OTC configuration for a user.
    entry fun add_otc_config(
        registry: &mut Registry,
        user: address,
        index: u64,
        round: u64,
        size: u64,
        price: u64,
        fee_bp: u64,
        expiration_ts_ms: u64,
        ctx: &mut TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::validate_registry_authority(registry, ctx);

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
        if (!dynamic_object_field::exists_(id, KOtcConfigs.to_string())) {
            dynamic_object_field::add(id, KOtcConfigs.to_string(), table::new<address, Table<u64, OtcConfig>>(ctx));
        };
        let otc_configs: &mut Table<address, Table<u64, OtcConfig>> = dynamic_object_field::borrow_mut(id, KOtcConfigs.to_string());
        if (!otc_configs.contains(user)) {
            otc_configs.add(user, table::new<u64, OtcConfig>(ctx));
        };
        let user_otc_configs = otc_configs.borrow_mut(user);
        if (user_otc_configs.contains(index)) {
            user_otc_configs.remove(index);
        };
        user_otc_configs.add(
            index,
            OtcConfig {
                round,
                size,
                price,
                fee_bp,
                expiration_ts_ms,
                u64_padding: vector[],
            }
        );

        typus_dov_single::emit_add_otc_config_event(
            user,
            index,
            round,
            size,
            price,
            vector[fee_bp, expiration_ts_ms],
            ctx,
        );
    }

    /// [Authorized Function] Removes an OTC configuration for a user.
    entry fun remove_otc_config(
        registry: &mut Registry,
        user: address,
        index: u64,
        ctx: &TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::validate_registry_authority(registry, ctx);

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
        let otc_configs: &mut Table<address, Table<u64, OtcConfig>> = dynamic_object_field::borrow_mut(id, KOtcConfigs.to_string());
        let user_otc_configs = otc_configs.borrow_mut(user);
        user_otc_configs.remove(index);

        typus_dov_single::emit_remove_otc_config_event(
            user,
            index,
            ctx,
        );
    }

    /// [User Function] Executes an OTC deal.
    public fun otc<D_TOKEN, B_TOKEN>(
        registry: &mut Registry,
        index: u64,
        mut balance: Balance<B_TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, index);

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
        let user = ctx.sender();
        let current_ts_ms = clock.timestamp_ms();
        let otc_configs: &mut Table<address, Table<u64, OtcConfig>> = dynamic_object_field::borrow_mut(id, KOtcConfigs.to_string());
        assert!(otc_configs.contains(user), EInvalidUser);
        let user_otc_configs = otc_configs.borrow_mut(user);
        assert!(user_otc_configs.contains(index), EInvalidIndex);
        let otc_config = user_otc_configs.remove(index);
        assert!(current_ts_ms <= otc_config.expiration_ts_ms, EExpired);
        let size_decimal = typus_dov_single::get_size_decimal(portfolio_vault_registry, index);
        let fee_balance_value = ((otc_config.price as u128) * (otc_config.size as u128) / (utils::multiplier(size_decimal) as u128) * (otc_config.fee_bp as u128) / 10000 as u64);
        let fee_balance = balance.split(fee_balance_value);
        let bid_value = balance.value();
        typus_dov_single::otc_<D_TOKEN, B_TOKEN>(
            registry,
            index,
            option::some(otc_config.round),
            otc_config.price,
            otc_config.size,
            balance,
            fee_balance,
            balance::zero(),
            balance::zero(),
            balance::zero(),
            clock,
            ctx,
        );

        typus_dov_single::emit_otc_event(
            registry,
            index,
            otc_config.price,
            otc_config.size,
            bid_value,
            fee_balance_value,
            0,
            0,
            0,
            ctx,
        );
    }

    /// [View Function] A view function to get a user's OTC configurations.
    public(package) fun get_user_otc_configs(
        registry: &mut Registry,
        user: address,
        indexes: vector<u64>,
    ): vector<vector<u8>> {
        typus_dov_single::version_check(registry);

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
        if (!dynamic_object_field::exists_(id, KOtcConfigs.to_string())) {
            return vector[]
        };
        let otc_configs: &mut Table<address, Table<u64, OtcConfig>> = dynamic_object_field::borrow_mut(id, KOtcConfigs.to_string());
        if (!otc_configs.contains(user)) {
            return vector[]
        };
        let user_otc_configs = otc_configs.borrow_mut(user);
        let mut result = vector[];
        indexes.do!(|index| {
            if (user_otc_configs.contains(index)) {
                let mut bytes = bcs::to_bytes(&index);
                bytes.append(bcs::to_bytes(user_otc_configs.borrow(index)));
                result.push_back(bytes);
            };
        });

        result
    }

    #[error]
    const EInvalidUser: vector<u8> = b"invalid_user";
    #[error]
    const EInvalidIndex: vector<u8> = b"invalid_index";
    #[error]
    const EExpired: vector<u8> = b"expired";
}