// Copyright (c) Typus Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This module defines the `TGLD` (Typus Gold) token, a fungible token used within the Typus ecosystem.
/// It provides functions for creating, minting, and burning the token.
module typus::tgld {
    use std::ascii;

    use sui::coin::{Self, TreasuryCap};
    use sui::event::emit;
    use sui::token::{Self, Token, TokenPolicyCap};
    use sui::url;

    use typus::ecosystem::{ManagerCap, Version};

    // ======== Structs ========

    /// A struct representing the Typus Gold token type.
    public struct TGLD has drop {}

    /// A registry object that holds the `TreasuryCap` and `TokenPolicyCap` for the `TGLD` token.
    public struct TgldRegistry has key {
        id: UID,
        /// The treasury capability for the `TGLD` token, which allows for minting and burning.
        treasury_cap: TreasuryCap<TGLD>,
        /// The token policy capability, which allows for managing the token's transfer policy.
        token_policy_cap: TokenPolicyCap<TGLD>,
    }

    /// An event emitted when new `TGLD` tokens are minted.
    public struct MintEvent has copy, drop {
        /// The address of the recipient of the minted tokens.
        recipient: address,
        /// Log data: [minted_amount]
        log: vector<u64>,
        /// Padding for BCS.
        bcs_padding: vector<vector<u8>>,
    }

    /// An event emitted when `TGLD` tokens are burned.
    public struct BurnEvent has copy, drop {
        /// Log data: [burned_amount]
        log: vector<u64>,
        /// Padding for BCS.
        bcs_padding: vector<vector<u8>>,
    }

    // ======== Public Functions ========

