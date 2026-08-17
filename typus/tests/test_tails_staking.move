#[test_only]
extend module typus::tails_staking {
    use sui::test_scenario;
    use sui::clock;
    use typus::ecosystem;

    #[test]
    fun test_tails_staking() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let mut typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        upload_ipfs_urls(&version, &mut tails_staking_registry, 1, vector[vector[1], vector[2]], scenario.ctx());
        remove_ipfs_urls(&version, &mut tails_staking_registry, 1, scenario.ctx());
        let mut urls = vector[];
        15u64.do!(|_| {
            urls.push_back(b"https://docs.typus.finance/");
        });
        upload_ipfs_urls(&version, &mut tails_staking_registry, 1, urls, scenario.ctx());
        upload_ipfs_urls(&version, &mut tails_staking_registry, 2, urls, scenario.ctx());
        upload_ipfs_urls(&version, &mut tails_staking_registry, 3, urls, scenario.ctx());
        upload_ipfs_urls(&version, &mut tails_staking_registry, 4, urls, scenario.ctx());
        upload_ipfs_urls(&version, &mut tails_staking_registry, 5, urls, scenario.ctx());
        upload_ipfs_urls(&version, &mut tails_staking_registry, 6, urls, scenario.ctx());
        upload_ipfs_urls(&version, &mut tails_staking_registry, 7, urls, scenario.ctx());
        upload_webp_bytes(&version, &mut tails_staking_registry, 1, 1, vector[1], scenario.ctx());
        upload_webp_bytes(&version, &mut tails_staking_registry, 1, 1, vector[1], scenario.ctx());
        remove_webp_bytes(&version, &mut tails_staking_registry, 1, 1, scenario.ctx());
        upload_webp_bytes(&version, &mut tails_staking_registry, 10, 1, vector[1], scenario.ctx());
        upload_webp_bytes(&version, &mut tails_staking_registry, 10, 2, vector[1], scenario.ctx());
        upload_webp_bytes(&version, &mut tails_staking_registry, 10, 3, vector[1], scenario.ctx());
        update_tails_staking_registry_config(&version, &mut tails_staking_registry, 0, 5, scenario.ctx());
        update_tails_staking_registry_config(&version, &mut tails_staking_registry, 10, 0, scenario.ctx());
        get_max_staking_level(&version, &tails_staking_registry, scenario.sender());
        let mut tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tailses[0], string::utf8(b"updating_url"), 0);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tailses[0], string::utf8(b"attendance_ms"), 0);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tailses[0], string::utf8(b"snapshot_ms"), 0);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tailses[0], string::utf8(b"usd_in_deposit"), 0);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tailses[0], string::utf8(b"dice_profit"), 0);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tailses[0], string::utf8(b"exp_profit"), 0);
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[1,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 3, 1, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[2,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 18, 1, scenario.ctx());
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        let mut nft = typus_nft::test_mint(9, scenario.ctx());
        let tails = object::id_address(&nft);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut nft, string::utf8(b"updating_url"), 0);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut nft, string::utf8(b"attendance_ms"), 0);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut nft, string::utf8(b"snapshot_ms"), 0);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut nft, string::utf8(b"usd_in_deposit"), 0);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut nft, string::utf8(b"dice_profit"), 0);
        typus_nft::insert_u64_padding(&tails_staking_registry.tails_manager_cap, &mut nft, string::utf8(b"exp_profit"), 0);
        let nft2 = typus_nft::test_mint(10, scenario.ctx());
        let tails2 = object::id_address(&nft2);
        verify_staking(&version, &tails_staking_registry, scenario.sender(), tails);
        verify_staking_identity(&version, &tails_staking_registry, scenario.sender(), 1);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft2);
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails2, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());
        verify_staking(&version, &tails_staking_registry, scenario.sender(), @0xAAAA);
        verify_staking(&version, &tails_staking_registry, scenario.sender(), tails);
        verify_staking(&version, &tails_staking_registry, scenario.sender(), tails2);
        verify_staking_identity(&version, &tails_staking_registry, scenario.sender(), 0);
        verify_staking_identity(&version, &tails_staking_registry, scenario.sender(), 1);
        get_staking_info(&version, &tails_staking_registry, scenario.sender());
        get_staking_info(&version, &tails_staking_registry, @0xABAB);
        get_staking_infos(&version, &tails_staking_registry, scenario.sender());
        get_level_counts(&version, &tails_staking_registry);
        clock.set_for_testing(86400000*2);
        daily_sign_up(&mut version, &mut tails_staking_registry, coin::mint_for_testing(0_050000000, scenario.ctx()), &clock, scenario.ctx());
        exp_up(&version, &mut tails_staking_registry, &mut typus_user_registry, tails, 0, scenario.ctx());
        public_exp_up(&manager_cap, &version, &mut tails_staking_registry, tails2, 10000);
        level_up(&version, &mut tails_staking_registry, tails2, true);
        verify_staking_identity(&version, &tails_staking_registry, scenario.sender(), 2);
        public_exp_up(&manager_cap, &version, &mut tails_staking_registry, tails, 10000);
        level_up(&version, &mut tails_staking_registry, tails, false);
        verify_staking_identity(&version, &tails_staking_registry, scenario.sender(), 5);
        get_max_staking_level(&version, &tails_staking_registry, scenario.sender());
        exp_down_with_fee(&mut version, &mut tails_staking_registry, &mut typus_user_registry, tails, 10, coin::mint_for_testing(10_000000000, scenario.ctx()), scenario.ctx());
        public_exp_down(&manager_cap, &version, &mut tails_staking_registry, tails, 10);
        exp_down_with_fee(&mut version, &mut tails_staking_registry, &mut typus_user_registry, tails, 9990, coin::mint_for_testing(10_000000000, scenario.ctx()), scenario.ctx());
        public_exp_down(&manager_cap, &version, &mut tails_staking_registry, tails2, 9990);
        public_exp_up(&manager_cap, &version, &mut tails_staking_registry, tails2, 10000);
        level_up(&version, &mut tails_staking_registry, tails2, true);
        public_exp_up(&manager_cap, &version, &mut tails_staking_registry, tails, 10000);
        level_up(&version, &mut tails_staking_registry, tails, false);
        claim_profit_sharing<sui::sui::SUI>(&mut version, &mut tails_staking_registry, scenario.ctx()).destroy_for_testing();
        unstake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails2, scenario.ctx());
        unstake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails, scenario.ctx());
        remove_profit_sharing<sui::sui::SUI>(&version, &mut tails_staking_registry, scenario.sender(), scenario.ctx());
        exp_up_without_staking(&version, &tails_staking_registry, &mut typus_user_registry, &mut kiosk, &kiosk_owner_cap, tails, 0, scenario.ctx());
        public_exp_up_without_staking(&manager_cap, &version, &tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails, 0);
        exp_down_without_staking_with_fee(&mut version, &tails_staking_registry, &mut typus_user_registry, &mut kiosk, &kiosk_owner_cap, tails, 10, coin::mint_for_testing(10_000000000, scenario.ctx()), scenario.ctx());
        public_exp_down_without_staking(&manager_cap, &version, &tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails2, 10);
        exp_down_without_staking_with_fee(&mut version, &tails_staking_registry, &mut typus_user_registry, &mut kiosk, &kiosk_owner_cap, tails, 9900, coin::mint_for_testing(10_000000000, scenario.ctx()), scenario.ctx());
        public_exp_down_without_staking(&manager_cap, &version, &tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails2, 9900);
        transfer_tails(&mut version, &tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails2, coin::mint_for_testing(0_010000000, scenario.ctx()), @0xAAAA, scenario.ctx());

        clock.destroy_for_testing();
        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure, allow(deprecated_usage)]
    fun test_exp_down_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let mut typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        exp_down(&version, &mut tails_staking_registry, &mut typus_user_registry, @0xABCD, 0, scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure, allow(deprecated_usage)]
    fun test_exp_down_without_staking_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let mut typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        exp_down_without_staking(&version, &tails_staking_registry, &mut typus_user_registry, &mut kiosk, &kiosk_owner_cap, @0xABCD, 0, scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        transfer::public_transfer(kiosk, scenario.sender());
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EStakingInfoNotFound)]
    fun test_unstake_tails_staking_info_not_found_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[1,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 3, 1, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[2,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 18, 1, scenario.ctx());
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        let nft = typus_nft::test_mint(9, scenario.ctx());
        let tails = object::id_address(&nft);
        let nft2 = typus_nft::test_mint(10, scenario.ctx());
        let tails2 = object::id_address(&nft2);
        verify_staking(&version, &tails_staking_registry, scenario.sender(), tails);
        verify_staking_identity(&version, &tails_staking_registry, scenario.sender(), 1);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft2);
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails2, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());
        unstake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, @0xABAB, scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EStakingInfoNotFound)]
    fun test_unstake_tails_staking_info_not_found_error2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[1,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 3, 1, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[2,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 18, 1, scenario.ctx());
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        unstake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, @0xABAB, scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EStakingInfoNotFound)]
    fun test_level_up_staking_info_not_found_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        level_up(&version, &mut tails_staking_registry, @0xABAB, false);

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInsufficientExp)]
    fun test_level_up_insufficient_exp_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        let tails = object::id_address(&tailses[0]);
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[1,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 3, 1, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[2,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 18, 1, scenario.ctx());
        level_up(&version, &mut tails_staking_registry, tails, false);

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EStakingInfoNotFound)]
    fun test_public_exp_up_staking_info_not_found_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        public_exp_up(&manager_cap, &version, &mut tails_staking_registry, @0xABAB, 10);

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EStakingInfoNotFound)]
    fun test_public_exp_down_staking_info_not_found_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        public_exp_down(&manager_cap, &version, &mut tails_staking_registry, @0xABAB, 10);

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidFee)]
    fun test_exp_down_without_staking_with_fee_invalid_feestaking_info_not_found_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let mut typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        exp_down_without_staking_with_fee(&mut version, &tails_staking_registry, &mut typus_user_registry, &mut kiosk, &kiosk_owner_cap, @0xABAB, 10, coin::mint_for_testing(1_000000000, scenario.ctx()), scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidFee)]
    fun test_exp_down_with_fee_invalid_fee_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let mut typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        exp_down_with_fee(&mut version, &mut tails_staking_registry, &mut typus_user_registry, @0xABAB, 10, coin::mint_for_testing(1_000000000, scenario.ctx()), scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EStakingInfoNotFound)]
    fun test_exp_down_with_fee_staking_info_not_found_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let mut typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        exp_down_with_fee(&mut version, &mut tails_staking_registry, &mut typus_user_registry, @0xABAB, 10, coin::mint_for_testing(10_000000000, scenario.ctx()), scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EStakingInfoNotFound)]
    fun test_exp_up_staking_info_not_found_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let mut typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        exp_up(&version, &mut tails_staking_registry, &mut typus_user_registry, @0xABAB, 10, scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EAlreadySignedUp)]
    fun test_daily_sign_up_already_signed_up_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[1,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 3, 1, scenario.ctx());
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        let nft = typus_nft::test_mint(9, scenario.ctx());
        let tails = object::id_address(&nft);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft);
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());
        daily_sign_up(&mut version, &mut tails_staking_registry, coin::mint_for_testing(0_050000000, scenario.ctx()), &clock, scenario.ctx());

        clock.destroy_for_testing();
        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EStakingInfoNotFound)]
    fun test_daily_sign_up_staking_info_not_found_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        daily_sign_up(&mut version, &mut tails_staking_registry, coin::mint_for_testing(0_050000000, scenario.ctx()), &clock, scenario.ctx());

        clock.destroy_for_testing();
        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidFee)]
    fun test_daily_sign_up_invalid_fee_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        daily_sign_up(&mut version, &mut tails_staking_registry, coin::mint_for_testing(0_010000000, scenario.ctx()), &clock, scenario.ctx());

        clock.destroy_for_testing();
        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidFee)]
    fun test_transfer_tails_invalid_fee_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        transfer_tails(&mut version, &tails_staking_registry, &mut kiosk, &kiosk_owner_cap, @0xABAB, coin::mint_for_testing(0_001000000, scenario.ctx()), @0xAAAA, scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidFee)]
    fun test_stake_tails_invalid_fee_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        let nft = typus_nft::test_mint(9, scenario.ctx());
        let tails = object::id_address(&nft);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft);
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails, coin::mint_for_testing(0_010000000, scenario.ctx()), scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EMaxStakeAmountReached)]
    fun test_stake_tails_max_stake_amount_reached_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(11, scenario.ctx()),
            typus_nft::test_mint(12, scenario.ctx()),
            typus_nft::test_mint(13, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[1,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 3, 1, scenario.ctx());
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        let nft1 = typus_nft::test_mint(1, scenario.ctx());
        let tails1 = object::id_address(&nft1);
        let nft2 = typus_nft::test_mint(2, scenario.ctx());
        let tails2 = object::id_address(&nft2);
        let nft3 = typus_nft::test_mint(3, scenario.ctx());
        let tails3 = object::id_address(&nft3);
        let nft4 = typus_nft::test_mint(4, scenario.ctx());
        let tails4 = object::id_address(&nft4);
        let nft5 = typus_nft::test_mint(5, scenario.ctx());
        let tails5 = object::id_address(&nft5);
        let nft6 = typus_nft::test_mint(6, scenario.ctx());
        let tails6 = object::id_address(&nft6);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft1);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft2);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft3);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft4);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft5);
        kiosk::lock(&mut kiosk, &kiosk_owner_cap, &tails_staking_registry.transfer_policy, nft6);
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails1, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails2, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails3, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails4, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails5, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());
        stake_tails(&mut version, &mut tails_staking_registry, &mut kiosk, &kiosk_owner_cap, tails6, coin::mint_for_testing(0_050000000, scenario.ctx()), scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInsufficientBalance)]
    fun test_set_profit_sharing_insufficient_balance_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[1,1,1,1,1,1,1], coin::mint_for_testing(1, scenario.ctx()), 3, 1, scenario.ctx());

        clock.destroy_for_testing();
        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidInput)]
    fun test_set_profit_sharing_invalid_input_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[1,1,1,1,1,1,1], coin::mint_for_testing(6, scenario.ctx()), 3, 1, scenario.ctx());

        clock.destroy_for_testing();
        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidToken)]
    fun test_remove_profit_sharing_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        remove_profit_sharing<sui::sui::SUI>(&version, &mut tails_staking_registry, scenario.sender(), scenario.ctx());

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidInput)]
    fun test_import_tails_invalid_input_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());

        clock.destroy_for_testing();
        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EInvalidToken)]
    fun test_claim_profit_sharing_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        claim_profit_sharing<sui::sui::SUI>(&mut version, &mut tails_staking_registry, scenario.ctx()).destroy_for_testing();

        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EStakingInfoNotFound)]
    fun test_claim_profit_sharing_staking_info_not_found_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        user::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        typus_nft::test_init(scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        let tails_manager_cap = scenario.take_from_sender();
        let publisher = scenario.take_from_sender();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new<Tails>(&publisher, scenario.ctx());
        init_tails_staking_registry(&version, tails_manager_cap, transfer_policy, scenario.ctx());
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut tails_staking_registry = test_scenario::take_shared<TailsStakingRegistry>(&scenario);
        let typus_user_registry = test_scenario::take_shared<TypusUserRegistry>(&scenario);
        let manager_cap = ecosystem::issue_manager_cap(&version, scenario.ctx());
        let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
        upload_ids(&version, &mut tails_staking_registry, scenario.ctx());
        upload_levels(&version, &mut tails_staking_registry, scenario.ctx());
        let tailses = vector[
            typus_nft::test_mint(1, scenario.ctx()),
            typus_nft::test_mint(2, scenario.ctx()),
            typus_nft::test_mint(3, scenario.ctx()),
        ];
        let users = vector[@0xAAAA, @0xBBBB, @0xCCCC];
        import_tails(&mut version, &mut tails_staking_registry, tailses, users, scenario.ctx());
        set_profit_sharing<sui::sui::SUI, sui::sui::SUI>(&version, &mut tails_staking_registry, vector[1,1,1,1,1,1,1], coin::mint_for_testing(3, scenario.ctx()), 3, 1, scenario.ctx());
        claim_profit_sharing<sui::sui::SUI>(&mut version, &mut tails_staking_registry, scenario.ctx()).destroy_for_testing();

        clock.destroy_for_testing();
        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        ecosystem::burn_manager_cap(&version, manager_cap, scenario.ctx());
        test_scenario::return_to_sender(&scenario, publisher);
        test_scenario::return_shared(version);
        test_scenario::return_shared(tails_staking_registry);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::end(scenario);
    }
}