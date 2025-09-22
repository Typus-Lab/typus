/// This module implements a "witness lock" pattern, which is a way to create restricted functions
/// that can only be called if a specific witness type is provided. This is a common pattern in Sui Move
/// for creating authorization mechanisms that are not tied to a specific authority address.
module typus::witness_lock {
    use std::type_name;
    use std::string::String;
    use typus::ecosystem::Version;

    public struct HotPotato<T> {
        obj: T,
        witness: String
    }

    /// Wraps an object in a `HotPotato`, effectively locking it with a witness.
    /// The witness is the type name of a specific type that will be required to unlock the object.
    public fun wrap<T>(
        version: &Version,
        obj: T,
        witness: String,
    ): HotPotato<T> {
        version.version_check();

        let hot_potato = HotPotato<T> {
            obj,
            witness,
        };
        hot_potato
    }

    /// Unwraps a `HotPotato`, returning the original object.
    /// This function requires a witness of type `W` to be passed in. It checks that the type name
    /// of the witness matches the witness string stored in the `HotPotato`.
    /// Aborts if the witness is invalid.
    public fun unwrap<T, W: drop>(
        version: &Version,
        hot_potato: HotPotato<T>,
        _witness: W,
    ): T {
        version.version_check();

        let HotPotato { obj, witness } = hot_potato;
        // check witness
        assert!(type_name::with_defining_ids<W>().into_string().to_string() == witness, invalid_witness());
        obj
    }

    /// Aborts with an error code indicating an invalid witness.
    fun invalid_witness(): u64 { abort 0 }
}

#[test_only]
module typus::test_witness_lock {
    use std::type_name;
    use sui::test_scenario;

    use typus::ecosystem::{Self, Version};
    use typus::witness_lock;

    public struct TestWitness has drop {}
    public struct InvalidWitness has drop {}

    #[test]
    fun test_witness_lock() {
        let mut scenario = test_scenario::begin(@0xABCD);
        ecosystem::test_init(test_scenario::ctx(&mut scenario));
        test_scenario::next_tx(&mut scenario, @0xABCD);
        let version = test_scenario::take_shared<Version>(&scenario);
        let hot_potato = witness_lock::wrap(
            &version,
            0,
            type_name::with_defining_ids<TestWitness>().into_string().into_bytes().to_string(),
        );
        witness_lock::unwrap<u64, TestWitness>(
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
        let hot_potato = witness_lock::wrap(
            &version,
            0,
            type_name::with_defining_ids<TestWitness>().into_string().into_bytes().to_string(),
        );
        witness_lock::unwrap<u64, InvalidWitness>(
            &version,
            hot_potato,
            InvalidWitness {},
        );
        test_scenario::return_shared(version);
        test_scenario::end(scenario);
    }
}