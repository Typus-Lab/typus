/// No authority chech in these public functions, do not let `DepositVault` and `ObligationOwnerCap` be exposed.
module typus_framework::suilend {
    use sui::coin;
    use sui::balance::{Self, Balance};
    use sui::clock::Clock;

    use suilend::lending_market::{Self, LendingMarket, ObligationOwnerCap};
    use suilend::suilend::MAIN_POOL;

    use typus_framework::vault::{Self, DepositVault};
    use typus_framework::balance_pool::BalancePool;

    const U64_MAX: u64 = 18_446_744_073_709_551_615;

    /// Creates a new `ObligationOwnerCap` for the Suilend protocol.
    /// WARNING: mut inputs without authority check inside
    public fun new_suilend_obligation_owner_cap(
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        ctx: &mut TxContext,
    ): ObligationOwnerCap<MAIN_POOL> {
        lending_market::create_obligation(suilend_lending_market, ctx)
    }

    /// Deposits assets into a Suilend lending market.
    /// This function is called after the vault is activated.
    /// WARNING: mut inputs without authority check inside
    public fun deposit<TOKEN>(
        deposit_vault: &mut DepositVault,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        suilend_obligation_owner_cap: &ObligationOwnerCap<MAIN_POOL>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let (balance, mut log) = vault::withdraw_for_lending(deposit_vault);
        if (balance.value() == 0) {
            balance::destroy_zero(balance);
            return vector::empty()
        };
        let ctokens = lending_market::deposit_liquidity_and_mint_ctokens(
            suilend_lending_market,
            reserve_array_index,
            clock,
            coin::from_balance<TOKEN>(balance, ctx),
            ctx,
        );
        log.push_back(ctokens.value());
        lending_market::deposit_ctokens_into_obligation(
            suilend_lending_market,
            reserve_array_index,
            suilend_obligation_owner_cap,
            clock,
            ctokens,
            ctx,
        );

        log
    }

    /// Withdraws assets and claims rewards from a Suilend lending market.
    /// This function is called before recouping or settling the vault.
    /// WARNING: mut inputs without authority check inside
    public fun withdraw<D_TOKEN, R_TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        incentive: &mut Balance<D_TOKEN>,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        reward_index: u64,
        suilend_obligation_owner_cap: &ObligationOwnerCap<MAIN_POOL>,
        distribute: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let reward = coin::into_balance<R_TOKEN>(
            lending_market::claim_rewards(
                suilend_lending_market,
                suilend_obligation_owner_cap,
                clock,
                reserve_array_index,
                reward_index,
                true,
                ctx,
            )
        );
        let ctokens = suilend::lending_market::withdraw_ctokens(
            suilend_lending_market,
            reserve_array_index,
            suilend_obligation_owner_cap,
            clock,
            U64_MAX,
            ctx,
        );
        let balance = coin::into_balance(suilend::lending_market::redeem_ctokens_and_withdraw_liquidity(
            suilend_lending_market,
            reserve_array_index,
            clock,
            ctokens,
            option::none(),
            ctx,
        ));

        vault::deposit_from_lending(fee_pool, deposit_vault, incentive, balance, reward, distribute)
    }

    /// Withdraws assets from a Suilend lending market without claiming rewards.
    /// This function is called before recouping or settling the vault.
    /// WARNING: mut inputs without authority check inside
    public fun withdraw_without_reward<TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        incentive: &mut Balance<TOKEN>,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        suilend_obligation_owner_cap: &ObligationOwnerCap<MAIN_POOL>,
        distribute: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let ctokens = suilend::lending_market::withdraw_ctokens(
            suilend_lending_market,
            reserve_array_index,
            suilend_obligation_owner_cap,
            clock,
            U64_MAX,
            ctx,
        );
        let balance = coin::into_balance(suilend::lending_market::redeem_ctokens_and_withdraw_liquidity(
            suilend_lending_market,
            reserve_array_index,
            clock,
            ctokens,
            option::none(),
            ctx,
        ));

        vault::deposit_from_lending(fee_pool, deposit_vault, incentive, balance, balance::zero<TOKEN>(), distribute)
    }

    /// Claims rewards from a Suilend lending market.
    /// This function is called before recouping or settling the vault.
    /// WARNING: mut inputs without authority check inside
    public fun reward<TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        suilend_lending_market: &mut LendingMarket<MAIN_POOL>,
        reserve_array_index: u64,
        reward_index: u64,
        suilend_obligation_owner_cap: &ObligationOwnerCap<MAIN_POOL>,
        distribute: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let reward = coin::into_balance<TOKEN>(
            lending_market::claim_rewards(
                suilend_lending_market,
                suilend_obligation_owner_cap,
                clock,
                reserve_array_index,
                reward_index,
                true,
                ctx,
            )
        );

        vault::reward_from_lending(fee_pool, deposit_vault, reward, distribute)
    }
}