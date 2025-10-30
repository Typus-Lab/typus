#[deprecated]
module typus_framework::scallop {
    use protocol::market::Market;
    use protocol::reserve::MarketCoin;
    use protocol::version::Version;
    use spool::rewards_pool::RewardsPool;
    use spool::spool_account::SpoolAccount;
    use spool::spool::Spool;
    use sui::balance::Balance;
    use sui::clock::Clock;
    use sui::coin::Coin;
    use typus_framework::balance_pool::BalancePool;
    use typus_framework::vault::DepositVault;

    #[deprecated]
    public fun new_spool_account<TOKEN>(
        _spool: &mut Spool,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): SpoolAccount<MarketCoin<TOKEN>> { abort 0 }
    #[deprecated]
    public fun deposit<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _version: &Version,
        _market: &mut Market,
        _spool: &mut Spool,
        _spool_account: &mut SpoolAccount<MarketCoin<TOKEN>>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun withdraw<D_TOKEN, R_TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<D_TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _spool: &mut Spool,
        _rewards_pool: &mut RewardsPool<R_TOKEN>,
        _spool_account: &mut SpoolAccount<MarketCoin<D_TOKEN>>,
        _distribute: bool,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
    #[deprecated]
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
    ): vector<u64> { abort 0 }
    #[deprecated]
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
    ): vector<u64> { abort 0 }
    #[deprecated]
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
    ): vector<u64> { abort 0 }
    #[deprecated]
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
    ): vector<u64> { abort 0 }
    #[deprecated]
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
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun deposit_basic_lending<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _version: &Version,
        _market: &mut Market,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (Coin<MarketCoin<TOKEN>>, vector<u64>) { abort 0 }
    #[deprecated]
    public fun withdraw_basic_lending<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _market_coin: Coin<MarketCoin<TOKEN>>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun withdraw_basic_lending_xy<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _market_coin: Coin<MarketCoin<TOKEN>>,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun withdraw_basic_lending_v2<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<TOKEN>,
        _version: &Version,
        _market: &mut Market,
        _market_coin: Coin<MarketCoin<TOKEN>>,
        _distribute: bool,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
}