#[test_only]
module typus_perp::test_position {
    use std::type_name;

    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::sui::SUI;
    use sui::test_scenario::{Scenario, begin, end, ctx, sender, next_tx, take_shared, return_shared, take_from_address};

    use typus_perp::admin::{Self, Version};
    use typus_perp::position::{Self, TradingOrder, Position};
    use typus_perp::symbol;
    use typus_perp::competition;

    use typus::ecosystem::{Self, Version as TypusEcosystemVersion};
    use typus::leaderboard::{Self, TypusLeaderboardRegistry};
    use typus::tails_staking::{Self, TailsStakingRegistry};
    use typus_perp::competition::CompetitionConfig;
    use typus_nft::typus_nft::{Self, Tails, ManagerCap as TailsManagerCap};
    use sui::transfer_policy;

    const K_ORDERS: vector<u8> = b"orders";
    const K_POSITIONS: vector<u8> = b"positions";

    const ADMIN: address = @0xFFFF;
    // const USER_1: address = @0xBABE1;
    // const USER_2: address = @0xBABE2;
    const SIZE_DECIMAL: u64 = 9;
    const COLLATERAL_TOKEN_DECIMAL: u64 = 9;
    const ORACLE_PRICE_DECIMAL: u64 = 8;
    const TRADING_FEE_MBP: u64 = 10000;
    const MAINTENANCE_MARGIN_RATE_BP: u64 = 150;
    const CURRENT_TS_MS: u64 = 1_715_212_800_000;

    const CUMULATIVE_FUNDING_RATE_INDEX_SIGN: bool = true;
    const CUMULATIVE_FUNDING_RATE_INDEX: u64 = 0;

    public struct TSUI has drop {}
    public struct USD has drop {}

    // use for storing orders and positions when testing
    public struct Orders has key {
        id: UID
    }
    public struct Positions has key {
        id: UID
    }

    fun new_orders(scenario: &mut Scenario) {
        let mut orders = Orders {id: object::new(ctx(scenario))};
        dynamic_field::add(&mut orders.id, K_ORDERS, vector::empty<TradingOrder>());
        transfer::share_object(orders);
        next_tx(scenario, ADMIN);
    }

    fun new_positions(scenario: &mut Scenario) {
        let mut positions = Positions {id: object::new(ctx(scenario))};
        dynamic_field::add(&mut positions.id, K_POSITIONS, vector::empty<Position>());
        transfer::share_object(positions);
        next_tx(scenario, ADMIN);
    }

