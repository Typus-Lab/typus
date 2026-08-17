/// The `competition` module defines the logic for trading competitions.
module typus_perp::competition {
    use sui::clock::Clock;
    use std::ascii::String;

    use typus::tails_staking::{Self, TailsStakingRegistry};
    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::leaderboard::TypusLeaderboardRegistry;
    use typus_perp::admin::{Self, Version};
    use typus_perp::error;
    use typus_perp::math;

    public struct CompetitionConfig has key {
        id: UID,
        /// The boost in basis points for each staking level.
        boost_bp: vector<u64>, // idx = max level, value = boost_bp (decimal = 4)
        /// Whether the competition is active.
        is_active: bool,
        /// The name of the program.
        program_name: String,
        /// Padding for future use.
        u64_padding: vector<u64>
    }

    // Due to the package size, we changed it to a test_only function
    entry fun new_competition_config(
        version: &Version,
        boost_bp: vector<u64>,
        program_name: String,
        ctx: &mut TxContext
    ) {
        // safety check
        version.verify(ctx);
        assert!(boost_bp.length() == 8, error::invalid_boost_bp_array_length());
        let competition_config = CompetitionConfig {
            id: object::new(ctx),
            boost_bp,
            is_active: true,
            program_name,
            u64_padding: vector::empty()
        };
        transfer::share_object(competition_config);
    }

    entry fun set_boost_bp(
        version: &Version,
        competition_config: &mut CompetitionConfig,
        boost_bp: vector<u64>,
        ctx: &TxContext
    ) {
        // safety check
        version.verify(ctx);
        assert!(boost_bp.length() == 8, error::invalid_boost_bp_array_length());
        assert!(competition_config.is_active, error::invalid_boost_bp_array_length());
        competition_config.boost_bp = boost_bp;
    }

    /// Adds a score to the competition leaderboard.
    /// WARNING: no authority check inside
    public(package) fun add_score(
        version: &Version,
        ecosystem_version: &TypusEcosystemVersion,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        tails_staking_registry: &TailsStakingRegistry,
        competition_config: &CompetitionConfig,
        volume_usd: u64,
        user: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        version.version_check();
        let leaderboard_key = competition_config.program_name;
        let max_level = tails_staking::get_max_staking_level(ecosystem_version, tails_staking_registry, user);
        let boost_bp = if (competition_config.is_active) {
            competition_config.boost_bp[max_level]
        } else {
            0
        };

        let score = ((volume_usd as u128) * (boost_bp as u128) / (math::get_bp_scale() as u128) as u64);
        if (score > 0) {
            admin::add_competition_leaderboard(
                version,
                ecosystem_version,
                typus_leaderboard_registry,
                leaderboard_key,
                user,
                score,
                clock,
                ctx,
            );
        };
    }

    #[test_only]
    entry fun suspend_competition_config(
        version: &Version,
        competition_config: &mut CompetitionConfig,
        ctx: &TxContext
    ) {
        version.verify(ctx);
        if (competition_config.is_active) {
            competition_config.is_active = false;
        };
    }
}