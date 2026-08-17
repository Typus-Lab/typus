#[test_only]
extend module typus_framework::authority {
    use sui::test_scenario;

    #[test]
    fun test_authority() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut authority = new(
            vector[scenario.sender()],
            scenario.ctx(),
        );
        authority.add_authorized_user(@0xAAAA);
        authority.add_authorized_user(@0xAAAA);
        authority.remove_authorized_user(@0xAAAA);
        authority.remove_authorized_user(@0xAAAA);
        assert!(authority.whitelist()==vector[@0xABCD], 0);
        authority.destroy(scenario.ctx());
        scenario.end();
    }

    #[test, expected_failure(abort_code = E_EMPTY_WHITELIST)]
    fun test_new_empty_whitelist_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let authority = new(
            vector[],
            scenario.ctx(),
        );
        authority.destroy(scenario.ctx());
        scenario.end();
    }

    #[test, expected_failure, allow(deprecated_usage)]
    fun test_remove_all_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut authority = new(
            vector[scenario.sender()],
            scenario.ctx(),
        );
        authority.remove_all(scenario.ctx());
        authority.destroy(scenario.ctx());
        scenario.end();
    }

    #[test, expected_failure, allow(deprecated_usage)]
    fun test_destroy_empty_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let authority = new(
            vector[scenario.sender()],
            scenario.ctx(),
        );
        authority.destroy_empty(scenario.ctx());
        scenario.end();
    }

    #[test]
    fun test_verify() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let authority = new(
            vector[scenario.sender()],
            scenario.ctx(),
        );
        authority.verify(scenario.ctx());
        authority.destroy(scenario.ctx());
        scenario.end();
    }

    #[test, expected_failure(abort_code = E_UNAUTHORIZED)]
    fun test_verify_unauthorized_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let authority = new(
            vector[@0xAAAA],
            scenario.ctx(),
        );
        authority.verify(scenario.ctx());
        authority.destroy(scenario.ctx());
        scenario.end();
    }

    #[test]
    fun test_double_verify() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let authority1 = new(
            vector[scenario.sender()],
            scenario.ctx(),
        );
        let authority2 = new(
            vector[@0xAAAA],
            scenario.ctx(),
        );
        double_verify(&authority1, &authority2, scenario.ctx());
        double_verify(&authority2, &authority1, scenario.ctx());
        authority1.destroy(scenario.ctx());
        let Authority { whitelist } = authority2;
        whitelist.drop();
        scenario.end();
    }

    #[test, expected_failure(abort_code = E_UNAUTHORIZED)]
    fun test_double_verify_unauthorized_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let authority1 = new(
            vector[@0xAAAA],
            scenario.ctx(),
        );
        let authority2 = new(
            vector[@0xBBBB],
            scenario.ctx(),
        );
        double_verify(&authority1, &authority2, scenario.ctx());
        authority1.destroy(scenario.ctx());
        let Authority { whitelist } = authority2;
        whitelist.drop();
        scenario.end();
    }
}