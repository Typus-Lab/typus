module typus_perp::symbol {
    use std::type_name::{TypeName};

    public struct Symbol has copy, store, drop {
        base_token: TypeName,
        quote_token: TypeName,
    }

    // public(package) fun new<BASE_TOKEN, QUOTE_TOKEN>(): Symbol {
    //     Symbol {
    //         base_token: type_name::with_defining_ids<BASE_TOKEN>(),
    //         quote_token: type_name::with_defining_ids<QUOTE_TOKEN>(),
    //     }
    // }

    public(package) fun create(base_token: TypeName, quote_token: TypeName): Symbol {
        Symbol {
            base_token,
            quote_token
        }
    }

    public(package) fun base_token(self: &Symbol): TypeName {
        self.base_token
    }

    public(package) fun quote_token(self: &Symbol): TypeName {
        self.quote_token
    }
}