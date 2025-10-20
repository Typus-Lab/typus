#[test_only]
module typus_perp::test_competition {
    use sui::test_scenario::{Scenario, end, ctx, take_shared, return_shared};
    use sui::clock::{Self, Clock};

    use typus_perp::test_trading;
    use typus_perp::admin::Version;
    use typus_perp::competition::{Self, CompetitionConfig};

    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::leaderboard::TypusLeaderboardRegistry;
    use typus::tails_staking::TailsStakingRegistry;

    const ADMIN: address = @0xFFFF;
    const CURRENT_TS_MS: u64 = 1_715_212_800_000;

    fun new_clock(scenario: &mut Scenario): Clock {
        let mut clock = clock::create_for_testing(ctx(scenario));
        clock::set_for_testing(&mut clock, CURRENT_TS_MS);
        clock
    }

    fun version(scenario: &Scenario): Version {
        take_shared<Version>(scenario)
    }

    fun ecosystem_version(scenario: &Scenario): TypusEcosystemVersion {
        take_shared<TypusEcosystemVersion>(scenario)
    }

    fun leaderboard_registry(scenario: &Scenario): TypusLeaderboardRegistry {
        take_shared<TypusLeaderboardRegistry>(scenario)
    }

    fun tails_staking_registry(scenario: &Scenario): TailsStakingRegistry {
        take_shared<TailsStakingRegistry>(scenario)
    }

    fun competition_config(scenario: &Scenario): CompetitionConfig {
        take_shared<CompetitionConfig>(scenario)
    }

    #[test]
    public(package) fun test_competition_() {
        let mut scenario = test_trading::begin_test();
        let version = version(&scenario);
        let ecosystem_version = ecosystem_version(&scenario);
        let mut typus_leaderboard_registry = leaderboard_registry(&scenario);
        let tails_staking_registry = tails_staking_registry(&scenario);
        let mut competition_config = competition_config(&scenario);
        let clock = new_clock(&mut scenario);

        // score = 0 => nothing happened
        let volume_usd = 1;
        competition::add_score(
            &version,
            &ecosystem_version,
            &mut typus_leaderboard_registry,
            &tails_staking_registry,
            &competition_config,
            volume_usd,
            ADMIN,
            &clock,
            ctx(&mut scenario)
        );

        // score > 0 => add score
        let volume_usd = 10000;
        competition::add_score(
            &version,
            &ecosystem_version,
            &mut typus_leaderboard_registry,
            &tails_staking_registry,
            &competition_config,
            volume_usd,
            ADMIN,
            &clock,
            ctx(&mut scenario)
        );

        competition::suspend_competition_config(&version, &mut competition_config, ctx(&mut scenario));

        // config inactive => score = 0 => add score
        let volume_usd = 10000;
        competition::add_score(
            &version,
            &ecosystem_version,
            &mut typus_leaderboard_registry,
            &tails_staking_registry,
            &competition_config,
            volume_usd,
            ADMIN,
            &clock,
            ctx(&mut scenario)
        );

        return_shared(version);
        return_shared(ecosystem_version);
        return_shared(typus_leaderboard_registry);
        return_shared(tails_staking_registry);
        return_shared(competition_config);
        clock.destroy_for_testing();

        end(scenario);
    }
}