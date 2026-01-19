#[test_only]
module typus_dov::test_tds_witness_entry {
    use sui::test_scenario::{end, sender, return_shared, ctx};

    use typus_dov::test_environment::{Self, current_ts_ms};
    use typus_dov::test_tds_user_entry;
    use typus_dov::test_manager_entry;
    use typus_dov::tds_witness_entry::{Self, WITNESS};
    use typus_dov::babe::BABE;
    use typus::witness_lock;
    use std::type_name;
    use sui::balance;

    const ADMIN: address = @0xFFFF;

    public struct CAP has key, store {
        id: UID,
    }

    public struct W has drop {}

    #[test]
    public(package) fun test_tds_witness_entry() {
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

        test_manager_entry::test_set_lending_protocol_flag_(&mut scenario, 0, 5);

        let index = 0;
        test_manager_entry::test_set_available_incentive_amount_(&mut scenario, index, 999999_0000_00000);
        let activate_ts_ms = current_ts_ms() / 86400_000 * 86400_000;

        // deposit
        let ts_ms = activate_ts_ms;
        let deposit_amount = 1000_0000_00000;
        let receipt = test_tds_user_entry::test_public_raise_fund_<BABE, BABE>(&mut scenario, index, vector[], deposit_amount, false, false, ts_ms);
        transfer::public_transfer(receipt, sender(&scenario));

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
        test_manager_entry::test_new_auction_<BABE, BABE>(&mut scenario, index);

        let mut registry = test_environment::dov_registry(&scenario);
        let ecosystem_version = test_environment::ecosystem_version(&scenario);
        tds_witness_entry::add_lending_account_cap(
            &mut registry,
            0,
            5,
            CAP { id: object::new(ctx(&mut scenario)) },
            ctx(&mut scenario),
        );
        let (mut cap, hp) = tds_witness_entry::borrow_lending_account_cap<CAP>(
            &ecosystem_version,
            &mut registry,
            0,
            5,
            ctx(&mut scenario),
        );
        witness_lock::update_witness_for_testing(&mut cap, std::string::from_ascii(type_name::with_defining_ids<WITNESS>().into_string()));
        tds_witness_entry::return_lending_account_cap(
            &ecosystem_version,
            &mut registry,
            0,
            cap,
            hp,
            ctx(&mut scenario),
        );
        let mut balance = tds_witness_entry::withdraw_for_lending<BABE, BABE>(
            &ecosystem_version,
            &mut registry,
            0,
            5,
            ctx(&mut scenario),
        );
        witness_lock::update_witness_for_testing(&mut balance, std::string::from_ascii(type_name::with_defining_ids<WITNESS>().into_string()));
        tds_witness_entry::deposit_from_lending<BABE, BABE>(
            &ecosystem_version,
            &mut registry,
            0,
            5,
            balance,
            balance::zero(),
            ctx(&mut scenario),
        );

        return_shared(registry);
        return_shared(ecosystem_version);
        end(scenario);
    }

    #[test]
    #[expected_failure]
    #[allow(deprecated_usage)]
    fun test_remove_nft_extension_abort() {
        let mut scenario = test_environment::begin_test();
        let mut registry = test_environment::dov_registry(&scenario);
        let clock = test_environment::new_clock(&mut scenario);
        let (receipt_opt, balance_opt, _) = tds_witness_entry::otc<W, BABE, BABE>(
            W {},
            vector[],
            &mut registry,
            0,
            0,
            0,
            balance::zero(),
            0,
            &clock,
            ctx(&mut scenario),
        );
        receipt_opt.destroy_none();
        balance_opt.destroy_none();
        return_shared(registry);
        clock.destroy_for_testing();
        end(scenario);
    }

    #[test]
    #[expected_failure]
    public(package) fun test_tds_witness_entry_invalid_witness_error() {
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

        test_manager_entry::test_set_lending_protocol_flag_(&mut scenario, 0, 5);

        let index = 0;
        test_manager_entry::test_set_available_incentive_amount_(&mut scenario, index, 999999_0000_00000);
        let activate_ts_ms = current_ts_ms() / 86400_000 * 86400_000;

        // deposit
        let ts_ms = activate_ts_ms;
        let deposit_amount = 1000_0000_00000;
        let receipt = test_tds_user_entry::test_public_raise_fund_<BABE, BABE>(&mut scenario, index, vector[], deposit_amount, false, false, ts_ms);
        transfer::public_transfer(receipt, sender(&scenario));

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
        test_manager_entry::test_new_auction_<BABE, BABE>(&mut scenario, index);

        let mut registry = test_environment::dov_registry(&scenario);
        let ecosystem_version = test_environment::ecosystem_version(&scenario);
        tds_witness_entry::add_lending_account_cap(
            &mut registry,
            0,
            5,
            CAP { id: object::new(ctx(&mut scenario)) },
            ctx(&mut scenario),
        );
        let (mut cap, hp) = tds_witness_entry::borrow_lending_account_cap<CAP>(
            &ecosystem_version,
            &mut registry,
            0,
            999,
            ctx(&mut scenario),
        );
        witness_lock::update_witness_for_testing(&mut cap, std::string::from_ascii(type_name::with_defining_ids<WITNESS>().into_string()));
        tds_witness_entry::return_lending_account_cap(
            &ecosystem_version,
            &mut registry,
            0,
            cap,
            hp,
            ctx(&mut scenario),
        );

        return_shared(registry);
        return_shared(ecosystem_version);
        end(scenario);
    }
}