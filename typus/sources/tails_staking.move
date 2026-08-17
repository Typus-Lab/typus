// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module implements the staking functionality for Typus Tails NFTs.
/// It allows users to stake their Tails NFTs to earn rewards, participate in profit sharing,
/// and level up their NFTs by gaining experience points (EXP).
module typus::tails_staking {
    use std::bcs;
    use std::string;
    use std::type_name::{Self, TypeName};

    use sui::bag::{Self, Bag};
    use sui::balance::{Self, Balance};
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::object_table::{Self, ObjectTable};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use sui::transfer_policy::{Self, TransferPolicy};

    use typus::big_vector::{Self, BigVector};
    use typus::ecosystem::{ManagerCap, Version};
    use typus::user::{Self, TypusUserRegistry};
    use typus::utility;

    use typus_nft::typus_nft::{Self, Tails, ManagerCap as TailsManagerCap};

    /// Constant for the number of milliseconds in a day.
    const CMillisecondsADay: u64 = 24 * 60 * 60 * 1000;

    // ======== TailsStakingRegistry config Index ========

    /// Index for the maximum number of Tails a user can stake.
    const IMaxStakeAmount: u64 = 0;
    /// Index for the fee required to stake a Tails NFT (in SUI).
    const IStakeTailsFee: u64 = 1;
    /// Index for the fee required to transfer a Tails NFT (in SUI).
    const ITransferTailsFee: u64 = 2;
    /// Index for the amount of EXP gained from a daily sign-up.
    const IDailySignUpExp: u64 = 3;
    /// Index for the fee required for a daily sign-up (in SUI).
    const IDailySignUpFee: u64 = 4;
    /// Index for the fee required to convert EXP back to the user's balance (in SUI).
    const IExpDownFee: u64 = 5;

    // ======== StakingInfo u64_padding Index ========

    /// Index for the timestamp of the last daily sign-up.
    const ILastSignUpTsMs: u64 = 0;

    // ======== Tails Metadata Key ========

    /// Key for the vector of Tails NFT IDs.
    const KTailsIds: vector<u8> = b"tails_ids";                 // vector<address>
    /// Key for the vector of Tails NFT levels.
    const KTailsLevels: vector<u8> = b"tails_levels";           // vector<u64>
    /// Key for the table of Tails IPFS URLs.
    const KTailsIpfsUrls: vector<u8> = b"tails_ipfs_urls";      // Table<u64(level), BigVector(vector<u8>)>
    /// Key for the table of Tails WEBP images.
    const KTailsWebpImages: vector<u8> = b"tails_webp_images";  // Table<u64(level*10000+number), vector<u8>>

    // ======== Error Code ========

    /// Error when a user has already signed up for the day.
    #[error]
    const EAlreadySignedUp: vector<u8> = b"already_signed_up";
    /// Error for insufficient balance.
    #[error]
    const EInsufficientExp: vector<u8> = b"insufficient_exp";
    /// Error for an invalid fee amount.
    #[error]
    const EInvalidFee: vector<u8> = b"invalid_fee";
    /// Error for invalid input.
    #[error]
    const EInvalidInput: vector<u8> = b"invalid_input";
    /// Error for an invalid token type.
    #[error]
    const EInvalidToken: vector<u8> = b"invalid_token";
    /// Error when the maximum stake amount is reached.
    #[error]
    const EMaxStakeAmountReached: vector<u8> = b"max_stake_amount_reached";
    /// Error when staking information for a user is not found.
    #[error]
    const EStakingInfoNotFound: vector<u8> = b"staking_info_not_found";

    // ======== Tails Staking ========

    /// The main registry for the Tails NFT staking system.
    public struct TailsStakingRegistry has key {
        id: UID,
        /// A vector of configuration values for the staking system.
        config: vector<u64>,
        /// The manager capability for the Tails NFT contract.
        tails_manager_cap: TailsManagerCap,
        /// A table storing the staked Tails NFTs.
        tails: ObjectTable<address, Tails>,
        /// A bag for storing various metadata related to Tails NFTs.
        tails_metadata: Bag,
        /// A big vector of `StakingInfo` structs for all users.
        staking_infos: BigVector,
        /// A vector of token types that are used for profit sharing.
        profit_assets: vector<TypeName>,
        /// The transfer policy for Tails NFTs.
        transfer_policy: TransferPolicy<Tails>,
    }

    /// Stores staking information for a single user.
    public struct StakingInfo has store, drop {
        /// The address of the user.
        user: address,
        /// A vector of the numbers of the Tails NFTs staked by the user.
        tails: vector<u64>,
        /// A vector of the profits earned by the user from profit sharing.
        profits: vector<u64>,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// Initializes the `TailsStakingRegistry`.
    /// This is an authorized function.
    entry fun init_tails_staking_registry(
        version: &Version,
        tails_manager_cap: TailsManagerCap,
        transfer_policy: TransferPolicy<Tails>,
        ctx: &mut TxContext,
    ) {
        version.verify(ctx);

        let mut tails_metadata = bag::new(ctx);
        let mut tails_ipfs_urls = table::new(ctx);
        let mut i = 1;
        while (i <= 7) {
            table::add(&mut tails_ipfs_urls, i, big_vector::new<vector<u8>>(1111, ctx));
            i = i + 1;
        };
        bag::add(&mut tails_metadata, KTailsIpfsUrls, tails_ipfs_urls);
        bag::add(&mut tails_metadata, KTailsIds, vector<address>[]);
        bag::add(&mut tails_metadata, KTailsLevels, vector<u64>[]);
        bag::add(&mut tails_metadata, KTailsWebpImages, table::new<u64, vector<u8>>(ctx));
        transfer::share_object(TailsStakingRegistry {
            id: object::new(ctx),
            config: vector[
                5,              // IMaxStakeAmount, no greater than 10
                0_050000000,    // IStakeTailsFee, SUI
                0_010000000,    // ITransferTailsFee, SUI
                10,             // IDailySignUpExp
                0_050000000,    // IDailySignUpFee, SUI
                10_000000000,    // IExpDownFee, SUI
            ],
            tails_manager_cap,
            tails: object_table::new(ctx),
            tails_metadata,
            staking_infos: big_vector::new<StakingInfo>(1000, ctx),
            profit_assets: vector[],
            transfer_policy,
        });
    }

