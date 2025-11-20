
#[test_only]
module typus_dov::test_otc_entry {
    use sui::test_scenario::{Scenario, ctx, next_tx, return_shared};
    use typus_dov::tds_otc_entry;
    use typus_dov::test_environment;

    const ADMIN: address = @0xFFFF;

    public(package) fun test_add_otc_config_(
        scenario: &mut Scenario,
        user: address,
        index: u64,
        round: u64,
        size: u64,
        price: u64,
        fee_bp: u64,
        expiration_ts_ms: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_otc_entry::add_otc_config(
            &mut registry,
            user,
            index,
            round,
            size,
            price,
            fee_bp,
            expiration_ts_ms,
            ctx(scenario),
        );
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_remove_otc_config_(
        scenario: &mut Scenario,
        user: address,
        index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_otc_entry::remove_otc_config(&mut registry, user, index, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_otc_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        amount: u64,
        ts_ms: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        let coin = test_environment::mint_test_coin<B_TOKEN>(scenario, amount);
        tds_otc_entry::otc<D_TOKEN, B_TOKEN>(&mut registry, index, coin.into_balance(), &clock, ctx(scenario));
        return_shared(registry);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

}