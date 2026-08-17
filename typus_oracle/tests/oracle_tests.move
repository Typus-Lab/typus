// #[test_only]
// module typus_oracle::oracle_tests {
//     use sui::test_scenario::{Self, Scenario};
//     use sui::clock::{Self, Clock};

//     use typus_oracle::oracle::{
//         Self, ManagerCap, Oracle, UpdateAuthority,
//     };
//     use std::type_name;
//     use pyth::pyth_tests;
//     use pyth::pyth_tests::get_mock_price_infos;
//     use typus_oracle::oracle::update_pyth_oracle;
//     use typus_oracle::oracle::update_with_pyth;
//     use typus_oracle::oracle::update_pyth_oracle_usd_reciprocal;

//     const ADMIN: address = @0x123;
//     const AUTHORITY: address = @0x456;
//     const RANDOM: address = @0x8;
//     const RECIPIENT: address = @0x789;

//     public struct BTC has drop {}
//     public struct USDC has drop {}
//     public struct USD has drop {}
//     public struct JPY has drop {}
//     public struct ETH has drop {}

//     fun setup_oracle(scenario: &mut Scenario) {
//         test_scenario::next_tx(scenario, ADMIN);
//         oracle::test_init(test_scenario::ctx(scenario));

//         test_scenario::next_tx(scenario, ADMIN);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(scenario);
//         oracle::new_oracle<BTC, USDC>(
//             &manager_cap,
//             std::ascii::string(b"BTC"),
//             std::ascii::string(b"USDC"),
//             8,
//             test_scenario::ctx(scenario)
//         );
//         test_scenario::return_to_sender(scenario, manager_cap);
//     }

//     #[test]
//     fun test_init_and_new_oracle() {
//         let mut scenario = test_scenario::begin(ADMIN);
//         setup_oracle(&mut scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         {
//             let oracle = test_scenario::take_shared<Oracle>(&scenario);

//             let (base_token, quote_token, base_token_type, quote_token_type) = oracle.get_token();
//             assert!(base_token == std::ascii::string(b"BTC"), 0);
//             assert!(quote_token == std::ascii::string(b"USDC"), 1);
//             assert!(base_token_type == type_name::with_defining_ids<BTC>(), 2);
//             assert!(quote_token_type == type_name::with_defining_ids<USDC>(), 3);


//             let (_price, decimal, _ts_ms, _epoch) = oracle.get_oracle();
//             assert!(decimal == 8, 2);

//             test_scenario::return_shared(oracle);
//         };
//         test_scenario::end(scenario);
//     }

//     #[test]
//     fun test_update_authority() {
//         let mut scenario = test_scenario::begin(ADMIN);
//         let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
//         setup_oracle(&mut scenario);

//         // Create and add authority
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//         oracle::new_update_authority(&manager_cap, test_scenario::ctx(&mut scenario));
//         test_scenario::return_to_sender(&scenario, manager_cap);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//         let mut auth = test_scenario::take_shared<UpdateAuthority>(&scenario);
//         oracle::add_update_authority(&manager_cap, &mut auth, vector[AUTHORITY]);
//         test_scenario::return_shared(auth);
//         test_scenario::return_to_sender(&scenario, manager_cap);

//         // Update price with new authority
//         test_scenario::next_tx(&mut scenario, AUTHORITY);
//         let auth = test_scenario::take_shared<UpdateAuthority>(&scenario);
//         let mut oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//         let price = 112000_00000000;
//         let ts_ms = 1758521586;

//         clock.set_for_testing(ts_ms);
//         oracle::update_v2(&mut oracle_obj, &auth, price, price, &clock, test_scenario::ctx(&mut scenario));

//         let (_price, _decimal, _ts_ms, _epoch) = oracle_obj.get_oracle();
//         assert!(_price == price, 1);
//         assert!(_ts_ms == ts_ms, 2);

//         test_scenario::return_shared(oracle_obj);
//         test_scenario::return_shared(auth);

//         // Remove authority
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//         let mut auth = test_scenario::take_shared<UpdateAuthority>(&scenario);
//         oracle::remove_update_authority(&manager_cap, &mut auth, vector[AUTHORITY]);

//         test_scenario::return_shared(auth);
//         test_scenario::return_to_sender(&scenario, manager_cap);

//         clock.destroy_for_testing();
//         test_scenario::end(scenario);
//     }

