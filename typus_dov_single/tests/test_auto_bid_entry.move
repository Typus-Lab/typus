#[test_only]
module typus_dov::test_auto_bid_entry {
    use sui::test_scenario::{Scenario, ctx, sender, next_tx, return_shared};

    use typus_dov::auto_bid;
    use typus_dov::test_environment;

    const ADMIN: address = @0xFFFF;

    public(package) fun test_add_authority_(scenario: &mut Scenario, new_authority: address) {
        let registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        auto_bid::add_authority(&registry, &mut strategy_pool, new_authority, ctx(scenario));
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }
    public(package) fun test_new_strategy_vault_(scenario: &mut Scenario, dov_index: u64) {
        let registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        auto_bid::new_strategy_vault(&registry, &mut strategy_pool, dov_index, ctx(scenario));
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_remove_strategy_vault_(scenario: &mut Scenario, dov_index: u64) {
        let registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        auto_bid::remove_strategy_vault(&registry, &mut strategy_pool, dov_index, ctx(scenario));
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_new_strategy_signal_(scenario: &mut Scenario, dov_index: u64, signal_index: u64) {
        let registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        auto_bid::new_strategy_signal(&registry, &mut strategy_pool, dov_index, signal_index, ctx(scenario));
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_new_strategy_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        dov_index: u64,
        signal_index: u64,
        size: u64,
        price_percentage: u64,
        max_times: u64,
        target_rounds: vector<u64>,
        deposit_premium_amount: u64,
    ) {
        let registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        let coin = test_environment::mint_test_coin<B_TOKEN>(scenario, deposit_premium_amount);
        auto_bid::new_strategy_v3<D_TOKEN, B_TOKEN>(
            &registry,
            &mut strategy_pool,
            dov_index,
            signal_index,
            size,
            price_percentage,
            max_times,
            target_rounds,
            coin,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_update_strategy_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        dov_index: u64,
        signal_index: u64,
        strategy_index: u64,
        size: Option<u64>,
        price_percentage: Option<u64>,
        max_times: Option<u64>,
        target_rounds: vector<u64>,
        deposit_premium_amount: u64,
    ) {
        let registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        let coin = test_environment::mint_test_coin<B_TOKEN>(scenario, deposit_premium_amount);
        auto_bid::update_strategy_v3<D_TOKEN, B_TOKEN>(
            &registry,
            &mut strategy_pool,
            dov_index,
            signal_index,
            strategy_index,
            size,
            price_percentage,
            max_times,
            target_rounds,
            vector[coin],
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_close_strategy_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        dov_index: u64,
        signal_index: u64,
        strategy_index: u64,
    ) {
        let registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        let (d_token, b_token) = auto_bid::close_strategy_v3<D_TOKEN, B_TOKEN>(
            &registry,
            &mut strategy_pool,
            dov_index,
            signal_index,
            strategy_index,
            ctx(scenario)
        );
        transfer::public_transfer(d_token, sender(scenario));
        transfer::public_transfer(b_token, sender(scenario));
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_withdraw_bid_receipt_(
        scenario: &mut Scenario,
        dov_index: u64,
        signal_index: u64,
        strategy_index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        let bid_receipt = auto_bid::withdraw_bid_receipt_v3(
            &mut registry,
            &mut strategy_pool,
            dov_index,
            signal_index,
            strategy_index,
            ctx(scenario)
        );
        transfer::public_transfer(bid_receipt, sender(scenario));
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_withdraw_profit_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        dov_index: u64,
        signal_index: u64,
        strategy_index: u64,
    ) {
        let registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        let profit_coin = auto_bid::withdraw_profit_v3<D_TOKEN, B_TOKEN>(
            &registry,
            &mut strategy_pool,
            dov_index,
            signal_index,
            strategy_index,
            ctx(scenario)
        );
        transfer::public_transfer(profit_coin, sender(scenario));
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_new_bid_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        dov_index: u64,
        signal_index: u64,
        update_ts_ms: u64,
    ) {
        let typus_ecosystem_version = test_environment::ecosystem_version(scenario);
        let mut typus_user_registry = test_environment::typus_user_registry(scenario);
        let mut tgld_registry = test_environment::tgld_registry(scenario);
        let mut typus_leaderboard_registry = test_environment::leaderboard_registry(scenario);
        let mut registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, update_ts_ms);
        auto_bid::new_bid<D_TOKEN, B_TOKEN>(
            &typus_ecosystem_version,
            &mut typus_user_registry,
            &mut tgld_registry,
            &mut typus_leaderboard_registry,
            &mut registry,
            &mut strategy_pool,
            dov_index,
            signal_index,
            &clock,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(strategy_pool);
        return_shared(typus_ecosystem_version);
        return_shared(typus_user_registry);
        return_shared(tgld_registry);
        return_shared(typus_leaderboard_registry);
        clock.destroy_for_testing();
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_exercise_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        dov_index: u64,
        signal_index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        auto_bid::exercise<D_TOKEN, B_TOKEN>(
            &mut registry,
            &mut strategy_pool,
            dov_index,
            signal_index,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_exercise_single_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        dov_index: u64,
        signal_index: u64,
        strategy_index: u64,
    ) {
        let mut registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        auto_bid::exercise_single<D_TOKEN, B_TOKEN>(
            &mut registry,
            &mut strategy_pool,
            dov_index,
            signal_index,
            strategy_index,
            ctx(scenario)
        );
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_close_strategy_vault_<D_TOKEN, B_TOKEN>(scenario: &mut Scenario, dov_index: u64) {
        let registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        auto_bid::close_strategy_vault<D_TOKEN, B_TOKEN>(&registry, &mut strategy_pool, dov_index, ctx(scenario));
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_view_user_strategies_(scenario: &mut Scenario, user: address): vector<vector<u8>> {
        let registry = test_environment::dov_registry(scenario);
        let mut strategy_pool = test_environment::strategy_pool_v3(scenario);
        let result = auto_bid::view_user_strategies(&registry, &mut strategy_pool, user);
        return_shared(registry);
        return_shared(strategy_pool);
        next_tx(scenario, ADMIN);
        result
    }
}