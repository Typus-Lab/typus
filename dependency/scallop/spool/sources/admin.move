#[allow(deprecated_usage)]
module spool::admin {
    public struct AdminCap has store, key {
        id: sui::object::UID,
    }

    public struct CreateSpoolEvent has copy, drop {
        spool_id: sui::object::ID,
        staking_type: std::type_name::TypeName,
        distributed_point_per_period: u64,
        point_distribution_time: u64,
        max_distributed_point: u64,
        max_stakes: u64,
        created_at: u64,
    }

    public struct UpdateSpoolConfigEvent has copy, drop {
        spool_id: sui::object::ID,
        distributed_point_per_period: u64,
        point_distribution_time: u64,
        max_distributed_point: u64,
        max_stakes: u64,
        updated_at: u64,
    }

    public struct AddSpoolPointEvent has copy, drop {
        spool_id: sui::object::ID,
        new_points: u64,
        distributed_point_per_period: u64,
        incentive_duration: u64,
        updated_at: u64,
    }

    public fun add_rewards<T0>(arg0: &mut spool::rewards_pool::RewardsPool<T0>, arg1: sui::coin::Coin<T0>) {
        spool::rewards_pool::add_rewards<T0>(arg0, sui::coin::into_balance<T0>(arg1));
    }

    public fun take_old_rewards<T0>(_arg0: &AdminCap, arg1: &mut spool::rewards_pool::RewardsPool<T0>, arg2: u64, arg3: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        sui::coin::from_balance<T0>(spool::rewards_pool::take_old_rewards<T0>(arg1, arg2), arg3)
    }

    public fun take_rewards<T0>(_arg0: &AdminCap, arg1: &mut spool::rewards_pool::RewardsPool<T0>, arg2: u64, arg3: &mut sui::tx_context::TxContext) : sui::coin::Coin<T0> {
        sui::coin::from_balance<T0>(spool::rewards_pool::take_rewards<T0>(arg1, arg2), arg3)
    }

    public fun add_points(_arg0: &AdminCap, arg1: &mut spool::spool::Spool, arg2: u64, arg3: u64, arg4: &sui::clock::Clock) {
        spool::spool::accrue_points(arg1, arg4);
        let v0 = spool::spool::point_distribution_time(arg1);
        let v1 = spool::spool::max_distributed_point(arg1) + arg3;
        let v2 = (v1 - spool::spool::distributed_point(arg1)) / arg2 / v0;
        let max_stakes = spool::spool::max_stakes(arg1);
        spool::spool::update_config(arg1, v2, v0, v1, max_stakes);
        let v3 = AddSpoolPointEvent{
            spool_id                     : sui::object::id<spool::spool::Spool>(arg1),
            new_points                   : arg3,
            distributed_point_per_period : v2,
            incentive_duration           : arg2,
            updated_at                   : sui::clock::timestamp_ms(arg4) / 1000,
        };
        sui::event::emit<AddSpoolPointEvent>(v3);
    }

    #[allow(lint(share_owned))]
    public fun create_rewards_pool<T0>(_arg0: &AdminCap, arg1: &spool::spool::Spool, arg2: u64, arg3: u64, arg4: &mut sui::tx_context::TxContext) {
        sui::transfer::public_share_object<spool::rewards_pool::RewardsPool<T0>>(spool::rewards_pool::new<T0>(arg1, arg2, arg3, arg4));
    }

    #[allow(lint(share_owned))]
    public fun create_spool<T0>(_arg0: &AdminCap, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: &sui::clock::Clock, arg6: &mut sui::tx_context::TxContext) {
        let v0 = spool::spool::new<T0>(arg1, arg2, arg3, arg4, arg5, arg6);
        let v1 = CreateSpoolEvent{
            spool_id                     : sui::object::id<spool::spool::Spool>(&v0),
            staking_type                 : std::type_name::get<T0>(),
            distributed_point_per_period : arg1,
            point_distribution_time      : arg2,
            max_distributed_point        : arg3,
            max_stakes                   : arg4,
            created_at                   : sui::clock::timestamp_ms(arg5) / 1000,
        };
        sui::event::emit<CreateSpoolEvent>(v1);
        sui::transfer::public_share_object<spool::spool::Spool>(v0);
    }

    fun init(arg0: &mut sui::tx_context::TxContext) {
        let v0 = AdminCap{id: sui::object::new(arg0)};
        sui::transfer::transfer<AdminCap>(v0, sui::tx_context::sender(arg0));
    }

    public fun update_reward_fee_config<T0>(_arg0: &AdminCap, arg1: &mut spool::rewards_pool::RewardsPool<T0>, arg2: u64, arg3: u64, arg4: address) {
        spool::rewards_pool::update_reward_fee<T0>(arg1, arg2, arg3, arg4);
    }

    public fun update_spool_config(_arg0: &AdminCap, arg1: &mut spool::spool::Spool, arg2: u64, arg3: u64, arg4: u64, arg5: u64, arg6: &sui::clock::Clock) {
        spool::spool::accrue_points(arg1, arg6);
        spool::spool::update_config(arg1, arg2, arg3, arg4, arg5);
        let v0 = UpdateSpoolConfigEvent{
            spool_id                     : sui::object::id<spool::spool::Spool>(arg1),
            distributed_point_per_period : arg2,
            point_distribution_time      : arg3,
            max_distributed_point        : arg4,
            max_stakes                   : arg5,
            updated_at                   : sui::clock::timestamp_ms(arg6) / 1000,
        };
        sui::event::emit<UpdateSpoolConfigEvent>(v0);
    }

    // decompiled from Move bytecode v6
    #[test_only]
    public fun test_init(ctx: &mut sui::tx_context::TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun test_create_spool<TOKEN>(
        admin_cap: &AdminCap,
        distributed_point_per_period: u64,
        point_distribution_time: u64,
        max_distributed_point: u64,
        max_stakes: u64,
        clock: &sui::clock::Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        create_spool<TOKEN>(admin_cap,
            distributed_point_per_period,
            point_distribution_time,
            max_distributed_point,
            max_stakes,
            clock,
            ctx
        );
    }
}

