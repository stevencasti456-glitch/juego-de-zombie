extends Node3D
class_name WeaponSystem

signal weapon_changed(weapon_name: String)
signal ammo_updated(current: int, magazine: int, total: int, is_reloading: bool)
signal reload_started
signal reload_finished

@export var weapon_holder: Node3D
@export var muzzle_point: Node3D

var current_weapon: WeaponBase = null
var weapons: Array[WeaponBase] = []
var current_index: int = 0

var owner_player: Node3D = null

func _ready() -> void:
	owner_player = get_parent()
	if weapon_holder == null:
		weapon_holder = self
	print("WeaponSystem listo")

func equip_weapon(weapon_scene: PackedScene) -> WeaponBase:
	if current_weapon:
		current_weapon.visible = false
		current_weapon.cancel_reload()
	
	var new_weapon = weapon_scene.instantiate() as WeaponBase
	if new_weapon == null:
		push_error("WeaponSystem: La escena no es un WeaponBase")
		return null
	
	new_weapon.owner_player = owner_player
	new_weapon.muzzle_point = muzzle_point if muzzle_point else weapon_holder
	
	weapon_holder.add_child(new_weapon)
	new_weapon.position = Vector3.ZERO
	new_weapon.rotation = Vector3.ZERO
	
	new_weapon.ammo_changed.connect(_on_ammo_changed)
	new_weapon.weapon_fired.connect(_on_weapon_fired)
	new_weapon.reload_started.connect(_on_reload_started)
	new_weapon.reload_finished.connect(_on_reload_finished)
	
	current_weapon = new_weapon
	weapons.append(new_weapon)
	current_index = weapons.size() - 1
	
	for i in range(weapons.size()):
		weapons[i].visible = (i == current_index)
	
	weapon_changed.emit(new_weapon.weapon_data.weapon_name if new_weapon.weapon_data else "Arma")
	_on_ammo_changed(new_weapon.current_ammo, new_weapon.total_ammo)
	
	print("WeaponSystem: Arma equipada - ", new_weapon.weapon_data.weapon_name if new_weapon.weapon_data else "sin nombre")
	return new_weapon

func fire() -> bool:
	if current_weapon == null:
		return false
	return current_weapon.try_fire()

func reload() -> void:
	if current_weapon == null:
		return
	current_weapon.start_reload()

func _on_ammo_changed(current: int, total: int) -> void:
	if current_weapon and current_weapon.weapon_data:
		ammo_updated.emit(
			current,
			current_weapon.weapon_data.magazine_size,
			total,
			current_weapon.is_reloading
		)

func _on_weapon_fired() -> void:
	pass

func _on_reload_started() -> void:
	reload_started.emit()

func _on_reload_finished() -> void:
	reload_finished.emit()

func get_current_weapon_name() -> String:
	if current_weapon and current_weapon.weapon_data:
		return current_weapon.weapon_data.weapon_name
	return "Sin arma"

func get_ammo_info() -> Dictionary:
	if current_weapon:
		return current_weapon.get_ammo_info()
	return {"current": 0, "magazine": 0, "total": 0, "is_reloading": false}
