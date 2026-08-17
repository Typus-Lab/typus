#[test_only]
module typus_dov::test_manager_entry {
    use sui::balance::Balance;
    use sui::test_scenario::{Scenario, ctx, sender, next_tx, take_shared, return_shared};
    use typus_dov::tds_authorized_entry;
    use typus_dov::tds_registry_authorized_entry;
    use typus_dov::test_environment;
    use pyth::price_info::PriceInfoObject;
    use typus::witness_lock::HotPotato;

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

    public(package) fun test_update_config_(
        scenario: &mut Scenario,
        index: u64,
        oracle_id: Option<address>,
        deposit_lot_size: Option<u64>,
        bid_lot_size: Option<u64>,
        min_deposit_size: Option<u64>,
        min_bid_size: Option<u64>,
        max_deposit_entry: Option<u64>,
        max_bid_entry: Option<u64>,
        deposit_fee_bp: Option<u64>,
        deposit_fee_share_bp: Option<u64>,
        deposit_shared_fee_pool: Option<Option<vector<u8>>>,
        bid_fee_bp: Option<u64>,
        deposit_incentive_bp: Option<u64>,
        bid_incentive_bp: Option<u64>,
        auction_delay_ts_ms: Option<u64>,
        auction_duration_ts_ms: Option<u64>,
        recoup_delay_ts_ms: Option<u64>,
        capacity: Option<u64>,
        leverage: Option<u64>,
        risk_level: Option<u64>,
        deposit_incentive_bp_divisor_decimal: Option<u64>,
        incentive_fee_bp: Option<u64>,
        shared_navi_amount: Option<u64>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);

