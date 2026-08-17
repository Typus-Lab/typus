
#[test_only]
module typus_perp::test_admin {
    use sui::test_scenario::{Scenario, begin, end, ctx, next_tx, take_shared, return_shared};
    use typus_perp::admin::{Self, Version};

    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use typus_perp::babe::BABE;

    const ADMIN: address = @0xFFFF;

    fun mint_test_coin<T>(scenario: &mut Scenario, amount: u64): Coin<T> {
        coin::mint_for_testing<T>(amount, ctx(scenario))
    }

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

    fun test_charge_fee_<T>(scenario: &mut Scenario, amount: u64) {
        let coin = mint_test_coin<T>(scenario, amount);
        let mut version = version(scenario);
        admin::charge_fee<T>(&mut version, coin.into_balance());
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_send_fee_<T>(scenario: &mut Scenario) {
        let mut version = version(scenario);
        admin::send_fee<T>(&mut version, ctx(scenario));
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_upgrade_(scenario: &mut Scenario) {
        let mut version = version(scenario);
        admin::upgrade(&mut version);
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_charge_liquidator_fee_<T>(scenario: &mut Scenario, amount: u64) {
        let coin = mint_test_coin<T>(scenario, amount);
        let mut version = version(scenario);
        admin::charge_liquidator_fee<T>(&mut version, coin.into_balance());
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_send_liquidator_fee_<T>(scenario: &mut Scenario) {
        let mut version = version(scenario);
        admin::send_liquidator_fee<T>(&mut version, ctx(scenario));
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    #[test]
    public(package) fun test_admin() {
        let mut scenario = begin_test();
        test_send_fee_<SUI>(&mut scenario); // nothing happened
        test_send_liquidator_fee_<SUI>(&mut scenario); // nothing happened
        test_charge_fee_<SUI>(&mut scenario, 100_0000_00000);
        test_charge_fee_<BABE>(&mut scenario, 100_0000_00000);
        test_send_fee_<SUI>(&mut scenario);
        test_send_fee_<SUI>(&mut scenario); // nothing happened
        test_send_fee_<BABE>(&mut scenario);
        test_charge_liquidator_fee_<SUI>(&mut scenario, 100_0000_00000);
        test_charge_liquidator_fee_<BABE>(&mut scenario, 100_0000_00000);
        test_send_liquidator_fee_<SUI>(&mut scenario);
        test_send_liquidator_fee_<BABE>(&mut scenario);

        test_upgrade_(&mut scenario);
        end(scenario);
    }
}