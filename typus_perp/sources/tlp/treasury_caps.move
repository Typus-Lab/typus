/// The `treasury_caps` module defines the `TreasuryCaps` struct, which is a shared object that stores the treasury caps for the TLP tokens.
module typus_perp::treasury_caps {
    use std::type_name::{Self, TypeName};
    use sui::coin::TreasuryCap;
    use sui::dynamic_object_field;

    /// A shared object that stores the treasury caps for the TLP tokens.
    public struct TreasuryCaps has key, store {
        id: UID
    }

    // Due to the package size, we changed it to a test_only function
    #[test_only]
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
    #[test_only]
    public(package) fun store_treasury_cap<TOKEN>(treasury_caps: &mut TreasuryCaps, treasury_cap: TreasuryCap<TOKEN>) {
        dynamic_object_field::add(&mut treasury_caps.id, type_name::with_defining_ids<TOKEN>(), treasury_cap);
    }

    // Due to the package size, we changed it to a test_only function
    #[test_only]
    public(package) fun remove_treasury_cap<TOKEN>(treasury_caps: &mut TreasuryCaps): TreasuryCap<TOKEN> {
        dynamic_object_field::remove<TypeName, TreasuryCap<TOKEN>>(&mut treasury_caps.id, type_name::with_defining_ids<TOKEN>())
    }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}


#[test_only]
module typus_perp::test_treasury_caps {
    use sui::test_scenario::{Scenario, begin, end, ctx, next_tx, take_shared, return_shared};
    use typus_perp::admin::{Self, Version};
    use typus_perp::treasury_caps::{Self, TreasuryCaps};
    use typus_perp::tlp::{Self, TLP, LpRegistry as TlpRegistry};
    const ADMIN: address = @0xFFFF;

    fun new_version(scenario: &mut Scenario) {
        admin::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_treasury_caps(scenario: &mut Scenario) {
        treasury_caps::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_tlp_registry(scenario: &mut Scenario) {
        tlp::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);

        let version = version(scenario);
        let mut tlp_registry = tlp_registry(scenario);
        let mut treasury_caps = treasury_caps(scenario);
        tlp::transfer_treasury_cap(&version, &mut tlp_registry, &mut treasury_caps, ctx(scenario));
        return_shared(version);
        return_shared(tlp_registry);
        return_shared(treasury_caps);
        next_tx(scenario, ADMIN);
    }

    fun begin_test(): Scenario {
        let mut scenario = begin(ADMIN);
        tlp::test_init(ctx(&mut scenario));
        new_version(&mut scenario);
        new_treasury_caps(&mut scenario);
        new_tlp_registry(&mut scenario);
        scenario
    }

    fun version(scenario: &Scenario): Version {
        take_shared<Version>(scenario)
    }

    fun tlp_registry(scenario: &Scenario): TlpRegistry {
        take_shared<TlpRegistry>(scenario)
    }

    fun treasury_caps(scenario: &Scenario): TreasuryCaps {
        take_shared<TreasuryCaps>(scenario)
    }

    #[test]
    public(package) fun test_store_treasury_cap() {
        let scenario = begin_test();
        let mut treasury_caps = treasury_caps(&scenario);
        let treasury_cap = treasury_caps.remove_treasury_cap<TLP>();
        treasury_caps.store_treasury_cap<TLP>(treasury_cap);
        return_shared(treasury_caps);
        end(scenario);
    }
}