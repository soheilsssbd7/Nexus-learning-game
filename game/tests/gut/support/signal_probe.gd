extends Node
# ===========================================================================
# SignalProbe — شنونده‌ی ساده برای تست سیگنال‌ها (کمکیِ فاز ۱، نه کد بازی)
# ===========================================================================

var orb_payloads: Array[Dictionary] = []
var balance: Array[Vector2] = []


func _ready() -> void:
	EventBus.orb_placed.connect(_on_orb_placed)
	EventBus.balance_changed.connect(_on_balance_changed)


func _on_orb_placed(orb_data: Dictionary) -> void:
	orb_payloads.append(orb_data)


func _on_balance_changed(left_weight: float, right_weight: float) -> void:
	balance.append(Vector2(left_weight, right_weight))
