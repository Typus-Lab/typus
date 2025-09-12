// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module implements a leaderboard system for tracking user scores and rankings.
/// It supports multiple leaderboards, each with its own start and end time.
/// Leaderboards can be activated, extended, deactivated, and removed.
/// User scores can be updated, and rankings can be retrieved.
module typus::leaderboard {
    use std::ascii::String;
    use std::option::{Self, Option};

    use sui::bcs;
    use sui::clock::Clock;
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::TxContext;

    use typus::critbit::{Self, CritbitTree};
    use typus::ecosystem::{ManagerCap, Version};
    use typus::linked_object_table::{Self, LinkedObjectTable};
    use typus::linked_set::{Self, LinkedSet};

    // ======== Typus Leaderboard ========

    /// A registry for all leaderboards, separating them into active and inactive categories.
    public struct TypusLeaderboardRegistry has key {
        id: UID,
        /// A UID for the dynamic field that stores the active leaderboards.
        active_leaderboard_registry: UID,
        /// A UID for the dynamic field that stores the inactive leaderboards.
        inactive_leaderboard_registry: UID,
    }

    /// Represents a single leaderboard.
    public struct Leaderboard has key, store {
        /// The unique identifier of the Leaderboard object.
        id: UID,
        /// The start timestamp of the leaderboard in milliseconds.
        start_ts_ms: u64,
        /// The end timestamp of the leaderboard in milliseconds.
        end_ts_ms: u64,
        /// A table mapping user addresses to their scores.
        score: Table<address, u64>,
        /// A Crit-bit tree for ranking users by score. The value is a linked set of user addresses with the same score.
        ranking: CritbitTree<LinkedSet<address>>,
    }

