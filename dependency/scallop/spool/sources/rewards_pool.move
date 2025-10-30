#[allow(deprecated_usage)]
module spool::rewards_pool {
    public struct RewardsPool<phantom T0> has store, key {
        id: sui::object::UID,
        spool_id: sui::object::ID,
        exchange_rate_numerator: u64,
        exchange_rate_denominator: u64,
        rewards: sui::balance::Balance<T0>,
        claimed_rewards: u64,
    }

    public struct RewardsPoolFeeKey has copy, drop, store {
        dummy_field: bool,
    }

    public struct RewardsPoolFee has store {
        fee_rate_numerator: u64,
        fee_rate_denominator: u64,
        recipient: address,
    }

    public struct RewardsPoolRewardsBalanceKey has copy, drop, store {
        dummy_field: bool,
    }

    public(package) fun new<T0>(arg0: &spool::spool::Spool, arg1: u64, arg2: u64, arg3: &mut sui::tx_context::TxContext) : RewardsPool<T0> {
        RewardsPool<T0>{
            id                        : sui::object::new(arg3),
            spool_id                  : sui::object::id<spool::spool::Spool>(arg0),
            exchange_rate_numerator   : arg1,
            exchange_rate_denominator : arg2,
            rewards                   : sui::balance::zero<T0>(),
            claimed_rewards           : 0,
        }
    }

    public(package) fun add_rewards<T0>(arg0: &mut RewardsPool<T0>, arg1: sui::balance::Balance<T0>) {
        create_rewards_balance_if_not_exists<T0>(arg0);
        let v0 = RewardsPoolRewardsBalanceKey{dummy_field: false};
        sui::balance::join<T0>(sui::dynamic_field::borrow_mut<RewardsPoolRewardsBalanceKey, sui::balance::Balance<T0>>(&mut arg0.id, v0), arg1);
    }

    public fun assert_spool_id<T0>(arg0: &RewardsPool<T0>, arg1: &spool::spool::Spool) {
        assert!(arg0.spool_id == sui::object::id<spool::spool::Spool>(arg1), 16);
    }

    public fun calculate_point_to_reward<T0>(arg0: &RewardsPool<T0>, arg1: u64) : u64 {
        spool::u64::mul_div(arg1, arg0.exchange_rate_numerator, arg0.exchange_rate_denominator)
    }

    public fun calculate_reward_to_point<T0>(arg0: &RewardsPool<T0>, arg1: u64) : u64 {
        spool::u64::mul_div(arg1, arg0.exchange_rate_denominator, arg0.exchange_rate_numerator)
    }

    public fun claimed_rewards<T0>(arg0: &RewardsPool<T0>) : u64 {
        arg0.claimed_rewards
    }

    fun create_rewards_balance_if_not_exists<T0>(arg0: &mut RewardsPool<T0>) {
        let v0 = RewardsPoolRewardsBalanceKey{dummy_field: false};
        if (!sui::dynamic_field::exists_<RewardsPoolRewardsBalanceKey>(&arg0.id, v0)) {
            let v1 = RewardsPoolRewardsBalanceKey{dummy_field: false};
            sui::dynamic_field::add<RewardsPoolRewardsBalanceKey, sui::balance::Balance<T0>>(&mut arg0.id, v1, sui::balance::zero<T0>());
        };
    }

    public(package) fun redeem_rewards<T0, T1>(arg0: &mut RewardsPool<T1>, arg1: &mut spool::spool_account::SpoolAccount<T0>) : sui::balance::Balance<T1> {
        let v0 = sui::math::min(calculate_point_to_reward<T1>(arg0, spool::spool_account::points<T0>(arg1)), rewards<T1>(arg0));
        arg0.claimed_rewards = arg0.claimed_rewards + v0;
        spool::spool_account::redeem_point<T0>(arg1, calculate_reward_to_point<T1>(arg0, v0));
        take_rewards<T1>(arg0, v0)
    }

