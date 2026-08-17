#[test_only]
extend module typus_framework::dutch {
    use sui::sui::SUI;

    #[test_only]
    public struct TEST has drop {}

    #[test]
    fun test_dutch() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut id = object::new(scenario.ctx());
        dynamic_field::add(&mut id, K_BIDDER_BALANCE, balance::zero<SUI>());
        dynamic_field::add(&mut id, K_INCENTIVE_BALANCE, balance::zero<SUI>());
        let mut auction = Auction {
            id,
            index: 0,
            token: type_name::with_defining_ids<SUI>(),
            start_ts_ms: 1736208000000,
            end_ts_ms: 1736294400000,
            size: 10000000000000,
            decay_speed: 1,
            initial_price: 2000000,
            final_price: 1000000,
            fee_bp: 1000,
            incentive_bp: 500,
            token_decimal: 9,
            size_decimal: 9,
            total_bid_size: 0,
            able_to_remove_bid: true,
            bids: big_vector::new(2, scenario.ctx()),
            bid_index: 0,
        };
        scenario.next_tx(@0xABCD);
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(22000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        scenario.next_tx(@0xA);
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(0, scenario.ctx())],
            balance::create_for_testing(22000000),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        scenario.next_tx(@0xABCD);
        clock.set_for_testing((1736208000000+1736294400000)/2);
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(22000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        clock.set_for_testing((1736208000000+1736294400000)/2+1);
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(22000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        clock.set_for_testing((1736208000000+1736294400000)/2+2);
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(22000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        clock.set_for_testing((1736208000000+1736294400000)/2+3);
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(22000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        remove_bid<SUI>(
            &mut auction,
            1736208000000,
            &clock,
            scenario.ctx(),
        ).destroy_for_testing();
        remove_bid<SUI>(
            &mut auction,
            (1736208000000+1736294400000)/2,
            &clock,
            scenario.ctx(),
        ).destroy_for_testing();
        remove_bid<SUI>(
            &mut auction,
            (1736208000000+1736294400000)/2+3,
            &clock,
            scenario.ctx(),
        ).destroy_for_testing();
        clock.set_for_testing((1736208000000+1736294400000)/2+4);
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(22000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        get_user_bid_info(&auction, 0);
        get_user_bid_info(&auction, 1736208000000);
        get_user_bid_info(&auction, (1736208000000+1736294400000)/2);
        get_bid_info(&auction, 10000000000000, 1000, 1736294400000);
        calculate_bid_size(1000, 9, 2000000, 22000000, 0);
        assert!(auction.token() == type_name::with_defining_ids<SUI>(), 0);
        assert!(auction.size() == 10000000000000, 0);
        assert!(auction.total_bid_size() == 40000000000, 0);
        assert!(auction.bid_index() == 7, 0);
        assert!(auction.incentive_bp() == 500, 0);
        auction.bids();
        get_decayed_price(&auction, &clock);
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        transfer::public_transfer(refund_vault, scenario.sender());
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_dutch_delivery() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut id = object::new(scenario.ctx());
        dynamic_field::add(&mut id, K_BIDDER_BALANCE, balance::zero<SUI>());
        dynamic_field::add(&mut id, K_INCENTIVE_BALANCE, balance::zero<SUI>());
        let mut auction = Auction {
            id,
            index: 0,
            token: type_name::with_defining_ids<SUI>(),
            start_ts_ms: 1736208000000,
            end_ts_ms: 1736294400000,
            size: 10000000000000,
            decay_speed: 1,
            initial_price: 2000000,
            final_price: 1000000,
            fee_bp: 1000,
            incentive_bp: 500,
            token_decimal: 9,
            size_decimal: 9,
            total_bid_size: 0,
            able_to_remove_bid: true,
            bids: big_vector::new(2, scenario.ctx()),
            bid_index: 0,
        };
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(22000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(0, scenario.ctx())],
            balance::create_for_testing(22000000),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        remove_bid<SUI>(
            &mut auction,
            1736208000000,
            &clock,
            scenario.ctx(),
        ).destroy_for_testing();
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(22000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        let (balance_x, balance_y, _, _, _, _, _, _) = delivery<SUI>(
            &mut fee_pool,
            &mut refund_vault,
            auction,
            true,
            &clock,
            scenario.ctx(),
        );
        balance_x.destroy_for_testing();
        balance_y.destroy_for_testing();
        let mut id = object::new(scenario.ctx());
        dynamic_field::add(&mut id, K_BIDDER_BALANCE, balance::zero<SUI>());
        dynamic_field::add(&mut id, K_INCENTIVE_BALANCE, balance::zero<SUI>());
        let mut auction = Auction {
            id,
            index: 0,
            token: type_name::with_defining_ids<SUI>(),
            start_ts_ms: 1736208000000,
            end_ts_ms: 1736294400000,
            size: 10000000000000,
            decay_speed: 1,
            initial_price: 2000000,
            final_price: 1000000,
            fee_bp: 1000,
            incentive_bp: 500,
            token_decimal: 9,
            size_decimal: 9,
            total_bid_size: 0,
            able_to_remove_bid: true,
            bids: big_vector::new(2, scenario.ctx()),
            bid_index: 0,
        };
        clock.set_for_testing(1736208000000 + 1);
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000000,
            vector[coin::mint_for_testing(22000000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        let (balance_x, balance_y, _, _, _, _, _, _) = delivery<SUI>(
            &mut fee_pool,
            &mut refund_vault,
            auction,
            true,
            &clock,
            scenario.ctx(),
        );
        balance_x.destroy_for_testing();
        balance_y.destroy_for_testing();
        transfer::public_transfer(fee_pool, scenario.sender());
        transfer::public_transfer(refund_vault, scenario.sender());
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidTimePeriod, location = Self)]
    fun test_new_invalid_time_period_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let auction = new<SUI>(
            0, 1736294400000, 1736208000000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidSize, location = Self)]
    fun test_new_invalid_size_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let auction = new<SUI>(
            0, 1736208000000, 1736294400000, 0, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidDecaySpeed, location = Self)]
    fun test_new_invalid_decay_speed_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 0,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_terminate_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<TEST>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidAuctionPrice, location = Self)]
    fun test_new_invalid_auction_price_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            1000000, 2000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EAuctionNotYetStarted, location = Self)]
    fun test_delivery_auction_not_yet_started_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736207000000);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (balance_x, balance_y, _, _, _, _, _, _) = delivery<SUI>(
            &mut fee_pool,
            &mut refund_vault,
            auction,
            true,
            &clock,
            scenario.ctx(),
        );
        balance_x.destroy_for_testing();
        balance_y.destroy_for_testing();
        transfer::public_transfer(fee_pool, scenario.sender());
        transfer::public_transfer(refund_vault, scenario.sender());
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EAuctionNotYetEnded, location = Self)]
    fun test_delivery_auction_not_yet_ended_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (balance_x, balance_y, _, _, _, _, _, _) = delivery<SUI>(
            &mut fee_pool,
            &mut refund_vault,
            auction,
            false,
            &clock,
            scenario.ctx(),
        );
        balance_x.destroy_for_testing();
        balance_y.destroy_for_testing();
        transfer::public_transfer(fee_pool, scenario.sender());
        transfer::public_transfer(refund_vault, scenario.sender());
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_delivery_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (balance_x, balance_y, _, _, _, _, _, _) = delivery<TEST>(
            &mut fee_pool,
            &mut refund_vault,
            auction,
            true,
            &clock,
            scenario.ctx(),
        );
        balance_x.destroy_for_testing();
        balance_y.destroy_for_testing();
        transfer::public_transfer(fee_pool, scenario.sender());
        transfer::public_transfer(refund_vault, scenario.sender());
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EAuctionNotYetStarted, location = Self)]
    fun test_public_new_bid_v2_auction_not_yet_started_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736207000000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            0,
            vector[],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EAuctionClosed, location = Self)]
    fun test_public_new_bid_v2_auction_closed_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736294500000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            0,
            vector[],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EZeroSize, location = Self)]
    fun test_public_new_bid_v2_zero_size_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            0,
            vector[],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EMaxSizeReached, location = Self)]
    fun test_public_new_bid_v2_max_size_reached_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            100000000000000,
            vector[],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_public_new_bid_v2_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<TEST>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            1000000000000,
            vector[],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidBidValue, location = Self)]
    fun test_public_new_bid_v2_invalid_bid_value_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            100,
            vector[],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = ERemoveBidDisabled, location = Self)]
    fun test_remove_bid_remove_bid_disabled_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        remove_bid<TEST>(
            &mut auction,
            0,
            &clock,
            scenario.ctx(),
        ).destroy_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EAuctionNotYetStarted, location = Self)]
    fun test_remove_bid_auction_not_yet_started_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736207000000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, true, scenario.ctx(),
        );
        remove_bid<TEST>(
            &mut auction,
            0,
            &clock,
            scenario.ctx(),
        ).destroy_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EAuctionClosed, location = Self)]
    fun test_remove_bid_auction_closed_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736294500000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, true, scenario.ctx(),
        );
        remove_bid<TEST>(
            &mut auction,
            0,
            &clock,
            scenario.ctx(),
        ).destroy_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidToken, location = Self)]
    fun test_remove_bid_invalid_token_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, true, scenario.ctx(),
        );
        remove_bid<TEST>(
            &mut auction,
            0,
            &clock,
            scenario.ctx(),
        ).destroy_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EBidNotExists, location = Self)]
    fun test_remove_bid_bid_not_exists_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing(1736208000000);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, true, scenario.ctx(),
        );
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(22000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        let (_, _, _, _, _, _, _, coin) = public_new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            scenario.sender(),
            10000000000,
            vector[coin::mint_for_testing(22000000, scenario.ctx())],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        remove_bid<SUI>(
            &mut auction,
            0,
            &clock,
            scenario.ctx(),
        ).destroy_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    fun test_update_auction_config() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        update_auction_config(
            &mut auction, 1736208000000, 1736294400000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, &clock, scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EAuctionAlreadyStarted, location = Self)]
    fun test_update_auction_config_auction_already_started_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let mut clock = clock::create_for_testing(scenario.ctx());
        clock.set_for_testing((1736208000000+1736294400000)/2);
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        update_auction_config(
            &mut auction, 1736208000000, 1736294400000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, &clock, scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidTimePeriod, location = Self)]
    fun test_update_auction_config_invalid_time_period_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        update_auction_config(
            &mut auction, 1736294400000, 1736208000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, &clock, scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidDecaySpeed, location = Self)]
    fun test_update_auction_config_invalid_decay_speed_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        update_auction_config(
            &mut auction, 1736208000000, 1736294400000, 0,
            2000000, 1000000, 1000, 500, 9, 9, false, &clock, scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EInvalidAuctionPrice, location = Self)]
    fun test_update_auction_config_invalid_auction_price_error() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        update_auction_config(
            &mut auction, 1736208000000, 1736294400000, 1,
            1000000, 2000000, 1000, 500, 9, 9, false, &clock, scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EDeprecated, location = Self)]
    #[allow(deprecated_usage)]
    fun test_public_new_bid_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (_, _, _, _, _, _, _, coin) = public_new_bid<SUI>(
            @0xABCD,
            &mut auction,
            0,
            vector[],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        coin.burn_for_testing();
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EDeprecated, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_bid_v2_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        new_bid_v2<SUI>(
            &mut refund_vault,
            &mut auction,
            0,
            vector[],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EDeprecated, location = Self)]
    #[allow(deprecated_usage)]
    fun test_new_bid_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let mut auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        new_bid<SUI>(
            &mut auction,
            0,
            vector[],
            balance::zero(),
            0,
            &clock,
            scenario.ctx(),
        );
        auction.terminate(&mut refund_vault, scenario.ctx()).destroy_for_testing<SUI>();
        refund_vault.drop_refund_vault<SUI>();
        clock.destroy_for_testing();
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = EDeprecated, location = Self)]
    #[allow(deprecated_usage)]
    fun test_old_delivery_abort() {
        let mut scenario = test_scenario::begin(@0xABCD);
        let clock = clock::create_for_testing(scenario.ctx());
        let mut fee_pool = typus_framework::balance_pool::new(vector[@0xABCD], scenario.ctx());
        let mut refund_vault = vault::new_refund_vault<SUI>(scenario.ctx());
        let auction = new<SUI>(
            0, 1736208000000, 1736294400000, 10000000000000, 1,
            2000000, 1000000, 1000, 500, 9, 9, false, scenario.ctx(),
        );
        let (balance_x, balance_y, _, _, _, _, _, _) = old_delivery<SUI>(
            &mut fee_pool,
            &mut refund_vault,
            auction,
            true,
            &clock,
            scenario.ctx(),
        );
        balance_x.destroy_for_testing();
        balance_y.destroy_for_testing();
        refund_vault.drop_refund_vault<SUI>();
        fee_pool.drop_balance_pool(scenario.ctx());
        clock.destroy_for_testing();
        scenario.end();
    }
}