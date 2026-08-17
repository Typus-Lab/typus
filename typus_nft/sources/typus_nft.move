/// This module implements the Typus NFT collection.
/// It includes functionality for minting, managing, and staking NFTs.
module typus_nft::typus_nft {
    use std::string::{Self, String};

    use sui::url::{Self, Url};
    use sui::display;
    use sui::coin;
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::balance;
    use sui::vec_map::{Self, VecMap};
    use sui::transfer_policy::{Self, TransferPolicy, TransferPolicyCap};
    use sui::event;
    use sui::clock::{Clock};

    use kiosk::royalty_rule as kiosk_royalty_rule;
    use kiosk::kiosk_lock_rule;

    use typus_nft::royalty_rule::{Self, Rule, Config};
    use typus_nft::utils;
    use typus_nft::table_vec::{Self, TableVec};

    const E_INVALID_WHITELIST: u64 = 1;
    const E_INVALID_NUM: u64 = 2;
    const E_EMPTY_POOL: u64 = 3;
    const E_NOT_START: u64 = 4;
    const E_NOT_LIVE: u64 = 5;
    const E_INVALID_VEC: u64 = 6;
    const E_INVALID_INDEX: u64 = 7;

    /* friend typus_nft::discount_mint; */

    /// One time witness is only instantiated in the init method
    public struct TYPUS_NFT has drop {}

    /// The Typus NFT object.
    public struct Tails has key, store {
        id: UID,
        /// The name of the NFT.
        name: String,
        /// The description of the NFT.
        description: String,
        /// The number of the NFT.
        number: u64,
        /// The URL of the NFT image.
        url: Url,
        /// The attributes of the NFT.
        attributes: VecMap<String, String>,
        /// The level of the NFT.
        level: u64,
        /// The experience points of the NFT.
        exp: u64,
        /// Whether the NFT has made its first bid.
        first_bid: bool,
        /// Whether the NFT has made its first deposit.
        first_deposit: bool,
        /// Whether the NFT has made its first NFT deposit.
        first_deposit_nft: bool,
        /// Padding for future use.
        u64_padding: VecMap<String, u64>,
    }

    /// A capability that allows the owner to manage the NFT collection.
    public struct ManagerCap has key, store { id: UID }

    const MAX_BPS: u64 = 10_000;

    /// The royalty object.
    public struct Royalty has key {
        id: UID,
        /// The recipients of the royalty.
        recipients: VecMap<address, u64>,
        /// The transfer policy capability for the royalty.
        policy_cap: TransferPolicyCap<Tails>
    }


    /// Initializes the NFT module.
    #[lint_allow(self_transfer, share_owned)]
    fun init(otw: TYPUS_NFT, ctx: &mut TxContext) {
        let publisher = sui::package::claim(otw, ctx);

        let mut display = display::new<Tails>(&publisher, ctx);
        display::add(&mut display, string::utf8(b"name"), string::utf8(b"{name}"));
        display::add(&mut display, string::utf8(b"description"), string::utf8(b"{description}"));
        display::add(&mut display, string::utf8(b"image_url"), string::utf8(b"{url}"));
        display::add(&mut display, string::utf8(b"attributes"), string::utf8(b"{attributes}"));
        display::add(&mut display, string::utf8(b"level"), string::utf8(b"{level}"));
        display::add(&mut display, string::utf8(b"exp"), string::utf8(b"{exp}"));
        display::update_version(&mut display);

        let manager_cap = ManagerCap { id: object::new(ctx) };

        let (mut policy, policy_cap) = transfer_policy::new<Tails>(&publisher, ctx);
        royalty_rule::add(&mut policy, &policy_cap, 1_000, 1_000_000_000); // MAX(10%, 1 SUI)

        let mut recipients = vec_map::empty();
        vec_map::insert(&mut recipients, @TYPUS, 5_000);
        vec_map::insert(&mut recipients, @SM, 2_000);
        vec_map::insert(&mut recipients, @HOLDERS, 3_000);

        let royalty = Royalty {
            id: object::new(ctx),
            recipients,
            policy_cap
        };

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(display, sender);
        transfer::public_transfer(manager_cap, sender);
        transfer::public_share_object(policy);
        // transfer::public_transfer(policy_cap, sender);
        transfer::share_object(royalty);

        let event = RoyaltyUpdateEvent {
            sender,
            recipients,
        };
        event::emit(event);
    }

