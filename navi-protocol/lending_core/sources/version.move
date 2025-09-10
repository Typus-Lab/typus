module lending_core::version {
    public fun next_version() : u64 {
        lending_core::constants::version() + 1
    }

    public fun pre_check_version(arg0: u64) {
        assert!(arg0 == lending_core::constants::version(), lending_core::error::incorrect_version());
    }

    public fun this_version() : u64 {
        lending_core::constants::version()
    }

    // decompiled from Move bytecode v6
}

