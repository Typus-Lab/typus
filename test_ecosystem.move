#[test_only]
extend module typus::ecosystem {

    use sui::test_scenario;

    #[test, expected_failure(abort_code = EInvalidVersion)]
    fun test_version_check_invalid_version_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.upgrade();
        version.value = 999;
        version.version_check();
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EUnauthorized)]
    fun test_verify_unauthorized_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.authority.remove(&scenario.sender());
        version.verify(test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_add_remove_authorized_user() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.add_authorized_user(@0xFFFF, test_scenario::ctx(&mut scenario));
        version.remove_authorized_user(@0xFFFF, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EAuthorityAlreadyExists)]
    fun test_add_authorized_user_authority_already_exists_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.add_authorized_user(@0xABCD, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EAuthorityDoesNotExist)]
    fun test_remove_authorized_user_authority_does_not_exists_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.remove_authorized_user(@0xAAAA, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test, expected_failure(abort_code = EAuthorityEmpty)]
    fun test_remove_authorized_user_authority_empty_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.remove_authorized_user(@0xABCD, test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }
    #[test_only]
    public struct TestToken has drop {}
    #[test]
    fun test_send_fee() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let mut version = test_scenario::take_shared<Version>(&scenario);
        version.charge_fee<TestToken>(balance::create_for_testing(10));
        version.charge_fee<sui::sui::SUI>(balance::create_for_testing(10));
        version.charge_fee<sui::sui::SUI>(balance::create_for_testing(10));
        version.send_fee<sui::sui::SUI>(test_scenario::ctx(&mut scenario));
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }
}