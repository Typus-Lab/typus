#[allow(deprecated_usage)]
module spool::user {
    public struct CreateSpoolAccountEvent has copy, drop {
        spool_account_id: sui::object::ID,
        spool_id: sui::object::ID,
        staking_type: std::type_name::TypeName,
        created_at: u64,
    }

    public struct SpoolAccountUnstakeEvent has copy, drop {
        spool_account_id: sui::object::ID,
        spool_id: sui::object::ID,
        staking_type: std::type_name::TypeName,
        unstake_amount: u64,
        remaining_amount: u64,
        timestamp: u64,
    }

    public struct SpoolAccountStakeEvent has copy, drop {
        sender: address,
        spool_account_id: sui::object::ID,
        spool_id: sui::object::ID,
        staking_type: std::type_name::TypeName,
        stake_amount: u64,
        previous_amount: u64,
        timestamp: u64,
    }

    #[deprecated]
    public struct SpoolAccountRedeemRewardsEvent has copy, drop {
        sender: address,
        spool_account_id: sui::object::ID,
        spool_id: sui::object::ID,
        rewards_pool_id: sui::object::ID,
        staking_type: std::type_name::TypeName,
        rewards_type: std::type_name::TypeName,
        redeemed_points: u64,
        previous_points: u64,
        rewards: u64,
        total_claimed_rewards: u64,
        total_user_points: u64,
        timestamp: u64,
    }

    public struct SpoolAccountRedeemRewardsEventV2 has copy, drop {
        sender: address,
        spool_account_id: sui::object::ID,
        spool_id: sui::object::ID,
        rewards_pool_id: sui::object::ID,
        staking_type: std::type_name::TypeName,
        rewards_type: std::type_name::TypeName,
        redeemed_points: u64,
        previous_points: u64,
        rewards_fee: u64,
        rewards: u64,
        total_claimed_rewards: u64,
        total_user_points: u64,
        timestamp: u64,
    }

    public fun redeem_rewards<T0, T1>(arg0: &mut spool::spool::Spool, arg1: &mut spool::rewards_pool::RewardsPool<T1>, arg2: &mut spool::spool_account::SpoolAccount<T0>, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) : sui::coin::Coin<T1> {
        spool::spool_account::assert_pool_id<T0>(arg0, arg2);
        spool::rewards_pool::assert_spool_id<T1>(arg1, arg0);
        spool::spool::accrue_points(arg0, arg3);
        spool::spool_account::accrue_points<T0>(arg0, arg2, arg3);
        let v0 = spool::spool_account::points<T0>(arg2);
        let mut v1 = spool::rewards_pool::redeem_rewards<T0, T1>(arg1, arg2);
        let v2 = sui::balance::value<T1>(&v1);
        let (v3, v4) = spool::rewards_pool::reward_fee<T1>(arg1);
        let v5 = if (v4 > 0) {
            spool::u64::mul_div(v2, v3, v4)
        } else {
            0
        };
        let v6 = SpoolAccountRedeemRewardsEventV2{
            sender                : sui::tx_context::sender(arg4),
            spool_account_id      : sui::object::id<spool::spool_account::SpoolAccount<T0>>(arg2),
            spool_id              : sui::object::id<spool::spool::Spool>(arg0),
            rewards_pool_id       : sui::object::id<spool::rewards_pool::RewardsPool<T1>>(arg1),
            staking_type          : std::type_name::get<T0>(),
            rewards_type          : std::type_name::get<T1>(),
            redeemed_points       : v0 - spool::spool_account::points<T0>(arg2),
            previous_points       : v0,
            rewards_fee           : v5,
            rewards               : v2,
            total_claimed_rewards : spool::rewards_pool::claimed_rewards<T1>(arg1),
            total_user_points     : spool::spool_account::total_points<T0>(arg2),
            timestamp             : sui::clock::timestamp_ms(arg3) / 1000,
        };
        sui::event::emit<SpoolAccountRedeemRewardsEventV2>(v6);
        if (v5 > 0) {
            sui::transfer::public_transfer<sui::coin::Coin<T1>>(sui::coin::from_balance<T1>(sui::balance::split<T1>(&mut v1, v5), arg4), spool::rewards_pool::reward_fee_recipient<T1>(arg1));
        };
        sui::coin::from_balance<T1>(v1, arg4)
    }

