#[test_only]
extend module typus::tgld {

    use sui::test_scenario;
    use typus::ecosystem;

    #[test]
    fun test_tgld() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let mut registry = test_scenario::take_shared<TgldRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, test_scenario::ctx(&mut scenario));
        mint(&manager_cap, &version, &mut registry, @0xABCD, 10, test_scenario::ctx(&mut scenario));
        burn(&manager_cap, &version, &mut registry, token::zero(test_scenario::ctx(&mut scenario)));

        ecosystem::burn_manager_cap(&version, manager_cap, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::return_shared(registry);
        test_scenario::end(scenario);
    }
}