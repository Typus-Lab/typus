module typus_dov::tds_witness_entry {
    use std::string::{Self, String};

    use sui::balance::Balance;
    use sui::clock::Clock;
    use sui::event::emit;

    use typus_dov::typus_dov_single::{Self, Registry};
    use typus_framework::vault::TypusBidReceipt;
    use typus::witness_lock::{Self, HotPotato};
    use typus::ecosystem::Version as TypusEcosystemVersion;

    #[error]
    const EinvalidWitness: vector<u8> = b"invalid_witness";

    /// Executes an OTC deal with a witness.
    /// WARNING: without authority check inside.
    #[deprecated, allow(unused)]
    public fun otc<W: drop, D_TOKEN, B_TOKEN>(
        witness: W,
        signature: vector<u8>,
        registry: &mut Registry,
        index: u64,
        price: u64,
        size: u64,
        mut balance: Balance<B_TOKEN>,
        ts_ms: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Option<TypusBidReceipt>, Option<Balance<B_TOKEN>>, vector<u64>) {
        // // without authority check
        // safety_check<W, D_TOKEN, B_TOKEN>(witness, registry, index);

        // let mut msg = vector[];
        // msg.append(bcs::to_bytes(&index));
        // msg.append(bcs::to_bytes(&price));
        // msg.append(bcs::to_bytes(&size));
        // msg.append(bcs::to_bytes(&balance));
        // msg.append(bcs::to_bytes(&ts_ms));
        // assert!(
        //     bls12381::bls12381_min_pk_verify(&signature, &C_PUBLIC_KEY, &msg),
        //     E_INVALID_SIGNATURE
        // );
        // assert!(clock::timestamp_ms(clock) <= ts_ms + 20_000, E_EXPIRED_SIGNATURE);
        // // main logic
        // let (
        //     _id,
        //     _num_of_vault,
        //     _authority,
        //     _fee_pool,
        //     portfolio_vault_registry,
        //     _deposit_vault_registry,
        //     _auction_registry,
        //     _bid_vault_registry,
        //     _refund_vault_registry,
        //     _additional_config_registry,
        //     _version,
        //     _transaction_suspended,
        // ) = typus_dov_single::get_mut_registry_inner(registry);
        // let bid_fee_bp = typus_dov_single::get_bid_fee_bp(portfolio_vault_registry, index);
        // let fee_balance_value = ((balance.value() as u128) * (bid_fee_bp as u128) / 10000) as u64;
        // let fee_balance = balance.split(fee_balance_value);
        // let (receipt, balance, log) = typus_dov_single::witness_otc_<D_TOKEN, B_TOKEN>(
        //     registry,
        //     index,
        //     price,
        //     size,
        //     balance,
        //     fee_balance,
        //     clock,
        //     ctx,
        // );
        // typus_dov_single::emit_witness_otc_event(
        //     type_name::with_defining_ids<W>(),
        //     registry,
        //     index,
        //     log[0],
        //     log[1],
        //     log[2],
        //     log[3],
        //     ctx,
        // );

        // (receipt, balance, log)
        abort 0
    }

    const TYPUS_GALAXY_DOV_ALPHALEND_WITNESS: vector<u8> = b"37853e40e10a44aa9ded5a7bf9c3e2d973830f290dfd03cfbfd76213dd1b8627::dov_alphalend::WITNESS";

    /// A helper function to get the witness string for a given lending protocol.
    /// TODO: extend supported witnesses
    fun lending_witness(
        lending_index: u64
    ): String {
        // 0: none, 1: scallop spool, 2: scallop, 3: suilend, 4: navi, 5: alphalend
        if (lending_index == 5) {
            return string::utf8(TYPUS_GALAXY_DOV_ALPHALEND_WITNESS)
        };

        abort EinvalidWitness
    }

    /// A generic witness struct.
    public struct WITNESS has drop {}

    /// Event emitted when a lending account cap is created.
    public struct CreateLendingAccountCap has copy, drop {
        signer: address,
        index: u64,
        lending_index: u64,
        account_cap_id: address,
    }
    /// [Authorized Function] Adds a lending account cap to the registry.
    public fun add_lending_account_cap<CAP: key + store>(
        registry: &mut Registry,
        index: u64,
        lending_index: u64,
        account_cap: CAP,
        ctx: &mut TxContext,
    ) {
        // with authority check
        // without token check
        typus_dov_single::validate_portfolio_authority(registry, index, ctx);
        typus_dov_single::version_check(registry);

        // main logic
        let account_cap_id = typus_dov_single::add_lending_account_cap_(registry, index, lending_index, account_cap);

        // emit event
        emit(CreateLendingAccountCap {
            signer: tx_context::sender(ctx),
            index,
            lending_index,
            account_cap_id,
        });
    }

    /// [Authorized Function] Borrows a lending account cap from the registry.
    public fun borrow_lending_account_cap<CAP: key + store>(
        typus_ecosystem_version: &TypusEcosystemVersion,
        registry: &mut Registry,
        index: u64,
        lending_index: u64,
        ctx: &mut TxContext,
    ): (HotPotato<CAP>, typus_dov_single::LendingCapHotPotato) {
        // with authority check
        // without token check
        typus_dov_single::validate_portfolio_authority(registry, index, ctx);
        typus_dov_single::version_check(registry);

        // main logic
        let (cap, cap_hot_potato) = typus_dov_single::borrow_lending_account_cap_<CAP>(registry, index, lending_index);

        let witness = lending_witness(lending_index);
        let wrapped_cap = witness_lock::wrap(typus_ecosystem_version, cap, witness);

        (wrapped_cap, cap_hot_potato)
    }


    /// [Authorized Function] Returns a lending account cap to the registry.
    public fun return_lending_account_cap<CAP: key + store>(
        typus_ecosystem_version: &TypusEcosystemVersion,
        registry: &mut Registry,
        index: u64,
        account_cap: HotPotato<CAP>,
        lending_cap_hot_potato: typus_dov_single::LendingCapHotPotato,
        ctx: &mut TxContext,
    ) {
        // with authority check
        // without token check
        typus_dov_single::validate_portfolio_authority(registry, index, ctx);
        typus_dov_single::version_check(registry);

        // main logic
        let account_cap = witness_lock::unwrap(typus_ecosystem_version, account_cap, WITNESS{});
        typus_dov_single::return_lending_account_cap_(registry, account_cap, lending_cap_hot_potato);
    }

    /// Event emitted when funds are withdrawn for lending.
    public struct DepositLending has copy, drop {
        signer: address,
        index: u64,
        lending_index: u64,
        u64_padding: vector<u64>,
    }

    /// [Authorized Function] Withdraws funds from a vault for lending.
    public fun withdraw_for_lending<D_TOKEN, B_TOKEN>(
        typus_ecosystem_version: &TypusEcosystemVersion,
        registry: &mut Registry,
        index: u64,
        lending_index: u64,
        ctx: &mut TxContext,
    ): HotPotato<Balance<D_TOKEN>> {
        // with authority check
        typus_dov_single::validate_portfolio_authority(registry, index, ctx);
        typus_dov_single::version_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, index);

        let (balance, u64_padding) = typus_dov_single::withdraw_for_lending_<D_TOKEN>(registry, index, lending_index);
        emit(DepositLending {signer: tx_context::sender(ctx), index, lending_index, u64_padding });

        let witness = lending_witness(lending_index);
        witness_lock::wrap(typus_ecosystem_version, balance, witness)
    }

    /// Event emitted when funds are deposited from lending.
    public struct WithdrawLending has copy, drop {
        signer: address,
        index: u64,
        lending_index: u64,
        u64_padding: vector<u64>,
    }

    /// [Authorized Function] Deposits funds from a lending protocol back into the vault.
    public fun deposit_from_lending<D_TOKEN, B_TOKEN>(
        typus_ecosystem_version: &TypusEcosystemVersion,
        registry: &mut Registry,
        index: u64,
        lending_index: u64,
        d_balance: HotPotato<Balance<D_TOKEN>>,
        r_balance: Balance<D_TOKEN>,
        ctx: &mut TxContext,
    ) {
        // with authority check
        typus_dov_single::validate_portfolio_authority(registry, index, ctx);
        typus_dov_single::version_check(registry);
        typus_dov_single::portfolio_vault_token_check<D_TOKEN, B_TOKEN>(registry, index);

        let d_balance = witness_lock::unwrap(typus_ecosystem_version, d_balance, WITNESS{});

        let u64_padding = typus_dov_single::deposit_from_lending_<D_TOKEN>(registry, index, lending_index, d_balance, r_balance);
        emit(WithdrawLending {signer: tx_context::sender(ctx), index, lending_index, u64_padding });
    }
}