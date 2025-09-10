// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
module typus::utility {
    use sui::balance::Balance;
    use sui::coin::{Self, Coin};

    public fun transfer_coins<TOKEN>(mut coins: vector<Coin<TOKEN>>, user: address) {
        while (!vector::is_empty(&coins)) {
            transfer::public_transfer(coins.pop_back(), user);
        };
        coins.destroy_empty();
    }

    public fun transfer_balance<TOKEN>(balance: Balance<TOKEN>, user: address, ctx: &mut TxContext) {
        if (balance.value() == 0) {
            balance.destroy_zero();
        } else {
            transfer::public_transfer(coin::from_balance(balance, ctx), user);
        }
    }

    public fun transfer_balance_opt<TOKEN>(balance_opt: Option<Balance<TOKEN>>, user: address, ctx: &mut TxContext) {
        if(balance_opt.is_some()) {
            transfer_balance(balance_opt.destroy_some(), user, ctx);
        } else {
            balance_opt.destroy_none();
        }
    }

    public fun basis_point_value(value: u64, bp: u64): u64 {
        ((value as u128) * (bp as u128) / (10000 as u128) as u64)
    }

    public fun set_u64_vector_value(data: &mut vector<u64>, i: u64, value: u64) {
        pad_u64_vector(data, i);
        *&mut data[i] = value;
    }

    public fun increase_u64_vector_value(data: &mut vector<u64>, i: u64, value: u64) {
        pad_u64_vector(data, i);
        *&mut data[i] = data[i] + value;
    }

    public fun decrease_u64_vector_value(data: &mut vector<u64>, i: u64, value: u64) {
        pad_u64_vector(data, i);
        *&mut data[i] = data[i] - value;
    }

    public fun pad_u64_vector(data: &mut vector<u64>, i: u64) {
        while (data.length() < i + 1) {
            data.push_back(0);
        };
    }

    public fun get_u64_vector_value(data: &vector<u64>, i: u64): u64 {
        if (data.length() > i) {
            return *data.borrow(i)
        };

        0
    }

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