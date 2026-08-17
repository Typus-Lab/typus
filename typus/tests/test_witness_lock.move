#[test_only]
extend module typus::witness_lock {

    use sui::test_scenario;
    use typus::ecosystem;

    public struct TestWitness has drop {}
    public struct InvalidWitness has drop {}

    #[test]
    fun test_witness_lock() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let hot_potato = wrap(
            &version,
            0,
            type_name::with_defining_ids<TestWitness>().into_string().into_bytes().to_string(),
        );
        unwrap<u64, TestWitness>(
            &version,
            hot_potato,
            TestWitness {},
        );
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }

    #[test, expected_failure]
    fun test_witness_lock_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let hot_potato = wrap(
            &version,
            0,
            type_name::with_defining_ids<TestWitness>().into_string().into_bytes().to_string(),
        );
        unwrap<u64, InvalidWitness>(
            &version,
            hot_potato,
            InvalidWitness {},
        );
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }
}