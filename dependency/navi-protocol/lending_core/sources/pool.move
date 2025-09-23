module lending_core::pool {
    public struct Pool<phantom T0> has store, key {
        id: 0x2::object::UID,
        balance: 0x2::balance::Balance<T0>,
        treasury_balance: 0x2::balance::Balance<T0>,
        decimal: u8,
    }

    public struct PoolAdminCap has store, key {
        id: 0x2::object::UID,
        creator: address,
    }

    public struct PoolCreate has copy, drop {
        creator: address,
    }

    public struct PoolBalanceRegister has copy, drop {
        sender: address,
        amount: u64,
        new_amount: u64,
        pool: 0x1::ascii::String,
    }

    public struct PoolDeposit has copy, drop {
        sender: address,
        amount: u64,
        pool: 0x1::ascii::String,
    }

    public struct PoolWithdraw has copy, drop {
        sender: address,
        recipient: address,
        amount: u64,
        pool: 0x1::ascii::String,
    }

    public struct PoolWithdrawReserve has copy, drop {
        sender: address,
        recipient: address,
        amount: u64,
        before: u64,
        after: u64,
        pool: 0x1::ascii::String,
        poolId: address,
    }

    public fun convert_amount(mut arg0: u64, mut arg1: u8, arg2: u8) : u64 {
        while (arg1 != arg2) {
            if (arg1 < arg2) {
                arg0 = arg0 * 10;
                arg1 = arg1 + 1;
                continue
            };
            arg0 = arg0 / 10;
            arg1 = arg1 - 1;
        };
        arg0
    }

    public(package) fun create_pool<T0>(arg0: &PoolAdminCap, arg1: u8, arg2: &mut 0x2::tx_context::TxContext) {
        let v0 = Pool<T0>{
            id               : 0x2::object::new(arg2),
            balance          : 0x2::balance::zero<T0>(),
            treasury_balance : 0x2::balance::zero<T0>(),
            decimal          : arg1,
        };
        0x2::transfer::share_object<Pool<T0>>(v0);
        let v1 = PoolCreate{creator: 0x2::tx_context::sender(arg2)};
        0x2::event::emit<PoolCreate>(v1);
    }

    public(package) fun deposit<T0>(arg0: &mut Pool<T0>, arg1: 0x2::coin::Coin<T0>, arg2: &mut 0x2::tx_context::TxContext) {
        let v0 = PoolDeposit{
            sender : 0x2::tx_context::sender(arg2),
            amount : 0x2::coin::value<T0>(&arg1),
            pool   : 0x1::type_name::into_string(0x1::type_name::get<T0>()),
        };
        0x2::event::emit<PoolDeposit>(v0);
        0x2::balance::join<T0>(&mut arg0.balance, 0x2::coin::into_balance<T0>(arg1));
    }

    public(package) fun deposit_balance<T0>(arg0: &mut Pool<T0>, arg1: 0x2::balance::Balance<T0>, arg2: address) {
        let v0 = PoolDeposit{
            sender : arg2,
            amount : 0x2::balance::value<T0>(&arg1),
            pool   : 0x1::type_name::into_string(0x1::type_name::get<T0>()),
        };
        0x2::event::emit<PoolDeposit>(v0);
        0x2::balance::join<T0>(&mut arg0.balance, arg1);
    }

    public(package) fun deposit_treasury<T0>(arg0: &mut Pool<T0>, arg1: u64) {
        assert!(0x2::balance::value<T0>(&arg0.balance) >= arg1, lending_core::error::insufficient_balance());
        0x2::balance::join<T0>(&mut arg0.treasury_balance, 0x2::balance::split<T0>(&mut arg0.balance, arg1));
    }

    public fun get_coin_decimal<T0>(arg0: &Pool<T0>) : u8 {
        arg0.decimal
    }

    fun init(arg0: &mut 0x2::tx_context::TxContext) {
        let v0 = PoolAdminCap{
            id      : 0x2::object::new(arg0),
            creator : 0x2::tx_context::sender(arg0),
        };
        0x2::transfer::public_transfer<PoolAdminCap>(v0, 0x2::tx_context::sender(arg0));
    }

    public fun normal_amount<T0>(arg0: &Pool<T0>, arg1: u64) : u64 {
        convert_amount(arg1, get_coin_decimal<T0>(arg0), 9)
    }

    public fun uid<T0>(arg0: &Pool<T0>) : &0x2::object::UID {
        &arg0.id
    }

    public fun unnormal_amount<T0>(arg0: &Pool<T0>, arg1: u64) : u64 {
        convert_amount(arg1, 9, get_coin_decimal<T0>(arg0))
    }

    public(package) fun withdraw<T0>(arg0: &mut Pool<T0>, arg1: u64, arg2: address, arg3: &mut 0x2::tx_context::TxContext) {
        let v0 = PoolWithdraw{
            sender    : 0x2::tx_context::sender(arg3),
            recipient : arg2,
            amount    : arg1,
            pool      : 0x1::type_name::into_string(0x1::type_name::get<T0>()),
        };
        0x2::event::emit<PoolWithdraw>(v0);
        0x2::transfer::public_transfer<0x2::coin::Coin<T0>>(0x2::coin::from_balance<T0>(0x2::balance::split<T0>(&mut arg0.balance, arg1), arg3), arg2);
    }

    public(package) fun withdraw_balance<T0>(arg0: &mut Pool<T0>, arg1: u64, arg2: address) : 0x2::balance::Balance<T0> {
        if (arg1 == 0) {
            return 0x2::balance::zero<T0>()
        };
        let v0 = PoolWithdraw{
            sender    : arg2,
            recipient : arg2,
            amount    : arg1,
            pool      : 0x1::type_name::into_string(0x1::type_name::get<T0>()),
        };
        0x2::event::emit<PoolWithdraw>(v0);
        0x2::balance::split<T0>(&mut arg0.balance, arg1)
    }

    public(package) fun withdraw_reserve_balance<T0>(arg0: &PoolAdminCap, arg1: &mut Pool<T0>, arg2: u64, arg3: address, arg4: &mut 0x2::tx_context::TxContext) {
        let v0 = 0x2::balance::value<T0>(&arg1.balance);
        assert!(v0 >= arg2, lending_core::error::insufficient_balance());
        let v1 = PoolWithdrawReserve{
            sender    : 0x2::tx_context::sender(arg4),
            recipient : arg3,
            amount    : arg2,
            before    : v0,
            after     : 0x2::balance::value<T0>(&arg1.balance),
            pool      : 0x1::type_name::into_string(0x1::type_name::get<T0>()),
            poolId    : 0x2::object::uid_to_address(&arg1.id),
        };
        0x2::event::emit<PoolWithdrawReserve>(v1);
        0x2::transfer::public_transfer<0x2::coin::Coin<T0>>(0x2::coin::from_balance<T0>(0x2::balance::split<T0>(&mut arg1.balance, arg2), arg4), arg3);
    }

    public fun withdraw_treasury<T0>(arg0: &mut PoolAdminCap, arg1: &mut Pool<T0>, arg2: u64, arg3: address, arg4: &mut 0x2::tx_context::TxContext) {
        assert!(0x2::balance::value<T0>(&arg1.treasury_balance) >= arg2, lending_core::error::insufficient_balance());
        0x2::transfer::public_transfer<0x2::coin::Coin<T0>>(0x2::coin::from_balance<T0>(0x2::balance::split<T0>(&mut arg1.treasury_balance, arg2), arg4), arg3);
    }

    // decompiled from Move bytecode v6

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun test_create_pool<T>(pool_admin_cap: &PoolAdminCap, decimal: u8, ctx: &mut TxContext) {
        create_pool<T>(pool_admin_cap, decimal, ctx);
    }
}

