// #[test_only]
// module typus_dov::test_witness_entry {
//     use sui::balance::Balance;
//     use sui::test_scenario::{Scenario, ctx, sender, next_tx, take_shared, return_shared};
//     use typus_dov::tds_witness_entry;
//     use typus_dov::test_environment;
//     use pyth::price_info::PriceInfoObject;
//     use typus::witness_lock::HotPotato;

//     public(package) fun test_add_lending_account_cap_<D_TOKEN, B_TOKEN>{
//         scenario: &mut Scenario,
//         index: u64,
//         price: u64,
//         size: u64,
//         premium_amount: u64,
//     } {
//         let mut registry = test_environment::dov_registry(scenario);
//         let coin = test_environment::mint_test_coin<B_TOKEN>(scenario, bidder_bid_value + bidder_fee_balance_value);

//         let (bid_receipt_option, rebate_balance_option, _log) = tds_witness_entry::add_lending_account_cap<W, D_TOKEN, B_TOKEN>(
//             witness,
//             signature,
//             &mut registry,
//             index,
//             price,
//             size,
//             coin.into_balance(),
//             ts_ms,
//             &clock,
//             ctx(scenario)
//         );

//         return_shared(registry);
//         clock.destroy_for_testing();
//         next_tx(scenario, ADMIN);
//     }
// }