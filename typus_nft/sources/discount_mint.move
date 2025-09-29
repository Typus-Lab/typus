/// This module implements a discount minting pool for Typus NFTs.
/// Users can request to mint an NFT with a discount, and the final price is determined by a VRF.
module typus_nft::discount_mint {
    use std::string;

    use sui::coin::{Self, Coin};
    use sui::kiosk;
    use sui::balance::{Self, Balance};
    use sui::table_vec::{Self, TableVec};
    use sui::table::{Self, Table};
    use sui::event;
    use sui::hash::blake2b256;
    use sui::sui::SUI;
    use sui::bcs;
    use sui::bls12381::bls12381_min_pk_verify;
    use sui::clock::{Self, Clock};
    use sui::transfer_policy::TransferPolicy;
    use sui::dynamic_field;

    use typus_nft::typus_nft::{Self, Tails};

    const E_INVALID_COIN: u64 = 1;
    const E_INVALID_SEED: u64 = 2;
    const E_EMPTY_POOL: u64 = 3;
    const E_NOT_START: u64 = 4;
    const E_NOT_LIVE: u64 = 5;
    const E_INVALID_RND_LENGTH: u64 = 6;
    const E_IS_ENDED: u64 = 7;

    const DISCOUNT_PCT: u64 = 40;

    /// The discount minting pool object.
    public struct Pool has key {
        // constant
        id: UID,
        /// The number of NFTs remaining in the pool.
        num: u64,   // remaining
        /// The price of the NFT in SUI with 9 decimals.
        price: u64, // SUI decimal 9
        /// The start time of the mint in milliseconds.
        start_ms: u64,
        /// The end time of the mint in milliseconds.
        end_ms: u64,
        /// The authority of the pool.
        authority: address,
        /// The public key for the VRF.
        public_key: vector<u8>,
        /// The discount percentages with 2 decimals.
        discount_pcts: vector<u64>, // decimal 2
        /// Whether the pool is live.
        is_live: bool,
        /// The balance of the pool.
        balance: Balance<SUI>,
        /// The NFTs in the pool.
        tails: TableVec<Tails>,
        /// The mint requests.
        requests: vector<MintRequest>,
    }

    /// Creates a new discount minting pool.
    /// Safe with `ManagerCap` check
    entry fun new_pool(
        _manager_cap: &typus_nft::ManagerCap,
        price: u64,
        start_ms: u64,
        end_ms: u64,
        public_key: vector<u8>,
        discount_pcts: vector<u64>,
        ctx: &mut TxContext
    ) {
        let pool = Pool {
            id: object::new(ctx),
            num: 0,
            price,
            start_ms,
            end_ms,
            authority: tx_context::sender(ctx),
            public_key,
            discount_pcts,
            is_live: true,
            balance: balance::zero<SUI>(),
            tails: table_vec::empty(ctx),
            requests: vector::empty<MintRequest>(),
        };
        transfer::share_object(pool);
    }

    /// Deposits an NFT into the pool.
    entry fun deposit_nft(
        pool: &mut Pool,
        nft: Tails,
    ) {
        table_vec::push_back(&mut pool.tails, nft);
    }

    /// Migrates NFTs from an old pool to a new pool.
    /// Safe with `ManagerCap` check
    entry fun migrate_nfts(
        manager_cap: &typus_nft::ManagerCap,
        pool: &mut typus_nft::Pool,
        n: u64,
        new_pool: &mut Pool,
    ) {
        let mut nfts = typus_nft::withdraw_nfts(manager_cap, pool, n);

        while (!vector::is_empty(&nfts)) {
            let nft = vector::pop_back(&mut nfts);
            deposit_nft(new_pool, nft)
        };

        vector::destroy_empty(nfts);
    }

