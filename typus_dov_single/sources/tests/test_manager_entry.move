#[test_only]
module typus_dov::test_manager_entry {
    use sui::clock::{Self, Clock};
    use sui::sui::SUI;
    use sui::test_scenario::{Scenario, begin, end, ctx, sender, next_tx, take_shared, return_shared, take_from_sender, return_to_sender, take_shared_by_id, take_from_address};
    use typus_dov::tds_registry_authorized_entry;
    use typus_dov::tds_authorized_entry;
    use typus_dov::test_environment::{Self, USDC, current_ts_ms};
    use typus_dov::test_tds_user_entry;

    const ADMIN: address = @0xFFFF;

    public(package) fun test_new_portfolio_vault_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        option_type: u64,
        period: u8,
        d_token_decimal: u64,
        b_token_decimal: u64,
        o_token_decimal: u64,
        activation_ts_ms: u64,
        expiration_ts_ms: u64,
        oracle_id: ID,
        oracle_price: u64,
        deposit_lot_size: u64,
        bid_lot_size: u64,
        min_deposit_size: u64,
        min_bid_size: u64,
        max_deposit_entry: u64,
        max_bid_entry: u64,
        deposit_fee_bp: u64,
        bid_fee_bp: u64,
        deposit_incentive_bp: u64,
        bid_incentive_bp: u64,
        auction_delay_ts_ms: u64,
        auction_duration_ts_ms: u64,
        recoup_delay_ts_ms: u64,
        capacity: u64,
        leverage: u64,
        risk_level: u64,
        has_next: bool,
        strike_bp: vector<u64>,
        weight: vector<u64>,
        is_buyer: vector<bool>,
        strike_increment: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
        whitelist: vector<address>,
        ts_ms: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);

        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        let mut oracle = test_environment::oracle(scenario, oracle_id);
        let sender_address = sender(scenario);
        next_tx(scenario, ADMIN);
        test_environment::update_oracle(scenario, &mut oracle, oracle_price, ts_ms);
        next_tx(scenario, sender_address);

        tds_registry_authorized_entry::new_portfolio_vault<D_TOKEN, B_TOKEN>(
            &mut registry,
            option_type,
            period,
            d_token_decimal,
            b_token_decimal,
            o_token_decimal,
            activation_ts_ms,
            expiration_ts_ms,
            &oracle,
            deposit_lot_size,
            bid_lot_size,
            min_deposit_size,
            min_bid_size,
            max_deposit_entry,
            max_bid_entry,
            deposit_fee_bp,
            bid_fee_bp,
            deposit_incentive_bp,
            bid_incentive_bp,
            auction_delay_ts_ms,
            auction_duration_ts_ms,
            recoup_delay_ts_ms,
            capacity,
            leverage,
            risk_level,
            has_next,
            strike_bp,
            weight,
            is_buyer,
            strike_increment,
            decay_speed,
            initial_price,
            final_price,
            whitelist,
            &clock,
            ctx(scenario)
        );

        return_shared(registry);
        return_shared(oracle);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_activate_<D_TOKEN, B_TOKEN, I_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        oracle_id: ID,
        d_token_order_id: ID,
        oracle_price: u64,
        d_oracle_price: u64,
        ts_ms: u64
    ) {
        let mut registry = test_environment::dov_registry(scenario);

        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        if (oracle_id == d_token_order_id) {
            let sender_address = sender(scenario);
            next_tx(scenario, ADMIN);
            let mut oracle = test_environment::oracle(scenario, oracle_id);
            test_environment::update_oracle(scenario, &mut oracle, oracle_price, ts_ms);
            next_tx(scenario, sender_address);
            tds_authorized_entry::activate<D_TOKEN, B_TOKEN, I_TOKEN>(
                &mut registry,
                index,
                &oracle,
                &oracle,
                &clock,
                ctx(scenario)
            );
            return_shared(oracle);
        } else {
            let mut oracle = test_environment::oracle(scenario, oracle_id);
            let mut d_oracle = test_environment::oracle(scenario, d_token_order_id);
            let sender_address = sender(scenario);
            next_tx(scenario, ADMIN);
            test_environment::update_oracle(scenario, &mut oracle, oracle_price, ts_ms);
            test_environment::update_oracle(scenario, &mut d_oracle, d_oracle_price, ts_ms);
            next_tx(scenario, sender_address);
            tds_authorized_entry::activate<D_TOKEN, B_TOKEN, I_TOKEN>(
                &mut registry,
                index,
                &oracle,
                &d_oracle,
                &clock,
                ctx(scenario)
            );
            return_shared(oracle);
            return_shared(d_oracle);
        };
        return_shared(registry);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_new_auction_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::new_auction<D_TOKEN, B_TOKEN>(
            &mut registry,
            index,
            option::none(),
            option::none(),
            ctx(scenario)
        );
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_delivery_<D_TOKEN, B_TOKEN, I_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        ts_ms: u64
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);
        tds_authorized_entry::delivery<D_TOKEN, B_TOKEN, I_TOKEN>(
            &mut registry,
            index,
            false,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_recoup_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        ts_ms: u64
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);
        tds_authorized_entry::recoup<D_TOKEN, B_TOKEN>(
            &mut registry,
            index,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_settle_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        oracle_id: ID,
        d_token_order_id: ID,
        oracle_price: u64,
        d_oracle_price: u64,
        ts_ms: u64
    ) {
        let mut registry = test_environment::dov_registry(scenario);

        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        if (oracle_id == d_token_order_id) {
            let sender_address = sender(scenario);
            next_tx(scenario, ADMIN);
            let mut oracle = test_environment::oracle(scenario, oracle_id);
            test_environment::update_oracle(scenario, &mut oracle, oracle_price, ts_ms);
            next_tx(scenario, sender_address);
            tds_authorized_entry::settle<D_TOKEN, B_TOKEN>(
                &mut registry,
                index,
                &oracle,
                &oracle,
                &clock,
                ctx(scenario)
            );
            return_shared(oracle);
        } else {
            let mut oracle = test_environment::oracle(scenario, oracle_id);
            let mut d_oracle = test_environment::oracle(scenario, d_token_order_id);
            let sender_address = sender(scenario);
            next_tx(scenario, ADMIN);
            test_environment::update_oracle(scenario, &mut oracle, oracle_price, ts_ms);
            test_environment::update_oracle(scenario, &mut d_oracle, d_oracle_price, ts_ms);
            next_tx(scenario, sender_address);
            tds_authorized_entry::settle<D_TOKEN, B_TOKEN>(
                &mut registry,
                index,
                &oracle,
                &d_oracle,
                &clock,
                ctx(scenario)
            );
            return_shared(oracle);
            return_shared(d_oracle);
        };
        return_shared(registry);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    #[test]
    public(package) fun test_new_portfolio_vault() {
        let mut scenario = test_environment::begin_test();
        let sui_oracle_id = test_environment::new_oracle<SUI>(&mut scenario);

        // create daily call
        test_new_portfolio_vault_<SUI, SUI>(
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
        test_new_portfolio_vault_<USDC, SUI>(
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
        let sui_oracle_id = test_environment::new_oracle<SUI>(&mut scenario);

        // create daily call
        test_new_portfolio_vault_<SUI, SUI>(
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

        let index = 0;
        let activate_ts_ms = current_ts_ms() / 86400_000 * 86400_000;

        // deposit
        let ts_ms = activate_ts_ms;
        let deposit_amount = 1000_0000_00000;
        let receipt = test_tds_user_entry::test_deposit_<SUI, SUI>(&mut scenario, index, vector[], deposit_amount, ts_ms);
        transfer::public_transfer(receipt, sender(&mut scenario));

        // activate
        let ts_ms = activate_ts_ms;
        let oracle_price = 100000_0000_0000;
        test_activate_<SUI, SUI, SUI>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        test_new_auction_<SUI, SUI>(&mut scenario, index);

        let ts_ms = activate_ts_ms + 300_000;
        test_delivery_<SUI, SUI, SUI>(&mut scenario, index, ts_ms);

        let ts_ms = activate_ts_ms + 86400_000;
        test_recoup_<SUI, SUI>(&mut scenario, index, ts_ms);

        // settle
        let ts_ms = activate_ts_ms + 86400_000;
        let oracle_price = 100000_0000_0000;
        test_settle_<SUI, SUI>(
            &mut scenario,
            index,
            sui_oracle_id,
            sui_oracle_id,
            oracle_price,
            oracle_price,
            ts_ms,
        );

        end(scenario);

    }
}