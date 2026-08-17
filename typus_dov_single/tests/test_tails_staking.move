#[test_only]
extend module typus_dov::tails_staking {
    use sui::clock;
    use sui::coin;
    use sui::kiosk;
    use sui::object_table;
    use sui::test_scenario;
    use sui::transfer_policy;

    use typus_nft::typus_nft;
    use typus_dov::test_environment;

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_remove_nft_extension_abort() {
        let mut scenario = test_environment::begin_test();
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let (ot, nmc, tp, c) = remove_nft_extension(&mut registry, scenario.ctx());
        ot.destroy_empty();
        transfer::public_transfer(nmc, scenario.sender());
        transfer::public_transfer(tp, scenario.sender());
        transfer::public_transfer(c, scenario.sender());
        test_scenario::return_shared(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_remove_nft_table_tails_abort() {
        let mut scenario = test_environment::begin_test();
        scenario.next_tx(@0xABCD);
        let registry = scenario.take_shared<Registry>();
        let mut ot = object_table::new(scenario.ctx());
        let v = remove_nft_table_tails(&registry, &mut ot, vector[], scenario.ctx());
        ot.destroy_empty();
        v.destroy_empty();
        test_scenario::return_shared(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_bid_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let (r, _) = new_bid<SUI, SUI>(
            &mut registry,
            0,
            vector[],
            0,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(r, scenario.sender());
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_bid_v2_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let (r, c, _) = new_bid_v2<SUI, SUI>(
            &mut registry,
            0,
            vector[],
            0,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(r, scenario.sender());
        transfer::public_transfer(c, scenario.sender());
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_bid_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let typus_ecosystem_version = scenario.take_shared<TypusEcosystemVersion>();
        let mut typus_user_registry = scenario.take_shared<TypusUserRegistry>();
        let mut tgld_registry = scenario.take_shared<TgldRegistry>();
        let mut typus_leaderboard_registry = scenario.take_shared<TypusLeaderboardRegistry>();
        let (r, c, _) = bid<SUI, SUI>(
            &typus_ecosystem_version,
            &mut typus_user_registry,
            &mut tgld_registry,
            &mut typus_leaderboard_registry,
            &mut registry,
            0,
            vector[],
            0,
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(r, scenario.sender());
        transfer::public_transfer(c, scenario.sender());
        test_scenario::return_shared(registry);
        test_scenario::return_shared(typus_ecosystem_version);
        test_scenario::return_shared(typus_user_registry);
        test_scenario::return_shared(tgld_registry);
        test_scenario::return_shared(typus_leaderboard_registry);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_deposit_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let (v, r, _) = deposit<SUI, SUI>(
            &mut registry,
            0,
            vector[],
            0,
            vector[],
            &clock,
            scenario.ctx(),
        );
        v.destroy_empty();
        transfer::public_transfer(r, scenario.sender());
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let (b, o, _) = withdraw<SUI, SUI>(
            &mut registry,
            0,
            vector[],
            option::none(),
            &clock,
            scenario.ctx(),
        );
        b.destroy_zero();
        o.destroy_none();
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_unsubscribe_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let (r, _) = unsubscribe<SUI, SUI>(
            &mut registry,
            0,
            vector[],
            option::none(),
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(r, scenario.sender());
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_compound_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let (r, _) = compound<SUI, SUI>(
            &mut registry,
            0,
            vector[],
            &clock,
            scenario.ctx(),
        );
        transfer::public_transfer(r, scenario.sender());
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_reduce_usd_in_deposit_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        reduce_usd_in_deposit(
            &mut registry,
            scenario.sender(),
            0,
            &clock,
            scenario.ctx(),
        );
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_partner_add_exp_abort() {
        let mut scenario = test_environment::begin_test();
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let id = object::new(scenario.ctx());
        let `for` = id.uid_to_inner();
        let partner_key = PartnerKey {
            id,
            `for`,
            partner: b"".to_string(),
        };
        partner_add_exp(
            &mut registry,
            &partner_key,
            scenario.sender(),
            0,
        );
        let PartnerKey {
            id,
            `for`: _,
            partner: _,
        } = partner_key;
        id.delete();
        test_scenario::return_shared(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_nft_exp_up_abort() {
        let mut scenario = test_environment::begin_test();
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let typus_ecosystem_version = scenario.take_shared<TypusEcosystemVersion>();
        let mut typus_user_registry = scenario.take_shared<TypusUserRegistry>();
        nft_exp_up(
            &typus_ecosystem_version,
            &mut typus_user_registry,
            &mut registry,
            0,
            scenario.ctx(),
        );
        test_scenario::return_shared(registry);
        test_scenario::return_shared(typus_ecosystem_version);
        test_scenario::return_shared(typus_user_registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_stake_nft_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let id = object::new(scenario.ctx());
        stake_nft(
            &mut registry,
            &mut kiosk,
            &kiosk_owner_cap,
            id.uid_to_inner(),
            &clock,
            coin::zero(scenario.ctx()),
            scenario.ctx(),
        );
        id.delete();
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_switch_nft_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let id = object::new(scenario.ctx());
        switch_nft(
            &mut registry,
            &mut kiosk,
            &kiosk_owner_cap,
            id.uid_to_inner(),
            &clock,
            coin::zero(scenario.ctx()),
            scenario.ctx(),
        );
        id.delete();
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        test_scenario::return_shared(registry);
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_unstake_nft_abort() {
        let mut scenario = test_environment::begin_test();
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        unstake_nft(
            &mut registry,
            &mut kiosk,
            &kiosk_owner_cap,
            scenario.ctx(),
        );
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        test_scenario::return_shared(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_transfer_nft_abort() {
        let mut scenario = test_environment::begin_test();
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let id = object::new(scenario.ctx());
        transfer_nft(
            &mut registry,
            &mut kiosk,
            &kiosk_owner_cap,
            id.uid_to_inner(),
            scenario.sender(),
            coin::zero(scenario.ctx()),
            scenario.ctx(),
        );
        id.delete();
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        test_scenario::return_shared(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_migrate_nft_extension_abort() {
        let mut scenario = test_environment::begin_test();
        let (transfer_policy, transfer_policy_cap) = transfer_policy::new_for_testing<Tails>(scenario.ctx());
        scenario.next_tx(@0xABCD);
        typus_nft::test_init(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let nft_manager_cap = scenario.take_from_sender<NftManagerCap>();
        migrate_nft_extension(
            &mut registry,
            object_table::new(scenario.ctx()),
            nft_manager_cap,
            transfer_policy,
            coin::zero(scenario.ctx()),
            scenario.ctx(),
        );
        transfer::public_transfer(transfer_policy_cap, scenario.sender());
        test_scenario::return_shared(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_migrate_typus_ecosystem_tails_abort() {
        let mut scenario = test_environment::begin_test();
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let v = migrate_typus_ecosystem_tails(
            &mut registry,
            vector[],
            scenario.ctx(),
        );
        v.destroy_empty();
        test_scenario::return_shared(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_consume_exp_coin_unstaked_abort() {
        let mut scenario = test_environment::begin_test();
        let (mut kiosk, kiosk_owner_cap) = kiosk::new(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let id = object::new(scenario.ctx());
        consume_exp_coin_unstaked<SUI>(
            &mut registry,
            &mut kiosk,
            &kiosk_owner_cap,
            id.uid_to_inner(),
            coin::zero(scenario.ctx()),
            scenario.ctx(),
        );
        id.delete();
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, scenario.sender());
        test_scenario::return_shared(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_consume_exp_coin_staked_abort() {
        let mut scenario = test_environment::begin_test();
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        consume_exp_coin_staked<SUI>(
            &mut registry,
            coin::zero(scenario.ctx()),
            scenario.ctx(),
        );
        test_scenario::return_shared(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_has_staked_abort() {
        let mut scenario = test_environment::begin_test();
        scenario.next_tx(@0xABCD);
        let registry = scenario.take_shared<Registry>();
        has_staked(
            &registry,
            scenario.sender(),
        );
        test_scenario::return_shared(registry);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_snapshot_abort() {
        let mut scenario = test_environment::begin_test();
        let clock = clock::create_for_testing(scenario.ctx());
        scenario.next_tx(@0xABCD);
        let mut registry = scenario.take_shared<Registry>();
        let typus_ecosystem_version = scenario.take_shared<TypusEcosystemVersion>();
        let mut typus_user_registry = scenario.take_shared<TypusUserRegistry>();
        snapshot(
            &typus_ecosystem_version,
            &mut typus_user_registry,
            &mut registry,
            0,
            scenario.ctx(),
        );
        test_scenario::return_shared(registry);
        test_scenario::return_shared(typus_ecosystem_version);
        test_scenario::return_shared(typus_user_registry);
        clock.destroy_for_testing();
        scenario.end();
    }
}