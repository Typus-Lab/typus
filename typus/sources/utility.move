// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module provides a collection of utility functions that are used throughout the Typus ecosystem.
/// These functions include helpers for transferring coins and balances, calculating basis points,
/// and manipulating vectors of `u64`.
module typus::utility {
    use sui::balance::Balance;
    use sui::coin::{Self, Coin};

    /// Transfers a vector of `Coin`s to a specified user.
    public fun transfer_coins<TOKEN>(mut coins: vector<Coin<TOKEN>>, user: address) {
        while (!vector::is_empty(&coins)) {
            transfer::public_transfer(coins.pop_back(), user);
        };
        coins.destroy_empty();
    }

    /// Transfers a `Balance` to a specified user.
    /// If the balance is zero, it is destroyed.
    public fun transfer_balance<TOKEN>(balance: Balance<TOKEN>, user: address, ctx: &mut TxContext) {
        if (balance.value() == 0) {
            balance.destroy_zero();
        } else {
            transfer::public_transfer(coin::from_balance(balance, ctx), user);
        }
    }

    /// Transfers an `Option<Balance>` to a specified user.
    /// If the option is `None`, it does nothing.
    public fun transfer_balance_opt<TOKEN>(balance_opt: Option<Balance<TOKEN>>, user: address, ctx: &mut TxContext) {
        if(balance_opt.is_some()) {
            transfer_balance(balance_opt.destroy_some(), user, ctx);
        } else {
            balance_opt.destroy_none();
        }
    }

    /// Calculates a value based on basis points (1/10000).
    public fun basis_point_value(value: u64, bp: u64): u64 {
        ((value as u128) * (bp as u128) / (10000 as u128) as u64)
    }

    /// Sets a value in a `vector<u64>` at a specific index.
    /// If the index is out of bounds, it pads the vector with zeros.
    public fun set_u64_vector_value(data: &mut vector<u64>, i: u64, value: u64) {
        pad_u64_vector(data, i);
        *&mut data[i] = value;
    }

    /// Increases a value in a `vector<u64>` at a specific index.
    /// If the index is out of bounds, it pads the vector with zeros before increasing the value.
    public fun increase_u64_vector_value(data: &mut vector<u64>, i: u64, value: u64) {
        pad_u64_vector(data, i);
        *&mut data[i] = data[i] + value;
    }

    /// Decreases a value in a `vector<u64>` at a specific index.
    /// If the index is out of bounds, it pads the vector with zeros before decreasing the value.
    public fun decrease_u64_vector_value(data: &mut vector<u64>, i: u64, value: u64) {
        pad_u64_vector(data, i);
        *&mut data[i] = data[i] - value;
    }

    /// Pads a `vector<u64>` with zeros until it reaches a specified length.
    public fun pad_u64_vector(data: &mut vector<u64>, i: u64) {
        while (data.length() < i + 1) {
            data.push_back(0);
        };
    }

    /// Gets a value from a `vector<u64>` at a specific index.
    /// Returns 0 if the index is out of bounds.
    public fun get_u64_vector_value(data: &vector<u64>, i: u64): u64 {
        if (data.length() > i) {
            return *data.borrow(i)
        };

        0
    }

    /// Calculates a multiplier based on a number of decimals (10^decimal).
    public fun multiplier(decimal: u64): u64 {
        let mut i = 0;
        let mut multiplier = 1;
        while (i < decimal) {
            multiplier = multiplier * 10;
            i = i + 1;
        };
        multiplier
    }
}