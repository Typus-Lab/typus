module typus_dov::tds_fee_pool_entry {
    use std::type_name::{Self, TypeName};

    use sui::event::emit;

    use typus_dov::typus_dov_single::{Self, Registry};
    use typus_framework::authority;
    use typus_framework::balance_pool;

    /// Performs a safety check for authorized functions.
    fun safety_check(
        registry: &Registry,
        ctx: &TxContext,
    ) {
        typus_dov_single::version_check(registry);
        typus_dov_single::validate_registry_authority(registry, ctx);
    }

    /// Event emitted when an authorized user is added to the fee pool.
    public struct AddFeePoolAuthorizedUserEvent has copy, drop {
        signer: address,
        users: vector<address>,
    }
    /// Adds an authorized user to the fee pool.
    /// This is an authorized function (via registry authority).
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

    /// Event emitted when an authorized user is removed from the fee pool.
    public struct RemoveFeePoolAuthorizedUserEvent has copy, drop {
        signer: address,
        users: vector<address>,
    }
    /// Removes an authorized user from the fee pool.
    /// This is an authorized function (via registry authority).
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

    /// Event emitted when a fee is taken from the fee pool.
    public struct TakeFeeEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
    }
    /// Takes a fee from the fee pool.
    /// This is an authorized function (via registry authority).
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
                token: type_name::with_defining_ids<TOKEN>(),
                amount,
            }
        );
    }

    /// Event emitted when a fee is sent from the fee pool.
    public struct SendFeeEvent has copy, drop {
        signer: address,
        token: TypeName,
        amount: u64,
        recipient: address,
    }
    /// Sends a fee from the fee pool to a specified address.
    /// This is an authorized function (via registry authority).
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
                token: type_name::with_defining_ids<TOKEN>(),
                amount,
                recipient: @fee_address,
            }
        );
    }

    #[deprecated]
    public struct AddSharedFeePoolAuthorizedUserEvent has copy, drop {
        signer: address,
        users: vector<address>,
    }
    #[deprecated]
    public fun add_shared_fee_pool_authorized_user(
        _registry: &mut Registry,
        _key: vector<u8>,
        _users: vector<address>,
        _ctx: &TxContext,
    ) { abort 0 }
    #[deprecated]
    public struct RemoveSharedFeePoolAuthorizedUserEvent has copy, drop {
        signer: address,
        users: vector<address>,
    }
    #[deprecated]
    public fun remove_shared_fee_pool_authorized_user(
        _registry: &mut Registry,
        _key: vector<u8>,
        _users: vector<address>,
        _ctx: &TxContext,
    ) { abort 0 }
    #[deprecated]
    public struct TakeSharedFeeEvent has copy, drop {
        signer: address,
        key: vector<u8>,
        token: TypeName,
        amount: u64,
    }
}