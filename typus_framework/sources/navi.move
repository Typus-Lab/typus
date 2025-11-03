#[deprecated]
module typus_framework::navi {
    use lending_core::account::AccountCap;
    use sui::balance::Balance;
    use sui::clock::Clock;
    use typus_framework::balance_pool::BalancePool;
    use typus_framework::vault::DepositVault;

    #[deprecated]
    public fun new_navi_account_cap(_ctx: &mut TxContext): AccountCap { abort 0 }
    #[deprecated]
    public fun deposit<TOKEN>(
        _deposit_vault: &mut DepositVault,
        _navi_account_cap: &AccountCap,
        _storage: &mut lending_core::storage::Storage,
        _pool: &mut lending_core::pool::Pool<TOKEN>,
        _asset: u8,
        _incentive_v1: &mut lending_core::incentive::Incentive,
        _incentive_v2: &mut lending_core::incentive_v2::Incentive,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun withdraw<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _incentive: &mut Balance<TOKEN>,
        _distribute: bool,
        _navi_account_cap: &AccountCap,
        _oracle_config: &mut oracle::config::OracleConfig,
        _price_oracle: &mut oracle::oracle::PriceOracle,
        _supra_oracle_holder: &SupraOracle::SupraSValueFeed::OracleHolder,
        _pyth_price_info: &pyth::price_info::PriceInfoObject,
        _feed_address: address,
        _storage: &mut lending_core::storage::Storage,
        _pool: &mut lending_core::pool::Pool<TOKEN>,
        _asset: u8,
        _incentive_v1: &mut lending_core::incentive::Incentive,
        _incentive_v2: &mut lending_core::incentive_v2::Incentive,
        _clock: &Clock,
    ): vector<u64> { abort 0 }
    #[deprecated]
    public fun reward<TOKEN>(
        _fee_pool: &mut BalancePool,
        _deposit_vault: &mut DepositVault,
        _distribute: bool,
        _navi_account_cap: &AccountCap,
        _storage: &mut lending_core::storage::Storage,
        _incentive_funds_pool: &mut lending_core::incentive_v2::IncentiveFundsPool<TOKEN>,
        _asset: u8,
        _option: u8,
        _incentive_v2: &mut lending_core::incentive_v2::Incentive,
        _clock: &Clock,
    ): vector<u64> { abort 0 }
}