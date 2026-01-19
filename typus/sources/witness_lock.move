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

    #[test_only]
    public fun update_witness_for_testing<T>(hot_potato: &mut HotPotato<T>, witness: String) {
        hot_potato.witness = witness;
    }
}