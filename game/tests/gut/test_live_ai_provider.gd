extends GutTest
# ===========================================================================
# تسک ۵.۶ — DoD: «حضور کد بدون فراخوانی واقعی به هیچ API خارجی» و flag خاموش
# ===========================================================================

const NETWORK_TOKENS := ["HTTPClient", "HTTPRequest", "WebSocketPeer", "TCPServer",
	"UDPServer", "open_websocket", "curl ", "URLSession", "Java.net.URL"]
const SCRIPTS_ROOT := "res://scripts"


func test_the_flag_is_off_in_this_build() -> void:
	assert_false(FeatureFlags.LIVE_AI_ENABLED, "master باید آفلاین باشد (docs/01 §۵)")
	assert_false(LiveAIProvider.is_available())


func test_the_stub_returns_an_empty_string_for_any_context() -> void:
	var provider := LiveAIProvider.new()
	assert_eq(provider.get_dynamic_response({}), "")
	assert_eq(provider.get_dynamic_response({"level_id": "tier1_level_01",
		"error_type": "wrong_operation"}), "", "تهی یعنی «قالب آفلاین را نگه دار»")


func test_no_game_script_mentions_a_network_api() -> void:
	var scanned: int = 0
	var hits: Array[String] = []
	for path: String in _gd_files(SCRIPTS_ROOT):
		if path.ends_with("live_ai_provider.gd"):
			continue  # خودِ placeholder تنها جایی است که این واژه‌ها مجازند
		var text: String = _read(path)
		scanned += 1
		for token: String in NETWORK_TOKENS:
			if text.contains(token):
				hits.append("%s → %s" % [path, token])
	assert_gt(scanned, 20, "اسکن باید کل کد بازی را پوشش بدهد")
	assert_true(hits.is_empty(), "کد بازی نباید هیچ API شبکه‌ای را ببیند: %s" % str(hits))


func _gd_files(root_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = root_path.path_join(name)
		if dir.current_is_dir():
			out.append_array(_gd_files(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text
