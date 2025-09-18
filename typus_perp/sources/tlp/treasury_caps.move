module typus_perp::treasury_caps {
    use std::type_name::{Self};
    use sui::coin::TreasuryCap;
    use sui::dynamic_object_field;

    public struct TreasuryCaps has key, store {
        id: UID
    }

    // fun init(ctx: &mut TxContext) {
    //     transfer::share_object(TreasuryCaps {
    //         id: object::new(ctx)
    //     });
    // }

    public(package) fun get_mut_treasury_cap<TOKEN>(treasury_caps: &mut TreasuryCaps): &mut TreasuryCap<TOKEN> {
        dynamic_object_field::borrow_mut(&mut treasury_caps.id, type_name::get<TOKEN>())
    }

    // public(package) fun store_treasury_cap<TOKEN>(treasury_caps: &mut TreasuryCaps, treasury_cap: TreasuryCap<TOKEN>) {
    //     dynamic_object_field::add(&mut treasury_caps.id, type_name::get<TOKEN>(), treasury_cap);
    // }

    // public(package) fun remove_treasury_cap<TOKEN>(treasury_caps: &mut TreasuryCaps): TreasuryCap<TOKEN> {
    //     dynamic_object_field::remove<TypeName, TreasuryCap<TOKEN>>(&mut treasury_caps.id, type_name::get<TOKEN>())
    // }

    // #[test_only]
    // public(package) fun test_init(ctx: &mut TxContext) {
    //     init(ctx);
    // }
}