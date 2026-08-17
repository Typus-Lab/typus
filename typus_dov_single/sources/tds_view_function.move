module typus_dov::tds_view_function {
    use std::bcs;
    use std::type_name;

    use typus_dov::typus_dov_single::{Self, Registry};
    use typus_framework::big_vector;
    use typus_framework::dutch;
    use typus_framework::vault::{Self, TypusDepositReceipt, TypusBidReceipt};

    /// [View Function Only] Gets the data for one or more vaults, BCS-encoded.
    public(package) fun get_vault_data_bcs(
        registry: &Registry,
        mut indexes: vector<u64>,
    ): vector<vector<u8>> {
        let (
            _id,
            num_of_vault,
            _authority,
            _fee_pool,
            portfolio_vault_registry,
            deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_registry_inner(registry);

        let mut result = vector::empty();
        if (vector::is_empty(&indexes)) {
            let mut index = 0;
            while (index < *num_of_vault) {
                if (typus_dov_single::portfolio_vault_exists(portfolio_vault_registry, index)) {
                    let mut data = vector::empty();
                    let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, index);
                    vector::append(&mut data, bcs::to_bytes(portfolio_vault));
                    let deposit_vault = typus_dov_single::get_deposit_vault(deposit_vault_registry, index);
                    vector::append(&mut data, bcs::to_bytes(deposit_vault));
                    vector::push_back(&mut result, data);
                };
                index = index + 1;
            };
        } else {
            while (!vector::is_empty(&indexes)) {
                let index = vector::pop_back(&mut indexes);
                if (typus_dov_single::portfolio_vault_exists(portfolio_vault_registry, index)) {
                    let mut data = vector::empty();
                    let portfolio_vault = typus_dov_single::get_portfolio_vault(portfolio_vault_registry, index);
                    vector::append(&mut data, bcs::to_bytes(portfolio_vault));
                    let deposit_vault = typus_dov_single::get_deposit_vault(deposit_vault_registry, index);
                    vector::append(&mut data, bcs::to_bytes(deposit_vault));
                    vector::push_back(&mut result, data);
                }
            };
        };

        result
    }

    /// [View Function Only] Gets the data for one or more auctions, BCS-encoded.
    public(package) fun get_auction_bcs(
        registry: &Registry,
        mut indexes: vector<u64>,
    ): vector<vector<u8>> {
        let (
            _id,
            num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_registry_inner(registry);

        let mut result = vector::empty();
        if (vector::is_empty(&indexes)) {
            let mut index = 0;
            while (index < *num_of_vault) {
                if (typus_dov_single::auction_exists(auction_registry, index)) {
                    let auction = typus_dov_single::get_auction(auction_registry, index);
                    vector::push_back(&mut result, bcs::to_bytes(auction));
                };
                index = index + 1;
            };
        } else {
            while (!vector::is_empty(&indexes)) {
                let index = vector::pop_back(&mut indexes);
                if (typus_dov_single::auction_exists(auction_registry, index)) {
                    let auction = typus_dov_single::get_auction(auction_registry, index);
                    vector::push_back(&mut result, bcs::to_bytes(auction));
                }
            };
        };

        result
    }

    /// [View Function Only] Gets the bids for a specific auction, BCS-encoded.
    public(package) fun get_auction_bids_bcs(
        registry: &Registry,
        index: u64,
    ): vector<vector<u8>> {
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_registry_inner(registry);

        let mut result = vector::empty();
        if (typus_dov_single::auction_exists(auction_registry, index)) {
            let auction = typus_dov_single::get_auction(auction_registry, index);
            let bids = dutch::bids(auction);
            let length = big_vector::length(bids);
            let slice_size = big_vector::slice_size(bids);
            let mut slice = big_vector::borrow_slice(bids, 1);
            let mut i = 0;
            while (i < length) {
                let bid = vector::borrow(slice, i % slice_size);
                vector::push_back(&mut result, bcs::to_bytes(bid));
                if (i + 1 < length && (i + 1) % slice_size == 0) {
                    let slice_id = big_vector::slice_id(bids, i + 1);
                    slice = big_vector::borrow_slice(
                        bids,
                        slice_id,
                    );
                };
                i = i + 1;
            };
        };

        result
    }

    /// A struct representing a user's deposit shares.
    public struct DepositShare has drop {
        index: u64,
        active_share: u64,
        deactivating_share: u64,
        inactive_share: u64,
        warmup_share: u64,
        premium_share: u64,
        incentive_share: u64,
    }
    /// [View Function Only] Gets the deposit shares for a user, BCS-encoded.
    public(package) fun get_deposit_shares_bcs(
        registry: &Registry,
        mut receipts: vector<TypusDepositReceipt>,
        user: address,
    ): vector<vector<u8>> {
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            _refund_vault_registry,
            additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_registry_inner(registry);

        let mut result = vector[typus_dov_single::get_deposit_snapshot_bcs(additional_config_registry, user)];
        while (!vector::is_empty(&receipts)) {
            let mut vault_receipts = vector::empty();
            let receipt = vector::pop_back(&mut receipts);
            let index = vault::get_deposit_receipt_index(&receipt);
            vector::push_back(&mut vault_receipts, receipt);
            while (!vector::is_empty(&receipts)) {
                if (vault::get_deposit_receipt_index(vector::borrow(&receipts, vector::length(&receipts) - 1)) != index) {
                    break
                } else {
                    let receipt = vector::pop_back(&mut receipts);
                    vector::push_back(&mut vault_receipts, receipt);
                };
            };
            let deposit_vault = typus_dov_single::get_deposit_vault(deposit_vault_registry, index);
            let (
                active_share,
                deactivating_share,
                inactive_share,
                warmup_share,
                premium_share,
                incentive_share,
            ) = vault::summarize_deposit_shares(deposit_vault, vault_receipts);
            let user_share = DepositShare {
                index,
                active_share,
                deactivating_share,
                inactive_share,
                warmup_share,
                premium_share,
                incentive_share,
            };
            vector::push_back(
                &mut result,
                bcs::to_bytes(&user_share),
            );
        };
        vector::destroy_empty(receipts);

        result
    }

    /// [View Function Only] Gets the bids for a user, BCS-encoded.
    /// WARNING: input receipts will be destroyed
    public(package) fun get_my_bids_bcs(
        registry: &Registry,
        mut receipts: vector<TypusBidReceipt>,
    ): vector<vector<u8>> {
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            bid_vault_registry,
            _refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_registry_inner(registry);

        let mut result = vector::empty();
        while (!vector::is_empty(&receipts)) {
            let mut vault_receipts = vector::empty();
            let receipt = vector::pop_back(&mut receipts);
            let (vid, index, _) = vault::get_bid_receipt_info(&receipt);
            vector::push_back(&mut vault_receipts, receipt);
            while (!vector::is_empty(&receipts)) {
                let (n_vid, n_index, _) = vault::get_bid_receipt_info(vector::borrow(&receipts, vector::length(&receipts) - 1));
                if (n_vid != vid || n_index != index) {
                    break
                } else {
                    let receipt = vector::pop_back(&mut receipts);
                    vector::push_back(&mut vault_receipts, receipt);
                };
            };
            let bid_vault = typus_dov_single::get_bid_vault_by_id_or_index(bid_vault_registry, &vid, index);
            let share = vault::summarize_bid_shares(bid_vault, vault_receipts);
            let mut data = bcs::to_bytes(bid_vault);
            vector::append(&mut data, bcs::to_bytes(&share));
            vector::push_back(
                &mut result,
                data,
            );
        };
        vector::destroy_empty(receipts);

        result
    }

    /// [View Function Only] Gets the refund shares for a user, BCS-encoded.
    public(package) fun get_refund_shares_bcs<TOKEN>(
        registry: &Registry,
        ctx: &TxContext,
    ): vector<u8> {
        let (
            _id,
            _num_of_vault,
            _authority,
            _fee_pool,
            _portfolio_vault_registry,
            _deposit_vault_registry,
            _auction_registry,
            _bid_vault_registry,
            refund_vault_registry,
            _additional_config_registry,
            _version,
            _transaction_suspended,
        ) = typus_dov_single::get_registry_inner(registry);

        let mut result = bcs::to_bytes(&type_name::with_defining_ids<TOKEN>());
        let share = if (typus_dov_single::refund_vault_exists<TOKEN>(refund_vault_registry)) {
            let refund_vault = typus_dov_single::get_refund_vault<TOKEN>(refund_vault_registry);
            vault::get_refund_share(refund_vault, tx_context::sender(ctx))
        } else {
            0
        };
        vector::append(&mut result, bcs::to_bytes(&share));

        result
    }
}