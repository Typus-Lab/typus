#[test_only]
module typus_dov::test_user_cases {
    use sui::sui::SUI;
    use sui::test_scenario::{end, ctx, sender, next_tx, return_shared, take_from_sender};
    use typus_dov::test_environment::{Self, current_ts_ms};
    use typus_dov::test_manager_entry;
    use typus_dov::test_tds_user_entry;
    use typus_dov::tds_view_function;
    use typus_dov::babe::BABE;
    use typus_framework::vault::{TypusDepositReceipt, TypusBidReceipt};

    const ADMIN: address = @0xFFFF;
    const BABE1: address = @0xBABE1;

    #[test]
    public(package) fun test_user_operations() {
        let mut scenario = test_environment::begin_test();
        test_manager_entry::test_incentivise_<SUI>(&mut scenario, 10000_0000_00000);
        test_manager_entry::test_withdraw_incentive_<SUI>(&mut scenario, option::some(1_0000_00000));
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
            1, 0_0200_00000, 0_0100_00000, // decay_speed, upper bound price, lower bound price
            vector[ADMIN], // whitelist
            current_ts_ms()
        );

        let index = 0;
        let activate_ts_ms = current_ts_ms() / 86400_000 * 86400_000;

        // deposit
        let ts_ms = activate_ts_ms;
        let deposit_amount = 1000_0000_00000;
        let receipt = test_tds_user_entry::test_public_raise_fund_<SUI, SUI>(&mut scenario, index, vector[], deposit_amount, false, false, ts_ms);
        transfer::public_transfer(receipt, sender(&scenario));

        // activate
        let ts_ms = activate_ts_ms;
        let oracle_price = 100000_0000_0000;
        test_manager_entry::test_activate_<SUI, SUI, SUI>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        test_manager_entry::test_new_auction_<SUI, SUI>(&mut scenario, index);

        let premium = 2_0000_00000; // 100 * 0.0167 => rebate ~ 0.164
        let bid_ts_ms = activate_ts_ms + 100_000;
        let (bid_receipt, rebate_coin) = test_tds_user_entry::test_public_bid_<SUI, SUI>(
            &mut scenario,
            index,
            premium,
            100_0000_00000,
            bid_ts_ms,
        );
        transfer::public_transfer(bid_receipt, sender(&scenario));
        transfer::public_transfer(rebate_coin, sender(&scenario));
        next_tx(&mut scenario, BABE1);
        let premium = 100000_0000_00000; // 100 * 0.0167 => rebate ~ 0.164
        let bid_ts_ms = activate_ts_ms + 100_000;
        let (bid_receipt, rebate_coin) = test_tds_user_entry::test_public_bid_<SUI, SUI>(
            &mut scenario,
            index,
            premium,
            1000_0000_00000, // exceed max size
            bid_ts_ms,
        );
        transfer::public_transfer(bid_receipt, BABE1);
        transfer::public_transfer(rebate_coin, BABE1);

        next_tx(&mut scenario, ADMIN);
        let ts_ms = activate_ts_ms + 300_000;
        test_manager_entry::test_delivery_<SUI, SUI, SUI>(&mut scenario, index, ts_ms);

        // transfer bid receipt
        next_tx(&mut scenario, BABE1);
        let receipt = take_from_sender<TypusBidReceipt>(&scenario);
        test_tds_user_entry::test_transfer_bid_receipt_<SUI, SUI>(
            &mut scenario,
            index,
            vector[receipt],
            option::some(100_0000_00000),
            ADMIN,
        );
        let receipt = take_from_sender<TypusBidReceipt>(&scenario);
        test_tds_user_entry::test_public_transfer_bid_receipt_<SUI, SUI>(
            &mut scenario,
            index,
            vector[receipt],
            option::some(100_0000_00000),
            ADMIN,
        );
        let receipt = take_from_sender<TypusBidReceipt>(&scenario);
        test_tds_user_entry::test_transfer_bid_receipt_<SUI, SUI>(
            &mut scenario,
            index,
            vector[receipt],
            option::none(),
            ADMIN,
        );

        // compound
        next_tx(&mut scenario, ADMIN);
        let ts_ms = activate_ts_ms + 300_001;
        let deposit_amount = 0;
        let receipt = take_from_sender<TypusDepositReceipt>(&scenario);
        let receipt = test_tds_user_entry::test_public_raise_fund_<SUI, SUI>(&mut scenario, index, vector[receipt], deposit_amount, true, false, ts_ms);
        transfer::public_transfer(receipt, sender(&scenario));
        next_tx(&mut scenario, ADMIN);

        let ts_ms = activate_ts_ms + 86400_000;
        test_manager_entry::test_recoup_<SUI, SUI>(&mut scenario, index, ts_ms);

