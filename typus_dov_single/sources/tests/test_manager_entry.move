#[test_only]
module typus_dov::test_manager_entry {
    use sui::clock::{Self, Clock};
    use sui::coin::Coin;
    use sui::sui::SUI;
    use sui::test_scenario::{Scenario, ctx, sender, next_tx, take_shared, return_shared};
    use typus_dov::tds_authorized_entry;
    use typus_dov::tds_registry_authorized_entry;
    use typus_dov::test_environment::{Self, current_ts_ms};
    use pyth::price_info::PriceInfoObject;

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

    public(package) fun test_close_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::close<D_TOKEN, B_TOKEN>(&mut registry, index, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_resume_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::resume<D_TOKEN, B_TOKEN>(&mut registry, index, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_drop_vault_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::drop_vault<D_TOKEN, B_TOKEN>(&mut registry, index, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_terminate_vault_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::terminate_vault<D_TOKEN, B_TOKEN>(&mut registry, index, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_incentivise_<TOKEN>(
        scenario: &mut Scenario,
        amount: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let incentive_coin = test_environment::mint_test_coin<TOKEN>(scenario, amount);
        tds_registry_authorized_entry::incentivise<TOKEN>(&mut registry, incentive_coin, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    // set I_INFO_CURRENT_LENDING_PROTOCOL
    public(package) fun test_set_current_lending_protocol_flag_(
        scenario: &mut Scenario,
        index: u64,
        lending_protocol: u64, // 0: none, 1: scallop spool, 2: scallop, 3: suilend, 4: navi, 5: alphalend
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::set_current_lending_protocol_flag(&mut registry, index, lending_protocol, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_set_safu_vault_index_(
        scenario: &mut Scenario,
        index: u64,
        safu_index: u64, // set as 999 -> for off-chain preventing vault evolution
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::set_safu_vault_index(&mut registry, index, safu_index, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    // set I_CONFIG_NEXT_LENDING_PROTOCOL
    public(package) fun test_set_lending_protocol_flag_(
        scenario: &mut Scenario,
        index: u64,
        lending_protocol: u64, // 0: none, 1: scallop spool, 2: scallop, 3: suilend, 4: navi, 5: alphalend
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::set_lending_protocol_flag(&mut registry, index, lending_protocol, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_add_portfolio_vault_authorized_user_(
        scenario: &mut Scenario,
        index: u64,
        users: vector<address>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::add_portfolio_vault_authorized_user(&mut registry, index, users, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_remove_portfolio_vault_authorized_user_(
        scenario: &mut Scenario,
        index: u64,
        users: vector<address>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::remove_portfolio_vault_authorized_user(&mut registry, index, users, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_deposit_navi_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        asset_id: u8,
        ts_ms: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut storage = take_shared<lending_core::storage::Storage>(scenario);
        let mut pool = take_shared<lending_core::pool::Pool<D_TOKEN>>(scenario);
        let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
        let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);

        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        tds_authorized_entry::deposit_navi<D_TOKEN, B_TOKEN>(
            &mut registry,
            index,
            &mut storage,
            &mut pool,
            asset_id,
            &mut incentive_v2,
            &mut incentive_v3,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(storage);
        return_shared(pool);
        return_shared(incentive_v2);
        return_shared(incentive_v3);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_reward_navi_<D_TOKEN, B_TOKEN, R_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        ts_ms: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut storage = take_shared<lending_core::storage::Storage>(scenario);
        let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);
        let mut reward_fund = take_shared<lending_core::incentive_v3::RewardFund<R_TOKEN>>(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        let coin_types = vector[];
        let rule_ids = vector[];

        let reward_balance = tds_authorized_entry::pre_reward_navi<D_TOKEN, B_TOKEN, R_TOKEN>(
            &mut registry,
            index,
            &mut storage,
            &mut reward_fund,
            coin_types,
            rule_ids,
            &mut incentive_v3,
            &clock,
            ctx(scenario)
        );

        tds_authorized_entry::post_reward_navi<D_TOKEN, B_TOKEN, R_TOKEN>(
            &mut registry,
            index,
            vector[reward_balance],
            ctx(scenario)
        );

        return_shared(registry);
        return_shared(storage);
        return_shared(incentive_v3);
        return_shared(reward_fund);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_withdraw_navi_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        asset_id: u8,
        ts_ms: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut oracle_config = take_shared<oracle::config::OracleConfig>(scenario);
        let mut price_oracle = take_shared<oracle::oracle::PriceOracle>(scenario);
        let supra_oracle_holder = take_shared<SupraOracle::SupraSValueFeed::OracleHolder>(scenario);
        let pyth_price_info = take_shared<PriceInfoObject>(scenario);
        let feed_address = oracle::config::get_vec_feeds(&oracle_config)[asset_id as u64];
        let mut storage = take_shared<lending_core::storage::Storage>(scenario);
        let mut pool = take_shared<lending_core::pool::Pool<D_TOKEN>>(scenario);
        let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
        let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);

        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        tds_authorized_entry::withdraw_navi<D_TOKEN, B_TOKEN>(
            &mut registry,
            index,
            &mut oracle_config,
            &mut price_oracle,
            &supra_oracle_holder,
            &pyth_price_info,
            feed_address,
            &mut storage,
            &mut pool,
            asset_id,
            &mut incentive_v2,
            &mut incentive_v3,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(oracle_config);
        return_shared(price_oracle);
        return_shared(supra_oracle_holder);
        return_shared(pyth_price_info);
        return_shared(storage);
        return_shared(pool);
        return_shared(incentive_v2);
        return_shared(incentive_v3);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }
}