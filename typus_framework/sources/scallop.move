/// No authority chech in these public functions, do not let `DepositVault` and `SpoolAccount` be exposed.
module typus_framework::scallop {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::clock::Clock;

    use spool::user;
    use spool::spool::Spool;
    use protocol::mint;
    use spool::spool_account;
    use spool::rewards_pool::RewardsPool;
    use protocol::redeem;
    use protocol::market::Market;
    use protocol::version::Version;
    use spool::spool_account::SpoolAccount;
    use protocol::reserve::MarketCoin;

    use typus_framework::vault::{Self, DepositVault, deprecated};
    use typus_framework::balance_pool::BalancePool;

    /// Creates a new `SpoolAccount` for Scallop.
    /// WARNING: mut inputs without authority check inside
    public fun new_spool_account<TOKEN>(
        spool: &mut Spool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): SpoolAccount<MarketCoin<TOKEN>> {
        user::new_spool_account<MarketCoin<TOKEN>>(spool, clock, ctx)
    }

    /// Deposits assets into a Scallop spool.
    /// This function is called after the vault is activated.
    /// WARNING: mut inputs without authority check inside
    public fun deposit<TOKEN>(
        deposit_vault: &mut DepositVault,
        version: &Version,
        market: &mut Market,
        spool: &mut Spool,
        spool_account: &mut SpoolAccount<MarketCoin<TOKEN>>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let (balance, mut log) = vault::withdraw_for_lending(deposit_vault);
        if (balance.value() == 0) {
            balance::destroy_zero(balance);
            return vector[0, 0, 0]
        };
        let market_coin = mint::mint<TOKEN>(
            version,
            market,
            coin::from_balance(balance, ctx),
            clock,
            ctx,
        );
        log.push_back(market_coin.value());
        user::stake(
            spool,
            spool_account,
            market_coin,
            clock,
            ctx,
        );

        log
    }

    /// Withdraws assets and claims rewards from a Scallop spool.
    /// This function is called before recouping or settling the vault.
    /// WARNING: mut inputs without authority check inside
    public fun withdraw<D_TOKEN, R_TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        incentive: &mut Balance<D_TOKEN>,
        version: &Version,
        market: &mut Market,
        spool: &mut Spool,
        rewards_pool: &mut RewardsPool<R_TOKEN>,
        spool_account: &mut SpoolAccount<MarketCoin<D_TOKEN>>,
        distribute: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let stake_amount = spool_account::stake_amount(spool_account);
        if (stake_amount == 0) {
            return vector[0, 0, 0, 0, 0, 0, 0, 0]
        };
        let reward = coin::into_balance(
            user::redeem_rewards<MarketCoin<D_TOKEN>, R_TOKEN>(
                spool,
                rewards_pool,
                spool_account,
                clock,
                ctx,
            )
        );
        let market_coin = user::unstake(
            spool,
            spool_account,
            stake_amount,
            clock,
            ctx,
        );
        let balance = coin::into_balance(
            redeem::redeem(
                version,
                market,
                market_coin,
                clock,
                ctx,
            )
        );

        vault::deposit_from_lending(fee_pool, deposit_vault, incentive, balance, reward, distribute)
    }

    /// Deprecated function.
    public fun withdraw_xxx<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _spool: &mut Spool,
        _rewards_pool: &mut RewardsPool<TOKEN>,
        _spool_account: &mut SpoolAccount<MarketCoin<TOKEN>>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { deprecated(); abort 0 }

    /// Deprecated function.
    public fun withdraw_xyy<D_TOKEN, B_TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<D_TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _spool: &mut Spool,
        _rewards_pool: &mut RewardsPool<B_TOKEN>,
        _spool_account: &mut SpoolAccount<MarketCoin<D_TOKEN>>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { deprecated(); abort 0 }

    /// Deprecated function.
    public fun withdraw_xyx<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _spool: &mut Spool,
        _rewards_pool: &mut RewardsPool<TOKEN>,
        _spool_account: &mut SpoolAccount<MarketCoin<TOKEN>>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { deprecated(); abort 0 }

    /// Deprecated function.
    public fun withdraw_xyz<D_TOKEN, I_TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<D_TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _spool: &mut Spool,
        _rewards_pool: &mut RewardsPool<I_TOKEN>,
        _spool_account: &mut SpoolAccount<MarketCoin<D_TOKEN>>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { deprecated(); abort 0 }

    /// Deprecated function.
    public fun withdraw_additional_lending<D_TOKEN, I_TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<D_TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _spool: &mut Spool,
        _rewards_pool: &mut RewardsPool<I_TOKEN>,
        _spool_account: &mut SpoolAccount<MarketCoin<D_TOKEN>>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { deprecated(); abort 0 }

    // ======= basic lending =======

    /// Deposits assets for basic lending (without staking).
    /// This function is called after the vault is activated.
    /// WARNING: mut inputs without authority check inside
    public fun deposit_basic_lending<TOKEN>(
        deposit_vault: &mut DepositVault,
        version: &Version,
        market: &mut Market,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Coin<MarketCoin<TOKEN>>, vector<u64>) {
        let (balance, mut log) = vault::withdraw_for_lending(deposit_vault);
        if (balance.value() == 0) {
            balance::destroy_zero(balance);
            return (coin::zero(ctx), vector[0, 0, 0])
        };
        let market_coin = mint::mint<TOKEN>(
            version,
            market,
            coin::from_balance(balance, ctx),
            clock,
            ctx,
        );
        log.push_back(market_coin.value());

        (
            market_coin,
            log,
        )
    }

    /// Withdraws assets from basic lending.
    /// This function is called before recouping or settling the vault.
    /// It puts the principal into the active & deactivating pools, and the reward into the premium pool.
    /// This function is for when the deposit token is the same as the reward token.
    /// WARNING: mut inputs without authority check inside
    public fun withdraw_basic_lending_v2<TOKEN>(
        fee_pool: &mut BalancePool,
        deposit_vault: &mut DepositVault,
        incentive: &mut Balance<TOKEN>,
        version: &Version,
        market: &mut Market,
        market_coin: Coin<MarketCoin<TOKEN>>,
        distribute: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let market_coin_amount = coin::value(&market_coin);
        if (market_coin_amount == 0) {
            coin::destroy_zero(market_coin);
            return vector[0, 0, 0, 0, 0, 0, 0, 0]
        };
        let balance = coin::into_balance(
            redeem::redeem(
                version,
                market,
                market_coin,
                clock,
                ctx,
            )
        );

        vault::deposit_from_lending(fee_pool, deposit_vault, incentive, balance, balance::zero<TOKEN>(), distribute)
    }

    /// Deprecated function.
    public fun withdraw_basic_lending<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _market_coin: Coin<MarketCoin<TOKEN>>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { deprecated(); abort 0 }

    /// Deprecated function.
    public fun withdraw_basic_lending_xy<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _market_coin: Coin<MarketCoin<TOKEN>>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { deprecated(); abort 0 }
}