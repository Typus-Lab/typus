#[test_only]
module typus_dov::test_otc_cases {
    use sui::test_scenario::{end, sender, next_tx, return_shared};

    use typus_dov::test_environment::{Self, current_ts_ms};
    use typus_dov::test_tds_user_entry;
    use typus_dov::test_manager_entry;
    use typus_dov::test_otc_entry;
    use typus_dov::tds_otc_entry;
    use typus_dov::babe::BABE;

    const ADMIN: address = @0xFFFF;
    const BABE1: address = @0xBABE1;
    const BABE2: address = @0xBABE2;

    public struct WITNESS_1 has drop {}
    public struct WITNESS_2 has drop {}

    #[test]
    public(package) fun test_otc_process() {
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

        // set protocol flag = 2 (scallop basic lending)
        // test_manager_entry::test_set_lending_protocol_flag_(&mut scenario, 0, 2);
        test_manager_entry::test_set_safu_vault_index_(&mut scenario, 0, 999); // nothing happened
        test_manager_entry::test_add_portfolio_vault_authorized_user_(&mut scenario, 0, vector[BABE1, BABE2]);
        test_manager_entry::test_remove_portfolio_vault_authorized_user_(&mut scenario, 0, vector[BABE2]);

        let index = 0;
        test_manager_entry::test_set_available_incentive_amount_(&mut scenario, index, 999999_0000_00000);
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

        // test_manager_entry::test_deposit_navi_<BABE, BABE>(&mut scenario, index, 0, ts_ms);
        // test_manager_entry::test_deposit_scallop_basic_lending_<BABE, BABE>(&mut scenario, 0, ts_ms);

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

        {
            let mut registry = test_environment::dov_registry(&scenario);
            let result = tds_otc_entry::get_user_otc_configs(&mut registry, BABE1, vector[0]);
            assert!(result.length() == 0, 0);
            return_shared(registry);
        };

        // ADMIN set BABE1 as otc maker
        next_tx(&mut scenario, ADMIN);
        test_otc_entry::test_add_otc_config_(
            &mut scenario,
            BABE1,
            index,
            1, // round
            100_0000_00000, // size
            0_0100_00000, // price
            50, // fee bp
            ts_ms + 300_000, // ts_ms + 5 minutes
        );

        test_otc_entry::test_remove_otc_config_(&mut scenario, BABE1, index);

        test_otc_entry::test_add_otc_config_(
            &mut scenario,
            BABE1,
            index,
            1, // round
            600_0000_00000, // size
            0_0100_00000, // price
            50, // fee bp
            ts_ms + 300_000, // ts_ms + 5 minutes
        );

        // overwrite the previous config
        test_otc_entry::test_add_otc_config_(
            &mut scenario,
            BABE1,
            index,
            1, // round
            600_0000_00000, // size
            0_0080_00000, // price
            50, // fee bp
            ts_ms + 300_000, // ts_ms + 5 minutes
        );

        {
            let mut registry = test_environment::dov_registry(&scenario);
            let result = tds_otc_entry::get_user_otc_configs(&mut registry, BABE1, vector[0]);
            assert!(result.length() > 0, 0);
            let result = tds_otc_entry::get_user_otc_configs(&mut registry, BABE1, vector[]);
            assert!(result.length() == 0, 0);
            let result = tds_otc_entry::get_user_otc_configs(&mut registry, BABE2, vector[]);
            assert!(result.length() == 0, 0);
            return_shared(registry);
        };

        next_tx(&mut scenario, BABE1);
        let premium = 600_0000_00000 * 0_0100_00000 / 1_0000_00000;
        let fee = premium * 50 / 10000;
        let amount = premium + fee;
        test_otc_entry::test_otc_<BABE, BABE>( &mut scenario, index, amount, ts_ms + 300_000);


        end(scenario);
    }

    #[test]
    #[expected_failure]
    public(package) fun test_otc_invalid_user_error() {
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

        // set protocol flag = 2 (scallop basic lending)
        // test_manager_entry::test_set_lending_protocol_flag_(&mut scenario, 0, 2);
        test_manager_entry::test_set_safu_vault_index_(&mut scenario, 0, 999); // nothing happened
        test_manager_entry::test_add_portfolio_vault_authorized_user_(&mut scenario, 0, vector[BABE1, BABE2]);
        test_manager_entry::test_remove_portfolio_vault_authorized_user_(&mut scenario, 0, vector[BABE2]);

        let index = 0;
        test_manager_entry::test_set_available_incentive_amount_(&mut scenario, index, 999999_0000_00000);
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

        // test_manager_entry::test_deposit_navi_<BABE, BABE>(&mut scenario, index, 0, ts_ms);
        // test_manager_entry::test_deposit_scallop_basic_lending_<BABE, BABE>(&mut scenario, 0, ts_ms);

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

        {
            let mut registry = test_environment::dov_registry(&scenario);
            let result = tds_otc_entry::get_user_otc_configs(&mut registry, BABE1, vector[0]);
            assert!(result.length() == 0, 0);
            return_shared(registry);
        };

        // ADMIN set BABE1 as otc maker
        next_tx(&mut scenario, ADMIN);
        test_otc_entry::test_add_otc_config_(
            &mut scenario,
            BABE2,
            index,
            1, // round
            100_0000_00000, // size
            0_0100_00000, // price
            50, // fee bp
            ts_ms + 300_000, // ts_ms + 5 minutes
        );

        next_tx(&mut scenario, BABE1);
        let premium = 600_0000_00000 * 0_0100_00000 / 1_0000_00000;
        let fee = premium * 50 / 10000;
        let amount = premium + fee;
        test_otc_entry::test_otc_<BABE, BABE>( &mut scenario, index, amount, ts_ms + 300_000);


        end(scenario);
    }

