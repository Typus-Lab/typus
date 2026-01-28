#[test_only]
module typus_dov::test_tds_user_entry {
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{Scenario, ctx, sender, next_tx, return_shared};
    use typus_dov::tds_user_entry;
    use typus_dov::test_environment;
    use typus_framework::vault::{TypusDepositReceipt, TypusBidReceipt};

    const ADMIN: address = @0xFFFF;

    public(package) fun test_public_raise_fund_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        amount: u64,
        raise_from_premium: bool,
        raise_from_inactive: bool,
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
            raise_from_premium,
            raise_from_inactive,
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

    public(package) fun test_public_bid_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        premium_amount: u64,
        size: u64,
        ts_ms: u64,
    ): (TypusBidReceipt, Coin<B_TOKEN>) {
        let mut dov_registry = test_environment::dov_registry(scenario);
        let mut typus_user_registry = test_environment::typus_user_registry(scenario);
        let mut tgld_registry = test_environment::tgld_registry(scenario);
        let mut leaderboard_registry = test_environment::leaderboard_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);
        let ecosystem_version = test_environment::ecosystem_version(scenario);
        let premium_coin = test_environment::mint_test_coin<B_TOKEN>(scenario, premium_amount);
        let (bid_receipt, rebate_coin, _log) = tds_user_entry::public_bid<D_TOKEN, B_TOKEN>(
            &ecosystem_version,
            &mut typus_user_registry,
            &mut tgld_registry,
            &mut leaderboard_registry,
            &mut dov_registry,
            index,
            vector[premium_coin],
            size,
            &clock,
            ctx(scenario)
        );

        return_shared(dov_registry);
        return_shared(typus_user_registry);
        return_shared(tgld_registry);
        return_shared(leaderboard_registry);
        return_shared(ecosystem_version);
        clock.destroy_for_testing();

        next_tx(scenario, ADMIN);
        (bid_receipt, rebate_coin)
    }

    public(package) fun test_public_reduce_fund_<D_TOKEN, B_TOKEN, I_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        reduce_from_warmup: u64, // amount
        reduce_from_active: u64,  // amount
        reduce_from_premium: bool,
        reduce_from_inactive: bool,
        reduce_from_incentive: bool,
        ts_ms: u64,
    ) {
        let mut dov_registry = test_environment::dov_registry(scenario);
        let mut typus_user_registry = test_environment::typus_user_registry(scenario);
        let mut leaderboard_registry = test_environment::leaderboard_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);
        let ecosystem_version = test_environment::ecosystem_version(scenario);

        let (mut deposit_receipt_option, d_balance, b_balance, i_balance, _log) = tds_user_entry::public_reduce_fund<D_TOKEN, B_TOKEN, I_TOKEN>(
            &ecosystem_version,
            &mut typus_user_registry,
            &mut leaderboard_registry,
            &mut dov_registry,
            index,
            receipts,
            reduce_from_warmup,
            reduce_from_active,
            reduce_from_premium,
            reduce_from_inactive,
            reduce_from_incentive,
            &clock,
            ctx(scenario)
        );

        transfer::public_transfer(coin::from_balance(d_balance, ctx(scenario)), sender(scenario));
        transfer::public_transfer(coin::from_balance(b_balance, ctx(scenario)), sender(scenario));
        transfer::public_transfer(coin::from_balance(i_balance, ctx(scenario)), sender(scenario));

        if (deposit_receipt_option.is_some()) {
            let deposit_receipt = deposit_receipt_option.extract();
            transfer::public_transfer(deposit_receipt, sender(scenario));
        };

        deposit_receipt_option.destroy_none();

        return_shared(dov_registry);
        return_shared(typus_user_registry);
        return_shared(leaderboard_registry);
        return_shared(ecosystem_version);
        clock.destroy_for_testing();

        next_tx(scenario, ADMIN);
    }

    public(package) fun test_rebate_<TOKEN>(
        scenario: &mut Scenario,
    ) {
        let mut dov_registry = test_environment::dov_registry(scenario);

        let (balance, _log) = tds_user_entry::rebate<TOKEN>(
            &mut dov_registry,
            ctx(scenario),
        );
        if (balance.is_some()) {
            transfer::public_transfer(coin::from_balance(balance.destroy_some(), ctx(scenario)), sender(scenario));
        } else {
            balance.destroy_none();
        };

        return_shared(dov_registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_exercise_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        receipts: vector<TypusBidReceipt>,
    ): u64 {
        let mut dov_registry = test_environment::dov_registry(scenario);
        let (balance, _log) = tds_user_entry::exercise<D_TOKEN, B_TOKEN>(
            &mut dov_registry,
            index,
            receipts,
            ctx(scenario)
        );
        let value = balance.value();
        transfer::public_transfer(coin::from_balance(balance, ctx(scenario)), sender(scenario));
        return_shared(dov_registry);
        next_tx(scenario, ADMIN);
        value
    }

    public(package) fun test_public_refresh_deposit_snapshot_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
        ts_ms: u64,
    ) {
        let mut dov_registry = test_environment::dov_registry(scenario);
        let mut typus_user_registry = test_environment::typus_user_registry(scenario);
        let mut leaderboard_registry = test_environment::leaderboard_registry(scenario);
        let mut clock = test_environment::new_clock(scenario);
        test_environment::update_clock(&mut clock, ts_ms);
        let ecosystem_version = test_environment::ecosystem_version(scenario);

        let (receipt, _log) = tds_user_entry::public_refresh_deposit_snapshot<D_TOKEN, B_TOKEN>(
            &ecosystem_version,
            &mut typus_user_registry,
            &mut leaderboard_registry,
            &mut dov_registry,
            index,
            receipts,
            &clock,
            ctx(scenario)
        );

        transfer::public_transfer(receipt, sender(scenario));

        return_shared(dov_registry);
        return_shared(typus_user_registry);
        return_shared(leaderboard_registry);
        return_shared(ecosystem_version);
        clock.destroy_for_testing();

        next_tx(scenario, ADMIN);
    }

    public(package) fun test_transfer_bid_receipt_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        receipts: vector<TypusBidReceipt>,
        share: Option<u64>,
        recipient: address,
    ) {
        let mut dov_registry = test_environment::dov_registry(scenario);
        tds_user_entry::transfer_bid_receipt<D_TOKEN, B_TOKEN>(
            &mut dov_registry,
            index,
            receipts,
            share,
            recipient,
            ctx(scenario)
        );
        return_shared(dov_registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_public_transfer_bid_receipt_<D_TOKEN, B_TOKEN>(
        scenario: &mut Scenario,
        index: u64,
        receipts: vector<TypusBidReceipt>,
        share: Option<u64>,
        recipient: address,
    ) {
        let mut dov_registry = test_environment::dov_registry(scenario);
        let (mut my_receipt_option, _log) = tds_user_entry::public_transfer_bid_receipt<D_TOKEN, B_TOKEN>(
            &mut dov_registry,
            index,
            receipts,
            share,
            recipient,
            ctx(scenario)
        );

        if (my_receipt_option.is_some()) {
            let bid_receipt = my_receipt_option.extract();
            transfer::public_transfer(bid_receipt, sender(scenario));
        };
        my_receipt_option.destroy_none();

        return_shared(dov_registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_split_deposit_receipt_v2_(
        scenario: &mut Scenario,
        index: u64,
        receipt: TypusDepositReceipt,
        split_active_share: u64,
        split_warmup_share: u64,
    ) {
        let mut dov_registry = test_environment::dov_registry(scenario);
        let (mut receipt_0_option, mut receipt_1_option) = tds_user_entry::split_deposit_receipt_v2(
            &mut dov_registry,
            index,
            receipt,
            split_active_share,
            split_warmup_share,
            ctx(scenario)
        );

        if (receipt_0_option.is_some()) {
            let recepit_0 = receipt_0_option.extract();
            transfer::public_transfer(recepit_0, sender(scenario));
        };
        receipt_0_option.destroy_none();
        if (receipt_1_option.is_some()) {
            let recepit_1 = receipt_1_option.extract();
            transfer::public_transfer(recepit_1, sender(scenario));
        };
        receipt_1_option.destroy_none();

        return_shared(dov_registry);
        next_tx(scenario, ADMIN);
    }

    public(package) fun test_merge_deposit_receipts_(
        scenario: &mut Scenario,
        index: u64,
        receipts: vector<TypusDepositReceipt>,
    ) {
        let mut dov_registry = test_environment::dov_registry(scenario);
        let (receipt, _log) = tds_user_entry::merge_deposit_receipts(
            &mut dov_registry,
            index,
            receipts,
            ctx(scenario)
        );
        transfer::public_transfer(receipt, sender(scenario));
        return_shared(dov_registry);
        next_tx(scenario, ADMIN);
    }
}

