#[test_only]
module typus_dov::test_fee_pool_cases {
    use sui::test_scenario::{Scenario, end, sender, next_tx};

    use typus_dov::test_environment::{Self, current_ts_ms};
    use typus_dov::test_fee_pool_entry;
    use typus_dov::test_manager_entry;
    use typus_dov::test_tds_user_entry;
    use typus_dov::babe::BABE;
    use typus_dov::babe2::BABE2;

    const ADMIN: address = @0xFFFF;
    const USER1: address = @0xBABE1;
    const USER2: address = @0xBABE2;

    public(package) fun begin_test(): Scenario {
        let mut scenario = test_environment::begin_test();
        let babe_oracle_id = test_environment::new_oracle<BABE>(&mut scenario);
        let babe2_oracle_id = test_environment::new_oracle<BABE2>(&mut scenario);
        test_manager_entry::test_incentivise_<BABE>(&mut scenario, 10000_0000_00000);
        test_manager_entry::test_incentivise_<BABE2>(&mut scenario, 10000_0000_00000);

        // create BABE daily call
        test_manager_entry::test_new_portfolio_vault_<BABE, BABE>(
            &mut scenario,
            0, // option type
            0, // period
            9, 9, 9, // d b o decimal
            current_ts_ms() / 86400_000 * 86400_000, // activation ts ms
            current_ts_ms() / 86400_000 * 86400_000 + 86400_000, // expiration ts ms
            babe_oracle_id, 100000_0000_0000, // oracle id, price
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
        let receipt = test_tds_user_entry::test_public_raise_fund_<BABE, BABE>(&mut scenario, index, vector[], deposit_amount, false, false, ts_ms);
        transfer::public_transfer(receipt, sender(&scenario));

        // activate
        let ts_ms = activate_ts_ms;
        let oracle_price = 100000_0000_0000;
        test_manager_entry::test_activate_<BABE, BABE, BABE>(
            &mut scenario,
            index,
            babe_oracle_id,
            babe_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

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

        // create BABE2 daily call
        test_manager_entry::test_new_portfolio_vault_<BABE2, BABE2>(
            &mut scenario,
            0, // option type
            0, // period
            9, 9, 9, // d b o decimal
            current_ts_ms() / 86400_000 * 86400_000, // activation ts ms
            current_ts_ms() / 86400_000 * 86400_000 + 86400_000, // expiration ts ms
            babe2_oracle_id, 100000_0000_0000, // oracle id, price
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
        let index = 1;
        let activate_ts_ms = current_ts_ms() / 86400_000 * 86400_000;
        // deposit
        let ts_ms = activate_ts_ms;
        let deposit_amount = 1000_0000_00000;
        let receipt = test_tds_user_entry::test_public_raise_fund_<BABE2, BABE2>(&mut scenario, index, vector[], deposit_amount, false, false, ts_ms);
        transfer::public_transfer(receipt, sender(&scenario));

        // activate
        let ts_ms = activate_ts_ms;
        let oracle_price = 100000_0000_0000;
        test_manager_entry::test_activate_<BABE2, BABE2, BABE2>(
            &mut scenario,
            index,
            babe2_oracle_id,
            babe2_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        test_manager_entry::test_new_auction_<BABE2, BABE2>(&mut scenario, index);

        let premium = 2_0000_00000; // 100 * 0.0167 => rebate ~ 0.164
        let bid_ts_ms = activate_ts_ms + 100_000;
        let (bid_receipt, rebate_coin) = test_tds_user_entry::test_public_bid_<BABE2, BABE2>(
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
        test_manager_entry::test_delivery_<BABE2, BABE2, BABE2>(&mut scenario, index, ts_ms);
        next_tx(&mut scenario, ADMIN);
        scenario
    }

    #[test]
    public(package) fun test_fee_pool() {
        let mut scenario = begin_test();

        test_fee_pool_entry::test_add_fee_pool_authorized_user_(&mut scenario, vector[USER1, USER2]);
        test_fee_pool_entry::test_add_fee_pool_authorized_user_(&mut scenario, vector[]); // nothing happened
        test_fee_pool_entry::test_remove_fee_pool_authorized_user_(&mut scenario, vector[USER1]);
        test_fee_pool_entry::test_remove_fee_pool_authorized_user_(&mut scenario, vector[]); // nothing happened

        test_fee_pool_entry::test_take_fee_<BABE>(&mut scenario, option::some(100));
        test_fee_pool_entry::test_take_fee_<BABE2>(&mut scenario, option::some(100));
        test_fee_pool_entry::test_send_fee_<BABE2>(&mut scenario, option::none());
        test_fee_pool_entry::test_take_fee_<BABE>(&mut scenario, option::none());

        end(scenario);
    }
}
