#[test_only]
extend module typus_framework::vault {
    use sui::sui::SUI;

    #[test_only]
    public struct TEST has drop {}

    #[test]
    fun test_vault() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        big_vector::destroy_empty<DepositShare>(dynamic_field::remove(&mut deposit_vault.id, K_DEPOSIT_SHARES));
        dynamic_field::add(&mut deposit_vault.id, K_DEPOSIT_SHARES, big_vector::new<DepositShare>(1, scenario.ctx()));
        deposit_vault.update_deposit_vault_incentive_token<SUI>();
        deposit_vault.activate<SUI>(true, scenario.ctx());
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        deposit_vault.delivery<SUI, SUI>(&mut bid_vault, balance::zero());
        deposit_vault.delivery_d<SUI, SUI>(&mut bid_vault, balance::zero(), balance::zero(), scenario.ctx());
        deposit_vault.delivery_b<SUI, SUI>(&mut bid_vault, balance::zero(), balance::zero(), scenario.ctx());
        deposit_vault.delivery_i<SUI, SUI, SUI>(&mut bid_vault, balance::zero(), balance::zero(), scenario.ctx());
        deposit_vault.recoup<SUI>(0, scenario.ctx());
        deposit_vault.settle<SUI, SUI>(&mut bid_vault, 100000000, 8, scenario.ctx());
        let (receipt, _) = raise_fund<SUI>(&mut fee_pool, &mut deposit_vault, vector[], balance::create_for_testing(100000000000), false, false, scenario.ctx());
        receipt.get_deposit_receipt_index();
        receipt.get_deposit_receipt_vid();
        let (receipt_opt, balance_d, balance_b, balance_i, _) = reduce_fund<SUI, SUI, SUI>(&mut fee_pool, &mut deposit_vault, vector[receipt], 50000000000, 0, false, false, false, scenario.ctx());
        balance_d.destroy_for_testing();
        balance_b.destroy_for_testing();
        balance_i.destroy_for_testing();
        let (receipt, _) = raise_fund<SUI>(&mut fee_pool, &mut deposit_vault, vector[receipt_opt.destroy_some()], balance::create_for_testing(100000000000), false, false, scenario.ctx());
        deposit_vault.activate<SUI>(true, scenario.ctx());
        let (receipt_opt, balance_d, balance_b, balance_i, _) = reduce_fund<SUI, SUI, SUI>(&mut fee_pool, &mut deposit_vault, vector[receipt], 0, 50000000000, false, false, false, scenario.ctx());
        balance_d.destroy_for_testing();
        balance_b.destroy_for_testing();
        balance_i.destroy_for_testing();
        deposit_vault.get_deposit_share(0);
        let deposit_share = deposit_vault.get_mut_deposit_share(0);
        deposit_share.get_deposit_share_inner(active_share_tag());
        deposit_share.get_deposit_share_inner(deactivating_share_tag());
        deposit_share.get_deposit_share_inner(inactive_share_tag());
        deposit_share.get_deposit_share_inner(warmup_share_tag());
        deposit_share.get_deposit_share_inner(premium_share_tag());
        deposit_share.get_deposit_share_inner(incentive_share_tag());
        deposit_share.get_mut_deposit_share_inner(active_share_tag());
        deposit_share.get_mut_deposit_share_inner(deactivating_share_tag());
        deposit_share.get_mut_deposit_share_inner(inactive_share_tag());
        deposit_share.get_mut_deposit_share_inner(warmup_share_tag());
        deposit_share.get_mut_deposit_share_inner(premium_share_tag());
        deposit_share.get_mut_deposit_share_inner(incentive_share_tag());
        deposit_vault.delivery<SUI, SUI>(&mut bid_vault, balance::create_for_testing(1000000000));
        deposit_vault.delivery_d<SUI, SUI>(&mut bid_vault, balance::create_for_testing(1000000000), balance::create_for_testing(1000000000), scenario.ctx());
        deposit_vault.delivery_b<SUI, SUI>(&mut bid_vault, balance::create_for_testing(1000000000), balance::create_for_testing(1000000000), scenario.ctx());
        deposit_vault.delivery_i<SUI, SUI, SUI>(&mut bid_vault, balance::create_for_testing(1000000000), balance::create_for_testing(1000000000), scenario.ctx());
        transfer::public_transfer(bid_vault.public_new_bid(10000000000, scenario.ctx()), scenario.sender());
        deposit_vault.recoup<SUI>(40000000000, scenario.ctx());
        deposit_vault.settle<SUI, SUI>(&mut bid_vault, 100000000, 8, scenario.ctx());
        let (receipt, _) = raise_fund<SUI>(&mut fee_pool, &mut deposit_vault, vector[receipt_opt.destroy_some()], balance::zero(), true, true, scenario.ctx());
        deposit_vault.activate<SUI>(true, scenario.ctx());
        let (balance, _) = deposit_vault.withdraw_for_lending<SUI>();
        reward_from_lending<SUI>(&mut fee_pool, &mut deposit_vault, balance::create_for_testing(1000000000), false);
        reward_from_lending<SUI>(&mut fee_pool, &mut deposit_vault, balance::create_for_testing(1000000000), true);
        let mut incentive_balance = balance::create_for_testing(10);
        deposit_from_lending<SUI, SUI>(&mut fee_pool, &mut deposit_vault, &mut incentive_balance, balance, balance::create_for_testing(1000000000), true);
        incentive_balance.destroy_for_testing();
        let (receipt2, _) = raise_fund<SUI>(&mut fee_pool, &mut deposit_vault, vector[], balance::create_for_testing(100000000000), false, false, scenario.ctx());
        deposit_vault.delivery_d<SUI, SUI>(&mut bid_vault, balance::create_for_testing(1000000000), balance::create_for_testing(1000000000), scenario.ctx());
        deposit_vault.delivery_b<SUI, SUI>(&mut bid_vault, balance::create_for_testing(1000000000), balance::create_for_testing(1000000000), scenario.ctx());
        deposit_vault.delivery_i<SUI, SUI, SUI>(&mut bid_vault, balance::create_for_testing(1000000000), balance::create_for_testing(1000000000), scenario.ctx());
        let (receipt_opt, balance_d, balance_b, balance_i, _) = reduce_fund<SUI, SUI, SUI>(&mut fee_pool, &mut deposit_vault, vector[receipt], 0, 50000000000, true, true, true, scenario.ctx());
        balance_d.destroy_for_testing();
        balance_b.destroy_for_testing();
        balance_i.destroy_for_testing();
        let (receipt2_opt, balance_d, balance_b, balance_i, _) = reduce_fund<SUI, SUI, SUI>(&mut fee_pool, &mut deposit_vault, vector[receipt2], 0, 1000000000000, true, true, true, scenario.ctx());
        balance_d.destroy_for_testing();
        balance_b.destroy_for_testing();
        balance_i.destroy_for_testing();
        let bid_receipt1 = bid_vault.public_new_bid(50000000000, scenario.ctx());
        bid_receipt1.get_bid_receipt_index();
        bid_receipt1.get_bid_receipt_vid();
        deposit_vault.recoup<SUI>(10000000000, scenario.ctx());
        deposit_vault.settle<SUI, SUI>(&mut bid_vault, 90000000, 8, scenario.ctx());
        let (receipt3, _) = raise_fund<SUI>(&mut fee_pool, &mut deposit_vault, vector[], balance::create_for_testing(100000000000), false, false, scenario.ctx());
        deposit_vault.activate<SUI>(false, scenario.ctx());
        deposit_vault.delivery_d<SUI, SUI>(&mut bid_vault, balance::create_for_testing(1000000000), balance::create_for_testing(1000000000), scenario.ctx());
        deposit_vault.delivery_b<SUI, SUI>(&mut bid_vault, balance::create_for_testing(1000000000), balance::create_for_testing(1000000000), scenario.ctx());
        deposit_vault.delivery_i<SUI, SUI, SUI>(&mut bid_vault, balance::create_for_testing(1000000000), balance::create_for_testing(1000000000), scenario.ctx());
        let bid_receipt2 = bid_vault.public_new_bid(20000000000, scenario.ctx());
        deposit_vault.recoup<SUI>(30000000000, scenario.ctx());
        deposit_vault.settle<SUI, SUI>(&mut bid_vault, 90000000, 8, scenario.ctx());
        deposit_vault.adjust_user_share_ratio<SUI>(0);
        let (receipt_opt, balance_d, balance_b, balance_i, _) = reduce_fund<SUI, SUI, SUI>(&mut fee_pool, &mut deposit_vault, vector[receipt_opt.destroy_some()], 0, 0, true, true, true, scenario.ctx());
        balance_d.destroy_for_testing();
        balance_b.destroy_for_testing();
        balance_i.destroy_for_testing();
        let (_, bid_receipt2_opt, none) = bid_vault.split_bid_receipt(vector[bid_receipt2], option::some(30000000000), scenario.ctx());
        none.destroy_none();
        let (_, bid_receipt2_opt, bid_receipt3_opt) = bid_vault.split_bid_receipt(vector[bid_receipt2_opt.destroy_some()], option::some(10000000000), scenario.ctx());
        let (_, bid_receipt3_opt, none) = bid_vault.split_bid_receipt(vector[bid_receipt3_opt.destroy_some()], option::some(10000000000), scenario.ctx());
        none.destroy_none();
        let (_, none, bid_receipt3_opt) = bid_vault.split_bid_receipt(vector[bid_receipt3_opt.destroy_some()], option::some(0), scenario.ctx());
        none.destroy_none();
        let mut bid_receipts = vector[bid_receipt1, bid_receipt2_opt.destroy_some(), bid_receipt3_opt.destroy_some()];
        bid_vault.get_bid_share(@0xA);
        bid_vault.get_bid_share(object::id_address(&bid_receipts[0]));
        bid_vault.get_bid_share(object::id_address(&bid_receipts[2]));
        bid_vault.calculate_exercise_value_for_receipts<SUI>(&bid_receipts);
        bid_vault.calculate_exercise_value<SUI>(&bid_receipts[0]);
        let (_, _, balance) = bid_vault.delegate_exercise<SUI>(vector[bid_receipts.pop_back()]);
        balance.destroy_for_testing();
        let (balance, _) = bid_vault.public_exercise<SUI>(vector[bid_receipts.pop_back()]);
        balance.destroy_for_testing();
        bid_vault.summarize_bid_shares(bid_receipts);
        let mut refund_vault = new_refund_vault<SUI>(scenario.ctx());
        transfer::public_transfer(
            dynamic_field::remove<vector<u8>, BigVector<RefundShare>>(&mut refund_vault.id, K_REFUND_SHARES),
            scenario.sender(),
        );
        dynamic_field::add(&mut refund_vault.id, K_REFUND_SHARES, big_vector::new<RefundShare>(1, scenario.ctx()));
        refund_vault.put_refund<SUI>(balance::create_for_testing(1), @0xA);
        refund_vault.put_refund<SUI>(balance::create_for_testing(1), @0xABCD);
        refund_vault.put_refund<SUI>(balance::create_for_testing(1), @0xA);
        refund_vault.get_refund_share(@0xA);
        refund_vault.get_refund_share(@0xABCD);
        refund_vault.get_refund_share(@0xB);
        refund_vault.register_refund<SUI>(@0xA);
        refund_vault.register_refund<SUI>(@0xB);
        let (balance_opt, _) = refund_vault.public_rebate<SUI>(@0xABCD);
        balance_opt.destroy_some().destroy_for_testing();
        let (balance_opt, _) = refund_vault.public_rebate<SUI>(@0xA);
        balance_opt.destroy_some().destroy_for_testing();
        let (balance_opt, _) = refund_vault.public_rebate<SUI>(@0xC);
        balance_opt.destroy_none();
        transfer::public_transfer(
            dynamic_field::remove<vector<u8>, BigVector<RefundShare>>(&mut refund_vault.id, K_REFUND_SHARES),
            scenario.sender(),
        );
        dynamic_field::add(&mut refund_vault.id, K_REFUND_SHARES, big_vector::new<RefundShare>(1, scenario.ctx()));
        refund_vault.drop_refund_vault<SUI>();
        deposit_vault.terminate<SUI>(scenario.ctx());
        let (receipt_opt, _) = deposit_vault.merge_deposit_receipts(vector[receipt_opt.destroy_some(), receipt2_opt.destroy_some()], scenario.ctx());
        transfer::public_transfer(receipt_opt.destroy_some(), scenario.sender());
        let receipt_opt = deposit_vault.add_deposit_share(10000, 0, 0, 10000, 0, 0, vector[], scenario.ctx());
        let (receipt_opt, receipt2_opt) = deposit_vault.split_deposit_receipt(receipt_opt.destroy_some(), 1000, 1000, scenario.ctx());
        deposit_vault.summarize_deposit_shares(vector[receipt_opt.destroy_some(), receipt2_opt.destroy_some(), receipt3]);
        let receipt_opt = deposit_vault.add_deposit_share(0, 0, 0, 0, 0, 0, vector[], scenario.ctx());
        receipt_opt.destroy_none();
        let mut balance = balance::create_for_testing<SUI>(1000000000);
        charge_fee_by_bp(&mut fee_pool, 1000, &mut balance);
        balance.destroy_for_testing();
        transfer::public_transfer(fee_pool, scenario.sender());
        transfer::public_transfer(deposit_vault, scenario.sender());
        transfer::public_transfer(bid_vault, scenario.sender());
        scenario.end();
    }

    #[test]
    fun test_drop_vaults() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        deposit_vault.update_deposit_vault_incentive_token<SUI>();
        deposit_vault.update_deposit_vault_incentive_token<SUI>();
        deposit_vault.update_deposit_receipt_display(b"deposit_vault".to_string());
        deposit_vault.update_fee(1000, scenario.ctx());
        deposit_vault.update_incentive_fee(1000);
        deposit_vault.close();
        deposit_vault.resume();
        deposit_vault.has_next();
        deposit_vault.fee_bp();
        deposit_vault.fee_share_bp();
        deposit_vault.get_deposit_vault_token_types();
        deposit_vault.get_deposit_vault_balance<SUI>(active_share_tag());
        deposit_vault.get_deposit_vault_balance<SUI>(deactivating_share_tag());
        deposit_vault.get_deposit_vault_balance<SUI>(inactive_share_tag());
        deposit_vault.get_deposit_vault_balance<SUI>(warmup_share_tag());
        deposit_vault.get_deposit_vault_balance<SUI>(premium_share_tag());
        deposit_vault.get_deposit_vault_balance<SUI>(incentive_share_tag());
        deposit_vault.get_deposit_vault_share_supply(active_share_tag());
        deposit_vault.get_deposit_vault_share_supply(deactivating_share_tag());
        deposit_vault.get_deposit_vault_share_supply(inactive_share_tag());
        deposit_vault.get_deposit_vault_share_supply(warmup_share_tag());
        deposit_vault.get_deposit_vault_share_supply(premium_share_tag());
        deposit_vault.get_deposit_vault_share_supply(incentive_share_tag());
        deposit_vault.get_mut_deposit_vault_share_supply(active_share_tag());
        deposit_vault.get_mut_deposit_vault_share_supply(deactivating_share_tag());
        deposit_vault.get_mut_deposit_vault_share_supply(inactive_share_tag());
        deposit_vault.get_mut_deposit_vault_share_supply(warmup_share_tag());
        deposit_vault.get_mut_deposit_vault_share_supply(premium_share_tag());
        deposit_vault.get_mut_deposit_vault_share_supply(incentive_share_tag());
        deposit_vault.active_balance<SUI>();
        deposit_vault.deactivating_balance<SUI>();
        deposit_vault.inactive_balance<SUI>();
        deposit_vault.warmup_balance<SUI>();
        deposit_vault.premium_balance<SUI>();
        deposit_vault.incentive_balance<SUI>();
        deposit_vault.active_share_supply();
        deposit_vault.deactivating_share_supply();
        deposit_vault.inactive_share_supply();
        deposit_vault.warmup_share_supply();
        deposit_vault.premium_share_supply();
        deposit_vault.get_mut_active_share_supply();
        deposit_vault.get_mut_deactivating_share_supply();
        deposit_vault.get_mut_inactive_share_supply();
        deposit_vault.get_mut_warmup_share_supply();
        deposit_vault.get_mut_premium_share_supply();
        deposit_vault.get_mut_incentive_share_supply();
        let deposit_receipt = deposit_vault.new_typus_deposit_receipt(scenario.ctx());
        transfer_deposit_receipt(option::none(), scenario.sender());
        transfer_deposit_receipt(option::some(deposit_receipt), scenario.sender());
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        bid_vault.update_bid_receipt_display(b"bid_vault".to_string());
        bid_vault.set_bid_vault_u64_padding_value(0, 0);
        bid_vault.get_bid_vault_u64_padding_value(0);
        bid_vault.get_bid_vault_token_types();
        bid_vault.bid_vault_balance<SUI>();
        bid_vault.bid_share_supply();
        bid_vault.get_bid_shares();
        let mut bid_receipt = bid_vault.new_typus_bid_receipt(0, scenario.ctx());
        bid_receipt.update_bid_receipt_u64_padding(vector[0]);
        transfer_bid_receipt(option::none(), scenario.sender());
        transfer_bid_receipt(option::some(bid_receipt), scenario.sender());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        let mut refund_vault = new_refund_vault<SUI>(scenario.ctx());
        refund_vault.refund_vault_share_supply();
        refund_vault.get_refund_shares();
        refund_vault.register_refund<SUI>(scenario.sender());
        refund_vault.refund_vault_balance<SUI>();
        transfer::public_transfer(
            dynamic_field::remove<vector<u8>, BigVector<RefundShare>>(&mut refund_vault.id, K_REFUND_SHARES),
            scenario.sender(),
        );
        dynamic_field::add(&mut refund_vault.id, K_REFUND_SHARES, big_vector::new<RefundShare>(4500, scenario.ctx()));
        refund_vault.drop_refund_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_public_rebate_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut refund_vault = new_refund_vault<SUI>(scenario.ctx());
        let (balance_opt, _) = public_rebate<TEST>(
            &mut refund_vault,
            scenario.sender(),
        );
        balance_opt.destroy_none();
        refund_vault.drop_refund_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_register_refund_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut refund_vault = new_refund_vault<SUI>(scenario.ctx());
        register_refund<TEST>(
            &mut refund_vault,
            scenario.sender(),
        );
        refund_vault.drop_refund_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_put_refund_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut refund_vault = new_refund_vault<SUI>(scenario.ctx());
        put_refund<TEST>(
            &mut refund_vault,
            balance::zero(),
            scenario.sender(),
        );
        refund_vault.drop_refund_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_put_refunds_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut refund_vault = new_refund_vault<SUI>(scenario.ctx());
        put_refunds<TEST>(
            &mut refund_vault,
            balance::zero(),
            vector[],
            vector[],
        );
        refund_vault.drop_refund_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EDepositDisabled, location = Self)]
    fun test_raise_fund_deposit_disabled_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        deposit_vault.has_next = false;
        let (receipt, _ ) = raise_fund<SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            balance::zero(),
            false,
            false,
            scenario.ctx(),
        );
        transfer::public_transfer(receipt, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_raise_fund_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (receipt, _ ) = raise_fund<TEST>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            balance::zero(),
            false,
            false,
            scenario.ctx(),
        );
        transfer::public_transfer(receipt, scenario.sender());
        transfer::public_transfer(fee_pool, scenario.sender());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_reduce_fund_invalid_token_error_1() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<TEST, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (receipt_opt, balance_d, balance_b, balance_i, _ ) = reduce_fund<SUI, SUI, SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            0,
            0,
            false,
            false,
            false,
            scenario.ctx(),
        );
        receipt_opt.destroy_none();
        balance_d.destroy_for_testing();
        balance_b.destroy_for_testing();
        balance_i.destroy_for_testing();
        transfer::public_transfer(fee_pool, scenario.sender());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_reduce_fund_invalid_token_error_2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, TEST>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (receipt_opt, balance_d, balance_b, balance_i, _ ) = reduce_fund<SUI, SUI, SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            0,
            0,
            false,
            false,
            false,
            scenario.ctx(),
        );
        receipt_opt.destroy_none();
        balance_d.destroy_for_testing();
        balance_b.destroy_for_testing();
        balance_i.destroy_for_testing();
        transfer::public_transfer(fee_pool, scenario.sender());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_reduce_fund_invalid_token_error_3() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (receipt_opt, balance_d, balance_b, balance_i, _ ) = reduce_fund<SUI, SUI, SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            0,
            0,
            false,
            false,
            true,
            scenario.ctx(),
        );
        receipt_opt.destroy_none();
        balance_d.destroy_for_testing();
        balance_b.destroy_for_testing();
        balance_i.destroy_for_testing();
        transfer::public_transfer(fee_pool, scenario.sender());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidShareTag, location = Self)]
    fun test_invalid_share_tag_error_1() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        get_deposit_vault_balance<SUI>(
            &deposit_vault,
            10,
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidShareTag, location = Self)]
    fun test_invalid_share_tag_error_2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        get_mut_deposit_vault_balance<SUI>(
            &mut deposit_vault,
            10,
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidShareTag, location = Self)]
    fun test_invalid_share_tag_error_3() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        get_deposit_vault_share_supply(
            &deposit_vault,
            10,
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidShareTag, location = Self)]
    fun test_invalid_share_tag_error_4() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        get_mut_deposit_vault_share_supply(
            &mut deposit_vault,
            10,
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidShareTag, location = Self)]
    fun test_invalid_share_tag_error_5() {
        let deposit_share = DepositShare {
            receipt: @0xA,
            active_share: 0,
            deactivating_share: 0,
            inactive_share: 0,
            warmup_share: 0,
            premium_share: 0,
            incentive_share: 0,
            u64_padding: vector[],
        };
        get_deposit_share_inner(
            &deposit_share,
            10,
        );
        let DepositShare {
            receipt: _,
            active_share: _,
            deactivating_share: _,
            inactive_share: _,
            warmup_share: _,
            premium_share: _,
            incentive_share: _,
            u64_padding: _,
        } = deposit_share;
    }

    #[test]
    #[expected_failure(abort_code = EInvalidShareTag, location = Self)]
    fun test_invalid_share_tag_error_6() {
        let mut deposit_share = DepositShare {
            receipt: @0xA,
            active_share: 0,
            deactivating_share: 0,
            inactive_share: 0,
            warmup_share: 0,
            premium_share: 0,
            incentive_share: 0,
            u64_padding: vector[],
        };
        get_mut_deposit_share_inner(
            &mut deposit_share,
            10,
        );
        let DepositShare {
            receipt: _,
            active_share: _,
            deactivating_share: _,
            inactive_share: _,
            warmup_share: _,
            premium_share: _,
            incentive_share: _,
            u64_padding: _,
        } = deposit_share;
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_activate_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        activate<TEST>(
            &mut deposit_vault,
            true,
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_recoup_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        recoup<TEST>(
            &mut deposit_vault,
            0,
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EZeroValue, location = Self)]
    fun test_settle_zero_value_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        settle<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            0,
            0,
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_settle_invalid_token_error_1() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<TEST, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        settle<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            1,
            0,
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_settle_invalid_token_error_2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, TEST>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        settle<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            1,
            0,
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_settle_invalid_token_error_3() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<TEST, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        settle<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            1,
            0,
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_settle_invalid_token_error_4() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, TEST>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        settle<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            1,
            0,
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_terminate_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        terminate<TEST>(
            &mut deposit_vault,
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_public_exercise_invalid_token_error_1() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bid_vault = new_bid_vault<TEST, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        let (balance, _) = public_exercise<SUI>(
            &mut bid_vault,
            vector[],
        );
        balance.destroy_for_testing();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_public_exercise_invalid_token_error_2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        bid_vault.incentive_token = option::some(type_name::with_defining_ids<SUI>());
        let (balance, _) = public_exercise<SUI>(
            &mut bid_vault,
            vector[],
        );
        balance.destroy_for_testing();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_calculate_exercise_value_for_receipts_invalid_token_error_1() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let bid_vault = new_bid_vault<TEST, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        let receipts = vector[];
        calculate_exercise_value_for_receipts<SUI>(
            &bid_vault,
            &receipts,
        );
        receipts.destroy_empty();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_calculate_exercise_value_for_receipts_invalid_token_error_2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        bid_vault.incentive_token = option::some(type_name::with_defining_ids<SUI>());
        let receipts = vector[];
        calculate_exercise_value_for_receipts<SUI>(
            &bid_vault,
            &receipts,
        );
        receipts.destroy_empty();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_calculate_exercise_value_invalid_token_error_1() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let bid_vault = new_bid_vault<TEST, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        let bid_receipt = new_typus_bid_receipt(&bid_vault, 0, scenario.ctx());
        calculate_exercise_value<SUI>(
            &bid_vault,
            &bid_receipt,
        );
        transfer::public_transfer(bid_receipt, scenario.sender());
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_calculate_exercise_value_invalid_token_error_2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        bid_vault.incentive_token = option::some(type_name::with_defining_ids<SUI>());
        let bid_receipt = new_typus_bid_receipt(&bid_vault, 0, scenario.ctx());
        calculate_exercise_value<SUI>(
            &bid_vault,
            &bid_receipt,
        );
        transfer::public_transfer(bid_receipt, scenario.sender());
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_invalid_token_error_1() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<TEST, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_invalid_token_error_2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, TEST>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_invalid_token_error_3() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<TEST, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_invalid_token_error_4() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, TEST>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_d_invalid_token_error_1() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<TEST, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_d<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_d_invalid_token_error_2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, TEST>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_d<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_d_invalid_token_error_3() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<TEST, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_d<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_d_invalid_token_error_4() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, TEST>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_d<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_b_invalid_token_error_1() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<TEST, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_b<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_b_invalid_token_error_2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, TEST>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_b<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_b_invalid_token_error_3() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<TEST, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_b<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_b_invalid_token_error_4() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, TEST>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_b<SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_i_invalid_token_error_1() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<TEST, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_i<SUI, SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_i_invalid_token_error_2() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, TEST>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_i<SUI, SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_i_invalid_token_error_3() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_i<SUI, SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_i_invalid_token_error_4() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        deposit_vault.incentive_token = option::some(type_name::with_defining_ids<SUI>());
        let mut bid_vault = new_bid_vault<TEST, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_i<SUI, SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_i_invalid_token_error_5() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        deposit_vault.incentive_token = option::some(type_name::with_defining_ids<SUI>());
        let mut bid_vault = new_bid_vault<SUI, TEST>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        delivery_i<SUI, SUI, SUI>(
            &mut deposit_vault,
            &mut bid_vault,
            balance::zero(),
            balance::zero(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_public_deposit_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (coins, receipt_opt, _) = public_deposit<SUI>(
            &mut deposit_vault,
            vector[],
            0,
            vector[],
            scenario.ctx(),
        );
        coins.destroy_empty();
        receipt_opt.destroy_none();
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_public_withdraw_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (balance_opt, receipt_opt, _) = public_withdraw<SUI>(
            &mut deposit_vault,
            vector[],
            option::none(),
            scenario.ctx(),
        );
        balance_opt.destroy_none();
        receipt_opt.destroy_none();
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_to_inactive_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (receipt_opt, _) = withdraw_to_inactive<SUI>(
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        receipt_opt.destroy_none();
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_public_unsubscribe_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (receipt_opt, _) = public_unsubscribe<SUI>(
            &mut deposit_vault,
            vector[],
            option::none(),
            scenario.ctx(),
        );
        receipt_opt.destroy_none();
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_public_unsubscribe_share_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (receipt_opt, _) = public_unsubscribe_share(
            &mut deposit_vault,
            vector[],
            option::none(),
            scenario.ctx(),
        );
        receipt_opt.destroy_none();
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_public_claim_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (balance_opt_, receipt_opt, _) = public_claim<SUI>(
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        balance_opt_.destroy_none();
        receipt_opt.destroy_none();
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_public_harvest_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (balance_opt_, receipt_opt, _) = public_harvest<SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        balance_opt_.destroy_none();
        receipt_opt.destroy_none();
        fee_pool.drop_balance_pool(scenario.ctx());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_public_redeem_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (balance_opt_, receipt_opt, _) = public_redeem<SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        balance_opt_.destroy_none();
        receipt_opt.destroy_none();
        fee_pool.drop_balance_pool(scenario.ctx());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_public_compound_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        let (receipt_opt, _) = public_compound<SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        receipt_opt.destroy_none();
        fee_pool.drop_balance_pool(scenario.ctx());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_deposit_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        deposit<SUI>(
            &mut deposit_vault,
            vector[],
            0,
            vector[],
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_withdraw_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        withdraw<SUI>(
            &mut deposit_vault,
            vector[],
            option::none(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_unsubscribe_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        unsubscribe<SUI>(
            &mut deposit_vault,
            vector[],
            option::none(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_unsubscribe_share_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        unsubscribe_share(
            &mut deposit_vault,
            vector[],
            option::none(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_claim_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        claim<SUI>(
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_harvest_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        harvest<SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        fee_pool.drop_balance_pool(scenario.ctx());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_harvest_v2_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        harvest_v2<SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        fee_pool.drop_balance_pool(scenario.ctx());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_compound_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        compound<SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        fee_pool.drop_balance_pool(scenario.ctx());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_compound_v2_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        compound_v2<SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        fee_pool.drop_balance_pool(scenario.ctx());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_redeem_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        redeem<SUI>(
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_redeem_v2_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        redeem_v2<SUI>(
            &mut fee_pool,
            &mut deposit_vault,
            vector[],
            scenario.ctx(),
        );
        fee_pool.drop_balance_pool(scenario.ctx());
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_bid_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        new_bid(
            &mut bid_vault,
            0,
            scenario.ctx(),
        );
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_exercise_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        exercise<SUI>(
            &mut bid_vault,
            vector[],
            scenario.ctx(),
        );
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_exercise_v2_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        exercise_v2<SUI>(
            &mut bid_vault,
            vector[],
            scenario.ctx(),
        );
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_exercise_i_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        exercise_i<SUI, SUI>(
            &mut bid_vault,
            vector[],
            scenario.ctx(),
        );
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_take_refund_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut refund_vault = new_refund_vault<SUI>(scenario.ctx());
        take_refund<SUI>(
            &mut refund_vault,
            scenario.ctx(),
        );
        refund_vault.drop_refund_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_delegate_take_refund_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut refund_vault = new_refund_vault<SUI>(scenario.ctx());
        let coin = delegate_take_refund<SUI>(
            &mut refund_vault,
            scenario.sender(),
            scenario.ctx(),
        );
        coin.burn_for_testing();
        refund_vault.drop_refund_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_is_active_user_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        is_active_user(
            &deposit_vault,
            scenario.sender(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_is_deactivating_user_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        is_deactivating_user(
            &deposit_vault,
            scenario.sender(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_is_inactive_user_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        is_inactive_user(
            &deposit_vault,
            scenario.sender(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_is_warmup_user_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        is_warmup_user(
            &deposit_vault,
            scenario.sender(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_get_active_deposit_share_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        get_active_deposit_share(
            &deposit_vault,
            scenario.sender(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_get_deactivating_deposit_share_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        get_deactivating_deposit_share(
            &deposit_vault,
            scenario.sender(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_get_inactive_deposit_share_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        get_inactive_deposit_share(
            &deposit_vault,
            scenario.sender(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_get_warmup_deposit_share_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        get_warmup_deposit_share(
            &deposit_vault,
            scenario.sender(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_get_premium_deposit_share_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        get_premium_deposit_share(
            &deposit_vault,
            scenario.sender(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_incentivise_bidder_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        incentivise_bidder<SUI>(
            &mut bid_vault,
            balance::zero(),
            scenario.ctx(),
        );
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    fun test_update_fee_share_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        update_fee_share(
            &mut deposit_vault,
            0,
            option::none(),
            scenario.ctx(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    public fun test_bid_vault_incentive_balance_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        bid_vault_incentive_balance<SUI>(
            &bid_vault,
        );
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    public fun test_get_bid_vault_incentive_balance_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let bid_vault = new_bid_vault<SUI, SUI>(
            0,
            b"bid_vault".to_string(),
            scenario.ctx(),
        );
        get_bid_vault_incentive_balance<SUI>(
            &bid_vault,
        );
        bid_vault.drop_bid_vault<SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    public fun test_charge_deposit_vault_inactive_token_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut deposit_vault = new_deposit_vault<SUI, SUI>(
            0,
            1000,
            b"deposit_vault".to_string(),
            scenario.ctx(),
        );
        charge_deposit_vault_inactive_token<SUI>(
            &mut deposit_vault,
            balance::zero(),
        );
        deposit_vault.drop_deposit_vault<SUI, SUI>();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    #[allow(deprecated_usage)]
    public fun test_deprecated_abort() {
        deprecated();
    }
}