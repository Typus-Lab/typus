#[test_only]
extend module typus::airdrop {

    use sui::test_scenario;
    use typus::ecosystem;
    use sui::coin;

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test]
    fun test_airdrop() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let mut typus_airdrop_registry = test_scenario::take_shared<TypusAirdropRegistry>(&scenario);
        set_airdrop<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            vector[coin::mint_for_testing(60, test_scenario::ctx(&mut scenario))],
            vector[@0xAAAA, @0xBBBB, @0xCCCC],
            vector[10, 20, 30],
            test_scenario::ctx(&mut scenario),
        );
        claim_airdrop<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            test_scenario::ctx(&mut scenario),
        ).destroy_none();
        claim_airdrop_by_index<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            0,
            test_scenario::ctx(&mut scenario),
        ).destroy_none();
        get_airdrop<sui::sui::SUI>(
            &version,
            &typus_airdrop_registry,
            b"test".to_ascii_string(),
            scenario.sender(),
        );
        set_airdrop<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            vector[coin::mint_for_testing(40, test_scenario::ctx(&mut scenario))],
            vector[@0xABCD],
            vector[40],
            test_scenario::ctx(&mut scenario),
        );
        claim_airdrop_by_index<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            3,
            test_scenario::ctx(&mut scenario),
        ).destroy_some().destroy_for_testing();
        set_airdrop<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            vector[coin::mint_for_testing(150, test_scenario::ctx(&mut scenario))],
            vector[@0xAAAA, @0xBBBB, @0xCCCC, @0xABCD],
            vector[10, 20, 30, 40],
            test_scenario::ctx(&mut scenario),
        );
        get_airdrop<sui::sui::SUI>(
            &version,
            &typus_airdrop_registry,
            b"test".to_ascii_string(),
            scenario.sender(),
        );
        claim_airdrop<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            test_scenario::ctx(&mut scenario),
        ).destroy_some().destroy_for_testing();
        remove_airdrop<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            test_scenario::ctx(&mut scenario),
        ).destroy_for_testing();

        test_scenario::return_shared(version);
        test_scenario::return_shared(typus_airdrop_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidInput)]
    fun test_set_airdrop_invalid_input_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let mut typus_airdrop_registry = test_scenario::take_shared<TypusAirdropRegistry>(&scenario);
        set_airdrop<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            vector[coin::mint_for_testing(60, test_scenario::ctx(&mut scenario))],
            vector[@0xAAAA, @0xBBBB, @0xCCCC],
            vector[10, 20],
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(version);
        test_scenario::return_shared(typus_airdrop_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInsufficientBalance)]
    fun test_set_airdrop_insufficient_balance_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let mut typus_airdrop_registry = test_scenario::take_shared<TypusAirdropRegistry>(&scenario);
        set_airdrop<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            vector[coin::mint_for_testing(10, test_scenario::ctx(&mut scenario))],
            vector[@0xAAAA, @0xBBBB, @0xCCCC],
            vector[10, 20, 30],
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(version);
        test_scenario::return_shared(typus_airdrop_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidInput)]
    fun test_claim_airdrop_invalid_input_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let mut typus_airdrop_registry = test_scenario::take_shared<TypusAirdropRegistry>(&scenario);
        claim_airdrop<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            test_scenario::ctx(&mut scenario),
        ).destroy_none();

        test_scenario::return_shared(version);
        test_scenario::return_shared(typus_airdrop_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidInput)]
    fun test_claim_airdrop_by_index_invalid_input_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let mut typus_airdrop_registry = test_scenario::take_shared<TypusAirdropRegistry>(&scenario);
        claim_airdrop_by_index<sui::sui::SUI>(
            &version,
            &mut typus_airdrop_registry,
            b"test".to_ascii_string(),
            0,
            test_scenario::ctx(&mut scenario),
        ).destroy_none();

        test_scenario::return_shared(version);
        test_scenario::return_shared(typus_airdrop_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidInput)]
    fun test_get_airdrop_invalid_input_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let typus_airdrop_registry = test_scenario::take_shared<TypusAirdropRegistry>(&scenario);
        get_airdrop<sui::sui::SUI>(
            &version,
            &typus_airdrop_registry,
            b"test".to_ascii_string(),
            scenario.sender(),
        );

        test_scenario::return_shared(version);
        test_scenario::return_shared(typus_airdrop_registry);
        test_scenario::end(scenario);
    }
}