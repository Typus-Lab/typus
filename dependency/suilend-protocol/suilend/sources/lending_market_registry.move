/// Top level object that tracks all lending markets.
/// Ensures that there is only one LendingMarket of each type.
/// Anyone can create a new LendingMarket via the registry.
module suilend::lending_market_registry {
    use sui::table::{Self, Table};
    use sui::object::{Self, ID, UID};
    use std::type_name::{Self, TypeName};
    use sui::tx_context::{TxContext};
    use sui::transfer::{Self};
    use sui::dynamic_field::{Self};

    use suilend::lending_market::{Self, LendingMarket, LendingMarketOwnerCap};

    // === Errors ===
    const EIncorrectVersion: u64 = 1;

    // === Constants ===
    const CURRENT_VERSION: u64 = 1;

    public struct Registry has key {
        id: UID,
        version: u64,
        lending_markets: Table<TypeName, ID>
    }

    fun init(ctx: &mut TxContext) {
        let registry = Registry {
            id: object::new(ctx),
            version: CURRENT_VERSION,
            lending_markets: table::new(ctx)
        };

        transfer::share_object(registry);
    }

    public fun create_lending_market<P>(registry: &mut Registry, ctx: &mut TxContext): (
        LendingMarketOwnerCap<P>,
        LendingMarket<P>
    ) {
        assert!(registry.version == CURRENT_VERSION, EIncorrectVersion);

        let (owner_cap, lending_market) = lending_market::create_lending_market<P>(ctx);
        table::add(&mut registry.lending_markets, type_name::get<P>(), object::id(&lending_market));
        (owner_cap, lending_market)
    }
}
