#[test_only]
module typus_dov::test_tds_user_entry {
    use sui::test_scenario::{Scenario, begin, end, ctx, sender, next_tx, take_shared, return_shared, take_from_sender, return_to_sender, take_shared_by_id, take_from_address};
    use typus_dov::tds_user_entry;
    use typus_dov::test_environment;
    use typus_framework::vault::TypusDepositReceipt;

    const ADMIN: address = @0xFFFF;

    public(package) fun test_deposit_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        amount: u64,
        ts_ms: u64,
    ): TypusDepositReceipt {
        let mut dov_registry = test_environment::dov_registry(scenario);
        let mut typus_user_registry = test_environment::typus_user_registry(scenario);
        let mut leaderboard_registry = test_environment::leaderboard_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);
        let ecosystem_version = test_environment::ecosystem_version(scenario);
        let deposit_coin = test_environment::mint_test_coin<D_TOKEN>(scenario, amount);
        let (deposit_receipt, _log) = tds_user_entry::public_raise_fund<D_TOKEN, B_TOKEN>(
            &ecosystem_version,
            &mut typus_user_registry,
            &mut leaderboard_registry,
            &mut dov_registry,
            index,
            receipts,
            deposit_coin.into_balance(),
            false,
            false,
            &clock,
            ctx(scenario)
        );

        return_shared(dov_registry);
        return_shared(typus_user_registry);
        return_shared(leaderboard_registry);
        return_shared(ecosystem_version);
        clock.destroy_for_testing();

        next_tx(scenario, ADMIN);
        deposit_receipt
    }
}

