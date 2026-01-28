/// No authority chech in these public functions, do not let `Auction` be exposed.
module typus_framework::dutch {
    use std::type_name::{Self, TypeName};

    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::event::emit;

    use typus_framework::balance_pool::{Self, BalancePool};
    use typus_framework::big_vector::{Self, BigVector};
    use typus_framework::utils;
    use typus_framework::vault::{Self, RefundVault};

    #[test_only]
    use sui::test_scenario;

    // ======== Errors ========

    #[error]
    const EInvalidTimePeriod: vector<u8> = b"invalid_time_period";
    #[error]
    const EInvalidSize: vector<u8> = b"invalid_size";
    #[error]
    const EInvalidDecaySpeed: vector<u8> = b"invalid_decay_speed";
    #[error]
    const EInvalidAuctionPrice: vector<u8> = b"invalid_auction_price";
    #[error]
    const EInvalidToken: vector<u8> = b"invalid_token";
    #[error]
    const EMaxSizeReached: vector<u8> = b"max_size_reached";
    #[error]
    const EZeroSize: vector<u8> = b"zero_size";
    #[error]
    const EBidNotExists: vector<u8> = b"bid_not_exists";
    #[error]
    const EAuctionNotYetStarted: vector<u8> = b"auction_not_yet_started";
    #[error]
    const EAuctionAlreadyStarted: vector<u8> = b"auction_already_started";
    #[error]
    const EAuctionNotYetEnded: vector<u8> = b"auction_not_yet_ended";
    #[error]
    const EAuctionClosed: vector<u8> = b"auction_closed";
    #[error]
    const EInvalidBidValue: vector<u8> = b"invalid_bid_value";
    #[error]
    const ERemoveBidDisabled: vector<u8> = b"remove_bid_disabled";
    #[error]
    const EDeprecated: vector<u8> = b"deprecated";


    // ======== Dynamic Field Key ========

    const K_BIDDER_BALANCE: vector<u8> = b"bidder_balance";
    const K_INCENTIVE_BALANCE: vector<u8> = b"incentive_balance";

    // ======== Structs ========

    /// One-time witness struct for the `dutch` module.
    public struct DUTCH has drop {}

    /// Represents a Dutch auction.
    public struct Auction has key, store {
        id: UID,
        /// An index for the auction.
        index: u64,
        /// The `TypeName` of the token being accepted for bids.
        token: TypeName,
        /// The start timestamp of the auction in milliseconds.
        start_ts_ms: u64,
        /// The end timestamp of the auction in milliseconds.
        end_ts_ms: u64,
        /// The total amount of the asset being auctioned.
        size: u64, // max size
        /// The speed at which the price decays.
        decay_speed: u64,
        /// The starting price of the asset.
        initial_price: u64,
        /// The final price of the asset.
        final_price: u64,
        /// The fee in basis points.
        fee_bp: u64,
        /// The incentive in basis points.
        incentive_bp: u64,
        /// The decimal precision of the bid token.
        token_decimal: u64, // bid token
        /// The decimal precision of the auctioned asset.
        size_decimal: u64, // contract token / contract size
        /// The total size of all bids received so far.
        total_bid_size: u64, // sum of bids size
        /// A boolean indicating if bids can be removed.
        able_to_remove_bid: bool,
        /// A `BigVector` to store all the bids.
        bids: BigVector<Bid>,
        /// A counter for the number of bids.
        bid_index: u64,
    }

    /// Represents a single bid in a Dutch auction.
    public struct Bid has store {
        /// An index for the bid.
        index: u64,
        /// The address of the bidder.
        bidder: address,
        /// The price at which the bid was made.
        price: u64,
        /// The size of the bid.
        size: u64,
        /// The balance provided by the bidder.
        bidder_balance: u64,
        /// The incentive balance used for the bid.
        incentive_balance: u64,
        /// The fee discount applied to the bid.
        fee_discount: u64,
        /// The timestamp of the bid in milliseconds.
        ts_ms: u64,
    }

    // ======== Public Functions ========

