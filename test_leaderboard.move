#[test_only]
extend module typus::leaderboard {
    use sui::test_scenario;
    use typus::ecosystem;
    use sui::clock;

    #[test]
    fun test_leaderboard() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let mut registry = test_scenario::take_shared<TypusLeaderboardRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, test_scenario::ctx(&mut scenario));
        let key = b"test".to_ascii_string();
        let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        activate_leaderboard(&version, &mut registry, key, 10, 20, test_scenario::ctx(&mut scenario));
        activate_leaderboard(&version, &mut registry, key, 10, 50, test_scenario::ctx(&mut scenario));
        let id = *dynamic_field::borrow<String, LinkedObjectTable<address, Leaderboard>>(&registry.active_leaderboard_registry, key).front().borrow();
        let id2 = *dynamic_field::borrow<String, LinkedObjectTable<address, Leaderboard>>(&registry.active_leaderboard_registry, key).back().borrow();
        get_rankings(&version, &registry, key, id, 10, scenario.sender(), true);
        extend_leaderboard(&version, &mut registry, key, id, 25, test_scenario::ctx(&mut scenario));
        trim_leaderboard(&version, &mut registry, key, id, true, 0, 10, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, scenario.sender(), 10, &clock, test_scenario::ctx(&mut scenario));
        deduct(&manager_cap, &version, &mut registry, key, scenario.sender(), 2, &clock, test_scenario::ctx(&mut scenario));
        clock.set_for_testing(11);
        delegate_score(&version, &mut registry, key, scenario.sender(), 10, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, b"lalala".to_ascii_string(), scenario.sender(), 10, &clock, test_scenario::ctx(&mut scenario));
        delegate_deduct(&version, &mut registry, b"lalala".to_ascii_string(), scenario.sender(), 2, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, scenario.sender(), 10, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, scenario.sender(), 0, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, @0xAAAA, 20, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, @0xBBBB, 10, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, @0xBBBB, 5, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, @0xBBBB, 5, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, @0xBBBB, 5, &clock, test_scenario::ctx(&mut scenario));
        deduct(&manager_cap, &version, &mut registry, key, @0xBBBB, 5, &clock, test_scenario::ctx(&mut scenario));
        deduct(&manager_cap, &version, &mut registry, key, @0xBBBB, 5, &clock, test_scenario::ctx(&mut scenario));
        delegate_deduct(&version, &mut registry, key, scenario.sender(), 0, &clock, test_scenario::ctx(&mut scenario));
        delegate_deduct(&version, &mut registry, key, scenario.sender(), 2, &clock, test_scenario::ctx(&mut scenario));
        trim_leaderboard(&version, &mut registry, key, id, true, 0, 10, test_scenario::ctx(&mut scenario));
        get_rankings(&version, &registry, key, id, 10, scenario.sender(), true);
        clock.set_for_testing(28);
        score(&manager_cap, &version, &mut registry, key, @0xCCCC, 20, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, @0xDDDD, 35, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, @0xDDDD, 5, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, @0xEEEE, 5, &clock, test_scenario::ctx(&mut scenario));
        score(&manager_cap, &version, &mut registry, key, @0xFFFF, 15, &clock, test_scenario::ctx(&mut scenario));
        deduct(&manager_cap, &version, &mut registry, key, @0xFFFF, 15, &clock, test_scenario::ctx(&mut scenario));
        deduct(&manager_cap, &version, &mut registry, key, scenario.sender(), 2, &clock, test_scenario::ctx(&mut scenario));
        deduct(&manager_cap, &version, &mut registry, key, scenario.sender(), 6, &clock, test_scenario::ctx(&mut scenario));
        clock.set_for_testing(51);
        score(&manager_cap, &version, &mut registry, key, scenario.sender(), 10, &clock, test_scenario::ctx(&mut scenario));
        deduct(&manager_cap, &version, &mut registry, key, scenario.sender(), 2, &clock, test_scenario::ctx(&mut scenario));
        deactivate_leaderboard(&version, &mut registry, key, id, test_scenario::ctx(&mut scenario));
        deactivate_leaderboard(&version, &mut registry, key, id2, test_scenario::ctx(&mut scenario));
        trim_leaderboard(&version, &mut registry, key, id, false, 0, 10, test_scenario::ctx(&mut scenario));
        get_rankings(&version, &registry, key, id, 10, scenario.sender(), false);
        get_rankings(&version, &registry, key, id, 10, @0xDBCA, false);
        remove_leaderboard(&version, &mut registry, key, id, test_scenario::ctx(&mut scenario));

        clock.destroy_for_testing();
        ecosystem::burn_manager_cap(&version, manager_cap, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::return_shared(registry);
        test_scenario::end(scenario);
    }
}