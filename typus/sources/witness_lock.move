module typus::witness_lock {
    use std::type_name::{Self};
    use std::string::{String};
    use typus::ecosystem::{Version};

    public struct HotPotato<T> {
        obj: T,
        witness: String
    }

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

    public fun unwrap<T, W: drop>(
        version: &Version,
        hot_potato: HotPotato<T>,
        _witness: W,
    ): T {
        version.version_check();

        let HotPotato { obj, witness } = hot_potato;
        // check witness
        assert!(type_name::get<W>().into_string().to_string() == witness, invalid_witness());
        obj
    }

    fun invalid_witness(): u64 { abort 0 }
}