    /// Withdraws the royalty from the transfer policy.
    /// Safe with `ManagerCap` check
    entry fun withdraw_royalty(
        _manager_cap: &ManagerCap,
        royalty: &Royalty,
        policy: &mut TransferPolicy<Tails>,
        ctx: &mut TxContext,
    ) {
        let mut total = transfer_policy::withdraw(policy, &royalty.policy_cap, option::none(), ctx);
        let total_v = coin::value(&total);
        let balance_mut = coin::balance_mut(&mut total);

        let mut k = vec_map::keys(&royalty.recipients);

        while (vector::length(&k) > 0) {
            let recipient = vector::pop_back(&mut k);
            let share = *vec_map::get(&royalty.recipients, &recipient);
            let value = if (vector::length(&k) > 0) { total_v * share / MAX_BPS } else { balance::value(balance_mut) };

            let c = coin::take(balance_mut, value, ctx);
            transfer::public_transfer(c, recipient);
        };

        coin::destroy_zero(total);
    }

    /// Event emitted when the royalty is updated.
    public struct RoyaltyUpdateEvent has copy, drop {
        sender: address,
        recipients: VecMap<address, u64>,
    }

    /// Updates the royalty recipients and shares.
    /// Safe with `ManagerCap` check
    entry fun update_royalty(
        _manager_cap: &ManagerCap,
        royalty: &mut Royalty,
        mut recipients: vector<address>,
        mut shares: vector<u64>,
        ctx: &TxContext,
    ) {
        assert!(vector::length(&recipients) == vector::length(&shares), E_INVALID_VEC);

        let mut v = vec_map::empty();

        while (vector::length(&recipients) > 0) {
            let recipient = vector::pop_back(&mut recipients);
            let share = vector::pop_back(&mut shares);
            vec_map::insert(&mut v, recipient, share);
        };

        royalty.recipients = v;

        let event = RoyaltyUpdateEvent {
            sender: tx_context::sender(ctx),
            recipients: v
        };
        event::emit(event);
    }

    /// Updates the policy rules for the NFT collection.
    /// Safe with `ManagerCap` check
    entry fun update_policy_rules(
        _manager_cap: &ManagerCap,
        policy: &mut TransferPolicy<Tails>,
        royalty: &Royalty,
    ) {
        // 1. remove
        transfer_policy::remove_rule<Tails, Rule, Config>(policy, &royalty.policy_cap);

        // 2. add royalty_rule
        kiosk_royalty_rule::add(policy, &royalty.policy_cap, 1_000, 1_000_000_000); // MAX(10%, 1 SUI)

        // 3. add kiosk_lock_rule
        kiosk_lock_rule::add(policy, &royalty.policy_cap);
    }

    /// The NFT pool object.
    public struct Pool has key {
        id: UID,
        /// The NFTs in the pool.
        tails: TableVec<Tails>,
        /// The number of NFTs in the pool.
        num: u64,
        /// Whether the pool is live.
        is_live: bool,
        /// The start time of the pool in milliseconds.
        start_ms: u64, // 18_446_744_073_709_551_615
    }

    /// Creates a new NFT pool.
    /// Safe with `ManagerCap` check
    entry fun new_pool(
        _manager_cap: &ManagerCap,
        start_ms: u64,
        ctx: &mut TxContext,
    ) {
        let pool = Pool {
            id: object::new(ctx),
            tails: table_vec::empty(ctx),
            num: 0,
            is_live: false,
            start_ms
        };
        transfer::share_object(pool);
    }

    /// Closes an NFT pool.
    /// Safe with `ManagerCap` check
    entry fun close_pool(
        _manager_cap: &ManagerCap,
        pool: Pool,
    ) {
        let Pool {
            id,
            tails,
            num:_,
            is_live:_,
            start_ms:_
        } = pool;

        table_vec::destroy_empty(tails);
        object::delete(id);
    }

    /// Event emitted when a new manager capability is created.
    public struct NewManagerCapEvent has copy, drop {
        id: ID,
        sender: address
    }

    /// Creates a new manager capability.
    /// Safe with `ManagerCap` check
    #[lint_allow(self_transfer)]
    entry fun new_manager_cap (
        _manager_cap: &ManagerCap,
        ctx: &mut TxContext,
    ) {
        let manager_cap = ManagerCap { id: object::new(ctx) };
        let sender = tx_context::sender(ctx);

        let new_manager_cap_event = NewManagerCapEvent {
            id: object::id(&manager_cap),
            sender
        };
        event::emit(new_manager_cap_event);

        transfer::public_transfer(manager_cap, sender);
    }