    #[test]
    #[expected_failure]
    public(package) fun test_otc_invalid_index_error() {
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

        // set protocol flag = 2 (scallop basic lending)
        // test_manager_entry::test_set_lending_protocol_flag_(&mut scenario, 0, 2);
        test_manager_entry::test_set_safu_vault_index_(&mut scenario, 0, 999); // nothing happened
        test_manager_entry::test_add_portfolio_vault_authorized_user_(&mut scenario, 0, vector[BABE1, BABE2]);
        test_manager_entry::test_remove_portfolio_vault_authorized_user_(&mut scenario, 0, vector[BABE2]);

        let index = 0;
        test_manager_entry::test_set_available_incentive_amount_(&mut scenario, index, 999999_0000_00000);
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

        // test_manager_entry::test_deposit_navi_<BABE, BABE>(&mut scenario, index, 0, ts_ms);
        // test_manager_entry::test_deposit_scallop_basic_lending_<BABE, BABE>(&mut scenario, 0, ts_ms);

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

        {
            let mut registry = test_environment::dov_registry(&scenario);
            let result = tds_otc_entry::get_user_otc_configs(&mut registry, BABE1, vector[0]);
            assert!(result.length() == 0, 0);
            return_shared(registry);
        };

        // ADMIN set BABE1 as otc maker
        next_tx(&mut scenario, ADMIN);
        test_otc_entry::test_add_otc_config_(
            &mut scenario,
            BABE1,
            index,
            1, // round
            100_0000_00000, // size
            0_0100_00000, // price
            50, // fee bp
            ts_ms + 300_000, // ts_ms + 5 minutes
        );

        test_otc_entry::test_remove_otc_config_(&mut scenario, BABE1, index);

        next_tx(&mut scenario, BABE1);
        let premium = 600_0000_00000 * 0_0100_00000 / 1_0000_00000;
        let fee = premium * 50 / 10000;
        let amount = premium + fee;
        test_otc_entry::test_otc_<BABE, BABE>( &mut scenario, index, amount, ts_ms + 300_000);


        end(scenario);
    }

    #[test]
    #[expected_failure]
    public(package) fun test_otc_expired_error() {
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

        // set protocol flag = 2 (scallop basic lending)
        // test_manager_entry::test_set_lending_protocol_flag_(&mut scenario, 0, 2);
        test_manager_entry::test_set_safu_vault_index_(&mut scenario, 0, 999); // nothing happened
        test_manager_entry::test_add_portfolio_vault_authorized_user_(&mut scenario, 0, vector[BABE1, BABE2]);
        test_manager_entry::test_remove_portfolio_vault_authorized_user_(&mut scenario, 0, vector[BABE2]);

        let index = 0;
        test_manager_entry::test_set_available_incentive_amount_(&mut scenario, index, 999999_0000_00000);
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

        // test_manager_entry::test_deposit_navi_<BABE, BABE>(&mut scenario, index, 0, ts_ms);
        // test_manager_entry::test_deposit_scallop_basic_lending_<BABE, BABE>(&mut scenario, 0, ts_ms);

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

        {
            let mut registry = test_environment::dov_registry(&scenario);
            let result = tds_otc_entry::get_user_otc_configs(&mut registry, BABE1, vector[0]);
            assert!(result.length() == 0, 0);
            return_shared(registry);
        };

        // ADMIN set BABE1 as otc maker
        next_tx(&mut scenario, ADMIN);
        test_otc_entry::test_add_otc_config_(
            &mut scenario,
            BABE1,
            index,
            1, // round
            100_0000_00000, // size
            0_0100_00000, // price
            50, // fee bp
            ts_ms + 300_000, // ts_ms + 5 minutes
        );

        next_tx(&mut scenario, BABE1);
        let premium = 600_0000_00000 * 0_0100_00000 / 1_0000_00000;
        let fee = premium * 50 / 10000;
        let amount = premium + fee;
        test_otc_entry::test_otc_<BABE, BABE>( &mut scenario, index, amount, ts_ms + 1000_000);


        end(scenario);
    }
}