    fun new_version(scenario: &mut Scenario) {
        admin::test_init(ctx(scenario));
        ecosystem::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_leaderboard_registry(scenario: &mut Scenario) {
        leaderboard::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_competition_config(scenario: &mut Scenario) {
        let version = version(scenario);
        let program_name = std::ascii::string(b"");
        competition::new_competition_config(
            &version,
            vector[0, 0, 0, 0, 0, 0, 0, 0],
            program_name,
            ctx(scenario)
        );
        return_shared(version);
        next_tx(scenario, ADMIN);
    }

    fun new_nft_pool(scenario: &mut Scenario) {
        typus_nft::test_init(ctx(scenario));
        next_tx(scenario, ADMIN);
        // let typus_nft_manager_cap = typus_nft_manager_cap(scenario);
        // typus_nft::new_pool(&typus_nft_manager_cap, 18_446_744_073_709_551_615, ctx(scenario));
        // next_tx(scenario, ADMIN);
        // let mut tails_pool = tails_pool(scenario);
        // typus_nft::deposit_nft(
        //     &typus_nft_manager_cap,
        //     &mut tails_pool,
        //     std::string::utf8(b""),
        //     0,
        //     vector[],
        //     vector[],
        //     vector[],
        //     ctx(scenario),
        // );
        // typus_nft::update_sale(&typus_nft_manager_cap, &mut tails_pool, true);

        // next_tx(scenario, ADMIN);
        // typus_nft::issue_whitelist(&typus_nft_manager_cap, &tails_pool, vector[sender(scenario)], ctx(scenario));

        // next_tx(scenario, ADMIN);
        // let tails_whitelist = tails_whitelist(scenario);
        // let (policy, policy_cap) = transfer_policy::new_for_testing<Tails>(ctx(scenario));
        // let clock = new_clock(scenario);
        // typus_nft::free_mint(&mut tails_pool, &policy, tails_whitelist, &clock, ctx(scenario));

        // return_shared(tails_pool);
        // return_to_sender(scenario, typus_nft_manager_cap);
        // transfer::public_transfer(policy, sender(scenario));
        // transfer::public_transfer(policy_cap, sender(scenario));
        // clock::destroy_for_testing(clock);
        // next_tx(scenario, ADMIN);
    }

    fun new_tails_staking_registry(scenario: &mut Scenario) {
        let ecosystem_version = ecosystem_version(scenario);
        let typus_nft_manager_cap = typus_nft_manager_cap(scenario);
        let (policy, policy_cap) = transfer_policy::new_for_testing<Tails>(ctx(scenario));
        tails_staking::init_tails_staking_registry(
            &ecosystem_version,
            typus_nft_manager_cap,
            policy,
            ctx(scenario),
        );
        return_shared(ecosystem_version);
        transfer::public_transfer(policy_cap, sender(scenario));
        next_tx(scenario, ADMIN);
    }

    fun new_clock(scenario: &mut Scenario): Clock {
        let mut clock = clock::create_for_testing(ctx(scenario));
        clock::set_for_testing(&mut clock, CURRENT_TS_MS);
        clock
    }

    fun orders(scenario: &Scenario): Orders {
        take_shared<Orders>(scenario)
    }

    fun positions(scenario: &Scenario): Positions {
        take_shared<Positions>(scenario)
    }

    fun version(scenario: &Scenario): Version {
        take_shared<Version>(scenario)
    }

    fun ecosystem_version(scenario: &Scenario): TypusEcosystemVersion {
        take_shared<TypusEcosystemVersion>(scenario)
    }

    fun leaderboard_registry(scenario: &Scenario): TypusLeaderboardRegistry {
        take_shared<TypusLeaderboardRegistry>(scenario)
    }

    fun competition_config(scenario: &Scenario): CompetitionConfig {
        take_shared<CompetitionConfig>(scenario)
    }

    fun typus_nft_manager_cap(scenario: &Scenario): TailsManagerCap {
        take_from_address<TailsManagerCap>(scenario, ADMIN)
    }

    fun tails_staking_registry(scenario: &Scenario): TailsStakingRegistry {
        take_shared<TailsStakingRegistry>(scenario)
    }

    fun mint_test_coin<T>(scenario: &mut Scenario, amount: u64): Coin<T> {
        coin::mint_for_testing<T>(amount, ctx(scenario))
    }

    fun test_create_order_<C_TOKEN, BASE_TOKEN, QUOTE_TOKEN>(
        scenario: &mut Scenario,
        leverage_mbp: u64,
        reduce_only: bool,
        is_long: bool,
        is_stop_order: bool,
        size: u64,
        trigger_price: u64,
        collateral_amount: u64,
        mut linked_position_id: Option<u64>,
        order_id: u64,
        oracle_price: u64,
    ) {
        let mut orders = orders(scenario);
        let version = version(scenario);
        let clock = new_clock(scenario);
        let collateral = mint_test_coin<C_TOKEN>(scenario, collateral_amount);
        let balance = coin::into_balance(collateral);
        let symbol = symbol::create(type_name::with_defining_ids<BASE_TOKEN>(), type_name::with_defining_ids<QUOTE_TOKEN>());
        let order = position::create_order<C_TOKEN>(
            &version,
            // order parameters
            symbol,
            leverage_mbp,
            reduce_only,
            is_long,
            is_stop_order,
            size,
            SIZE_DECIMAL,
            trigger_price,
            balance,
            COLLATERAL_TOKEN_DECIMAL,
            // generated by entry function
            linked_position_id,
            order_id,
            oracle_price,
            &clock,
            ctx(scenario)
        );

        let active_orders = dynamic_field::borrow_mut<vector<u8>, vector<TradingOrder>>(&mut orders.id, K_ORDERS);
        active_orders.push_back(order);
        if (linked_position_id.is_some()) {
            let linked_position_id = linked_position_id.extract();
            let mut positions = positions(scenario);
            let active_positions = dynamic_field::borrow_mut<vector<u8>, vector<Position>>(&mut positions.id, K_POSITIONS);
            let length = active_positions.length();
            let mut i = 0;
            while (i < length) {
                if (position::get_position_id(&active_positions[i]) == linked_position_id) {
                    position::add_position_linked_order_info(&mut active_positions[i], order_id, trigger_price);
                    break
                };
                i = i + 1;
            };
            return_shared(positions);
        };
        return_shared(version);
        return_shared(orders);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
    }

    fun test_remove_order_<C_TOKEN>(scenario: &mut Scenario, collateral_amount: u64) {
        let mut orders = orders(scenario);
        let version = version(scenario);
        let active_orders = dynamic_field::borrow_mut<vector<u8>, vector<TradingOrder>>(&mut orders.id, K_ORDERS);
        let order = active_orders.pop_back();
        let user = position::get_order_user(&order);

        let balance = position::remove_order<C_TOKEN>(&version, order);
        assert!(balance.value() == collateral_amount, 0);
        transfer::public_transfer(coin::from_balance(balance, ctx(scenario)), user);

        return_shared(version);
        return_shared(orders);
        next_tx(scenario, ADMIN);
    }

    fun test_check_order_filled_<C_TOKEN, BASE_TOKEN, QUOTE_TOKEN>(
        scenario: &mut Scenario,
        order_side: bool,
        stop_order: bool,
        trigger_price: u64
    ) {
        let oracle_price = 60000_0000_0000;
        test_create_order_<C_TOKEN, BASE_TOKEN, QUOTE_TOKEN>(
            scenario,
            10000,
            false,
            order_side,
            stop_order,
            1_0000_00000,
            trigger_price,
            0_0100_00000,
            option::none(),
            0,
            oracle_price,
        );

        let orders = orders(scenario);
        let active_orders = dynamic_field::borrow<vector<u8>, vector<TradingOrder>>(&orders.id, K_ORDERS);

        let (result_0, result_1, result_2) = if (order_side) {
            if (!stop_order) { (true, true, false) } else { (false, true, true) }
        } else {
            if (!stop_order) { (false, true, true) } else { (true, true, false) }
        };
        let oracle_price = trigger_price - 1000_0000_00000;
        assert!(position::check_order_filled(&active_orders[active_orders.length() - 1], oracle_price) == result_0, 0);
        let oracle_price = trigger_price;
        assert!(position::check_order_filled(&active_orders[active_orders.length() - 1], oracle_price) == result_1, 1);
        let oracle_price = trigger_price + 1000_0000_00000;
        assert!(position::check_order_filled(&active_orders[active_orders.length() - 1], oracle_price) == result_2, 2);

        return_shared(orders);
        next_tx(scenario, ADMIN);
    }

    fun test_order_filled_<C_TOKEN>(
        scenario: &mut Scenario,
        collateral_oracle_price: u64,
        trading_pair_oracle_price: u64,
        cumulative_borrow_rate: u64,
        cumulative_funding_rate_index_sign: bool,
        cumulative_funding_rate_index: u64,
    ): (u64, u64, u64) {
        let mut positions = positions(scenario);
        let next_position_id = {
            let active_positions = dynamic_field::borrow<vector<u8>, vector<Position>>(&positions.id, K_POSITIONS);
            if (active_positions.length() > 0) {
                position::get_position_id(&active_positions[active_positions.length() - 1]) + 1
            } else {
                0
            }
        };
        let mut orders = orders(scenario);
        let active_orders = dynamic_field::borrow_mut<vector<u8>, vector<TradingOrder>>(&mut orders.id, K_ORDERS);
        let order = active_orders.pop_back();
        let linked_position = if (position::get_order_linked_position_id(&order).is_some()) {
            let linked_position_id = position::get_order_linked_position_id(&order).extract();
            let active_positions = dynamic_field::borrow_mut<vector<u8>, vector<Position>>(&mut positions.id, K_POSITIONS);
            let mut i = 0;
            let length = active_positions.length();
            let mut linked_position = option::none();
            while (i < length) {
                if (position::get_position_id(&active_positions[i]) == linked_position_id) {
                    let original_position = active_positions.remove(i);
                    linked_position.fill(original_position);
                    break
                };
                i = i + 1;
            };
            linked_position
        } else {
            option::none()
        };

        let version = version(scenario);
        let ecosystem_version = ecosystem_version(scenario);
        let mut leaderboard_registry = leaderboard_registry(scenario);
        let tails_staking_registry = tails_staking_registry(scenario);
        let competition_config = competition_config(scenario);
        let clock = new_clock(scenario);
        let (
            position,
            realized_loss_value,
            realized_profit_value,
            trading_fee_usd
        ) = position::order_filled<C_TOKEN>(
            &version,
            &ecosystem_version,
            &mut leaderboard_registry,
            &tails_staking_registry,
            &competition_config,
            order,
            linked_position,
            next_position_id,
            collateral_oracle_price,
            ORACLE_PRICE_DECIMAL,
            trading_pair_oracle_price,
            ORACLE_PRICE_DECIMAL,
            cumulative_borrow_rate,
            cumulative_funding_rate_index_sign,
            cumulative_funding_rate_index,
            TRADING_FEE_MBP,
            &clock,
            ctx(scenario)
        );

        // let (realized_loss, realized_fee)
        //     = (realized_loss_balance.value(), realized_fee_balance.value());

        let active_positions = dynamic_field::borrow_mut<vector<u8>, vector<Position>>(&mut positions.id, K_POSITIONS);
        active_positions.push_back(position);
        // transfer::public_transfer(coin::from_balance(realized_loss_balance, ctx(scenario)), ADMIN);
        // transfer::public_transfer(coin::from_balance(realized_fee_balance, ctx(scenario)), ADMIN);

        return_shared(version);
        return_shared(orders);
        return_shared(positions);
        return_shared(ecosystem_version);
        return_shared(leaderboard_registry);
        return_shared(tails_staking_registry);
        return_shared(competition_config);
        clock::destroy_for_testing(clock);
        next_tx(scenario, ADMIN);
        (realized_loss_value, trading_fee_usd, realized_profit_value)
    }

    fun test_check_position_liquidated_(
        scenario: &mut Scenario,
        collateral_oracle_price: u64,
        trading_pair_oracle_price: u64,
        cumulative_borrow_rate: u64,
        cumulative_funding_rate_index_sign: bool,
        cumulative_funding_rate_index: u64,
        position_id: u64,
    ): bool {
        let mut positions = positions(scenario);
        let active_positions = dynamic_field::borrow_mut<vector<u8>, vector<Position>>(&mut positions.id, K_POSITIONS);
        let mut i = 0;
        let length = active_positions.length();
        let mut position = option::none();
        while (i < length) {
            if (position::get_position_id(&active_positions[i]) == position_id) {
                let original_position = active_positions.remove(i);
                position.fill(original_position);
                break
            };
            i = i + 1;
        };
        let position_liquidated = position::check_position_liquidated(
            position.borrow(),
            collateral_oracle_price,
            ORACLE_PRICE_DECIMAL,
            trading_pair_oracle_price,
            ORACLE_PRICE_DECIMAL,
            TRADING_FEE_MBP,
            MAINTENANCE_MARGIN_RATE_BP,
            cumulative_borrow_rate,
            cumulative_funding_rate_index_sign,
            cumulative_funding_rate_index
        );
        let active_positions = dynamic_field::borrow_mut<vector<u8>, vector<Position>>(&mut positions.id, K_POSITIONS);
        let current_position = position.destroy_some();
        active_positions.push_back(current_position);
        return_shared(positions);
        next_tx(scenario, ADMIN);
        position_liquidated
    }

    fun new_test(): Scenario {
        let mut scenario = begin(ADMIN);
        new_version(&mut scenario);
        new_leaderboard_registry(&mut scenario);
        new_competition_config(&mut scenario);
        new_nft_pool(&mut scenario);
        new_tails_staking_registry(&mut scenario);
        new_orders(&mut scenario);
        new_positions(&mut scenario);
        next_tx(&mut scenario, ADMIN);
        scenario
    }

    #[test]
    public(package) fun test_create_order() {
        let mut scenario = new_test();
        new_orders(&mut scenario);
        test_create_order_<SUI, TSUI, USD>(
            &mut scenario,
            10000,
            false,
            true,
            false,
            1_0000_00000,
            60000_0000_0000,
            0_0100_00000,
            option::none(),
            0,
            60000_0000_0000,
        );
        end(scenario);
    }

    #[test]
    public(package) fun test_remove_order() {
        let mut scenario = new_test();
        new_orders(&mut scenario);
        let collateral_amount = 0_0100_00000;
        test_create_order_<SUI, TSUI, USD>(
            &mut scenario,
            10000,
            false,
            true,
            false,
            1_0000_00000,
            60000_0000_0000,
            0_0100_00000,
            option::none(),
            0,
            60000_0000_0000,
        );
        test_remove_order_<SUI>(&mut scenario, collateral_amount);
        end(scenario);
    }

    #[test]
    public(package) fun test_check_order_filled() {
        let mut scenario = new_test();
        new_orders(&mut scenario);

        // order side / stop order flag / order price
        test_check_order_filled_<SUI, TSUI, USD>(&mut scenario, true, false, 60000_0000_0000);
        test_check_order_filled_<SUI, TSUI, USD>(&mut scenario, true, true, 60000_0000_0000);
        test_check_order_filled_<SUI, TSUI, USD>(&mut scenario, false, false, 60000_0000_0000);
        test_check_order_filled_<SUI, TSUI, USD>(&mut scenario, false, true, 60000_0000_0000);

        end(scenario);
    }

    #[test]
    public(package) fun test_order_filled() {
        let mut scenario = new_test();

        test_create_order_<SUI, TSUI, USD>(
            &mut scenario,
            10000,
            false,
            true,
            false,
            1_0000_00000,
            60000_0000_0000,
            0_1000_00000,
            option::none(),
            0,
            60000_0000_0000,
        );

        let collateral_oracle_price = 60000_0000_0000;
        let trading_pair_oracle_price_0 = 60000_0000_0000;
        let cumulative_borrow_rate = 0;
        let (realized_loss_value, trading_fee_usd, realized_profit_value)
            = test_order_filled_<SUI>(&mut scenario, collateral_oracle_price, trading_pair_oracle_price_0, cumulative_borrow_rate, CUMULATIVE_FUNDING_RATE_INDEX_SIGN, CUMULATIVE_FUNDING_RATE_INDEX);
        assert!(realized_loss_value == 0, 0);
        assert!(trading_fee_usd == 60_0000_00000, 0);
        assert!(realized_profit_value == 0, 0);
        {
            let positions = positions(&scenario);
            let active_positions = dynamic_field::borrow<vector<u8>, vector<Position>>(&positions.id, K_POSITIONS);
            assert!(
                position::get_position_size(&active_positions[active_positions.length() - 1])
                    == 1_0000_00000,
                0
            );
            return_shared(positions);
        };
        next_tx(&mut scenario, ADMIN);
        test_create_order_<SUI, TSUI, USD>(
            &mut scenario,
            10000,
            false,
            true,
            false,
            1_0000_00000,
            60000_0000_0000,
            0,
            option::some(0),
            0,
            60000_0000_0000,
        );

        let collateral_oracle_price = 60000_0000_0000;
        let trading_pair_oracle_price = 58000_0000_0000;
        let cumulative_borrow_rate = 0;
        let (realized_loss_value, trading_fee_usd, realized_profit_value)
            = test_order_filled_<SUI>(&mut scenario, collateral_oracle_price, trading_pair_oracle_price, cumulative_borrow_rate, CUMULATIVE_FUNDING_RATE_INDEX_SIGN, CUMULATIVE_FUNDING_RATE_INDEX);
        assert!(realized_loss_value == 0, 0);
        assert!(trading_fee_usd == 58_0000_00000, 0);
        assert!(realized_profit_value == 0, 0);
        {
            let positions = positions(&scenario);
            let active_positions = dynamic_field::borrow<vector<u8>, vector<Position>>(&positions.id, K_POSITIONS);
            assert!(
                position::get_position_size(&active_positions[active_positions.length() - 1])
                    == 2_0000_00000,
                0
            );
            return_shared(positions);
        };

        next_tx(&mut scenario, ADMIN);
        test_create_order_<SUI, TSUI, USD>(
            &mut scenario,
            10000,
            true, // reduce only
            false, // sell
            false,
            1_0000_00000,
            57000_0000_0000,
            0_0000_00000,
            option::some(0),
            0,
            57000_0000_0000,
        );

        let collateral_oracle_price = 60000_0000_0000;
        let trading_pair_oracle_price = 57000_0000_0000;
        let cumulative_borrow_rate = 0_0001_00000;
        let (realized_loss_value, trading_fee_usd, realized_profit_value)
            = test_order_filled_<SUI>(&mut scenario, collateral_oracle_price, trading_pair_oracle_price, cumulative_borrow_rate, CUMULATIVE_FUNDING_RATE_INDEX_SIGN, CUMULATIVE_FUNDING_RATE_INDEX);
        assert!(
            realized_loss_value
                == (1_0000_00000
                    * (59000_0000_0000 - (trading_pair_oracle_price as u128))
                        / (collateral_oracle_price as u128) as u64),
            0
        );
        assert!(trading_fee_usd == 57_0000_00000, 0);
        assert!(realized_profit_value == 0, 0);
        {
            let positions = positions(&scenario);
            let active_positions = dynamic_field::borrow<vector<u8>, vector<Position>>(&positions.id, K_POSITIONS);
            assert!(
                position::get_position_size(&active_positions[active_positions.length() - 1])
                    == 1_0000_00000,
                0
            );
            return_shared(positions);
        };
        next_tx(&mut scenario, ADMIN);
        test_create_order_<SUI, TSUI, USD>(
            &mut scenario,
            10000,
            false,
            false, // sell
            false,
            3_0000_00000, // capped to 1_0000_00000 => position size = 0
            60000_0000_0000,
            0_0100_00000,
            option::some(0),
            0,
            60000_0000_0000,
        );

        let collateral_oracle_price = 60000_0000_0000;
        let trading_pair_oracle_price = 60000_0000_0000;
        test_order_filled_<SUI>(&mut scenario, collateral_oracle_price, trading_pair_oracle_price, cumulative_borrow_rate, CUMULATIVE_FUNDING_RATE_INDEX_SIGN, CUMULATIVE_FUNDING_RATE_INDEX);

        {
            let positions = positions(&scenario);
            let active_positions = dynamic_field::borrow<vector<u8>, vector<Position>>(&positions.id, K_POSITIONS);
            assert!(
                position::get_position_size(&active_positions[active_positions.length() - 1])
                    == 0_0000_00000,
                0
            );
            return_shared(positions);
        };
        next_tx(&mut scenario, ADMIN);
        test_create_order_<SUI, TSUI, USD>(
            &mut scenario,
            10000,
            false,
            true, // buy
            true, // stop
            1_0000_00000,
            60000_0000_0000,
            0_0100_00000,
            option::some(0),
            0,
            60000_0000_0000,
        );

        let collateral_oracle_price = 60000_0000_0000;
        let trading_pair_oracle_price = 60000_0000_0000;
        test_order_filled_<SUI>(&mut scenario, collateral_oracle_price, trading_pair_oracle_price, cumulative_borrow_rate, CUMULATIVE_FUNDING_RATE_INDEX_SIGN, CUMULATIVE_FUNDING_RATE_INDEX);

        {
            let positions = positions(&scenario);
            let active_positions = dynamic_field::borrow<vector<u8>, vector<Position>>(&positions.id, K_POSITIONS);
            assert!(
                position::get_position_size(&active_positions[active_positions.length() - 1])
                    == 1_0000_00000,
                0
            );
            return_shared(positions);
        };
        next_tx(&mut scenario, ADMIN);
        test_create_order_<SUI, TSUI, USD>(
            &mut scenario,
            10000,
            false,
            true, // buy
            true, // stop
            5_0000_00000,
            60000_0000_0000,
            0_0100_00000,
            option::some(0),
            0,
            60000_0000_0000,
        );

        let collateral_oracle_price = 60000_0000_0000;
        let trading_pair_oracle_price = 60000_0000_0000;
        test_order_filled_<SUI>(&mut scenario, collateral_oracle_price, trading_pair_oracle_price, cumulative_borrow_rate, CUMULATIVE_FUNDING_RATE_INDEX_SIGN, CUMULATIVE_FUNDING_RATE_INDEX);

        {
            let positions = positions(&scenario);
            let active_positions = dynamic_field::borrow<vector<u8>, vector<Position>>(&positions.id, K_POSITIONS);
            assert!(
                position::get_position_size(&active_positions[active_positions.length() - 1])
                    == 6_0000_00000,
                0
            );
            return_shared(positions);
        };

        end(scenario);
    }

    #[test]
    public(package) fun test_check_position_liquidated() {
        let mut scenario = new_test();
        new_orders(&mut scenario);
        new_positions(&mut scenario);

        // create order
        test_create_order_<SUI, TSUI, USD>(
            &mut scenario,
            10000,
            false,
            true,
            false,
            1_0000_00000,
            60000_0000_0000,
            0_0100_00000,
            option::none(),
            0,
            60000_0000_0000,
        );

        // order filled
        let collateral_oracle_price = 60000_0000_0000;
        let trading_pair_oracle_price = 60000_0000_0000;
        test_order_filled_<SUI>(&mut scenario, collateral_oracle_price, trading_pair_oracle_price, 0, CUMULATIVE_FUNDING_RATE_INDEX_SIGN, CUMULATIVE_FUNDING_RATE_INDEX);

        // position liquidated
        let collateral_oracle_price = 60000_0000_0000;
        let trading_pair_oracle_price = 60000_0000_0000;
        let cumulative_borrow_rate = 0_0001_00000;
        let cumulative_funding_rate_index_sign = true;
        let cumulative_funding_rate_index = 0;
        let position_liquidated = test_check_position_liquidated_(
            &mut scenario,
            collateral_oracle_price,
            trading_pair_oracle_price,
            cumulative_borrow_rate,
            cumulative_funding_rate_index_sign,
            cumulative_funding_rate_index,
            0,
        );
        assert!(position_liquidated, 0);

        // create order
        test_create_order_<SUI, TSUI, USD>(
            &mut scenario,
            10000,
            false,
            true,
            false,
            1_0000_00000,
            60000_0000_0000,
            0_1000_00000,
            option::none(),
            0,
            60000_0000_0000,
        );

        // order filled
        let collateral_oracle_price = 60000_0000_0000;
        let trading_pair_oracle_price = 60000_0000_0000;
        test_order_filled_<SUI>(&mut scenario, collateral_oracle_price, trading_pair_oracle_price, 0, CUMULATIVE_FUNDING_RATE_INDEX_SIGN, CUMULATIVE_FUNDING_RATE_INDEX);

        // position liquidated
        let collateral_oracle_price = 60000_0000_0000;
        let trading_pair_oracle_price = 60000_0000_0000;
        let cumulative_borrow_rate = 0_0001_00000;
        let cumulative_funding_rate_index_sign = true;
        let cumulative_funding_rate_index = 0;
        let position_liquidated = test_check_position_liquidated_(
            &mut scenario,
            collateral_oracle_price,
            trading_pair_oracle_price,
            cumulative_borrow_rate,
            cumulative_funding_rate_index_sign,
            cumulative_funding_rate_index,
            1,
        );
        assert!(position_liquidated == false, 0);

        end(scenario);
    }
}