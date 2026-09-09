class_name AriaCore
extends Node2D
# ===========================================================================
# تسک ۵.۴ — هسته‌ی نورانی Aria: تنها بخشی که رنگش بر اساس حالت عوض می‌شود
# (§۳ Art Bible). خودِ رنگ را AnimationPlayer روی `self_modulate` می‌گذارد.
# ===========================================================================

@export var radius: float = 11.0
@export var halo_scale: float = 2.1


func _draw() -> void:
	# هاله + نقطه‌ی مرکزی: دو دایره‌ی هم‌مرکز با آلفای مختلف
	draw_circle(Vector2.ZERO, radius * halo_scale, Color(1.0, 1.0, 1.0, 0.22))
	draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, 0.95))