    public fun stake<T0>(arg0: &mut spool::spool::Spool, arg1: &mut spool::spool_account::SpoolAccount<T0>, arg2: sui::coin::Coin<T0>, arg3: &sui::clock::Clock, arg4: &sui::tx_context::TxContext) {
        spool::spool_account::assert_pool_id<T0>(arg0, arg1);
        spool::spool::accrue_points(arg0, arg3);
        spool::spool_account::accrue_points<T0>(arg0, arg1, arg3);
        let v0 = sui::coin::value<T0>(&arg2);
        assert!(spool::spool::stakes(arg0) + v0 <= spool::spool::max_stakes(arg0), 16);
        spool::spool::stake(arg0, v0);
        spool::spool_account::stake<T0>(arg0, arg1, sui::coin::into_balance<T0>(arg2));
        let v1 = SpoolAccountStakeEvent{
            sender           : sui::tx_context::sender(arg4),
            spool_account_id : sui::object::id<spool::spool_account::SpoolAccount<T0>>(arg1),
            spool_id         : sui::object::id<spool::spool::Spool>(arg0),
            staking_type     : std::type_name::get<T0>(),
            stake_amount     : v0,
            previous_amount  : spool::spool_account::stake_amount<T0>(arg1) - v0,
            timestamp        : sui::clock::timestamp_ms(arg3) / 1000,
        };
        sui::event::emit<SpoolAccountStakeEvent>(v1);
    }

    public fun unstake<T0>(arg0: &mut spool::spool::Spool, arg1: &mut spool::spool_account::SpoolAccount<T0>, arg2: u64, arg3: &sui::clock::Clock, arg4: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        spool::spool_account::assert_pool_id<T0>(arg0, arg1);
        spool::spool::accrue_points(arg0, arg3);
        spool::spool_account::accrue_points<T0>(arg0, arg1, arg3);
        spool::spool::unstake(arg0, arg2);
        let v0 = SpoolAccountUnstakeEvent{
            spool_account_id : sui::object::id<spool::spool_account::SpoolAccount<T0>>(arg1),
            spool_id         : sui::object::id<spool::spool::Spool>(arg0),
            staking_type     : std::type_name::get<T0>(),
            unstake_amount   : arg2,
            remaining_amount : spool::spool_account::stake_amount<T0>(arg1),
            timestamp        : sui::clock::timestamp_ms(arg3) / 1000,
        };
        sui::event::emit<SpoolAccountUnstakeEvent>(v0);
        sui::coin::from_balance<T0>(spool::spool_account::unstake<T0>(arg1, arg2), arg4)
    }

    public fun new_spool_account<T0>(arg0: &mut spool::spool::Spool, arg1: &sui::clock::Clock, arg2: &mut sui::tx_context::TxContext) : spool::spool_account::SpoolAccount<T0> {
        spool::spool::accrue_points(arg0, arg1);
        assert!(std::type_name::get<T0>() == spool::spool::stake_type(arg0), 17);
        let v0 = spool::spool_account::new<T0>(arg0, arg2);
        let v1 = CreateSpoolAccountEvent{
            spool_account_id : sui::object::id<spool::spool_account::SpoolAccount<T0>>(&v0),
            spool_id         : sui::object::id<spool::spool::Spool>(arg0),
            staking_type     : std::type_name::get<T0>(),
            created_at       : sui::clock::timestamp_ms(arg1) / 1000,
        };
        sui::event::emit<CreateSpoolAccountEvent>(v1);
        v0
    }

    public fun update_points<T0>(arg0: &mut spool::spool::Spool, arg1: &mut spool::spool_account::SpoolAccount<T0>, arg2: &sui::clock::Clock) {
        spool::spool::accrue_points(arg0, arg2);
        spool::spool_account::accrue_points<T0>(arg0, arg1, arg2);
    }

    // decompiled from Move bytecode v6
}

