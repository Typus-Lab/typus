
#[test_only]
module typus::test_event {
    use sui::test_scenario;
    use sui::vec_map;

    use typus::event;

    #[test]
    fun test_emit_event() {
        let scenario = test_scenario::begin(@0xABCD);
        event::emit_event(
            b"test".to_string(),
            vec_map::empty(),
            vec_map::empty(),
        );
        let effects = test_scenario::end(scenario);
        assert!(test_scenario::num_user_events(&effects) == 1, 0);
    }
}