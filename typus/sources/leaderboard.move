// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0
module typus::leaderboard {
    use std::ascii::String;

    use sui::bcs;
    use sui::clock::Clock;
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::table::{Self, Table};

    use typus::critbit::{Self, CritbitTree};
    use typus::ecosystem::{ManagerCap, Version};
    use typus::linked_object_table::{Self, LinkedObjectTable};
    use typus::linked_set::{Self, LinkedSet};

    // ======== Typus Leaderboard ========

    public struct TypusLeaderboardRegistry has key {
        id: UID,
        active_leaderboard_registry: UID,
        inactive_leaderboard_registry: UID,
    }

    public struct Leaderboard has key, store {
        id: UID,
        start_ts_ms: u64,
        end_ts_ms: u64,
        score: Table<address, u64>,
        ranking: CritbitTree<LinkedSet<address>>,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(TypusLeaderboardRegistry {
            id: object::new(ctx),
            active_leaderboard_registry: object::new(ctx),
            inactive_leaderboard_registry: object::new(ctx),
        });
    }

    public struct ActivateLeaderboardEvent has copy, drop {
        key: String,
        id: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    public fun activate_leaderboard(
        version: &Version,
        registry: &mut TypusLeaderboardRegistry,
        key: String,
        start_ts_ms: u64,
        end_ts_ms: u64,
        ctx: &mut TxContext,
    ) {
        version.verify(ctx);

        if (!dynamic_field::exists_(&registry.active_leaderboard_registry, key)) {
            dynamic_field::add(
                &mut registry.active_leaderboard_registry,
                key,
                linked_object_table::new<address, Leaderboard>(ctx),
            );
        };
        let leaderboards: &mut LinkedObjectTable<address, Leaderboard> =
            dynamic_field::borrow_mut(&mut registry.active_leaderboard_registry, key);
        let leaderboard = Leaderboard {
            id: object::new(ctx),
            start_ts_ms,
            end_ts_ms,
            score: table::new(ctx),
            ranking: critbit::new(ctx),
        };
        emit(ActivateLeaderboardEvent {
            key,
            id: object::id_address(&leaderboard),
            log: vector[start_ts_ms, end_ts_ms],
            bcs_padding: vector[],
        });
        leaderboards.push_back(
            object::id_address(&leaderboard),
            leaderboard,
        );
    }

    public struct ExtendLeaderboardEvent has copy, drop {
        key: String,
        id: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    public fun extend_leaderboard(
        version: &Version,
        registry: &mut TypusLeaderboardRegistry,
        key: String,
        id: address,
        end_ts_ms: u64,
        ctx: &mut TxContext,
    ) {
        version.verify(ctx);

        let leaderboards: &mut LinkedObjectTable<address, Leaderboard> =
            dynamic_field::borrow_mut(&mut registry.active_leaderboard_registry, key);
        *&mut leaderboards[id].end_ts_ms = end_ts_ms;
        emit(ExtendLeaderboardEvent {
            key,
            id,
            log: vector[end_ts_ms],
            bcs_padding: vector[],
        });
    }

    public struct DeactivateLeaderboardEvent has copy, drop {
        key: String,
        id: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    public fun deactivate_leaderboard(
        version: &Version,
        registry: &mut TypusLeaderboardRegistry,
        key: String,
        id: address,
        ctx: &mut TxContext,
    ) {
        version.verify(ctx);

        if (!dynamic_field::exists_(&registry.inactive_leaderboard_registry, key)) {
            dynamic_field::add(
                &mut registry.inactive_leaderboard_registry,
                key,
                linked_object_table::new<address, Leaderboard>(ctx),
            );
        };
        let leaderboards: &mut LinkedObjectTable<address, Leaderboard> =
            dynamic_field::borrow_mut(&mut registry.active_leaderboard_registry, key);
        let leaderboard: Leaderboard = leaderboards.remove(id);
        emit(DeactivateLeaderboardEvent {
            key,
            id: object::id_address(&leaderboard),
            log: vector[],
            bcs_padding: vector[],
        });
        let leaderboards: &mut LinkedObjectTable<address, Leaderboard> =
            dynamic_field::borrow_mut(&mut registry.inactive_leaderboard_registry, key);
        leaderboards.push_back(
            object::id_address(&leaderboard),
            leaderboard,
        );
    }

