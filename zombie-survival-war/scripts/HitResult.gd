extends RefCounted
class_name HitResult

var damage: int = 0
var hit_position: Vector3 = Vector3.ZERO
var hit_normal: Vector3 = Vector3.ZERO
var hit_direction: Vector3 = Vector3.ZERO
var is_critical: bool = false
var knockback_force: float = 0.0
var weapon_type: int = 0

func _init(p_damage: int = 0, p_position: Vector3 = Vector3.ZERO) -> void:
	damage = p_damage
	hit_position = p_position
