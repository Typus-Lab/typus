module typus_perp::admin {
    use std::type_name::{Self, TypeName};
    use std::ascii::String;

    use sui::balance::{Self, Balance};
    use sui::coin;
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::vec_set::{Self, VecSet};
    use sui::clock::{Clock};

    use typus_perp::math::{Self};
    use typus_perp::error;

    // ======== Constants ========
    const CVersion: u64 = 5;
    const ECOSYSTEM_MANAGER_CAP: vector<u8> = b"ecosystem_manager_cap";

    // ======== Manager Cap ========

    // public struct ManagerCap has store { }

    // public(package) fun issue_manager_cap(
    //     version: &Version,
    //     ctx: &TxContext,
    // ): ManagerCap {
    //     verify(version, ctx);

    //     ManagerCap { }
    // }

    // ======== Version ========

    #[allow(unused_field)]
    public struct Version has key {
        id: UID,
        value: u64,
        fee_pool: FeePool,
        liquidator_fee_pool: FeePool,
        authority: VecSet<address>,
        u64_padding: vector<u64>,
    }

    public(package) fun version_check(version: &Version) {
        assert!(CVersion >= version.value, error::invalid_version());
    }

    entry fun upgrade(version: &mut Version) {
        version_check(version);
        version.value = CVersion;
    }

    // ======== Init ========

    // fun init(ctx: &mut TxContext) {
    //     transfer::share_object(Version {
    //         id: object::new(ctx),
    //         value: CVersion,
    //         fee_pool: FeePool {
    //             id: object::new(ctx),
    //             fee_infos: vector[],
    //         },
    //         liquidator_fee_pool: FeePool {
    //             id: object::new(ctx),
    //             fee_infos: vector[],
    //         },
    //         authority: vec_set::singleton(tx_context::sender(ctx)),
    //         u64_padding: vector[],
    //     });
    // }

    // #[test_only]
    // public(package) fun test_init(ctx: &mut TxContext) {
    //     init(ctx);
    // }

    // ======== Authority ========

    public(package) fun verify(
        version: &Version,
        ctx: &TxContext,
    ) {
        version_check(version);

        assert!(
            vec_set::contains(&version.authority, &tx_context::sender(ctx)),
            error::unauthorized()
        );
    }

    // entry fun add_authorized_user(
    //     version: &mut Version,
    //     user_address: address,
    //     ctx: &TxContext,
    // ) {
    //     verify(version, ctx);

    //     assert!(!vec_set::contains(&version.authority, &user_address), error::authority_already_existed());
    //     vec_set::insert(&mut version.authority, user_address);
    // }

    // entry fun remove_authorized_user(
    //     version: &mut Version,
    //     user_address: address,
    //     ctx: &TxContext,
    // ) {
    //     verify(version, ctx);

    //     assert!(vec_set::contains(&version.authority, &user_address), error::authority_doest_not_exist());
    //     vec_set::remove(&mut version.authority, &user_address);
    //     assert!(vec_set::size(&version.authority) > 0, error::authority_empty());
    // }

    // ======== Tails Exp & Leaderboard ========
    use typus::ecosystem::{Version as TypusEcosystemVersion};
    use typus::leaderboard::{Self, TypusLeaderboardRegistry};
    use typus::user::{Self, TypusUserRegistry};

    // TODO: can be remove after install
    // entry fun install_ecosystem_manager_cap_entry(
    //     version: &mut Version,
    //     typus_ecosystem_version: &TypusEcosystemVersion,
    //     ctx: &TxContext,
    // ) {
    //     verify(version, ctx);
    //     let manager_cap = ecosystem::issue_manager_cap(typus_ecosystem_version, ctx);
    //     dynamic_field::add(&mut version.id, std::string::utf8(ECOSYSTEM_MANAGER_CAP), manager_cap);
    // }

    public(package) fun add_tails_exp_and_leaderboard(
        version: &Version,
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_user_registry: &mut TypusUserRegistry,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        user: address,
        trading_fee_usd: u64,
        exp_multiplier: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let boosted_exp = ((trading_fee_usd as u128)
            * (exp_multiplier as u128)
            / (math::multiplier(math::get_usd_decimal()) as u128) as u64);
        user::add_tails_exp_amount(
            dynamic_field::borrow(&version.id, std::string::utf8(ECOSYSTEM_MANAGER_CAP)),
            typus_ecosystem_version,
            typus_user_registry,
            user,
            boosted_exp
        );
        leaderboard::score(
            dynamic_field::borrow(&version.id, std::string::utf8(ECOSYSTEM_MANAGER_CAP)),
            typus_ecosystem_version,
            typus_leaderboard_registry,
            std::ascii::string(b"exp_leaderboard"),
            user,
            boosted_exp,
            clock,
            ctx,
        );
    }

    public(package) fun add_competition_leaderboard(
        version: &Version,
        typus_ecosystem_version: &TypusEcosystemVersion,
        typus_leaderboard_registry: &mut TypusLeaderboardRegistry,
        leaderboard_key: String,
        user: address,
        score: u64,
        clock: &sui::clock::Clock,
        ctx: &mut TxContext,
    ) {
        leaderboard::score(
            dynamic_field::borrow(&version.id, std::string::utf8(ECOSYSTEM_MANAGER_CAP)),
            typus_ecosystem_version,
            typus_leaderboard_registry,
            leaderboard_key,
            user,
            score,
            clock,
            ctx,
        );
    }

    // ======== Fee Pool ========

    public struct FeePool has key, store {
        id: UID,
        fee_infos: vector<FeeInfo>,
    }

    public struct FeeInfo has copy, drop, store {
        token: TypeName,
        value: u64,
    }

    public struct SendFeeEvent has copy, drop {
        token: TypeName,
        amount: u64,
    }
    entry fun send_fee<TOKEN>(
        version: &mut Version,
        ctx: &mut TxContext,
    ) {
        version_check(version);

        let mut i = 0;
        while (i < vector::length(&version.fee_pool.fee_infos)) {
            let fee_info = vector::borrow_mut(&mut version.fee_pool.fee_infos, i);
            if (fee_info.token == type_name::with_defining_ids<TOKEN>()) {
                if (fee_info.value > 0) {
                    transfer::public_transfer(
                        coin::from_balance<TOKEN>(
                            balance::withdraw_all(dynamic_field::borrow_mut(&mut version.fee_pool.id, type_name::with_defining_ids<TOKEN>())),
                            ctx,
                        ),
                        @typus_perp_fee_address,
                    );
                };
                emit(SendFeeEvent {
                    token: type_name::with_defining_ids<TOKEN>(),
                    amount: fee_info.value,
                });
                fee_info.value = 0;
                return
            };
            i = i + 1;
        };
    }
    public(package) fun charge_fee<TOKEN>(
        version: &mut Version,
        balance: Balance<TOKEN>,
    ) {
        let amount = balance.value();
        let mut i = 0;
        while (i < version.fee_pool.fee_infos.length()) {
            let fee_info = &mut version.fee_pool.fee_infos[i];
            if (fee_info.token == type_name::with_defining_ids<TOKEN>()) {
                fee_info.value = fee_info.value + amount;
                balance::join(
                    dynamic_field::borrow_mut(&mut version.fee_pool.id, type_name::with_defining_ids<TOKEN>()),
                    balance,
                );
                emit(ProtocolFeeEvent {
                    token: type_name::with_defining_ids<TOKEN>(),
                    amount,
                });
                return
            };
            i = i + 1;
        };
        // if not found, add new fee info
        version.fee_pool.fee_infos.push_back(
            FeeInfo {
                token: type_name::with_defining_ids<TOKEN>(),
                value: balance.value(),
            },
        );
        dynamic_field::add(&mut version.fee_pool.id, type_name::with_defining_ids<TOKEN>(), balance);
        emit(ProtocolFeeEvent {
            token: type_name::with_defining_ids<TOKEN>(),
            amount,
        });
    }
    public struct ProtocolFeeEvent has copy, drop {
        token: TypeName,
        amount: u64,
    }
    public struct PutInsuranceFundEvent has copy, drop {
        token: TypeName,
        amount: u64,
    }
    entry fun send_liquidator_fee<TOKEN>(
        version: &mut Version,
        ctx: &mut TxContext,
    ) {
        version_check(version);

        let mut i = 0;
        while (i < vector::length(&version.liquidator_fee_pool.fee_infos)) {
            let fee_info = vector::borrow_mut(&mut version.liquidator_fee_pool.fee_infos, i);
            if (fee_info.token == type_name::with_defining_ids<TOKEN>()) {
                transfer::public_transfer(
                    coin::from_balance<TOKEN>(
                        balance::withdraw_all(dynamic_field::borrow_mut(&mut version.liquidator_fee_pool.id, type_name::with_defining_ids<TOKEN>())),
                        ctx,
                    ),
                    @insurance_fund_address,
                );
                emit(SendFeeEvent {
                    token: type_name::with_defining_ids<TOKEN>(),
                    amount: fee_info.value,
                });
                fee_info.value = 0;
                return
            };
            i = i + 1;
        };
    }
    public(package) fun charge_liquidator_fee<TOKEN>(
        version: &mut Version,
        balance: Balance<TOKEN>,
    ) {
        let amount = balance.value();
        let mut i = 0;
        while (i < version.liquidator_fee_pool.fee_infos.length()) {
            let fee_info = &mut version.liquidator_fee_pool.fee_infos[i];
            if (fee_info.token == type_name::with_defining_ids<TOKEN>()) {
                fee_info.value = fee_info.value + amount;
                balance::join(
                    dynamic_field::borrow_mut(&mut version.liquidator_fee_pool.id, type_name::with_defining_ids<TOKEN>()),
                    balance,
                );
                emit(PutInsuranceFundEvent {
                    token: type_name::with_defining_ids<TOKEN>(),
                    amount,
                });
                return
            };
            i = i + 1;
        };
        // if not found, add new fee info
        version.liquidator_fee_pool.fee_infos.push_back(
            FeeInfo {
                token: type_name::with_defining_ids<TOKEN>(),
                value: balance.value(),
            },
        );
        dynamic_field::add(&mut version.liquidator_fee_pool.id, type_name::with_defining_ids<TOKEN>(), balance);
        emit(PutInsuranceFundEvent {
            token: type_name::with_defining_ids<TOKEN>(),
            amount,
        });
    }
}