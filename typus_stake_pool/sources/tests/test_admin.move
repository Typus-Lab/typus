
#[test_only]
module typus_stake_pool::test_admin {
    use sui::test_scenario::{Scenario, begin, end, ctx, next_tx, take_shared, return_shared};
    use typus_stake_pool::admin::{Self, Version};

    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use typus_stake_pool::babe::BABE;

    const ADMIN: address = @0xFFFF;

    fun mint_test_coin<T>(scenario: &mut Scenario, amount: u64): Coin<T> {
        coin::mint_for_testing<T>(amount, ctx(scenario))
    }

    fun new_version(scenario: &mut Scenario) {
        admin::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun version(scenario: &Scenario): Version {
        take_shared<Version>(scenario)
    }

    fun begin_test(): Scenario {
        let mut scenario = begin(ADMIN);
        new_version(&mut scenario);
        next_tx(&mut scenario, ADMIN);
        next_tx(&mut scenario, ADMIN);
        scenario
    }

    fun test_charge_fee_<T>(scenario: &mut Scenario, amount: u64) {
        let coin = mint_test_coin<T>(scenario, amount);
        let mut version = version(scenario);
        admin::charge_fee<T>(&mut version, coin.into_balance());
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_send_fee_<T>(scenario: &mut Scenario) {
        let mut version = version(scenario);
        admin::send_fee<T>(&mut version, ctx(scenario));
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_upgrade_(scenario: &mut Scenario) {
        let mut version = version(scenario);
        admin::upgrade(&mut version);
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_charge_liquidator_fee_<T>(scenario: &mut Scenario, amount: u64) {
        let coin = mint_test_coin<T>(scenario, amount);
        let mut version = version(scenario);
        admin::charge_liquidator_fee<T>(&mut version, coin.into_balance());
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_send_liquidator_fee_<T>(scenario: &mut Scenario) {
        let mut version = version(scenario);
        admin::send_liquidator_fee<T>(&mut version, ctx(scenario));
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_add_authorized_user_(scenario: &mut Scenario, user_address: address) {
        let mut version = version(scenario);
        admin::add_authorized_user(&mut version, user_address, ctx(scenario));
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun test_remove_authorized_user_(scenario: &mut Scenario, user_address: address) {
        let mut version = version(scenario);
        admin::remove_authorized_user(&mut version, user_address, ctx(scenario));
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    #[test]
    public(package) fun test_admin() {
        let mut scenario = begin_test();
        test_send_fee_<SUI>(&mut scenario); // nothing happened
        test_send_liquidator_fee_<SUI>(&mut scenario); // nothing happened
        test_charge_fee_<SUI>(&mut scenario, 100_0000_00000);
        test_charge_fee_<SUI>(&mut scenario, 100_0000_00000);
        test_charge_fee_<BABE>(&mut scenario, 100_0000_00000);
        test_send_fee_<SUI>(&mut scenario);
        test_send_fee_<SUI>(&mut scenario); // nothing happened
        test_send_fee_<BABE>(&mut scenario);
        test_charge_liquidator_fee_<SUI>(&mut scenario, 100_0000_00000);
        test_charge_liquidator_fee_<SUI>(&mut scenario, 100_0000_00000);
        test_charge_liquidator_fee_<BABE>(&mut scenario, 100_0000_00000);
        test_send_liquidator_fee_<SUI>(&mut scenario);
        test_send_liquidator_fee_<BABE>(&mut scenario);
        test_add_authorized_user_(&mut scenario, @0xEEEE);
        test_remove_authorized_user_(&mut scenario, @0xEEEE);

        test_upgrade_(&mut scenario);
        end(scenario);
    }
}

#[test_only]
module typus_stake_pool::babe {
    use sui::coin;
    use sui::url;

    public struct BABE has drop {}

    const Decimals: u8 = 9;
    // Due to the package size, we changed it to a test_only function
    #[test_only]
    fun init(witness: BABE, ctx: &mut TxContext) {
        let (treasury_cap, coin_metadata) = coin::create_currency(
            witness,
            Decimals,
            b"BABE",
            b"Typus Perp LP Token",
            b"Typus Perp LP Token Description", // TODO: update description
            option::some(url::new_unsafe_from_bytes(b"https://raw.githubusercontent.com/Typus-Lab/typus-asset/main/assets/BABE.svg")),
            ctx
        );

        transfer::public_freeze_object(coin_metadata);
        transfer::public_transfer(treasury_cap, ctx.sender());
    }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(BABE {}, ctx);
    }
}