    /// Creates a new `Auction`.
    public fun new<TOKEN>(
        index: u64,
        start_ts_ms: u64,
        end_ts_ms: u64,
        size: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
        fee_bp: u64,
        incentive_bp: u64,
        token_decimal: u64,
        size_decimal: u64,
        able_to_remove_bid: bool,
        ctx: &mut TxContext,
    ): Auction {
        assert!(end_ts_ms > start_ts_ms, EInvalidTimePeriod);
        assert!(size > 0, EInvalidSize);
        assert!(decay_speed > 0, EInvalidDecaySpeed);
        assert!(initial_price >= final_price && final_price > 0, EInvalidAuctionPrice);

        let mut id = object::new(ctx);
        dynamic_field::add(&mut id, K_BIDDER_BALANCE, balance::zero<TOKEN>());
        dynamic_field::add(&mut id, K_INCENTIVE_BALANCE, balance::zero<TOKEN>());

        Auction {
            id,
            index,
            token: type_name::with_defining_ids<TOKEN>(),
            start_ts_ms,
            end_ts_ms,
            size,
            decay_speed,
            initial_price,
            final_price,
            fee_bp,
            incentive_bp,
            token_decimal,
            size_decimal,
            total_bid_size: 0,
            able_to_remove_bid,
            bids: big_vector::new(1000, ctx),
            bid_index: 0,
        }
    }

