// /// The `user_account` module defines the `UserAccount` and `UserAccountCap` structs, and the logic for creating, updating, and using them.
// module typus_perp::user_account {
//     use std::type_name::{Self, TypeName};
//     use std::string::{Self};
//     use sui::dynamic_field;
//     use sui::object_table::{Self, ObjectTable};
//     use sui::balance::{Self, Balance};

//     use typus_perp::error;

//     const K_USER_ACCOUNTS: vector<u8> = b"user_accounts";
//     // user_accounts: ObjectTable<address, UserAccount>

//     /// A struct that represents a user account.
//     public struct UserAccount has key, store {
//         id: UID,
//         /// The address of the owner of the user account.
//         owner: address,
//         /// A vector of the delegate users.
//         delegate_user: vector<address>,
//         /// A vector of the symbols of the tokens in the user account.
//         symbols: vector<TypeName>, // balances in df
//         /// Padding for future use.
//         u64_padding: vector<u64>,
//     }

//     /// A capability that allows a user to manage their account.
//     public struct UserAccountCap has key, store {
//         id: UID,
//         /// The address of the owner of the user account.
//         owner: address, // to find the UserAccount in table
//         /// The ID of the user account.
//         user_account_id: ID, // id of UserAccount
//     }

//     /// Creates a new user account and capability.
//     public(package) fun new_user_account(
//         ctx: &mut TxContext,
//     ): (UserAccount, UserAccountCap) {
//         let user_account = UserAccount {
//             id: object::new(ctx),
//             owner: ctx.sender(),
//             delegate_user: vector[ctx.sender()],
//             symbols: vector::empty(),
//             u64_padding: vector::empty(),
//         };

//         let user_account_cap = UserAccountCap {
//             id: object::new(ctx),
//             owner: ctx.sender(),
//             user_account_id: object::id(&user_account)
//         };

//         (user_account, user_account_cap)
//     }

//     /// Removes a user account.
//     /// WARNING: no authority check inside
//     public(package) fun remove_user_account(
//         market_id: &mut UID,
//         user: address,
//         user_account_cap: UserAccountCap,
//     ) {
//         let user_accounts = dynamic_field::borrow_mut(market_id, string::utf8(K_USER_ACCOUNTS));
//         let user_account: UserAccount = object_table::remove(user_accounts, user);

//         let UserAccount {
//             id,
//             owner: _,
//             delegate_user: _,
//             symbols,
//             u64_padding: _,
//         } = user_account;

//         assert!(symbols.is_empty(), error::not_empty_symbols());
//         id.delete();

//         let UserAccountCap {
//             id,
//             owner: _,
//             user_account_id: _
//         } = user_account_cap;
//         id.delete();
//     }


//     /// Checks if a user has an account.
//     public(package) fun has_user_account(
//         market_id: &UID,
//         user: address,
//     ): bool {
//         let user_accounts: &ObjectTable<address, UserAccount> = dynamic_field::borrow(market_id, string::utf8(K_USER_ACCOUNTS));
//         object_table::contains(user_accounts, user)
//     }

//     /// Gets a mutable reference to a user account.
//     /// WARNING: no security check, only delegate_user or cranker can access
//     public(package) fun get_mut_user_account(
//         market_id: &mut UID,
//         user: address
//     ): &mut UserAccount {
//         let user_accounts = dynamic_field::borrow_mut(market_id, string::utf8(K_USER_ACCOUNTS));
//         let user_account: &mut UserAccount = object_table::borrow_mut(user_accounts, user);
//         user_account
//     }

//     /// Checks if the sender is the owner of the user account.
//     /// Abort if not owner
//     public(package) fun check_owner(
//         user_account: &UserAccount,
//         ctx: &TxContext,
//     ) {
//         assert!(user_account.owner == ctx.sender(), error::not_user_account_owner());
//     }

//     /// Adds a delegate user to a user account.
//     /// WARNING: no authority check inside
//     public(package) fun add_delegate_user(
//         user_account: &mut UserAccount,
//         user: address,
//     ) {
//         if (!user_account.delegate_user.contains(&user)) {
//             user_account.delegate_user.push_back(user);
//         }
//     }

//     /// Remove a delegate user from a user account.
//     /// WARNING: no authority check inside
//     public(package) fun remove_delegate_user(
//         user_account: &mut UserAccount,
//         user: address,
//     ) {
//         if (user_account.delegate_user.contains(&user)) {
//             let (_exists, idx) = user_account.delegate_user.index_of(&user);
//             user_account.delegate_user.remove(idx);
//         }
//     }

//     /// Deposits collateral into a user account.
//     /// WARNING: no authority check inside
//     public(package) fun deposit<C_TOKEN>(
//         user_account: &mut UserAccount,
//         balance: Balance<C_TOKEN>,
//     ) {
//         let token_name = type_name::with_defining_ids<C_TOKEN>();
//         if (user_account.symbols.contains(&token_name)) {
//             let mut_balance: &mut Balance<C_TOKEN> = dynamic_field::borrow_mut(&mut user_account.id, token_name);
//             mut_balance.join(balance);
//         } else {
//             user_account.symbols.push_back(token_name);
//             dynamic_field::add(&mut user_account.id, token_name, balance);
//         }
//     }

//     /// Withdraws collateral from a user account.
//     /// WARNING: no authority check inside
//     public(package) fun withdraw<C_TOKEN>(
//         user_account: &mut UserAccount,
//         mut amount: Option<u64>,
//         user_account_cap: &UserAccountCap,
//     ): Balance<C_TOKEN> {
//         let token_name = type_name::with_defining_ids<C_TOKEN>();

//         // check user_account_cap
//         assert!(user_account_cap.user_account_id == object::id(user_account), error::not_user_account_cap());

//         if (amount.is_none()) {
//             let (exist, i) = user_account.symbols.index_of(&token_name);
//             if (exist) {
//                 user_account.symbols.remove(i);
//                 dynamic_field::remove(&mut user_account.id, token_name)
//             } else {
//                 balance::zero<C_TOKEN>()
//             }
//         } else {
//             let mut_balance: &mut Balance<C_TOKEN> = dynamic_field::borrow_mut(&mut user_account.id, token_name);
//             let amount = amount.extract();
//             // return balance
//             mut_balance.split(amount)
//         }
//     }

//     /// Gets the owner of a user account from a capability.
//     public(package) fun get_user_account_owner(
//         user_account_cap: &UserAccountCap,
//     ): address {
//         user_account_cap.owner
//     }
// }