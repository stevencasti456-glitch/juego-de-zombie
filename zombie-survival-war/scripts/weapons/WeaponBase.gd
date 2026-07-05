extends Node3D
class_name WeaponBase

signal weapon_fired
signal weapon_reloaded
signal ammo_changed(current: int, total: int)
signal out_of_ammo
signal reload_started
signal reload_finished

@export var weapon_data: WeaponData

var current_ammo: int = 0
var total_ammo: int = 0
var can_fire: bool = true
var is_reloading: bool = false

var owner_player: Node3D = null
var muzzle_point: Node3D = null

func _ready() -> void:
	if weapon_data:
		current_ammo = weapon_data.magazine_size
		total_ammo = weapon_data.max_ammo
		ammo_changed.emit(current_ammo, total_ammo)

func try_fire() -> bool:
	# ¿Está recargando?
	if is_reloading:
		return false
	
	# ¿Sin balas en cargador?
	if current_ammo <= 0:
		play_empty_sound()
		
		# Recarga automática si está configurada y hay munición
		if weapon_data and weapon_data.auto_reload and total_ammo > 0:
			print("Auto-recargando...")
			start_reload()
		else:
			out_of_ammo.emit()
		
		return false
	
	# ¿En cooldown?
	if not can_fire:
		return false
	
	# ¡DISPARAR!
	perform_fire()
	return true

func perform_fire() -> void:
	push_error("perform_fire() debe ser sobrescrito en la subclase")

	# Verificar si quedan pocas balas
	if current_ammo == 0 and total_ammo > 0:
		print("Cargador vacio. Quedan ", total_ammo, " balas en inventario.")
	elif current_ammo == 0 and total_ammo == 0:
		print("SIN MUNICION. Busca mas balas.")

func start_reload() -> void:
	# ¿Ya está recargando?
	if is_reloading:
		return
	
	# ¿Cargador lleno?
	if current_ammo == weapon_data.magazine_size:
		return
	
	# ¿Sin munición total en inventario?
	if total_ammo <= 0:
		out_of_ammo.emit()
		play_empty_sound()
		return
	
	is_reloading = true
	can_fire = false
	reload_started.emit()
	play_reload_sound()
	
	# Timer de recarga
	await get_tree().create_timer(weapon_data.reload_time).timeout
	
	# Si se canceló la recarga, no hacer nada
	if not is_reloading:
		return
	
	# Calcular cuántas balas faltan en el cargador
	var needed = weapon_data.magazine_size - current_ammo
	var available = min(needed, total_ammo)
	
	current_ammo += available
	total_ammo -= available
	
	is_reloading = false
	can_fire = true
	
	ammo_changed.emit(current_ammo, total_ammo)
	reload_finished.emit()
	weapon_reloaded.emit()
	
	print("Recarga completa: ", current_ammo, "/", weapon_data.magazine_size, " | Inventario: ", total_ammo)

func cancel_reload() -> void:
	if is_reloading:
		is_reloading = false
		can_fire = true

func play_shoot_sound() -> void:
	if weapon_data and weapon_data.shoot_sound:
		var player = AudioStreamPlayer3D.new()
		player.stream = weapon_data.shoot_sound
		player.finished.connect(func(): player.queue_free())
		add_child(player)
		player.play()

func play_reload_sound() -> void:
	var stream = load("res://assets/audio/player/reload.wav")
	if stream == null:
		print("DEBUG: No se encontro reload.wav")
		return
	
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.volume_db = 0.0
	
	audio_player.finished.connect(func(): audio_player.queue_free())
	get_tree().get_root().add_child(audio_player)
	
	audio_player.play()
	print("DEBUG: Sonido de recarga reproducido")

func play_empty_sound() -> void:
	if weapon_data and weapon_data.empty_sound:
		var player = AudioStreamPlayer3D.new()
		player.stream = weapon_data.empty_sound
		player.finished.connect(func(): player.queue_free())
		add_child(player)
		player.play()

func spawn_muzzle_flash() -> void:
	if weapon_data and weapon_data.muzzle_flash_scene and muzzle_point:
		var flash = weapon_data.muzzle_flash_scene.instantiate()
		muzzle_point.add_child(flash)
		flash.global_position = muzzle_point.global_position
		await get_tree().create_timer(0.05).timeout
		if is_instance_valid(flash):
			flash.queue_free()

func spawn_shell_eject() -> void:
	if weapon_data and weapon_data.shell_eject_scene and muzzle_point:
		var shell = weapon_data.shell_eject_scene.instantiate()
		shell.global_position = muzzle_point.global_position + Vector3(0.1, 0, 0)
		get_tree().get_root().add_child(shell)

func get_raycast_direction() -> Vector3:
	var base_dir = -global_transform.basis.z
	if weapon_data and weapon_data.accuracy < 1.0:
		var spread = (1.0 - weapon_data.accuracy) * 0.1
		base_dir += Vector3(
			randf_range(-spread, spread),
			randf_range(-spread, spread),
			randf_range(-spread, spread)
		)
		base_dir = base_dir.normalized()
	return base_dir

func get_muzzle_origin() -> Vector3:
	if muzzle_point:
		return muzzle_point.global_position
	return global_position + Vector3(0, 1.5, 0)

func get_ammo_info() -> Dictionary:
	return {
		"current": current_ammo,
		"magazine": weapon_data.magazine_size if weapon_data else 0,
		"total": total_ammo,
		"is_reloading": is_reloading
	}