    /// Allows a user to place a bid on the auction.
    /// WARNING: mut inputs without authority check inside
    public fun public_new_bid_v2<TOKEN>(
        refund_vault: &mut RefundVault,
        auction: &mut Auction,
        bidder: address,
        size: u64,
        coins: vector<Coin<TOKEN>>,
        incentive_balance: Balance<TOKEN>,
        fee_discount: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (u64, u64, u64, u64, u64, u64, address, Coin<TOKEN>) {
        // safety check
        let ts_ms = clock::timestamp_ms(clock);
        assert!(ts_ms >= auction.start_ts_ms, EAuctionNotYetStarted);
        assert!(ts_ms <= auction.end_ts_ms, EAuctionClosed);
        assert!(size > 0, EZeroSize);
        assert!(auction.total_bid_size + size <= auction.size, EMaxSizeReached);
        assert!(auction.token == type_name::with_defining_ids<TOKEN>(), EInvalidToken);

        // main logic
        let refund_index = vault::register_refund<TOKEN>(refund_vault, bidder);
        let (price, size, bid_value, fee) = get_bid_info(auction, size, fee_discount, ts_ms);
        let total_bid_value = bid_value + fee;
        assert!(total_bid_value > 0, EInvalidBidValue);
        let incentive_balance_value = balance::value(&incentive_balance);
        // add new bid
        let index = auction.bid_index;
        auction.bid_index = auction.bid_index + 1;
        auction.total_bid_size = auction.total_bid_size + size;
        let bidder_balance_value = if (total_bid_value > incentive_balance_value) {
            total_bid_value - incentive_balance_value
        } else {
            0
        };

        let mut coin = utils::merge_coins(coins);
        let bidder_coin = coin::split<TOKEN>(&mut coin, bidder_balance_value, ctx);
        let bidder_balance = coin::into_balance(bidder_coin);

        big_vector::push_back(
            &mut auction.bids,
            Bid {
                index: ts_ms,
                bidder,
                price,
                size,
                bidder_balance: bidder_balance_value,
                incentive_balance: incentive_balance_value,
                fee_discount,
                ts_ms: refund_index,
            }
        );
        balance::join(
            dynamic_field::borrow_mut(&mut auction.id, K_BIDDER_BALANCE),
            bidder_balance
        );
        balance::join(
            dynamic_field::borrow_mut(&mut auction.id, K_INCENTIVE_BALANCE),
            incentive_balance
        );

        // emit event
        emit(NewBid {
            signer: bidder,
            index: auction.index,
            token: type_name::with_defining_ids<TOKEN>(),
            bid_index: index,
            price,
            size,
            bidder_balance: bidder_balance_value,
            incentive_balance: incentive_balance_value,
            ts_ms,
        });

        (
            index,
            price,
            size,
            bidder_balance_value,
            incentive_balance_value,
            ts_ms,
            bidder,
            coin,
        )
    }

    /// Allows a user to remove their bid.
    /// WARNING: mut inputs without authority check inside
    #[lint_allow(self_transfer)]
    public fun remove_bid<TOKEN>(
        auction: &mut Auction,
        index: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Balance<TOKEN> {
        // safety check
        assert!(auction.able_to_remove_bid, ERemoveBidDisabled);
        let ts_ms = clock::timestamp_ms(clock);
        assert!(ts_ms >= auction.start_ts_ms, EAuctionNotYetStarted);
        assert!(ts_ms <= auction.end_ts_ms, EAuctionClosed);
        assert!(auction.token == type_name::with_defining_ids<TOKEN>(), EInvalidToken);

        // main logic
        let bidder = tx_context::sender(ctx);
        let length = big_vector::length(&auction.bids);
        let slice_size = big_vector::slice_size(&auction.bids);
        let mut slice = big_vector::borrow_slice(&auction.bids, 1);
        let mut i = 0;
        while (i < length) {
            let bid = vector::borrow(slice, i % slice_size);
            if (bid.bidder == bidder && bid.index == index) {
                break
            };
            if (i + 1 < length && (i + 1) % slice_size == 0) {
                let slice_id = big_vector::slice_id(&auction.bids, i + 1);
                slice = big_vector::borrow_slice(
                    &auction.bids,
                    slice_id,
                );
            };
            i = i + 1;
        };
        if (i == length) {
            abort EBidNotExists
        };
        let Bid {
            index: _,
            bidder: _,
            price,
            size,
            bidder_balance,
            incentive_balance,
            fee_discount,
            ts_ms,
        } = big_vector::remove(&mut auction.bids, i);
        auction.total_bid_size = auction.total_bid_size - size;
        transfer::public_transfer(
            coin::from_balance<TOKEN>(
                balance::split(
                    dynamic_field::borrow_mut(&mut auction.id, K_BIDDER_BALANCE),
                    bidder_balance,
                ),
                ctx,
            ),
            bidder,
        );

        // emit event
        emit(RemoveBid {
            signer: bidder,
            index: auction.index,
            token: type_name::with_defining_ids<TOKEN>(),
            bid_index: index,
            price,
            size,
            bidder_balance,
            incentive_balance,
            fee_discount,
            ts_ms,
        });

        balance::split(
            dynamic_field::borrow_mut(&mut auction.id, K_INCENTIVE_BALANCE),
            incentive_balance,
        )
    }

    /// This function is called after the auction ends to distribute the assets and funds.
    /// WARNING: mut inputs without authority check inside
    public fun delivery<TOKEN>(
        fee_pool: &mut BalancePool,
        refund_vault: &mut RefundVault,
        auction: Auction,
        early: bool,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Balance<TOKEN>, Balance<TOKEN>, u64, u64, u64, u64, u64, u64) {
        // safety check
        assert!(clock::timestamp_ms(clock) >= auction.start_ts_ms, EAuctionNotYetStarted);
        assert!(early || clock::timestamp_ms(clock) >= auction.end_ts_ms, EAuctionNotYetEnded);
        assert!(auction.token == type_name::with_defining_ids<TOKEN>(), EInvalidToken);

        // main logic
        let Auction {
            mut id,
            index,
            token: _,
            start_ts_ms: _,
            end_ts_ms: _,
            size,
            decay_speed: _,
            initial_price: _,
            final_price,
            fee_bp,
            incentive_bp,
            token_decimal,
            size_decimal,
            total_bid_size,
            able_to_remove_bid: _,
            mut bids,
            bid_index: _,
        } = auction;
        let mut total_incentive_bid_value = 0;
        let mut total_incentive_fee = 0;
        let mut total_bidder_fee = 0;
        let price = if (total_bid_size < size) {
            final_price
        } else {
            big_vector::borrow(&bids, big_vector::length(&bids) - 1).price
        };
        let mut premium_balance = dynamic_field::remove(&mut id, K_BIDDER_BALANCE);
        let mut refund_users = vector[];
        let mut refund_shares = vector[];
        let mut refund_balance = balance::zero();
        while (!big_vector::is_empty(&bids)) {
            // get market maker bid and fund
            let Bid {
                index: _,
                bidder: _,
                price: _,
                size,
                mut bidder_balance,
                mut incentive_balance,
                fee_discount,
                ts_ms: refund_index,
            } = big_vector::pop_back(&mut bids);
            let (mut bid_value, mut fee) = calculate_bid_value(
                fee_bp,
                token_decimal,
                size_decimal,
                price,
                size,
                fee_discount,
            );
            let mut incentive_bid_value = ((bid_value as u128)
                                        * (incentive_bp as u128)
                                            / (10000 as u128) as u64);
            let mut incentive_fee = ((fee as u128)
                                        * (incentive_bp as u128)
                                            / (10000 as u128) as u64);
            if (incentive_fee > incentive_balance) {
                incentive_fee = incentive_balance;
            };
            total_incentive_fee = total_incentive_fee + incentive_fee;
            incentive_balance = incentive_balance - incentive_fee;
            fee = fee - incentive_fee;
            if (incentive_bid_value > incentive_balance) {
                incentive_bid_value = incentive_balance;
            };
            total_incentive_bid_value = total_incentive_bid_value + incentive_bid_value;
            bid_value = bid_value - incentive_bid_value;
            // balance
            if (fee > bidder_balance) {
                fee = bidder_balance;
            };
            total_bidder_fee = total_bidder_fee + fee;
            bidder_balance = bidder_balance - fee;
            if (bid_value < bidder_balance) {
                let balance = balance::split(&mut premium_balance, bidder_balance - bid_value);
                vector::push_back(&mut refund_users, refund_index);
                vector::push_back(&mut refund_shares, bidder_balance - bid_value);
                balance::join(&mut refund_balance, balance);
            };
        };
        if (balance::value(&refund_balance) != 0) {
            vault::put_refunds<TOKEN>(
                refund_vault,
                refund_balance,
                refund_users,
                refund_shares,
            );
        } else {
            balance::destroy_zero(refund_balance);
        };
        // extract balance
        let mut incentive_refund: Balance<TOKEN> = dynamic_field::remove(&mut id, K_INCENTIVE_BALANCE);
        let mut fee_balance = balance::split(&mut premium_balance, total_bidder_fee);
        let total_bidder_bid_value = balance::value(&premium_balance);
        balance::join(&mut fee_balance, balance::split(&mut incentive_refund, total_incentive_fee));
        balance_pool::put(fee_pool, fee_balance);
        balance::join(&mut premium_balance, balance::split(&mut incentive_refund, total_incentive_bid_value));
        // destruct auction
        object::delete(id);
        big_vector::destroy_empty(bids);

        // emit event
        emit(Delivery {
            signer: tx_context::sender(ctx),
            index,
            token: type_name::with_defining_ids<TOKEN>(),
            price,
            size: total_bid_size,
            bidder_bid_value: total_bidder_bid_value,
            bidder_fee: total_bidder_fee,
            incentive_bid_value: total_incentive_bid_value,
            incentive_fee: total_incentive_fee,
        });

        (
            premium_balance,
            incentive_refund,
            price,
            total_bid_size,
            total_bidder_bid_value,
            total_bidder_fee,
            total_incentive_bid_value,
            total_incentive_fee,
        )
    }

    /// Updates the configuration of an auction before it has started.
    /// WARNING: mut inputs without authority check inside
    public fun update_auction_config(
        auction: &mut Auction,
        start_ts_ms: u64,
        end_ts_ms: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
        fee_bp: u64,
        incentive_bp: u64,
        token_decimal: u64, // bid token
        size_decimal: u64, // deposit token / contract size
        able_to_remove_bid: bool,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        // main logic
        let ts_ms = clock::timestamp_ms(clock);
        assert!(ts_ms < auction.start_ts_ms, EAuctionAlreadyStarted);
        assert!(end_ts_ms > start_ts_ms, EInvalidTimePeriod);
        assert!(decay_speed > 0, EInvalidDecaySpeed);
        assert!(initial_price >= final_price && final_price > 0, EInvalidAuctionPrice);
        let prev_start_ts_ms = auction.start_ts_ms;
        let prev_end_ts_ms = auction.end_ts_ms;
        let prev_decay_speed = auction.decay_speed;
        let prev_initial_price = auction.initial_price;
        let prev_final_price = auction.final_price;
        let prev_fee_bp = auction.fee_bp;
        let prev_incentive_bp = auction.incentive_bp;
        let prev_token_decimal = auction.token_decimal;
        let prev_size_decimal = auction.size_decimal;
        let prev_able_to_remove_bid = auction.able_to_remove_bid;
        auction.start_ts_ms = start_ts_ms;
        auction.end_ts_ms = end_ts_ms;
        auction.decay_speed = decay_speed;
        auction.initial_price = initial_price;
        auction.final_price = final_price;
        auction.fee_bp = fee_bp;
        auction.incentive_bp = incentive_bp;
        auction.token_decimal = token_decimal;
        auction.size_decimal = size_decimal;
        auction.able_to_remove_bid = able_to_remove_bid;

        // emit event
        emit(UpdateAuctionConfig{
            signer: tx_context::sender(ctx),
            index: auction.index,
            prev_start_ts_ms,
            prev_end_ts_ms,
            prev_decay_speed,
            prev_initial_price,
            prev_final_price,
            prev_fee_bp,
            prev_incentive_bp,
            prev_token_decimal,
            prev_size_decimal,
            prev_able_to_remove_bid,
            start_ts_ms,
            end_ts_ms,
            decay_speed,
            initial_price,
            final_price,
            fee_bp,
            incentive_bp,
            token_decimal,
            size_decimal,
            able_to_remove_bid,
        });
    }

    /// Terminates an auction and refunds all bidders.
    /// WARNING: mut inputs without authority check inside
    public fun terminate<TOKEN>(
        auction: Auction,
        refund_vault: &mut RefundVault,
        ctx: &TxContext,
    ): Balance<TOKEN> {
        // safety check
        assert!(auction.token == type_name::with_defining_ids<TOKEN>(), EInvalidToken);

        // main logic
        let Auction {
            mut id,
            index,
            token,
            start_ts_ms: _,
            end_ts_ms: _,
            size: _,
            decay_speed: _,
            initial_price: _,
            final_price: _,
            fee_bp: _,
            incentive_bp: _,
            token_decimal: _,
            size_decimal: _,
            total_bid_size: _,
            able_to_remove_bid: _,
            mut bids,
            bid_index: _,
        } = auction;
        while (!big_vector::is_empty(&bids)) {
            // get market maker bid and fund
            let Bid {
                index: _,
                bidder,
                price: _,
                size: _,
                bidder_balance,
                incentive_balance: _,
                fee_discount: _,
                ts_ms: _,
            } = big_vector::pop_back(&mut bids);
            vault::put_refund<TOKEN>(
                refund_vault,
                balance::split(
                    dynamic_field::borrow_mut(&mut id, K_BIDDER_BALANCE),
                    bidder_balance,
                ),
                bidder,
            );
        };
        big_vector::destroy_empty(bids);
        balance::destroy_zero<TOKEN>(dynamic_field::remove(&mut id, K_BIDDER_BALANCE));
        let incentive_refund = dynamic_field::remove(&mut id, K_INCENTIVE_BALANCE);
        object::delete(id);

        // emit event
        emit(Terminate{
            signer: tx_context::sender(ctx),
            index,
            token,
        });

        incentive_refund
    }

    // ======== Helper Functions ========

    /// Gets the bid information for a given size at a specific time.
    public fun get_bid_info(
        auction: &Auction,
        mut size: u64,
        fee_discount: u64,
        ts_ms: u64,
    ): (u64, u64, u64, u64) {
        let price = decay_formula(
            auction.initial_price,
            auction.final_price,
            auction.decay_speed,
            auction.start_ts_ms,
            auction.end_ts_ms,
            ts_ms,
        );
        if (auction.size - auction.total_bid_size < size) {
            size = auction.size - auction.total_bid_size;
        };
        let (bid_value, fee) = calculate_bid_value(
            auction.fee_bp,
            auction.token_decimal,
            auction.size_decimal,
            price,
            size,
            fee_discount,
        );

        (price, size, bid_value, fee)
    }

    /// Calculates the bid value and fee for a given price, size, and fee discount.
    public fun calculate_bid_value(
        fee_bp: u64,
        token_decimal: u64,
        size_decimal: u64,
        price: u64,
        size: u64,
        fee_discount: u64,
    ): (u64, u64) {
        let token_multiplier = utils::multiplier(token_decimal);
        let size_multiplier = utils::multiplier(size_decimal);
        let fee_multiplier = 10000;
        let bid_value = ((price as u128) * (size as u128) / (token_multiplier as u128) as u64); // size_decimal
        // 1000 * (10000 - 500) / 10000 = fee 5% off
        let fee_cap = (fee_bp as u128) * ((fee_multiplier - fee_discount) as u128) / (fee_multiplier as u128);
        let fee = ((bid_value as u128) * fee_cap / (fee_multiplier as u128) as u64); // size_decimal

        // change bid_value decimal from size_decimal to token_decimal
        (
            ((bid_value as u128) * (token_multiplier as u128) / (size_multiplier as u128) as u64),
            ((fee as u128) * (token_multiplier as u128) / (size_multiplier as u128) as u64),
        )
    }

    /// Calculates the bid size for a given balance, price, and fee discount.
    public fun calculate_bid_size(
        fee_bp: u64,
        size_decimal: u64,
        price: u64,
        balance: u64,
        fee_discount: u64,
    ): u64 {
        let size_multiplier = utils::multiplier(size_decimal);
        let fee_multiplier = 10000;

        // 1000 * (10000 - 500) / 10000 = fee 5% off
        let fee_cap = ((fee_bp as u128) * ((fee_multiplier - fee_discount) as u128) / (fee_multiplier as u128) as u64);
        let price_with_fee = ((price as u128) * (fee_cap + fee_multiplier as u128) / (fee_multiplier as u128) as u64);

        ((balance as u128) * (size_multiplier as u128) / (price_with_fee + 1 as u128) as u64)
    }

    /// Returns the `TypeName` of the token being accepted for bids.
    public fun token(
        auction: &Auction,
    ): TypeName {
        auction.token
    }

    /// Returns the total size of the asset being auctioned.
    public fun size(
        auction: &Auction,
    ): u64 {
        auction.size
    }

    /// Returns the total size of all bids received so far.
    public fun total_bid_size(
        auction: &Auction,
    ): u64 {
        auction.total_bid_size
    }

    /// Returns the current bid index.
    public fun bid_index(
        auction: &Auction,
    ): u64 {
        auction.bid_index
    }

    /// Returns the incentive in basis points.
    public fun incentive_bp(
        auction: &Auction,
    ): u64 {
        auction.incentive_bp
    }

    /// Returns a reference to the `BigVector` of bids.
    public fun bids(
        auction: &Auction,
    ): &BigVector<Bid> {
        &auction.bids
    }

    /// Returns the current decayed price of the auction.
    public fun get_decayed_price(
        auction: &Auction,
        clock: &Clock,
    ): u64 {
        decay_formula(
            auction.initial_price,
            auction.final_price,
            auction.decay_speed,
            auction.start_ts_ms,
            auction.end_ts_ms,
            clock::timestamp_ms(clock)
        )
    }

    /// Returns information about a specific bid.
    public fun get_user_bid_info(
        auction: &Auction,
        bid_index: u64,
    ): (u64, address, u64, u64, u64, u64, u64, u64) {
        let mut i = 0;
        let length = big_vector::length(&auction.bids);
        while (i < length) {
            let bid = big_vector::borrow(&auction.bids, i);
            if (bid.index == bid_index) {
                return (
                    bid.index,
                    bid.bidder,
                    bid.price,
                    bid.size,
                    bid.bidder_balance,
                    bid.incentive_balance,
                    bid.fee_discount,
                    bid.ts_ms,
                )
            };
            i = i + 1;
        };
        (0, @0x1, 0, 0, 0, 0, 0, 0)
    }

    // ======== Private Functions ========

    /// Private function that is called when the module is published.
    fun init(otw: DUTCH, ctx: &mut TxContext) {
        sui::package::claim_and_keep(otw, ctx);
    }

    /// The core logic for the Dutch auction's price decay.
    /// decayed_price =
    ///     initial_price -
    ///         (initial_price - final_price) *
    ///             (1 - remaining_time / auction_duration) ^ decay_speed
    fun decay_formula(
        initial_price: u64,
        final_price: u64,
        mut decay_speed: u64,
        start_ts_ms: u64,
        end_ts_ms: u64,
        current_ts_ms: u64,
    ): u64 {
        if (current_ts_ms <= start_ts_ms) {
            return initial_price
        };
        // 1 - remaining_time / auction_duration => 1 - (end - current) / (end - start) => (current - start) / (end - start)
        let mut price_diff = initial_price - final_price;
        let numerator = current_ts_ms - start_ts_ms;
        let denominator = end_ts_ms - start_ts_ms;
        while (decay_speed > 0) {
            price_diff  = ((price_diff as u128) * (numerator as u128) / (denominator as u128) as u64);
            decay_speed = decay_speed - 1;
        };

        initial_price - price_diff
    }
    // ======== Events =========

    /// Event emitted when a new bid is placed.
    public struct NewBid has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        bid_index: u64,
        price: u64,
        size: u64,
        bidder_balance: u64,
        incentive_balance: u64,
        ts_ms: u64,
    }

    /// Event emitted when a bid is removed.
    public struct RemoveBid has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        bid_index: u64,
        price: u64,
        size: u64,
        bidder_balance: u64,
        incentive_balance: u64,
        fee_discount: u64,
        ts_ms: u64,
    }

