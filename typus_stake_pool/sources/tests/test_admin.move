
#[test_only]
module typus_stake_pool::test_admin {
    use sui::test_scenario::{Scenario, begin, end, ctx, next_tx, take_shared, return_shared};
    use typus_stake_pool::admin::{Self, Version};

    const ADMIN: address = @0xFFFF;

    fun new_version(scenario: &mut Scenario) {
        admin::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun version(scenario: &Scenario): Version {
        take_shared<Version>(scenario)
    }

    fun begin_test(): Scenario {
        let mut scenario = begin(ADMIN);
        new_version(&mut scenario);
        next_tx(&mut scenario, ADMIN);
        next_tx(&mut scenario, ADMIN);
        scenario
    }

    fun test_upgrade_(scenario: &mut Scenario) {
        let mut version = version(scenario);
        admin::upgrade(&mut version);
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_add_authorized_user_(scenario: &mut Scenario, user_address: address) {
        let mut version = version(scenario);
        admin::add_authorized_user(&mut version, user_address, ctx(scenario));
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_remove_authorized_user_(scenario: &mut Scenario, user_address: address) {
        let mut version = version(scenario);
        admin::remove_authorized_user(&mut version, user_address, ctx(scenario));
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    #[test]
    public(package) fun test_admin() {
        let mut scenario = begin_test();
        test_add_authorized_user_(&mut scenario, @0xEEEE);
        test_remove_authorized_user_(&mut scenario, @0xEEEE);

        test_upgrade_(&mut scenario);
        end(scenario);
    }
}