    public struct RemoveLeaderboardEvent has copy, drop {
        key: String,
        id: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    public fun remove_leaderboard(
        version: &Version,
        registry: &mut TypusLeaderboardRegistry,
        key: String,
        id: address,
        ctx: &mut TxContext,
    ) {
        version.verify(ctx);

        let leaderboards: &mut LinkedObjectTable<address, Leaderboard> =
            dynamic_field::borrow_mut(&mut registry.inactive_leaderboard_registry, key);
        let Leaderboard {
            id,
            start_ts_ms: _,
            end_ts_ms: _,
            score,
            mut ranking,
        } = leaderboards.remove(id);
        emit(RemoveLeaderboardEvent {
            key,
            id: object::uid_to_address(&id),
            log: vector[],
            bcs_padding: vector[],
        });
        id.delete();
        score.drop();
        while (ranking.size() > 0) {
            ranking.remove_min_leaf().drop();
        };
        ranking.destroy_empty();
    }

    public struct ScoreEvent has copy, drop {
        key: String,
        id: address,
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    public fun delegate_score(
        version: &Version,
        registry: &mut TypusLeaderboardRegistry,
        key: String,
        user: address,
        score: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let manager_cap = version.issue_manager_cap(ctx);
        let log = score(
            &manager_cap,
            version,
            registry,
            key,
            user,
            score,
            clock,
            ctx,
        );
        version.burn_manager_cap(manager_cap, ctx);

        log
    }
    public fun score(
        _manager_cap: &ManagerCap,
        version: &Version,
        registry: &mut TypusLeaderboardRegistry,
        key: String,
        user: address,
        score: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        version.version_check();

        if (!dynamic_field::exists_(&registry.active_leaderboard_registry, key) || score == 0) {
            return vector[0]
        };
        let leaderboards: &mut LinkedObjectTable<address, Leaderboard> = dynamic_field::borrow_mut(&mut registry.active_leaderboard_registry, key);
        let ts_ms = clock.timestamp_ms();
        let mut first = *leaderboards.front();
        while (option::is_some(&first)) {
            let id = option::destroy_some(first);
            let leaderboard = leaderboards.borrow_mut(id);
            if (ts_ms >= leaderboard.start_ts_ms && ts_ms < leaderboard.end_ts_ms) {
                if (!leaderboard.score.contains(user)) {
                    leaderboard.score.add(user, 0);
                };
                let user_score = leaderboard.score.borrow_mut(user);
                let (has_leaf, index) = leaderboard.ranking.find_leaf(*user_score);
                if (has_leaf) {
                    if (critbit::borrow_mut_leaf_by_index(&mut leaderboard.ranking, index).length() == 1) {
                        critbit::remove_leaf_by_index(&mut leaderboard.ranking, index).drop();
                    } else {
                        linked_set::remove(
                            critbit::borrow_mut_leaf_by_index(&mut leaderboard.ranking, index),
                            user,
                        );
                    };
                };
                *user_score = *user_score + score;
                let (has_leaf, mut index) = leaderboard.ranking.find_leaf(*user_score);
                if (!has_leaf) {
                    index = critbit::insert_leaf(
                        &mut leaderboard.ranking,
                        *user_score,
                        linked_set::new(ctx),
                    );
                };
                linked_set::push_back(
                    critbit::borrow_mut_leaf_by_index(&mut leaderboard.ranking, index),
                    user,
                );
                emit(ScoreEvent {
                    key,
                    id: object::id_address(leaderboard),
                    user,
                    log: vector[score],
                    bcs_padding: vector[],
                });
                return vector[score]
            };
            first = *leaderboards.next(id);
        };

        vector[0]
    }

