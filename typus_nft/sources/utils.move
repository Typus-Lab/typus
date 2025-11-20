/// This module provides utility functions for the Typus NFT collection.
/// Only contains public(friend) functions
module typus_nft::utils {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::vec_map::{Self, VecMap};
    use sui::bcs;

    /* friend typus_nft::typus_nft; */

    const E_INSUFFICIENT_BALANCE: u64 = 0;
    const ETruncatedBytes: u64 = 1;
    const E_INVALID_LENGTH: u64 = 2;

    /// Extracts a balance of a given amount from a vector of coins.
    #[lint_allow(self_transfer)]
    public(package) fun extract_balance<Token>(mut coins: vector<Coin<Token>>, mut amount: u64, ctx: &TxContext): Balance<Token> {
        let mut balance = balance::zero();
        while (!vector::is_empty(&coins)) {
            if (amount > 0) {
                let mut coin = vector::pop_back(&mut coins);
                if (coin::value(&coin) >= amount) {
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
        assert!(amount == 0, E_INSUFFICIENT_BALANCE);
        let user = tx_context::sender(ctx);
        while (!vector::is_empty(&coins)) {
            let coin = vector::pop_back(&mut coins);
            transfer::public_transfer(coin, user);
        };
        vector::destroy_empty(coins);
        balance
    }

    /// Creates a map from a vector of keys and a vector of values.
    public(package) fun from_vec_to_map<K: copy + drop, V: drop>(
        mut keys: vector<K>,
        mut values: vector<V>,
    ): VecMap<K, V> {
        assert!(vector::length(&keys) == vector::length(&values), E_INVALID_LENGTH);

        let mut i = 0;
        let n = vector::length(&keys);
        let mut map = vec_map::empty<K, V>();

        while (i < n) {
            let key = vector::pop_back(&mut keys);
            let value = vector::pop_back(&mut values);

            vec_map::insert(
                &mut map,
                key,
                value,
            );

            i = i + 1;
        };

        map
    }

    /// Converts a vector of bytes to a u64.
    public(package) fun u64_from_bytes(bytes: &vector<u8>): u64 {
        let mut m: u64 = 0;

        // Cap length at 8 bytes
        let len = vector::length(bytes);

        assert!(len <= 8, ETruncatedBytes);

        let mut i = 0;
        while (i < len) {
            m = m * 10;
            let byte = *vector::borrow(bytes, i);
            m = m + (byte as u64) - 48;
            i = i + 1;
        };

        m
    }

    /// Generates a random u256 number.
    public(package) fun rand(ctx: &mut TxContext): u256 {
        let uid = object::new(ctx);
        let mut object_nonce = object::uid_to_bytes(&uid);
        object::delete(uid);

        let epoch_nonce = bcs::to_bytes(&tx_context::epoch(ctx));
        let sender_nonce = bcs::to_bytes(&tx_context::sender(ctx));

        vector::append(&mut object_nonce, epoch_nonce);
        vector::append(&mut object_nonce, sender_nonce);

        let rand = std::hash::sha3_256(object_nonce);

        u256_from_bytes(&rand)
    }

    /// Converts a vector of bytes to a u256.
    public(package) fun u256_from_bytes(bytes: &vector<u8>): u256 {
        let mut m: u256 = 0;

        // Cap length at 32 bytes
        let len = vector::length(bytes);
        assert!(len <= 32, ETruncatedBytes);

        let mut i = 0;
        while (i < len) {
            m = m << 8;
            let byte = *vector::borrow(bytes, i);
            m = m + (byte as u256);
            i = i + 1;
        };

        m
    }


    #[test]
    fun test_u64_from_bytes() {
        let s = std::ascii::string(b"1230");
        let bytes = std::ascii::as_bytes(&s);
        assert!(1230 == u64_from_bytes(bytes), 0);

        let s = std::ascii::string(b"123456789");
        let bytes = std::ascii::as_bytes(&s);
        assert!(123456789 == u64_from_bytes(bytes), 0);

        let s = std::ascii::string(b"0987654321");
        let bytes = std::ascii::as_bytes(&s);
        assert!(0987654321 == u64_from_bytes(bytes), 0);

        assert!(12345 == u64_from_bytes(&b"12345"), 0);
    }
    #[test]
    fun test_rand() {
        use sui::test_scenario::{Self, ctx};
        // use std::debug::print;

        let mut scenario = test_scenario::begin(@0x1);
        let num = rand(ctx(&mut scenario));
        // std::debug::print(&num);
        assert!(115170965196527074966438585871818494722075011700686295937061508976360424967044 == num, 1);
        test_scenario::end(scenario);

        let mut scenario = test_scenario::begin(@0x123);
        let num = rand(ctx(&mut scenario));
        assert!(29711549470554919680687358874047181380854438259270651202242130999283702377307 == num, 1);
        test_scenario::end(scenario);

        // let scenario = test_scenario::begin(@0x1444);
        // let num = rand(ctx(&mut scenario));
        // test_scenario::end(scenario);

        // let scenario = test_scenario::begin(@0x556661);
        // let num = rand(ctx(&mut scenario));
        // std::debug::print(&num);
        // test_scenario::end(scenario);

        // let scenario = test_scenario::begin(@0x155555555);
        // let num = rand(ctx(&mut scenario));
        // std::debug::print(&num);
        // test_scenario::end(scenario);

        // let scenario = test_scenario::begin(@0x6664621);
        // let num = rand(ctx(&mut scenario));
        // std::debug::print(&num);
        // test_scenario::end(scenario);

        // let scenario = test_scenario::begin(@0x324455551);
        // let num = rand(ctx(&mut scenario));
        // std::debug::print(&num);
        // test_scenario::end(scenario);
    }
    // #[test]
    // fun test_sub_string() {
    //     use std::string;
    //     use std::debug;

    //     let name = string::utf8(b"Tails By Typus #2");
    //     let len = string::length(&name);
    //     let num_str = string::sub_string(&name, 16, len);
    //     debug::print(&num_str);

    //     let mut description = string::utf8(b"Tails /6,666 by Typus Finance.");
    //     string::insert(&mut description, 6, num_str);
    //     debug::print(&description);
    // }
}