        // settle
        let ts_ms = activate_ts_ms + 86400_000;
        let oracle_price = 110000_0000_0000;
        test_manager_entry::test_settle_<SUI, SUI>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        let receipt = take_from_sender<TypusBidReceipt>(&scenario);
        test_tds_user_entry::test_exercise_<SUI, SUI>(&mut scenario, index, vector[receipt]);

        // activate
        // activate_ts_ms = ts_ms;
        let oracle_price = 100000_0000_0000;
        test_manager_entry::test_activate_<SUI, SUI, SUI>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        // refresh deposit snapshot
        let receipt = take_from_sender<TypusDepositReceipt>(&scenario);
        test_tds_user_entry::test_public_refresh_deposit_snapshot_<SUI, SUI>(&mut scenario, index, vector[receipt], ts_ms);

        // unsubscribe
        next_tx(&mut scenario, ADMIN);
        let receipt = take_from_sender<TypusDepositReceipt>(&scenario);
        test_tds_user_entry::test_public_reduce_fund_<SUI, SUI, SUI>(
            &mut scenario,
            index,
            vector[receipt],
            0,
            deposit_amount / 2, // unsubscribe half of active fund
            false,
            false,
            false,
            ts_ms,
        );

        // split deposit receipt
        next_tx(&mut scenario, ADMIN);
        let receipt = take_from_sender<TypusDepositReceipt>(&scenario);
        test_tds_user_entry::test_split_deposit_receipt_v2_(
            &mut scenario,
            index,
            receipt,
            100_0000_00000,
            0,
        );

        // merge deposit receipt
        let receipt_1 = take_from_sender<TypusDepositReceipt>(&scenario);
        let receipt_0 = take_from_sender<TypusDepositReceipt>(&scenario);
        test_tds_user_entry::test_merge_deposit_receipts_(&mut scenario, index, vector[receipt_1, receipt_0]);

        // // withdraw all fund from premium share
        // let ts_ms = activate_ts_ms + 86400_000;
        // let receipt = take_from_sender<TypusDepositReceipt>(&mut scenario);
        // test_public_reduce_fund_<SUI, SUI, SUI>(
        //     &mut scenario,
        //     index,
        //     vector[receipt],
        //     0,
        //     0,
        //     true,
        //     false,
        //     false,
        //     ts_ms,
        // );

        // // withdraw all fund from inactive share
        // let ts_ms = activate_ts_ms + 86400_000;
        // let receipt = take_from_sender<TypusDepositReceipt>(&mut scenario);
        // test_public_reduce_fund_<SUI, SUI, SUI>(
        //     &mut scenario,
        //     index,
        //     vector[receipt],
        //     0,
        //     0,
        //     false,
        //     true,
        //     false,
        //     ts_ms,
        // );


