#[test_only]
extend module typus::user {

    use sui::test_scenario;
    use typus::ecosystem;

    #[test]
    fun test_user() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        tgld::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let mut tgld_registry = test_scenario::take_shared<TgldRegistry>(&scenario);
        let mut typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, test_scenario::ctx(&mut scenario));
        add_accumulated_tgld_amount(&manager_cap, &version, &mut typus_user_registry, &mut tgld_registry, @0xAAAA, 0, test_scenario::ctx(&mut scenario));
        add_accumulated_tgld_amount(&manager_cap, &version, &mut typus_user_registry, &mut tgld_registry, @0xAAAA, 10, test_scenario::ctx(&mut scenario));
        add_tails_exp_amount(&manager_cap, &version, &mut typus_user_registry, @0xBBBB, 0);
        add_tails_exp_amount(&manager_cap, &version, &mut typus_user_registry, @0xBBBB, 10);
        remove_tails_exp_amount(&manager_cap, &version, &mut typus_user_registry, @0xBBBB, 0);
        remove_tails_exp_amount(&manager_cap, &version, &mut typus_user_registry, @0xBBBB, 10);
        remove_tails_exp_amount(&manager_cap, &version, &mut typus_user_registry, @0xCCCC, 10);
        get_user_metadata(&version, &typus_user_registry, @0xAAAA);
        get_user_metadata(&version, &typus_user_registry, @0xFFFF);

        ecosystem::burn_manager_cap(&version, manager_cap, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::return_shared(tgld_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }
}