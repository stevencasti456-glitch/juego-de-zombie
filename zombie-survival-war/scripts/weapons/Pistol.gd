extends WeaponBase
class_name Pistol


func _ready() -> void:
	if weapon_data == null:
		weapon_data = load("res://data/weapons/pistol_data.tres")
	super._ready()


func perform_fire() -> void:
	current_ammo -= 1
	ammo_changed.emit(current_ammo, total_ammo)
	
	can_fire = false
	get_tree().create_timer(weapon_data.fire_rate).timeout.connect(func(): can_fire = true)
	
	spawn_muzzle_flash_effect()
	eject_shell()
	play_shoot_sound()
	weapon_fired.emit()
	apply_recoil()
	
	var camera = owner_player.get_node_or_null("CameraPivot/Camera3D")
	if camera == null:
		return
	
	var origin = camera.global_position
	var direction = -camera.global_transform.basis.z.normalized()
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = origin + direction * weapon_data.range
	query.exclude = [owner_player] if owner_player else []
	
	var result = space_state.intersect_ray(query)
	
	if result:
		handle_hit(result)


func handle_hit(result: Dictionary) -> void:
	var collider = result.collider
	var hit_point = result.position
	var hit_normal = result.normal
	
	if weapon_data and weapon_data.impact_effect_scene:
		var effect = weapon_data.impact_effect_scene.instantiate()
		effect.global_position = hit_point
		effect.look_at(hit_point + hit_normal, Vector3.UP)
		get_tree().get_root().add_child(effect)
	
	if collider.has_method("take_damage"):
		collider.take_damage(weapon_data.damage)
	
	if collider is RigidBody3D:
		var force_dir = (hit_point - global_position).normalized()
		collider.apply_central_impulse(force_dir * 5.0)


func apply_recoil() -> void:
	if owner_player and owner_player.has_method("apply_weapon_recoil"):
		owner_player.apply_weapon_recoil(weapon_data.recoil_strength)


func spawn_muzzle_flash_effect() -> void:
	print("DEBUG: Intentando crear fogonazo...")
	
	var flash_scene = load("res://scenes/effects/MuzzleFlash.tscn")
	if flash_scene == null:
		print("DEBUG: ERROR - No se encontro MuzzleFlash.tscn")
		return
	
	print("DEBUG: Escena cargada correctamente")
	
	var flash = flash_scene.instantiate()
	print("DEBUG: Fogonazo instanciado: ", flash != null)
	
	# Posicionar en el punto de salida del arma
	if muzzle_point:
		print("DEBUG: muzzle_point existe en posicion: ", muzzle_point.global_position)
		muzzle_point.add_child(flash)
		flash.global_position = muzzle_point.global_position
		print("DEBUG: Fogonazo posicionado en: ", flash.global_position)
	else:
		print("DEBUG: muzzle_point es null, usando global_position")
		add_child(flash)
	
	# Activar partículas
	var particles = flash.get_node_or_null("FlashParticles")
	if particles:
		particles.emitting = true
		print("DEBUG: Particulas activadas")
	else:
		print("DEBUG: No se encontraron particulas")
	
	# Activar luz
	var light = flash.get_node_or_null("OmniLight3D")
	if light:
		light.visible = true
		print("DEBUG: Luz activada")
	
	# Auto-destruir
	get_tree().create_timer(0.2).timeout.connect(func(): 
		if is_instance_valid(flash): 
			flash.queue_free()
	)

func eject_shell() -> void:
	var shell_scene = load("res://scenes/effects/ShellCasing.tscn")
	if shell_scene == null:
		return
	
	var shell = shell_scene.instantiate()
	
	# Añadir PRIMERO al mundo
	get_tree().get_root().add_child(shell)
	
	# DESPUES posicionar (RigidBody necesita estar en el arbol antes)
	if muzzle_point:
		shell.global_position = muzzle_point.global_position
		shell.global_rotation = muzzle_point.global_rotation
	else:
		shell.global_position = global_position
	
	# Lanzar hacia la derecha y arriba
	var eject_direction = Vector3(
		randf_range(0.5, 1.0),
		randf_range(0.3, 0.8),
		randf_range(-0.2, 0.2)
	).normalized()
	
	shell.apply_central_impulse(eject_direction * randf_range(1.5, 3.0))
	shell.apply_torque_impulse(Vector3(randf(), randf(), randf()) * 0.5)

func play_shoot_sound() -> void:
	var stream = load("res://assets/audio/weapons/shoot.wav")
	if stream == null:
		return
	
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.volume_db = 0.0
	audio_player.bus = "Master"
	
	audio_player.finished.connect(func(): audio_player.queue_free())
	get_tree().get_root().add_child(audio_player)
	
	audio_player.play()
