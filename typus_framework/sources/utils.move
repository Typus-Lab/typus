// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module typus_framework::utils {
    use std::type_name;

    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};

    // ======== Constants ========

    const C_MONTH_STRING: vector<vector<u8>> = vector[
        b"JAN", b"FEB", b"MAR", b"APR", b"MAY", b"JUN",
        b"JUL", b"AUG", b"SEP", b"OCT", b"NOV", b"DEC"
    ];
    const C_NUMBER_STRING: vector<vector<u8>> = vector[
        b"00", b"01", b"02", b"03", b"04", b"05", b"06", b"07", b"08", b"09",
        b"10", b"11", b"12", b"13", b"14", b"15", b"16", b"17", b"18", b"19",
        b"20", b"21", b"22", b"23", b"24", b"25", b"26", b"27", b"28", b"29",
        b"30", b"31", b"32", b"33", b"34", b"35", b"36", b"37", b"38", b"39",
        b"40", b"41", b"42", b"43", b"44", b"45", b"46", b"47", b"48", b"49",
        b"50", b"51", b"52", b"53", b"54", b"55", b"56", b"57", b"58", b"59",
        b"60", b"61", b"62", b"63", b"64", b"65", b"66", b"67", b"68", b"69",
        b"70", b"71", b"72", b"73", b"74", b"75", b"76", b"77", b"78", b"79",
        b"80", b"81", b"82", b"83", b"84", b"85", b"86", b"87", b"88", b"89",
        b"90", b"91", b"92", b"93", b"94", b"95", b"96", b"97", b"98", b"99"
    ];

    // ======== Errors ========

    #[error]
    const EInsufficientBalance: vector<u8> = b"Insufficient Balance";

    // ======== Functions ========

    /// Calculates a multiplier based on a number of decimals.
    /// For example, `multiplier(2)` returns 100.
    public fun multiplier(decimal: u64): u64 {
        let mut i = 0;
        let mut multiplier = 1;
        while (i < decimal) {
            multiplier = multiplier * 10;
            i = i + 1;
        };
        multiplier
    }

    /// Extracts a specific `amount` from a vector of `Coin`s and returns it as a `Balance`.
    /// The remaining coins are transferred back to the sender.
    public fun extract_balance<Token>(coins: vector<Coin<Token>>, amount: u64, ctx: &TxContext): Balance<Token> {
        let user = tx_context::sender(ctx);
        delegate_extract_balance<Token>(user, coins, amount)
    }

    /// A helper for `extract_balance` that transfers the remaining coins back to the user.
    public fun delegate_extract_balance<Token>(user: address, coins: vector<Coin<Token>>, amount: u64): Balance<Token> {
        let (mut coins, balance) = public_extract_balance<Token>(coins, amount);
        while (!vector::is_empty(&coins)) {
            let coin = vector::pop_back(&mut coins);
            transfer::public_transfer(coin, user);
        };
        vector::destroy_empty(coins);
        balance
    }

    /// The core logic for extracting a balance from coins.
    /// It takes a vector of coins and an amount, and returns the remaining coins and the extracted balance.
    public fun public_extract_balance<TOKEN>(
        mut coins: vector<Coin<TOKEN>>,
        mut amount: u64,
    ): (vector<Coin<TOKEN>>, Balance<TOKEN>) {
        let mut balance = balance::zero();
        while (!vector::is_empty(&coins)) {
            if (amount > 0) {
                let mut coin = vector::pop_back(&mut coins);
                if (coin::value(&coin) > amount) {
                    balance::join(&mut balance, balance::split(coin::balance_mut(&mut coin), amount));
                    vector::push_back(&mut coins, coin);
                    amount = 0;
                    break
                }
                else {
                    amount = amount - coin::value(&coin);
                    balance::join(&mut balance, coin::into_balance(coin));
                };
            }
            else {
                break
            }
        };
        assert!(amount == 0, EInsufficientBalance);

        (coins, balance)
    }

    /// Merges a vector of `Coin`s into a single `Coin`.
    public fun merge_coins<Token>(mut coins: vector<Coin<Token>>): Coin<Token> {
        let mut coin = vector::pop_back(&mut coins);
        while (!vector::is_empty(&coins)) {
            let temp = vector::pop_back(&mut coins);
            coin::join(&mut coin, temp);
        };
        vector::destroy_empty(coins);
        coin
    }

    /// Transfers a vector of `Coin`s to a user.
    public fun transfer_coins<TOKEN>(mut coins: vector<Coin<TOKEN>>, user: address) {
        while (!vector::is_empty(&coins)) {
            let coin = vector::pop_back(&mut coins);
            transfer::public_transfer(coin, user);
        };
        vector::destroy_empty(coins);
    }

    /// Transfers a `Balance` to a user.
    public fun transfer_balance<TOKEN>(balance: Balance<TOKEN>, user: address, ctx: &mut TxContext) {
        if (balance::value(&balance) > 0) {
            transfer::public_transfer(
                coin::from_balance(balance, ctx),
                user,
            );
        } else {
            balance::destroy_zero(balance);
        };
    }

    /// Converts a Unix timestamp to a date (year, month, day).
    /// reference: http://howardhinnant.github.io/date_algorithms.html#civil_from_days
    public fun get_date_from_ts(timestamp: u64): (u64, u64, u64) {
        let z = timestamp / 86400 + 719468;
        let era = z / 146097;
        let doe = z - era * 146097;
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        let y = yoe + era * 400;
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        let mp = (5 * doy + 2) / 153;
        let d = doy - (153 * mp + 2) / 5 + 1;
        let m = if (mp < 10) { mp + 3 } else { mp - 9 };
        let y = if (m <= 2) { y + 1 } else { y };
        (y, m, d)
    }

    /// Checks if two generic types are the same.
    public fun match_types<X, Y>(): bool {
        type_name::with_defining_ids<X>() == type_name::with_defining_ids<Y>()
    }


    /// Converts a `u64` to a byte vector representation of a decimal number.
    public fun u64_to_bytes(mut value: u64, mut decimal: u64): vector<u8> {
        let mut result = vector::empty();
        while (decimal > 0) {
            let digit = value % 10;
            if (!vector::is_empty(&result) || digit != 0) {
                vector::push_back(&mut result, (digit as u8) + 48);
            };
            value = value / 10;
            decimal = decimal - 1;
        };
        if (!vector::is_empty(&result)) {
            vector::push_back(&mut result, 46);
        };
        if (value == 0) {
            vector::push_back(&mut result, 48);
        } else {
            while (value > 0) {
                let digit = value % 10;
                vector::push_back(&mut result, (digit as u8) + 48);
                value = value / 10;
            }
        };
        vector::reverse(&mut result);

        result
    }

    /// Returns the three-letter abbreviation for a month.
    #[allow(implicit_const_copy)]
    public fun get_month_short_string(month: u64): vector<u8> {
        *vector::borrow(&C_MONTH_STRING, month - 1)
    }

    /// Returns a two-digit padded string for a number.
    #[allow(implicit_const_copy)]
    public fun get_pad_2_number_string(value: u64): vector<u8> {
        *vector::borrow(&C_NUMBER_STRING, value % 100)
    }

    /// Sets a value in a `vector<u64>` used for padding, resizing it if necessary.
    /// WARNING: mut inputs without authority check inside
    public fun set_u64_padding_value(u64_padding: &mut vector<u64>, i: u64, value: u64) {
        while (vector::length(u64_padding) < i + 1) {
            vector::push_back(u64_padding, 0);
        };
        *vector::borrow_mut(u64_padding, i) = value;
    }

    /// Gets a value from a padding vector.
    public fun get_u64_padding_value(u64_padding: &vector<u64>, i: u64): u64 {
        if (vector::length(u64_padding) > i) {
            return *vector::borrow(u64_padding, i)
        };

        0
    }

    /// Gets a value and a flag from a padding vector.
    /// The flag is stored in the most significant bit of the value.
    public fun get_flagged_u64_padding_value(u64_padding: &vector<u64>, i: u64): (bool, u64) {
        if (vector::length(u64_padding) > i) {
            let value = *vector::borrow(u64_padding, i);
            if (value >= 1 << 63) {
                return (true, value - (1 << 63))
            };
        };

        (false, 0)
    }
}