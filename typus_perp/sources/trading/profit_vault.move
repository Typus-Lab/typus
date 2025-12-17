module typus_perp::profit_vault {
    use std::type_name::{Self, TypeName};
    use sui::bcs;
    use sui::balance::{Self, Balance};
    use sui::clock::Clock;
    use sui::dynamic_field;
    use sui::event::emit;
    use sui::table::{Self, Table};
    use sui::vec_set::{Self, VecSet};

    use typus_perp::admin::{Self, Version};
    use typus_perp::error;

    public struct ProfitVault has key {
        id: UID,
        whitelist: VecSet<address>,
        user_profits: Table<address, vector<UserProfit>>,
        unlock_countdown_ts_ms: u64
    }

    public struct LockVault has key {
        id: UID,
        user_profits: Table<address, vector<LockedUserProfit>>,
    }

    public struct UserProfit has copy, drop, store {
        collateral_token: TypeName,
        base_token: TypeName,
        position_id: u64,
        order_id: u64,
        amount: u64,
        create_ts_ms: u64,
    }

    public struct LockedUserProfit has copy, drop, store {
        user_profit: UserProfit,
        create_ts_ms: u64,
    }

    public struct CreateProfitVaultEvent has copy, drop {
        unlock_countdown_ts_ms: u64,
    }
    entry fun create_profit_vault(version: &Version, unlock_countdown_ts_ms: u64, ctx: &mut TxContext) {
        // safety check
        admin::verify(version, ctx);

        let profit_vault = ProfitVault {
            id: object::new(ctx),
            whitelist: vec_set::empty(),
            user_profits: table::new(ctx),
            unlock_countdown_ts_ms
        };

        emit(CreateProfitVaultEvent { unlock_countdown_ts_ms });

        transfer::share_object(profit_vault);
    }

    entry fun create_lock_vault(version: &Version, ctx: &mut TxContext) {
        // safety check
        admin::verify(version, ctx);

        let lock_vault = LockVault {
            id: object::new(ctx),
            user_profits: table::new(ctx),
        };
        transfer::share_object(lock_vault);
    }


    public struct AddWhitelistEvent has copy, drop {
        new_whitelist_address: address
    }
    entry fun add_whitelist(
        version: &Version,
        profit_vault: &mut ProfitVault,
        user: address,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);
        assert!(!vec_set::contains(&profit_vault.whitelist, &user), error::whitelist_already_existed());
        profit_vault.whitelist.insert(user);

        emit(AddWhitelistEvent {
            new_whitelist_address: user
        });
    }

    public struct RemoveWhitelistEvent has copy, drop {
        removed_whitelist_address: address
    }
    entry fun remove_whitelist(
        version: &Version,
        profit_vault: &mut ProfitVault,
        user: address,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);
        assert!(vec_set::contains(&profit_vault.whitelist, &user), error::whitelist_not_existed());
        profit_vault.whitelist.remove(&user);

        emit(RemoveWhitelistEvent {
            removed_whitelist_address: user
        });
    }

    public struct UpdateUnlockCountdownTsMsEvent has copy, drop {
        previous: u64,
        new: u64
    }
    entry fun update_unlock_countdown_ts_ms(
        version: &Version,
        profit_vault: &mut ProfitVault,
        new_unlock_countdown_ts_ms: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);

        emit(UpdateUnlockCountdownTsMsEvent {
            previous: profit_vault.unlock_countdown_ts_ms,
            new: new_unlock_countdown_ts_ms
        });

        profit_vault.unlock_countdown_ts_ms = new_unlock_countdown_ts_ms;
    }

    public struct LockUserProfitEvent has copy, drop {
        user: address,
        user_profit: UserProfit,
    }
    entry fun lock_user_profit<TOKEN>(
        version: &Version,
        profit_vault: &mut ProfitVault,
        lock_vault: &mut LockVault,
        user: address,
        idx: u64,
        clock: &Clock,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);
        let token_type = type_name::with_defining_ids<TOKEN>();
        let current_ts_ms = clock.timestamp_ms();
        if (profit_vault.user_profits.contains(user)) {
            let profits = profit_vault.user_profits.borrow_mut(user);
            assert!(idx < profits.length(), error::invalid_idx());
            let locked_user_profit = LockedUserProfit {
                user_profit: profits.remove(idx),
                create_ts_ms: current_ts_ms
            };
            assert!(token_type == locked_user_profit.user_profit.collateral_token, error::collateral_token_type_mismatched());
            let locked_balance_value = locked_user_profit.user_profit.amount;
            if (lock_vault.user_profits.contains(user)) {
                let lock_profits = lock_vault.user_profits.borrow_mut(user);
                lock_profits.push_back(locked_user_profit);
            } else {
                lock_vault.user_profits.add(user, vector[locked_user_profit]);
            };

            let locked_balance = dynamic_field::borrow_mut<TypeName, Balance<TOKEN>>(
                &mut profit_vault.id, token_type
            ).split(locked_balance_value);

            if (dynamic_field::exists_(&lock_vault.id, token_type)) {
                dynamic_field::borrow_mut<TypeName, Balance<TOKEN>>(&mut lock_vault.id, token_type).join(locked_balance);
            } else {
                dynamic_field::add(&mut lock_vault.id, token_type, locked_balance);
            };
            if (profits.length() == 0) {
                let _user_profits = profit_vault.user_profits.remove(user);
            };

            emit(LockUserProfitEvent {
                user,
                user_profit: locked_user_profit.user_profit
            });
        };
    }

    public struct UnlockUserProfitEvent has copy, drop {
        user: address,
        user_profit: UserProfit,
    }
    entry fun unlock_user_profit<TOKEN>(
        version: &Version,
        profit_vault: &mut ProfitVault,
        lock_vault: &mut LockVault,
        user: address,
        idx: u64,
        ctx: &TxContext
    ) {
        // safety check
        admin::verify(version, ctx);
        let token_type = type_name::with_defining_ids<TOKEN>();
        if (lock_vault.user_profits.contains(user)) {
            let profits = lock_vault.user_profits.borrow_mut(user);
            assert!(idx < profits.length(), error::invalid_idx());
            let locked_user_profit = profits.remove(idx);
            assert!(token_type == locked_user_profit.user_profit.collateral_token, error::collateral_token_type_mismatched());
            let locked_balance_value = locked_user_profit.user_profit.amount;
            if (profit_vault.user_profits.contains(user)) {
                let user_profits = profit_vault.user_profits.borrow_mut(user);
                user_profits.push_back(locked_user_profit.user_profit);
            } else {
                profit_vault.user_profits.add(user, vector[locked_user_profit.user_profit]);
            };

            let locked_balance = dynamic_field::borrow_mut<TypeName, Balance<TOKEN>>(
                &mut lock_vault.id, token_type
            ).split(locked_balance_value);

            if (dynamic_field::exists_(&profit_vault.id, token_type)) {
                dynamic_field::borrow_mut<TypeName, Balance<TOKEN>>(&mut profit_vault.id, token_type).join(locked_balance);
            } else {
                dynamic_field::add(&mut profit_vault.id, token_type, locked_balance);
            };
            if (profits.length() == 0) {
                let _user_profits = lock_vault.user_profits.remove(user);
            };

            emit(UnlockUserProfitEvent {
                user,
                user_profit: locked_user_profit.user_profit
            });
        };
    }

    public struct PutUserProfitEvent has copy, drop {
        user: address,
        user_profit: UserProfit,
    }
    public(package) fun put_user_profit<C_TOKEN>(
        profit_vault: &mut ProfitVault,
        user: address,
        balance: Balance<C_TOKEN>,
        base_token_type: TypeName,
        position_id: u64,
        order_id: u64,
        clock: &Clock,
    ) {
        let collateral_token_type = type_name::with_defining_ids<C_TOKEN>();
        let user_profit = UserProfit {
            collateral_token: collateral_token_type,
            base_token: base_token_type,
            position_id,
            order_id,
            amount: balance.value(),
            create_ts_ms: clock.timestamp_ms(),
        };
        if (profit_vault.user_profits.contains(user)) {
            let profits = profit_vault.user_profits.borrow_mut(user);
            profits.push_back(user_profit);
        } else {
            profit_vault.user_profits.add(user, vector[user_profit]);
        };
        if (dynamic_field::exists_(&profit_vault.id, collateral_token_type)) {
            dynamic_field::borrow_mut<TypeName, Balance<C_TOKEN>>(&mut profit_vault.id, collateral_token_type).join(balance);
        } else {
            dynamic_field::add(&mut profit_vault.id, collateral_token_type, balance);
        };
        emit(PutUserProfitEvent { user, user_profit });
    }

    public struct WithdrawProfitEvent has copy, drop {
        token_type: TypeName,
        withdraw_amount: u64,
    }
    public fun withdraw_profit<TOKEN>(
        profit_vault: &mut ProfitVault,
        clock: &Clock,
        ctx: &mut TxContext
    ): Balance<TOKEN> {
        let token_type = type_name::with_defining_ids<TOKEN>();
        let current_ts_ms = clock.timestamp_ms();
        let user = tx_context::sender(ctx);
        let mut total_withdrawable = 0;
        let mut remaining_shares = vector::empty<UserProfit>();
        let balance = if (profit_vault.user_profits.contains(user)) {
            let mut profits = profit_vault.user_profits.remove(user);
            while (profits.length() > 0) {
                let user_profit = profits.pop_back();
                if (user_profit.collateral_token == token_type
                    && current_ts_ms >= user_profit.create_ts_ms + profit_vault.unlock_countdown_ts_ms
                ) {
                    total_withdrawable = total_withdrawable + user_profit.amount;
                } else {
                    remaining_shares.push_back(user_profit);
                };
            };

            if (remaining_shares.length() > 0) {
                profit_vault.user_profits.add(user, remaining_shares);
            };

            if (total_withdrawable > 0) {
                let balance = dynamic_field::borrow_mut<TypeName, Balance<TOKEN>>(
                    &mut profit_vault.id, token_type
                ).split(total_withdrawable);
                balance
            } else {
                balance::zero<TOKEN>()
            }
        } else {
            balance::zero<TOKEN>()
        };

        emit(WithdrawProfitEvent {
            token_type,
            withdraw_amount: balance.value()
        });

        balance
    }

    public(package) fun is_whitelist(
        profit_vault: &ProfitVault,
        user: address,
    ): bool {
        profit_vault.whitelist.contains(&user)
    }

    // ======= View Functions =======
    public(package) fun get_user_profits(
        version: &Version,
        profit_vault: &ProfitVault,
        user: address,
    ): vector<vector<u8>> {
        admin::version_check(version);
        let mut result = vector::empty<vector<u8>>();
        if (profit_vault.user_profits.contains(user)) {
            let user_profits = profit_vault.user_profits.borrow(user);
            user_profits.do_ref!(|user_profit|{
                result.push_back(bcs::to_bytes(user_profit));
            });
        };
        result
    }

    public(package) fun get_locked_user_profits(
        version: &Version,
        lock_vault: &LockVault,
        user: address,
    ): vector<vector<u8>> {
        admin::version_check(version);
        let mut result = vector::empty<vector<u8>>();
        if (lock_vault.user_profits.contains(user)) {
            let user_profits = lock_vault.user_profits.borrow(user);
            user_profits.do_ref!(|user_profit|{
                result.push_back(bcs::to_bytes(user_profit));
            });
        };
        result
    }
}