    /// Event emitted when the auction is delivered.
    public struct Delivery has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
        price: u64,
        size: u64,
        bidder_bid_value: u64,
        bidder_fee: u64,
        incentive_bid_value: u64,
        incentive_fee: u64,
    }

    /// Event emitted when the auction configuration is updated.
    public struct UpdateAuctionConfig has copy, drop {
        signer: address,
        index: u64,
        prev_start_ts_ms: u64,
        prev_end_ts_ms: u64,
        prev_decay_speed: u64,
        prev_initial_price: u64,
        prev_final_price: u64,
        prev_fee_bp: u64,
        prev_incentive_bp: u64,
        prev_token_decimal: u64,
        prev_size_decimal: u64,
        prev_able_to_remove_bid: bool,
        start_ts_ms: u64,
        end_ts_ms: u64,
        decay_speed: u64,
        initial_price: u64,
        final_price: u64,
        fee_bp: u64,
        incentive_bp: u64,
        token_decimal: u64,
        size_decimal: u64,
        able_to_remove_bid: bool,
    }

    /// Event emitted when the auction is terminated.
    public struct Terminate has copy, drop {
        signer: address,
        index: u64,
        token: TypeName,
    }

    #[test]
    fun test_init() {
        let mut scenario = test_scenario::begin(@0xABCD);
        init(DUTCH {}, scenario.ctx());
        scenario.end();
    }

    #[deprecated]
    public fun public_new_bid<TOKEN>(
        _bidder: address,
        _auction: &mut Auction,
        _size: u64,
        _coins: vector<Coin<TOKEN>>,
        _incentive_balance: Balance<TOKEN>,
        _fee_discount: u64,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (u64, u64, u64, u64, u64, u64, address, Coin<TOKEN>) {
        abort EDeprecated
    }
    #[deprecated]
    public fun new_bid_v2<TOKEN>(
        _refund_vault: &mut RefundVault,
        _auction: &mut Auction,
        _size: u64,
        _coins: vector<Coin<TOKEN>>,
        _incentive_balance: Balance<TOKEN>,
        _fee_discount: u64,
        _clock: &Clock,
        _ctx: &TxContext,
    ): (u64, u64, u64, u64, u64, u64, address) {
        abort EDeprecated
    }
    #[deprecated]
    public fun new_bid<TOKEN>(
        _auction: &mut Auction,
        _size: u64,
        _coins: vector<Coin<TOKEN>>,
        _incentive_balance: Balance<TOKEN>,
        _fee_discount: u64,
        _clock: &Clock,
        _ctx: &TxContext,
    ): (u64, u64, u64, u64, u64, u64, address) {
        abort EDeprecated
    }
    #[deprecated]
    public fun old_delivery<TOKEN>(
        _fee_pool: &mut BalancePool,
        _refund_vault: &mut RefundVault,
        _auction: Auction,
        _early: bool,
        _clock: &Clock,
        _ctx: &mut TxContext,
    ): (Balance<TOKEN>, Balance<TOKEN>, u64, u64, u64, u64, u64, u64) {
        abort EDeprecated
    }
}