    /// Uploads a vector of placeholder IDs for Tails NFTs.
    /// This is an authorized function used for initialization.
    entry fun upload_ids(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        // mut count: u64,
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        let mut count = 6666;
        let tails_ids: &mut vector<address> = &mut tails_staking_registry.tails_metadata[KTailsIds];
        while (count > 0) {
            tails_ids.push_back(@0x0);
            count = count - 1;
        }
    }

    // entry fun remove_ids(
    //     version: &Version,
    //     tails_staking_registry: &mut TailsStakingRegistry,
    //     mut count: u64,
    //     ctx: &TxContext,
    // ) {
    //     version.verify(ctx);

    //     let tails_ids: &mut vector<address> = &mut tails_staking_registry.tails_metadata[KTailsIds];
    //     while (count > 0) {
    //         tails_ids.pop_back();
    //         count = count - 1;
    //     }
    // }

    /// Uploads a vector of placeholder levels for Tails NFTs.
    /// This is an authorized function used for initialization.
    entry fun upload_levels(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        // mut count: u64,
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        let mut count = 6666;
        let tails_levels: &mut vector<u64> = &mut tails_staking_registry.tails_metadata[KTailsLevels];
        while (count > 0) {
            tails_levels.push_back(0);
            count = count - 1;
        }
    }

    // entry fun remove_levels(
    //     version: &Version,
    //     tails_staking_registry: &mut TailsStakingRegistry,
    //     mut count: u64,
    //     ctx: &TxContext,
    // ) {
    //     version.verify(ctx);

    //     let tails_levels: &mut vector<u64> = &mut tails_staking_registry.tails_metadata[KTailsLevels];
    //     while (count > 0) {
    //         tails_levels.pop_back();
    //         count = count - 1;
    //     }
    // }

    /// Uploads IPFS URLs for a specific level of Tails NFTs.
    /// This is an authorized function.
    entry fun upload_ipfs_urls(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        level: u64,
        mut urls: vector<vector<u8>>, // reverse
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        let tails_ipfs_urls: &mut Table<u64, BigVector> = &mut tails_staking_registry.tails_metadata[KTailsIpfsUrls];
        let v = &mut tails_ipfs_urls[level];
        while (!urls.is_empty()) {
            v.push_back(urls.pop_back());
        }
    }

    /// Removes all IPFS URLs for a specific level.
    /// This is an authorized function.
    entry fun remove_ipfs_urls(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        level: u64,
        ctx: &mut TxContext,
    ) {
        version.verify(ctx);

        let tails_ipfs_urls: &mut Table<u64, BigVector> = &mut tails_staking_registry.tails_metadata[KTailsIpfsUrls];
        tails_ipfs_urls.remove(level).drop<vector<u8>>();
        tails_ipfs_urls.add(level, big_vector::new<vector<u8>>(1111, ctx));
    }

    /// Uploads the WEBP image bytes for a specific Tails NFT.
    /// This is an authorized function.
    entry fun upload_webp_bytes(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        number: u64,
        level: u64,
        mut bytes: vector<u8>, // reverse when extend
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        let tails_webp_images: &mut Table<u64, vector<u8>> = &mut tails_staking_registry.tails_metadata[KTailsWebpImages];
        if (!tails_webp_images.contains(level * 10000 + number)) {
            tails_webp_images.add(level * 10000 + number, bytes);
        } else {
            let v: &mut vector<u8> = &mut tails_webp_images[level * 10000 + number];
            while (!bytes.is_empty()) {
                v.push_back(bytes.pop_back());
            }
        };
    }

    /// Removes the WEBP image bytes for a specific Tails NFT.
    /// This is an authorized function.
    entry fun remove_webp_bytes(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        number: u64,
        level: u64,
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        let tails_webp_images: &mut Table<u64, vector<u8>> = &mut tails_staking_registry.tails_metadata[KTailsWebpImages];
        tails_webp_images.remove(level * 10000 + number);
    }

    /// Event emitted when the staking registry config is updated.
    public struct UpdateTailsStakingRegistryConfigEvent has copy, drop {
        index: u64,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Updates a configuration value in the `TailsStakingRegistry`.
    /// This is an authorized function.
    entry fun update_tails_staking_registry_config(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        index: u64,
        value: u64,
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        while (tails_staking_registry.config.length() < index + 1) {
            tails_staking_registry.config.push_back(0);
        };
        emit(UpdateTailsStakingRegistryConfigEvent {
            index,
            log: vector[tails_staking_registry.config[index], value],
            bcs_padding: vector[],
        });
        *&mut tails_staking_registry.config[index] = value;
    }