    /// Migrates NFTs from one pool to another based on level.
    /// Safe with `authority` check
    entry fun migrate_pool(
        pool: &mut Pool,
        new_pool: &mut Pool,
        lt_level: u64,
        start: u64,
        mut n: u64,
        ctx: & TxContext
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);
        assert!(new_pool.authority == tx_context::sender(ctx), 0);
        let mut i = start;
        let mut len = table_vec::length(&pool.tails);
        while ((i < len) && (n > 0)) {
            let nft = table_vec::borrow<Tails>(&pool.tails, i);
            let level = typus_nft::tails_level(nft);
            if (level>lt_level) {
                table_vec::swap(&mut pool.tails, i, len-1);
                let nft = table_vec::pop_back(&mut pool.tails);
                deposit_nft(new_pool, nft);
                len = len - 1;
            } else {
                i = i + 1;
                n = n - 1;
            };
        };
    }

    /// Updates an NFT in the pool.
    /// Safe with `ManagerCap` check
    entry fun update_pool_nft(
        manager_cap: &typus_nft::ManagerCap,
        pool: &mut Pool,
        index: u64,
        id: ID,
        level: u64,
        url: vector<u8>,
        ctx: & TxContext
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);
        let nft = table_vec::borrow_mut(&mut pool.tails, index);
        typus_nft::update_nft(manager_cap, nft, id, level, url);
    }

    /// A request to mint an NFT.
    #[lint_allow(coin_field)]
    public struct MintRequest has store {
        user: address,
        coin: Coin<SUI>,
        vrf_input: vector<u8>
    }

    /// Event emitted when a mint request is made.
    public struct MintRequestEvent has copy, drop {
        user: address,
        vrf_input: vector<u8>,
        remaining: u64,
        seed: u64,
    }

    /// Requests to mint an NFT.
    entry fun request_mint(
        pool: &mut Pool,
        seed: u64, // 0, 1, 2
        coin: Coin<SUI>,
        clock: &Clock,
        ctx: & TxContext
    ) {
        assert!(seed < 3, E_INVALID_SEED);

        let ms = clock::timestamp_ms(clock);
        assert!(ms >= pool.start_ms, E_NOT_START);
        assert!(ms < pool.end_ms, E_IS_ENDED);
        assert!(pool.is_live, E_NOT_LIVE);

        let mut vrf_input = object::id_bytes(pool);

        // check remaining
        let remaining = pool.num;
        assert!(remaining > 0, E_EMPTY_POOL);

        vector::append(&mut vrf_input, bcs::to_bytes(&remaining));
        vector::append(&mut vrf_input, bcs::to_bytes(&seed));
        vector::append(&mut vrf_input, bcs::to_bytes(&ms));

        let user = tx_context::sender(ctx);
        let mut check_price = pool.price;

        if (dynamic_field::exists_(& pool.id, string::utf8(b"whitelist"))){
            let whitelist: &mut Table<address, bool> = dynamic_field::borrow_mut(&mut pool.id, string::utf8(b"whitelist"));
            if (table::contains(whitelist, user)){
                table::remove(whitelist, user);
                check_price = pool.price * (100 - DISCOUNT_PCT) / 100;
            };
        };

        // check coin equal price
        assert!(coin::value(&coin) == check_price, E_INVALID_COIN);


        let mint_request = MintRequest {
            user,
            coin,
            vrf_input
        };

        vector::push_back(&mut pool.requests, mint_request);
        pool.num = pool.num - 1;

        let event = MintRequestEvent { user, vrf_input, remaining, seed };
        event::emit(event);
    }

    /// Executes a mint request.
    /// Safe with `authority` check
    #[lint_allow(share_owned)]
    entry fun execute_mint(
        pool: &mut Pool,
        policy: &TransferPolicy<Tails>,
        bls_sig: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);

        let MintRequest {
            user,
            coin,
            vrf_input
        } = vector::remove(&mut pool.requests, 0);

        let coin_value = coin::value(&coin);
        if ((coin_value == pool.price) || (coin_value == pool.price *  (100 - DISCOUNT_PCT)/ 100)) {
            assert!(bls12381_min_pk_verify(&bls_sig, &pool.public_key, &vrf_input), 0);
            let hashed_beacon = blake2b256(&bls_sig);
            let len = table_vec::length(&pool.tails);
            let index = generate_answer(len, &hashed_beacon);
            // mint
            let nft = if (len == 1) {
                table_vec::pop_back(&mut pool.tails)
            } else {
                table_vec::swap(&mut pool.tails, (index as u64), len-1);
                table_vec::pop_back(&mut pool.tails)
            };

            typus_nft::emit_mint_event(&nft, user);

            let level = typus_nft::tails_level(&nft);

            let (mut kiosk, kiosk_cap) = kiosk::new(ctx);
            kiosk::lock(&mut kiosk, &kiosk_cap, policy, nft);

            transfer::public_share_object(kiosk);
            transfer::public_transfer(kiosk_cap, user);

            // take coin
            let mut balance = coin::into_balance(coin);
            let len = vector::length(&pool.discount_pcts);
            let index = generate_answer(len, &hashed_beacon);
            let mut discount_pct = *vector::borrow(&pool.discount_pcts, index);

            if (coin_value == pool.price *  (100 - DISCOUNT_PCT)/ 100) {
                discount_pct = DISCOUNT_PCT;
            } else {
                let return_v = pool.price * discount_pct / 100;
                let return_c = coin::take<SUI>(&mut balance, return_v, ctx);
                transfer::public_transfer(return_c, user);
            };

            let discount_price = balance::value(&balance);
            balance::join(&mut pool.balance, balance);
            let event = DiscountEventV3 { pool: object::id(pool) , price: pool.price, discount_pct, discount_price, user, vrf_input, level };
            event::emit(event);
        } else {
            transfer::public_transfer(coin, user);
        }
    }

    /// Event emitted when a discount is applied.
    public struct DiscountEventV3 has copy, drop {
        pool: ID,
        price: u64,
        discount_pct: u64,
        discount_price: u64,
        user: address,
        vrf_input: vector<u8>,
        level: u64,
    }

    /// Refunds a mint request.
    /// Safe with `authority` check
    entry fun refund(
        pool: &mut Pool,
        ctx: & TxContext
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);

        let MintRequest {
            user,
            coin,
            vrf_input:_
        } = vector::remove(&mut pool.requests, 0);

        transfer::public_transfer(coin, user);
    }

    /// Closes the pool.
    /// Safe with `authority` check
    entry fun close(
        pool: &mut Pool,
        ctx: & TxContext
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);
        pool.is_live = false;
    }

    /// Starts a new round.
    /// Safe with `authority` check
    entry fun new_round(
        pool: &mut Pool,
        num: u64,
        price: u64, // SUI decimal 9
        start_ms: u64,
        end_ms: u64,
        ctx: & TxContext
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);
        pool.num = num;
        pool.price = price;
        pool.start_ms = start_ms;
        pool.end_ms = end_ms;
        if (dynamic_field::exists_(& pool.id, string::utf8(b"total"))){
            let total: &mut u64 = dynamic_field::borrow_mut(&mut pool.id, string::utf8(b"total"));
            *total = num;
        } else {
            dynamic_field::add(&mut pool.id, string::utf8(b"total"), num);
        }
    }

    /// Updates the discount percentages.
    /// Safe with `authority` check
    entry fun update_discount_pcts(
        pool: &mut Pool,
        discount_pcts: vector<u64>,
        ctx: & TxContext
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);
        pool.discount_pcts = discount_pcts;
    }

    /// Updates the end time of the mint.
    /// Safe with `authority` check
    entry fun update_end_ms(
        pool: &mut Pool,
        end_ms: u64,
        ctx: & TxContext
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);
        pool.end_ms = end_ms;
    }

    /// Adds users to the whitelist.
    /// Safe with `authority` check
    entry fun add_whitelist(
        pool: &mut Pool,
        mut users: vector<address>,
        ctx: &mut TxContext
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);

        if (dynamic_field::exists_(& pool.id, string::utf8(b"whitelist"))){
            let whitelist: &mut Table<address, bool> = dynamic_field::borrow_mut(&mut pool.id, string::utf8(b"whitelist"));
            while (!vector::is_empty(&users)) {
                let user = vector::pop_back(&mut users);
                table::add(whitelist, user, true);
            };
        } else {
            let mut whitelist = table::new<address, bool>(ctx);
            while (!vector::is_empty(&users)) {
                let user = vector::pop_back(&mut users);
                table::add(&mut whitelist, user, true);
            };
            dynamic_field::add(&mut pool.id, string::utf8(b"whitelist"), whitelist);
        }
    }

    /// Sends an NFT from the pool to the given recipient.
    /// Safe with `authority` check
    #[lint_allow(share_owned)]
    entry fun send_nft(
        _manager_cap: &typus_nft::ManagerCap,
        pool: &mut Pool,
        policy: &TransferPolicy<Tails>,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);

        let (mut kiosk, kiosk_cap) = kiosk::new(ctx);

        let nft = table_vec::pop_back(&mut pool.tails);
        typus_nft::emit_mint_event(&nft, recipient);
        pool.num = pool.num - 1;

        kiosk::lock(&mut kiosk, &kiosk_cap, policy, nft);

        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_cap, recipient);
    }

    /// Checks if a user is whitelisted.
    public(package) fun is_whitelist(
        pool: & Pool,
        user: address
    ): bool {
        if (dynamic_field::exists_(& pool.id, string::utf8(b"whitelist"))){
            let whitelist: & Table<address, bool> = dynamic_field::borrow(& pool.id, string::utf8(b"whitelist"));
            if (table::contains(whitelist, user)){
                return true
            };
        };
        return false
    }

    /// Withdraws the balance from the pool.
    /// Safe with `authority` check
    entry fun withdraw_balance(
        pool: &mut Pool,
        ctx: &mut TxContext
    ) {
        assert!(pool.authority == tx_context::sender(ctx), 0);
        let b = balance::withdraw_all(&mut pool.balance);
        let c = coin::from_balance(b, ctx);
        transfer::public_transfer(c, @TYPUS);
    }

    /// Generates a random number from a given seed.
    fun generate_answer(n: u64, rnd: &vector<u8>): u64 {
        assert!(vector::length(rnd) >= 16, E_INVALID_RND_LENGTH);
        let mut m: u128 = 0;
        let mut i = 0;
        while (i < 16) {
            m = m << 8;
            let curr_byte = *vector::borrow(rnd, i);
            m = m + (curr_byte as u128);
            i = i + 1;
        };
        let n_128 = (n as u128);
        let module_128  = m % n_128;
        let res = (module_128 as u64);
        res
    }
}