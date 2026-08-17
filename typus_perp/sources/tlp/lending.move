/// The `lending` module provides functions for interacting with the Scallop lending protocol.
module typus_perp::lending {
    use sui::balance::Balance;
    use sui::clock::Clock;
    use sui::coin::{Self, Coin};

    use protocol::reserve::MarketCoin;
    use protocol::redeem;
    use protocol::mint;
    use protocol::market::Market as ScallopMarket;
    use protocol::version::Version as ScallopVersion;


    /// Deposits a token into the Scallop lending protocol.
    /// WARNING: no authority check inside
    public(package) fun deposit_scallop_basic<C_TOKEN>(
        balance: Balance<C_TOKEN>,
        scallop_version: &ScallopVersion,
        scallop_market: &mut ScallopMarket,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Coin<MarketCoin<C_TOKEN>>, vector<u64>) {
        let balance_value = balance.value();
        if (balance_value == 0) {
            balance.destroy_zero();
            return (coin::zero<MarketCoin<C_TOKEN>>(ctx), vector[0, 0])
        };
        let market_coin = mint::mint<C_TOKEN>(
            scallop_version,
            scallop_market,
            coin::from_balance(balance, ctx),
            clock,
            ctx,
        );
        let minted_coin_value = market_coin.value();
        let log = vector[
            balance_value,
            minted_coin_value
        ];

        (market_coin, log)
    }

    /// Withdraws a token from the Scallop lending protocol.
    /// WARNING: no authority check inside
    public(package) fun withdraw_scallop_basic<C_TOKEN>(
        market_coin: Coin<MarketCoin<C_TOKEN>>,
        scallop_version: &ScallopVersion,
        scallop_market: &mut ScallopMarket,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Balance<C_TOKEN>, vector<u64>) {
        let market_coin_value = market_coin.value();
        let balance = coin::into_balance(
            redeem::redeem<C_TOKEN>(
                scallop_version,
                scallop_market,
                market_coin,
                clock,
                ctx,
            )
        );
        // charge fee at lp_pool
        let balance_value = balance.value();
        let log = vector[
            market_coin_value,
            balance_value
        ];

        (balance, log)
    }
}