    /// Initializes the `TypusLeaderboardRegistry` and shares it.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(TypusLeaderboardRegistry {
            id: object::new(ctx),
            active_leaderboard_registry: object::new(ctx),
            inactive_leaderboard_registry: object::new(ctx),
        });
    }

    /// Event emitted when a leaderboard is activated.
    public struct ActivateLeaderboardEvent has copy, drop {
        key: String,
        id: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Activates a new leaderboard.
    /// This is an authorized function.
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
        linked_object_table::push_back(
            leaderboards,
            object::id_address(&leaderboard),
            leaderboard,
        );
    }

    /// Event emitted when a leaderboard's end time is extended.
    public struct ExtendLeaderboardEvent has copy, drop {
        key: String,
        id: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Extends the end time of an active leaderboard.
    /// This is an authorized function.
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

    /// Event emitted when a leaderboard is deactivated.
    public struct DeactivateLeaderboardEvent has copy, drop {
        key: String,
        id: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Deactivates a leaderboard, moving it from the active to the inactive registry.
    /// This is an authorized function.
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
        let leaderboard: Leaderboard = linked_object_table::remove(leaderboards, id);
        emit(DeactivateLeaderboardEvent {
            key,
            id: object::id_address(&leaderboard),
            log: vector[],
            bcs_padding: vector[],
        });
        let leaderboards: &mut LinkedObjectTable<address, Leaderboard> =
            dynamic_field::borrow_mut(&mut registry.inactive_leaderboard_registry, key);
        linked_object_table::push_back(
            leaderboards,
            object::id_address(&leaderboard),
            leaderboard,
        );
    }

    /// Event emitted when a leaderboard is removed.
    public struct RemoveLeaderboardEvent has copy, drop {
        key: String,
        id: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// Removes a leaderboard from the inactive registry.
    /// This is an authorized function.
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
        } = linked_object_table::remove(leaderboards, id);
        emit(RemoveLeaderboardEvent {
            key,
            id: object::uid_to_address(&id),
            log: vector[],
            bcs_padding: vector[],
        });
        object::delete(id);
        table::drop(score);
        while (critbit::size(&ranking) > 0) {
            critbit::remove_min_leaf(&mut ranking).drop();
        };
        critbit::destroy_empty(ranking);
    }

    /// Event emitted when a user's score is updated.
    public struct ScoreEvent has copy, drop {
        key: String,
        id: address,
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// A wrapper function that delegates the call to the `score` function.
    /// It requires a `ManagerCap` for authorization.
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
    /// Updates a user's score on all active leaderboards.
    /// This function is authorized by requiring a `ManagerCap`.
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
        let mut first = *linked_object_table::front(leaderboards);
        while (option::is_some(&first)) {
            let id = option::destroy_some(first);
            let leaderboard = linked_object_table::borrow_mut(leaderboards, id);
            if (ts_ms >= leaderboard.start_ts_ms && ts_ms < leaderboard.end_ts_ms) {
                if (!table::contains(&leaderboard.score, user)) {
                    table::add(&mut leaderboard.score, user, 0);
                };
                let user_score = table::borrow_mut(&mut leaderboard.score, user);
                let (has_leaf, index) = critbit::find_leaf(&leaderboard.ranking, *user_score);
                if (has_leaf) {
                    if (linked_set::length(critbit::borrow_mut_leaf_by_index(&mut leaderboard.ranking, index)) == 1) {
                        critbit::remove_leaf_by_index(&mut leaderboard.ranking, index).drop();
                    } else {
                        linked_set::remove(
                            critbit::borrow_mut_leaf_by_index(&mut leaderboard.ranking, index),
                            user,
                        );
                    };
                };
                *user_score = *user_score + score;
                let (has_leaf, mut index) = critbit::find_leaf(&leaderboard.ranking, *user_score);
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
            first = *linked_object_table::next(leaderboards, id);
        };

        vector[0]
    }

    /// Event emitted when a user's score is deducted.
    public struct DeductEvent has copy, drop {
        key: String,
        id: address,
        user: address,
        log: vector<u64>,
        bcs_padding: vector<vector<u8>>,
    }
    /// A wrapper function that delegates the call to the `deduct` function.
    /// It requires a `ManagerCap` for authorization.
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
    /// Deducts a user's score on all active leaderboards.
    /// This function is authorized by requiring a `ManagerCap`.
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
        let mut first = *linked_object_table::front(leaderboards);
        while (option::is_some(&first)) {
            let id = option::destroy_some(first);
            let leaderboard = linked_object_table::borrow_mut(leaderboards, id);
            if (ts_ms >= leaderboard.start_ts_ms && ts_ms < leaderboard.end_ts_ms) {
                if (!table::contains(&leaderboard.score, user)) {
                    return vector[0]
                };
                let user_score = table::borrow_mut(&mut leaderboard.score, user);
                let (has_leaf, index) = critbit::find_leaf(&leaderboard.ranking, *user_score);
                if (has_leaf) {
                    if (linked_set::length(critbit::borrow_mut_leaf_by_index(&mut leaderboard.ranking, index)) == 1) {
                        critbit::remove_leaf_by_index(&mut leaderboard.ranking, index).drop();
                    } else {
                        linked_set::remove(
                            critbit::borrow_mut_leaf_by_index(&mut leaderboard.ranking, index),
                            user,
                        );
                    };
                };
                *user_score = *user_score - score;
                if (*user_score == 0) {
                    return vector[score]
                };
                let (has_leaf, mut index) = critbit::find_leaf(&leaderboard.ranking, *user_score);
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
            first = *linked_object_table::next(leaderboards, id);
        };

        vector[0]
    }

    /// Retrieves the rankings from a leaderboard.
    /// It returns the user's score and the top `ranks` users.
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
        let leaderboard: &Leaderboard = linked_object_table::borrow(leaderboards, id);
        if (critbit::is_empty(&leaderboard.ranking)) {
            return vector[bcs::to_bytes(&0)]
        };
        let mut result = if (table::contains(&leaderboard.score, user)) {
            vector[bcs::to_bytes(table::borrow(&leaderboard.score, user))]
        } else {
            vector[bcs::to_bytes(&0)]
        };
        let (mut max_score, mut max_score_index) = critbit::max_leaf(&leaderboard.ranking);
        let mut max_leaf_bcs = bcs::to_bytes(&max_score);
        let mut max_leaf_users = vector[];
        let mut max_rankings = critbit::borrow_leaf_by_index(&leaderboard.ranking, max_score_index);
        let mut front = *linked_set::front(max_rankings).borrow();
        while (ranks > 0) {
            max_leaf_users.push_back(front);
            ranks = ranks - 1;
            let next = linked_set::next(max_rankings, front);
            if (option::is_some(&next)) {
                front = *option::borrow(&next);
            } else {
                max_leaf_bcs.append(bcs::to_bytes(&max_leaf_users));
                result.push_back(max_leaf_bcs);
                let (next_max_score, next_max_score_index) = critbit::previous_leaf(&leaderboard.ranking, max_score);
                if (next_max_score == 0) {
                    break
                };
                max_score = next_max_score;
                max_score_index = next_max_score_index;
                max_leaf_bcs = bcs::to_bytes(&max_score);
                max_leaf_users = vector[];
                max_rankings = critbit::borrow_leaf_by_index(&leaderboard.ranking, max_score_index);
                front = *linked_set::front(max_rankings).borrow();
            };
        };

        result
    }

    /// Trims empty leaves from a leaderboard's ranking tree.
    /// This is an authorized function.
    entry fun trim_leaderboard(
        version: &Version,
        registry: &mut TypusLeaderboardRegistry,
        key: String,
        id: address,
        active: bool,
        from: u64,
        to: u64,
        ctx: &mut TxContext,
    ) {
        version.verify(ctx);

        let uid = if (active) {
            &mut registry.active_leaderboard_registry
        } else {
            &mut registry.inactive_leaderboard_registry
        };
        let leaderboards: &mut LinkedObjectTable<address, Leaderboard> = dynamic_field::borrow_mut(uid, key);
        let leaderboard: &mut Leaderboard = linked_object_table::borrow_mut(leaderboards, id);
        if (critbit::is_empty(&leaderboard.ranking)) {
            return
        };
        let mut index = from;
        while (index <= to) {
            if (critbit::has_index(&leaderboard.ranking, index)) {
                if (linked_set::is_empty(critbit::borrow_leaf_by_index(&leaderboard.ranking, index))) {
                    critbit::remove_leaf_by_index(&mut leaderboard.ranking, index).drop();
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