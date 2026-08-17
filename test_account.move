#[test_only]
extend module typus::account {

    use sui::test_scenario::{Self, Scenario};
    use typus::ecosystem;

    #[test_only]
    fun new_scenario(): Scenario {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        init_account_registry(&mut version, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::next_tx(&mut scenario, @0xABCD);

        scenario
    }

    #[test]
    fun test_create_account() {
        let mut scenario = new_scenario();
        let mut version = test_scenario::take_shared<Version>(&scenario);
        create_account(&mut version, test_scenario::ctx(&mut scenario));
        create_account(&mut version, test_scenario::ctx(&mut scenario));
        get_user_account_address(&version, test_scenario::ctx(&mut scenario));
        borrow_user_account(&mut version, test_scenario::ctx(&mut scenario));

        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_new_account() {
        let mut scenario = new_scenario();
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let account_cap = new_account(&mut version, test_scenario::ctx(&mut scenario));
        get_user_account_address_with_account_cap(&version, &account_cap);
        borrow_user_account_with_account_cap(&mut version, &account_cap);
        transfer::public_transfer(account_cap, test_scenario::sender(&scenario));

        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_transfer_account() {
        let mut scenario = new_scenario();
        let mut version = test_scenario::take_shared<Version>(&scenario);
        create_account(&mut version, test_scenario::ctx(&mut scenario));
        transfer_account(&mut version, @0xFFFF, test_scenario::ctx(&mut scenario));

        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }
}