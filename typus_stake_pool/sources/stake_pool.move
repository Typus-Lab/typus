module typus_stake_pool::stake_pool {
    use std::type_name::{Self, TypeName};
    use std::string::{Self, String};

    use sui::bcs;
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::dynamic_object_field;
    use sui::table::{Table};
    use sui::vec_map::{Self, VecMap};
    use sui::event::emit;

    use typus_stake_pool::admin::{Self, Version};

    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::user::TypusUserRegistry;
    use typus::keyed_big_vector::{Self, KeyedBigVector};

    // ======== Constants ========
    const C_INCENTIVE_INDEX_DECIMAL: u64 = 9;

    // ======== Keys ========
    const K_LP_USER_SHARES: vector<u8> = b"lp_user_shares";
    const K_LP_USER_SHARES_V2: vector<u8> = b"lp_user_shares_v2";
    const K_STAKED_TLP: vector<u8> = b"staked_tlp";

    // ======== Errors ========
    const E_TOKEN_TYPE_MISMATCHED: u64 = 0;
    // const E_USER_SHARE_NOT_EXISTED: u64 = 1;
    const E_INCENTIVE_TOKEN_NOT_EXISTED: u64 = 3;
    const E_INCENTIVE_TOKEN_ALREADY_EXISTED: u64 = 4;
    // const E_USER_MISMATCHED: u64 = 5;
    const E_ACTIVE_SHARES_NOT_ENOUGH: u64 = 6;
    // const E_ZERO_UNLOCK_COUNTDOWN: u64 = 7;
    const E_OUTDATED_HARVEST_STATUS: u64 = 8;
    const E_INCENTIVE_TOKEN_NOT_ENOUGH: u64 = 9;
    const E_TIMESTAMP_MISMATCHED: u64 = 10;
    const E_ZERO_INCENTIVE_INTERVAL: u64 = 11;

    /// A registry for all stake pools.
    public struct StakePoolRegistry has key {
        id: UID,
        /// The number of pools in the registry.
        num_pool: u64,
    }

    /// A struct that represents a stake pool.
    public struct StakePool has key, store {
        id: UID,
        /// Information about the stake pool.
        pool_info: StakePoolInfo,
        /// Configuration for the stake pool.
        config: StakePoolConfig,
        /// A vector of the incentives in the stake pool.
        incentives: vector<Incentive>,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// A struct that holds information about an incentive.
    public struct Incentive has copy, drop, store {
        /// The type name of the incentive token.
        token_type: TypeName,
        /// The configuration for the incentive.
        config: IncentiveConfig,
        /// Information about the incentive.
        info: IncentiveInfo
    }

    /// Information about a stake pool.
    public struct StakePoolInfo has copy, drop, store {
        /// The type name of the stake token.
        stake_token: TypeName,
        /// The index of the pool.
        index: u64,
        /// The next user share ID.
        next_user_share_id: u64,
        /// The total number of shares in the pool.
        total_share: u64, // = total staked and has not been unsubscribed
        /// Whether the pool is active.
        active: bool,
        /// Padding for future use. [new_tlp_price (decimal 4), usd_per_exp, depositors_count]
        u64_padding: vector<u64>,
    }

    /// Configuration for a stake pool.
    public struct StakePoolConfig has copy, drop, store {
        /// The unlock countdown in milliseconds.
        unlock_countdown_ts_ms: u64,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// Configuration for an incentive.
    public struct IncentiveConfig has copy, drop, store {
        /// The amount of incentive per period.
        period_incentive_amount: u64,
        /// The incentive interval in milliseconds.
        incentive_interval_ts_ms: u64,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// Information about an incentive.
    public struct IncentiveInfo has copy, drop, store {
        /// Whether the incentive is active.
        active: bool,
        /// The timestamp of the last allocation.
        last_allocate_ts_ms: u64, // record allocate ts ms for each I_TOKEN
        /// The price index for accumulating incentive.
        incentive_price_index: u64, // price index for accumulating incentive
        /// The unallocated amount of incentive.
        unallocated_amount: u64,
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// A struct that represents a user's share in a stake pool.
    public struct LpUserShare has store {
        /// The address of the user.
        user: address,
        /// The ID of the user's share.
        user_share_id: u64,
        /// The timestamp when the user staked.
        stake_ts_ms: u64,
        /// The total number of shares.
        total_shares: u64,
        /// The number of active shares.
        active_shares: u64,
        /// A vector of deactivating shares.
        deactivating_shares: vector<DeactivatingShares>,
        /// The last incentive price index.
        last_incentive_price_index: VecMap<TypeName, u64>,
        /// Padding for future use. [snapshot_ts_ms, old_tlp_price (decimal 4), is_auto_compound(deprecated), harvested_amount]
        u64_padding: vector<u64>,
    }

    /// A struct for deactivating shares.
    public struct DeactivatingShares has store {
        /// The number of shares.
        shares: u64,
        /// The timestamp when the user unsubscribed.
        unsubscribed_ts_ms: u64,
        /// The timestamp when the shares can be unlocked.
        unlocked_ts_ms: u64,
        /// The unsubscribed incentive price index.
        unsubscribed_incentive_price_index: VecMap<TypeName, u64>, // the share can only receive incentive until this index
        /// Padding for future use.
        u64_padding: vector<u64>,
    }

    /// Initializes the module.
    fun init(ctx: &mut TxContext) {
        let registry = StakePoolRegistry {
            id: object::new(ctx),
            num_pool: 0,
        };

        transfer::share_object(registry);
    }

    /// An event that is emitted when a new stake pool is created.
    public struct NewStakePoolEvent has copy, drop {
        sender: address,
        stake_pool_info: StakePoolInfo,
        stake_pool_config: StakePoolConfig,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Creates a new stake pool.
    entry fun new_stake_pool<LP_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        unlock_countdown_ts_ms: u64,
        ctx: &mut TxContext
    ) {
        // safety check
        admin::verify(version, ctx);
        // assert!(unlock_countdown_ts_ms > 0, E_ZERO_UNLOCK_COUNTDOWN);

        let mut id = object::new(ctx);
        let stake_token = type_name::with_defining_ids<LP_TOKEN>();

        // field for LP_TOKEN balance
        dynamic_field::add(&mut id, string::utf8(K_STAKED_TLP), balance::zero<LP_TOKEN>());

        // field for user share
        // dynamic_field::add(&mut id, string::utf8(K_LP_USER_SHARES), table::new<address, vector<LpUserShare>>(ctx));
        dynamic_field::add(&mut id, string::utf8(K_LP_USER_SHARES_V2), keyed_big_vector::new<address, LpUserShare>(1000, ctx));

        // object field for StakePool
        let stake_pool = StakePool {
            id,
            pool_info: StakePoolInfo {
                stake_token,
                index: registry.num_pool,
                next_user_share_id: 0,
                total_share: 0,
                active: true,
                u64_padding: vector::empty()
            },
            config: StakePoolConfig {
                unlock_countdown_ts_ms,
                u64_padding: vector::empty()
            },
            incentives: vector::empty(),
            u64_padding: vector::empty()
        };

        emit(NewStakePoolEvent {
            sender: tx_context::sender(ctx),
            stake_pool_info: stake_pool.pool_info,
            stake_pool_config: stake_pool.config,
            u64_padding: vector::empty()
        });

        dynamic_object_field::add(&mut registry.id, registry.num_pool, stake_pool);
        registry.num_pool = registry.num_pool + 1;
    }

    /// [Authorized Function] Migrates to staked TLP.
    // entry fun migrate_to_staked_tlp<TOKEN>(
    //     version: &Version,
    //     registry: &mut StakePoolRegistry,
    //     index: u64,
    //     ctx: &TxContext
    // ) {
    //     // safety check
    //     admin::verify(version, ctx);

    //     let stake_pool = get_mut_stake_pool(&mut registry.id, index);
    //     assert!(type_name::with_defining_ids<TOKEN>() == stake_pool.pool_info.stake_token, E_TOKEN_TYPE_MISMATCHED);
    //     let balance = dynamic_field::remove<TypeName, Balance<TOKEN>>(&mut stake_pool.id, type_name::with_defining_ids<TOKEN>());
    //     dynamic_field::add(&mut stake_pool.id, string::utf8(K_STAKED_TLP), balance);
    // }

    /// [Authorized Function]
    // entry fun add_lp_user_shares_v2(
    //     version: &Version,
    //     registry: &mut StakePoolRegistry,
    //     index: u64,
    //     ctx: &mut TxContext
    // ) {
    //     // safety check
    //     admin::verify(version, ctx);
    //     let stake_pool = get_mut_stake_pool(&mut registry.id, index);
    //     dynamic_field::add(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES_V2), keyed_big_vector::new<address, LpUserShare>(1000, ctx));
    // }

    /// [Authorized Function]
    // entry fun migrate_lp_user_shares_v2(
    //     version: &Version,
    //     registry: &mut StakePoolRegistry,
    //     index: u64,
    //     user: address,
    //     ctx: & TxContext
    // ) {
    //     // safety check
    //     admin::verify(version, ctx);

    //     let stake_pool = get_mut_stake_pool(&mut registry.id, index);
    //     let all_lp_user_shares = dynamic_field::borrow_mut<String, Table<address, vector<LpUserShare>>>(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES));
    //     let user_shares = all_lp_user_shares.borrow_mut(user);

    //     let mut user_share = user_shares.pop_back();

    //     // if more than 1
    //     while (vector::length(user_shares) > 0) {

    //         let user_share2 = user_shares.pop_back();

    //         let LpUserShare {
    //             user: _,
    //             user_share_id: _,
    //             stake_ts_ms: _,
    //             total_shares,
    //             active_shares,
    //             deactivating_shares,
    //             last_incentive_price_index: _,
    //             u64_padding: _,
    //         } = user_share2;

    //         user_share.total_shares = user_share.total_shares + total_shares;
    //         user_share.active_shares = user_share.active_shares + active_shares;
    //         user_share.deactivating_shares.append(deactivating_shares);
    //     };

    //     if (user_shares.length() == 0) {
    //         let shares = all_lp_user_shares.remove(user);
    //         shares.destroy_empty();
    //     };

    //     // add to v2
    //     let user_shares_v2 = dynamic_field::borrow_mut<String, KeyedBigVector>(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));
    //     user_shares_v2.push_back(user, user_share);
    // }


    /// [Authorized Function]
    // entry fun remove_lp_user_shares_v1(
    //     version: &Version,
    //     registry: &mut StakePoolRegistry,
    //     index: u64,
    //     ctx: & TxContext
    // ) {
    //     // safety check
    //     admin::verify(version, ctx);
    //     let stake_pool = get_mut_stake_pool(&mut registry.id, index);
    //     let all_lp_user_shares = dynamic_field::remove<String, Table<address, vector<LpUserShare>>>(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES));
    //     all_lp_user_shares.destroy_empty();

    //     let user_shares_v2 = dynamic_field::borrow<String, KeyedBigVector>(& stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));
    //     let depositors_count = user_shares_v2.length();
    //     stake_pool.pool_info.u64_padding.push_back(depositors_count);
    // }

    public struct AutoCompoundEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token: TypeName,
        incentive_price_index: u64,
        total_amount: u64,
        compound_users: u64,
        total_users: u64,
        u64_padding: vector<u64>
    }

    /// [Authorized Function]
    entry fun auto_compound<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        clock: &Clock,
        ctx: & TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        allocate_incentive(version, registry, index, clock);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let incentive_token = type_name::with_defining_ids<I_TOKEN>();
        assert!(incentive_token == stake_pool.pool_info.stake_token, E_TOKEN_TYPE_MISMATCHED);
        let incentive_tokens = get_incentive_tokens(stake_pool);
        assert!(vector::contains(&incentive_tokens, &incentive_token), E_INCENTIVE_TOKEN_NOT_EXISTED);

        let incentive = get_incentive(stake_pool, &incentive_token);
        let current_incentive_index = incentive.info.incentive_price_index;

        let user_shares_v2 = dynamic_field::borrow_mut<String, KeyedBigVector>(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));
        let total_users = user_shares_v2.length();

        let mut total_incentive_value = 0;
        let mut compound_users = 0;

        user_shares_v2.do_mut!(|_user: address, lp_user_share: &mut LpUserShare| {
            let (incentive_value, _) = calculate_incentive(current_incentive_index, &incentive_token, lp_user_share);
            lp_user_share.update_last_incentive_price_index(incentive_token, current_incentive_index);
            // accumulate incentive_value
            lp_user_share.log_harvested_amount(incentive_value);

            // handle user share incentive_value
            total_incentive_value = total_incentive_value + incentive_value;
            lp_user_share.total_shares = lp_user_share.total_shares + incentive_value;
            lp_user_share.active_shares = lp_user_share.active_shares + incentive_value;

            compound_users = compound_users + 1;
        });

        // handle pool
        let total_incentive_balance: Balance<I_TOKEN> = balance::split(dynamic_field::borrow_mut(&mut stake_pool.id, incentive_token), total_incentive_value);
        balance::join(dynamic_field::borrow_mut(&mut stake_pool.id, string::utf8(K_STAKED_TLP)), total_incentive_balance);
        stake_pool.pool_info.total_share = stake_pool.pool_info.total_share + total_incentive_value;


        emit(AutoCompoundEvent{
            sender: tx_context::sender(ctx),
            index,
            incentive_token: incentive_token,
            incentive_price_index: current_incentive_index,
            total_amount: total_incentive_value,
            compound_users,
            total_users,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when a new incentive token is added.
    public struct AddIncentiveTokenEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token: TypeName,
        incentive_info: IncentiveInfo,
        incentive_config: IncentiveConfig,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Adds a new incentive token to a pool.
    entry fun add_incentive_token<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        // incentive config
        period_incentive_amount: u64,
        incentive_interval_ts_ms: u64,
        clock: &Clock,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let incentive_token = type_name::with_defining_ids<I_TOKEN>();

        // check incentive token not existed
        let incentive_tokens = get_incentive_tokens(stake_pool);
        assert!(!vector::contains(&incentive_tokens, &incentive_token), E_INCENTIVE_TOKEN_ALREADY_EXISTED);

        assert!(incentive_interval_ts_ms > 0, E_ZERO_INCENTIVE_INTERVAL);

        // create public struct Incentive
        let incentive = Incentive {
            token_type: incentive_token,
            config: IncentiveConfig {
                period_incentive_amount,
                incentive_interval_ts_ms,
                u64_padding: vector::empty(),
            },
            info: IncentiveInfo {
                active: true,
                last_allocate_ts_ms: clock::timestamp_ms(clock),
                incentive_price_index: 0,
                unallocated_amount: 0,
                u64_padding: vector::empty(),
            }
        };
        vector::push_back(&mut stake_pool.incentives, incentive);

        emit(AddIncentiveTokenEvent {
            sender: tx_context::sender(ctx),
            index,
            incentive_token: incentive.token_type,
            incentive_info: incentive.info,
            incentive_config: incentive.config,
            u64_padding: vector::empty()
        });
        dynamic_field::add(&mut stake_pool.id, incentive_token, balance::zero<I_TOKEN>());
    }

    /// An event that is emitted when an incentive token is deactivated.
    public struct DeactivateIncentiveTokenEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token: TypeName,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Deactivates an incentive token.
    entry fun deactivate_incentive_token<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let incentive_token = type_name::with_defining_ids<I_TOKEN>();
        let incentive = get_mut_incentive(stake_pool, &incentive_token);
        incentive.info.active = false;

        emit(DeactivateIncentiveTokenEvent {
            sender: tx_context::sender(ctx),
            index,
            incentive_token,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when an incentive token is activated.
    public struct ActivateIncentiveTokenEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token: TypeName,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Activates an incentive token.
    entry fun activate_incentive_token<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let incentive_token = type_name::with_defining_ids<I_TOKEN>();
        let incentive = get_mut_incentive(stake_pool, &incentive_token);
        incentive.info.active = true;

        emit(ActivateIncentiveTokenEvent {
            sender: tx_context::sender(ctx),
            index,
            incentive_token,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when an incentive token is removed.
    public struct RemoveIncentiveTokenEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token: TypeName,
        incentive_balance_value: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Removes an incentive token.
    public fun remove_incentive_token<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        ctx: &mut TxContext
    ): Coin<I_TOKEN> {
        // safety check
        admin::verify(version, ctx);

        let incentive_token = type_name::with_defining_ids<I_TOKEN>();
        let stake_pool = get_mut_stake_pool(&mut registry.id, index);

        // check incentive token not existed
        let incentive_tokens = get_incentive_tokens(stake_pool);
        assert!(vector::contains(&incentive_tokens, &incentive_token), E_INCENTIVE_TOKEN_NOT_EXISTED);

        let incentive = remove_incentive(stake_pool, &incentive_token);

        let Incentive {
            token_type: _,
            config: _,
            info: _
        } = incentive;

        let incentive_balance: Balance<I_TOKEN> = dynamic_field::remove(&mut stake_pool.id, incentive_token);

        emit(RemoveIncentiveTokenEvent {
            sender: tx_context::sender(ctx),
            index,
            incentive_token,
            incentive_balance_value: balance::value(&incentive_balance),
            u64_padding: vector::empty()
        });

        coin::from_balance(incentive_balance, ctx)
    }

    /// An event that is emitted when the unlock countdown is updated.
    public struct UpdateUnlockCountdownTsMsEvent has copy, drop {
        sender: address,
        index: u64,
        previous_unlock_countdown_ts_ms: u64,
        new_unlock_countdown_ts_ms: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Updates the unlock countdown.
    entry fun update_unlock_countdown_ts_ms(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        unlock_countdown_ts_ms: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        // assert!(unlock_countdown_ts_ms > 0, E_ZERO_UNLOCK_COUNTDOWN);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let previous_unlock_countdown_ts_ms = stake_pool.config.unlock_countdown_ts_ms;
        stake_pool.config.unlock_countdown_ts_ms = unlock_countdown_ts_ms;

        emit(UpdateUnlockCountdownTsMsEvent {
            sender: tx_context::sender(ctx),
            index,
            previous_unlock_countdown_ts_ms,
            new_unlock_countdown_ts_ms: unlock_countdown_ts_ms,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when the incentive configuration is updated.
    public struct UpdateIncentiveConfigEvent has copy, drop {
        sender: address,
        index: u64,
        previous_incentive_config: IncentiveConfig,
        new_incentive_config: IncentiveConfig,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Updates the incentive configuration.
    entry fun update_incentive_config<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        clock: &Clock,
        // incentive config
        mut period_incentive_amount: Option<u64>,
        mut incentive_interval_ts_ms: Option<u64>,
        mut u64_padding: Option<vector<u64>>,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        allocate_incentive(version, registry, index, clock);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let incentive_token = type_name::with_defining_ids<I_TOKEN>();
        let incentive = get_mut_incentive(stake_pool, &incentive_token);

        let previous_incentive_config = incentive.config;

        if (option::is_some(&period_incentive_amount)) {
            incentive.config.period_incentive_amount = option::extract(&mut period_incentive_amount);
        };
        if (option::is_some(&incentive_interval_ts_ms)) {
            incentive.config.incentive_interval_ts_ms = option::extract(&mut incentive_interval_ts_ms);
        };
        if (option::is_some(&u64_padding)) {
            incentive.config.u64_padding = option::extract(&mut u64_padding);
        };

        emit(UpdateIncentiveConfigEvent {
            sender: tx_context::sender(ctx),
            index,
            previous_incentive_config,
            new_incentive_config: incentive.config,
            u64_padding: vector::empty()
        });
    }

    /// Allocates incentive to the pool.
    /// WARNING: no authority check inside
    public(package) fun allocate_incentive(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        clock: &Clock,
    ) {
        // safety check
        admin::version_check(version);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let mut i = 0;
        let length = vector::length(&stake_pool.incentives);
        while (i < length) {
            let incentive = vector::borrow_mut(&mut stake_pool.incentives, i);

            // clip current_ts_ms into interval increment
            let mut current_ts_ms = clock::timestamp_ms(clock);
            current_ts_ms = current_ts_ms / incentive.config.incentive_interval_ts_ms * incentive.config.incentive_interval_ts_ms;
            // only update incentive index for active incentive tokens
            let last_allocate_ts_ms = incentive.info.last_allocate_ts_ms;
            if (incentive.info.active && current_ts_ms > last_allocate_ts_ms) {
                // allocate latest incentive into incentive_price_index
                let (period_allocate_amount, price_index_increment) = if (stake_pool.pool_info.total_share > 0) {
                    let period_allocate_amount = ((incentive.config.period_incentive_amount as u128)
                        * ((current_ts_ms - last_allocate_ts_ms) as u128)
                            / (incentive.config.incentive_interval_ts_ms as u128) as u64);
                    (
                        period_allocate_amount,
                        ((multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128)
                            * (period_allocate_amount as u128)
                                / (stake_pool.pool_info.total_share as u128) as u64)
                    )
                } else { (0, 0) };

                incentive.info.unallocated_amount = incentive.info.unallocated_amount - period_allocate_amount;
                incentive.info.incentive_price_index = incentive.info.incentive_price_index + price_index_increment;
                incentive.info.last_allocate_ts_ms = current_ts_ms;
            };
            i = i + 1;
        };
    }

    /// An event that is emitted when incentive tokens are deposited.
    public struct DepositIncentiveEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token_type: TypeName,
        deposit_amount: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Deposits incentive tokens.
    entry fun deposit_incentive<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        coin: Coin<I_TOKEN>,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        // check incentive token not existed
        let incentive_token = type_name::with_defining_ids<I_TOKEN>();
        let incentive_tokens = get_incentive_tokens(stake_pool);
        assert!(vector::contains(&incentive_tokens, &incentive_token), E_INCENTIVE_TOKEN_NOT_EXISTED);

        let incentive_balance = dynamic_field::borrow_mut(&mut stake_pool.id, incentive_token);
        let incentive_amount = coin.value();
        balance::join(incentive_balance, coin.into_balance());

        let mut_incentive = get_mut_incentive(stake_pool, &incentive_token);
        mut_incentive.info.unallocated_amount = mut_incentive.info.unallocated_amount + incentive_amount;

        emit(DepositIncentiveEvent {
            sender: tx_context::sender(ctx),
            index,
            incentive_token_type: incentive_token,
            deposit_amount: incentive_amount,
            u64_padding: vector::empty()
        });
    }

    /// An event that is emitted when incentive tokens are withdrawn.
    public struct WithdrawIncentiveEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token_type: TypeName,
        withdrawal_amount: u64,
        u64_padding: vector<u64>
    }
    /// [Authorized Function] Withdraws incentive tokens.
    public fun withdraw_incentive_v2<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        mut amount: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<I_TOKEN> {
        // safety check
        admin::verify(version, ctx);

        allocate_incentive(version, registry, index, clock);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        // check incentive token not existed
        let incentive_token = type_name::with_defining_ids<I_TOKEN>();
        let incentive_tokens = get_incentive_tokens(stake_pool);
        assert!(vector::contains(&incentive_tokens, &incentive_token), E_INCENTIVE_TOKEN_NOT_EXISTED);

        let mut_incentive = get_mut_incentive(stake_pool, &incentive_token);
        let withdrawal_amount = if (option::is_some(&amount)) {
            let amount = option::extract(&mut amount);
            if (amount > mut_incentive.info.unallocated_amount) { mut_incentive.info.unallocated_amount } else { amount }
        } else {
            mut_incentive.info.unallocated_amount
        };
        mut_incentive.info.unallocated_amount = mut_incentive.info.unallocated_amount - withdrawal_amount;
        let incentive_balance = dynamic_field::borrow_mut(&mut stake_pool.id, incentive_token);
        let withdraw_balance = balance::split(incentive_balance, withdrawal_amount);
        emit(WithdrawIncentiveEvent {
            sender: tx_context::sender(ctx),
            index,
            incentive_token_type: incentive_token,
            withdrawal_amount,
            u64_padding: vector::empty()
        });
        coin::from_balance(withdraw_balance, ctx)
    }

    public struct StakeEvent has copy, drop {
        sender: address,
        index: u64,
        lp_token_type: TypeName,
        stake_amount: u64,
        user_share_id: u64,
        stake_ts_ms: u64,
        last_incentive_price_index: VecMap<TypeName, u64>,
        u64_padding: vector<u64>
    }

    /// [User Function] Stake LP tokens.
    public fun stake<LP_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        lp_token: Coin<LP_TOKEN>,
        _user_share_id: Option<u64>, // deprecated
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // safety check
        admin::version_check(version);

        allocate_incentive(version, registry, index, clock);

        let user = tx_context::sender(ctx);
        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let token_type = type_name::with_defining_ids<LP_TOKEN>();
        assert!(token_type == stake_pool.pool_info.stake_token, E_TOKEN_TYPE_MISMATCHED);

        // join balance
        let balance = coin::into_balance(lp_token);
        let balance_value = balance::value(&balance);
        balance::join(dynamic_field::borrow_mut(&mut stake_pool.id, string::utf8(K_STAKED_TLP)), balance);

        let current_ts_ms = clock::timestamp_ms(clock);
        let new_tlp_price = stake_pool.pool_info.u64_padding[0];

        let last_incentive_price_index = get_last_incentive_price_index(stake_pool);

        let user_shares_v2 = dynamic_field::borrow_mut<String, KeyedBigVector>(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));

        if (user_shares_v2.contains(user)) {
            let lp_user_share = user_shares_v2.borrow_by_key<address, LpUserShare>(user);
            assert!(harvest_progress_updated(last_incentive_price_index, lp_user_share.last_incentive_price_index), E_OUTDATED_HARVEST_STATUS);

            let lp_user_share = user_shares_v2.borrow_by_key_mut<address, LpUserShare>(user);
            lp_user_share.stake_ts_ms = current_ts_ms;
            assert!(lp_user_share.u64_padding[0] == current_ts_ms, E_TIMESTAMP_MISMATCHED);
            lp_user_share.total_shares = lp_user_share.total_shares + balance_value;
            lp_user_share.active_shares = lp_user_share.active_shares + balance_value;

            emit(StakeEvent {
                sender: tx_context::sender(ctx),
                index,
                lp_token_type: token_type,
                stake_amount: lp_user_share.total_shares,
                user_share_id: lp_user_share.user_share_id,
                stake_ts_ms: lp_user_share.stake_ts_ms,
                last_incentive_price_index: lp_user_share.last_incentive_price_index,
                u64_padding: lp_user_share.u64_padding
            });
        } else {
            let lp_user_share = LpUserShare {
                user,
                user_share_id: stake_pool.pool_info.next_user_share_id,
                stake_ts_ms: current_ts_ms,
                total_shares: balance_value,
                active_shares: balance_value,
                deactivating_shares: vector::empty(),
                last_incentive_price_index,
                u64_padding: vector[current_ts_ms, new_tlp_price, 0, 0],
            };
            stake_pool.pool_info.next_user_share_id = stake_pool.pool_info.next_user_share_id + 1;

            emit(StakeEvent {
                sender: tx_context::sender(ctx),
                index,
                lp_token_type: token_type,
                stake_amount: lp_user_share.total_shares,
                user_share_id: lp_user_share.user_share_id,
                stake_ts_ms: lp_user_share.stake_ts_ms,
                last_incentive_price_index: lp_user_share.last_incentive_price_index,
                u64_padding: lp_user_share.u64_padding
            });
            user_shares_v2.push_back(user, lp_user_share);
        };

        let depositors_count = user_shares_v2.length();
        *vector::borrow_mut(&mut stake_pool.pool_info.u64_padding, 2) = depositors_count;

        stake_pool.pool_info.total_share = stake_pool.pool_info.total_share + balance_value;
    }

    public struct UpdatePoolInfoU64PaddingEvent has copy, drop {
        sender: address,
        index: u64,
        u64_padding: vector<u64>
    }

    /// [Authorized Function] Update TLP price for calculating staking exp
    entry fun update_pool_info_u64_padding(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        tlp_price: u64, // decimal 4
        usd_per_exp: u64, // 200 usd = earn 1 exp for 1 hour
        ctx: &TxContext,
    ) {
        // safety check auth
        admin::verify(version, ctx);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        *vector::borrow_mut(&mut stake_pool.pool_info.u64_padding, 0) = tlp_price;
        *vector::borrow_mut(&mut stake_pool.pool_info.u64_padding, 1) = usd_per_exp;
        let user_shares_v2 = dynamic_field::borrow_mut<String, KeyedBigVector>(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));
        *vector::borrow_mut(&mut stake_pool.pool_info.u64_padding, 2) = user_shares_v2.length();

        emit(UpdatePoolInfoU64PaddingEvent {
            sender: tx_context::sender(ctx),
            index,
            u64_padding: stake_pool.pool_info.u64_padding
        })
    }

    /// [Authorized Function] Update TLP price for calculating staking exp
    entry fun hotfix_pool_info_u64_padding(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        u64_padding: vector<u64>,
        ctx: &TxContext,
    ) {
        // safety check auth
        admin::verify(version, ctx);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        stake_pool.pool_info.u64_padding = u64_padding;

        emit(UpdatePoolInfoU64PaddingEvent {
            sender: tx_context::sender(ctx),
            index,
            u64_padding: stake_pool.pool_info.u64_padding
        })
    }

    public struct SnapshotEvent has copy, drop {
        sender: address,
        index: u64,
        user_share_id: u64,
        shares: u64,
        tlp_price: u64,
        last_ts_ms: u64,
        current_ts_ms: u64,
        exp: u64,
        u64_padding: vector<u64>
    }

    /// [User Function] Get the staking exp
    public fun snapshot(
        version: &Version,
        registry: &mut StakePoolRegistry,
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        index: u64,
        _user_share_id: u64, // deprecated
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // safety check
        admin::version_check(version);

        let user = tx_context::sender(ctx);
        let stake_pool = get_mut_stake_pool(&mut registry.id, index);

        let new_tlp_price = stake_pool.pool_info.u64_padding[0];

        let user_shares_v2 = dynamic_field::borrow_mut<String, KeyedBigVector>(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));
        let lp_user_share = user_shares_v2.borrow_by_key_mut<address, LpUserShare>(user);

        if (lp_user_share.u64_padding.length() == 0) {
            lp_user_share.u64_padding = vector[lp_user_share.stake_ts_ms, new_tlp_price];
        };

        let shares = lp_user_share.active_shares;
        let last_ts_ms = lp_user_share.u64_padding[0];
        let old_tlp_price = lp_user_share.u64_padding[1];
        let user_share_id = lp_user_share.user_share_id;

        let current_ts_ms = clock::timestamp_ms(clock);
        let minutes = (current_ts_ms - last_ts_ms) / 60_000;

        let usd_per_exp = stake_pool.pool_info.u64_padding[1];
        let exp = ((shares as u256) * (old_tlp_price as u256) * (minutes as u256)
            / (multiplier(9 + 4) as u256) / ((60 * usd_per_exp) as u256) as u64);
        // snapshot_ts_ms ony update here
        *vector::borrow_mut(&mut lp_user_share.u64_padding, 0) = current_ts_ms;
        *vector::borrow_mut(&mut lp_user_share.u64_padding, 1) = new_tlp_price;

        admin::add_tails_exp_amount(version, typus_ecosystem_version, typus_user_registry, user, exp);
        emit(SnapshotEvent {
            sender: tx_context::sender(ctx),
            index,
            user_share_id,
            shares,
            tlp_price: old_tlp_price,
            last_ts_ms,
            current_ts_ms,
            exp,
            u64_padding: vector[new_tlp_price, usd_per_exp]
        });
    }

    public struct UnsubscribeEvent has copy, drop {
        sender: address,
        index: u64,
        lp_token_type: TypeName,
        user_share_id: u64,
        unsubscribed_shares: u64,
        unsubscribe_ts_ms: u64,
        unlocked_ts_ms: u64,
        u64_padding: vector<u64>
    }

    /// [User Function] Pre-process to unstake the TLP
    public fun unsubscribe<LP_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        _user_share_id: u64, // deprecated
        mut unsubscribed_shares: Option<u64>,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // safety check
        admin::version_check(version);

        allocate_incentive(version, registry, index, clock);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let token_type = type_name::with_defining_ids<LP_TOKEN>();
        assert!(token_type == stake_pool.pool_info.stake_token, E_TOKEN_TYPE_MISMATCHED);

        let current_ts_ms = clock::timestamp_ms(clock);
        let last_incentive_price_index = get_last_incentive_price_index(stake_pool);

        let user = tx_context::sender(ctx);
        let user_shares_v2 = dynamic_field::borrow_mut<String, KeyedBigVector>(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));
        let lp_user_share = user_shares_v2.borrow_by_key_mut<address, LpUserShare>(user);
        let user_share_id = lp_user_share.user_share_id;

        let unsubscribed_shares = if (unsubscribed_shares.is_some()) {
            unsubscribed_shares.extract()
        } else {
            lp_user_share.active_shares
        };
        assert!(lp_user_share.active_shares >= unsubscribed_shares, E_ACTIVE_SHARES_NOT_ENOUGH);

        // check snapshot_ts_ms updated
        assert!(lp_user_share.u64_padding[0] == current_ts_ms, E_TIMESTAMP_MISMATCHED);
        lp_user_share.active_shares = lp_user_share.active_shares - unsubscribed_shares;

        let unlocked_ts_ms = current_ts_ms + stake_pool.config.unlock_countdown_ts_ms;

        let deactivating_shares = DeactivatingShares {
            shares: unsubscribed_shares,
            unsubscribed_ts_ms: current_ts_ms,
            unlocked_ts_ms,
            unsubscribed_incentive_price_index: last_incentive_price_index,
            u64_padding: vector::empty(),
        };
        lp_user_share.deactivating_shares.push_back(deactivating_shares);

        stake_pool.pool_info.total_share = stake_pool.pool_info.total_share - unsubscribed_shares;
        emit(UnsubscribeEvent {
            sender: tx_context::sender(ctx),
            index,
            lp_token_type: token_type,
            user_share_id,
            unsubscribed_shares,
            unsubscribe_ts_ms: current_ts_ms,
            unlocked_ts_ms,
            u64_padding: vector::empty()
        });
    }

    public struct UnstakeEvent has copy, drop {
        sender: address,
        index: u64,
        lp_token_type: TypeName,
        user_share_id: u64,
        unstake_amount: u64,
        unstake_ts_ms: u64,
        u64_padding: vector<u64>
    }
    /// [User Function] Post-process to unstake the TLP
    public fun unstake<LP_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        _user_share_id: u64, // deprecated
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<LP_TOKEN> {
        // safety check
        admin::version_check(version);

        allocate_incentive(version, registry, index, clock);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let token_type = type_name::with_defining_ids<LP_TOKEN>();
        assert!(token_type == stake_pool.pool_info.stake_token, E_TOKEN_TYPE_MISMATCHED);
        let last_incentive_price_index = get_last_incentive_price_index(stake_pool);

        let current_ts_ms = clock::timestamp_ms(clock);
        let user = tx_context::sender(ctx);
        let user_shares_v2 = dynamic_field::borrow_mut<String, KeyedBigVector>(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));
        let lp_user_share = user_shares_v2.borrow_by_key_mut<address, LpUserShare>(user);
        let user_share_id = lp_user_share.user_share_id;

        assert!(harvest_progress_updated(last_incentive_price_index, lp_user_share.last_incentive_price_index), E_OUTDATED_HARVEST_STATUS);

        let mut i = 0;
        let mut temp_unstaked_shares = 0;
        while (i < lp_user_share.deactivating_shares.length()) {
            let deactivating_shares = lp_user_share.deactivating_shares.borrow(i);
            // use new config to calculate unlock_ts_ms
            if (deactivating_shares.unsubscribed_ts_ms + stake_pool.config.unlock_countdown_ts_ms <= current_ts_ms) {
                let DeactivatingShares {
                    shares,
                    unsubscribed_ts_ms: _,
                    unlocked_ts_ms: _,
                    unsubscribed_incentive_price_index: _,
                    u64_padding: _,
                } = lp_user_share.deactivating_shares.remove(i);
                temp_unstaked_shares = temp_unstaked_shares + shares;
            } else {
                // next
                i = i + 1;
            };
        };

        assert!(lp_user_share.u64_padding[0] == current_ts_ms, E_TIMESTAMP_MISMATCHED);
        lp_user_share.total_shares = lp_user_share.total_shares - temp_unstaked_shares;

        if (
            lp_user_share.deactivating_shares.length() == 0
            && lp_user_share.total_shares == 0
            && lp_user_share.active_shares == 0
        ) {
            let lp_user_share = user_shares_v2.swap_remove_by_key(user);
            let LpUserShare {
                user: _,
                user_share_id: _,
                stake_ts_ms: _,
                total_shares: _,
                active_shares: _,
                deactivating_shares,
                last_incentive_price_index: _,
                u64_padding: _,
            } = lp_user_share;
            deactivating_shares.destroy_empty();
        };

        emit(UnstakeEvent {
            sender: tx_context::sender(ctx),
            index,
            lp_token_type: token_type,
            user_share_id,
            unstake_amount: temp_unstaked_shares,
            unstake_ts_ms: current_ts_ms,
            u64_padding: vector::empty()
        });

        let b = balance::split(dynamic_field::borrow_mut(&mut stake_pool.id, string::utf8(K_STAKED_TLP)), temp_unstaked_shares);
        coin::from_balance(b, ctx)
    }

    public struct HarvestPerUserShareEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token_type: TypeName,
        harvest_amount: u64,
        user_share_id: u64,
        u64_padding: vector<u64>
    }

    fun update_last_incentive_price_index(lp_user_share: &mut LpUserShare, incentive_token: TypeName, current_incentive_index: u64) {
        if (vec_map::contains(&lp_user_share.last_incentive_price_index, &incentive_token)) {
            let last_incentive_price_index = vec_map::get_mut(&mut lp_user_share.last_incentive_price_index, &incentive_token);
            *last_incentive_price_index = current_incentive_index;
        } else {
            vec_map::insert(&mut lp_user_share.last_incentive_price_index, incentive_token, current_incentive_index);
        };
    }

    fun log_harvested_amount(user_share: &mut LpUserShare, incentive_value: u64) {
        if (user_share.u64_padding.length() == 2) {
            user_share.u64_padding.append(vector[0, incentive_value]);
        } else if (user_share.u64_padding.length() == 4) {
            let v = user_share.u64_padding.borrow_mut(3);
            *v = *v + incentive_value;
        }
    }

    /// [User Function] Harvest the incentive from staking TLP
    public fun harvest_per_user_share<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        _user_share_id: u64, // deprecated
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<I_TOKEN> {
        // safety check
        admin::version_check(version);

        allocate_incentive(version, registry, index, clock);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let incentive_token = type_name::with_defining_ids<I_TOKEN>();
        let incentive_tokens = get_incentive_tokens(stake_pool);
        assert!(vector::contains(&incentive_tokens, &incentive_token), E_INCENTIVE_TOKEN_NOT_EXISTED);

        let incentive = get_incentive(stake_pool, &incentive_token);
        let current_incentive_index = incentive.info.incentive_price_index;

        let user = tx_context::sender(ctx);
        let user_shares_v2 = dynamic_field::borrow_mut<String, KeyedBigVector>(&mut stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));
        let lp_user_share = user_shares_v2.borrow_by_key_mut<address, LpUserShare>(user);
        let user_share_id = lp_user_share.user_share_id;

        let (incentive_value, current_incentive_index) = calculate_incentive(current_incentive_index, &incentive_token, lp_user_share);

        lp_user_share.update_last_incentive_price_index(incentive_token, current_incentive_index);

        // accumulate incentive_value
        lp_user_share.log_harvested_amount(incentive_value);

        let incentive_pool_value = dynamic_field::borrow<TypeName, Balance<I_TOKEN>>(&stake_pool.id, incentive_token).value();
        if (incentive_value > incentive_pool_value) { abort E_INCENTIVE_TOKEN_NOT_ENOUGH };

        emit(HarvestPerUserShareEvent {
            sender: tx_context::sender(ctx),
            index,
            incentive_token_type: incentive_token,
            harvest_amount: incentive_value,
            user_share_id,
            u64_padding: vector::empty()
        });

        let b = balance::split(dynamic_field::borrow_mut(&mut stake_pool.id, incentive_token), incentive_value);
        coin::from_balance(b, ctx)
    }

    // ======= Inner Functions =======
    fun calculate_incentive(
        current_incentive_index: u64,
        incentive_token: &TypeName,
        lp_user_share: &LpUserShare,
    ): (u64, u64) {
        let lp_last_incentive_price_index = if (
            vec_map::contains(&lp_user_share.last_incentive_price_index, incentive_token)
        ) {
            *vec_map::get(&lp_user_share.last_incentive_price_index, incentive_token)
        } else {
            // not in lp_user_share.last_incentive_price_index
            // => new incentive token set after staking / harvesting => new index should be always start from 0
            0
        };

        let mut incentive_value = 0;

        // incentive_value from active shares
        let d_incentive_index = current_incentive_index - lp_last_incentive_price_index;
        incentive_value = incentive_value + ((lp_user_share.active_shares as u128)
                            * (d_incentive_index as u128)
                                / (multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128) as u64);

        // incentive_value from deactivating shares
        let mut i = 0;
        let length = lp_user_share.deactivating_shares.length();
        while (i < length) {
            let deactivating_shares = &lp_user_share.deactivating_shares[i];
            // unsubscribed_incentive_price_index was initially set when unsubscribing
            // incentive_token not existed in unsubscribed_incentive_price_index => pool incentive_token set after unlocking
            // => deactivating_shares has no right to attend to this incentive token
            if (deactivating_shares.unsubscribed_incentive_price_index.contains(incentive_token)) {
                let unsubscribed_incentive_price_index
                    = *deactivating_shares.unsubscribed_incentive_price_index.get(incentive_token);
                // if lp_last_incentive_price_index >= unsubscribed_incentive_price_index
                // => no more incentive for this deactivating share
                let d_incentive_index = if (unsubscribed_incentive_price_index > lp_last_incentive_price_index) {
                    unsubscribed_incentive_price_index - lp_last_incentive_price_index
                } else { 0 };
                incentive_value = incentive_value + ((deactivating_shares.shares as u128)
                                    * (d_incentive_index as u128)
                                        / (multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128) as u64);
            };
            i = i + 1;
        };

        (incentive_value, current_incentive_index)
    }

    // harvest transactions to all incentive tokens should be appended before unstaking
    fun harvest_progress_updated(current: VecMap<TypeName, u64>, user: VecMap<TypeName, u64>): bool {
        let mut updated = true;
        let (mut incentive_tokens, mut current_incentive_price_indexs) = current.into_keys_values();
        while (incentive_tokens.length() > 0) {
            let incentive_token = incentive_tokens.pop_back();
            let current_incentive_price_index = current_incentive_price_indexs.pop_back();
            if (vec_map::contains(&user, &incentive_token)) {
                let last_incentive_price_index = vec_map::get(&user, &incentive_token);
                if (*last_incentive_price_index != current_incentive_price_index) { updated = false };
            } else {
                return false
            };
        };
        updated
    }

    fun multiplier(decimal: u64): u64 {
        let mut i = 0;
        let mut multiplier = 1;
        while (i < decimal) {
            multiplier = multiplier * 10;
            i = i + 1;
        };
        multiplier
    }

    // ======= View Functions =======
    public(package) fun get_user_shares(
        registry: &StakePoolRegistry,
        index: u64,
        user: address,
    ): vector<u8> {
        let stake_pool = get_stake_pool(&registry.id, index);
        let all_lp_user_shares = dynamic_field::borrow<String, KeyedBigVector>(&stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));

        // check exist
        if (!all_lp_user_shares.contains(user)) {
            // early return
            return vector::empty<u8>()
        };
        let user_share: & LpUserShare = all_lp_user_shares.borrow_by_key(user);
        let incentive_tokens = get_incentive_tokens(stake_pool);

        let mut incentive_values = vector::empty();
        incentive_tokens.do_ref!(|incentive_token| {
            let incentive = get_incentive(stake_pool, incentive_token);
            let current_incentive_index = incentive.info.incentive_price_index;
            let (incentive_value, _) = calculate_incentive(current_incentive_index, incentive_token, user_share);
            incentive_values.push_back(incentive_value);
        });
        let mut data = bcs::to_bytes(user_share);
        data.append(bcs::to_bytes(&incentive_values));
        data
    }

    public(package) fun get_user_shares_by_user_share_id(
        registry: &StakePoolRegistry,
        index: u64,
        user_share_id: u64,
    ): vector<u8> {
        let stake_pool = get_stake_pool(&registry.id, index);
        let all_lp_user_shares = dynamic_field::borrow<String, KeyedBigVector>(&stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));

        let mut result = vector::empty<u8>();

        all_lp_user_shares.do_ref!<address, LpUserShare>(|_user, user_share| {
            if (user_share.user_share_id == user_share_id) {
                let incentive_tokens = get_incentive_tokens(stake_pool);
                let mut incentive_values = vector::empty();
                incentive_tokens.do_ref!(|incentive_token| {
                    let incentive = get_incentive(stake_pool, incentive_token);
                    let current_incentive_index = incentive.info.incentive_price_index;
                    let (incentive_value, _) = calculate_incentive(current_incentive_index, incentive_token, user_share);
                    incentive_values.push_back(incentive_value);
                });
                let mut data = bcs::to_bytes(user_share);
                data.append(bcs::to_bytes(&incentive_values));
                result = data;
            };
        });

        result
    }

    // ======= Helper Functions =======
    fun get_stake_pool(
        id: &UID,
        index: u64,
    ): &StakePool {
        dynamic_object_field::borrow<u64, StakePool>(id, index)
    }

    fun get_mut_stake_pool(
        id: &mut UID,
        index: u64,
    ): &mut StakePool {
        dynamic_object_field::borrow_mut<u64, StakePool>(id, index)
    }

    fun get_incentive_tokens(stake_pool: &StakePool): vector<TypeName> {
        let mut i = 0;
        let length = vector::length(&stake_pool.incentives);
        let mut incentive_tokens = vector::empty();
        while (i < length) {
            vector::push_back(
                &mut incentive_tokens,
                vector::borrow(&stake_pool.incentives, i).token_type
            );
            i = i + 1;
        };
        incentive_tokens
    }

    fun get_incentive(stake_pool: &StakePool, token_type: &TypeName): &Incentive {
        let mut i = 0;
        let length = vector::length(&stake_pool.incentives);
        while (i < length) {
            if (vector::borrow(&stake_pool.incentives, i).token_type == *token_type) {
                return vector::borrow(&stake_pool.incentives, i)
            };
            i = i + 1;
        };
        abort E_INCENTIVE_TOKEN_NOT_EXISTED
    }

    fun get_mut_incentive(stake_pool: &mut StakePool, token_type: &TypeName): &mut Incentive {
        let mut i = 0;
        let length = vector::length(&stake_pool.incentives);
        while (i < length) {
            if (vector::borrow(&stake_pool.incentives, i).token_type == *token_type) {
                return vector::borrow_mut(&mut stake_pool.incentives, i)
            };
            i = i + 1;
        };
        abort E_INCENTIVE_TOKEN_NOT_EXISTED
    }

    fun remove_incentive(stake_pool: &mut StakePool, token_type: &TypeName): Incentive {
        let mut i = 0;
        let length = vector::length(&stake_pool.incentives);
        while (i < length) {
            if (vector::borrow(&stake_pool.incentives, i).token_type == *token_type) {
                return vector::remove(&mut stake_pool.incentives, i)
            };
            i = i + 1;
        };
        abort E_INCENTIVE_TOKEN_NOT_EXISTED
    }

    fun get_last_incentive_price_index(stake_pool: &StakePool): VecMap<TypeName, u64> {
        let mut incentives = stake_pool.incentives;
        let mut last_incentive_price_index = vec_map::empty();
        while (vector::length(&incentives) > 0) {
            let incentive = vector::pop_back(&mut incentives);
            vec_map::insert(&mut last_incentive_price_index, incentive.token_type, incentive.info.incentive_price_index);
        };
        last_incentive_price_index
    }

    #[allow(dead_code, unused_variable, unused_type_parameter, unused_let_mut)]
    public fun withdraw_incentive<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        mut amount: Option<u64>,
        ctx: &mut TxContext
    ): Coin<I_TOKEN> {
        deprecated();
        coin::zero<I_TOKEN>(ctx)
    }

    fun deprecated() { abort 0 }

    #[test_only]
    public(package) fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public(package) fun test_get_stake_pool(registry: &StakePoolRegistry, index: u64): &StakePool {
        get_stake_pool(&registry.id, index)
    }

    #[test_only]
    public(package) fun test_get_last_incentive_price_index(stake_pool: &StakePool): VecMap<TypeName, u64> {
        get_last_incentive_price_index(stake_pool)
    }

    #[test_only]
    public(package) fun get_user_share_id(stake_pool: &StakePool, user: address): u64 {
        let all_lp_user_shares = dynamic_field::borrow<String, KeyedBigVector>(&stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));
        let user_shares = all_lp_user_shares.borrow_by_key<address, LpUserShare>(user);
        user_shares.user_share_id
    }

    // #[test_only]
    // public(package) fun test_get_lp_user_share_info<I_TOKEN>(
    //     registry: &StakePoolRegistry,
    //     index: u64,
    //     ctx: &TxContext
    // ): (vector<u64>, vector<u64>, vector<u64>, vector<u64>, vector<u64>, vector<u64>) {
    //     let stake_pool = get_stake_pool(&registry.id, index);
    //     let incentive_token_type = type_name::with_defining_ids<I_TOKEN>();
    //     let all_lp_user_shares
    //         = dynamic_field::borrow<String, Table<address, vector<LpUserShare>>>(&stake_pool.id, string::utf8(K_LP_USER_SHARES));
    //     let user_shares = table::borrow(all_lp_user_shares, tx_context::sender(ctx));
    //     let mut i = 0;
    //     let mut user_share_id = vector::empty();
    //     let mut share = vector::empty();
    //     let mut stake_ts_ms = vector::empty();
    //     let mut unlock_incentive_price_index = vector::empty();
    //     let mut last_incentive_price_index = vector::empty();
    //     let mut last_harvest_ts_ms = vector::empty();
    //     let length = user_shares.length();
    //     while (i < length) {
    //         user_share_id.push_back(user_shares[i].user_share_id);
    //         share.push_back(user_shares[i].share);
    //         stake_ts_ms.push_back(user_shares[i].stake_ts_ms);
    //         last_incentive_price_index.push_back(*user_shares[i].last_incentive_price_index.get(&incentive_token_type));
    //         last_harvest_ts_ms.push_back(*user_shares[i].last_harvest_ts_ms.get(&incentive_token_type));
    //         unlock_incentive_price_index.push_back(*user_shares[i].unlock_incentive_price_index.get(&incentive_token_type));
    //         i = i + 1;
    //     };
    //     (user_share_id, share, stake_ts_ms, unlock_incentive_price_index, last_incentive_price_index, last_harvest_ts_ms)
    // }

    #[test_only]
    public(package) fun test_get_single_lp_user_share_info<I_TOKEN>(
        registry: &StakePoolRegistry,
        index: u64,
        ctx: &TxContext
    ): (u64, u64, u64, u64, u64) {
        let stake_pool = get_stake_pool(&registry.id, index);
        let incentive_token_type = type_name::with_defining_ids<I_TOKEN>();
        let all_lp_user_shares = dynamic_field::borrow<String, KeyedBigVector>(&stake_pool.id, string::utf8(K_LP_USER_SHARES_V2));
        let user_shares = all_lp_user_shares.borrow_by_key<address, LpUserShare>(tx_context::sender(ctx));
        return (
            user_shares.user_share_id,
            user_shares.stake_ts_ms,
            user_shares.total_shares,
            user_shares.active_shares,
            *user_shares.last_incentive_price_index.get(&incentive_token_type)
        )
    }
}