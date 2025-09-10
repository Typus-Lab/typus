module typus::event {
    use std::string::String;

    use sui::event::emit;
    use sui::vec_map::VecMap;

    public struct Event has copy, drop {
        action: String,
        log: VecMap<String, u64>,
        bcs_padding: VecMap<String, vector<u8>>,
    }

    public fun emit_event(
        action: String,
        log: VecMap<String, u64>,
        bcs_padding: VecMap<String, vector<u8>>,
    ) {
        emit(Event {
            action,
            log,
            bcs_padding,
        });
    }
}