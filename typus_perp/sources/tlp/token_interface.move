/// The `token_interface` module defines an interface for interacting with the TLP token.
module typus_perp::token_interface {
    // use std::type_name;
    // use sui::coin::Coin;
    // use sui::coin::TreasuryCap;

    // use typus_perp::error;
    // use typus_perp::tlp::{Self, TLP};


    // /// Mints TLP tokens.
    // /// WARNING: no authority check inside
    // public(package) fun mint<TOKEN>(treasury_cap: &mut TreasuryCap<TOKEN>, value: u64, ctx: &mut TxContext): Coin<TOKEN> {
    //     assert!(type_name::with_defining_ids<TOKEN>() == type_name::with_defining_ids<TLP>(), error::liquidity_token_not_existed());
    //     return tlp::mint(treasury_cap, value, ctx)
    // }

    // /// Burns TLP tokens.
    // /// WARNING: no authority check inside
    // public(package) fun burn<TOKEN>(treasury_cap: &mut TreasuryCap<TOKEN>, coin: Coin<TOKEN>): u64 {
    //     assert!(type_name::with_defining_ids<TOKEN>() == type_name::with_defining_ids<TLP>(), error::liquidity_token_not_existed());
    //     return tlp::burn(treasury_cap, coin)
    // }
}