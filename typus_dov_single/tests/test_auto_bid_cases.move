#[test_only]
module typus_dov::test_auto_bid_cases {
    use sui::test_scenario::{end, sender, next_tx};

    use typus_dov::test_environment::{Self, current_ts_ms};
    use typus_dov::test_tds_user_entry;
    use typus_dov::test_manager_entry;
    use typus_dov::test_auto_bid_entry;
    use typus_dov::babe::BABE;

    const ADMIN: address = @0xFFFF;
    const BABE1: address = @0xBABE1;
    const BABE2: address = @0xBABE2;
    const BABE3: address = @0xBABE3;

    public struct WITNESS_1 has drop {}
    public struct WITNESS_2 has drop {}

    #[test]
    public(package) fun test_general_operation() {
        let mut scenario = test_environment::begin_test();

        // prepare env
        // test_environment::prepare_navi_lending_env(&mut scenario);
        // test_environment::prepare_scallop_lending_env(&mut scenario);
        test_manager_entry::test_incentivise_<BABE>(&mut scenario, 10000_0000_00000);
        test_manager_entry::test_withdraw_incentive_<BABE>(&mut scenario, option::some(1_0000_00000));
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
        // test_manager_entry::test_set_lending_protocol_flag_(&mut scenario, 0, 4);
        test_manager_entry::test_set_safu_vault_index_(&mut scenario, 0, 999); // nothing happened

        let index = 0;
        test_manager_entry::test_set_available_incentive_amount_(&mut scenario, index, 999999_0000_00000);
        let mut activate_ts_ms = current_ts_ms() / 86400_000 * 86400_000;

        test_auto_bid_entry::test_new_strategy_vault_(&mut scenario, index);
        test_auto_bid_entry::test_remove_strategy_vault_(&mut scenario, index);
        test_auto_bid_entry::test_new_strategy_vault_(&mut scenario, index);

        test_auto_bid_entry::test_add_authority_(&mut scenario, ADMIN);
        test_auto_bid_entry::test_add_authority_(&mut scenario, BABE1);
        test_auto_bid_entry::test_add_authority_(&mut scenario, BABE2);
        test_auto_bid_entry::test_add_authority_(&mut scenario, BABE3);

        let signal_index = 0;
        test_auto_bid_entry::test_new_strategy_signal_(&mut scenario, index, signal_index);

        next_tx(&mut scenario, BABE1);
        let (size, price_percentage, max_times) = (100_0000_00000, 50, 10);
        let target_rounds = vector[1, 2, 3, 4, 5, 6, 7];
        let deposit_premium_amount = 100_0000_00000;
        test_auto_bid_entry::test_new_strategy_<BABE, BABE>(&mut scenario, index, signal_index, size, price_percentage, max_times, target_rounds, deposit_premium_amount);

        next_tx(&mut scenario, BABE2);
        let (size, price_percentage, max_times) = (100_0000_00000, 50, 10);
        let target_rounds = vector[1, 5, 6, 7];
        let deposit_premium_amount = 80_0000_00000;
        test_auto_bid_entry::test_new_strategy_<BABE, BABE>(&mut scenario, index, signal_index, size, price_percentage, max_times, target_rounds, deposit_premium_amount);

        next_tx(&mut scenario, BABE3);
        let (size, price_percentage, max_times) = (100_0000_00000, 75, 10);
        let target_rounds = vector[1];
        let deposit_premium_amount = 80_0000_00000;
        test_auto_bid_entry::test_new_strategy_<BABE, BABE>(&mut scenario, index, signal_index, size, price_percentage, max_times, target_rounds, deposit_premium_amount);

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

        // test_manager_entry::test_deposit_navi_<BABE, BABE>(&mut scenario, index, 0, ts_ms);

        test_manager_entry::test_new_auction_<BABE, BABE>(&mut scenario, index);

        let ts_ms = activate_ts_ms + 150_000; // at half of auction
        test_auto_bid_entry::test_new_bid_<BABE, BABE>(&mut scenario, index, signal_index, ts_ms);

        let ts_ms = activate_ts_ms + 225_000; // at 75% period of auction
        test_auto_bid_entry::test_new_bid_<BABE, BABE>(&mut scenario, index, signal_index, ts_ms);

        let ts_ms = activate_ts_ms + 300_000;
        test_manager_entry::test_delivery_<BABE, BABE, BABE>(&mut scenario, index, ts_ms);

        next_tx(&mut scenario, BABE3);
        test_auto_bid_entry::test_withdraw_bid_receipt_(&mut scenario, index, signal_index, 2);

        // next_tx(&mut scenario, BABE3);
        // test_auto_bid_entry::test_withdraw_bid_receipt_(&mut scenario, index, signal_index, 2);

        let ts_ms = activate_ts_ms + 300_000;
        let oracle_price = 101000_0000_0000;
        test_manager_entry::test_update_strike_(&mut scenario, index, sui_oracle_id, oracle_price, ts_ms);

        // let ts_ms = activate_ts_ms + 86400_000;
        // test_manager_entry::test_reward_navi_<BABE, BABE, SUI>(&mut scenario, index, ts_ms);
        // test_manager_entry::test_oracle_price_update_single_price_(&mut scenario, 0, ts_ms);
        // test_environment::navi_update_token_price(&mut scenario, 0, oracle_price as u256, ts_ms);
        // test_manager_entry::test_withdraw_navi_<BABE, BABE>(&mut scenario, index, 0, ts_ms);

        let ts_ms = activate_ts_ms + 86400_000;
        test_manager_entry::test_recoup_<BABE, BABE>(&mut scenario, index, ts_ms);

        // settle
        let ts_ms = activate_ts_ms + 86400_000;
        let oracle_price = 110000_0000_0000; // ITM
        test_manager_entry::test_settle_<BABE, BABE>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        // next round -> activate
        activate_ts_ms = activate_ts_ms + 86400_000;
        let ts_ms = activate_ts_ms;
        let oracle_price = 110000_0000_0000;
        test_manager_entry::test_activate_<BABE, BABE, BABE>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        // test_manager_entry::test_deposit_navi_<BABE, BABE>(&mut scenario, index, 0, ts_ms);

        test_manager_entry::test_new_auction_<BABE, BABE>(&mut scenario, index);

        let ts_ms = activate_ts_ms + 150_000; // at half of auction
        test_auto_bid_entry::test_new_bid_<BABE, BABE>(&mut scenario, index, signal_index, ts_ms);

        let ts_ms = activate_ts_ms + 300_000;
        test_manager_entry::test_delivery_<BABE, BABE, BABE>(&mut scenario, index, ts_ms);

        test_manager_entry::test_new_auction_<BABE, BABE>(&mut scenario, index);
        test_manager_entry::test_terminate_auction_<BABE, BABE>(&mut scenario, index);

        let result = test_auto_bid_entry::test_view_user_strategies_(&mut scenario, BABE1);
        assert!(result.length() > 0, 0);

        let strategy_index = 0;
        next_tx(&mut scenario, BABE1);
        test_auto_bid_entry::test_exercise_single_<BABE, BABE>(&mut scenario, index, signal_index, strategy_index);

        // duplicated exercise single -> no receipt -> nothing happened
        next_tx(&mut scenario, BABE1);
        test_auto_bid_entry::test_exercise_single_<BABE, BABE>(&mut scenario, index, signal_index, strategy_index);

        test_auto_bid_entry::test_exercise_<BABE, BABE>(&mut scenario, index, signal_index);
        // // duplicated exercise -> no receipt
        // -> panic at let bid_vault = typus_dov_single::get_mut_bid_vault_by_id(bid_vault_registry, &vid_exercisable);
        // test_auto_bid_entry::test_exercise_<BABE, BABE>(&mut scenario, index, signal_index);

        next_tx(&mut scenario, BABE2);
        test_auto_bid_entry::test_withdraw_profit_<BABE, BABE>(&mut scenario, index, signal_index, 1);

        next_tx(&mut scenario, BABE1);
        test_auto_bid_entry::test_close_strategy_<BABE, BABE>(&mut scenario, index, signal_index, 0);

        next_tx(&mut scenario, BABE2);
        test_auto_bid_entry::test_close_strategy_<BABE, BABE>(&mut scenario, index, signal_index, 1);

        // next_tx(&mut scenario, BABE2);
        test_auto_bid_entry::test_close_strategy_vault_<BABE, BABE>(&mut scenario, index);

        end(scenario);
    }

