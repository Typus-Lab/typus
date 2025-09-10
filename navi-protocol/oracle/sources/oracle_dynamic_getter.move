module oracle::oracle_dynamic_getter {
    public fun get_dynamic_single_price(arg0: &0x2::clock::Clock, arg1: &oracle::config::OracleConfig, arg2: &oracle::oracle::PriceOracle, arg3: &0x5d8fbbf6f908a4af8c6d072669a462d53e03eb3c1d863bd0359dc818c69ea706::SupraSValueFeed::OracleHolder, arg4: &0x8d97f1cd6ac663735be08d1d2b6d02a159e711586461306ce60a2b7a6a565a9e::price_info::PriceInfoObject, arg5: address) : (u64, u256) {
        oracle::config::version_verification(arg1);
        if (oracle::config::is_paused(arg1)) {
            return (oracle::oracle_error::paused(), 0)
        };
        let v0 = oracle::config::get_price_feed(arg1, arg5);
        if (!oracle::config::is_price_feed_enable(v0)) {
            return (oracle::oracle_error::price_feed_not_found(), 0)
        };
        let v1 = 0x2::clock::timestamp_ms(arg0);
        let v2 = oracle::config::get_max_timestamp_diff_from_feed(v0);
        let v3 = oracle::oracle::safe_decimal(arg2, oracle::config::get_oracle_id_from_feed(v0));
        if (oracle::oracle_provider::is_empty(oracle::config::get_primary_oracle_provider(v0))) {
            return (oracle::oracle_error::invalid_oracle_provider(), 0)
        };
        let v4 = oracle::config::get_primary_oracle_provider_config(v0);
        if (!oracle::oracle_provider::is_oracle_provider_config_enable(v4)) {
            return (oracle::oracle_error::oracle_provider_disabled(), 0)
        };
        let (v5, v6) = oracle::oracle_pro::get_price_from_adaptor(v4, v3, arg3, arg4);
        let v7 = oracle::strategy::is_oracle_price_fresh(v1, v6, v2);
        let mut v8 = false;
        let mut v9 = 0;
        if (oracle::config::is_secondary_oracle_available(v0)) {
            let (v10, v11) = oracle::oracle_pro::get_price_from_adaptor(oracle::config::get_secondary_source_config(v0), v3, arg3, arg4);
            v9 = v10;
            v8 = oracle::strategy::is_oracle_price_fresh(v1, v11, v2);
        };
        let mut v12 = v5;
        if (v7 && v8) {
            let v13 = oracle::strategy::validate_price_difference(v5, v9, oracle::config::get_price_diff_threshold1_from_feed(v0), oracle::config::get_price_diff_threshold2_from_feed(v0), v1, oracle::config::get_max_duration_within_thresholds_from_feed(v0), oracle::config::get_diff_threshold2_timer_from_feed(v0));
            if (v13 != oracle::oracle_constants::level_normal()) {
                if (v13 != oracle::oracle_constants::level_warning()) {
                    return (oracle::oracle_error::invalid_price_diff(), 0)
                };
            };
        } else {
            if (v7) {
            } else {
                if (v8) {
                    v12 = v9;
                } else {
                    return (oracle::oracle_error::no_available_price(), 0)
                };
            };
        };
        let (v14, v15) = oracle::config::get_history_price_data_from_feed(v0);
        if (!oracle::strategy::validate_price_range_and_history(v12, oracle::config::get_maximum_effective_price_from_feed(v0), oracle::config::get_minimum_effective_price_from_feed(v0), oracle::config::get_maximum_allowed_span_percentage_from_feed(v0), v1, oracle::config::get_historical_price_ttl(v0), v14, v15)) {
            return (oracle::oracle_error::invalid_final_price(), 0)
        };
        (oracle::oracle_constants::success(), v12)
    }

    // decompiled from Move bytecode v6
}