    /// Deposits an NFT into the pool.
    /// Safe with `ManagerCap` check
    entry fun deposit_nft(
        _manager_cap: &ManagerCap,
        pool: &mut Pool,
        name: String,
        number: u64,
        url: vector<u8>,
        attribute_keys: vector<String>,
        attribute_values: vector<String>,
        ctx: &mut TxContext,
    ) {
        let url = url::new_unsafe_from_bytes(url);
        let attributes = utils::from_vec_to_map(attribute_keys, attribute_values);
        let nft = new_nft(name, number, url, attributes, ctx);

        table_vec::push_back(&mut pool.tails, nft);
        pool.num = pool.num + 1;
    }

    /// Creates a new NFT.
    fun new_nft(
        name: String,
        number: u64,
        url: Url,
        attributes: VecMap<String, String>,
        ctx: &mut TxContext,
    ): Tails {

        let mut description = string::utf8(b"Tails /6,666 by Typus Finance.");

        let len = string::length(&name);
        let num_str = string::substring(&name, 16, len);
        string::insert(&mut description, 6, num_str);

        let nft = Tails {
            id: object::new(ctx),
            name,
            number,
            description,
            url,
            attributes,
            level: 1,
            exp: 0,
            first_bid: false,
            first_deposit: false,
            first_deposit_nft: false,
            u64_padding: vec_map::empty()
        };

        nft
    }

    /// The whitelist object.
    public struct Whitelist has key {
        id: UID,
        `for`: ID
    }

    /// Issues whitelist tokens to the given recipients.
    /// Safe with `ManagerCap` check
    entry fun issue_whitelist(
        _manager_cap: &ManagerCap,
        pool: &Pool,
        mut recipients: vector<address>,
        ctx: &mut TxContext,
    ) {
        while (!vector::is_empty(&recipients)) {
            let recipient = vector::pop_back<address>(&mut recipients);
            let id = object::id(pool);
            let wl = Whitelist{ id: object::new(ctx), `for`: id };
            transfer::transfer(wl, recipient);
        }
    }

    /// Updates the sale status of the pool.
    entry fun update_sale(
        _manager_cap: &ManagerCap,
        pool: &mut Pool,
        is_live: bool,
    ) {
        pool.is_live = is_live;
    }

    /// Updates the start time of the pool.
    /// Safe with `ManagerCap` check
    entry fun update_start_ms(
        _manager_cap: &ManagerCap,
        pool: &mut Pool,
        start_ms: u64,
    ) {
        pool.start_ms = start_ms;
    }

