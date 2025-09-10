module oracle::oracle_version {
    public fun next_version() : u64 {
        oracle::oracle_constants::version() + 1
    }

    public fun pre_check_version(arg0: u64) {
        assert!(arg0 == oracle::oracle_constants::version(), oracle::oracle_error::incorrect_version());
    }

    public fun this_version() : u64 {
        oracle::oracle_constants::version()
    }

    // decompiled from Move bytecode v6
}

