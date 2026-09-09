extends GutTest
# ===========================================================================
# تسک ۶.۳ — Loc: همه‌ی رشته‌های UI از یک فایل، و «چندزبانه» یعنی واقعی چندزبانه
# ---------------------------------------------------------------------------
# سه چیز را می‌سنجد: (۱) فایل پارس می‌شود و هیچ کلیدی در هیچ locale کم نیست،
# (۲) رشته‌ی گمشده = خودِ کلید، نه crash و نه رشته‌ی خالی (بچه‌ها صفحه‌ی خالی نمی‌بینند)،
# (۳) جهت/ارقام از *داده* می‌آیند، پس افزودن زبان جدید کد را دست نمی‌زند.
# ===========================================================================


func before_each() -> void:
	Loc.reset_for_tests()
	Loc.load_file()


func after_each() -> void:
	Loc.set_locale(Loc.default_locale())


func test_the_string_table_loads() -> void:
	assert_true(Loc.load_file(), "فایل رشته‌ها باید خوانده شود")
	assert_eq(Loc.default_locale(), "fa", "پیش‌فرض §۷ سند هنری: فارسی")
	assert_gt(Loc.strings().size(), 40, "فاز ۶ کل منو/پاز/تنظیمات/داشبورد را پوشش می‌دهد")


func test_every_locale_has_the_same_keys() -> void:
	var missing: Dictionary = Loc.missing_keys()
	assert_true(missing.is_empty(), "کلیدهای جاافتاده: " + str(missing))


func test_no_empty_or_overlong_string() -> void:
	var offenders: Array[String] = []
	for code: Variant in Loc.available_locales():
		var table: Dictionary = Loc.strings(str(code))
		for key: Variant in table.keys():
			var value: String = str(table[key])
			if value.is_empty():
				offenders.append("%s/%s خالی است" % [code, key])
			elif value.length() > 80:
				offenders.append("%s/%s بلندتر از ۸۰ نویسه (§۷: بدون دیوار متن)" % [code, key])
	assert_true(offenders.is_empty(), "\n".join(offenders))


func test_missing_key_shows_the_key_itself() -> void:
	assert_eq(Loc.t("this.key.does.not.exist"), "this.key.does.not.exist",
		"رشته‌ی گمشده باید لو برود، نه اینکه صفحه خالی/کرش شود")


func test_locale_switch_is_data_driven() -> void:
	assert_true(Loc.is_rtl("fa"), "fa راست‌به‌چپ است")
	assert_false(Loc.is_rtl("en"), "en چپ‌به‌راست است")
	assert_eq(Loc.text_direction(), Control.TEXT_DIRECTION_RTL)
	assert_true(Loc.set_locale("en"), "en در فایل تعریف شده")
	assert_eq(Loc.text_direction(), Control.TEXT_DIRECTION_LTR,
		"جهت از خودِ locale می‌آید، نه از hardcode صحنه")
	assert_false(Loc.set_locale("de"), "زبان تعریف‌نشده رد می‌شود (نه کرش، نه English ناخواسته)")
	assert_eq(Loc.locale(), "en", "تنظیم ناموفق نباید locale را عوض کند")


func test_digits_are_persian_in_rtl_and_untouched_in_ltr() -> void:
	assert_eq(Loc.digits("12/30"), "۱۲/۳۰")
	assert_true(Loc.percent(0.224).contains("۲۲"), Loc.percent(0.224))
	Loc.set_locale("en")
	assert_eq(Loc.digits("12/30"), "12/30", "در زبان چپ‌به‌راست ارقام لاتین می‌مانند")


func test_durations_are_readable_not_raw_seconds() -> void:
	var fa: String = Loc.duration_sec(3720.0)
	assert_true(fa.contains("۱") and fa.contains(Loc.t("dashboard.hour")), fa)
	var short: String = Loc.duration_sec(35.0)
	assert_true(short.contains("۳۵"), short)
	assert_true(Loc.duration_sec(-9.0).contains("۰"), "زمان منفی نباید عدد عجیب بدهد")
