extends GutTest
# ===========================================================================
# تسک ۵.۶ — DoD: «حضور کد بدون فراخوانی واقعی به هیچ API خارجی» و flag خاموش
# ===========================================================================

const NETWORK_TOKENS := ["HTTPClient", "HTTPRequest", "WebSocketPeer", "TCPServer",
	"UDPServer", "open_websocket", "curl ", "URLSession", "Java.net.URL"]
const SCRIPTS_ROOT := "res://scripts"

## allowlist = «هر جایی که **واقعاً** سوکت باز می‌شود» ⇒ دو مسیرِ دقیق، نه بیشتر ✓ (ADR-064)
## ⚠ نسخةٔ قبلی نامِ فایل را کوچک‌نویسِ اشتباه می‌کرد (فایل واقعی `LiveAIProvider.gd` است) ✗✗
## یعنی exempt هیچ‌وقت نمی‌خورد و فقط «تصادفاً» قرمز نمی‌شد ⇒ قفل‌کردن همین باگ کهنه هم
## بخشی از تسک ۹.۶ است ✓✓ (تستِ جدید، وجودِ فایل‌های exempt را می‌سنجد ✓)
const NETWORK_ALLOW_PATHS: Array[String] = [
	"res://scripts/ai/LiveAIProvider.gd",
	"res://scripts/autoload/NetworkClient.gd",
]


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
		if path in NETWORK_ALLOW_PATHS:
			continue  # تنها دو جای مجاز: placeholder آفلاین + صفِ آفلاین ۹.۶ ✓✓
		var text: String = _strip_comments(_read(path))
		scanned += 1
		for token: String in NETWORK_TOKENS:
			if text.contains(token):
				hits.append("%s → %s" % [path, token])
	assert_gt(scanned, 20, "اسکن باید کل کد بازی را پوشش بدهد")
	assert_true(hits.is_empty(), "کد بازی نباید API شبکه ببیند (جز allowlist): %s" % str(hits))


func test_the_network_allowlist_is_two_real_files() -> void:
	# تستِ خودِ فهرست ✗✓ (قاعدۀ «تستِ دروغگو ممنوع» ADR-060): هر ورودی باید روی دیسک باشد
	# و فهرست دو تا بماند؛ فایل سوم یعنی شکستنِ «آفلاین‌بودنِ MVP» ⇒ با دلیل در ADR ✓
	assert_eq(NETWORK_ALLOW_PATHS.size(), 2, "دو مسیر مجاز، نه بیشتر ✗§۹")
	for path: String in NETWORK_ALLOW_PATHS:
		assert_true(FileAccess.file_exists(path), "«%s» اعلام شده ولی نیست ✗" % path)
	# exempt‌ها باید واقعاً لایهٔ شبکه باشند ✓ (فهرستِ بی‌دلیل = دروغ ✓)
	var net_text := _read("res://scripts/autoload/NetworkClient.gd")
	assert_true(net_text.contains("HTTPRequest"),
			"NetworkClient واقعاً لایهٔ HTTP است (allowlist بی‌مورد نگذاریم ✓)")


## کامنت‌ها حذف می‌شوند: «در کامنت نوشتنِ اسم یک API» جرم نیست، ولی در کد بودنش هست.
func _strip_comments(text: String) -> String:
	var out: Array[String] = []
	for line: String in text.split("\n"):
		var cut: int = line.find("#")
		out.append(line if cut < 0 else line.substr(0, cut))
	return "\n".join(out)


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