        tds_authorized_entry::update_config(
            &mut registry,
            index,
            oracle_id,
            deposit_lot_size,
            bid_lot_size,
            min_deposit_size,
            min_bid_size,
            max_deposit_entry,
            max_bid_entry,
            deposit_fee_bp,
            deposit_fee_share_bp,
            deposit_shared_fee_pool,
            bid_fee_bp,
            deposit_incentive_bp,
            bid_incentive_bp,
            auction_delay_ts_ms,
            auction_duration_ts_ms,
            recoup_delay_ts_ms,
            capacity,
            leverage,
            risk_level,
            deposit_incentive_bp_divisor_decimal,
            incentive_fee_bp,
            shared_navi_amount,
            ctx(scenario)
        );

        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_update_oracle_(
        scenario: &mut Scenario,
        index: u64,
        oracle_id: ID,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let oracle = test_environment::oracle(scenario, oracle_id);
        tds_authorized_entry::update_oracle(&mut registry, index, &oracle, ctx(scenario));
        return_shared(oracle);
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_update_warmup_vault_config_(
        scenario: &mut Scenario,
        index: u64,
        strike_pct: vector<u64>,
        weight: vector<u64>,
        is_buyer: vector<bool>,
        strike_increment: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::update_warmup_vault_config(
            &mut registry,
            index,
            strike_pct,
            weight,
            is_buyer,
            strike_increment,
            decay_speed,
            initial_price,
            final_price,
            ctx(scenario),
        );
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    // ===== Vault evolution entries =====

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

    public(package) fun test_terminate_auction_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::terminate_auction<D_TOKEN, B_TOKEN>(
            &mut registry,
            index,
            ctx(scenario)
        );
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    // public(package) fun test_update_auction_config_(
    //     scenario: &mut Scenario,
    //     index: u64,
    //     start_ts_ms: u64,
    //     end_ts_ms: u64,
    //     decay_speed: u64,
    //     initial_price: u64,
    //     final_price: u64,
    //     fee_bp: u64,
    //     incentive_bp: u64,
    //     token_decimal: u64, // bid token
    //     size_decimal: u64, // deposit token / contract size
    //     able_to_remove_bid: bool,
    //     ts_ms: u64,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     let mut clock = test_environment::new_clock(scenario);
    //     test_environment::update_clock(&mut clock, ts_ms);
    //     tds_authorized_entry::update_auction_config(
    //         &mut registry,
    //         index,
    //         start_ts_ms,
    //         end_ts_ms,
    //         decay_speed,
    //         initial_price,
    //         final_price,
    //         fee_bp,
    //         incentive_bp,
    //         token_decimal,
    //         size_decimal,
    //         able_to_remove_bid,
    //         &clock,
    //         ctx(scenario),
    //     );
    //     return_shared(registry);
    //     clock.destroy_for_testing();
    //     next_tx(scenario, ADMIN);
    // }

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

    public(package) fun test_update_strike_(
        scenario: &mut Scenario,
        index: u64,
        oracle_id: ID,
        oracle_price: u64,
        ts_ms: u64
    ) {
        let mut registry = test_environment::dov_registry(scenario);

        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        let sender_address = sender(scenario);
        next_tx(scenario, ADMIN);
        let mut oracle = test_environment::oracle(scenario, oracle_id);
        test_environment::update_oracle(scenario, &mut oracle, oracle_price, ts_ms);
        next_tx(scenario, sender_address);

        tds_authorized_entry::update_strike(&mut registry, index, &oracle, &clock, ctx(scenario));
        return_shared(oracle);
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

    public(package) fun test_otc_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        delivery_price: u64,
        delivery_size: u64,
        bidder_bid_value: u64,
        bidder_fee_balance_value: u64,
        incentive_bid_value: u64,
        incentive_fee_balance_value: u64,
        depositor_incentive_value: u64,
        ts_ms: u64
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);
        let coin = test_environment::mint_test_coin<B_TOKEN>(scenario, bidder_bid_value + bidder_fee_balance_value);
        tds_authorized_entry::otc<D_TOKEN, B_TOKEN>(
            &mut registry,
            index,
            vector[coin],
            delivery_price,
            delivery_size,
            bidder_bid_value,
            bidder_fee_balance_value,
            incentive_bid_value,
            incentive_fee_balance_value,
            depositor_incentive_value,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_safu_otc_v2_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        delivery_price: u64,
        premium: u64,
        ts_ms: u64
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);
        let coin = test_environment::mint_test_coin<B_TOKEN>(scenario, premium);
        let (mut receipt_option, _log) = tds_authorized_entry::safu_otc_v2<D_TOKEN, B_TOKEN>(
            &mut registry,
            index,
            delivery_price,
            coin.into_balance(),
            &clock,
            ctx(scenario)
        );
        if (receipt_option.is_some()) {
            let receipt = receipt_option.extract();
            transfer::public_transfer(receipt, sender(scenario));
        };
        receipt_option.destroy_none();
        return_shared(registry);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_skip_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        ts_ms: u64
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);
        tds_authorized_entry::skip<D_TOKEN, B_TOKEN>(
            &mut registry,
            index,
            &clock,
            ctx(scenario)
        );
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

    public(package) fun test_fixed_incentivise_<D_TOKEN, B_TOKEN, I_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        amount: u64,
        amount_per_round: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let incentive_coin = test_environment::mint_test_coin<I_TOKEN>(scenario, amount);
        tds_authorized_entry::fixed_incentivise<D_TOKEN, B_TOKEN, I_TOKEN>(&mut registry, index, incentive_coin, amount_per_round, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_withdraw_fixed_incentive_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        amount: Option<u64>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::withdraw_fixed_incentive<TOKEN>(&mut registry, index, amount, ctx(scenario));
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

    public(package) fun test_withdraw_incentive_<TOKEN>(
        scenario: &mut Scenario,
        amount: Option<u64>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_registry_authorized_entry::withdraw_incentive<TOKEN>(&mut registry, amount, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_set_available_incentive_amount_(
        scenario: &mut Scenario,
        index: u64,
        amount: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_registry_authorized_entry::set_available_incentive_amount(&mut registry, index, amount, ctx(scenario));
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

    public(package) fun test_create_navi_account_cap_(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::create_navi_account_cap(&mut registry, index, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    // public(package) fun test_deposit_navi_<D_TOKEN, B_TOKEN>(
    //     scenario: &mut Scenario,
    //     index: u64,
    //     asset_id: u8,
    //     ts_ms: u64,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     let mut storage = take_shared<lending_core::storage::Storage>(scenario);
    //     let mut pool = take_shared<lending_core::pool::Pool<D_TOKEN>>(scenario);
    //     let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
    //     let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);

    //     let mut clock = test_environment::new_clock(scenario);
    //     test_environment::update_clock(&mut clock, ts_ms);

    //     tds_authorized_entry::deposit_navi<D_TOKEN, B_TOKEN>(
    //         &mut registry,
    //         index,
    //         &mut storage,
    //         &mut pool,
    //         asset_id,
    //         &mut incentive_v2,
    //         &mut incentive_v3,
    //         &clock,
    //         ctx(scenario)
    //     );
    //     return_shared(registry);
    //     return_shared(storage);
    //     return_shared(pool);
    //     return_shared(incentive_v2);
    //     return_shared(incentive_v3);
    //     clock.destroy_for_testing();
    //     next_tx(scenario, ADMIN);
    // }

    // public(package) fun test_reward_navi_<D_TOKEN, B_TOKEN, R_TOKEN>(
    //     scenario: &mut Scenario,
    //     index: u64,
    //     ts_ms: u64,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     let mut storage = take_shared<lending_core::storage::Storage>(scenario);
    //     let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);
    //     let mut reward_fund = take_shared<lending_core::incentive_v3::RewardFund<R_TOKEN>>(scenario);
    //     let mut clock = test_environment::new_clock(scenario);
    //     test_environment::update_clock(&mut clock, ts_ms);

    //     let coin_types = vector[];
    //     let rule_ids = vector[];

    //     let reward_balance = tds_authorized_entry::pre_reward_navi<D_TOKEN, B_TOKEN, R_TOKEN>(
    //         &mut registry,
    //         index,
    //         &mut storage,
    //         &mut reward_fund,
    //         coin_types,
    //         rule_ids,
    //         &mut incentive_v3,
    //         &clock,
    //         ctx(scenario)
    //     );

    //     tds_authorized_entry::post_reward_navi<D_TOKEN, B_TOKEN, R_TOKEN>(
    //         &mut registry,
    //         index,
    //         vector[reward_balance],
    //         ctx(scenario)
    //     );

    //     return_shared(registry);
    //     return_shared(storage);
    //     return_shared(incentive_v3);
    //     return_shared(reward_fund);
    //     clock.destroy_for_testing();
    //     next_tx(scenario, ADMIN);
    // }

    // public(package) fun test_withdraw_navi_<D_TOKEN, B_TOKEN>(
    //     scenario: &mut Scenario,
    //     index: u64,
    //     asset_id: u8,
    //     ts_ms: u64,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     let mut oracle_config = take_shared<oracle::config::OracleConfig>(scenario);
    //     let mut price_oracle = take_shared<oracle::oracle::PriceOracle>(scenario);
    //     let supra_oracle_holder = take_shared<SupraOracle::SupraSValueFeed::OracleHolder>(scenario);
    //     let pyth_price_info = take_shared<PriceInfoObject>(scenario);
    //     let feed_address = oracle::config::get_vec_feeds(&oracle_config)[asset_id as u64];
    //     let mut storage = take_shared<lending_core::storage::Storage>(scenario);
    //     let mut pool = take_shared<lending_core::pool::Pool<D_TOKEN>>(scenario);
    //     let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
    //     let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);

    //     let mut clock = test_environment::new_clock(scenario);
    //     test_environment::update_clock(&mut clock, ts_ms);

    //     tds_authorized_entry::withdraw_navi_v2<D_TOKEN, B_TOKEN>(
    //         &mut registry,
    //         index,
    //         &mut oracle_config,
    //         &mut price_oracle,
    //         &supra_oracle_holder,
    //         &pyth_price_info,
    //         feed_address,
    //         &mut storage,
    //         &mut pool,
    //         asset_id,
    //         &mut incentive_v2,
    //         &mut incentive_v3,
    //         &clock,
    //         ctx(scenario)
    //     );
    //     return_shared(registry);
    //     return_shared(oracle_config);
    //     return_shared(price_oracle);
    //     return_shared(supra_oracle_holder);
    //     return_shared(pyth_price_info);
    //     return_shared(storage);
    //     return_shared(pool);
    //     return_shared(incentive_v2);
    //     return_shared(incentive_v3);
    //     clock.destroy_for_testing();
    //     next_tx(scenario, ADMIN);
    // }

    public(package) fun test_oracle_price_update_single_price_(
        scenario: &mut Scenario,
        asset_id: u8,
        ts_ms: u64,
    ) {
        let mut oracle_config = take_shared<oracle::config::OracleConfig>(scenario);
        let mut price_oracle = take_shared<oracle::oracle::PriceOracle>(scenario);
        let supra_oracle_holder = take_shared<SupraOracle::SupraSValueFeed::OracleHolder>(scenario);
        let pyth_price_info = take_shared<PriceInfoObject>(scenario);
        let feed_address = oracle::config::get_vec_feeds(&oracle_config)[asset_id as u64];
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        oracle::oracle_pro::update_single_price(
            &clock,
            &mut oracle_config,
            &mut price_oracle,
            &supra_oracle_holder,
            &pyth_price_info,
            feed_address,
        );
        return_shared(oracle_config);
        return_shared(price_oracle);
        return_shared(supra_oracle_holder);
        return_shared(pyth_price_info);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    // public(package) fun test_borrow_navi_<TOKEN>(
    //     scenario: &mut Scenario,
    //     index: u64,
    //     deposit_dov_index: u64,
    //     asset_id: u8,
    //     amount: u64,
    //     ts_ms: u64,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     let mut oracle_config = take_shared<oracle::config::OracleConfig>(scenario);
    //     let mut price_oracle = take_shared<oracle::oracle::PriceOracle>(scenario);
    //     let supra_oracle_holder = take_shared<SupraOracle::SupraSValueFeed::OracleHolder>(scenario);
    //     let pyth_price_info = take_shared<PriceInfoObject>(scenario);
    //     let feed_address = oracle::config::get_vec_feeds(&oracle_config)[asset_id as u64];
    //     let mut storage = take_shared<lending_core::storage::Storage>(scenario);
    //     let mut pool = take_shared<lending_core::pool::Pool<TOKEN>>(scenario);
    //     let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
    //     let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);

    //     let mut clock = test_environment::new_clock(scenario);
    //     test_environment::update_clock(&mut clock, ts_ms);

    //     tds_authorized_entry::borrow_navi_v3<TOKEN>(
    //         &mut registry,
    //         index,
    //         deposit_dov_index,
    //         &mut oracle_config,
    //         &mut price_oracle,
    //         &supra_oracle_holder,
    //         &pyth_price_info,
    //         feed_address,
    //         &mut storage,
    //         &mut pool,
    //         asset_id,
    //         &mut incentive_v2,
    //         &mut incentive_v3,
    //         amount,
    //         &clock,
    //         ctx(scenario)
    //     );
    //     return_shared(registry);
    //     return_shared(oracle_config);
    //     return_shared(price_oracle);
    //     return_shared(supra_oracle_holder);
    //     return_shared(pyth_price_info);
    //     return_shared(storage);
    //     return_shared(pool);
    //     return_shared(incentive_v2);
    //     return_shared(incentive_v3);
    //     clock.destroy_for_testing();
    //     next_tx(scenario, ADMIN);
    // }

    public(package) fun test_unsubscribe_navi_<D_TOKEN, B_TOKEN, I_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        deposit_dov_index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);

        tds_authorized_entry::unsubscribe_navi<D_TOKEN, B_TOKEN, I_TOKEN>(
            &mut registry,
            index,
            deposit_dov_index,
            ctx(scenario)
        );
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_deposit_collateral_navi_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        asset_id: u8,
        amount: u64,
        ts_ms: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut storage = take_shared<lending_core::storage::Storage>(scenario);
        let mut pool = take_shared<lending_core::pool::Pool<TOKEN>>(scenario);
        let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
        let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        let coin = test_environment::mint_test_coin<TOKEN>(scenario, amount);

        tds_authorized_entry::deposit_collateral_navi<TOKEN>(
            &mut registry,
            index,
            &mut storage,
            &mut pool,
            asset_id,
            &mut incentive_v2,
            &mut incentive_v3,
            coin,
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

    public(package) fun test_withdraw_collateral_navi_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        asset_id: u8,
        amount: Option<u64>,
        ts_ms: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut oracle_config = take_shared<oracle::config::OracleConfig>(scenario);
        let mut price_oracle = take_shared<oracle::oracle::PriceOracle>(scenario);
        let supra_oracle_holder = take_shared<SupraOracle::SupraSValueFeed::OracleHolder>(scenario);
        let pyth_price_info = take_shared<PriceInfoObject>(scenario);
        let feed_address = oracle::config::get_vec_feeds(&oracle_config)[asset_id as u64];
        let mut storage = take_shared<lending_core::storage::Storage>(scenario);
        let mut pool = take_shared<lending_core::pool::Pool<TOKEN>>(scenario);
        let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
        let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        tds_authorized_entry::withdraw_collateral_navi<TOKEN>(
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
            amount,
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

    public(package) fun test_pre_repay_navi_interest_<D_TOKEN, B_TOKEN, I_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        deposit_dov_index: u64,
    ): (HotPotato<Balance<I_TOKEN>>, vector<u64>) {
        let ecosystem_version = test_environment::ecosystem_version(scenario);
        let mut registry = test_environment::dov_registry(scenario);

        let (hot_potato_balance, log) = tds_authorized_entry::pre_repay_navi_interest<D_TOKEN, B_TOKEN, I_TOKEN>(
            &ecosystem_version,
            &mut registry,
            index,
            deposit_dov_index,
            ctx(scenario)
        );
        return_shared(ecosystem_version);
        return_shared(registry);
        next_tx(scenario, ADMIN);
        (hot_potato_balance, log)
    }

    public(package) fun test_post_repay_navi_interest_<TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        asset_id: u8,
        hot_potato_balance: HotPotato<Balance<TOKEN>>,
        ts_ms: u64,
    ) {
        let ecosystem_version = test_environment::ecosystem_version(scenario);
        let mut registry = test_environment::dov_registry(scenario);
        let mut oracle_config = take_shared<oracle::config::OracleConfig>(scenario);
        let mut price_oracle = take_shared<oracle::oracle::PriceOracle>(scenario);
        let supra_oracle_holder = take_shared<SupraOracle::SupraSValueFeed::OracleHolder>(scenario);
        let pyth_price_info = take_shared<PriceInfoObject>(scenario);
        let feed_address = oracle::config::get_vec_feeds(&oracle_config)[asset_id as u64];
        let mut storage = take_shared<lending_core::storage::Storage>(scenario);
        let mut pool = take_shared<lending_core::pool::Pool<TOKEN>>(scenario);
        let mut incentive_v2 = take_shared<lending_core::incentive_v2::Incentive>(scenario);
        let mut incentive_v3 = take_shared<lending_core::incentive_v3::Incentive>(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);

        tds_authorized_entry::post_repay_navi_interest_<TOKEN>(
            &ecosystem_version,
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
            hot_potato_balance,
            &clock,
            ctx(scenario)
        );
        return_shared(ecosystem_version);
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

    // public(package) fun test_deposit_scallop_basic_lending_<D_TOKEN, B_TOKEN>(
    //     scenario: &mut Scenario,
    //     index: u64,
    //     ts_ms: u64,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     let scallop_version = protocol::version::create_for_testing(ctx(scenario));
    //     let mut scallop_market = take_shared<protocol::market::Market>(scenario);
    //     let mut clock = test_environment::new_clock(scenario);
    //     test_environment::update_clock(&mut clock, ts_ms);

    //     tds_authorized_entry::deposit_scallop_basic_lending<D_TOKEN, B_TOKEN>(
    //         &mut registry,
    //         index,
    //         &scallop_version,
    //         &mut scallop_market,
    //         &clock,
    //         ctx(scenario)
    //     );
    //     return_shared(registry);
    //     protocol::version::destroy_for_testing(scallop_version);
    //     return_shared(scallop_market);
    //     clock.destroy_for_testing();
    //     next_tx(scenario, ADMIN);
    // }

    // public(package) fun test_withdraw_scallop_basic_lending_<D_TOKEN, B_TOKEN>(
    //     scenario: &mut Scenario,
    //     index: u64,
    //     ts_ms: u64,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     let scallop_version = protocol::version::create_for_testing(ctx(scenario));
    //     let mut scallop_market = take_shared<protocol::market::Market>(scenario);
    //     let mut clock = test_environment::new_clock(scenario);
    //     test_environment::update_clock(&mut clock, ts_ms);

    //     tds_authorized_entry::withdraw_scallop_basic_lending<D_TOKEN, B_TOKEN>(
    //         &mut registry,
    //         index,
    //         &scallop_version,
    //         &mut scallop_market,
    //         &clock,
    //         ctx(scenario)
    //     );
    //     return_shared(registry);
    //     protocol::version::destroy_for_testing(scallop_version);
    //     return_shared(scallop_market);
    //     clock.destroy_for_testing();
    //     next_tx(scenario, ADMIN);
    // }

    public(package) fun test_enable_additional_lending_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::enable_additional_lending<D_TOKEN, B_TOKEN>(&mut registry, index, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_disable_additional_lending_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_authorized_entry::disable_additional_lending<D_TOKEN, B_TOKEN>(&mut registry, index, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_add_authorized_user_(
        scenario: &mut Scenario,
        users: vector<address>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_registry_authorized_entry::add_authorized_user(&mut registry, users, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_remove_authorized_user_(
        scenario: &mut Scenario,
        users: vector<address>,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_registry_authorized_entry::remove_authorized_user(&mut registry, users, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_add_witness_<W: drop>(
        scenario: &mut Scenario,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_registry_authorized_entry::add_witness<W>(&mut registry, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_remove_witness_<W: drop>(
        scenario: &mut Scenario,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_registry_authorized_entry::remove_witness<W>(&mut registry, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    // cannot be tested due to C_VERSION editing is not available in the test environment
    // public(package) fun test_upgrade_registry_(
    //     scenario: &mut Scenario,
    // ) {
    //     let mut registry = test_environment::dov_registry(scenario);
    //     tds_registry_authorized_entry::upgrade_registry(&mut registry, ctx(scenario));
    //     return_shared(registry);
    //     next_tx(scenario, ADMIN);
    // }

    public(package) fun test_suspend_transaction_(
        scenario: &mut Scenario,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_registry_authorized_entry::suspend_transaction(&mut registry, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_resume_transaction_(
        scenario: &mut Scenario,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        tds_registry_authorized_entry::resume_transaction(&mut registry, ctx(scenario));
        return_shared(registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_update_deposit_point_(
        scenario: &mut Scenario,
        users: vector<address>,
        ts_ms: u64,
    ) {
        let ecosystem_version = test_environment::ecosystem_version(scenario);
        let mut typus_user_registry = test_environment::typus_user_registry(scenario);
        let mut leaderboard_registry = test_environment::leaderboard_registry(scenario);
        let mut registry = test_environment::dov_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);
        tds_registry_authorized_entry::update_deposit_point(
            &ecosystem_version,
            &mut typus_user_registry,
            &mut leaderboard_registry,
            &mut registry,
            users,
            &clock,
            ctx(scenario),
        );

        return_shared(registry);
        return_shared(typus_user_registry);
        return_shared(leaderboard_registry);
        return_shared(ecosystem_version);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }
}