    #[test]
    public(package) fun test_update_config() {
        let mut scenario = test_environment::begin_test();

        // prepare env
        // test_environment::prepare_navi_lending_env(&mut scenario);
        // test_environment::prepare_scallop_lending_env(&mut scenario);
        test_manager_entry::test_incentivise_<BABE>(&mut scenario, 10000_0000_00000);
        test_manager_entry::test_withdraw_incentive_<BABE>(&mut scenario, option::some(1_0000_00000));
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

        let index = 0;
        test_auto_bid_entry::test_new_strategy_vault_(&mut scenario, index);

        let signal_index = 0;
        test_auto_bid_entry::test_new_strategy_signal_(&mut scenario, index, signal_index);

        next_tx(&mut scenario, BABE1);
        let (size, price_percentage, max_times) = (100_0000_00000, 50, 10);
        let target_rounds = vector[1, 2, 3, 4, 5, 6, 7];
        let deposit_premium_amount = 100_0000_00000;
        test_auto_bid_entry::test_new_strategy_<BABE, BABE>(&mut scenario, index, signal_index, size, price_percentage, max_times, target_rounds, deposit_premium_amount);

        next_tx(&mut scenario, BABE1);
        let strategy_index = 0;
        let (size, price_percentage, max_times) = (110_0000_00000, 50, 12);
        let deposit_premium_amount = 0;
        test_auto_bid_entry::test_update_strategy_<BABE, BABE>(
            &mut scenario,
            index,
            signal_index,
            strategy_index,
            option::some(size),
            option::some(price_percentage),
            option::some(max_times),
            target_rounds,
            deposit_premium_amount
        );

        next_tx(&mut scenario, BABE1);
        test_auto_bid_entry::test_update_strategy_<BABE, BABE>(
            &mut scenario,
            index,
            signal_index,
            strategy_index,
            option::none(),
            option::none(),
            option::none(),
            target_rounds,
            deposit_premium_amount
        );

        next_tx(&mut scenario, BABE1);
        test_auto_bid_entry::test_close_strategy_<BABE, BABE>(&mut scenario, index, signal_index, strategy_index);

        end(scenario);
    }
}
