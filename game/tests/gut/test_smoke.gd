extends GutTest
# ===========================================================================
# NEXUS — test_smoke.gd
# تسک ۰.۴ (فاز ۰): تأیید اینکه GUT در حالت headless اجرا می‌شود.
# این تست باید همیشه سبز باشد؛ اگر قرمز شد یعنی زیرساخت تست شکسته، نه بازی.
# ===========================================================================


func test_gut_assertions_work() -> void:
	assert_eq(2 + 2, 4, "۲+۲ باید ۴ شود")
	assert_gt(1920, 1080, "سنجه‌ی ساده‌ی بزرگ‌تر")


func test_viewport_is_portrait_mobile_first() -> void:
	var w: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var h: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	assert_eq(w, 1080, "viewport_width باید 1080 باشد (تسک ۰.۲)")
	assert_eq(h, 1920, "viewport_height باید 1920 باشد (تسک ۰.۲)")
	assert_gt(h, w, "نمایش بازی باید عمودی/موبایل‌محور باشد")


func test_mobile_stretch_settings() -> void:
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/mode")), "canvas_items",
		"stretch mode باید canvas_items باشد (تسک ۰.۲)")
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/aspect")), "expand",
		"stretch aspect باید expand باشد (تسک ۰.۲)")
	assert_eq(str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), "mobile",
		"رندرر باید Mobile باشد (تسک ۰.۲)")


func test_required_folder_layout_exists() -> void:
	# ساختار پوشه‌ها باید مطابق docs/01-ARCHITECTURE.md §2 بماند.
	var required: PackedStringArray = [
		"res://scenes/main",
		"res://scenes/gameplay",
		"res://scenes/characters",
		"res://scenes/ui",
		"res://scripts/autoload",
		"res://scripts/gameplay",
		"res://scripts/ai",
		"res://scripts/data",
		"res://data/levels",
		"res://data/dialogue",
		"res://data/narrative",
		"res://assets/fonts",
	]
	for p: String in required:
		assert_true(DirAccess.dir_exists_absolute(p), "پوشه‌ی لازم موجود نیست: " + p)
