/// The `tlp` module defines the TLP token and its associated functions.
module typus_perp::tlp {
    // use std::type_name;
    #[test_only]
    use std::string::{Self, String};
    #[test_only]
    use sui::coin::{Self, TreasuryCap};
    #[test_only]
    use sui::dynamic_object_field;
    #[test_only]
    use sui::url;

    // use typus_perp::error;
    #[test_only]
    use typus_perp::admin::{Self, Version};
    #[test_only]
    use typus_perp::treasury_caps::{Self, TreasuryCaps};

    // friend typus_perp::token_interface;
    #[test_only]
    const K_TREASURY_CAP: vector<u8> = b"treasury_cap";

    /// A registry for the TLP token.
    public struct LpRegistry has key{
        id: UID,
    }

    /// The TLP token.
    public struct TLP has drop {}

    /// The number of decimals for the TLP token.
    #[test_only]
    const Decimals: u8 = 9;
    // Due to the package size, we changed it to a test_only function
    #[test_only]
    fun init(witness: TLP, ctx: &mut TxContext) {
        let (treasury_cap, coin_metadata) = coin::create_currency(
            witness,
            Decimals,
            b"TLP",
            b"Typus Perp LP Token",
            b"Typus Perp LP Token Description", // TODO: update description
            option::some(url::new_unsafe_from_bytes(b"https://raw.githubusercontent.com/Typus-Lab/typus-asset/main/assets/TLP.svg")),
            ctx
        );

        let mut registry =  LpRegistry {
            id: object::new(ctx),
        };

        dynamic_object_field::add(&mut registry.id, string::utf8(K_TREASURY_CAP), treasury_cap);

        transfer::public_freeze_object(coin_metadata);
        transfer::share_object(registry);
    }

    // public(package) fun mint<TOKEN>(treasury_cap: &mut TreasuryCap<TOKEN>, value: u64, ctx: &mut TxContext): Coin<TOKEN> {
    //     assert!(type_name::with_defining_ids<TOKEN>() == type_name::with_defining_ids<TLP>(), error::lp_token_type_mismatched());
    //     coin::mint(treasury_cap, value, ctx)
    // }

    // public(package) fun burn<TOKEN>(treasury_cap: &mut TreasuryCap<TOKEN>, coin: Coin<TOKEN>): u64 {
    //     assert!(type_name::with_defining_ids<TOKEN>() == type_name::with_defining_ids<TLP>(), error::lp_token_type_mismatched());
    //     coin::burn(treasury_cap, coin)
    // }

    // public(package) fun total_supply(treasury_cap: &TreasuryCap<TLP>): u64 {
    //     coin::total_supply(treasury_cap)
    // }

    // Due to the package size, we changed it to a test_only function
    #[test_only]
    /// [Authorized Function] Transfers the treasury cap to the `TreasuryCaps` object.
    entry fun transfer_treasury_cap(
        version: &Version,
        lp_registry: &mut LpRegistry,
        treasury_caps: &mut TreasuryCaps,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let treasury_cap = dynamic_object_field::remove<String, TreasuryCap<TLP>>(&mut lp_registry.id, string::utf8(K_TREASURY_CAP));
        treasury_caps::store_treasury_cap(treasury_caps, treasury_cap);
    }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(TLP {}, ctx);
    }
}