    /// Sends NFTs from the pool to the given recipient.
    #[lint_allow(share_owned)]
    /// Safe with `ManagerCap` check
    entry fun send_nfts(
        _manager_cap: &ManagerCap,
        pool: &mut Pool,
        policy: &TransferPolicy<Tails>,
        recipient: address,
        mut n: u64,
        ctx: &mut TxContext,
    ) {
        let (mut kiosk, kiosk_cap) = kiosk::new(ctx);

        while (n > 0) {
            let nft = table_vec::pop_back(&mut pool.tails);

            let mint_event = MintEvent {
                id: object::id(&nft),
                name: nft.name,
                description: nft.description,
                number: nft.number,
                url: nft.url,
                attributes: nft.attributes,
                sender: tx_context::sender(ctx)
            };
            event::emit(mint_event);

            kiosk::lock(&mut kiosk, &kiosk_cap, policy, nft);
            n = n - 1;
        };

        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_cap, recipient);
    }

    /// Withdraws NFTs from the pool.
    public(package) fun withdraw_nfts(
        _manager_cap: &ManagerCap,
        pool: &mut Pool,
        mut n: u64
    ): vector<Tails> {
        let mut nfts = vector::empty<Tails>();
        while (n > 0) {
            let nft = table_vec::pop_back(&mut pool.tails);
            vector::push_back(&mut nfts, nft);
            n = n - 1;
        };
        nfts
    }

    /// Resends the mint event for the given NFT.
    /// Safe with `ManagerCap` check
    entry fun resend_nfts_event(
        _manager_cap: &ManagerCap,
        id: address,
        name: String,
        number: u64,
        url: vector<u8>,
        attribute_keys: vector<String>,
        attribute_values: vector<String>,
        ctx: & TxContext,
    ) {
        let url = url::new_unsafe_from_bytes(url);
        let attributes = utils::from_vec_to_map(attribute_keys, attribute_values);

        let mut description = string::utf8(b"Tails /6,666 by Typus Finance.");

        let len = string::length(&name);
        let num_str = string::substring(&name, 16, len);
        string::insert(&mut description, 6, num_str);

        let mint_event = MintEvent {
            id: object::id_from_address(id),
            name,
            description,
            number,
            url,
            attributes,
            sender: tx_context::sender(ctx)
        };
        event::emit(mint_event);
    }

    /// Returns the experience points required for the given level.
    /// 1_000, 50_000, 250_000, 1_000_000, 5_000_000, 20_000_000
    fun get_level_exp(level: u64): u64 {
        let exp = if (level == 2) { 1_000 }
            else if (level == 3) { 50_000 }
            else if (level == 4) { 250_000 }
            else if (level == 5) { 1_000_000 }
            else if (level == 6) { 5_000_000 }
            else if (level == 7) { 20_000_000 }
            else { 0 };
        exp
    }

    /// Sets the level of the first n NFTs in the pool.
    /// Safe with `ManagerCap` check
    entry fun pool_set_n_level(
        _manager_cap: &ManagerCap,
        pool: &mut Pool,
        num: u64,
        level: u64,
    ) {
        let len = table_vec::length(&pool.tails);
        assert!(len >= num, E_INVALID_NUM);

        let exp = get_level_exp(level);

        let mut i = 0;

        while (i < num) {
            let nft = table_vec::borrow_mut(&mut pool.tails, i);

            nft.exp = exp;
            level_up(_manager_cap, nft);

            i = i + 1;
        };
    }

    /// Updates an NFT in the pool.
    /// Safe with `ManagerCap` check
    entry fun update_pool_nft(
        manager_cap: &ManagerCap,
        pool: &mut Pool,
        index: u64,
        id: ID,
        level: u64,
        url: vector<u8>,
    ) {
        let nft = table_vec::borrow_mut(&mut pool.tails, index);
        update_nft(manager_cap, nft, id, level, url);
    }

    /// Updates an NFT.
    public(package) fun update_nft(
        manager_cap: &ManagerCap,
        nft: &mut Tails,
        id: ID,
        level: u64,
        url: vector<u8>,
    ) {
        let exp = get_level_exp(level);
        assert!(object::id(nft) == id, E_INVALID_INDEX);
        nft.exp = exp;
        nft.url = url::new_unsafe_from_bytes(url);
        level_up(manager_cap, nft);
    }

    // Staking Related
    /// Updates the image URL of the NFT.
    /// Safe with `ManagerCap` check
    public fun update_image_url(
        _manager_cap: &ManagerCap,
        tails: &mut Tails,
        url: vector<u8>,
    ) {
        tails.url = url::new_unsafe_from_bytes(url);
    }

    /// Event emitted when an NFT gains experience points.
    public struct ExpUpEvent has copy, drop {
        nft_id: ID,
        number: u64,
        exp_earn: u64
    }

    /// Increases the experience points of an NFT.
    /// Safe with `ManagerCap` check
    public fun nft_exp_up(
        _manager_cap: &ManagerCap,
        nft_mut: &mut Tails,
        exp: u64,
    ) {
        nft_mut.exp = nft_mut.exp + exp;

        let event = ExpUpEvent {
            nft_id: object::id(nft_mut),
            number: nft_mut.number,
            exp_earn: exp
        };
        event::emit(event);
    }

    /// Event emitted when an NFT loses experience points.
    public struct ExpDownEvent has copy, drop {
        nft_id: ID,
        number: u64,
        exp_remove: u64
    }

    /// Decreases the experience points of an NFT.
    /// Safe with `ManagerCap` check
    public fun nft_exp_down(
        _manager_cap: &ManagerCap,
        nft_mut: &mut Tails,
        exp: u64,
    ) {
        nft_mut.exp = nft_mut.exp - exp;

        let event = ExpDownEvent {
            nft_id: object::id(nft_mut),
            number: nft_mut.number,
            exp_remove: exp
        };
        event::emit(event);
    }

    /// Event emitted when an NFT makes its first bid.
    public struct FirstBidEvent has copy, drop {
        nft_id: ID,
        number: u64,
        exp_earn: u64
    }

    /// Marks an NFT as having made its first bid and increases its experience points.
    /// Safe with `ManagerCap` check
    public fun first_bid(
        _manager_cap: &ManagerCap,
        nft_mut: &mut Tails,
    ) {
        if (!nft_mut.first_bid) {
            nft_mut.first_bid = true;
            nft_mut.exp = nft_mut.exp + 500;
            let event = FirstBidEvent {
                nft_id: object::id(nft_mut),
                number: nft_mut.number,
                exp_earn: 500
            };
            event::emit(event);
        }
    }

    /// Event emitted when an NFT makes its first deposit.
    public struct FirstDepositEvent has copy, drop {
        nft_id: ID,
        number: u64,
        exp_earn: u64
    }

    /// Marks an NFT as having made its first deposit and increases its experience points.
    /// Safe with `ManagerCap` check
    public fun first_deposit(
        _manager_cap: &ManagerCap,
        nft_mut: &mut Tails,
    ) {
        if (!nft_mut.first_deposit) {
            nft_mut.first_deposit = true;
            nft_mut.exp = nft_mut.exp + 100;
            let event = FirstDepositEvent {
                nft_id: object::id(nft_mut),
                number: nft_mut.number,
                exp_earn: 100
            };
            event::emit(event);
        }
    }

    /// Marks an NFT as having made its first NFT deposit and increases its experience points.
    /// Safe with `ManagerCap` check
    public fun first_deposit_nft(
        _manager_cap: &ManagerCap,
        nft_mut: &mut Tails,
    ) {
        if (!nft_mut.first_deposit_nft) {
            nft_mut.first_deposit_nft = true;
            nft_mut.exp = nft_mut.exp + 1000;
        }
    }

    /// Event emitted when an NFT levels up.
    public struct LevelUpEvent has copy, drop {
        nft_id: ID,
        level: u64
    }

    /// Levels up an NFT if it has enough experience points.
    /// Safe with `ManagerCap` check
    public fun level_up(
        _manager_cap: &ManagerCap,
        nft_mut: &mut Tails,
    ): Option<u64> {
        let original_level = nft_mut.level;

        let level = if (nft_mut.exp >= get_level_exp(7)) { 7 }
                else if (nft_mut.exp >= get_level_exp(6)) { 6 }
                else if (nft_mut.exp >= get_level_exp(5)) { 5 }
                else if (nft_mut.exp >= get_level_exp(4)) { 4 }
                else if (nft_mut.exp >= get_level_exp(3)) { 3 }
                else if (nft_mut.exp >= get_level_exp(2)) { 2 }
                else { 1 };

        nft_mut.level = level;

        if (original_level != level) {
            let level_up_event = LevelUpEvent {
                nft_id: object::id(nft_mut),
                level: nft_mut.level
            };
            event::emit(level_up_event);

            option::some(nft_mut.level)
        } else {
            option::none()
        }
    }


    // Extension
    /// Inserts a key-value pair into the u64 padding of the NFT.
    /// Safe with `ManagerCap` check
    public fun insert_u64_padding(
        _manager_cap: &ManagerCap,
        nft_mut: &mut Tails,
        key: String,
        value: u64
    ) {
        vec_map::insert(&mut nft_mut.u64_padding, key, value);
    }

    /// Checks if the u64 padding of the NFT contains the given key.
    /// Safe with `ManagerCap` check
    public fun contains_u64_padding(
        _manager_cap: &ManagerCap,
        nft_mut: &Tails,
        key: String,
    ): bool {
        vec_map::contains(& nft_mut.u64_padding, &key)
    }

    /// Returns the value associated with the given key in the u64 padding of the NFT.
    /// Safe with `ManagerCap` check
    public fun get_u64_padding(
        _manager_cap: &ManagerCap,
        nft_mut: &Tails,
        key: String,
    ): u64 {
        *vec_map::get(& nft_mut.u64_padding, &key)
    }

    /// Updates the value associated with the given key in the u64 padding of the NFT.
    /// Safe with `ManagerCap` check
    public fun update_u64_padding(
        _manager_cap: &ManagerCap,
        nft_mut: &mut Tails,
        key: String,
        value: u64
    ) {
        let mut_v = vec_map::get_mut(&mut nft_mut.u64_padding, &key);
        *mut_v = value;
    }

    /// Removes the key-value pair with the given key from the u64 padding of the NFT.
    /// Safe with `ManagerCap` check
    public fun remove_u64_padding(
        _manager_cap: &ManagerCap,
        nft_mut: &mut Tails,
        key: String,
    ) {
        vec_map::remove(&mut nft_mut.u64_padding, &key);
    }

    // User Entry
    /// Event emitted when an NFT is minted.
    public struct MintEvent has copy, drop {
        id: ID,
        name: String,
        description: String,
        number: u64,
        url: Url,
        attributes: VecMap<String, String>,
        sender: address
    }

    /// Emits a mint event.
    public(package) fun emit_mint_event(nft: &Tails, sender: address) {
        let mint_event = MintEvent {
            id: object::id(nft),
            name: nft.name,
            description: nft.description,
            number: nft.number,
            url: nft.url,
            attributes: nft.attributes,
            sender
        };
        event::emit(mint_event);
    }

    /// Mints an NFT from the pool.
    fun mint(
        pool: &mut Pool,
        whitelist_token: Whitelist,
        _clock: &Clock,
        ctx: &mut TxContext,
    ): Tails {
        // let ms = clock::timestamp_ms(clock);
        assert!(18_446_744_073_709_551_615 == pool.start_ms, E_NOT_START);
        assert!(pool.is_live, E_NOT_LIVE);

        let len = table_vec::length(&pool.tails);
        assert!(len > 0, E_EMPTY_POOL);

        let Whitelist {id, `for`} = whitelist_token;
        object::delete(id);
        assert!(`for` == object::id(pool), E_INVALID_WHITELIST);

        let nft = if (len == 1) {
            table_vec::pop_back(&mut pool.tails)
        } else {
            let random = utils::rand(ctx);
            let i  = random % ((len-1) as u256);
            table_vec::swap(&mut pool.tails, (i as u64), len-1);
            table_vec::pop_back(&mut pool.tails)
        };

        let mint_event = MintEvent {
            id: object::id(&nft),
            name: nft.name,
            description: nft.description,
            number: nft.number,
            url: nft.url,
            attributes: nft.attributes,
            sender: tx_context::sender(ctx)
        };

        event::emit(mint_event);
        nft
    }

    /// Mints an NFT for free.
    #[lint_allow(self_transfer, share_owned)]
    entry fun free_mint(
        pool: &mut Pool,
        policy: &TransferPolicy<Tails>,
        whitelist_token: Whitelist,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let nft = mint(pool, whitelist_token, clock, ctx);

        let (mut kiosk, kiosk_cap) = kiosk::new(ctx);
        kiosk::lock(&mut kiosk, &kiosk_cap, policy, nft);

        let sender = tx_context::sender(ctx);
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_cap, sender);
    }

    /// Mints an NFT for free into a kiosk.
    entry fun free_mint_into_kiosk(
        pool: &mut Pool,
        policy: &TransferPolicy<Tails>,
        whitelist_token: Whitelist,
        kiosk: &mut Kiosk,
        kiosk_cap: &KioskOwnerCap,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let nft = mint(pool, whitelist_token, clock, ctx);

        kiosk::lock(kiosk, kiosk_cap, policy, nft);
    }

    // Public Functions

    /// Returns the number of the NFT.
    public fun tails_number(
        nft: &Tails,
    ): u64 {
        nft.number
    }

    /// Returns the level of the NFT.
    public fun tails_level(
        nft: &Tails,
    ): u64 {
        nft.level
    }

    /// Returns the experience points of the NFT.
    public fun tails_exp(
        nft: &Tails,
    ): u64 {
        nft.exp
    }

    /// Returns the attributes of the NFT.
    public fun tails_attributes(
        nft: &Tails,
    ): VecMap<String, String> {
        nft.attributes
    }

    /// Initializes the NFT module for testing.
    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(TYPUS_NFT {}, ctx);
    }

    #[test_only]
    public fun test_mint(number: u64, ctx: &mut TxContext): Tails {
        let mut name = b"Tails By Typus ".to_string();
        name.append(number.to_string());

        new_nft(
            name,
            number,
            url::new_unsafe_from_bytes(b"https://docs.typus.finance/"),
            vec_map::empty(),
            ctx,
        )
    }
}

    // TODO:
    // add version
    // redeem_nft

    // public fun level_up_with_sui(
    //     nft_mut: &mut Tails,
    //     coins: vector<Coin<sui::sui::SUI>>,
    //     amount: u64,
    //     ctx: &mut TxContext,
    // ) {
    //     let balance = utils::extract_balance(coins, amount, ctx);
    //     let exp = balance::value(&balance) / 1000000000 * 100;
    //     nft_mut.exp = nft_mut.exp + exp;

    //     let coin = coin::from_balance(balance, ctx);
    //     transfer::public_transfer(coin, @TYPUS);
    // }