    /// Event emitted when profit sharing is set.
    public struct SetProfitSharingEvent has copy, drop {
        token: TypeName,
        level_profits: vector<u64>,
        level_counts: vector<u64>,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Sets the profit sharing for a specific token.
    /// This is an authorized function.
    entry fun set_profit_sharing<TOKEN, N_TOKEN>(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        level_profits: vector<u64>,
        profit: Coin<TOKEN>,
        amount: u64,
        ts_ms: u64,
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        let mut level_counts = vector[0, 0, 0, 0, 0, 0, 0];
        let mut total_profit = 0;
        let profit_asset = type_name::with_defining_ids<TOKEN>();
        let (profit_asset_exists, profit_asset_index) = tails_staking_registry.profit_assets.index_of(&profit_asset);
        let tails_levels: &vector<u64> = &tails_staking_registry.tails_metadata[KTailsLevels];
        let length = tails_staking_registry.staking_infos.length();
        let slice_size = (tails_staking_registry.staking_infos.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = tails_staking_registry.staking_infos.borrow_slice_mut(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            let staking_info: &mut StakingInfo = &mut slice[i % slice_size];
            let mut profit = 0;
            let mut j = 0;
            let length = staking_info.tails.length();
            while (j < length) {
                let tails_number = staking_info.tails[j];
                let tails_level = tails_levels[tails_number - 1];
                profit = profit + level_profits[tails_level - 1];
                *&mut level_counts[tails_level - 1] = level_counts[tails_level - 1] + 1;
                j = j + 1;
            };
            // update user profit
            staking_info.profits.push_back(profit);
            if (profit_asset_exists) {
                staking_info.profits.swap_remove(profit_asset_index);
            };
            total_profit = total_profit + profit;
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = tails_staking_registry.staking_infos.borrow_slice_mut(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };

        if (!profit_asset_exists) {
            tails_staking_registry.profit_assets.push_back(profit_asset);
            if (!dynamic_field::exists_(&tails_staking_registry.id, profit_asset)) {
                dynamic_field::add(&mut tails_staking_registry.id, profit_asset, balance::zero<TOKEN>());
            }
        };
        let shared_profit = dynamic_field::borrow_mut<TypeName, Balance<TOKEN>>(&mut tails_staking_registry.id, profit_asset);
        let spent_profit = profit.value();
        balance::join(shared_profit, coin::into_balance(profit));
        assert!(shared_profit.value() == total_profit, EInvalidInput);

        emit(SetProfitSharingEvent {
            token: profit_asset,
            level_profits,
            level_counts,
            log: vector[total_profit, spent_profit, amount, ts_ms],
            bcs_padding: vector[bcs::to_bytes(&type_name::with_defining_ids<N_TOKEN>())],
        });
    }

    /// Event emitted when profit sharing is removed.
    public struct RemoveProfitSharingEvent has copy, drop {
        token: TypeName,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Removes a profit sharing token from the registry.
    /// This is an authorized function.
    entry fun remove_profit_sharing<TOKEN>(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        version.verify(ctx);

        let profit_asset = type_name::with_defining_ids<TOKEN>();
        let (profit_asset_exists, profit_asset_index) = tails_staking_registry.profit_assets.index_of(&profit_asset);
        if (!profit_asset_exists) {
            abort EInvalidToken
        };
        tails_staking_registry.profit_assets.swap_remove(profit_asset_index);
        let length = tails_staking_registry.staking_infos.length();
        let slice_size = (tails_staking_registry.staking_infos.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = tails_staking_registry.staking_infos.borrow_slice_mut(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            let staking_info: &mut StakingInfo = &mut slice[i % slice_size];
            staking_info.profits.swap_remove(profit_asset_index);
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = tails_staking_registry.staking_infos.borrow_slice_mut(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };
        let shared_profit: Balance<TOKEN> = dynamic_field::remove(&mut tails_staking_registry.id, profit_asset);
        let balance = shared_profit.value();
        transfer::public_transfer(coin::from_balance(shared_profit, ctx), recipient);

        emit(RemoveProfitSharingEvent {
            token: profit_asset,
            log: vector[balance],
            bcs_padding: vector[],
        });
    }

    #[deprecated, allow(unused)]
    public fun import_tails(
        version: &mut Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        mut tailses: vector<Tails>,
        mut users: vector<address>,
        ctx: &TxContext,
    ) { abort 0 }

    /// Event emitted when a user claims their profit sharing.
    public struct ClaimProfitSharingEvent has copy, drop {
        tails: vector<u64>,
        profit_asset: TypeName,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Allows a user to claim their profit sharing for a specific token.
    /// Safe with ctx.sender as verification
    public fun claim_profit_sharing<TOKEN>(
        version: &mut Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        ctx: &mut TxContext,
    ): Balance<TOKEN> {
        version.version_check();

        let profit_asset = type_name::with_defining_ids<TOKEN>();
        let (profit_asset_exists, profit_asset_index) = tails_staking_registry.profit_assets.index_of(&profit_asset);
        if (!profit_asset_exists) {
            abort EInvalidToken
        };
        let user = ctx.sender();
        let length = tails_staking_registry.staking_infos.length();
        let slice_size = (tails_staking_registry.staking_infos.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = tails_staking_registry.staking_infos.borrow_slice_mut(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            let staking_info: &mut StakingInfo = &mut slice[i % slice_size];
            if (staking_info.user == user) {
                let profit_balance = dynamic_field::borrow_mut(&mut tails_staking_registry.id, profit_asset);
                emit(ClaimProfitSharingEvent {
                    tails: staking_info.tails,
                    profit_asset,
                    log: vector[staking_info.profits[profit_asset_index]],
                    bcs_padding: vector[],
                });
                let balance = balance::split(profit_balance, staking_info.profits[profit_asset_index]);
                *&mut staking_info.profits[profit_asset_index] = 0;
                return balance
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = tails_staking_registry.staking_infos.borrow_slice_mut(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };

        abort EStakingInfoNotFound
    }

    /// Event emitted when a Tails NFT is staked.
    public struct StakeTailsEvent has copy, drop {
        tails: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Stakes a Tails NFT.
    public fun stake_tails(
        version: &mut Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        kiosk: &mut Kiosk,
        kiosk_owner_cap: &KioskOwnerCap,
        tails: address,
        coin: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        version.version_check();

        assert!(coin.value() == tails_staking_registry.config[IStakeTailsFee], EInvalidFee);
        version.charge_fee(coin.into_balance());
        kiosk::list<Tails>(kiosk, kiosk_owner_cap, object::id_from_address(tails), 0);
        let (tails, request) = kiosk::purchase(kiosk, object::id_from_address(tails), coin::zero(ctx));
        transfer_policy::confirm_request(&tails_staking_registry.transfer_policy, request);
        let tails_address = object::id_address(&tails);
        let tails_number = typus_nft::tails_number(&tails);
        let tails_level = typus_nft::tails_level(&tails);
        stake_tails_(
            tails_staking_registry,
            tails,
            ctx.sender(),
        );

        emit(StakeTailsEvent {
            tails: tails_address,
            log: vector[
                tails_number,
                tails_level,
            ],
            bcs_padding: vector[],
        });
    }

    /// Event emitted when a Tails NFT is unstaked.
    public struct UnstakeTailsEvent has copy, drop {
        tails: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Unstakes a Tails NFT.
    /// Safe with ctx.sender as verification
    public fun unstake_tails(
        version: &mut Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        kiosk: &mut Kiosk,
        kiosk_owner_cap: &KioskOwnerCap,
        tails: address,
        ctx: &TxContext,
    ) {
        version.version_check();

        let tails = unstake_tails_(tails_staking_registry, tails, ctx.sender());
        let tails_address = object::id_address(&tails);
        let tails_number = typus_nft::tails_number(&tails);
        let tails_level = typus_nft::tails_level(&tails);
        kiosk::lock(kiosk, kiosk_owner_cap, &tails_staking_registry.transfer_policy, tails);

        emit(UnstakeTailsEvent {
            tails: tails_address,
            log: vector[
                tails_number,
                tails_level,
            ],
            bcs_padding: vector[],
        });
    }

    /// Event emitted when a Tails NFT is transferred.
    public struct TransferTailsEvent has copy, drop {
        tails: address,
        recipient: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Transfers a Tails NFT to another user.
    #[lint_allow(share_owned)]
    public fun transfer_tails(
        version: &mut Version,
        tails_staking_registry: &TailsStakingRegistry,
        kiosk: &mut Kiosk,
        kiosk_owner_cap: &KioskOwnerCap,
        tails: address,
        coin: Coin<SUI>,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        version.version_check();

        assert!(coin.value() == tails_staking_registry.config[ITransferTailsFee], EInvalidFee);
        version.charge_fee(coin.into_balance());
        kiosk::list<Tails>(kiosk, kiosk_owner_cap, object::id_from_address(tails), 0);
        let (tails, request) = kiosk::purchase(kiosk, object::id_from_address(tails), coin::zero(ctx));
        transfer_policy::confirm_request(&tails_staking_registry.transfer_policy, request);
        let tails_address = object::id_address(&tails);
        let tails_number = typus_nft::tails_number(&tails);
        let tails_level = typus_nft::tails_level(&tails);
        let (mut recipient_kiosk, recipient_kiosk_owner_cap) = kiosk::new(ctx);
        kiosk::lock(&mut recipient_kiosk, &recipient_kiosk_owner_cap, &tails_staking_registry.transfer_policy, tails);
        transfer::public_share_object(recipient_kiosk);
        transfer::public_transfer(recipient_kiosk_owner_cap, recipient);

        emit(TransferTailsEvent {
            tails: tails_address,
            recipient,
            log: vector[
                tails_number,
                tails_level,
            ],
            bcs_padding: vector[],
        });
    }

    /// Event emitted when a user performs a daily sign-up.
    public struct DailySignUpEvent has copy, drop {
        tails: vector<u64>,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Allows a user to perform a daily sign-up to earn EXP for their staked Tails NFTs.
    /// Safe with ctx.sender as verification
    entry fun daily_sign_up(
        version: &mut Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        coin: Coin<SUI>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        version.version_check();

        assert!(coin.value() == tails_staking_registry.config[IDailySignUpFee], EInvalidFee);
        version.charge_fee(coin.into_balance());
        let user = ctx.sender();
        let tails_ids: &vector<address> = &tails_staking_registry.tails_metadata[KTailsIds];
        let length = tails_staking_registry.staking_infos.length();
        let slice_size = (tails_staking_registry.staking_infos.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = tails_staking_registry.staking_infos.borrow_slice_mut(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            let staking_info: &mut StakingInfo = &mut slice[i % slice_size];
            if (staking_info.user == user) {
                let ts_ms = clock.timestamp_ms();
                if (ts_ms / CMillisecondsADay - staking_info.u64_padding[ILastSignUpTsMs] / CMillisecondsADay == 0) {
                    abort EAlreadySignedUp
                };
                *&mut staking_info.u64_padding[ILastSignUpTsMs] = ts_ms;
                let mut i = 0;
                let length = staking_info.tails.length();
                let exp = tails_staking_registry.config[IDailySignUpExp];
                while (i < length) {
                    let tails_number = staking_info.tails[i];
                    let tails = &mut tails_staking_registry.tails[tails_ids[tails_number - 1]];
                    typus_nft::nft_exp_up(
                        &tails_staking_registry.tails_manager_cap,
                        tails,
                        exp,
                    );
                    i = i + 1;
                };

                emit(DailySignUpEvent {
                    tails: staking_info.tails,
                    log: vector[
                        exp,
                        tails_staking_registry.config[IDailySignUpFee],
                    ],
                    bcs_padding: vector[],
                });
                return
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = tails_staking_registry.staking_infos.borrow_slice_mut(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };

        abort EStakingInfoNotFound
    }

    /// Event emitted when a Tails NFT's EXP is increased.
    public struct ExpUpEvent has copy, drop {
        tails: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Increases the EXP of a staked Tails NFT.
    /// Safe with ctx.sender as verification
    public fun exp_up(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        typus_user_registry: &mut TypusUserRegistry,
        tails: address,
        amount: u64,
        ctx: &TxContext,
    ) {
        let user = tx_context::sender(ctx);
        assert!(verify_staking(version, tails_staking_registry, user, tails), EStakingInfoNotFound);

        if (!tails_staking_registry.tails.contains(tails)) {
            abort EStakingInfoNotFound
        };
        let tails = &mut tails_staking_registry.tails[tails];
        typus_nft::nft_exp_up(
            &tails_staking_registry.tails_manager_cap,
            tails,
            amount,
        );
        user::remove_tails_exp_amount_(
            version,
            typus_user_registry,
            user,
            amount,
        );
        let tails_address = object::id_address(tails);
        let tails_number = typus_nft::tails_number(tails);

        emit(ExpUpEvent {
            tails: tails_address,
            log: vector[tails_number, amount],
            bcs_padding: vector[],
        });
    }
    /// Increases the EXP of a non-staked Tails NFT.
    public fun exp_up_without_staking(
        version: &Version,
        tails_staking_registry: &TailsStakingRegistry,
        typus_user_registry: &mut TypusUserRegistry,
        kiosk: &mut Kiosk,
        kiosk_owner_cap: &KioskOwnerCap,
        tails: address,
        amount: u64,
        ctx: &TxContext,
    ) {
        version.version_check();

        let tails = kiosk.borrow_mut(kiosk_owner_cap, object::id_from_address(tails));
        typus_nft::nft_exp_up(
            &tails_staking_registry.tails_manager_cap,
            tails,
            amount,
        );
        user::remove_tails_exp_amount_(
            version,
            typus_user_registry,
            tx_context::sender(ctx),
            amount,
        );
        let tails_address = object::id_address(tails);
        let tails_number = typus_nft::tails_number(tails);

        emit(ExpUpEvent {
            tails: tails_address,
            log: vector[tails_number, amount],
            bcs_padding: vector[],
        });
    }
    /// Publicly increases the EXP of a staked Tails NFT.
    /// This is an authorized function that requires a `ManagerCap`.
    public fun public_exp_up(
        _manager_cap: &ManagerCap,
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        tails: address,
        amount: u64,
    ) {
        version.version_check();

        if (!tails_staking_registry.tails.contains(tails)) {
            abort EStakingInfoNotFound
        };
        let tails = &mut tails_staking_registry.tails[tails];
        typus_nft::nft_exp_up(
            &tails_staking_registry.tails_manager_cap,
            tails,
            amount,
        );
        let tails_address = object::id_address(tails);
        let tails_number = typus_nft::tails_number(tails);

        emit(ExpUpEvent {
            tails: tails_address,
            log: vector[tails_number, amount],
            bcs_padding: vector[],
        });
    }
    /// Publicly increases the EXP of a non-staked Tails NFT.
    /// This is an authorized function that requires a `ManagerCap`.
    public fun public_exp_up_without_staking(
        _manager_cap: &ManagerCap,
        version: &Version,
        tails_staking_registry: &TailsStakingRegistry,
        kiosk: &mut Kiosk,
        kiosk_owner_cap: &KioskOwnerCap,
        tails: address,
        amount: u64,
    ) {
        version.version_check();

        let tails = kiosk.borrow_mut(kiosk_owner_cap, object::id_from_address(tails));
        typus_nft::nft_exp_up(
            &tails_staking_registry.tails_manager_cap,
            tails,
            amount,
        );
        let tails_address = object::id_address(tails);
        let tails_number = typus_nft::tails_number(tails);

        emit(ExpUpEvent {
            tails: tails_address,
            log: vector[tails_number, amount],
            bcs_padding: vector[],
        });
    }

    /// Event emitted when a Tails NFT's EXP is decreased.
    public struct ExpDownEvent has copy, drop {
        tails: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Decreases the EXP of a staked Tails NFT, with a fee.
    /// Safe with ctx.sender as verification
    public fun exp_down_with_fee(
        version: &mut Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        typus_user_registry: &mut TypusUserRegistry,
        tails: address,
        amount: u64,
        coin: Coin<SUI>,
        ctx: &TxContext,
    ) {
        let user = tx_context::sender(ctx);
        assert!(verify_staking(version, tails_staking_registry, user, tails), EStakingInfoNotFound);

        assert!(coin.value() == tails_staking_registry.config[IExpDownFee], EInvalidFee);
        version.charge_fee(coin.into_balance());
        if (!tails_staking_registry.tails.contains(tails)) {
            abort EStakingInfoNotFound
        };
        let tails = &mut tails_staking_registry.tails[tails];
        typus_nft::nft_exp_down(
            &tails_staking_registry.tails_manager_cap,
            tails,
            amount,
        );
        user::add_tails_exp_amount_(
            version,
            typus_user_registry,
            tx_context::sender(ctx),
            amount,
        );
        let opt_level = typus_nft::level_up(&tails_staking_registry.tails_manager_cap, tails);
        let tails_address = object::id_address(tails);
        let tails_number = typus_nft::tails_number(tails);
        let tails_level = typus_nft::tails_level(tails);
        if (opt_level.is_some()) {
            let tails_ipfs_urls: &Table<u64, BigVector> = &tails_staking_registry.tails_metadata[KTailsIpfsUrls];
            typus_nft::update_image_url(
                &tails_staking_registry.tails_manager_cap,
                tails,
                tails_ipfs_urls[tails_level][tails_number - 1],
            );
        };
        let tails_levels: &mut vector<u64> = &mut tails_staking_registry.tails_metadata[KTailsLevels];
        *&mut tails_levels[tails_number - 1] = tails_level;

        emit(ExpDownEvent {
            tails: tails_address,
            log: vector[tails_number, amount],
            bcs_padding: vector[],
        });
    }
    /// Decreases the EXP of a non-staked Tails NFT, with a fee.
    public fun exp_down_without_staking_with_fee(
        version: &mut Version,
        tails_staking_registry: &TailsStakingRegistry,
        typus_user_registry: &mut TypusUserRegistry,
        kiosk: &mut Kiosk,
        kiosk_owner_cap: &KioskOwnerCap,
        tails: address,
        amount: u64,
        coin: Coin<SUI>,
        ctx: &TxContext,
    ) {
        version.version_check();

        assert!(coin.value() == tails_staking_registry.config[IExpDownFee], EInvalidFee);
        version.charge_fee(coin.into_balance());
        let tails = kiosk.borrow_mut(kiosk_owner_cap, object::id_from_address(tails));
        typus_nft::nft_exp_down(
            &tails_staking_registry.tails_manager_cap,
            tails,
            amount,
        );
        user::add_tails_exp_amount_(
            version,
            typus_user_registry,
            tx_context::sender(ctx),
            amount,
        );
        let opt_level = typus_nft::level_up(&tails_staking_registry.tails_manager_cap, tails);
        let tails_address = object::id_address(tails);
        let tails_number = typus_nft::tails_number(tails);
        let tails_level = typus_nft::tails_level(tails);
        if (opt_level.is_some()) {
            let tails_ipfs_urls: &Table<u64, BigVector> = &tails_staking_registry.tails_metadata[KTailsIpfsUrls];
            typus_nft::update_image_url(
                &tails_staking_registry.tails_manager_cap,
                tails,
                tails_ipfs_urls[tails_level][tails_number - 1],
            );
        };

        emit(ExpDownEvent {
            tails: tails_address,
            log: vector[tails_number, amount],
            bcs_padding: vector[],
        });
    }
    /// Publicly decreases the EXP of a staked Tails NFT.
    /// This is an authorized function that requires a `ManagerCap`.
    public fun public_exp_down(
        _manager_cap: &ManagerCap,
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        tails: address,
        amount: u64,
    ) {
        version.version_check();

        if (!tails_staking_registry.tails.contains(tails)) {
            abort EStakingInfoNotFound
        };
        let tails = &mut tails_staking_registry.tails[tails];
        typus_nft::nft_exp_down(
            &tails_staking_registry.tails_manager_cap,
            tails,
            amount,
        );
        let tails_address = object::id_address(tails);
        let tails_number = typus_nft::tails_number(tails);
        let tails_level = typus_nft::tails_level(tails);
        let opt_level = typus_nft::level_up(&tails_staking_registry.tails_manager_cap, tails);
        if (opt_level.is_some()) {
            let tails_ipfs_urls: &Table<u64, BigVector> = &tails_staking_registry.tails_metadata[KTailsIpfsUrls];
            typus_nft::update_image_url(
                &tails_staking_registry.tails_manager_cap,
                tails,
                tails_ipfs_urls[tails_level][tails_number - 1],
            );
        };
        let tails_levels: &mut vector<u64> = &mut tails_staking_registry.tails_metadata[KTailsLevels];
        *&mut tails_levels[tails_number - 1] = tails_level;

        emit(ExpDownEvent {
            tails: tails_address,
            log: vector[tails_number, amount],
            bcs_padding: vector[],
        });
    }
    /// Publicly decreases the EXP of a non-staked Tails NFT.
    /// This is an authorized function that requires a `ManagerCap`.
    public fun public_exp_down_without_staking(
        _manager_cap: &ManagerCap,
        version: &Version,
        tails_staking_registry: &TailsStakingRegistry,
        kiosk: &mut Kiosk,
        kiosk_owner_cap: &KioskOwnerCap,
        tails: address,
        amount: u64,
    ) {
        version.version_check();

        let tails = kiosk.borrow_mut(kiosk_owner_cap, object::id_from_address(tails));
        typus_nft::nft_exp_down(
            &tails_staking_registry.tails_manager_cap,
            tails,
            amount,
        );
        let tails_address = object::id_address(tails);
        let tails_number = typus_nft::tails_number(tails);
        let tails_level = typus_nft::tails_level(tails);
        let opt_level = typus_nft::level_up(&tails_staking_registry.tails_manager_cap, tails);
        if (opt_level.is_some()) {
            let tails_ipfs_urls: &Table<u64, BigVector> = &tails_staking_registry.tails_metadata[KTailsIpfsUrls];
            typus_nft::update_image_url(
                &tails_staking_registry.tails_manager_cap,
                tails,
                tails_ipfs_urls[tails_level][tails_number - 1],
            );
        };

        emit(ExpDownEvent {
            tails: tails_address,
            log: vector[tails_number, amount],
            bcs_padding: vector[],
        });
    }

    /// Event emitted when a Tails NFT levels up.
    public struct LevelUpEvent has copy, drop {
        tails: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Levels up a staked Tails NFT.
    /// WARNING: no owner check
    entry fun level_up(
        version: &Version,
        tails_staking_registry: &mut TailsStakingRegistry,
        tails: address,
        raw: bool,
    ) {
        version.version_check();

        if (!tails_staking_registry.tails.contains(tails)) {
            abort EStakingInfoNotFound
        };
        let tails = &mut tails_staking_registry.tails[tails];
        let opt_level = typus_nft::level_up(&tails_staking_registry.tails_manager_cap, tails);
        if (opt_level.is_none()) {
            abort EInsufficientExp
        };
        let tails_address = object::id_address(tails);
        let tails_number = typus_nft::tails_number(tails);
        let tails_level = typus_nft::tails_level(tails);
        if (raw) {
            let tails_webp_images: &Table<u64, vector<u8>> = &tails_staking_registry.tails_metadata[KTailsWebpImages];
            typus_nft::update_image_url(
                &tails_staking_registry.tails_manager_cap,
                tails,
                tails_webp_images[tails_level * 10000 + tails_number],
            );
        } else {
            let tails_ipfs_urls: &Table<u64, BigVector> = &tails_staking_registry.tails_metadata[KTailsIpfsUrls];
            typus_nft::update_image_url(
                &tails_staking_registry.tails_manager_cap,
                tails,
                tails_ipfs_urls[tails_level][tails_number - 1],
            );
        };
        let tails_levels: &mut vector<u64> = &mut tails_staking_registry.tails_metadata[KTailsLevels];
        *&mut tails_levels[tails_number - 1] = tails_level;

        emit(LevelUpEvent {
            tails: tails_address,
            log: vector[tails_number, tails_level],
            bcs_padding: vector[],
        });
    }

    /// Internal function to handle the logic of staking a Tails NFT.
    fun stake_tails_(
        tails_staking_registry: &mut TailsStakingRegistry,
        mut tails: Tails,
        user: address,
    ) {
        let tails_ids: &mut vector<address> = &mut tails_staking_registry.tails_metadata[KTailsIds];
        *&mut tails_ids[typus_nft::tails_number(&tails) - 1] = object::id_address(&tails);
        let tails_levels: &mut vector<u64> = &mut tails_staking_registry.tails_metadata[KTailsLevels];
        *&mut tails_levels[typus_nft::tails_number(&tails) - 1] = typus_nft::tails_level(&tails);
        let length = tails_staking_registry.staking_infos.length();
        let slice_size = (tails_staking_registry.staking_infos.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = tails_staking_registry.staking_infos.borrow_slice<StakingInfo>(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            if (slice[i % slice_size].user == user) {
                break
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = tails_staking_registry.staking_infos.borrow_slice(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };
        if (i == length) {
            let mut profits = vector[];
            utility::pad_u64_vector(&mut profits, tails_staking_registry.profit_assets.length() - 1);
            tails_staking_registry.staking_infos.push_back(
                StakingInfo {
                    user,
                    tails: vector[],
                    profits,
                    u64_padding: vector[0],
                }
            );
        };
        let staking_info: &mut StakingInfo = &mut tails_staking_registry.staking_infos[i];
        assert!(staking_info.tails.length() < tails_staking_registry.config[IMaxStakeAmount], EMaxStakeAmountReached);
        staking_info.tails.push_back(typus_nft::tails_number(&tails));
        if (typus_nft::contains_u64_padding(&tails_staking_registry.tails_manager_cap, &tails, string::utf8(b"updating_url"))) {
            typus_nft::remove_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tails, string::utf8(b"updating_url"));
        };
        if (typus_nft::contains_u64_padding(&tails_staking_registry.tails_manager_cap, &tails, string::utf8(b"attendance_ms"))) {
            typus_nft::remove_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tails, string::utf8(b"attendance_ms"));
        };
        if (typus_nft::contains_u64_padding(&tails_staking_registry.tails_manager_cap, &tails, string::utf8(b"snapshot_ms"))) {
            typus_nft::remove_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tails, string::utf8(b"snapshot_ms"));
        };
        if (typus_nft::contains_u64_padding(&tails_staking_registry.tails_manager_cap, &tails, string::utf8(b"usd_in_deposit"))) {
            typus_nft::remove_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tails, string::utf8(b"usd_in_deposit"));
        };
        if (typus_nft::contains_u64_padding(&tails_staking_registry.tails_manager_cap, &tails, string::utf8(b"dice_profit"))) {
            typus_nft::remove_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tails, string::utf8(b"dice_profit"));
        };
        if (typus_nft::contains_u64_padding(&tails_staking_registry.tails_manager_cap, &tails, string::utf8(b"exp_profit"))) {
            typus_nft::remove_u64_padding(&tails_staking_registry.tails_manager_cap, &mut tails, string::utf8(b"exp_profit"));
        };
        tails_staking_registry.tails.add(object::id_address(&tails), tails);
    }

    /// Internal function to handle the logic of unstaking a Tails NFT.
    fun unstake_tails_(
        tails_staking_registry: &mut TailsStakingRegistry,
        tails: address,
        user: address,
    ): Tails {
        let tails_ids: &vector<address> = &tails_staking_registry.tails_metadata[KTailsIds];
        let length = tails_staking_registry.staking_infos.length();
        let slice_size = (tails_staking_registry.staking_infos.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = tails_staking_registry.staking_infos.borrow_slice_mut(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            let staking_info: &mut StakingInfo = &mut slice[i % slice_size];
            if (staking_info.user == user) {
                let mut j = 0;
                let length = staking_info.tails.length();
                while (j < length) {
                    if (tails_ids[staking_info.tails[j] - 1] == tails) {
                        staking_info.tails.remove(j);
                        let tails = tails_staking_registry.tails.remove(tails);
                        if (staking_info.tails.is_empty()) {
                            tails_staking_registry.staking_infos.swap_remove<StakingInfo>(i);
                        };
                        return tails
                    };
                    j = j + 1;
                };
                break
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = tails_staking_registry.staking_infos.borrow_slice_mut(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };

        abort EStakingInfoNotFound
    }

    /// Retrieves the staking information for a specific user.
    public(package) fun get_staking_info(
        version: &Version,
        tails_staking_registry: &TailsStakingRegistry,
        user: address,
    ): vector<u8> {
        version.version_check();

        let length = tails_staking_registry.staking_infos.length();
        let slice_size = (tails_staking_registry.staking_infos.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = tails_staking_registry.staking_infos.borrow_slice<StakingInfo>(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            if (slice[i % slice_size].user == user) {
                return bcs::to_bytes(&slice[i % slice_size])
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = tails_staking_registry.staking_infos.borrow_slice(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };

        vector[]
    }

    /// Retrieves all staking information for a specific user.
    public(package) fun get_staking_infos(
        version: &Version,
        tails_staking_registry: &TailsStakingRegistry,
        user: address,
    ): vector<vector<u8>> {
        version.version_check();

        let mut result = vector[];
        let length = tails_staking_registry.staking_infos.length();
        let slice_size = (tails_staking_registry.staking_infos.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = tails_staking_registry.staking_infos.borrow_slice<StakingInfo>(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            if (slice[i % slice_size].user == user) {
                result.push_back(bcs::to_bytes(&slice[i % slice_size]));
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = tails_staking_registry.staking_infos.borrow_slice(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };

        result
    }

    /// Retrieves the counts of staked Tails NFTs for each level.
    public(package) fun get_level_counts(
        version: &Version,
        tails_staking_registry: &TailsStakingRegistry,
    ): vector<u64> {
        version.version_check();

        let mut level_counts = vector[0, 0, 0, 0, 0, 0, 0];
        let tails_levels: &vector<u64> = &tails_staking_registry.tails_metadata[KTailsLevels];
        let length = tails_staking_registry.staking_infos.length();
        let slice_size = (tails_staking_registry.staking_infos.slice_size() as u64);
        let mut slice_idx = 0;
        let mut slice = tails_staking_registry.staking_infos.borrow_slice(slice_idx);
        let mut slice_length = slice.get_slice_length();
        let mut i = 0;
        while (i < length) {
            let staking_info: &StakingInfo = &slice[i % slice_size];
            let mut j = 0;
            let length = staking_info.tails.length();
            while (j < length) {
                let tails_number = staking_info.tails[j];
                let tails_level = tails_levels[tails_number - 1];
                *&mut level_counts[tails_level - 1] = level_counts[tails_level - 1] + 1;
                j = j + 1;
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = slice.get_slice_idx() + 1;
                slice = tails_staking_registry.staking_infos.borrow_slice(slice_idx);
                slice_length = slice.get_slice_length();
            };
            i = i + 1;
        };

        level_counts
    }

    /// Verifies if a user has a staked Tails NFT of the certain address.
    public fun verify_staking(
        version: &Version,
        tails_staking_registry: &TailsStakingRegistry,
        user: address,
        tails: address,
    ): bool {
        version.version_check();

        let tails_ids: &vector<address> = &tails_staking_registry.tails_metadata[KTailsIds];
        let length = big_vector::length(&tails_staking_registry.staking_infos);
        let slice_size = (big_vector::slice_size(&tails_staking_registry.staking_infos) as u64);
        let mut slice_idx = 0;
        let mut slice = big_vector::borrow_slice(&tails_staking_registry.staking_infos, slice_idx);
        let mut slice_length = big_vector::get_slice_length(slice);
        let mut i = 0;
        while (i < length) {
            let staking_info = big_vector::borrow_from_slice<StakingInfo>(slice, i % slice_size);
            if (staking_info.user == user) {
                let mut i = 0;
                let length = vector::length(&staking_info.tails);
                while (i < length) {
                    let tails_number = *vector::borrow(&staking_info.tails, i);
                    if (*vector::borrow(tails_ids, tails_number - 1) == tails) {
                        return true
                    };
                    i = i + 1;
                };
                return false
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = big_vector::get_slice_idx(slice) + 1;
                slice = big_vector::borrow_slice(
                    &tails_staking_registry.staking_infos,
                    slice_idx,
                );
                slice_length = big_vector::get_slice_length(slice);
            };
            i = i + 1;
        };

        false
    }

    /// Verifies if a user has a staked Tails NFT of a certain level or higher.
    public fun verify_staking_identity(
        version: &Version,
        tails_staking_registry: &TailsStakingRegistry,
        user: address,
        level: u64,
    ): bool {
        version.version_check();

        if (level == 0) {
            return true
        };
        let tails_levels: &vector<u64> = bag::borrow(&tails_staking_registry.tails_metadata, KTailsLevels);
        let length = big_vector::length(&tails_staking_registry.staking_infos);
        let slice_size = (big_vector::slice_size(&tails_staking_registry.staking_infos) as u64);
        let mut slice_idx = 0;
        let mut slice = big_vector::borrow_slice(&tails_staking_registry.staking_infos, slice_idx);
        let mut slice_length = big_vector::get_slice_length(slice);
        let mut i = 0;
        while (i < length) {
            let staking_info = big_vector::borrow_from_slice<StakingInfo>(slice, i % slice_size);
            if (staking_info.user == user) {
                let mut i = 0;
                let length = vector::length(&staking_info.tails);
                while (i < length) {
                    let tails_number = *vector::borrow(&staking_info.tails, i);
                    if (*vector::borrow(tails_levels, tails_number - 1) >= level) {
                        return true
                    };
                    i = i + 1;
                };
                return false
            };
            // jump to next slice
            if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                slice_idx = big_vector::get_slice_idx(slice) + 1;
                slice = big_vector::borrow_slice(
                    &tails_staking_registry.staking_infos,
                    slice_idx,
                );
                slice_length = big_vector::get_slice_length(slice);
            };
            i = i + 1;
        };

        false
    }

    /// Retrieves the maximum level of a user's staked Tails NFTs.
    public fun get_max_staking_level(
        version: &Version,
        tails_staking_registry: &TailsStakingRegistry,
        user: address,
    ): u64 {
        version.version_check();

        let mut level = 0;
        let tails_levels: &vector<u64> = bag::borrow(&tails_staking_registry.tails_metadata, KTailsLevels);
        let length = big_vector::length(&tails_staking_registry.staking_infos);
        if (length > 0) {
            let slice_size = (big_vector::slice_size(&tails_staking_registry.staking_infos) as u64);
            let mut slice_idx = 0;
            let mut slice = big_vector::borrow_slice(&tails_staking_registry.staking_infos, slice_idx);
            let mut slice_length = big_vector::get_slice_length(slice);
            let mut i = 0;
            while (i < length) {
                let staking_info = big_vector::borrow_from_slice<StakingInfo>(slice, i % slice_size);
                if (staking_info.user == user) {
                    let mut i = 0;
                    let length = vector::length(&staking_info.tails);
                    while (i < length) {
                        let tails_number = *vector::borrow(&staking_info.tails, i);
                        if (tails_levels[tails_number - 1] > level) {
                            level = tails_levels[tails_number - 1];
                        };
                        i = i + 1;
                    };
                    break
                };
                // jump to next slice
                if (i + 1 < length && i + 1 == slice_idx * slice_size + slice_length) {
                    slice_idx = big_vector::get_slice_idx(slice) + 1;
                    slice = big_vector::borrow_slice(
                        &tails_staking_registry.staking_infos,
                        slice_idx,
                    );
                    slice_length = big_vector::get_slice_length(slice);
                };
                i = i + 1;
            };
        };

        level
    }

    #[deprecated(note = b"Use `exp_down_with_fee` instead.")]
    public fun exp_down(
        _version: &Version,
        _tails_staking_registry: &mut TailsStakingRegistry,
        _typus_user_registry: &mut TypusUserRegistry,
        _tails: address,
        _amount: u64,
        _ctx: &TxContext,
    ) {
        abort 0
    }
    #[deprecated(note = b"Use `exp_down_without_staking_with_fee` instead.")]
    public fun exp_down_without_staking(
        _version: &Version,
        _tails_staking_registry: &TailsStakingRegistry,
        _typus_user_registry: &mut TypusUserRegistry,
        _kiosk: &mut Kiosk,
        _kiosk_owner_cap: &KioskOwnerCap,
        _tails: address,
        _amount: u64,
        _ctx: &TxContext,
    ) {
        abort 0
    }
}