//     #[test]
//     #[expected_failure(abort_code = 1, location = typus_oracle::oracle)]
//     fun test_update_oracle() {
//         let mut scenario = test_scenario::begin(ADMIN);
//         let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
//         setup_oracle(&mut scenario);

//         // Update token
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         let mut oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//         oracle_obj.update_token(&manager_cap, std::ascii::string(b"ETH"),std::ascii::string(b"USDT"));

//         // Update price
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         oracle::update(&mut oracle_obj, &manager_cap, 30000_00000000, 30010_00000000, &clock, test_scenario::ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         clock::increment_for_testing(&mut clock, 10_000); // after 10s
//         oracle_obj.get_price_with_interval_ms(&clock, 20_000); // allow 20s
//         oracle_obj.get_price_with_interval_ms(&clock, 5_000); // allow 5s -> error

//         test_scenario::return_to_sender(&scenario, manager_cap);
//         test_scenario::return_shared(oracle_obj);
//         clock.destroy_for_testing();
//         test_scenario::end(scenario);
//     }


//     #[test]
//     #[expected_failure(abort_code = 1, location = typus_oracle::oracle)]
//     fun test_update_time_interval() {
//         let mut scenario = test_scenario::begin(ADMIN);
//         let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
//         setup_oracle(&mut scenario);

//         // Update time interval
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         let mut oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//         oracle_obj.update_time_interval(&manager_cap, 1_000); // allow 1s

//         // Update price
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         oracle::update(&mut oracle_obj, &manager_cap, 30000_00000000, 30010_00000000, &clock, test_scenario::ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         clock::increment_for_testing(&mut clock, 10_000); // after 10s
//         oracle_obj.get_price_with_interval_ms(&clock, 30_000); // allow min(1,30)s -> error

//         test_scenario::return_to_sender(&scenario, manager_cap);
//         test_scenario::return_shared(oracle_obj);
//         clock.destroy_for_testing();
//         test_scenario::end(scenario);
//     }


//     #[test]
//     #[expected_failure(abort_code = 1, location = typus_oracle::oracle)]
//     fun test_get_price_expiration() {
//         let mut scenario = test_scenario::begin(ADMIN);
//         let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
//         setup_oracle(&mut scenario);

//         // Update price
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//         let mut oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//         oracle::update(&mut oracle_obj, &manager_cap, 30000_00000000, 30010_00000000, &clock, test_scenario::ctx(&mut scenario));
//         test_scenario::return_shared(oracle_obj);
//         test_scenario::return_to_sender(&scenario, manager_cap);

//         // Advance clock to just before expiration
//         test_scenario::next_tx(&mut scenario, RANDOM);
//         let oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//         // Default time_interval is 300 * 1000 ms
//         clock::increment_for_testing(&mut clock, 299_999);
//         let (price, _) = oracle::get_price(&oracle_obj, &clock);
//         let (twap_price, _) = oracle::get_twap_price(&oracle_obj, &clock);
//         assert!(price == 30000_00000000, 0);
//         assert!(twap_price == 30010_00000000, 0);
//         test_scenario::return_shared(oracle_obj);

//         // Advance clock to expiration
//         test_scenario::next_tx(&mut scenario, RANDOM);
//         let oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//         clock::increment_for_testing(&mut clock, 2); // Total increment > 300_000
//         // This should now fail with E_ORACLE_EXPIRED (1)
//         oracle::get_price(&oracle_obj, &clock);
//         test_scenario::return_shared(oracle_obj); // This line won't be reached

//         clock.destroy_for_testing();
//         test_scenario::end(scenario);
//     }


//     #[test]
//     #[expected_failure(abort_code = 1, location = typus_oracle::oracle)]
//     fun test_get_twap_price_expiration() {
//         let mut scenario = test_scenario::begin(ADMIN);
//         let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
//         setup_oracle(&mut scenario);

//         // Update price
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//         let mut oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//         oracle::update(&mut oracle_obj, &manager_cap, 30000_00000000, 30010_00000000, &clock, test_scenario::ctx(&mut scenario));
//         test_scenario::return_shared(oracle_obj);
//         test_scenario::return_to_sender(&scenario, manager_cap);

//         // Advance clock to expiration
//         test_scenario::next_tx(&mut scenario, RANDOM);
//         let oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//         clock::increment_for_testing(&mut clock, 299_999 + 2); // Total increment > 300_000
//         // This should now fail with E_ORACLE_EXPIRED (1)
//         oracle::get_twap_price(&oracle_obj, &clock);
//         test_scenario::return_shared(oracle_obj); // This line won't be reached

//         clock.destroy_for_testing();
//         test_scenario::end(scenario);
//     }

//     #[test]
//     #[expected_failure(abort_code = 2, location = typus_oracle::oracle)]
//     fun test_update_invalid_price() {
//         let mut scenario = test_scenario::begin(ADMIN);
//         let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
//         setup_oracle(&mut scenario);

//         // Create and add authority
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         let mut oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//         oracle::update(&mut oracle_obj, &manager_cap, 0, 30010_00000000, &clock, test_scenario::ctx(&mut scenario));

//         test_scenario::return_shared(oracle_obj);
//         test_scenario::return_to_sender(&scenario, manager_cap);
//         clock.destroy_for_testing();
//         test_scenario::end(scenario);
//     }


//     #[test]
//     #[expected_failure(abort_code = 2, location = typus_oracle::oracle)]
//     fun test_update_invalid_twap_price() {
//         let mut scenario = test_scenario::begin(ADMIN);
//         let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
//         setup_oracle(&mut scenario);

//         // Create and add authority
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         let mut oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//         oracle::update(&mut oracle_obj, &manager_cap, 30010_00000000, 0, &clock, test_scenario::ctx(&mut scenario));

//         test_scenario::return_shared(oracle_obj);
//         test_scenario::return_to_sender(&scenario, manager_cap);
//         clock.destroy_for_testing();
//         test_scenario::end(scenario);
//     }

//     #[test]
//     fun test_copy_burn_manager_cap() {
//         let mut scenario = test_scenario::begin(ADMIN);
//         test_scenario::next_tx(&mut scenario, ADMIN);
//         oracle::test_init(test_scenario::ctx(&mut scenario));
//         setup_oracle(&mut scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//         oracle::copy_manager_cap(&manager_cap, RECIPIENT, test_scenario::ctx(&mut scenario));
//         test_scenario::return_to_sender(&scenario, manager_cap);

//         test_scenario::next_tx(&mut scenario, RECIPIENT);
//         {
//             let new_manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);

//             let mut oracle_obj = test_scenario::take_shared<Oracle>(&scenario);
//             oracle::update_version(&mut oracle_obj, &new_manager_cap);

//             // Assert that the new_manager_cap exists and is owned by RECIPIENT
//             oracle::burn_manager_cap(new_manager_cap);

//             test_scenario::return_shared(oracle_obj);
//         };
//         test_scenario::end(scenario);
//     }

//     use sui::test_scenario::{ctx, take_shared, return_shared};
//     use sui::coin;

//     use pyth::price_info::{PriceInfoObject};//, PriceInfo, PriceInfoObject};
//     use pyth::pyth::{Self};
//     use wormhole::state::{State as WormState};
//     use wormhole::vaa::{Self, VAA};

//     const DEPLOYER: address = @0x12345;
//     const DEFAULT_BASE_UPDATE_FEE: u64 = 50;
//     const DEFAULT_COIN_TO_MINT: u64 = 5000;

//     fun get_verified_test_vaas(worm_state: &WormState, clock: &Clock): vector<VAA> {
//         let test_vaas_: vector<vector<u8>> = vector[x"0100000000010036eb563b80a24f4253bee6150eb8924e4bdf6e4fa1dfc759a6664d2e865b4b134651a7b021b7f1ce3bd078070b688b6f2e37ce2de0d9b48e6a78684561e49d5201527e4f9b00000001001171f8dcb863d176e2c420ad6610cf687359612b6fb392e0642b0ca6b1f186aa3b0000000000000001005032574800030000000102000400951436e0be37536be96f0896366089506a59763d036728332d3e3038047851aea7c6c75c89f14810ec1c54c03ab8f1864a4c4032791f05747f560faec380a695d1000000000000049a0000000000000008fffffffb00000000000005dc0000000000000003000000000100000001000000006329c0eb000000006329c0e9000000006329c0e400000000000006150000000000000007215258d81468614f6b7e194c5d145609394f67b041e93e6695dcc616faadd0603b9551a68d01d954d6387aff4df1529027ffb2fee413082e509feb29cc4904fe000000000000041a0000000000000003fffffffb00000000000005cb0000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e4000000000000048600000000000000078ac9cf3ab299af710d735163726fdae0db8465280502eb9f801f74b3c1bd190333832fad6e36eb05a8972fe5f219b27b5b2bb2230a79ce79beb4c5c5e7ecc76d00000000000003f20000000000000002fffffffb00000000000005e70000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e40000000000000685000000000000000861db714e9ff987b6fedf00d01f9fea6db7c30632d6fc83b7bc9459d7192bc44a21a28b4c6619968bd8c20e95b0aaed7df2187fd310275347e0376a2cd7427db800000000000006cb0000000000000001fffffffb00000000000005e40000000000000003010000000100000001000000006329c0eb000000006329c0e9000000006329c0e400000000000007970000000000000001"];
//         let mut verified_vaas_reversed = vector::empty<VAA>();
//         let mut test_vaas = test_vaas_;
//         let mut i = 0;
//         while (i < vector::length(&test_vaas_)) {
//             let cur_test_vaa = vector::pop_back(&mut test_vaas);
//             let verified_vaa = vaa::parse_and_verify(worm_state, cur_test_vaa, clock);
//             vector::push_back(&mut verified_vaas_reversed, verified_vaa);
//             i=i+1;
//         };
//         let mut verified_vaas = vector::empty<VAA>();
//         while (vector::length<VAA>(&verified_vaas_reversed)!=0){
//             let cur = vector::pop_back(&mut verified_vaas_reversed);
//             vector::push_back(&mut verified_vaas, cur);
//         };
//         vector::destroy_empty(verified_vaas_reversed);
//         verified_vaas
//     }

//     #[test]
//     fun test_oracle_with_pyth() {
//         let (mut scenario, test_coins, mut clock) =  pyth_tests::setup_test(500, 23, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", pyth_tests::data_sources_for_test_vaa(), vector[x"beFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"], DEFAULT_BASE_UPDATE_FEE, DEFAULT_COIN_TO_MINT);
//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         clock.set_for_testing(1663680745000);
//         let (mut pyth_state, worm_state) = pyth_tests::take_wormhole_and_pyth_states(&scenario);

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let verified_vaas = get_verified_test_vaas(&worm_state, &clock);
//         pyth::create_price_feeds(&mut pyth_state,verified_vaas,&clock,ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let price_info_object_1 = take_shared<PriceInfoObject>(&scenario);
//         let price_info_object_2 = take_shared<PriceInfoObject>(&scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         setup_oracle(&mut scenario);
//         {
//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//             let mut oracle_1 = test_scenario::take_shared<Oracle>(&scenario);

//             oracle::update_pyth_oracle(&mut oracle_1, &manager_cap, &price_info_object_1, &price_info_object_2);
//             oracle::update_with_pyth(&mut oracle_1, &pyth_state, &price_info_object_1, &price_info_object_2, &clock, test_scenario::ctx(&mut scenario));

//             oracle::new_oracle<BTC, USD>(
//                 &manager_cap,
//                 std::ascii::string(b"BTC"),
//                 std::ascii::string(b"USD"),
//                 4,
//                 test_scenario::ctx(&mut scenario)
//             );
//             oracle::new_oracle<USD, JPY>(
//                 &manager_cap,
//                 std::ascii::string(b"USD"),
//                 std::ascii::string(b"JPY"),
//                 5,
//                 test_scenario::ctx(&mut scenario)
//             );
//             oracle::new_oracle<JPY, USD>(
//                 &manager_cap,
//                 std::ascii::string(b"JPY"),
//                 std::ascii::string(b"USD"),
//                 5,
//                 test_scenario::ctx(&mut scenario)
//             );
//             oracle::new_oracle<ETH, USD>(
//                 &manager_cap,
//                 std::ascii::string(b"ETH"),
//                 std::ascii::string(b"USDC"),
//                 4,
//                 test_scenario::ctx(&mut scenario)
//             );
//             test_scenario::next_tx(&mut scenario, ADMIN);

//             let mut oracle_5 = test_scenario::take_shared<Oracle>(&scenario);
//             let mut oracle_4 = test_scenario::take_shared<Oracle>(&scenario);
//             let mut oracle_3 = test_scenario::take_shared<Oracle>(&scenario);
//             let mut oracle_2 = test_scenario::take_shared<Oracle>(&scenario);
//             oracle::update_pyth_oracle_usd(&mut oracle_2, &manager_cap, &price_info_object_1);
//             oracle::update_with_pyth_usd(&mut oracle_2, &pyth_state, &price_info_object_1, &clock, test_scenario::ctx(&mut scenario));

//             oracle::update_pyth_oracle_usd(&mut oracle_3, &manager_cap, &price_info_object_1);
//             oracle::update_with_pyth_usd(&mut oracle_3, &pyth_state, &price_info_object_1, &clock, test_scenario::ctx(&mut scenario));

//             oracle::update_pyth_oracle_usd_reciprocal(&mut oracle_4, &manager_cap, &price_info_object_1);
//             oracle::update_with_pyth_usd(&mut oracle_4, &pyth_state, &price_info_object_1, &clock, test_scenario::ctx(&mut scenario));

//             oracle::update_pyth_oracle(&mut oracle_5, &manager_cap, &price_info_object_1, &price_info_object_2);
//             oracle::update_with_pyth(&mut oracle_5, &pyth_state, &price_info_object_1, &price_info_object_2, &clock, test_scenario::ctx(&mut scenario));

//             test_scenario::return_shared(oracle_1);
//             test_scenario::return_shared(oracle_2);
//             test_scenario::return_shared(oracle_3);
//             test_scenario::return_shared(oracle_4);
//             test_scenario::return_shared(oracle_5);

//             test_scenario::return_to_sender(&scenario, manager_cap);
//         };

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         return_shared(price_info_object_1);
//         return_shared(price_info_object_2);

//         coin::burn_for_testing(test_coins);
//         pyth_tests::cleanup_worm_state_pyth_state_and_clock(worm_state, pyth_state, clock);
//         test_scenario::end(scenario);
//     }

//     #[test]
//     #[expected_failure(abort_code = 5, location = typus_oracle::oracle)]
//     fun test_update_not_pyth() {
//         let (mut scenario, test_coins, mut clock) =  pyth_tests::setup_test(500, 23, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", pyth_tests::data_sources_for_test_vaa(), vector[x"beFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"], DEFAULT_BASE_UPDATE_FEE, DEFAULT_COIN_TO_MINT);
//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         clock.set_for_testing(1663680745000);
//         let (mut pyth_state, worm_state) = pyth_tests::take_wormhole_and_pyth_states(&scenario);

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let verified_vaas = get_verified_test_vaas(&worm_state, &clock);
//         pyth::create_price_feeds(&mut pyth_state,verified_vaas,&clock,ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let price_info_object_1 = take_shared<PriceInfoObject>(&scenario);
//         let price_info_object_2 = take_shared<PriceInfoObject>(&scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         setup_oracle(&mut scenario);
//         {
//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//             let mut oracle_1 = test_scenario::take_shared<Oracle>(&scenario);

//             oracle::update_with_pyth(&mut oracle_1, &pyth_state, &price_info_object_1, &price_info_object_2, &clock, test_scenario::ctx(&mut scenario));

//             test_scenario::return_shared(oracle_1);
//             test_scenario::return_to_sender(&scenario, manager_cap);
//         };

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         return_shared(price_info_object_1);
//         return_shared(price_info_object_2);

//         coin::burn_for_testing(test_coins);
//         pyth_tests::cleanup_worm_state_pyth_state_and_clock(worm_state, pyth_state, clock);
//         test_scenario::end(scenario);
//     }

//     #[test]
//     #[expected_failure(abort_code = 6, location = typus_oracle::oracle)]
//     fun test_update_invalid_pyth_base() {
//         let (mut scenario, test_coins, mut clock) =  pyth_tests::setup_test(500, 23, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", pyth_tests::data_sources_for_test_vaa(), vector[x"beFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"], DEFAULT_BASE_UPDATE_FEE, DEFAULT_COIN_TO_MINT);
//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         clock.set_for_testing(1663680745000);
//         let (mut pyth_state, worm_state) = pyth_tests::take_wormhole_and_pyth_states(&scenario);

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let verified_vaas = get_verified_test_vaas(&worm_state, &clock);
//         pyth::create_price_feeds(&mut pyth_state,verified_vaas,&clock,ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let price_info_object_1 = take_shared<PriceInfoObject>(&scenario);
//         let price_info_object_2 = take_shared<PriceInfoObject>(&scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         setup_oracle(&mut scenario);
//         {
//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//             let mut oracle_1 = test_scenario::take_shared<Oracle>(&scenario);

//             oracle::update_pyth_oracle(&mut oracle_1, &manager_cap, &price_info_object_1, &price_info_object_2);
//             oracle::update_with_pyth(&mut oracle_1, &pyth_state, &price_info_object_2, &price_info_object_2, &clock, test_scenario::ctx(&mut scenario));

//             test_scenario::return_shared(oracle_1);
//             test_scenario::return_to_sender(&scenario, manager_cap);
//         };

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         return_shared(price_info_object_1);
//         return_shared(price_info_object_2);

//         coin::burn_for_testing(test_coins);
//         pyth_tests::cleanup_worm_state_pyth_state_and_clock(worm_state, pyth_state, clock);
//         test_scenario::end(scenario);
//     }


//     #[test]
//     #[expected_failure(abort_code = 6, location = typus_oracle::oracle)]
//     fun test_update_invalid_pyth_quote() {
//         let (mut scenario, test_coins, mut clock) =  pyth_tests::setup_test(500, 23, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", pyth_tests::data_sources_for_test_vaa(), vector[x"beFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"], DEFAULT_BASE_UPDATE_FEE, DEFAULT_COIN_TO_MINT);
//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         clock.set_for_testing(1663680745000);
//         let (mut pyth_state, worm_state) = pyth_tests::take_wormhole_and_pyth_states(&scenario);

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let verified_vaas = get_verified_test_vaas(&worm_state, &clock);
//         pyth::create_price_feeds(&mut pyth_state,verified_vaas,&clock,ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let price_info_object_1 = take_shared<PriceInfoObject>(&scenario);
//         let price_info_object_2 = take_shared<PriceInfoObject>(&scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         setup_oracle(&mut scenario);
//         {
//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//             let mut oracle_1 = test_scenario::take_shared<Oracle>(&scenario);

//             oracle::update_pyth_oracle(&mut oracle_1, &manager_cap, &price_info_object_1, &price_info_object_2);
//             oracle::update_with_pyth(&mut oracle_1, &pyth_state, &price_info_object_1, &price_info_object_1, &clock, test_scenario::ctx(&mut scenario));

//             test_scenario::return_shared(oracle_1);
//             test_scenario::return_to_sender(&scenario, manager_cap);
//         };

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         return_shared(price_info_object_1);
//         return_shared(price_info_object_2);

//         coin::burn_for_testing(test_coins);
//         pyth_tests::cleanup_worm_state_pyth_state_and_clock(worm_state, pyth_state, clock);
//         test_scenario::end(scenario);
//     }

//     #[test]
//     #[expected_failure(abort_code = 5, location = typus_oracle::oracle)]
//     fun test_not_usd_quote() {
//         let (mut scenario, test_coins, mut clock) =  pyth_tests::setup_test(500, 23, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", pyth_tests::data_sources_for_test_vaa(), vector[x"beFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"], DEFAULT_BASE_UPDATE_FEE, DEFAULT_COIN_TO_MINT);
//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         clock.set_for_testing(1663680745000);
//         let (mut pyth_state, worm_state) = pyth_tests::take_wormhole_and_pyth_states(&scenario);

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let verified_vaas = get_verified_test_vaas(&worm_state, &clock);
//         pyth::create_price_feeds(&mut pyth_state,verified_vaas,&clock,ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let price_info_object_1 = take_shared<PriceInfoObject>(&scenario);
//         let price_info_object_2 = take_shared<PriceInfoObject>(&scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         setup_oracle(&mut scenario);
//         {
//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//             let mut oracle_1 = test_scenario::take_shared<Oracle>(&scenario);

//             oracle::update_pyth_oracle(&mut oracle_1, &manager_cap, &price_info_object_1, &price_info_object_2);
//             oracle::update_with_pyth_usd(&mut oracle_1, &pyth_state, &price_info_object_1, &clock, test_scenario::ctx(&mut scenario));

//             test_scenario::return_shared(oracle_1);
//             test_scenario::return_to_sender(&scenario, manager_cap);
//         };

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         return_shared(price_info_object_1);
//         return_shared(price_info_object_2);

//         coin::burn_for_testing(test_coins);
//         pyth_tests::cleanup_worm_state_pyth_state_and_clock(worm_state, pyth_state, clock);
//         test_scenario::end(scenario);
//     }

//     #[test]
//     #[expected_failure(abort_code = 5, location = typus_oracle::oracle)]
//     fun test_update_with_pyth_usd_not_pyth() {
//         let (mut scenario, test_coins, mut clock) =  pyth_tests::setup_test(500, 23, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", pyth_tests::data_sources_for_test_vaa(), vector[x"beFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"], DEFAULT_BASE_UPDATE_FEE, DEFAULT_COIN_TO_MINT);
//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         clock.set_for_testing(1663680745000);
//         let (mut pyth_state, worm_state) = pyth_tests::take_wormhole_and_pyth_states(&scenario);

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let verified_vaas = get_verified_test_vaas(&worm_state, &clock);
//         pyth::create_price_feeds(&mut pyth_state,verified_vaas,&clock,ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let price_info_object_1 = take_shared<PriceInfoObject>(&scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         setup_oracle(&mut scenario);
//         {
//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//             oracle::new_oracle<BTC, USD>(
//                 &manager_cap,
//                 std::ascii::string(b"BTC"),
//                 std::ascii::string(b"USD"),
//                 4,
//                 test_scenario::ctx(&mut scenario)
//             );

//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let mut oracle_1 = test_scenario::take_shared<Oracle>(&scenario);

//             // without setting pyth oracle
//             // oracle::update_pyth_oracle_usd(&mut oracle_1, &manager_cap, &price_info_object_1);
//             oracle::update_with_pyth_usd(&mut oracle_1, &pyth_state, &price_info_object_1, &clock, test_scenario::ctx(&mut scenario));

//             test_scenario::return_shared(oracle_1);
//             test_scenario::return_to_sender(&scenario, manager_cap);
//         };

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         return_shared(price_info_object_1);

//         coin::burn_for_testing(test_coins);
//         pyth_tests::cleanup_worm_state_pyth_state_and_clock(worm_state, pyth_state, clock);
//         test_scenario::end(scenario);
//     }


//     #[test]
//     #[expected_failure(abort_code = 6, location = typus_oracle::oracle)]
//     fun test_update_with_pyth_usd_invalid_pyth() {
//         let (mut scenario, test_coins, mut clock) =  pyth_tests::setup_test(500, 23, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", pyth_tests::data_sources_for_test_vaa(), vector[x"beFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"], DEFAULT_BASE_UPDATE_FEE, DEFAULT_COIN_TO_MINT);
//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         clock.set_for_testing(1663680745000);
//         let (mut pyth_state, worm_state) = pyth_tests::take_wormhole_and_pyth_states(&scenario);

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let verified_vaas = get_verified_test_vaas(&worm_state, &clock);
//         pyth::create_price_feeds(&mut pyth_state,verified_vaas,&clock,ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let price_info_object_1 = take_shared<PriceInfoObject>(&scenario);
//         let price_info_object_2 = take_shared<PriceInfoObject>(&scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         setup_oracle(&mut scenario);

//         {
//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//             oracle::new_oracle<BTC, USD>(
//                 &manager_cap,
//                 std::ascii::string(b"BTC"),
//                 std::ascii::string(b"USD"),
//                 4,
//                 test_scenario::ctx(&mut scenario)
//             );

//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let mut oracle_1 = test_scenario::take_shared<Oracle>(&scenario);

//             oracle::update_pyth_oracle_usd(&mut oracle_1, &manager_cap, &price_info_object_1);
//             oracle::update_with_pyth_usd(&mut oracle_1, &pyth_state, &price_info_object_2, &clock, test_scenario::ctx(&mut scenario));

//             test_scenario::return_shared(oracle_1);
//             test_scenario::return_to_sender(&scenario, manager_cap);
//         };

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         return_shared(price_info_object_1);
//         return_shared(price_info_object_2);

//         coin::burn_for_testing(test_coins);
//         pyth_tests::cleanup_worm_state_pyth_state_and_clock(worm_state, pyth_state, clock);
//         test_scenario::end(scenario);
//     }


//     #[test]
//     #[expected_failure(abort_code = 1, location = typus_oracle::oracle)]
//     fun test_update_with_pyth_usd_expiried() {
//         let (mut scenario, test_coins, mut clock) =  pyth_tests::setup_test(500, 23, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", pyth_tests::data_sources_for_test_vaa(), vector[x"beFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"], DEFAULT_BASE_UPDATE_FEE, DEFAULT_COIN_TO_MINT);
//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         clock.set_for_testing(1663680745000);
//         let (mut pyth_state, worm_state) = pyth_tests::take_wormhole_and_pyth_states(&scenario);

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let verified_vaas = get_verified_test_vaas(&worm_state, &clock);
//         pyth::create_price_feeds(&mut pyth_state,verified_vaas,&clock,ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let price_info_object_1 = take_shared<PriceInfoObject>(&scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         setup_oracle(&mut scenario);
//         {
//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//             oracle::new_oracle<BTC, USD>(
//                 &manager_cap,
//                 std::ascii::string(b"BTC"),
//                 std::ascii::string(b"USD"),
//                 4,
//                 test_scenario::ctx(&mut scenario)
//             );

//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let mut oracle_1 = test_scenario::take_shared<Oracle>(&scenario);

//             oracle_1.update_time_interval(&manager_cap, 5_000); // allow 5s
//             oracle::update_pyth_oracle_usd(&mut oracle_1, &manager_cap, &price_info_object_1);

//             clock.increment_for_testing(20_000);
//             oracle::update_with_pyth_usd(&mut oracle_1, &pyth_state, &price_info_object_1, &clock, test_scenario::ctx(&mut scenario));

//             test_scenario::return_shared(oracle_1);
//             test_scenario::return_to_sender(&scenario, manager_cap);
//         };

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         return_shared(price_info_object_1);

//         coin::burn_for_testing(test_coins);
//         pyth_tests::cleanup_worm_state_pyth_state_and_clock(worm_state, pyth_state, clock);
//         test_scenario::end(scenario);
//     }


//     #[test]
//     #[expected_failure(abort_code = 1, location = typus_oracle::oracle)]
//     fun test_update_with_pyth_expiried() {
//         let (mut scenario, test_coins, mut clock) =  pyth_tests::setup_test(500, 23, x"5d1f252d5de865279b00c84bce362774c2804294ed53299bc4a0389a5defef92", pyth_tests::data_sources_for_test_vaa(), vector[x"beFA429d57cD18b7F8A4d91A2da9AB4AF05d0FBe"], DEFAULT_BASE_UPDATE_FEE, DEFAULT_COIN_TO_MINT);
//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         clock.set_for_testing(1663680745000);
//         let (mut pyth_state, worm_state) = pyth_tests::take_wormhole_and_pyth_states(&scenario);

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let verified_vaas = get_verified_test_vaas(&worm_state, &clock);
//         pyth::create_price_feeds(&mut pyth_state,verified_vaas,&clock,ctx(&mut scenario));

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         let price_info_object_1 = take_shared<PriceInfoObject>(&scenario);
//         let price_info_object_2 = take_shared<PriceInfoObject>(&scenario);

//         test_scenario::next_tx(&mut scenario, ADMIN);
//         setup_oracle(&mut scenario);
//         {
//             test_scenario::next_tx(&mut scenario, ADMIN);
//             let manager_cap = test_scenario::take_from_sender<ManagerCap>(&scenario);
//             let mut oracle_1 = test_scenario::take_shared<Oracle>(&scenario);

//             oracle_1.update_time_interval(&manager_cap, 5_000); // allow 5s
//             oracle::update_pyth_oracle(&mut oracle_1, &manager_cap, &price_info_object_1, &price_info_object_2);

//             clock.increment_for_testing(300_000);
//             oracle::update_with_pyth(&mut oracle_1, &pyth_state, &price_info_object_1, &price_info_object_2, &clock, test_scenario::ctx(&mut scenario));

//             test_scenario::return_shared(oracle_1);
//             test_scenario::return_to_sender(&scenario, manager_cap);
//         };

//         test_scenario::next_tx(&mut scenario, DEPLOYER);
//         return_shared(price_info_object_1);
//         return_shared(price_info_object_2);

//         coin::burn_for_testing(test_coins);
//         pyth_tests::cleanup_worm_state_pyth_state_and_clock(worm_state, pyth_state, clock);
//         test_scenario::end(scenario);
//     }
// }