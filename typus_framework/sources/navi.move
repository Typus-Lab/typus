module typus_framework::navi {
    use sui::coin;
    use sui::balance::{Self, Balance};
    use sui::clock::Clock;

    use lending_core::account::AccountCap;

    use typus_framework::vault::{Self, DepositVault};
    use typus_framework::balance_pool::BalancePool;

    /// Creates a new `AccountCap` for the Navi protocol.
    public fun new_navi_account_cap(
        ctx: &mut TxContext,
    ): AccountCap {
        lending_core::lending::create_account(ctx)
    }

    /// Deposits assets into a Navi lending pool.
    /// This function is called after the vault is activated.
    /// WARNING: mut inputs without authority check inside
    public fun deposit<TOKEN>(
        deposit_vault: &mut DepositVault,
        navi_account_cap: &AccountCap,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v1: &mut lending_core::incentive::Incentive,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let (balance, mut log) = vault::withdraw_for_lending(deposit_vault);
        if (balance.value() == 0) {
            balance::destroy_zero(balance);
            return vector::empty()
        };
        log.push_back(balance.value());
        lending_core::incentive_v2::deposit_with_account_cap(
            clock,
            storage,
            pool,
            asset,
            coin::from_balance(balance, ctx),
            incentive_v1,
            incentive_v2,
            navi_account_cap,
        );

        log
    }

    /// Withdraws assets from a Navi lending pool.
    /// This function is called before recouping or settling the vault.
    /// WARNING: mut inputs without authority check inside
    public fun withdraw<TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        incentive: &mut Balance<TOKEN>,
        distribute: bool,
        navi_account_cap: &AccountCap,
        oracle_config: &mut oracle::config::OracleConfig,
        price_oracle: &mut oracle::oracle::PriceOracle,
        supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        pyth_price_info: &pyth::price_info::PriceInfoObject,
        feed_address: address,
        storage: &mut lending_core::storage::Storage,
        pool: &mut lending_core::pool::Pool<TOKEN>,
        asset: u8,
        incentive_v1: &mut lending_core::incentive::Incentive,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        clock: &Clock,
    ): vector<u64> {
        oracle::oracle_pro::update_single_price(
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
        let mut balance = lending_core::incentive_v2::withdraw_with_account_cap(
            clock,
            price_oracle,
            storage,
            pool,
            asset,
            amount + 1,
            incentive_v1,
            incentive_v2,
            navi_account_cap,
        );

        vault::deposit_from_lending(fee_pool, deposit_vault, incentive, balance, balance::zero<TOKEN>(), distribute)
    }

    /// Claims rewards from a Navi lending pool.
    /// This function is called before recouping or settling the vault.
    /// WARNING: mut inputs without authority check inside
    public fun reward<TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        distribute: bool,
        navi_account_cap: &AccountCap,
        storage: &mut lending_core::storage::Storage,
        incentive_funds_pool: &mut lending_core::incentive_v2::IncentiveFundsPool<TOKEN>,
        asset: u8,
        option: u8,
        incentive_v2: &mut lending_core::incentive_v2::Incentive,
        clock: &Clock,
    ): vector<u64> {
        let reward = lending_core::incentive_v2::claim_reward_with_account_cap(
            clock,
            incentive_v2,
            incentive_funds_pool,
            storage,
            asset,
            option,
            navi_account_cap,
        );

        vault::reward_from_lending(fee_pool, deposit_vault, reward, distribute)
    }
}