    /// Initializes the `TGLD` token, creating the `TreasuryCap`, `CoinMetadata`, and `TokenPolicy`.
    /// It also creates and shares the `TgldRegistry`. This function is called only once during deployment.
    #[lint_allow(share_owned), allow(deprecated_usage)]
    fun init(witness: TGLD, ctx: &mut TxContext) {
        let (treasury_cap, coin_metadata) = coin::create_currency<TGLD>(
            witness,
            0,
            b"TGLD",
            b"Typus Gold",
            b"TGLD on Sui maintained by Typus Lab",
            option::some(url::new_unsafe(ascii::string(b"data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNTIiIGhlaWdodD0iNTIiIHZpZXdCb3g9IjAgMCA1MiA1MiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGNpcmNsZSBjeD0iMjYiIGN5PSIyNiIgcj0iMjYiIGZpbGw9InVybCgjcGFpbnQwX2xpbmVhcl8xNDU5MV80NjczMTApIi8+CjxwYXRoIGQ9Ik0yNy41ODA4IDguOTkyOTlDMjguNzUxNSA5Ljc3ODc5IDI5LjgyNTUgMTAuOTU3NSAzMC40OTgxIDExLjc1MzZDMzEuNzQwMiAxMy4yMTU2IDMzLjEyMzIgMTQuODIwMyAzMy44MTA1IDE2LjYyMTRDMzQuMzA0NCAxNy45MiAzNC4zNjEyIDE5LjQ0ODIgMzMuNjE5MiAyMC42Mjg5QzMyLjk3ODIgMjEuNjUwNCAzMS44NDk1IDIyLjI2NDYgMzAuNzcxMyAyMi44MzUzQzI5LjA2ODggMjMuNzM2OSAyNy4zNjY0IDI0LjYzODUgMjUuNjU5NyAyNS41NDAxQzI1LjU5MjUgMjUuNTc1MyAyNS41MjEgMjUuNjE2NiAyNS40OTU4IDI1LjY4NDlDMjUuNDY2NCAyNS43NTcyIDI1LjUgMjUuODM1OCAyNS41MjczIDI1LjkwODJDMjUuNzM3NSAyNi40MjUyIDI1Ljk2ODcgMjYuODc1OSAyNi4wOTA2IDI3LjM1MTZDMjYuMjQxOSAyNy45Mzg4IDI2LjE4NTIgMjcuNDY3NCAyNi4yNTg3IDI4LjQ2MkMyNi4yOTAzIDI4Ljg4OCAyNi4xOTk5IDI5LjM3NiAyNS45ODc2IDI5Ljc3NzJDMjUuOTA5OCAyOS45MjE5IDI1LjgzIDMwLjE0OTQgMjUuNjc0NCAzMC4xOTlDMjUuMzczOSAzMC4yOTQxIDI0LjE1MjcgMjguODI4IDIzLjcwNTEgMjguNTQ2OEMyMi43MDQ2IDI3LjkyMDIgMjIuMTA5OCAyNy42MDM4IDIxLjY2NDIgMjcuNzE1NUMyMS42MDk2IDI3LjcyNzkgMjAuNTkwMiAyOC4yOTQ1IDIwLjE1NTEgMjguODU3QzE5Ljg4MTkgMjkuMjEyNiAxOS42MDY2IDI5LjYxMTcgMTkuMzg4IDI5Ljk0NjdDMTguNTc0NiAzMS4xODc1IDE4Ljg3OTMgMzIuNDQ2OCAxOC45ODQ0IDMyLjg3NjlDMTkuMzEwMiAzNC4yMjMxIDIwLjY5OTUgMzQuMjM5NiAyMS44ODQ5IDM0LjIwMDRDMjQuMTU5IDM0LjEyMzggMjYuNTM4MyAzNC4yNTgzIDI4LjUyMjQgMzUuMzU2M0MyOC44ODM5IDM1LjU1NjkgMjkuMjc2OSAzNS45MjA4IDI5LjEzMTkgMzYuMzAxM0MyOS4wNDk5IDM2LjUxMjIgMjguODI5MiAzNi42MzQyIDI4LjYyMTIgMzYuNzI5NEMyNy42ODU5IDM3LjE2MzYgMjYuNjkxNyAzNy40Nzc5IDI1LjY3NDQgMzcuNjU3OEMyNC44ODQyIDM3Ljc5ODUgMjQuMDU4MiAzNy44NjY3IDIzLjM1NDEgMzguMjQ1MUMyMi41ODI3IDM4LjY1ODcgMjIuMDQyNSAzOS40MDczIDIxLjY5NzggNDAuMjAzNEMyMS40MjA0IDQwLjg0NjUgMjAuOTg5NSA0NC4xMzg1IDE5Ljc3NjggNDMuNTUxM0MxOS41NjQ1IDQzLjQ0OTkgMTkuNDE1MyA0My4yNTU2IDE5LjI5MzQgNDMuMDU3MUMxOC43ODI2IDQyLjIyMTYgMTguNjc3NiA0MS4yMzMyIDE4LjI4NjYgNDAuMzUwMkMxNy44NDc0IDM5LjM1NTYgMTcuMDQyNCAzOC44NTcyIDE2LjE3NDMgMzguMjQ3MkMxNC4zOTQxIDM2Ljk5ODIgMTIuODU3NyAzNS4xMTIzIDEyLjMwOTEgMzMuMDA3MkMxMS41NzE0IDMwLjE4MjUgMTEuNzQ3OSAyNi42MzQgMTMuMjUyOCAyNC4wNTc0QzEyLjk1MjMgMjMuNzUxNCAxMi44MDA5IDIzLjcyNjYgMTEuMDk2NCAyMy44NTQ4QzEwLjg0ODQgMjMuODczNCA5LjQ2NTM5IDI0LjIxNDYgOS4zMzkyOCAyMy45OTk1QzkuMjM4NCAyMy44MjU4IDkuMzMyOTggMjMuNDU3OCA5LjQ2MTE5IDIzLjE1NzlDOS41MDMyMyAyMy4wNjI4IDkuNTUzNjYgMjIuOTUzMiA5LjU4NzI5IDIyLjg3NDZDOS43ODY5NiAyMi4zNzAxIDEwLjE4IDIyLjAyMjcgMTAuNjAyNSAyMS42ODM1QzExLjc3NTMgMjAuNzQwNiAxMy4wNDkgMTkuOTUyNyAxNC40ODI0IDE5LjQzOTlDMTQuOTA5IDE5LjI4ODkgMTUuMDk0IDE5LjAyNDIgMTUuMjc0OCAxOC41OTQxQzE2Ljg3NDIgMTQuNzk1NCAyMC40ODkzIDguMzgwOSAyNS4yNjY3IDguMTc4MjVDMjYuMDIzMyA4LjE0MzEgMjYuODI0MSA4LjQ4NjM3IDI3LjU4MDggOC45OTI5OVoiIGZpbGw9IiMxRDI1MkQiLz4KPHBhdGggZD0iTTQyLjcwNyAzMC40Mzk0QzM5LjU0NTggMzIuNTA1MyAzNy43MTMzIDM0LjQ3ODggMzcuNzk4MyAzNS42OTkyQzM3Ljc5NTEgMzUuNjk2IDM3Ljc5NTEgMzUuNjkyNyAzNy43OTUxIDM1LjY4OTVDMzcuNjMxNCAzMi44ODY3IDM2LjAxODEgMzAuNjg3NyAzNC4wNTE0IDMwLjY4NzdDMzMuNTc2OSAzMC42ODc3IDMzLjEyMiAzMC44MTU5IDMyLjcwMzEgMzEuMDQ5NkMzNS43NzI3IDI5LjAzODggMzcuNTc5MSAyNy4xMjA1IDM3LjU4NTYgMjUuODk4NEMzNy43Nzg3IDI4LjY2MjMgMzkuMzgyMiAzMC44MTkxIDQxLjMyOTMgMzAuODE5MUM0MS44MTY5IDMwLjgxOTEgNDIuMjgxNiAzMC42ODQ0IDQyLjcwNyAzMC40Mzk0WiIgZmlsbD0iIzFEMjUyRCIvPgo8ZGVmcz4KPGxpbmVhckdyYWRpZW50IGlkPSJwYWludDBfbGluZWFyXzE0NTkxXzQ2NzMxMCIgeDE9IjIuNzE0MjkiIHkxPSI1MC4wNzE0IiB4Mj0iNDAuMTQyOSIgeTI9IjcuNzE0MjgiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9uVXNlIj4KPHN0b3Agc3RvcC1jb2xvcj0iI0ZGQkUxNyIvPgo8c3RvcCBvZmZzZXQ9IjAuNjQwNjI1IiBzdG9wLWNvbG9yPSIjRkZFMjk3Ii8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz4KPC9zdmc+Cg=="))),
            ctx
        );
        let (token_policy, token_policy_cap) = token::new_policy(&treasury_cap, ctx);
        let registry = TgldRegistry {
            id: object::new(ctx),
            treasury_cap,
            token_policy_cap,
        };
        token::share_policy(token_policy);
        transfer::public_share_object(coin_metadata);
        transfer::share_object(registry);
    }

    /// Mints new `TGLD` tokens and transfers them to a recipient.
    /// This is an authorized function that requires a `ManagerCap`.
    public fun mint(
        _manager_cap: &ManagerCap,
        version: &Version,
        registry: &mut TgldRegistry,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        version.version_check();

        token::confirm_with_policy_cap(
            &registry.token_policy_cap,
            token::transfer(
                token::mint(&mut registry.treasury_cap, amount, ctx),
                recipient,
                ctx,
            ),
            ctx,
        );
        emit(MintEvent {
            recipient,
            log: vector[amount],
            bcs_padding: vector[],
        });
    }

    /// Burns `TGLD` tokens.
    /// This is an authorized function that requires a `ManagerCap`.
    public fun burn(
        _manager_cap: &ManagerCap,
        version: &Version,
        registry: &mut TgldRegistry,
        tgld: Token<TGLD>,
    ) {
        version.version_check();

        emit(BurnEvent {
            log: vector[token::value(&tgld)],
            bcs_padding: vector[],
        });
        token::burn(&mut registry.treasury_cap, tgld);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(TGLD {}, ctx);
    }
}