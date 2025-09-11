module lending_core::lending {
    public struct DepositEvent has copy, drop {
        reserve: u8,
        sender: address,
        amount: u64,
    }

    public struct DepositOnBehalfOfEvent has copy, drop {
        reserve: u8,
        sender: address,
        user: address,
        amount: u64,
    }

    public struct WithdrawEvent has copy, drop {
        reserve: u8,
        sender: address,
        to: address,
        amount: u64,
    }

    public struct BorrowEvent has copy, drop {
        reserve: u8,
        sender: address,
        amount: u64,
    }

    public struct RepayEvent has copy, drop {
        reserve: u8,
        sender: address,
        amount: u64,
    }

    public struct RepayOnBehalfOfEvent has copy, drop {
        reserve: u8,
        sender: address,
        user: address,
        amount: u64,
    }

    public struct LiquidationCallEvent has copy, drop {
        reserve: u8,
        sender: address,
        liquidate_user: address,
        liquidate_amount: u64,
    }

    public struct LiquidationEvent has copy, drop {
        sender: address,
        user: address,
        collateral_asset: u8,
        collateral_price: u256,
        collateral_amount: u64,
        treasury: u64,
        debt_asset: u8,
        debt_price: u256,
        debt_amount: u64,
    }

    public entry fun borrow<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: u64, arg6: &mut 0x2::tx_context::TxContext) {
        abort 0
    }

    public entry fun repay<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: 0x2::coin::Coin<T0>, arg6: u64, arg7: &mut 0x2::tx_context::TxContext) {
        abort 0
    }

    fun when_not_paused(arg0: &lending_core::storage::Storage) {
        assert!(!lending_core::storage::pause(arg0), lending_core::error::paused());
    }

    fun base_borrow<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: u64, arg6: address) : 0x2::balance::Balance<T0> {
        lending_core::storage::when_not_paused(arg2);
        lending_core::storage::version_verification(arg2);
        lending_core::logic::execute_borrow<T0>(arg0, arg1, arg2, arg4, arg6, lending_core::pool::normal_amount<T0>(arg3, arg5) as u256);
        let v0 = BorrowEvent{
            reserve : arg4,
            sender  : arg6,
            amount  : arg5,
        };
        0x2::event::emit<BorrowEvent>(v0);
        lending_core::pool::withdraw_balance<T0>(arg3, arg5, arg6)
    }

    fun base_deposit<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &mut lending_core::pool::Pool<T0>, arg3: u8, arg4: address, arg5: 0x2::balance::Balance<T0>) {
        lending_core::storage::when_not_paused(arg1);
        lending_core::storage::version_verification(arg1);
        let v0 = 0x2::balance::value<T0>(&arg5);
        lending_core::pool::deposit_balance<T0>(arg2, arg5, arg4);
        lending_core::logic::execute_deposit<T0>(arg0, arg1, arg3, arg4, lending_core::pool::normal_amount<T0>(arg2, v0) as u256);
        let v1 = DepositEvent{
            reserve : arg3,
            sender  : arg4,
            amount  : v0,
        };
        0x2::event::emit<DepositEvent>(v1);
    }

    fun base_flash_loan<T0>(arg0: &lending_core::flash_loan::Config, arg1: &mut lending_core::pool::Pool<T0>, arg2: address, arg3: u64) : (0x2::balance::Balance<T0>, lending_core::flash_loan::Receipt<T0>) {
        lending_core::flash_loan::loan<T0>(arg0, arg1, arg2, arg3)
    }

    fun base_flash_repay<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &mut lending_core::pool::Pool<T0>, arg3: lending_core::flash_loan::Receipt<T0>, arg4: address, arg5: 0x2::balance::Balance<T0>) : 0x2::balance::Balance<T0> {
        lending_core::flash_loan::repay<T0>(arg0, arg1, arg2, arg3, arg4, arg5)
    }

    fun base_liquidation_call<T0, T1>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: &mut lending_core::pool::Pool<T0>, arg5: 0x2::balance::Balance<T0>, arg6: u8, arg7: &mut lending_core::pool::Pool<T1>, arg8: address, arg9: address) : (0x2::balance::Balance<T0>, 0x2::balance::Balance<T1>) {
        lending_core::storage::when_not_paused(arg2);
        lending_core::storage::version_verification(arg2);
        let v0 = 0x2::balance::value<T0>(&arg5);
        lending_core::pool::deposit_balance<T0>(arg4, arg5, arg8);
        let (v1, v2, v3) = lending_core::logic::execute_liquidate<T0, T1>(arg0, arg1, arg2, arg9, arg6, arg3, lending_core::pool::normal_amount<T0>(arg4, v0) as u256);
        let v4 = lending_core::pool::unnormal_amount<T1>(arg7, v3 as u64);
        lending_core::pool::deposit_treasury<T1>(arg7, v4);
        let v5 = lending_core::pool::unnormal_amount<T1>(arg7, v1 as u64);
        let v6 = lending_core::pool::unnormal_amount<T0>(arg4, v2 as u64);
        let (_, v8, _) = 0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::get_token_price(arg0, arg1, lending_core::storage::get_oracle_id(arg2, arg6));
        let (_, v11, _) = 0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::get_token_price(arg0, arg1, lending_core::storage::get_oracle_id(arg2, arg3));
        let v13 = LiquidationEvent{
            sender            : arg8,
            user              : arg9,
            collateral_asset  : arg6,
            collateral_price  : v8,
            collateral_amount : v5 + v4,
            treasury          : v4,
            debt_asset        : arg3,
            debt_price        : v11,
            debt_amount       : v0 - v6,
        };
        0x2::event::emit<LiquidationEvent>(v13);
        (lending_core::pool::withdraw_balance<T0>(arg4, v6, arg8), lending_core::pool::withdraw_balance<T1>(arg7, v5, arg8))
    }

    fun base_repay<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: 0x2::balance::Balance<T0>, arg6: address) : 0x2::balance::Balance<T0> {
        lending_core::storage::when_not_paused(arg2);
        lending_core::storage::version_verification(arg2);
        let v0 = 0x2::balance::value<T0>(&arg5);
        lending_core::pool::deposit_balance<T0>(arg3, arg5, arg6);
        let v1 = lending_core::pool::unnormal_amount<T0>(arg3, lending_core::logic::execute_repay<T0>(arg0, arg1, arg2, arg4, arg6, lending_core::pool::normal_amount<T0>(arg3, v0) as u256) as u64);
        let v2 = RepayEvent{
            reserve : arg4,
            sender  : arg6,
            amount  : v0 - v1,
        };
        0x2::event::emit<RepayEvent>(v2);
        if (v1 > 0) {
            return lending_core::pool::withdraw_balance<T0>(arg3, v1, arg6)
        };
        0x2::balance::zero<T0>()
    }

    fun base_withdraw<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: u64, arg6: address) : 0x2::balance::Balance<T0> {
        lending_core::storage::when_not_paused(arg2);
        lending_core::storage::version_verification(arg2);
        let v0 = lending_core::pool::unnormal_amount<T0>(arg3, lending_core::logic::execute_withdraw<T0>(arg0, arg1, arg2, arg4, arg6, lending_core::pool::normal_amount<T0>(arg3, arg5) as u256));
        let v1 = WithdrawEvent{
            reserve : arg4,
            sender  : arg6,
            to      : arg6,
            amount  : v0,
        };
        0x2::event::emit<WithdrawEvent>(v1);
        lending_core::pool::withdraw_balance<T0>(arg3, v0, arg6)
    }

    public(package) fun borrow_coin<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: u64, arg6: &mut 0x2::tx_context::TxContext) : 0x2::balance::Balance<T0> {
        base_borrow<T0>(arg0, arg1, arg2, arg3, arg4, arg5, 0x2::tx_context::sender(arg6))
    }

    public(package) fun borrow_with_account_cap<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: u64, arg6: &lending_core::account::AccountCap) : 0x2::balance::Balance<T0> {
        base_borrow<T0>(arg0, arg1, arg2, arg3, arg4, arg5, lending_core::account::account_owner(arg6))
    }

    public fun create_account(arg0: &mut 0x2::tx_context::TxContext) : lending_core::account::AccountCap {
        lending_core::account::create_account_cap(arg0)
    }

    public fun delete_account(arg0: lending_core::account::AccountCap) {
        abort 0
    }

    public entry fun deposit<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &mut lending_core::pool::Pool<T0>, arg3: u8, arg4: 0x2::coin::Coin<T0>, arg5: u64, arg6: &mut lending_core::incentive::Incentive, arg7: &mut 0x2::tx_context::TxContext) {
        abort 0
    }

    public(package) fun deposit_coin<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &mut lending_core::pool::Pool<T0>, arg3: u8, arg4: 0x2::coin::Coin<T0>, arg5: u64, arg6: &mut 0x2::tx_context::TxContext) {
        base_deposit<T0>(arg0, arg1, arg2, arg3, 0x2::tx_context::sender(arg6), lending_core::utils::split_coin_to_balance<T0>(arg4, arg5, arg6));
    }

    public(package) fun deposit_on_behalf_of_user<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &mut lending_core::pool::Pool<T0>, arg3: u8, arg4: address, arg5: 0x2::coin::Coin<T0>, arg6: u64, arg7: &mut 0x2::tx_context::TxContext) {
        base_deposit<T0>(arg0, arg1, arg2, arg3, arg4, lending_core::utils::split_coin_to_balance<T0>(arg5, arg6, arg7));
        let v0 = DepositOnBehalfOfEvent{
            reserve : arg3,
            sender  : 0x2::tx_context::sender(arg7),
            user    : arg4,
            amount  : arg6,
        };
        0x2::event::emit<DepositOnBehalfOfEvent>(v0);
    }

    public(package) fun deposit_with_account_cap<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &mut lending_core::pool::Pool<T0>, arg3: u8, arg4: 0x2::coin::Coin<T0>, arg5: &lending_core::account::AccountCap) {
        base_deposit<T0>(arg0, arg1, arg2, arg3, lending_core::account::account_owner(arg5), 0x2::coin::into_balance<T0>(arg4));
    }

    public fun flash_loan_with_account_cap<T0>(arg0: &lending_core::flash_loan::Config, arg1: &mut lending_core::pool::Pool<T0>, arg2: u64, arg3: &lending_core::account::AccountCap) : (0x2::balance::Balance<T0>, lending_core::flash_loan::Receipt<T0>) {
        base_flash_loan<T0>(arg0, arg1, lending_core::account::account_owner(arg3), arg2)
    }

    public fun flash_loan_with_ctx<T0>(arg0: &lending_core::flash_loan::Config, arg1: &mut lending_core::pool::Pool<T0>, arg2: u64, arg3: &mut 0x2::tx_context::TxContext) : (0x2::balance::Balance<T0>, lending_core::flash_loan::Receipt<T0>) {
        base_flash_loan<T0>(arg0, arg1, 0x2::tx_context::sender(arg3), arg2)
    }

    public fun flash_repay_with_account_cap<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &mut lending_core::pool::Pool<T0>, arg3: lending_core::flash_loan::Receipt<T0>, arg4: 0x2::balance::Balance<T0>, arg5: &lending_core::account::AccountCap) : 0x2::balance::Balance<T0> {
        base_flash_repay<T0>(arg0, arg1, arg2, arg3, lending_core::account::account_owner(arg5), arg4)
    }

    public fun flash_repay_with_ctx<T0>(arg0: &0x2::clock::Clock, arg1: &mut lending_core::storage::Storage, arg2: &mut lending_core::pool::Pool<T0>, arg3: lending_core::flash_loan::Receipt<T0>, arg4: 0x2::balance::Balance<T0>, arg5: &mut 0x2::tx_context::TxContext) : 0x2::balance::Balance<T0> {
        base_flash_repay<T0>(arg0, arg1, arg2, arg3, 0x2::tx_context::sender(arg5), arg4)
    }

    public(package) fun liquidation<T0, T1>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: &mut lending_core::pool::Pool<T0>, arg5: 0x2::coin::Coin<T0>, arg6: u8, arg7: &mut lending_core::pool::Pool<T1>, arg8: address, arg9: u64, arg10: &mut 0x2::tx_context::TxContext) : (0x2::balance::Balance<T1>, 0x2::balance::Balance<T0>) {
        let (v0, v1) = base_liquidation_call<T0, T1>(arg0, arg1, arg2, arg3, arg4, lending_core::utils::split_coin_to_balance<T0>(arg5, arg9, arg10), arg6, arg7, 0x2::tx_context::sender(arg10), arg8);
        (v1, v0)
    }

    public entry fun liquidation_call<T0, T1>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: &mut lending_core::pool::Pool<T0>, arg5: u8, arg6: &mut lending_core::pool::Pool<T1>, arg7: 0x2::coin::Coin<T0>, arg8: address, arg9: u64, arg10: &mut lending_core::incentive::Incentive, arg11: &mut 0x2::tx_context::TxContext) {
        abort 0
    }

    public(package) fun liquidation_non_entry<T0, T1>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: u8, arg4: &mut lending_core::pool::Pool<T0>, arg5: 0x2::balance::Balance<T0>, arg6: u8, arg7: &mut lending_core::pool::Pool<T1>, arg8: address, arg9: &mut 0x2::tx_context::TxContext) : (0x2::balance::Balance<T1>, 0x2::balance::Balance<T0>) {
        let (v0, v1) = base_liquidation_call<T0, T1>(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, 0x2::tx_context::sender(arg9), arg8);
        (v1, v0)
    }

    public(package) fun repay_coin<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: 0x2::coin::Coin<T0>, arg6: u64, arg7: &mut 0x2::tx_context::TxContext) : 0x2::balance::Balance<T0> {
        base_repay<T0>(arg0, arg1, arg2, arg3, arg4, lending_core::utils::split_coin_to_balance<T0>(arg5, arg6, arg7), 0x2::tx_context::sender(arg7))
    }

    public(package) fun repay_on_behalf_of_user<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: address, arg6: 0x2::coin::Coin<T0>, arg7: u64, arg8: &mut 0x2::tx_context::TxContext) : 0x2::balance::Balance<T0> {
        let v0 = base_repay<T0>(arg0, arg1, arg2, arg3, arg4, lending_core::utils::split_coin_to_balance<T0>(arg6, arg7, arg8), arg5);
        let v1 = RepayOnBehalfOfEvent{
            reserve : arg4,
            sender  : 0x2::tx_context::sender(arg8),
            user    : arg5,
            amount  : arg7 - 0x2::balance::value<T0>(&v0),
        };
        0x2::event::emit<RepayOnBehalfOfEvent>(v1);
        v0
    }

    public(package) fun repay_with_account_cap<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: 0x2::coin::Coin<T0>, arg6: &lending_core::account::AccountCap) : 0x2::balance::Balance<T0> {
        base_repay<T0>(arg0, arg1, arg2, arg3, arg4, 0x2::coin::into_balance<T0>(arg5), lending_core::account::account_owner(arg6))
    }

    public entry fun withdraw<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: u64, arg6: address, arg7: &mut lending_core::incentive::Incentive, arg8: &mut 0x2::tx_context::TxContext) {
        abort 0
    }

    public(package) fun withdraw_coin<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: u64, arg6: &mut 0x2::tx_context::TxContext) : 0x2::balance::Balance<T0> {
        base_withdraw<T0>(arg0, arg1, arg2, arg3, arg4, arg5, 0x2::tx_context::sender(arg6))
    }

    public(package) fun withdraw_with_account_cap<T0>(arg0: &0x2::clock::Clock, arg1: &0xca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle::PriceOracle, arg2: &mut lending_core::storage::Storage, arg3: &mut lending_core::pool::Pool<T0>, arg4: u8, arg5: u64, arg6: &lending_core::account::AccountCap) : 0x2::balance::Balance<T0> {
        base_withdraw<T0>(arg0, arg1, arg2, arg3, arg4, arg5, lending_core::account::account_owner(arg6))
    }

    // decompiled from Move bytecode v6
}

