#[deprecated, allow(unused_type_parameter)]
module typus_framework::suilend {
    use sui::balance::Balance;
    use sui::clock::Clock;
    use suilend::lending_market::{LendingMarket, ObligationOwnerCap};
    use suilend::suilend::MAIN_POOL;
    use typus_framework::balance_pool::BalancePool;
    use typus_framework::vault::DepositVault;

    #[deprecated]
    public fun new_suilend_obligation_owner_cap(
        _suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        _ctx: &mut TxContext,
    ): ObligationOwnerCap<MAIN_POOL> { abort 0 }
    #[deprecated]
    public fun deposit<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        _reserve_array_index: u64,
        _suilend_obligation_owner_cap: &ObligationOwnerCap<MAIN_POOL>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun withdraw<D_TOKEN, R_TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<D_TOKEN>,
        _suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        _reserve_array_index: u64,
        _reward_index: u64,
        _suilend_obligation_owner_cap: &ObligationOwnerCap<MAIN_POOL>,
        _distribute: bool,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun withdraw_without_reward<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<TOKEN>,
        _suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        _reserve_array_index: u64,
        _suilend_obligation_owner_cap: &ObligationOwnerCap<MAIN_POOL>,
        _distribute: bool,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun reward<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        _reserve_array_index: u64,
        _reward_index: u64,
        _suilend_obligation_owner_cap: &ObligationOwnerCap<MAIN_POOL>,
        _distribute: bool,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
}