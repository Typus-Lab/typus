#[allow(deprecated_usage)]
module spool::spool_account {
    public struct SpoolAccount<phantom T0> has store, key {
        id: sui::object::UID,
        spool_id: sui::object::ID,
        stake_type: std::type_name::TypeName,
        stakes: sui::balance::Balance<T0>,
        points: u64,
        total_points: u64,
        index: u64,
    }

    public(package) fun new<T0>(arg0: &spool::spool::Spool, arg1: &mut sui::tx_context::TxContext) : SpoolAccount<T0> {
        SpoolAccount<T0>{
            id           : sui::object::new(arg1),
            spool_id     : sui::object::id<spool::spool::Spool>(arg0),
            stake_type   : std::type_name::get<T0>(),
            stakes       : sui::balance::zero<T0>(),
            points       : 0,
            total_points : 0,
            index        : spool::spool::index(arg0),
        }
    }

    public(package) fun accrue_points<T0>(arg0: &spool::spool::Spool, arg1: &mut SpoolAccount<T0>, arg2: &sui::clock::Clock) {
        assert!(spool::spool::is_points_up_to_date(arg0, arg2), 18);
        if (arg1.index >= spool::spool::index(arg0)) {
            return
        };
        if (sui::balance::value<T0>(&arg1.stakes) == 0) {
            arg1.index = spool::spool::index(arg0);
            return
        };
        let v0 = spool::u64::mul_div(sui::balance::value<T0>(&arg1.stakes), spool::spool::index(arg0) - arg1.index, spool::spool::base_index_rate());
        arg1.index = spool::spool::index(arg0);
        arg1.points = arg1.points + v0;
        arg1.total_points = arg1.total_points + v0;
    }

    public fun assert_pool_id<T0>(arg0: &spool::spool::Spool, arg1: &SpoolAccount<T0>) {
        assert!(arg1.spool_id == sui::object::id<spool::spool::Spool>(arg0), 19);
    }

    public fun points<T0>(arg0: &SpoolAccount<T0>) : u64 {
        arg0.points
    }

    public(package) fun redeem_point<T0>(arg0: &mut SpoolAccount<T0>, arg1: u64) {
        arg0.points = arg0.points - arg1;
    }

    public fun spool_id<T0>(arg0: &SpoolAccount<T0>) : sui::object::ID {
        arg0.spool_id
    }

    public(package) fun stake<T0>(arg0: &spool::spool::Spool, arg1: &mut SpoolAccount<T0>, arg2: sui::balance::Balance<T0>) {
        assert!(arg1.index == spool::spool::index(arg0), 17);
        sui::balance::join<T0>(&mut arg1.stakes, arg2);
    }

    public fun stake_amount<T0>(arg0: &SpoolAccount<T0>) : u64 {
        sui::balance::value<T0>(&arg0.stakes)
    }

    public fun stake_type<T0>(arg0: &SpoolAccount<T0>) : std::type_name::TypeName {
        arg0.stake_type
    }

    public fun total_points<T0>(arg0: &SpoolAccount<T0>) : u64 {
        arg0.total_points
    }

    public(package) fun unstake<T0>(arg0: &mut SpoolAccount<T0>, arg1: u64) : sui::balance::Balance<T0> {
        sui::balance::split<T0>(&mut arg0.stakes, arg1)
    }

    #[test_only]
    public fun test_new<T0>(arg0: &spool::spool::Spool, arg1: &mut sui::tx_context::TxContext) : SpoolAccount<T0> {
        SpoolAccount<T0>{
            id           : sui::object::new(arg1),
            spool_id     : sui::object::id<spool::spool::Spool>(arg0),
            stake_type   : std::type_name::get<T0>(),
            stakes       : sui::balance::zero<T0>(),
            points       : 0,
            total_points : 0,
            index        : spool::spool::index(arg0),
        }
    }

    // decompiled from Move bytecode v6
}

