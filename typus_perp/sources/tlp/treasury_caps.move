/// The `treasury_caps` module defines the `TreasuryCaps` struct, which is a shared object that stores the treasury caps for the TLP tokens.
module typus_perp::treasury_caps {
    use std::type_name;
    use sui::coin::TreasuryCap;
    use sui::dynamic_object_field;

    use typus_perp::admin::{Self, Version};

    /// A shared object that stores the treasury caps for the TLP tokens.
    public struct TreasuryCaps has key, store {
        id: UID
    }

    // Due to the package size, we changed it to a test_only function
    fun init(ctx: &mut TxContext) {
        transfer::share_object(TreasuryCaps {
            id: object::new(ctx)
        });
    }

    /// Gets a mutable reference to a treasury cap.
    /// WARNING: no authority check inside
    public(package) fun get_mut_treasury_cap<TOKEN>(treasury_caps: &mut TreasuryCaps): &mut TreasuryCap<TOKEN> {
        dynamic_object_field::borrow_mut(&mut treasury_caps.id, type_name::with_defining_ids<TOKEN>())
    }

    // Due to the package size, we changed it to a test_only function
    // #[test_only]
    // public(package) fun store_treasury_cap<TOKEN>(treasury_caps: &mut TreasuryCaps, treasury_cap: TreasuryCap<TOKEN>) {
    //     dynamic_object_field::add(&mut treasury_caps.id, type_name::with_defining_ids<TOKEN>(), treasury_cap);
    // }

    // // Due to the package size, we changed it to a test_only function
    // #[test_only]
    // public(package) fun remove_treasury_cap<TOKEN>(treasury_caps: &mut TreasuryCaps): TreasuryCap<TOKEN> {
    //     dynamic_object_field::remove<TypeName, TreasuryCap<TOKEN>>(&mut treasury_caps.id, type_name::with_defining_ids<TOKEN>())
    // }

    public fun manager_store_treasury_cap<TOKEN>(
        version: &Version,
        treasury_caps: &mut TreasuryCaps,
        treasury_cap: TreasuryCap<TOKEN>,
        ctx: &TxContext,
    ) {
        admin::verify(version, ctx);
        dynamic_object_field::add(&mut treasury_caps.id, type_name::with_defining_ids<TOKEN>(), treasury_cap);
    }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}