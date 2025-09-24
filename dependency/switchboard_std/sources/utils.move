module switchboard_std::utils {
    use sui::table_vec::{Self, TableVec};
    use sui::bag::{Self, Bag};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{TxContext};
    use std::vector;
    use std::type_name;
    use std::ascii;

    // swap remove for table vec
    public fun swap_remove<T: drop + store>(
        v: &mut TableVec<T>,
        idx: u64,
    ) {
        let last = table_vec::pop_back(v);
        let el = table_vec::borrow_mut(v, idx);
        *el = last;
    }

    // copy a portion of a vector into a new vector
    public fun slice(vec: &vector<u8>, start_index: u64, end_index: u64): vector<u8> {
        let result: vector<u8> = vector::empty();
        let max_index: u64 = vector::length(vec);
        let slice_end_index: u64 = if (end_index > max_index) { max_index } else { end_index };
        let i = start_index;
        while (i < slice_end_index) {
            let byte = vector::borrow(vec, i);
            vector::push_back(&mut result, *byte);
            i = i + 1;
        };
        result
    }

    // Escrow util functions

    public fun escrow_deposit<CoinType>(
        escrow_bag: &mut Bag,
        addr: address,
        coin: Coin<CoinType>
    ) {
        if (!bag::contains_with_type<address, Balance<CoinType>>(escrow_bag, addr)) {
            let escrow = balance::zero<CoinType>();
            coin::put(&mut escrow, coin);
            bag::add<address, Balance<CoinType>>(escrow_bag, addr, escrow);
        } else {
            let escrow = bag::borrow_mut<address, Balance<CoinType>>(escrow_bag, addr);
            coin::put(escrow, coin);
        }
    }

    public fun escrow_withdraw<CoinType>(
        escrow_bag: &mut Bag,
        addr: address,
        amount: u64,
        ctx: &mut TxContext,
    ): Coin<CoinType> {
        let escrow = bag::borrow_mut<address, Balance<CoinType>>(escrow_bag, addr);
        coin::take(escrow, amount, ctx)
    }

    public fun escrow_balance<CoinType>(
        escrow_bag: &Bag,
        key: address
    ): u64 {
        if (!bag::contains_with_type<address, Balance<CoinType>>(escrow_bag, key)) {
            0
        } else {
            let escrow = bag::borrow<address, Balance<CoinType>>(escrow_bag, key);
            balance::value(escrow)
        }
    }

    public fun type_of<T>(): vector<u8> {
        ascii::into_bytes(type_name::into_string(type_name::with_defining_ids<T>()))
    }

    // get mr_enclave and report body
    public fun parse_sgx_quote(quote: &vector<u8>): (vector<u8>, vector<u8>) {


        // snag relevant data from the quote
        let mr_enclave: vector<u8> = slice(quote, 112, 144);
        let report_body: vector<u8> = slice(quote, 368, 432);

        // Parse the SGX quote header
        // let _version: u16 = u16_from_le_bytes(&slice(&quote, 0, 2));
        // let _sign_type: u16 = u16_from_le_bytes(&slice(&quote, 2, 4));
        // let _epid_group_id: vector<u8> = slice(&quote, 4, 8);
        // let _qe_svn: u16 = u16_from_le_bytes(&slice(&quote, 8, 10));
        // let _pce_svn: u16 = u16_from_le_bytes(&slice(&quote, 10, 12));
        // let _qe_vendor_id: vector<u8> = slice(&quote, 12, 28);
        // let _user_data: vector<u8> = slice(&quote, 16, 48);

        // Parse the SGX &quote body
        // let report: vector<u8> = slice(&quote, 48, 48 + 384);
        // let _cpu_svn: vector<u8> = slice(&report, 0, 16);
        // let _misc_select: vector<u8> = slice(&report, 16, 20);
        // let _reserved1: vector<u8> = slice(&report, 20, 48);
        // let _attributes: vector<u8> = slice(&report, 48, 64);
        // let mr_enclave: vector<u8> = slice(&report, 64, 96);
        // let _reserved2: vector<u8> = slice(&report, 96, 128);
        // let _mr_signer: vector<u8> = slice(&report, 128, 160);
        // let _reserved3: vector<u8> = slice(&report, 160, 256);
        // let _isv_prod_id: u16 = u16_from_le_bytes(&slice(&report, 256, 258));
        // let _isv_svn: u16 = u16_from_le_bytes(&slice(&report, 258, 260));
        // let _reserved4: vector<u8> = slice(&report, 260, 320);
        // let report_body: vector<u8> = slice(&report, 320, 384);

        // print everything
        // std::debug::print(&_version);
        // std::debug::print(&_sign_type);
        // std::debug::print(&_epid_group_id);
        // std::debug::print(&_qe_svn);
        // std::debug::print(&_pce_svn);
        // std::debug::print(&_qe_vendor_id);
        // std::debug::print(&_user_data);
        // std::debug::print(&report);
        // std::debug::print(&_cpu_svn);
        // std::debug::print(&_misc_select);
        // std::debug::print(&_reserved1);
        // std::debug::print(&_attributes);
        // std::debug::print(&mr_enclave);
        // std::debug::print(&_reserved2);
        // std::debug::print(&_mr_signer);
        // std::debug::print(&_reserved3);
        // std::debug::print(&_isv_prod_id);
        // std::debug::print(&_isv_svn);
        // std::debug::print(&_reserved4);
        // std::debug::print(&_report_body);

        // Return the mr_enclave value
        (mr_enclave, report_body)
    }

    public fun u16_from_le_bytes(bytes: &vector<u8>): u16 {
        ((*(vector::borrow(bytes, 0)) as u16) <<  0) +
        ((*(vector::borrow(bytes, 1)) as u16) <<  8)
    }


    public fun u32_from_le_bytes(bytes: &vector<u8>): u32 {
        ((*(vector::borrow(bytes, 0)) as u32) <<  0) +
        ((*(vector::borrow(bytes, 1)) as u32) <<  8) +
        ((*(vector::borrow(bytes, 2)) as u32) << 16) +
        ((*(vector::borrow(bytes, 3)) as u32) << 24)
    }
}