    public fun reward_fee<T0>(arg0: &RewardsPool<T0>) : (u64, u64) {
        let v0 = RewardsPoolFeeKey{dummy_field: false};
        if (sui::dynamic_field::exists_<RewardsPoolFeeKey>(&arg0.id, v0)) {
            let v3 = RewardsPoolFeeKey{dummy_field: false};
            let v4 = sui::dynamic_field::borrow<RewardsPoolFeeKey, RewardsPoolFee>(&arg0.id, v3);
            (v4.fee_rate_numerator, v4.fee_rate_denominator)
        } else {
            (0, 0)
        }
    }

    public fun reward_fee_recipient<T0>(arg0: &RewardsPool<T0>) : address {
        let v0 = RewardsPoolFeeKey{dummy_field: false};
        assert!(sui::dynamic_field::exists_<RewardsPoolFeeKey>(&arg0.id, v0), 0);
        let v1 = RewardsPoolFeeKey{dummy_field: false};
        sui::dynamic_field::borrow<RewardsPoolFeeKey, RewardsPoolFee>(&arg0.id, v1).recipient
    }

    public fun rewards<T0>(arg0: &RewardsPool<T0>) : u64 {
        let v0 = RewardsPoolRewardsBalanceKey{dummy_field: false};
        sui::balance::value<T0>(sui::dynamic_field::borrow<RewardsPoolRewardsBalanceKey, sui::balance::Balance<T0>>(&arg0.id, v0))
    }

    public(package) fun take_old_rewards<T0>(arg0: &mut RewardsPool<T0>, arg1: u64) : sui::balance::Balance<T0> {
        sui::balance::split<T0>(&mut arg0.rewards, arg1)
    }

    public(package) fun take_rewards<T0>(arg0: &mut RewardsPool<T0>, arg1: u64) : sui::balance::Balance<T0> {
        let v0 = RewardsPoolRewardsBalanceKey{dummy_field: false};
        sui::balance::split<T0>(sui::dynamic_field::borrow_mut<RewardsPoolRewardsBalanceKey, sui::balance::Balance<T0>>(&mut arg0.id, v0), arg1)
    }

    public(package) fun update_reward_fee<T0>(arg0: &mut RewardsPool<T0>, arg1: u64, arg2: u64, arg3: address) {
        let v0 = RewardsPoolFeeKey{dummy_field: false};
        if (sui::dynamic_field::exists_<RewardsPoolFeeKey>(&arg0.id, v0)) {
            let v1 = RewardsPoolFeeKey{dummy_field: false};
            let v2 = sui::dynamic_field::borrow_mut<RewardsPoolFeeKey, RewardsPoolFee>(&mut arg0.id, v1);
            v2.fee_rate_numerator = arg1;
            v2.fee_rate_denominator = arg2;
            v2.recipient = arg3;
        } else {
            let v3 = RewardsPoolFee{
                fee_rate_numerator   : arg1,
                fee_rate_denominator : arg2,
                recipient            : arg3,
            };
            let v4 = RewardsPoolFeeKey{dummy_field: false};
            sui::dynamic_field::add<RewardsPoolFeeKey, RewardsPoolFee>(&mut arg0.id, v4, v3);
        };
    }

    #[test_only]
    public fun test_new<T0>(arg0: &spool::spool::Spool, arg3: &mut sui::tx_context::TxContext) : RewardsPool<T0> {
        RewardsPool<T0>{
            id                        : sui::object::new(arg3),
            spool_id                  : sui::object::id<spool::spool::Spool>(arg0),
            exchange_rate_numerator   : 0,
            exchange_rate_denominator : 0,
            rewards                   : sui::balance::zero<T0>(),
            claimed_rewards           : 0,
        }
    }

    #[test_only]
    public fun test_drop<T0>(rewards_pool: RewardsPool<T0>) {
        let RewardsPool{
            id,
            spool_id: _,
            exchange_rate_numerator: _,
            exchange_rate_denominator: _,
            rewards,
            claimed_rewards: _,
        } = rewards_pool;
        id.delete();
        rewards.destroy_for_testing();
    }

    // decompiled from Move bytecode v6
}

