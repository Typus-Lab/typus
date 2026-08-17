#[allow(deprecated_usage)]
module spool::spool {
    public struct Spool has store, key {
        id: sui::object::UID,
        stake_type: std::type_name::TypeName,
        distributed_point_per_period: u64,
        point_distribution_time: u64,
        distributed_point: u64,
        max_distributed_point: u64,
        max_stakes: u64,
        index: u64,
        stakes: u64,
        last_update: u64,
        created_at: u64,
    }

    public(package) fun new<T0>(arg0: u64, arg1: u64, arg2: u64, arg3: u64, arg4: &sui::clock::Clock, arg5: &mut sui::tx_context::TxContext) : Spool {
        let v0 = sui::clock::timestamp_ms(arg4) / 1000;
        Spool{
            id                           : sui::object::new(arg5),
            stake_type                   : std::type_name::get<T0>(),
            distributed_point_per_period : arg0,
            point_distribution_time      : arg1,
            distributed_point            : 0,
            max_distributed_point        : arg2,
            max_stakes                   : arg3,
            index                        : 1000000000,
            stakes                       : 0,
            last_update                  : v0,
            created_at                   : v0,
        }
    }

    public(package) fun accrue_points(arg0: &mut Spool, arg1: &sui::clock::Clock) {
        let v0 = sui::clock::timestamp_ms(arg1) / 1000;
        if (arg0.stakes == 0) {
            arg0.last_update = v0;
            return
        };
        let v1 = v0 - arg0.last_update;
        let v2 = v1 / arg0.point_distribution_time;
        if (v2 == 0) {
            return
        };
        let v3 = if (arg0.distributed_point > arg0.max_distributed_point) {
            0
        } else {
            arg0.max_distributed_point - arg0.distributed_point
        };
        let v4 = sui::math::min(arg0.distributed_point_per_period * v2, v3);
        arg0.last_update = v0 - v1 % arg0.point_distribution_time;
        arg0.distributed_point = arg0.distributed_point + v4;
        if (v4 == 0) {
            return
        };
        arg0.index = arg0.index + spool::u64::mul_div(1000000000, v4, arg0.stakes);
    }

    public fun base_index_rate() : u64 {
        1000000000
    }

    public fun distributed_point(arg0: &Spool) : u64 {
        arg0.distributed_point
    }

    public fun distributed_point_per_period(arg0: &Spool) : u64 {
        arg0.distributed_point_per_period
    }

    public fun index(arg0: &Spool) : u64 {
        arg0.index
    }

    public fun is_points_up_to_date(arg0: &Spool, arg1: &sui::clock::Clock) : bool {
        sui::clock::timestamp_ms(arg1) / 1000 - arg0.last_update < arg0.point_distribution_time
    }

    public fun last_update(arg0: &Spool) : u64 {
        arg0.last_update
    }

    public fun max_distributed_point(arg0: &Spool) : u64 {
        arg0.max_distributed_point
    }

    public fun max_stakes(arg0: &Spool) : u64 {
        arg0.max_stakes
    }

    public fun point_distribution_time(arg0: &Spool) : u64 {
        arg0.point_distribution_time
    }

    public(package) fun stake(arg0: &mut Spool, arg1: u64) {
        arg0.stakes = arg0.stakes + arg1;
    }

    public fun stake_type(arg0: &Spool) : std::type_name::TypeName {
        arg0.stake_type
    }

    public fun stakes(arg0: &Spool) : u64 {
        arg0.stakes
    }

    public(package) fun unstake(arg0: &mut Spool, arg1: u64) {
        arg0.stakes = arg0.stakes - arg1;
    }

    public(package) fun update_config(arg0: &mut Spool, arg1: u64, arg2: u64, arg3: u64, arg4: u64) {
        arg0.distributed_point_per_period = arg1;
        arg0.point_distribution_time = arg2;
        arg0.max_distributed_point = arg3;
        arg0.max_stakes = arg4;
    }

    #[test_only]
    public fun test_new<T0>(ctx: &mut sui::tx_context::TxContext) : Spool {
        Spool{
            id                           : sui::object::new(ctx),
            stake_type                   : std::type_name::get<T0>(),
            distributed_point_per_period : 0,
            point_distribution_time      : 0,
            distributed_point            : 0,
            max_distributed_point        : 0,
            max_stakes                   : 0,
            index                        : 1000000000,
            stakes                       : 0,
            last_update                  : 0,
            created_at                   : 0,
        }
    }

    #[test_only]
    public fun test_drop(spool: Spool) {
        let Spool{
            id,
            stake_type: _,
            distributed_point_per_period: _,
            point_distribution_time: _,
            distributed_point: _,
            max_distributed_point: _,
            max_stakes: _,
            index: _,
            stakes: _,
            last_update: _,
            created_at: _,
        } = spool;
        id.delete();
    }

    // decompiled from Move bytecode v6
}

