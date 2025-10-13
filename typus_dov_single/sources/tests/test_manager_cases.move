#[test_only]
module typus_dov::test_manager_cases {
    use sui::sui::SUI;
    use sui::test_scenario::{Scenario, begin, end, ctx, sender, next_tx, take_from_sender};

    use typus_dov::test_environment::{Self, USDC, current_ts_ms};
    use typus_dov::test_tds_user_entry;
    use typus_dov::test_manager_entry;
    use typus_dov::babe::BABE;
    use typus_framework::vault::TypusDepositReceipt;

    const ADMIN: address = @0xFFFF;
    const BABE1: address = @0xBABE1;
    const BABE2: address = @0xBABE2;
    const BABE3: address = @0xBABE3;

    #[test]
    public(package) fun test_new_portfolio_vault() {
        let mut scenario = test_environment::begin_test();
        let sui_oracle_id = test_environment::new_oracle<SUI>(&mut scenario);

        // create daily call
        test_manager_entry::test_new_portfolio_vault_<SUI, SUI>(
            &mut scenario,
            0, // option type
            0, // period
            9, 9, 9, // d b o decimal
            current_ts_ms() / 86400_000 * 86400_000, // activation ts ms
            current_ts_ms() / 86400_000 * 86400_000 + 86400_000, // expiration ts ms
            sui_oracle_id, 100000_0000_0000, // oracle id, price
            1_0000_00000, 1_0000_00000, // deposit, bid lot size
            100_0000_00000, 100_0000_00000, // min deposit, bid size
            10000, 10000, // max deposit, bid entry
            0, 1000, // deposit, bid fee bp
            10, 1000, // deposit, bid incentive bp
            0, 300_000, // auction delay, duration ts ms
            86400_000,// recoup_delay_ts_ms
            1000000_0000_00000, 100, 1, // capacity, leverage, risk_level
            true, vector[10100], vector[1], vector[false], // has_next, strike_bp, weight, is_buyer
            0_0100_00000, // strike_increment
            1, 100_0000_00000, 50_0000_00000, // decay_speed, upper bound price, lower bound price
            vector[ADMIN], // whitelist
            current_ts_ms()
        );

        // create weekly put (ts_ms 0 is Thursday 0:00)
        let activation_ts_ms = current_ts_ms() / 604800_000 * 604800_000 + 86400_000 + 8 * 3600_000;
        test_manager_entry::test_new_portfolio_vault_<USDC, SUI>(
            &mut scenario,
            1, // option type
            1, // period
            6, 9, 9, // d b o decimal
            activation_ts_ms,
            activation_ts_ms + 604800_000, // expiration ts ms
            sui_oracle_id, 100000_0000_0000, // oracle id, price
            1_0000_00000, 1_0000_00000, // deposit, bid lot size
            100_0000_00000, 100_0000_00000, // min deposit, bid size
            10000, 10000, // max deposit, bid entry
            0, 1000, // deposit, bid fee bp
            10, 1000, // deposit, bid incentive bp
            0, 1800_000, // auction delay, duration ts ms
            86400_000,// recoup_delay_ts_ms
            1000000_000_000, 100, 1, // capacity, leverage, risk_level
            true, vector[9000], vector[1], vector[false], // has_next, strike_bp, weight, is_buyer
            0_0100_00000, // strike_increment
            1, 100_0000_00000, 50_0000_00000, // decay_speed, upper bound price, lower bound price
            vector[ADMIN], // whitelist
            current_ts_ms()
        );

        end(scenario);
    }

