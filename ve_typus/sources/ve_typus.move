module ve_typus::ve_typus {
    use std::bcs;

    use sui::balance::Balance;
    use sui::dynamic_object_field;
    use sui::event::emit;
    use sui::coin::{Self, Coin};
    use sui::clock::Clock;

    use typus_token::typus::TYPUS;

    use typus::linked_object_table::{Self, LinkedObjectTable};
    use typus::utility;

    use version::version::{Self, Version};

    // ======== Constants ========

    const CVersion: u64 = 1;

    // ======== Registry Settings Index ========

    const I_TRANSACTION_SUSPENDED: u64 = 0;
    const I_MIN_LOCK_UP_PERIOD: u64 = 1;
    const I_MAX_LOCK_UP_PERIOD: u64 = 2;
    const I_MIN_LOCK_UP_AMOUNT: u64 = 3;
    const I_MAX_LOCK_UP_AMOUNT: u64 = 4;

    // ======== Structs ========

    public struct VE_TYPUS has drop {}

    public struct VERSION has drop {}

    public struct Registry has key {
        id: UID,
        setting: vector<u64>,
    }

    public struct VeTypus has key, store {
        id: UID,
        balance: Balance<TYPUS>,
        lock_up_period: u64,
        create_ts_ms: u64,
    }

    fun init(otw: VE_TYPUS, ctx: &mut TxContext) {
        version::issue_version(&otw, VERSION {}, ctx);
        transfer::share_object(Registry {
            id: object::new(ctx),
            setting: vector[
                0,                              // I_TRANSACTION_SUSPENDED
                24 * 60 * 60 * 1000,            // I_MIN_LOCK_UP_PERIOD
                4 * 365 * 24 * 60 * 60 * 1000,  // I_MAX_LOCK_UP_PERIOD
                100 * utility::multiplier(9),   // I_MIN_LOCK_UP_AMOUNT
                std::u64::max_value!(),         // I_MAX_LOCK_UP_AMOUNT
            ]
        });
    }

    // ======== Manager Function ========

    public struct UpdateRegistrySettingEvent has copy, drop {
        log: vector<u64>,
    }
    entry fun update_registry_setting(
        version: &Version,
        registry: &mut Registry,
        setting_index: u64,
        value: u64,
        ctx: &TxContext,
    ) {
        // safety check
        version.verify_authority(ctx);
        version.verify_witness(VERSION {});
        version.verify_version(CVersion);

        while (registry.setting.length() < setting_index + 1) {
            registry.setting.push_back(0);
        };
        emit(UpdateRegistrySettingEvent { log: vector[registry.setting[setting_index], value] });
        *&mut registry.setting[setting_index] = value;
    }

    entry fun delegate_mint(
        version: &Version,
        registry: &mut Registry,
        user: address,
        coin: Coin<TYPUS>,
        lock_up_period: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        // safety check
        version.verify_authority(ctx);
        version.verify_witness(VERSION {});
        version.verify_version(CVersion);

        // main logic
        mint_(registry, user, coin, lock_up_period, clock, ctx)
    }

    entry fun delegate_burn(
        version: &Version,
        registry: &mut Registry,
        user: address,
        ve_typus: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        // safety check
        version.verify_authority(ctx);
        version.verify_witness(VERSION {});
        version.verify_version(CVersion);

        // main logic
        transfer::public_transfer(
            burn_(registry, user, ve_typus, clock, ctx),
            user,
        );
    }

    entry fun delegate_renew(
        version: &Version,
        registry: &mut Registry,
        user: address,
        ve_typus: address,
        lock_up_period: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // safety check
        version.verify_authority(ctx);
        version.verify_witness(VERSION {});
        version.verify_version(CVersion);

        // main logic
        renew_(registry, user, ve_typus, lock_up_period, clock)
    }

    // ======== User Function ========

    public struct MintEvent has copy, drop {
        user: address,
        log: vector<u64>,
    }
    public fun mint(
        version: &Version,
        registry: &mut Registry,
        coin: Coin<TYPUS>,
        lock_up_period: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        // safety check
        version.verify_witness(VERSION {});
        version.verify_version(CVersion);

        // main logic
        mint_(registry, ctx.sender(), coin, lock_up_period, clock, ctx)
    }
    fun mint_(
        registry: &mut Registry,
        user: address,
        coin: Coin<TYPUS>,
        lock_up_period: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let amount = coin.value();
        let current_ts_ms = clock.timestamp_ms();
        // safety check
        assert!(registry.setting[I_TRANSACTION_SUSPENDED] == 0, transaction_suspended());
        assert!(lock_up_period >= registry.setting[I_MIN_LOCK_UP_PERIOD]
            && lock_up_period <= registry.setting[I_MAX_LOCK_UP_PERIOD], invalid_lock_up_period());
        assert!(amount >= registry.setting[I_MIN_LOCK_UP_AMOUNT]
            && amount <= registry.setting[I_MAX_LOCK_UP_AMOUNT], invalid_lock_up_amount());

        // main logic
        emit(MintEvent {
            user,
            log: vector[
                coin.value(),
                lock_up_period,
                current_ts_ms,
            ],
        });
        if (!dynamic_object_field::exists_(&registry.id, user)) {
            dynamic_object_field::add(&mut registry.id, user, linked_object_table::new<address, VeTypus>(ctx));
        };
        let ve_typus_list: &mut LinkedObjectTable<address, VeTypus> = dynamic_object_field::borrow_mut(&mut registry.id, user);
        let ve_typus = VeTypus {
            id: object::new(ctx),
            balance: coin.into_balance(),
            lock_up_period,
            create_ts_ms: current_ts_ms,
        };
        ve_typus_list.push_back(object::id_address(&ve_typus), ve_typus);
    }

    public struct BurnEvent has copy, drop {
        user: address,
        log: vector<u64>,
    }
    public fun burn(
        version: &Version,
        registry: &mut Registry,
        ve_typus: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<TYPUS> {
        // safety check
        version.verify_witness(VERSION {});
        version.verify_version(CVersion);

        // main logic
        burn_(registry, ctx.sender(), ve_typus, clock, ctx)
    }
    fun burn_(
        registry: &mut Registry,
        user: address,
        ve_typus: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<TYPUS> {
        let current_ts_ms = clock.timestamp_ms();
        // safety check
        assert!(dynamic_object_field::exists_(&registry.id, user), invalid_user());
        let ve_typus_list: &mut LinkedObjectTable<address, VeTypus> = dynamic_object_field::borrow_mut(&mut registry.id, user);
        assert!(ve_typus_list.contains(ve_typus), invalid_ve_typus());
        let VeTypus {
            id,
            balance,
            lock_up_period,
            create_ts_ms,
        } = ve_typus_list.remove(ve_typus);
        assert!(registry.setting[I_TRANSACTION_SUSPENDED] == 0, transaction_suspended());
        assert!(current_ts_ms >= create_ts_ms + lock_up_period, not_yet_expired());

        // main logic
        id.delete();
        emit(BurnEvent {
            user,
            log: vector[
                balance.value(),
                lock_up_period,
                create_ts_ms,
                current_ts_ms,
            ],
        });

        coin::from_balance(balance, ctx)
    }

    public struct RenewEvent has copy, drop {
        user: address,
        log: vector<u64>,
    }
    public fun renew(
        version: &Version,
        registry: &mut Registry,
        ve_typus: address,
        lock_up_period: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // safety check
        version.verify_witness(VERSION {});
        version.verify_version(CVersion);

        // main logic
        renew_(registry, ctx.sender(), ve_typus, lock_up_period, clock)
    }
    fun renew_(
        registry: &mut Registry,
        user: address,
        ve_typus: address,
        lock_up_period: u64,
        clock: &Clock,
    ) {
        let current_ts_ms = clock.timestamp_ms();
        // safety check
        assert!(dynamic_object_field::exists_(&registry.id, user), invalid_user());
        let ve_typus_list: &mut LinkedObjectTable<address, VeTypus> = dynamic_object_field::borrow_mut(&mut registry.id, user);
        assert!(ve_typus_list.contains(ve_typus), invalid_ve_typus());
        let ve_typus = ve_typus_list.borrow_mut(ve_typus);
        assert!(registry.setting[I_TRANSACTION_SUSPENDED] == 0, transaction_suspended());
        assert!(lock_up_period >= registry.setting[I_MIN_LOCK_UP_PERIOD]
            && lock_up_period <= registry.setting[I_MAX_LOCK_UP_PERIOD]
            && (current_ts_ms >= ve_typus.create_ts_ms + ve_typus.lock_up_period
                || lock_up_period >= ve_typus.create_ts_ms + ve_typus.lock_up_period - current_ts_ms), invalid_lock_up_period());

        // main logic
        ve_typus.lock_up_period = lock_up_period;
        ve_typus.create_ts_ms = current_ts_ms;
        emit(RenewEvent {
            user,
            log: vector[
                ve_typus.balance.value(),
                lock_up_period,
                current_ts_ms,
            ],
        });
    }

    // ======== Read Function ========

    public(package) fun get_ve_typus_bcs(
        registry: &Registry,
        user: address,
    ): vector<u8> {
        let mut result = vector[];
        if (dynamic_object_field::exists_(&registry.id, user)) {
            let ve_typus_list: &LinkedObjectTable<address, VeTypus> = dynamic_object_field::borrow(&registry.id, user);
            let mut front = ve_typus_list.front();
            while (front.is_some()) {
                let ve_typus = ve_typus_list.borrow(*front.borrow());
                result.push_back(bcs::to_bytes(ve_typus));
                front = ve_typus_list.next(*front.borrow());
            };
        };

        bcs::to_bytes(&result)
    }

    fun invalid_lock_up_amount(): u64 { abort 0 }
    fun invalid_lock_up_period(): u64 { abort 0 }
    fun invalid_user(): u64 { abort 0 }
    fun invalid_ve_typus(): u64 { abort 0 }
    fun not_yet_expired(): u64 { abort 0 }
    fun transaction_suspended(): u64 { abort 0 }
}
