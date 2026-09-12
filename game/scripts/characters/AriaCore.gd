class_name AriaCore
extends Node2D
# ===========================================================================
# NEXUS — AriaCore (§۳ Art Bible | تسک ۵.۴ → بازطراحیِ ۸.۱)
# --------------------------------------------------------------------------
# هسته = تنها بخشی که رنگش با حالت عوض می‌شود ✓ و رنگ را **کد** تعیین می‌کند
# (`AriaAvatar.core_color_for`)؛ این شیدر فقط جنسِ نور (نرمی + نفس) را می‌سازد ✓
# fallback حلقه‌ای عمداً مانده ✗✓: اگر `aria_core.gdshader` به هر دلیلی load نشود
# (ریپوی بریده، export با فیلترِ اشتباه ✗) بازی نباید بی‌هسته بماند ✓ — ولی
# `Log.error` می‌زند تا در لاگِ CI پیدا شود، نه بی‌صدا ✓ (قاعدهٔ فاز ۷: سبزِ بی‌صدا نه).
# ===========================================================================

const TAG := "AriaCore"
const SHADER_PATH := "res://assets/shaders/aria_core.gdshader"

@export var radius: float = 11.0:
	set(v):
		radius = maxf(2.0, v)
		_apply_uniforms()
		queue_redraw()
@export var halo_scale: float = 2.1:
	set(v):
		halo_scale = clampf(v, 1.2, 4.0)
		_apply_uniforms()
		queue_redraw()
## اگر شیدر هست، استفاده کن؛ اگر نه، حلقه‌ها ✓ (تستِ ۸.۱ هر دو مسیر را می‌بیند)
@export var use_shader: bool = true

var _material: ShaderMaterial = null
var _using_shader := false


func _ready() -> void:
	_build_material()


func is_using_shader() -> bool:
	return _using_shader


func _build_material() -> void:
	_using_shader = false
	if not use_shader:
		material = null
		return
	if not ResourceLoader.exists(SHADER_PATH):
		Log.error(TAG, "شیدرِ هسته نیست (%s) ⇒ به حلقه‌های ساده برگشتیم ✗" % SHADER_PATH)
		material = null
		return
	var shader: Shader = ResourceLoader.load(SHADER_PATH) as Shader
	if shader == null:
		Log.error(TAG, "شیدرِ هسته load نشد ⇒ حلقه‌ها ✗")
		material = null
		return
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material
	_using_shader = true
	_apply_uniforms()


## یونیفورمِ شعاع باید هم‌زمان با `radius` بماند ✗✓ وگرنه گرادیانِ نور با هندسه
## می‌رود (یک باگِ کلاسیکِ شیدرهای «اندازه‌ازروی-کد» ✓✓ و در هدلس دیده نمی‌شود ⇒ تست می‌گیردش)
func _apply_uniforms() -> void:
	if _material != null:
		_material.set_shader_parameter("radius", radius)
		_material.set_shader_parameter("halo_ratio", halo_scale)


func _draw() -> void:
	if _using_shader:
		# هندسه‌ی دیسک؛ شیدر خودش «نور» را از روی فاصله می‌سازد ✓ (یک draw call ✓)
		draw_circle(Vector2.ZERO, radius * halo_scale, Color(1.0, 1.0, 1.0, 0.95))
		return
	# مسیرِ fallback: همان دو دایره‌ی فاز ۵ (نیمه‌شفاف + مغزِ سفید) ✓
	draw_circle(Vector2.ZERO, radius * halo_scale, Color(1.0, 1.0, 1.0, 0.22))
	draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, 0.95))
