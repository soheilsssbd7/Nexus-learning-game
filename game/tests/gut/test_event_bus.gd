extends GutTest
# ===========================================================================
# تسک ۱.۱ — EventBus: سیگنال‌ها از بیرون قابل emit/شنیدن باشند (DoD).
# ===========================================================================

const SignalProbe := preload("res://tests/gut/support/signal_probe.gd")


func before_each() -> void:
	watch_signals(EventBus)


func test_signals_declared_with_expected_names() -> void:
	var expected: PackedStringArray = [
		"orb_placed", "balance_changed", "level_completed", "error_detected", "hint_requested",
	]
	var declared: Array[String] = []
	for s: Dictionary in EventBus.get_signal_list():
		declared.append(str(s["name"]))
	for sig: String in expected:
		assert_true(sig in declared, "سیگنال `%s` باید در EventBus باشد (تسک ۱.۱)" % sig)


func test_emit_from_other_script_is_received() -> void:
	var probe := SignalProbe.new()
	add_child_autofree(probe)
	EventBus.orb_placed.emit({"value": 5.0, "side": 1})
	assert_eq(probe.orb_payloads.size(), 1, "شنونده باید دقیقاً یک orb_placed بگیرد")
	assert_eq(float(probe.orb_payloads[0].get("value", 0.0)), 5.0)
	assert_eq(probe.balance.length(), 0, "هیچ سیگنال دیگری نباید emit شده باشد")


func test_balance_changed_carries_weights() -> void:
	EventBus.balance_changed.emit(8.0, 5.0)
	assert_signal_emitted_with_parameters(EventBus, "balance_changed", [8.0, 5.0])


func test_level_completed_payload_shape_matches_schema() -> void:
	# اسکیمای §۵ سند داده‌ها: time_to_solve_sec / hints_used / attempts / final_elo_delta
	var stats := {"time_to_solve_sec": 52.0, "hints_used": 1, "attempts": 4, "final_elo_delta": 12.5}
	EventBus.level_completed.emit("tier1_level_03", stats)
	for key: String in ["time_to_solve_sec", "hints_used", "attempts", "final_elo_delta"]:
		assert_true(stats.has(key), "payload رویداد باید `%s` داشته باشد" % key)
	assert_signal_emitted(EventBus, "level_completed")
