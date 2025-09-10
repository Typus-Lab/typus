module typus_dov::tds_fee_pool_entry {
    use std::type_name::{Self, TypeName};

    use sui::event::emit;

    use typus_dov::typus_dov_single::{Self, Registry};
    use typus_framework::authority;
    use typus_framework::balance_pool;

    fun safety_check(
        registry: &Registry,
        ctx: &TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::validate_registry_authority(registry, ctx);
    }

    public struct AddFeePoolAuthorizedUserEvent has copy, drop {
        signer: address,
        users: vector<address>,
    }
    public(package) entry fun add_fee_pool_authorized_user(
        registry: &mut Registry,
        mut users: vector<address>,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        // main logic
        let (
            _id,
            _num_of_vault,
            _authority,
            fee_pool,
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
            balance_pool::add_authorized_user(fee_pool, user);
        };

        // emit event
        emit(AddFeePoolAuthorizedUserEvent {
                signer: tx_context::sender(ctx),
                users: authority::whitelist(balance_pool::authority(fee_pool)),
            }
        );
    }

    public struct RemoveFeePoolAuthorizedUserEvent has copy, drop {
        signer: address,
        users: vector<address>,
    }
    public(package) entry fun remove_fee_pool_authorized_user(
        registry: &mut Registry,
        mut users: vector<address>,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        // main logic
        let (
            _id,
            _num_of_vault,
            _authority,
            fee_pool,
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
            balance_pool::remove_authorized_user(fee_pool, user);
        };

        // emit event
        emit(RemoveFeePoolAuthorizedUserEvent {
                signer: tx_context::sender(ctx),
                users: authority::whitelist(balance_pool::authority(fee_pool)),
            }
        );
    }

    public struct TakeFeeEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
    }
    public(package) entry fun take_fee<TOKEN>(
        registry: &mut Registry,
        amount: Option<u64>,
        ctx: &mut TxContext,
    ) {
        safety_check(registry, ctx);

        let (
            _id,
            _num_of_vault,
            _authority,
            fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let amount = balance_pool::take<TOKEN>(fee_pool, amount, ctx);

        // emit event
        emit(TakeFeeEvent {
                signer: tx_context::sender(ctx),
                token: type_name::get<TOKEN>(),
                amount,
            }
        );
    }

    public struct SendFeeEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
        recipient: address,
    }
    public(package) entry fun send_fee<TOKEN>(
        registry: &mut Registry,
        amount: Option<u64>,
        ctx: &mut TxContext,
    ) {
        safety_check(registry, ctx);

        let (
            _id,
            _num_of_vault,
            _authority,
            fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let amount = balance_pool::send<TOKEN>(fee_pool, amount, @fee_address, ctx);

        // emit event
        emit(SendFeeEvent {
                signer: tx_context::sender(ctx),
                token: type_name::get<TOKEN>(),
                amount,
                recipient: @fee_address,
            }
        );
    }

    public struct AddSharedFeePoolAuthorizedUserEvent has copy, drop {
        signer: address,
        users: vector<address>,
    }
    public entry fun add_shared_fee_pool_authorized_user(
        registry: &mut Registry,
        key: vector<u8>,
        mut users: vector<address>,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        // main logic
        let (
            _id,
            _num_of_vault,
            _authority,
            fee_pool,
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
            balance_pool::add_shared_authorized_user(fee_pool, key, user);
        };

        // emit event
        emit(AddSharedFeePoolAuthorizedUserEvent {
                signer: tx_context::sender(ctx),
                users: authority::whitelist(balance_pool::shared_authority(fee_pool, key)),
            }
        );
    }

    public struct RemoveSharedFeePoolAuthorizedUserEvent has copy, drop {
        signer: address,
        users: vector<address>,
    }
    public entry fun remove_shared_fee_pool_authorized_user(
        registry: &mut Registry,
        key: vector<u8>,
        mut users: vector<address>,
        ctx: &TxContext,
    ) {
        safety_check(registry, ctx);

        // main logic
        let (
            _id,
            _num_of_vault,
            _authority,
            fee_pool,
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
            balance_pool::remove_shared_authorized_user(fee_pool, key, user);
        };

        // emit event
        emit(RemoveSharedFeePoolAuthorizedUserEvent {
                signer: tx_context::sender(ctx),
                users: authority::whitelist(balance_pool::shared_authority(fee_pool, key)),
            }
        );
    }

    public struct TakeSharedFeeEvent has copy, drop {
        signer: address,
        key: vector<u8>,
        token: TypeName,
        amount: u64,
    }
    entry fun take_shared_fee<TOKEN>(
        registry: &mut Registry,
        key: vector<u8>,
        amount: Option<u64>,
        ctx: &mut TxContext,
    ) {
        safety_check(registry, ctx);

        let (
            _id,
            _num_of_vault,
            _authority,
            fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_mut_registry_inner(registry);
        let amount = balance_pool::take_shared<TOKEN>(fee_pool, key, amount, ctx);

        // emit event
        emit(TakeSharedFeeEvent {
                signer: tx_context::sender(ctx),
                key,
                token: type_name::get<TOKEN>(),
                amount,
            }
        );
    }
}