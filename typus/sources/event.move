/// This module provides a standardized way to emit events in the Typus ecosystem.
/// It defines a generic `Event` struct and a helper function to emit events with a consistent format.
module typus::event {
    use std::string::String;

    use sui::event::emit;
    use sui::vec_map::VecMap;

    /// A generic event structure for logging actions and data in the Typus ecosystem.
    public struct TypusEvent has copy, drop {
        /// A string that describes the action being performed.
        action: String,
        /// A map for logging key-value pairs of `u64` data.
        log: VecMap<String, u64>,
        /// A map for logging key-value pairs of BCS-encoded data.
        bcs_padding: VecMap<String, vector<u8>>,
    }

    /// Emits a generic `Event`.
    /// This function is used throughout the Typus ecosystem to log events in a standardized format.
    public(package) fun emit_typus_event(
        action: String,
        log: VecMap<String, u64>,
        bcs_padding: VecMap<String, vector<u8>>,
    ) {
        emit(TypusEvent {
            action,
            log,
            bcs_padding,
        });
    }

    #[deprecated]
    public struct Event has copy, drop {
        action: String,
        log: VecMap<String, u64>,
        bcs_padding: VecMap<String, vector<u8>>,
    }
    #[deprecated, allow(unused)]
    public fun emit_event(
        action: String,
        log: VecMap<String, u64>,
        bcs_padding: VecMap<String, vector<u8>>,
    ) { abort 0 }
}