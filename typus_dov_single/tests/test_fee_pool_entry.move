
#[test_only]
module typus_dov::test_fee_pool_entry {
    use sui::test_scenario::{Scenario, ctx, next_tx, return_shared};
    use typus_dov::test_environment;
    use typus_dov::tds_fee_pool_entry;

    const ADMIN: address = @0xFFFF;

    public(package) fun test_add_fee_pool_authorized_user_(
        scenario: &mut Scenario,
        users: vector<address>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_fee_pool_entry::add_fee_pool_authorized_user(&mut registry, users, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_remove_fee_pool_authorized_user_(
        scenario: &mut Scenario,
        users: vector<address>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_fee_pool_entry::remove_fee_pool_authorized_user(&mut registry, users, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_take_fee_<TOKEN>(
        scenario: &mut Scenario,
        amount: Option<u64>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_fee_pool_entry::take_fee<TOKEN>(&mut registry, amount, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_send_fee_<TOKEN>(
        scenario: &mut Scenario,
        amount: Option<u64>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_fee_pool_entry::send_fee<TOKEN>(&mut registry, amount, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    // public(package) fun test_add_shared_fee_pool_authorized_user_(
    //     scenario: &mut Scenario,
    //     key: vector<u8>,
    //     users: vector<address>,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     tds_fee_pool_entry::add_shared_fee_pool_authorized_user(&mut registry, key, users, ctx(scenario));
    //     return_shared(registry);
    //     next_tx(scenario, ADMIN);
    // }

    // public(package) fun test_remove_shared_fee_pool_authorized_user_(
    //     scenario: &mut Scenario,
    //     key: vector<u8>,
    //     users: vector<address>,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     tds_fee_pool_entry::remove_shared_fee_pool_authorized_user(&mut registry, key, users, ctx(scenario));
    //     return_shared(registry);
    //     next_tx(scenario, ADMIN);
    // }

    // public(package) fun test_take_shared_fee_<TOKEN>(
    //     scenario: &mut Scenario,
    //     key: vector<u8>,
    //     amount: Option<u64>,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     tds_fee_pool_entry::take_shared_fee<TOKEN>(&mut registry, key, amount, ctx(scenario));
    //     return_shared(registry);
    //     next_tx(scenario, ADMIN);
    // }
}