        end(scenario);

    }

    #[test]
    public(package) fun test_view_functions() {
        let mut scenario = test_environment::begin_test();
        test_manager_entry::test_incentivise_<SUI>(&mut scenario, 10000_0000_00000);
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
            1, 0_0200_00000, 0_0100_00000, // decay_speed, upper bound price, lower bound price
            vector[ADMIN], // whitelist
            current_ts_ms()
        );
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
            1, 0_0200_00000, 0_0100_00000, // decay_speed, upper bound price, lower bound price
            vector[ADMIN], // whitelist
            current_ts_ms()
        );
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
            1, 0_0200_00000, 0_0100_00000, // decay_speed, upper bound price, lower bound price
            vector[ADMIN], // whitelist
            current_ts_ms()
        );

        let index = 0;
        let activate_ts_ms = current_ts_ms() / 86400_000 * 86400_000;

        // deposit
        let ts_ms = activate_ts_ms;
        let deposit_amount = 1000_0000_00000;
        let deposit_receipt1 = test_tds_user_entry::test_public_raise_fund_<SUI, SUI>(&mut scenario, index, vector[], deposit_amount, false, false, ts_ms);
        let deposit_receipt11 = test_tds_user_entry::test_public_raise_fund_<SUI, SUI>(&mut scenario, index, vector[], deposit_amount, false, false, ts_ms);
        let deposit_receipt2 = test_tds_user_entry::test_public_raise_fund_<SUI, SUI>(&mut scenario, 1, vector[], deposit_amount, false, false, ts_ms);
        let deposit_receipt3 = test_tds_user_entry::test_public_raise_fund_<SUI, SUI>(&mut scenario, 2, vector[], deposit_amount, false, false, ts_ms);

        // activate
        let ts_ms = activate_ts_ms;
        let oracle_price = 100000_0000_0000;
        test_manager_entry::test_activate_<SUI, SUI, SUI>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );
        test_manager_entry::test_activate_<SUI, SUI, SUI>(
            &mut scenario,
            1,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );
        test_manager_entry::test_activate_<SUI, SUI, SUI>(
            &mut scenario,
            2,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        test_manager_entry::test_new_auction_<SUI, SUI>(&mut scenario, index);
        test_manager_entry::test_new_auction_<SUI, SUI>(&mut scenario, 1);
        test_manager_entry::test_new_auction_<SUI, SUI>(&mut scenario, 2);

        let premium = 2_0000_00000; // 100 * 0.0167 => rebate ~ 0.164
        let bid_ts_ms = activate_ts_ms + 100_000;
        let (bid_receipt1, rebate_coin) = test_tds_user_entry::test_public_bid_<SUI, SUI>(
            &mut scenario,
            index,
            premium,
            100_0000_00000,
            bid_ts_ms,
        );
        transfer::public_transfer(rebate_coin, sender(&scenario));
        let (bid_receipt2, rebate_coin) = test_tds_user_entry::test_public_bid_<SUI, SUI>(
            &mut scenario,
            index,
            premium,
            100_0000_00000,
            bid_ts_ms,
        );
        transfer::public_transfer(rebate_coin, sender(&scenario));
        let (bid_receipt3, rebate_coin) = test_tds_user_entry::test_public_bid_<SUI, SUI>(
            &mut scenario,
            index,
            premium,
            100_0000_00000,
            bid_ts_ms,
        );
        transfer::public_transfer(rebate_coin, sender(&scenario));
        next_tx(&mut scenario, BABE1);
        let premium = 100000_0000_00000; // 100 * 0.0167 => rebate ~ 0.164
        let bid_ts_ms = activate_ts_ms + 100_000;
        let (bid_receipt, rebate_coin) = test_tds_user_entry::test_public_bid_<SUI, SUI>(
            &mut scenario,
            index,
            premium,
            1000_0000_00000, // exceed max size
            bid_ts_ms,
        );
        transfer::public_transfer(bid_receipt, BABE1);
        transfer::public_transfer(rebate_coin, BABE1);

        {
            let registry = test_environment::dov_registry(&scenario);
            let _result = tds_view_function::get_vault_data_bcs(&registry, vector[]);
            let _result = tds_view_function::get_vault_data_bcs(&registry, vector[0]);
            let _result = tds_view_function::get_vault_data_bcs(&registry, vector[1]);
            return_shared(registry);
        };
        next_tx(&mut scenario, ADMIN);

        {
            let registry = test_environment::dov_registry(&scenario);
            let _result = tds_view_function::get_auction_bcs(&registry, vector[]);
            let _result = tds_view_function::get_auction_bcs(&registry, vector[0]);
            let _result = tds_view_function::get_auction_bcs(&registry, vector[1]);
            return_shared(registry);
        };
        next_tx(&mut scenario, ADMIN);

        {
            let registry = test_environment::dov_registry(&scenario);
            let _result = tds_view_function::get_auction_bids_bcs(&registry, 0);
            let _result = tds_view_function::get_auction_bids_bcs(&registry, 3);
            return_shared(registry);
        };
        next_tx(&mut scenario, ADMIN);

        {
            let registry = test_environment::dov_registry(&scenario);
            let _result = tds_view_function::get_deposit_shares_bcs(&registry, vector[], sender(&scenario));
            let _result = tds_view_function::get_deposit_shares_bcs(&registry, vector[deposit_receipt1, deposit_receipt11], sender(&scenario));
            let _result = tds_view_function::get_deposit_shares_bcs(&registry, vector[deposit_receipt2, deposit_receipt3], sender(&scenario));
            return_shared(registry);
        };
        next_tx(&mut scenario, ADMIN);

        {
            let registry = test_environment::dov_registry(&scenario);
            let _result = tds_view_function::get_my_bids_bcs(&registry, vector[]);
            let _result = tds_view_function::get_my_bids_bcs(&registry, vector[bid_receipt1]);
            let _result = tds_view_function::get_my_bids_bcs(&registry, vector[bid_receipt2, bid_receipt3]);
            return_shared(registry);
        };
        next_tx(&mut scenario, ADMIN);

        {
            let registry = test_environment::dov_registry(&scenario);
            let _result = tds_view_function::get_refund_shares_bcs<SUI>(&registry, ctx(&mut scenario));
            let _result = tds_view_function::get_refund_shares_bcs<BABE>(&registry, ctx(&mut scenario));
            return_shared(registry);
        };

        next_tx(&mut scenario, ADMIN);
        let ts_ms = activate_ts_ms + 300_000;
        test_manager_entry::test_delivery_<SUI, SUI, SUI>(&mut scenario, index, ts_ms);

        {
            let registry = test_environment::dov_registry(&scenario);
            let _result = tds_view_function::get_auction_bcs(&registry, vector[]);
            let _result = tds_view_function::get_auction_bcs(&registry, vector[0]);
            let _result = tds_view_function::get_auction_bcs(&registry, vector[1]);
            return_shared(registry);
        };
        next_tx(&mut scenario, ADMIN);

        end(scenario);
    }

}
