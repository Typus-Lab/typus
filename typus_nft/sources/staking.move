/// This module implements the staking functionality for Typus NFTs.
/// Users can stake their NFTs to earn experience points and level up.
/// Deprecated: use `typus/sources/tails_staking.move` instead.
module typus_nft::staking {
    use sui::event;
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::dynamic_field;
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};

    use typus_nft::typus_nft::{Self, Tails, ManagerCap as NftManagerCap};

    const E_INVALID_REGISTRY: u64 = 0;
    const E_ALREADY_STAKING: u64 = 1;
    const E_NO_STAKING: u64 = 2;
    const E_IN_COOLDOWN: u64 = 3;
    const E_UPDATING_URL: u64 = 4;

    // Registry of typus_dov_single
    /// The registry for the staking module.
    public struct Registry has key {
        id: UID,
    }

    /// A capability that allows the owner to manage the staking module.
    public struct ManagerCap has key {
        id: UID,
    }

    /// A staked Typus NFT.
    public struct StakingTails has store {
        nft: Tails,
        snapshot_ms: u64,
        updating_url: bool,
    }

    /// The NFT extension for the staking module.
    public struct NftExtension has store {
        nft_table: Table<address, StakingTails>,
        nft_manager_cap: NftManagerCap,
    }

    /// Initializes the staking module.
    fun init(ctx: &mut TxContext) {
        let registry = Registry { id: object::new(ctx) };
        let manager_cap = ManagerCap { id: object::new(ctx) };

        transfer::share_object(registry);
        transfer::transfer(manager_cap, tx_context::sender(ctx));
    }

    /// Adds the NFT extension to the registry.
    public fun add_nft_extension(
        registry: &mut Registry,
        nft_manager_cap: NftManagerCap,
        ctx: &mut TxContext
    ) {
        // E_INVALID_REGISTRY if exists
        assert!(!dynamic_field::exists_(&registry.id, b"nft_extension"), E_INVALID_REGISTRY);

        let nft_table = table::new<address, StakingTails>(ctx);
        dynamic_field::add(&mut registry.id, b"nft_extension",
            NftExtension {
                nft_table,
                nft_manager_cap
            }
        );
    }

    /// Stakes an NFT.
    public fun stake_nft(
        registry: &mut Registry,
        kiosk: &mut Kiosk,
        kiosk_cap: &KioskOwnerCap,
        id: ID,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // E_INVALID_REGISTRY if not exists
        assert!(dynamic_field::exists_(&registry.id, b"nft_extension"), E_INVALID_REGISTRY);

        let nft_extension: &mut NftExtension = dynamic_field::borrow_mut(&mut registry.id, b"nft_extension");
        let nft_table = &mut nft_extension.nft_table;

        let nft = kiosk::take(kiosk, kiosk_cap, id);

        let staking_nft = StakingTails { nft, snapshot_ms: clock::timestamp_ms(clock), updating_url: false};

        assert!(!table::contains(nft_table, tx_context::sender(ctx)), E_ALREADY_STAKING);
        table::add(nft_table, tx_context::sender(ctx), staking_nft);

        // StakeEvent
    }

    /// Unstakes an NFT.
    public fun unstake_nft(
        registry: &mut Registry,
        kiosk: &mut Kiosk,
        kiosk_cap: &KioskOwnerCap,
        ctx: &mut TxContext
    ) {
        // E_INVALID_REGISTRY if not exists
        assert!(dynamic_field::exists_(&registry.id, b"nft_extension"), E_INVALID_REGISTRY);

        let nft_extension: &mut NftExtension = dynamic_field::borrow_mut(&mut registry.id, b"nft_extension");
        let nft_table = &mut nft_extension.nft_table;

        assert!(table::contains(nft_table, tx_context::sender(ctx)), E_NO_STAKING);
        let staking_nft = table::remove(nft_table, tx_context::sender(ctx));
        let StakingTails { nft, snapshot_ms:_, updating_url } = staking_nft;
        assert!(!updating_url, E_UPDATING_URL);
        kiosk::place(kiosk, kiosk_cap, nft);

        // UnstakeEvent
    }

    /// Takes a snapshot of the staked NFT to earn experience points.
    public fun snapshot(
        registry: &mut Registry,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // E_INVALID_REGISTRY if not exists
        assert!(dynamic_field::exists_(&registry.id, b"nft_extension"), E_INVALID_REGISTRY);

        let nft_extension: &mut NftExtension = dynamic_field::borrow_mut(&mut registry.id, b"nft_extension");
        let nft_table = &mut nft_extension.nft_table;

        assert!(table::contains(nft_table, tx_context::sender(ctx)), E_NO_STAKING);
        let staking_nft = table::borrow_mut<address, StakingTails>(nft_table, tx_context::sender(ctx));

        let ms = clock::timestamp_ms(clock);

        assert!(ms - staking_nft.snapshot_ms >= 86_400_000, E_IN_COOLDOWN);

        staking_nft.snapshot_ms = ms;
        typus_nft::nft_exp_up(&nft_extension.nft_manager_cap, &mut staking_nft.nft, 10);
    }

    /// Marks the staked NFT as having made its first bid.
    public fun first_bid(
        registry: &mut Registry,
        ctx: &mut TxContext
    ) {
        // E_INVALID_REGISTRY if not exists
        assert!(dynamic_field::exists_(&registry.id, b"nft_extension"), E_INVALID_REGISTRY);

        let nft_extension: &mut NftExtension = dynamic_field::borrow_mut(&mut registry.id, b"nft_extension");
        let nft_table = &mut nft_extension.nft_table;

        if (table::contains(nft_table, tx_context::sender(ctx))) {
            let staking_nft = table::borrow_mut<address, StakingTails>(nft_table, tx_context::sender(ctx));
            typus_nft::first_bid(&nft_extension.nft_manager_cap, &mut staking_nft.nft);
        }

        // ....

    }

    /// Marks the staked NFT as having made its first deposit.
    public fun first_deposit(
        registry: &mut Registry,
        ctx: &mut TxContext
    ) {
        // E_INVALID_REGISTRY if not exists
        assert!(dynamic_field::exists_(&registry.id, b"nft_extension"), E_INVALID_REGISTRY);

        let nft_extension: &mut NftExtension = dynamic_field::borrow_mut(&mut registry.id, b"nft_extension");
        let nft_table = &mut nft_extension.nft_table;

        if (table::contains(nft_table, tx_context::sender(ctx))) {
            let staking_nft = table::borrow_mut<address, StakingTails>(nft_table, tx_context::sender(ctx));
            typus_nft::first_deposit(&nft_extension.nft_manager_cap, &mut staking_nft.nft);
        }

        // ....

    }

    /// Event emitted when a staked NFT levels up.
    public struct LevelUpEvent has copy, drop {
        nft_id: ID,
        sender: address,
        number: u64,
        level: u64
    }

    /// Levels up a staked NFT.
    public fun level_up(
        registry: &mut Registry,
        ctx: &mut TxContext
    ) {
        // E_INVALID_REGISTRY if not exists
        assert!(dynamic_field::exists_(&registry.id, b"nft_extension"), E_INVALID_REGISTRY);

        let nft_extension: &mut NftExtension = dynamic_field::borrow_mut(&mut registry.id, b"nft_extension");
        let nft_table = &mut nft_extension.nft_table;
        let sender = tx_context::sender(ctx);

        assert!(table::contains(nft_table, tx_context::sender(ctx)), E_NO_STAKING);

        let staking_nft = table::borrow_mut<address, StakingTails>(nft_table, sender);
        let mut opt_level = typus_nft::level_up(&nft_extension.nft_manager_cap, &mut staking_nft.nft);
        if (option::is_some(&opt_level)) {
            let level = option::extract(&mut opt_level);
            let number = typus_nft::tails_number(&staking_nft.nft);
            let event = LevelUpEvent { nft_id: object::id(&staking_nft.nft), sender, number, level };
            event::emit(event);
            staking_nft.updating_url = true;
        }
    }

    // Admin Functions

    /// Updates the image URL of a staked NFT.
    public fun update_image_url(
        registry: &mut Registry,
        _manager_cap: &ManagerCap,
        owner: address,
        url: vector<u8>,
    ) {
        // E_INVALID_REGISTRY if not exists
        assert!(dynamic_field::exists_(&registry.id, b"nft_extension"), E_INVALID_REGISTRY);

        let nft_extension: &mut NftExtension = dynamic_field::borrow_mut(&mut registry.id, b"nft_extension");
        let nft_table = &mut nft_extension.nft_table;

        assert!(table::contains(nft_table, owner), E_NO_STAKING);
        let staking_nft = table::borrow_mut<address, StakingTails>(nft_table, owner);
        typus_nft::update_image_url(&nft_extension.nft_manager_cap, &mut staking_nft.nft, url);
        staking_nft.updating_url = false;
    }

    /// Adds experience points to a staked NFT.
    public fun add_exp(
        registry: &mut Registry,
        _manager_cap: &ManagerCap,
        owner: address,
        exp: u64,
    ) {
        // E_INVALID_REGISTRY if not exists
        assert!(dynamic_field::exists_(&registry.id, b"nft_extension"), E_INVALID_REGISTRY);

        let nft_extension: &mut NftExtension = dynamic_field::borrow_mut(&mut registry.id, b"nft_extension");
        let nft_table = &mut nft_extension.nft_table;

        assert!(table::contains(nft_table, owner), E_NO_STAKING);
        let staking_nft = table::borrow_mut<address, StakingTails>(nft_table, owner);
        typus_nft::nft_exp_up(&nft_extension.nft_manager_cap, &mut staking_nft.nft, exp);
    }

}

// TODO:
// add version?
// add events