    public struct DeductEvent has copy, drop {
        key: String,
        id: address,
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    public fun delegate_deduct(
        version: &Version,
        registry: &mut TypusLeaderboardRegistry,
        key: String,
        user: address,
        score: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        let manager_cap = version.issue_manager_cap(ctx);
        let log = deduct(
            &manager_cap,
            version,
            registry,
            key,
            user,
            score,
            clock,
            ctx,
        );
        version.burn_manager_cap(manager_cap, ctx);

        log
    }
    public fun deduct(
        _manager_cap: &ManagerCap,
        version: &Version,
        registry: &mut TypusLeaderboardRegistry,
        key: String,
        user: address,
        score: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): vector<u64> {
        version.version_check();

        if (!dynamic_field::exists_(&registry.active_leaderboard_registry, key) || score == 0) {
            return vector[0]
        };
        let leaderboards: &mut LinkedObjectTable<address, Leaderboard> = dynamic_field::borrow_mut(&mut registry.active_leaderboard_registry, key);
        let ts_ms = clock.timestamp_ms();
        let mut first = *leaderboards.front();
        while (option::is_some(&first)) {
            let id = option::destroy_some(first);
            let leaderboard = leaderboards.borrow_mut(id);
            if (ts_ms >= leaderboard.start_ts_ms && ts_ms < leaderboard.end_ts_ms) {
                if (!leaderboard.score.contains(user)) {
                    return vector[0]
                };
                let user_score = leaderboard.score.borrow_mut(user);
                let (has_leaf, index) = leaderboard.ranking.find_leaf(*user_score);
                if (has_leaf) {
                    if (critbit::borrow_mut_leaf_by_index(&mut leaderboard.ranking, index).length() == 1) {
                        critbit::remove_leaf_by_index(&mut leaderboard.ranking, index).drop();
                    } else {
                        linked_set::remove(
                            critbit::borrow_mut_leaf_by_index(&mut leaderboard.ranking, index),
                            user,
                        );
                    };
                };
                *user_score = *user_score - score;
                if (user_score == 0) {
                    return vector[score]
                };
                let (has_leaf, mut index) = leaderboard.ranking.find_leaf(*user_score);
                if (!has_leaf) {
                    index = critbit::insert_leaf(
                        &mut leaderboard.ranking,
                        *user_score,
                        linked_set::new(ctx),
                    );
                };
                linked_set::push_back(
                    critbit::borrow_mut_leaf_by_index(&mut leaderboard.ranking, index),
                    user,
                );
                emit(DeductEvent {
                    key,
                    id: object::id_address(leaderboard),
                    user,
                    log: vector[score],
                    bcs_padding: vector[],
                });
                return vector[score]
            };
            first = *leaderboards.next(id);
        };

        vector[0]
    }

    public(package) fun get_rankings(
        version: &Version,
        registry: &TypusLeaderboardRegistry,
        key: String,
        id: address,
        mut ranks: u64,
        user: address,
        active: bool,
    ): vector<vector<u8>> {
        version.version_check();

        let uid = if (active) {
            &registry.active_leaderboard_registry
        } else {
            &registry.inactive_leaderboard_registry
        };
        let leaderboards: &LinkedObjectTable<address, Leaderboard> = dynamic_field::borrow(uid, key);
        let leaderboard: &Leaderboard = leaderboards.borrow(id);
        if (leaderboard.ranking.is_empty()) {
            return vector[bcs::to_bytes(&0)]
        };
        let mut result = if (leaderboard.score.contains(user)) {
            vector[bcs::to_bytes(leaderboard.score.borrow(user))]
        } else {
            vector[bcs::to_bytes(&0)]
        };
        let (mut max_score, mut max_score_index) = leaderboard.ranking.max_leaf();
        let mut max_leaf_bcs = bcs::to_bytes(&max_score);
        let mut max_leaf_users = vector[];
        let mut max_rankings = leaderboard.ranking.borrow_leaf_by_index(max_score_index);
        let mut front = *max_rankings.front().borrow();
        while (ranks > 0) {
            max_leaf_users.push_back(front);
            ranks = ranks - 1;
            let next = max_rankings.next(front);
            if (next.is_some()) {
                front = *next.borrow();
            } else {
                max_leaf_bcs.append(bcs::to_bytes(&max_leaf_users));
                result.push_back(max_leaf_bcs);
                let (next_max_score, next_max_score_index) = leaderboard.ranking.previous_leaf(max_score);
                if (next_max_score == 0) {
                    break
                };
                max_score = next_max_score;
                max_score_index = next_max_score_index;
                max_leaf_bcs = bcs::to_bytes(&max_score);
                max_leaf_users = vector[];
                max_rankings = leaderboard.ranking.borrow_leaf_by_index(max_score_index);
                front = *max_rankings.front().borrow();
            };
        };

        result
    }

    entry fun trim_leaderboard(
        version: &Version,
        registry: &mut TypusLeaderboardRegistry,
        key: String,
        id: address,
        active: bool,
        from: u64,
        to: u64,
        ctx: &TxContext,
    ) {
        version.verify(ctx);

        let uid = if (active) {
            &mut registry.active_leaderboard_registry
        } else {
            &mut registry.inactive_leaderboard_registry
        };
        let leaderboards: &mut LinkedObjectTable<address, Leaderboard> = dynamic_field::borrow_mut(uid, key);
        let leaderboard: &mut Leaderboard = leaderboards.borrow_mut(id);
        if (leaderboard.ranking.is_empty()) {
            return
        };
        let mut index = from;
        while (index <= to) {
            if (leaderboard.ranking.has_index(index)) {
                if (leaderboard.ranking.borrow_leaf_by_index(index).is_empty()) {
                    leaderboard.ranking.remove_leaf_by_index(index).drop();
                }
            };
            index = index + 1;
        }
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}