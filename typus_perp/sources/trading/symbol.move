/// The `symbol` module defines the `Symbol` struct, which represents a trading pair.
module typus_perp::symbol {
    use std::type_name::{TypeName};

    /// A struct that represents a trading pair.
    public struct Symbol has copy, store, drop {
        /// The base token of the trading pair.
        base_token: TypeName,
        /// The quote token of the trading pair.
        quote_token: TypeName,
    }

    // public(package) fun new<BASE_TOKEN, QUOTE_TOKEN>(): Symbol {
    //     Symbol {
    //         base_token: type_name::with_defining_ids<BASE_TOKEN>(),
    //         quote_token: type_name::with_defining_ids<QUOTE_TOKEN>(),
    //     }
    // }

    /// Creates a new `Symbol` from `TypeName`s.
    public(package) fun create(base_token: TypeName, quote_token: TypeName): Symbol {
        Symbol {
            base_token,
            quote_token
        }
    }

    /// Gets the base token of a `Symbol`.
    public(package) fun base_token(self: &Symbol): TypeName {
        self.base_token
    }

    /// Gets the quote token of a `Symbol`.
    public(package) fun quote_token(self: &Symbol): TypeName {
        self.quote_token
    }
}