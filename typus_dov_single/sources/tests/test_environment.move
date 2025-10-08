#[test_only]
module typus_dov::test_environment {
    use std::type_name;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Scenario, begin, end, ctx, sender, next_tx, take_shared, return_shared, take_from_sender, return_to_sender, take_shared_by_id, take_from_address};
    use typus_dov::typus_dov_single::{Self, Registry as DovRegistry};
    use typus::ecosystem::{Self, Version as TypusEcosystemVersion};
    use typus::leaderboard::{Self, TypusLeaderboardRegistry};
    use typus::user::{Self, TypusUserRegistry};
    use typus_oracle::oracle::{Self, Oracle, ManagerCap as OracleManagerCap};

    const ADMIN: address = @0xFFFF;
    const CURRENT_TS_MS: u64 = 1_715_212_800_000;
    const SUI_PRICE: u64 = 100000_0000_0000;
    public struct USD has drop {}
    public struct USDC has drop {}

    public(package) fun new_dov_registry(scenario: &mut Scenario) {
        typus_dov_single::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_typus_user_registry(scenario: &mut Scenario) {
        user::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_leaderboard_registry(scenario: &mut Scenario) {
        leaderboard::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_version(scenario: &mut Scenario) {
        ecosystem::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_clock(scenario: &mut Scenario): Clock {
        let mut clock = clock::create_for_testing(ctx(scenario));
        clock::set_for_testing(&mut clock, CURRENT_TS_MS);
        clock
    }

    public(package) fun update_clock(clock: &mut Clock, ts_ms: u64) {
        clock::set_for_testing(clock, ts_ms);
    }

    public(package) fun init_oracle(scenario: &mut Scenario) {
        oracle::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    public(package) fun new_oracle<TOKEN>(scenario: &mut Scenario): ID {
        let manager_cap = oracle_manager_cap(scenario);
        oracle::new_oracle<TOKEN, USD>(
            &manager_cap,
            type_name::with_defining_ids<TOKEN>().into_string(),
            std::ascii::string(b"USD"),
            8,
            ctx(scenario)
        );
        next_tx(scenario, ADMIN);
        let mut oracle = take_shared<Oracle>(scenario); // most recent shared object
        let id = object::id(&oracle);
        let clock = new_clock(scenario);
        oracle::update(
            &mut oracle,
            &manager_cap,
            SUI_PRICE,
            SUI_PRICE,
            &clock,
            ctx(scenario)
        );
        return_shared(oracle);
        clock.destroy_for_testing();
        return_to_sender(scenario, manager_cap);
        next_tx(scenario, ADMIN);
        id
    }

    public(package) fun update_oracle(scenario: &mut Scenario, oracle: &mut Oracle, new_price: u64, ts_ms: u64) {
        let mut clock = new_clock(scenario);
        let manager_cap = oracle_manager_cap(scenario);
        update_clock(&mut clock, ts_ms);
        oracle::update(
            oracle,
            &manager_cap,
            new_price,
            new_price,
            &clock,
            ctx(scenario)
        );
        clock.destroy_for_testing();
        return_to_sender(scenario, manager_cap);
        next_tx(scenario, ADMIN);
    }

    public(package) fun mint_test_coin<T>(scenario: &mut Scenario, amount: u64): Coin<T> {
        coin::mint_for_testing<T>(amount, ctx(scenario))
    }

    public(package) fun dov_registry(scenario: &Scenario): DovRegistry {
        take_shared<DovRegistry>(scenario)
    }

    public(package) fun typus_user_registry(scenario: &Scenario): TypusUserRegistry {
        take_shared<TypusUserRegistry>(scenario)
    }

    public(package) fun leaderboard_registry(scenario: &Scenario): TypusLeaderboardRegistry {
        take_shared<TypusLeaderboardRegistry>(scenario)
    }

    public(package) fun ecosystem_version(scenario: &Scenario): TypusEcosystemVersion {
        take_shared<TypusEcosystemVersion>(scenario)
    }

    public(package) fun oracle(scenario: &Scenario, id: ID): Oracle {
        take_shared_by_id<Oracle>(scenario, id)
    }

    public(package) fun oracle_manager_cap(scenario: &Scenario): OracleManagerCap {
        take_from_sender<OracleManagerCap>(scenario)
    }

    public(package) fun current_ts_ms(): u64 { return CURRENT_TS_MS }

    public(package) fun begin_test(): Scenario {
        let mut scenario = begin(ADMIN);
        new_dov_registry(&mut scenario);

        // create deposit snapshot
        let mut dov_registry = dov_registry(&mut scenario);
        typus_dov_single::create_deposit_snapshots_additional_config(&mut dov_registry, ctx(&mut scenario));
        next_tx(&mut scenario, ADMIN);

        new_version(&mut scenario);
        next_tx(&mut scenario, ADMIN);

        // issue ecosystem manager cap into typus_dov_single
        let ecosystem_version = ecosystem_version(&mut scenario);
        typus_dov_single::test_issue_ecosystem_manager_cap(&mut dov_registry, &ecosystem_version, ctx(&mut scenario));
        next_tx(&mut scenario, ADMIN);

        new_typus_user_registry(&mut scenario);
        new_leaderboard_registry(&mut scenario);
        init_oracle(&mut scenario);

        return_shared(dov_registry);
        return_shared(ecosystem_version);
        scenario
    }
}

