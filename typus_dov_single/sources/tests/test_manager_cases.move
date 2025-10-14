#[test_only]
module typus_dov::test_manager_cases {
    use sui::object;
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
        test_environment::prepare_scallop_lending_env(&mut scenario);
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
        let mut activate_ts_ms = current_ts_ms() / 86400_000 * 86400_000;

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

        let ts_ms = activate_ts_ms + 300_000;
        let oracle_price = 101000_0000_0000;
        test_manager_entry::test_update_strike_(&mut scenario, index, sui_oracle_id, oracle_price, ts_ms);

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

        // round 2
        test_manager_entry::test_set_lending_protocol_flag_(&mut scenario, index, 2);
        test_manager_entry::test_set_current_lending_protocol_flag_(&mut scenario, index, 2);
        test_manager_entry::test_enable_additional_lending_<BABE, BABE>(&mut scenario, index);
        test_manager_entry::test_disable_additional_lending_<BABE, BABE>(&mut scenario, index);

        // activate
        activate_ts_ms = activate_ts_ms + 86400_000;
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

        test_manager_entry::test_deposit_scallop_basic_lending_<BABE, BABE>(&mut scenario, index, ts_ms);

        // update auction delay
        test_manager_entry::test_update_config_(
            &mut scenario,
            0,
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::some(120_000), // auction delay
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
        );

        test_manager_entry::test_new_auction_<BABE, BABE>(&mut scenario, index);
        test_manager_entry::test_update_auction_config_(
            &mut scenario,
            0,
            activate_ts_ms + 1,
            activate_ts_ms + 240_000,
            1,
            0_1000_00000,
            0_0800_00000,
            1000,
            0,
            9, // bid token
            9, // deposit token / contract size
            false,
            ts_ms,
        );

        let premium = 9_2000_00000; // 100 * 0.0834 => 8.333, 8.33 * 1.1 = 9.1633
        let bid_ts_ms = activate_ts_ms + 200_000;
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

        let ts_ms = activate_ts_ms + 600_000; // delay deivery -> ok
        test_manager_entry::test_delivery_<BABE, BABE, BABE>(&mut scenario, index, ts_ms);

        // otc
        let ts_ms = activate_ts_ms + 1000_000;
        test_manager_entry::test_otc_<BABE, BABE>(
            &mut scenario,
            index,
            1_0000_00000,
            10_0000_00000,
            10_0000_00000,
            1_0000_00000,
            0,
            0,
            0,
            ts_ms
        );

        // safu otc
        let (delivery_price, premium) = (1_0000_00000, 1_0000_00000);
        test_manager_entry::test_safu_otc_v2_<BABE, BABE>(&mut scenario, index, delivery_price, premium, ts_ms);

        let ts_ms = activate_ts_ms + 86300_000;
        let (delivery_price, premium) = (0_0100_00000, 1000_0000_00000); // this may trigger otc size capped
        test_manager_entry::test_safu_otc_v2_<BABE, BABE>(&mut scenario, index, delivery_price, premium, ts_ms);

        let ts_ms = activate_ts_ms + 86400_000;
        test_manager_entry::test_withdraw_scallop_basic_lending_<BABE, BABE>(&mut scenario, index, ts_ms);

        let ts_ms = activate_ts_ms + 86400_000;
        test_manager_entry::test_recoup_<BABE, BABE>(&mut scenario, index, ts_ms);

        // safu otc after recoup -> nothing happened
        let (delivery_price, premium) = (1_0000_00000, 0);
        test_manager_entry::test_safu_otc_v2_<BABE, BABE>(&mut scenario, index, delivery_price, premium, ts_ms);

        // settle
        let ts_ms = activate_ts_ms + 86400_000;
        let oracle_price = 120000_0000_0000;
        test_manager_entry::test_settle_<BABE, BABE>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        // round 3
        // activate
        activate_ts_ms = activate_ts_ms + 86400_000;
        let ts_ms = activate_ts_ms;
        let oracle_price = 120000_0000_0000;
        test_manager_entry::test_activate_<BABE, BABE, BABE>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        // test_manager_entry::test_new_auction_<BABE, BABE>(&mut scenario, index);
        // test_manager_entry::test_terminate_auction_<BABE, BABE>(&mut scenario, index);

        let ts_ms = activate_ts_ms + 86400_000;
        test_manager_entry::test_skip_<BABE, BABE>(&mut scenario, index, ts_ms);

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

    #[test]
    public(package) fun test_update_config() {
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

        let index = 0;

        test_manager_entry::test_update_config_(
            &mut scenario,
            0,
            option::some(object::id_to_address(&sui_oracle_id)),
            option::some(1_0000_00000),
            option::some(1_0000_00000),
            option::some(10_0000_00000),
            option::some(10_0000_00000),
            option::some(9999),
            option::some(9999),
            option::some(0),
            option::none(),
            option::some(option::some(vector[])),
            option::some(800),
            option::some(15),
            option::some(1500),
            option::some(0),
            option::some(360_000),
            option::some(86400_000),
            option::some(800000_0000_00000),
            option::some(100),
            option::some(2),
            option::some(0),
            option::some(0),
        );

        test_manager_entry::test_update_config_(
            &mut scenario,
            0,
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
        );

        test_manager_entry::test_update_oracle_(&mut scenario, index, sui_oracle_id);

        test_manager_entry::test_update_warmup_vault_config_(
            &mut scenario,
            index,
            vector[10100],// strike_pct: vector<u64>,
            vector[1],// weight: vector<u64>,
            vector[false],// is_buyer: vector<bool>,
            0_0001_0000,// strike_increment: u64,
            1,// decay_speed: u64,
            0_1000_00000,// initial_price: u64,
            0_0500_00000,// final_price: u64,
        );

        end(scenario);
    }
}