    #[test]
    public(package) fun test_vault_evolution() {
        let mut scenario = test_environment::begin_test();
        test_environment::prepare_navi_lending_env(&mut scenario);
        test_manager_entry::test_incentivise_<BABE>(&mut scenario, 10000_0000_00000);
        let sui_oracle_id = test_environment::new_oracle<BABE>(&mut scenario);

        // create daily call
        test_manager_entry::test_new_portfolio_vault_<BABE, BABE>(
            &mut scenario,
            0, // option type
            0, // period
            9, 9, 9, // d b o decimal
            current_ts_ms() / 86400_000 * 86400_000, // activation ts ms
            current_ts_ms() / 86400_000 * 86400_000 + 86400_000, // expiration ts ms
            sui_oracle_id, 100000_0000_0000, // oracle id, price
            1_0000_00000, 1_0000_00000, // deposit, bid lot size
            100_0000_00000, 100_0000_00000, // min deposit, bid size
            10000, 10000, // max deposit, bid entry
            0, 1000, // deposit, bid fee bp
            10, 1000, // deposit, bid incentive bp
            0, 300_000, // auction delay, duration ts ms
            86400_000,// recoup_delay_ts_ms
            1000000_0000_00000, 100, 1, // capacity, leverage, risk_level
            true, vector[10100], vector[1], vector[false], // has_next, strike_bp, weight, is_buyer
            0_0100_00000, // strike_increment
            1, 0_0200_00000, 0_0100_00000, // decay_speed, upper bound price, lower bound price
            vector[ADMIN], // whitelist
            current_ts_ms()
        );

        // set protocol flag = 4 (navi)
        test_manager_entry::test_set_lending_protocol_flag_(&mut scenario, 0, 4);
        test_manager_entry::test_set_safu_vault_index_(&mut scenario, 0, 999); // nothing happened
        test_manager_entry::test_add_portfolio_vault_authorized_user_(&mut scenario, 0, vector[BABE1, BABE2]);
        test_manager_entry::test_remove_portfolio_vault_authorized_user_(&mut scenario, 0, vector[BABE2]);

        let index = 0;
        let activate_ts_ms = current_ts_ms() / 86400_000 * 86400_000;

        // deposit
        let ts_ms = activate_ts_ms;
        let deposit_amount = 1000_0000_00000;
        let receipt = test_tds_user_entry::test_public_raise_fund_<BABE, BABE>(&mut scenario, index, vector[], deposit_amount, false, false, ts_ms);
        transfer::public_transfer(receipt, sender(&scenario));

        // activate
        let ts_ms = activate_ts_ms;
        let oracle_price = 100000_0000_0000;
        test_manager_entry::test_activate_<BABE, BABE, BABE>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        test_manager_entry::test_deposit_navi_<BABE, BABE>(&mut scenario, index, 0, ts_ms);

        test_manager_entry::test_new_auction_<BABE, BABE>(&mut scenario, index);

        let premium = 2_0000_00000; // 100 * 0.0167 => rebate ~ 0.164
        let bid_ts_ms = activate_ts_ms + 100_000;
        let (bid_receipt, rebate_coin) = test_tds_user_entry::test_public_bid_<BABE, BABE>(
            &mut scenario,
            index,
            premium,
            100_0000_00000,
            bid_ts_ms,
        );
        transfer::public_transfer(bid_receipt, sender(&scenario));
        transfer::public_transfer(rebate_coin, sender(&scenario));
        next_tx(&mut scenario, ADMIN);

        let ts_ms = activate_ts_ms + 300_000;
        test_manager_entry::test_delivery_<BABE, BABE, BABE>(&mut scenario, index, ts_ms);

        let ts_ms = activate_ts_ms + 86400_000;
        test_manager_entry::test_reward_navi_<BABE, BABE, SUI>(&mut scenario, index, ts_ms);
        test_manager_entry::test_withdraw_navi_<BABE, BABE>(&mut scenario, index, 0, ts_ms);

        let ts_ms = activate_ts_ms + 86400_000;
        test_manager_entry::test_recoup_<BABE, BABE>(&mut scenario, index, ts_ms);

        // settle
        let ts_ms = activate_ts_ms + 86400_000;
        let oracle_price = 100000_0000_0000;
        test_manager_entry::test_settle_<BABE, BABE>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        test_manager_entry::test_set_current_lending_protocol_flag_(&mut scenario, 0, 4);
        test_manager_entry::test_close_<BABE, BABE>(&mut scenario, index);
        test_manager_entry::test_resume_<BABE, BABE>(&mut scenario, index);
        test_manager_entry::test_terminate_vault_<BABE, BABE>(&mut scenario, index);

        // withdraw all fund from premium share
        let ts_ms = activate_ts_ms + 86400_000;
        let receipt = take_from_sender<TypusDepositReceipt>(&mut scenario);
        test_tds_user_entry::test_public_reduce_fund_<BABE, BABE, BABE>(
            &mut scenario,
            index,
            vector[receipt],
            0,
            0,
            true,
            false,
            false,
            ts_ms,
        );

        // withdraw all fund from inactive share
        let ts_ms = activate_ts_ms + 86400_000;
        let receipt = take_from_sender<TypusDepositReceipt>(&mut scenario);
        test_tds_user_entry::test_public_reduce_fund_<BABE, BABE, BABE>(
            &mut scenario,
            index,
            vector[receipt],
            0,
            0,
            false,
            true,
            false,
            ts_ms,
        );

        test_manager_entry::test_drop_vault_<BABE, BABE>(&mut scenario, index);

        end(scenario);

    }
}
