extends Node
class_name PlayerAnimator

# Referencias
var player: CharacterBody3D = null
var character_model: Node3D = null
var weapon_mesh: Node3D = null  # <-- CAMBIADO: MeshInstance3D -> Node3D

# Estado
var current_animation: String = "idle"
var is_shooting: bool = false
var is_reloading: bool = false

func _init(p_player: CharacterBody3D) -> void:
	player = p_player

func setup() -> void:
	# Buscar el modelo del personaje
	character_model = player.get_node_or_null("CharacterModel")
	if character_model:
		weapon_mesh = character_model.get_node_or_null("VisualWeapon")
		print("PlayerAnimator: Modelo encontrado, weapon_mesh=", weapon_mesh != null)

func play_animation(anim_name: String) -> void:
	if current_animation == anim_name:
		return
	
	current_animation = anim_name
	
	match anim_name:
		"idle":
			play_idle()
		"walk":
			play_walk()
		"run":
			play_run()
		"shoot":
			play_shoot()
		"reload":
			play_reload()

func play_idle() -> void:
	if weapon_mesh:
		var tween = player.create_tween()
		tween.tween_property(weapon_mesh, "rotation", Vector3(0, -0.2, 0), 0.3)
		tween.tween_property(weapon_mesh, "position", Vector3(0.3, 1.3, 0.3), 0.3)

func play_walk() -> void:
	if weapon_mesh:
		var tween = player.create_tween()
		tween.tween_property(weapon_mesh, "rotation", Vector3(0, -0.2, 0), 0.3)
		tween.tween_property(weapon_mesh, "position", Vector3(0.3, 1.25, 0.3), 0.3)

func play_run() -> void:
	if weapon_mesh:
		var tween = player.create_tween()
		tween.tween_property(weapon_mesh, "rotation", Vector3(0, -0.2, 0), 0.2)
		tween.tween_property(weapon_mesh, "position", Vector3(0.3, 1.35, 0.25), 0.2)

func play_shoot() -> void:
	if weapon_mesh and not is_shooting:
		is_shooting = true
		
		var original_pos = weapon_mesh.position
		var recoil_pos = original_pos + Vector3(0, 0.05, -0.15)
		
		var tween = player.create_tween()
		tween.set_trans(Tween.TRANS_QUINT)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(weapon_mesh, "position", recoil_pos, 0.03)
		tween.tween_property(weapon_mesh, "position", original_pos, 0.15)
		
		await tween.finished
		is_shooting = false

func play_reload() -> void:
	if weapon_mesh and not is_reloading:
		is_reloading = true
		
		var original_pos = weapon_mesh.position
		var down_pos = original_pos + Vector3(0, -0.3, 0)
		
		var tween = player.create_tween()
		tween.tween_property(weapon_mesh, "position", down_pos, 0.3)
		tween.tween_property(weapon_mesh, "position", original_pos, 0.3)
		
		await tween.finished
		is_reloading = false

func update_animation(velocity: Vector3, is_crouching: bool) -> void:
	if is_reloading or is_shooting:
		return
	
	var speed = Vector2(velocity.x, velocity.z).length()
	
	if speed < 0.1:
		play_animation("idle")
	elif speed < 3.0:
		play_animation("walk")
	else:
		play_animation("run")
