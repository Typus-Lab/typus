module typus_stake_pool::stake_pool {
    use std::type_name::{Self, TypeName};
    use std::string::{Self, String};

    use sui::bcs;
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::dynamic_object_field;
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};
    use sui::event::emit;

    use typus_stake_pool::admin::{Self, Version};

    use typus::ecosystem::Version as TypusEcosystemVersion;
    use typus::user::TypusUserRegistry;

    // ======== Constants ========
    const C_INCENTIVE_INDEX_DECIMAL: u64 = 9;

    // ======== Keys ========
    const K_LP_USER_SHARES: vector<u8> = b"lp_user_shares";
    const K_STAKED_TLP: vector<u8> = b"staked_tlp";

    // ======== Errors ========
    const E_TOKEN_TYPE_MISMATCHED: u64 = 0;
    const E_USER_SHARE_NOT_EXISTED: u64 = 1;
    const E_INCENTIVE_TOKEN_NOT_EXISTED: u64 = 3;
    const E_INCENTIVE_TOKEN_ALREADY_EXISTED: u64 = 4;
    const E_USER_MISMATCHED: u64 = 5;
    const E_ACTIVE_SHARES_NOT_ENOUGH: u64 = 6;
    const E_ZERO_UNLOCK_COUNTDOWN: u64 = 7;
    const E_OUTDATED_HARVEST_STATUS: u64 = 8;
    const E_INCENTIVE_TOKEN_NOT_ENOUGH: u64 = 9;
    const E_TIMESTAMP_MISMATCHED: u64 = 10;
    const E_ZERO_INCENTIVE_INTERVAL: u64 = 11;

    public struct StakePoolRegistry has key {
        id: UID,
        num_pool: u64,
    }

    public struct StakePool has key, store {
        id: UID,
        pool_info: StakePoolInfo,
        config: StakePoolConfig,
        incentives: vector<Incentive>,
        u64_padding: vector<u64>,
    }

    public struct Incentive has copy, drop, store {
        token_type: TypeName,
        config: IncentiveConfig,
        info: IncentiveInfo
    }

    public struct StakePoolInfo has copy, drop, store {
        stake_token: TypeName,
        index: u64,
        next_user_share_id: u64,
        total_share: u64, // = total staked and has not been unsubscribed
        active: bool,
        u64_padding: vector<u64>, // [new_tlp_price (decimal 4), usd_per_exp]
    }

    public struct StakePoolConfig has copy, drop, store {
        unlock_countdown_ts_ms: u64,
        u64_padding: vector<u64>,
    }

    public struct IncentiveConfig has copy, drop, store {
        period_incentive_amount: u64,
        incentive_interval_ts_ms: u64,
        u64_padding: vector<u64>,
    }

    public struct IncentiveInfo has copy, drop, store {
        active: bool,
        last_allocate_ts_ms: u64, // record allocate ts ms for each I_TOKEN
        incentive_price_index: u64, // price index for accumulating incentive
        unallocated_amount: u64,
        u64_padding: vector<u64>,
    }

    public struct LpUserShare has store {
        user: address,
        user_share_id: u64,
        stake_ts_ms: u64,
        total_shares: u64,
        active_shares: u64,
        deactivating_shares: vector<DeactivatingShares>,
        last_incentive_price_index: VecMap<TypeName, u64>,
        u64_padding: vector<u64>, // [snapshot_ts_ms, old_tlp_price (decimal 4)]
    }

    public struct DeactivatingShares has store {
        shares: u64,
        unsubscribed_ts_ms: u64,
        unlocked_ts_ms: u64,
        unsubscribed_incentive_price_index: VecMap<TypeName, u64>, // the share can only receive incentive until this index
        u64_padding: vector<u64>,
    }

    fun init(ctx: &mut TxContext) {
        let registry = StakePoolRegistry {
            id: object::new(ctx),
            num_pool: 0,
        };

        transfer::share_object(registry);
    }

    public struct NewStakePoolEvent has copy, drop {
        sender: address,
        stake_pool_info: StakePoolInfo,
        stake_pool_config: StakePoolConfig,
        u64_padding: vector<u64>
    }
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
        dynamic_field::add(&mut id, string::utf8(K_LP_USER_SHARES), table::new<address, vector<LpUserShare>>(ctx));

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

    entry fun migrate_to_staked_tlp<TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        assert!(type_name::with_defining_ids<TOKEN>() == stake_pool.pool_info.stake_token, E_TOKEN_TYPE_MISMATCHED);
        let balance = dynamic_field::remove<TypeName, Balance<TOKEN>>(&mut stake_pool.id, type_name::with_defining_ids<TOKEN>());
        dynamic_field::add(&mut stake_pool.id, string::utf8(K_STAKED_TLP), balance);
    }

    public struct AddIncentiveTokenEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token: TypeName,
        incentive_info: IncentiveInfo,
        incentive_config: IncentiveConfig,
        u64_padding: vector<u64>
    }
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

    public struct DeactivateIncentiveTokenEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token: TypeName,
        u64_padding: vector<u64>
    }
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

    public struct ActivateIncentiveTokenEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token: TypeName,
        u64_padding: vector<u64>
    }
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

    public struct RemoveIncentiveTokenEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token: TypeName,
        incentive_balance_value: u64,
        u64_padding: vector<u64>
    }
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

    public struct UpdateUnlockCountdownTsMsEvent has copy, drop {
        sender: address,
        index: u64,
        previous_unlock_countdown_ts_ms: u64,
        new_unlock_countdown_ts_ms: u64,
        u64_padding: vector<u64>
    }
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

    public struct UpdateIncentiveConfigEvent has copy, drop {
        sender: address,
        index: u64,
        previous_incentive_config: IncentiveConfig,
        new_incentive_config: IncentiveConfig,
        u64_padding: vector<u64>
    }
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

    public struct DepositIncentiveEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token_type: TypeName,
        deposit_amount: u64,
        u64_padding: vector<u64>
    }
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

    public struct WithdrawIncentiveEvent has copy, drop {
        sender: address,
        index: u64,
        incentive_token_type: TypeName,
        withdrawal_amount: u64,
        u64_padding: vector<u64>
    }
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
    public fun stake<LP_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        lp_token: Coin<LP_TOKEN>,
        user_share_id: Option<u64>, // if is_some => merge share; none => create new share
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

        let lp_user_share = if (user_share_id.is_some()) {
            let mut lp_user_share
                = remove_user_share_by_id(&mut stake_pool.id, tx_context::sender(ctx), *user_share_id.borrow());
            assert!(user == lp_user_share.user, E_USER_MISMATCHED);
            assert!(harvest_progress_updated(stake_pool, &lp_user_share), E_OUTDATED_HARVEST_STATUS);

            lp_user_share.stake_ts_ms = current_ts_ms;
            assert!(lp_user_share.u64_padding[0] == current_ts_ms, E_TIMESTAMP_MISMATCHED);
            lp_user_share.total_shares = lp_user_share.total_shares + balance_value;
            lp_user_share.active_shares = lp_user_share.active_shares + balance_value;
            lp_user_share.last_incentive_price_index = get_last_incentive_price_index(stake_pool);
            lp_user_share
        } else {
            let lp_user_share = LpUserShare {
                user,
                user_share_id: stake_pool.pool_info.next_user_share_id,
                stake_ts_ms: current_ts_ms,
                total_shares: balance_value,
                active_shares: balance_value,
                deactivating_shares: vector::empty(),
                last_incentive_price_index: get_last_incentive_price_index(stake_pool),
                u64_padding: vector[current_ts_ms, new_tlp_price],
            };
            stake_pool.pool_info.next_user_share_id = stake_pool.pool_info.next_user_share_id + 1;
            lp_user_share
        };



        emit(StakeEvent {
            sender: tx_context::sender(ctx),
            index,
            lp_token_type: token_type,
            stake_amount: lp_user_share.total_shares,
            user_share_id: lp_user_share.user_share_id,
            stake_ts_ms: lp_user_share.stake_ts_ms,
            last_incentive_price_index: lp_user_share.last_incentive_price_index,
            u64_padding: vector::empty()
        });

        store_user_shares(&mut stake_pool.id, user, vector::singleton(lp_user_share));
        stake_pool.pool_info.total_share = stake_pool.pool_info.total_share + balance_value;
    }

    public struct UpdatePoolInfoU64PaddingEvent has copy, drop {
        sender: address,
        index: u64,
        u64_padding: vector<u64>
    }
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
        stake_pool.pool_info.u64_padding = vector[tlp_price, usd_per_exp];

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
    public fun snapshot(
        version: &Version,
        registry: &mut StakePoolRegistry,
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        index: u64,
        user_share_id: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // safety check
        admin::version_check(version);

        let user = tx_context::sender(ctx);
        let stake_pool = get_mut_stake_pool(&mut registry.id, index);

        let new_tlp_price = stake_pool.pool_info.u64_padding[0];

        let mut lp_user_share = remove_user_share_by_id(&mut stake_pool.id, tx_context::sender(ctx), user_share_id);

        if (lp_user_share.u64_padding.length() == 0) {
            lp_user_share.u64_padding = vector[lp_user_share.stake_ts_ms, new_tlp_price];
        };

        let shares = lp_user_share.active_shares;
        let last_ts_ms = lp_user_share.u64_padding[0];
        let old_tlp_price = lp_user_share.u64_padding[1];

        let current_ts_ms = clock::timestamp_ms(clock);
        let minutes = (current_ts_ms - last_ts_ms) / 60_000;

        let usd_per_exp = stake_pool.pool_info.u64_padding[1];
        let exp = ((shares as u256) * (old_tlp_price as u256) * (minutes as u256)
            / (multiplier(9 + 4) as u256) / ((60 * usd_per_exp) as u256) as u64);
        // snapshot_ts_ms ony update here
        *vector::borrow_mut(&mut lp_user_share.u64_padding, 0) = current_ts_ms;
        *vector::borrow_mut(&mut lp_user_share.u64_padding, 1) = new_tlp_price;

        store_user_shares(&mut stake_pool.id, user, vector::singleton(lp_user_share));
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
    public fun unsubscribe<LP_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        user_share_id: u64,
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
        let mut lp_user_share = remove_user_share_by_id(&mut stake_pool.id, tx_context::sender(ctx), user_share_id);
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
        store_user_shares(&mut stake_pool.id, lp_user_share.user, vector::singleton(lp_user_share));
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
    public fun unstake<LP_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        user_share_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<LP_TOKEN> {
        // safety check
        admin::version_check(version);

        allocate_incentive(version, registry, index, clock);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let token_type = type_name::with_defining_ids<LP_TOKEN>();
        assert!(token_type == stake_pool.pool_info.stake_token, E_TOKEN_TYPE_MISMATCHED);

        let current_ts_ms = clock::timestamp_ms(clock);
        let mut lp_user_share = remove_user_share_by_id(&mut stake_pool.id, tx_context::sender(ctx), user_share_id);
        assert!(harvest_progress_updated(stake_pool, &lp_user_share), E_OUTDATED_HARVEST_STATUS);

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
        } else {
            store_user_shares(&mut stake_pool.id, lp_user_share.user, vector::singleton(lp_user_share));
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
    public fun harvest_per_user_share<I_TOKEN>(
        version: &Version,
        registry: &mut StakePoolRegistry,
        index: u64,
        user_share_id: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<I_TOKEN> {
        // safety check
        admin::version_check(version);

        allocate_incentive(version, registry, index, clock);

        let user = tx_context::sender(ctx);

        let stake_pool = get_mut_stake_pool(&mut registry.id, index);
        let incentive_token = type_name::with_defining_ids<I_TOKEN>();
        let incentive_tokens = get_incentive_tokens(stake_pool);
        assert!(vector::contains(&incentive_tokens, &incentive_token), E_INCENTIVE_TOKEN_NOT_EXISTED);

        let mut lp_user_share = remove_user_share_by_id(&mut stake_pool.id, user, user_share_id);
        let (incentive_value, current_incentive_index)
            = calculate_incentive(stake_pool, &incentive_token, &lp_user_share);

        if (vec_map::contains(&lp_user_share.last_incentive_price_index, &incentive_token)) {
            let last_incentive_price_index = vec_map::get_mut(&mut lp_user_share.last_incentive_price_index, &incentive_token);
            *last_incentive_price_index = current_incentive_index;
        } else {
            vec_map::insert(&mut lp_user_share.last_incentive_price_index, incentive_token, current_incentive_index);
        };

        let incentive_pool_value = dynamic_field::borrow<TypeName, Balance<I_TOKEN>>(&stake_pool.id, incentive_token).value();
        if (incentive_value > incentive_pool_value) {
            abort E_INCENTIVE_TOKEN_NOT_ENOUGH
        };

        emit(HarvestPerUserShareEvent {
            sender: tx_context::sender(ctx),
            index,
            incentive_token_type: incentive_token,
            harvest_amount: incentive_value,
            user_share_id: lp_user_share.user_share_id,
            u64_padding: vector::empty()
        });

        store_user_shares(&mut stake_pool.id, user, vector::singleton(lp_user_share));

        let b = balance::split(dynamic_field::borrow_mut(&mut stake_pool.id, incentive_token), incentive_value);
        coin::from_balance(b, ctx)
    }

    // ======= Inner Functions =======
    fun store_user_shares(id: &mut UID, user: address, user_shares: vector<LpUserShare>) {
        let all_lp_user_shares = dynamic_field::borrow_mut<String, Table<address, vector<LpUserShare>>>(id, string::utf8(K_LP_USER_SHARES));
        if (!table::contains(all_lp_user_shares, user)) {
            table::add(all_lp_user_shares, user, vector::empty());
        };
        let shares_in_table = table::borrow_mut(all_lp_user_shares, user);
        vector::append(shares_in_table, user_shares);
    }

    fun remove_user_share_by_id(id: &mut UID, user: address, user_share_id: u64): LpUserShare {
        let all_lp_user_shares = dynamic_field::borrow_mut<String, Table<address, vector<LpUserShare>>>(id, string::utf8(K_LP_USER_SHARES));

        let user_shares = all_lp_user_shares.borrow_mut(user);

        let mut i = 0;
        let length = vector::length(user_shares);
        while (i < length) {
            let user_share = vector::borrow(user_shares, i);
            if (user_share.user_share_id == user_share_id) {
                break
            };
            i = i + 1;
        };

        assert!(i < length, E_USER_SHARE_NOT_EXISTED);

        let lp_user_share = vector::remove(user_shares, i);
        if (user_shares.length() == 0) {
            let shares = all_lp_user_shares.remove(user);
            shares.destroy_empty();
        };
        lp_user_share
    }

    fun calculate_incentive(
        stake_pool: &StakePool,
        incentive_token: &TypeName,
        lp_user_share: &LpUserShare,
    ): (u64, u64) {
        let incentive = get_incentive(stake_pool, incentive_token);
        let current_incentive_index = incentive.info.incentive_price_index;
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
    fun harvest_progress_updated(stake_pool: &StakePool, lp_user_share: &LpUserShare): bool {
        let mut updated = true;
        let mut incentive_tokens = stake_pool.get_incentive_tokens();
        while (incentive_tokens.length() > 0) {
            let incentive_token = incentive_tokens.pop_back();
            let current_incentive_price_index
                = get_incentive(stake_pool, &incentive_token).info.incentive_price_index;
            if (vec_map::contains(&lp_user_share.last_incentive_price_index, &incentive_token)) {
                let last_incentive_price_index = vec_map::get(&lp_user_share.last_incentive_price_index, &incentive_token);
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
    ): vector<vector<u8>> {
        let stake_pool = get_stake_pool(&registry.id, index);
        let all_lp_user_shares
            = dynamic_field::borrow<String, Table<address, vector<LpUserShare>>>(&stake_pool.id, string::utf8(K_LP_USER_SHARES));
        // check exist
        let mut result = vector::empty<vector<u8>>();
        if (!table::contains(all_lp_user_shares, user)) {
            // early return
            return result
        };
        let user_shares = table::borrow(all_lp_user_shares, user);
        let incentive_tokens = get_incentive_tokens(stake_pool);
        let mut i = 0;
        let length = user_shares.length();
        while (i < length) {
            let user_share = &user_shares[i];
            let mut incentive_values = vector::empty();
            incentive_tokens.do_ref!(|incentive_token| {
                let (incentive_value, _)
                    = calculate_incentive(stake_pool, incentive_token, user_share);
                incentive_values.push_back(incentive_value);
            });
            let mut data = bcs::to_bytes(user_share);
            data.append(bcs::to_bytes(&incentive_values));
            result.push_back(data);
            i = i + 1;
        };
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

    #[test_only]
    fun get_user_share_ids(stake_pool: &StakePool, user: address): vector<u64> {
        let all_lp_user_shares
            = dynamic_field::borrow<String, Table<address, vector<LpUserShare>>>(&stake_pool.id, string::utf8(K_LP_USER_SHARES));
        let user_shares = table::borrow(all_lp_user_shares, user);
        let mut i = 0;
        let mut ids = vector::empty();
        let length = user_shares.length();
        while (i < length) {
            ids.push_back(user_shares[i].user_share_id);
            i = i + 1;
        };
        ids
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

    // #[test_only]
    // public(package) fun test_init(ctx: &mut TxContext) {
    //     init(ctx);
    // }

    // #[test_only]
    // public(package) fun test_get_stake_pool(registry: &StakePoolRegistry, index: u64): &StakePool {
    //     get_stake_pool(&registry.id, index)
    // }

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

    // #[test_only]
    // public(package) fun test_get_single_lp_user_share_info<I_TOKEN>(
    //     registry: &StakePoolRegistry,
    //     index: u64,
    //     share_id: u64,
    //     ctx: &TxContext
    // ): (u64, u64, u64, u64, u64, u64) {
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
    //         if (user_shares[i].user_share_id == share_id) {
    //             user_share_id.push_back(user_shares[i].user_share_id);
    //             share.push_back(user_shares[i].share);
    //             stake_ts_ms.push_back(user_shares[i].stake_ts_ms);
    //             last_incentive_price_index.push_back(*user_shares[i].last_incentive_price_index.get(&incentive_token_type));
    //             last_harvest_ts_ms.push_back(*user_shares[i].last_harvest_ts_ms.get(&incentive_token_type));
    //             unlock_incentive_price_index.push_back(*user_shares[i].unlock_incentive_price_index.get(&incentive_token_type));
    //         };
    //         i = i + 1;
    //     };
    //     (
    //         user_share_id.pop_back(),
    //         share.pop_back(),
    //         stake_ts_ms.pop_back(),
    //         unlock_incentive_price_index.pop_back(),
    //         last_incentive_price_index.pop_back(),
    //         last_harvest_ts_ms.pop_back()
    //     )
    // }
}


// #[test_only]
// module typus_stake_pool::test_stake_pool {
//     use std::type_name;

//     use sui::balance;
//     use sui::clock::{Self, Clock};
//     use sui::coin::{Self, Coin};
//     use sui::sui::SUI;
//     use sui::test_scenario::{Scenario, begin, end, ctx, next_tx, take_shared, return_shared, sender};

//     use typus_perp::admin::{Self, Version};
//     use typus_perp::stake_pool::{Self, StakePoolRegistry};
//     use typus_perp::tlp::TLP;
//     use typus_perp::math;

//     const ADMIN: address = @0xFFFF;
//     const USER_1: address = @0xBABE1;
//     const USER_2: address = @0xBABE2;
//     const UNLOCK_COUNTDOWN_TS_MS: u64 = 5 * 24 * 60 * 60 * 1000; // 5 days
//     const PERIOD_INCENTIVE_AMOUNT: u64 = 0_0100_00000;
//     const INCENTIVE_INTERVAL_TS_MS: u64 = 60_000;
//     const C_INCENTIVE_INDEX_DECIMAL: u64 = 9;

//     const CURRENT_TS_MS: u64 = 1_715_212_800_000;

//     fun new_registry(scenario: &mut Scenario) {
//         stake_pool::test_init(ctx(scenario));
//         next_tx(scenario, ADMIN);
//     }

//     fun new_version(scenario: &mut Scenario) {
//         admin::test_init(ctx(scenario));
//         next_tx(scenario, ADMIN);
//     }

//     fun new_clock(scenario: &mut Scenario): Clock {
//         let mut clock = clock::create_for_testing(ctx(scenario));
//         clock::set_for_testing(&mut clock, CURRENT_TS_MS);
//         clock
//     }

//     fun registry(scenario: &Scenario): StakePoolRegistry {
//         take_shared<StakePoolRegistry>(scenario)
//     }

//     fun version(scenario: &Scenario): Version {
//         take_shared<Version>(scenario)
//     }

//     fun mint_test_coin<T>(scenario: &mut Scenario, amount: u64): Coin<T> {
//         coin::mint_for_testing<T>(amount, ctx(scenario))
//     }

//     fun update_clock(clock: &mut Clock, ts_ms: u64) {
//         clock::set_for_testing(clock, ts_ms);
//     }

//     fun test_new_stake_pool_<LP_TOKEN>(scenario: &mut Scenario) {
//         let mut registry = registry(scenario);
//         let version = version(scenario);
//         stake_pool::new_stake_pool<LP_TOKEN>(
//             &version,
//             &mut registry,
//             UNLOCK_COUNTDOWN_TS_MS,
//             ctx(scenario)
//         );
//         return_shared(registry);
//         return_shared(version);
//         next_tx(scenario, ADMIN);
//     }

//     fun test_add_incentive_token_<I_TOKEN>(scenario: &mut Scenario, index: u64) {
//         let mut registry = registry(scenario);
//         let version = version(scenario);
//         let clock = new_clock(scenario);
//         stake_pool::add_incentive_token<I_TOKEN>(
//             &version,
//             &mut registry,
//             index,
//             // incentive config
//             PERIOD_INCENTIVE_AMOUNT,
//             INCENTIVE_INTERVAL_TS_MS,
//             &clock,
//             ctx(scenario)
//         );
//         return_shared(registry);
//         return_shared(version);
//         clock::destroy_for_testing(clock);
//         next_tx(scenario, ADMIN);
//     }

//     fun test_deposit_incentive_<I_TOKEN>(scenario: &mut Scenario, index: u64, incentive_amount: u64) {
//         let deposit_incentive = mint_test_coin<I_TOKEN>(scenario, incentive_amount);
//         let mut registry = registry(scenario);
//         let version = version(scenario);
//         stake_pool::deposit_incentive<I_TOKEN>(
//             &version,
//             &mut registry,
//             index,
//             deposit_incentive,
//             incentive_amount,
//             ctx(scenario)
//         );
//         return_shared(registry);
//         return_shared(version);
//         next_tx(scenario, ADMIN);
//     }

//     fun test_stake_<LP_TOKEN>(
//         scenario: &mut Scenario,
//         index: u64,
//         stake_amount: u64,
//         stake_ts_ms: u64
//     ) {
//         let lp_token = mint_test_coin<LP_TOKEN>(scenario, stake_amount);
//         let mut registry = registry(scenario);
//         let version = version(scenario);
//         let mut clock = new_clock(scenario);
//         update_clock(&mut clock, stake_ts_ms);
//         stake_pool::stake<LP_TOKEN>(
//             &version,
//             &mut registry,
//             index,
//             lp_token,
//             &clock,
//             ctx(scenario)
//         );
//         return_shared(registry);
//         return_shared(version);
//         clock::destroy_for_testing(clock);
//         next_tx(scenario, ADMIN);
//     }

//     fun test_unstake_<LP_TOKEN>(scenario: &mut Scenario, index: u64, mut user_share_id: Option<u64>, unstake_ts_ms: u64): u64 {
//         let mut registry = registry(scenario);
//         let version = version(scenario);
//         let mut clock = new_clock(scenario);
//         update_clock(&mut clock, unstake_ts_ms);

//         let mut balance = balance::zero<LP_TOKEN>();
//         if (user_share_id.is_some()) {
//             let unstake_balance = stake_pool::unstake<LP_TOKEN>(
//                 &version,
//                 &mut registry,
//                 index,
//                 user_share_id.extract(),
//                 &clock,
//                 ctx(scenario),
//             );
//             balance.join(unstake_balance);
//         } else {
//             let mut user_share_ids = stake_pool::get_user_share_ids(
//                 stake_pool::test_get_stake_pool(&registry, index),
//                 sender(scenario)
//             );
//             while (!user_share_ids.is_empty()) {
//                 let unstake_balance = stake_pool::unstake<LP_TOKEN>(
//                     &version,
//                     &mut registry,
//                     index,
//                     user_share_ids.pop_back(),
//                     &clock,
//                     ctx(scenario),
//                 );
//                 balance.join(unstake_balance);
//             };
//         };

//         let unstake_balance_value = balance.value();
//         transfer::public_transfer(coin::from_balance(balance, ctx(scenario)), sender(scenario));

//         return_shared(registry);
//         return_shared(version);
//         clock::destroy_for_testing(clock);
//         next_tx(scenario, ADMIN);
//         unstake_balance_value
//     }

//     fun test_harvest_<I_TOKEN>(scenario: &mut Scenario, index: u64, harvest_ts_ms: u64): (u64, u64) {
//         let mut registry = registry(scenario);
//         let version = version(scenario);
//         let mut clock = new_clock(scenario);
//         update_clock(&mut clock, harvest_ts_ms);
//         let harvest_balance = stake_pool::harvest<I_TOKEN>(&version, &mut registry, index, &clock, ctx(scenario));
//         let harvest_balance_value = harvest_balance.value();
//         let (user_share_id, _, _, _, last_incentive_price_index, _)
//             = stake_pool::test_get_lp_user_share_info<I_TOKEN>(&registry, index, ctx(scenario));
//         // get stake pool get_last_incentive_price_index
//         let incentive_token = type_name::with_defining_ids<I_TOKEN>();
//         let incentive_price_indices
//             = stake_pool::get_last_incentive_price_index(stake_pool::test_get_stake_pool(&registry, index));
//         let incentive_price_index = incentive_price_indices.get(&incentive_token);
//         // calculate harvest_balance value
//         let mut i = 0;
//         let length = user_share_id.length();
//         while (i < length) {
//             // get user last_incentive_price_index and check the same as pool incentive_price_index
//             assert!(last_incentive_price_index[i] == *incentive_price_index, 0);
//             i = i + 1;
//         };
//         transfer::public_transfer(coin::from_balance(harvest_balance, ctx(scenario)), sender(scenario));
//         return_shared(registry);
//         return_shared(version);
//         clock::destroy_for_testing(clock);
//         next_tx(scenario, ADMIN);
//         (harvest_balance_value, *incentive_price_index)
//     }

//     fun test_harvest_per_user_share_<I_TOKEN>(
//         scenario: &mut Scenario,
//         index: u64,
//         user_share_id: u64,
//         harvest_ts_ms: u64
//     ): (u64, u64) {
//         let mut registry = registry(scenario);
//         let version = version(scenario);
//         let mut clock = new_clock(scenario);
//         update_clock(&mut clock, harvest_ts_ms);
//         let harvest_balance = stake_pool::harvest_per_user_share<I_TOKEN>(
//             &version,
//             &mut registry,
//             index,
//             user_share_id,
//             &clock,
//             ctx(scenario),
//         );
//         let harvest_balance_value = harvest_balance.value();
//         let (_user_share_id, _, _, _, last_incentive_price_index, _)
//             = stake_pool::test_get_single_lp_user_share_info<I_TOKEN>(&registry, index, user_share_id, ctx(scenario));
//         let incentive_token = type_name::with_defining_ids<I_TOKEN>();
//         let incentive_price_indices
//             = stake_pool::get_last_incentive_price_index(stake_pool::test_get_stake_pool(&registry, index));
//         let incentive_price_index = incentive_price_indices.get(&incentive_token);
//         assert!(last_incentive_price_index == *incentive_price_index, 0);
//         transfer::public_transfer(coin::from_balance(harvest_balance, ctx(scenario)), sender(scenario));
//         return_shared(registry);
//         return_shared(version);
//         clock::destroy_for_testing(clock);
//         next_tx(scenario, ADMIN);
//         (harvest_balance_value, *incentive_price_index)
//     }

//     #[test]
//     public(package) fun test_new_stake_pool() {
//         let mut scenario = begin(ADMIN);
//         new_registry(&mut scenario);
//         new_version(&mut scenario);
//         test_new_stake_pool_<TLP>(&mut scenario);
//         end(scenario);
//     }

//     #[test]
//     public(package) fun test_add_incentive_token() {
//         let mut scenario = begin(ADMIN);
//         new_registry(&mut scenario);
//         new_version(&mut scenario);
//         test_new_stake_pool_<TLP>(&mut scenario);

//         let index = 0;
//         test_add_incentive_token_<SUI>(&mut scenario, index);
//         end(scenario);
//     }

//     #[test]
//     public(package) fun test_deposit_incentive() {
//         let mut scenario = begin(ADMIN);
//         new_registry(&mut scenario);
//         new_version(&mut scenario);
//         test_new_stake_pool_<TLP>(&mut scenario);

//         let index = 0;
//         test_add_incentive_token_<SUI>(&mut scenario, index);

//         let incentive_amount = 1000_0000_00000;
//         test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);
//         end(scenario);
//     }

//     #[test]
//     public(package) fun test_stake() {
//         let mut scenario = begin(ADMIN);
//         new_registry(&mut scenario);
//         new_version(&mut scenario);
//         test_new_stake_pool_<TLP>(&mut scenario);

//         let index = 0;
//         test_add_incentive_token_<SUI>(&mut scenario, index);

//         let incentive_amount = 1000_0000_00000;
//         test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);

//         let stake_amount = 1_0000_00000;
//         test_stake_<TLP>(&mut scenario, index, stake_amount, CURRENT_TS_MS);
//         end(scenario);
//     }

//     #[test]
//     public(package) fun test_normal_harvest() {
//         let mut scenario = begin(ADMIN);
//         new_registry(&mut scenario);
//         new_version(&mut scenario);
//         test_new_stake_pool_<TLP>(&mut scenario);

//         let index = 0;
//         test_add_incentive_token_<SUI>(&mut scenario, index);

//         let incentive_amount = 1000_0000_00000;
//         test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);

//         next_tx(&mut scenario, USER_1);
//         let stake_amount_1 = 1_0000_00000;
//         test_stake_<TLP>(&mut scenario, index, stake_amount_1, CURRENT_TS_MS);

//         next_tx(&mut scenario, USER_2);
//         let stake_amount_2 = 0_0100_00000;
//         test_stake_<TLP>(&mut scenario, index, stake_amount_2, CURRENT_TS_MS);

//         // USER_1 harvest within locked-up period
//         next_tx(&mut scenario, USER_1);
//         let harvest_ts_ms_0 = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS;
//         let (harvest_balance_value, incentive_price_index_1) = test_harvest_<SUI>(&mut scenario, index, harvest_ts_ms_0);
//         let estimated_value_1 = ((stake_amount_1 as u128)
//                             * (incentive_price_index_1 as u128)
//                                 / (math::multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128)
//                                     * 11000
//                                         / 10000 as u64);
//         assert!(harvest_balance_value == estimated_value_1, 0);

//         // USER_2 harvest within locked-up period
//         next_tx(&mut scenario, USER_2);
//         let harvest_ts_ms_1 = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS + 1; // which means it would be the same period as USER_1
//         let (harvest_balance_value, incentive_price_index_2) = test_harvest_<SUI>(&mut scenario, index, harvest_ts_ms_1);
//         let estimated_value_2 = ((stake_amount_2 as u128)
//                             * (incentive_price_index_2 as u128)
//                                 / (math::multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128)
//                                     * 11000
//                                         / 10000 as u64);
//         assert!(harvest_balance_value == estimated_value_2, 0);

//         assert!(incentive_price_index_1 == incentive_price_index_2, 0);

//         // USER_1 harvest within locked-up period
//         next_tx(&mut scenario, USER_1);
//         let harvest_ts_ms_2 = CURRENT_TS_MS + 5 * INCENTIVE_INTERVAL_TS_MS;
//         let (harvest_balance_value, incentive_price_index_3) = test_harvest_<SUI>(&mut scenario, index, harvest_ts_ms_2);
//         let estimated_value_3 = ((stake_amount_1 as u128)
//                             * ((incentive_price_index_3 - incentive_price_index_1) as u128)
//                                 / (math::multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128)
//                                     * 11000
//                                         / 10000 as u64);
//         assert!(harvest_balance_value == estimated_value_3, 0);

//         // USER_1 harvest accross expiration
//         next_tx(&mut scenario, USER_1);
//         let expiration_ts_ms = CURRENT_TS_MS + locked_up_period_ts_ms_1;
//         let harvest_ts_ms_3 = expiration_ts_ms + 5 * INCENTIVE_INTERVAL_TS_MS;
//         let (harvest_balance_value, incentive_price_index_4) = test_harvest_<SUI>(&mut scenario, index, harvest_ts_ms_3);
//         let new_multiplier = ((harvest_ts_ms_3 - expiration_ts_ms) * 0
//                                 + (expiration_ts_ms - harvest_ts_ms_2) * 1000)
//                                     / (harvest_ts_ms_3 - harvest_ts_ms_2);
//         let estimated_value_4 = ((stake_amount_1 as u128)
//                             * ((incentive_price_index_4 - incentive_price_index_3) as u128)
//                                 / (math::multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128)
//                                     * (10000 + new_multiplier as u128)
//                                         / 10000 as u64);
//         assert!(harvest_balance_value == estimated_value_4, 0);

//         // USER_1 harvest after expiration
//         next_tx(&mut scenario, USER_1);
//         let harvest_ts_ms_4 = harvest_ts_ms_3 + 3 * INCENTIVE_INTERVAL_TS_MS;
//         let (harvest_balance_value, incentive_price_index_5) = test_harvest_<SUI>(&mut scenario, index, harvest_ts_ms_4);
//         let estimated_value_5 = ((stake_amount_1 as u128)
//                             * ((incentive_price_index_5 - incentive_price_index_4) as u128)
//                                 / (math::multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128)as u64);
//         assert!(harvest_balance_value == estimated_value_5, 0);

//         end(scenario);
//     }

//     #[test]
//     public(package) fun test_harvest_per_user_share() {
//         let mut scenario = begin(ADMIN);
//         new_registry(&mut scenario);
//         new_version(&mut scenario);
//         test_new_stake_pool_<TLP>(&mut scenario);

//         let index = 0;
//         test_add_incentive_token_<SUI>(&mut scenario, index);

//         let incentive_amount = 1000_0000_00000;
//         test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);

//         next_tx(&mut scenario, USER_1);
//         let stake_amount_1 = 1_0000_00000;
//         test_stake_<TLP>(&mut scenario, index, stake_amount_1, CURRENT_TS_MS);

//         next_tx(&mut scenario, USER_1);
//         let stake_amount_2 = 0_0100_00000;
//         test_stake_<TLP>(&mut scenario, index, stake_amount_2, CURRENT_TS_MS);

//         next_tx(&mut scenario, USER_2);
//         let stake_amount_3 = 0_2000_00000;
//         test_stake_<TLP>(&mut scenario, index, stake_amount_3, CURRENT_TS_MS);

//         // USER_1 harvest user_share_id 0 within locked-up period
//         next_tx(&mut scenario, USER_1);
//         let harvest_ts_ms_0 = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS;
//         let (harvest_balance_value, incentive_price_index_1)
//             = test_harvest_per_user_share_<SUI>(&mut scenario, index, 0, harvest_ts_ms_0);
//         let estimated_value_1 = ((stake_amount_1 as u128)
//                             * (incentive_price_index_1 as u128)
//                                 / (math::multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128)
//                                     * 11000
//                                         / 10000 as u64);
//         assert!(harvest_balance_value == estimated_value_1, 0);

//         // USER_1 harvest user_share_id 1 within locked-up period
//         next_tx(&mut scenario, USER_1);
//         let harvest_ts_ms_1 = CURRENT_TS_MS + 5 * INCENTIVE_INTERVAL_TS_MS;
//         let (harvest_balance_value, incentive_price_index_2)
//             = test_harvest_per_user_share_<SUI>(&mut scenario, index, 1, harvest_ts_ms_1);
//         let estimated_value_2 = ((stake_amount_2 as u128)
//                             * (incentive_price_index_2 as u128)
//                                 / (math::multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128)
//                                     * 15000
//                                         / 10000 as u64);
//         assert!(harvest_balance_value == estimated_value_2, 0);

//         end(scenario);
//     }

//     #[test]
//     public(package) fun test_harvest_for_zero_balance() {
//         let mut scenario = begin(ADMIN);
//         new_registry(&mut scenario);
//         new_version(&mut scenario);
//         test_new_stake_pool_<TLP>(&mut scenario);

//         let index = 0;
//         test_add_incentive_token_<SUI>(&mut scenario, index);

//         let incentive_amount = 1000_0000_00000;
//         test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);

//         next_tx(&mut scenario, USER_1);
//         let stake_amount_1 = 1_0000_00000;
//         test_stake_<TLP>(&mut scenario, index, stake_amount_1, CURRENT_TS_MS);

//         next_tx(&mut scenario, USER_1);
//         let stake_amount_2 = 0_0100_00000;
//         test_stake_<TLP>(&mut scenario, index, stake_amount_2, CURRENT_TS_MS);

//         next_tx(&mut scenario, USER_2);
//         let stake_amount_3 = 0_2000_00000;
//         test_stake_<TLP>(&mut scenario, index, stake_amount_3, CURRENT_TS_MS);

//         // USER_1 harvest user_share_id 0 within locked-up period
//         next_tx(&mut scenario, USER_1);
//         let harvest_ts_ms_0 = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS;
//         let (harvest_balance_value, incentive_price_index_1)
//             = test_harvest_per_user_share_<SUI>(&mut scenario, index, 0, harvest_ts_ms_0);
//         let estimated_value_1 = ((stake_amount_1 as u128)
//                             * (incentive_price_index_1 as u128)
//                                 / (math::multiplier(C_INCENTIVE_INDEX_DECIMAL) as u128)
//                                     * 11000
//                                         / 10000 as u64);
//         assert!(harvest_balance_value == estimated_value_1, 0);

//         // USER_1 harvest user_share_id 0 within locked-up period
//         next_tx(&mut scenario, USER_1);
//         let harvest_ts_ms_1 = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS + 1;
//         let (harvest_balance_value, incentive_price_index_2)
//             = test_harvest_per_user_share_<SUI>(&mut scenario, index, 0, harvest_ts_ms_1);
//         assert!(harvest_balance_value == 0, 0);
//         assert!(incentive_price_index_2 == incentive_price_index_1, 0);

//         end(scenario);
//     }

    // #[test]
    // #[expected_failure(abort_code = stake_pool::E_USER_SHARE_NOT_YET_EXPIRED)]
    // public(package) fun test_early_unstake_failed() {
    //     let mut scenario = begin(ADMIN);
    //     new_registry(&mut scenario);
    //     new_version(&mut scenario);
    //     test_new_stake_pool_<TLP>(&mut scenario);

    //     let index = 0;
    //     test_add_incentive_token_<SUI>(&mut scenario, index);

    //     let incentive_amount = 1000_0000_00000;
    //     test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);

    //     next_tx(&mut scenario, USER_1);
    //     let stake_amount_1 = 1_0000_00000;
    //     test_stake_<TLP>(&mut scenario, index, stake_amount_1, CURRENT_TS_MS);

    //     next_tx(&mut scenario, USER_1);
    //     let unstake_ts_ms = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS;
    //     let _ = test_unstake_<TLP>(&mut scenario, index, option::none(), unstake_ts_ms); // unstake all

    //     end(scenario);
    // }

    // #[test]
    // public(package) fun test_unstake_multiple_times() {
    //     let mut scenario = begin(ADMIN);
    //     new_registry(&mut scenario);
    //     new_version(&mut scenario);
    //     test_new_stake_pool_<TLP>(&mut scenario);

    //     let index = 0;
    //     test_add_incentive_token_<SUI>(&mut scenario, index);

    //     let incentive_amount = 1000_0000_00000;
    //     test_deposit_incentive_<SUI>(&mut scenario, index, incentive_amount);

    //     next_tx(&mut scenario, USER_1);
    //     let stake_amount_1 = 1_0000_00000;
    //     test_stake_<TLP>(&mut scenario, index, stake_amount_1, CURRENT_TS_MS);

    //     next_tx(&mut scenario, USER_2);
    //     let stake_amount_2 = 0_0100_00000;
    //     test_stake_<TLP>(&mut scenario, index, stake_amount_2, CURRENT_TS_MS);

    //     next_tx(&mut scenario, USER_2);
    //     let stake_amount_3 = 0_3000_00000;
    //     test_stake_<TLP>(&mut scenario, index, stake_amount_3, CURRENT_TS_MS + 1);

    //     next_tx(&mut scenario, USER_1);
    //     let stake_amount_4 = 1_0000_00000;
    //     test_stake_<TLP>(
    //         &mut scenario,
    //         index,
    //         stake_amount_4,
    //         CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS
    //     ); // stake at first incentive period

    //     // unstake user_share_id = 1 (share = 0_0100_00000)
    //     next_tx(&mut scenario, USER_2);
    //     let unstake_ts_ms_0 = CURRENT_TS_MS + locked_up_period_ts_ms_1;
    //     let unstake_user_2
    //         = test_unstake_<TLP>(&mut scenario, index, option::some(1), unstake_ts_ms_0);
    //     assert!(unstake_user_2 == stake_amount_2, 1);

    //     // unstake USER_1 all shares
    //     next_tx(&mut scenario, USER_1);
    //     let unstake_ts_ms_1 = CURRENT_TS_MS + INCENTIVE_INTERVAL_TS_MS + locked_up_period_ts_ms_3;
    //     let unstake_user_1 = test_unstake_<TLP>(&mut scenario, index, option::none(), unstake_ts_ms_1);
    //     assert!(unstake_user_1 == stake_amount_1 + stake_amount_4, 1);

    //     end(scenario);
    // }
// }