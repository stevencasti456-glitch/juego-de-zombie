extends CharacterBody3D

# ============================================================
# CONFIGURACION
# ============================================================
@export var SPEED: float = 3.5
@export var DAMAGE: int = 15
@export var ROTATION_SPEED: float = 8.0
@export var DETECTION_RANGE: float = 15.0
@export var ATTACK_RANGE: float = 1.8
@export var ATTACK_COOLDOWN: float = 1.5

@export var max_health: int = 50
var current_health: int = 50

var idle_sound_timer: float = 0.0
var idle_sound_interval: float = 5.0  # Gemir cada 5 segundos
var is_dead: bool = false
var animator: ZombieAnimator = null

# Patrulla
var is_patrolling: bool = false
var patrol_target: Vector3 = Vector3.ZERO
var patrol_timer: float = 0.0
var patrol_wait_time: float = 0.0
var patrol_speed: float = 1.5

# ============================================================
# REFERENCIAS
# ============================================================
var nav_agent: NavigationAgent3D
var mesh_instance: Node3D
var player: CharacterBody3D = null

# ============================================================
# VARIABLES DE ESTADO
# ============================================================
var path_update_time: float = 0.0
var path_update_interval: float = 0.5
var attack_timer: float = 0.0
var can_attack: bool = true
var is_attacking: bool = false
var original_color: Color = Color(0.186, 0.392, 0.241)

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	nav_agent = get_node_or_null("NavigationAgent3D")
	
	# ← NUEVO: Crear modelo detallado del zombie
	create_zombie_model()
	
	# ← NUEVO: mesh_instance ahora apunta al contenedor del modelo
	mesh_instance = get_node_or_null("ZombieModel")

	# Ajustar posición de la colisión para que toque el suelo
	var collision = get_node_or_null("CollisionShape3D")
	if collision:
		collision.position = Vector3(0, 1.0, 0)

	await get_tree().create_timer(0.5).timeout

	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		player = get_tree().get_root().find_child("Player", true, false)

	if player != null and is_instance_valid(player):
		print("ZOMBIE: Jugador encontrado")
	else:
		push_error("ZOMBIE: No se encontro el jugador")
		return

	current_health = max_health
	# Iniciar patrulla
	start_patrol()

	if nav_agent:
		nav_agent.path_desired_distance = 1.5
		nav_agent.target_desired_distance = ATTACK_RANGE
		nav_agent.avoidance_enabled = false

	# ← NUEVO: Guardar color original del torso (parte principal)
	if mesh_instance:
		var torso = mesh_instance.get_node_or_null("Torso")
		if torso and torso.get_surface_override_material(0):
			original_color = torso.get_surface_override_material(0).albedo_color

# Inicializar animador
	animator = ZombieAnimator.new(self)
	animator.setup()

# ============================================================
# NUMERO DE DANO FLOTANTE
# ============================================================
func show_damage_number(amount: int) -> void:
	var damage_label = Label3D.new()
	damage_label.text = "-" + str(amount)
	damage_label.font_size = 128
	damage_label.modulate = Color(1, 0, 0, 1)
	damage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	damage_label.position = Vector3(0, 2.0, 0)
	damage_label.outline_size = 8
	damage_label.outline_modulate = Color(0, 0, 0, 1)
	add_child(damage_label)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", 3.5, 1.0)
	tween.tween_property(damage_label, "modulate:a", 0.0, 1.0)
	tween.tween_property(damage_label, "font_size", 64, 1.0)

	await tween.finished
	damage_label.queue_free()

# ============================================================
# FISICA
# ============================================================
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 15.0 * delta

	# Si no hay jugador, patrullar de todos modos
	if player == null or not is_instance_valid(player):
		patrol(delta)
		move_and_slide()
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player > DETECTION_RANGE:
		# Jugador lejos: patrullar
		patrol(delta)
		
	elif distance_to_player <= ATTACK_RANGE:
		# Jugador cerca: atacar
		is_patrolling = false
		look_at_player()
		if can_attack:
			perform_attack()
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	else:
		# Jugador en rango: perseguir
		is_patrolling = false
		chase_player(delta)

	update_attack_cooldown(delta)
	move_and_slide()

# Sonidos de zombie
	handle_zombie_sounds(delta)

# ============================================================
# PERSECUCION
# ============================================================
func chase_player(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	path_update_time += delta
	if path_update_time >= path_update_interval:
		if nav_agent:
			nav_agent.target_position = player.global_position
			path_update_time = 0.0

	var direction: Vector3

	if nav_agent and not nav_agent.is_navigation_finished():
		var next_pos = nav_agent.get_next_path_position()
		direction = (next_pos - global_position).normalized()
		if direction.length() < 0.1:
			direction = (player.global_position - global_position).normalized()
			direction.y = 0
	else:
		direction = (player.global_position - global_position).normalized()
		direction.y = 0

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	rotate_towards_direction(direction, delta)

# ============================================================
# ATAQUE
# ============================================================
func perform_attack() -> void:
	if player == null or not is_instance_valid(player):
		return

	is_attacking = true
	can_attack = false
	attack_timer = 0.0

	if player.has_method("take_damage"):
		player.take_damage(DAMAGE)
		print("ZOMBIE ATACA! Dano: ", DAMAGE)

	set_color(Color(1.0, 0.2, 0.2))
	await get_tree().create_timer(0.2).timeout
	set_color(original_color)
	is_attacking = false

 # Sonido de ataque
	play_zombie_attack_sound()

# ============================================================
# RECIBIR DANO
# ============================================================
func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health < 0:
		current_health = 0

	print("Zombie herido! Dano: -", amount, " | Vida: ", current_health, "/", max_health)

	show_damage_number(amount)
	
	# Retroceso al recibir daño
	apply_damage_knockback()
	
	# Destello rojo intenso
	flash_damage_effect()

	if current_health <= 0:
		die()

# ============================================================
# MUERTE
# ============================================================
func die() -> void:
	print("ZOMBIE MUERE")
	set_physics_process(false)
	
	if nav_agent:
		nav_agent.avoidance_enabled = false
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("zombie_died"):
		gm.zombie_died()
		print("Game Manager notificado")
	else:
		push_warning("No se pudo notificar al GameManager")
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.5)
	
	# ← CORREGIDO: Aplicar transparencia a TODAS las partes del modelo
	if mesh_instance:
		for child in mesh_instance.get_children():
			if child is MeshInstance3D and child.get_surface_override_material(0):
				var mat = child.get_surface_override_material(0)
				tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	
	await tween.finished
	
	create_blood_particles()
	spawn_coin()
	queue_free()

# ============================================================
# PARTICULAS DE SANGRE
# ============================================================
func create_blood_particles() -> void:
	var particles = GPUParticles3D.new()
	particles.name = "BloodParticles"
	particles.position = global_position
	get_tree().get_root().add_child(particles)

	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.5
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 90.0
	particle_material.initial_velocity_min = 2.0
	particle_material.initial_velocity_max = 5.0
	particle_material.gravity = Vector3(0, -9.8, 0)
	particle_material.color = Color(0.8, 0.1, 0.1, 1.0)
	particle_material.scale_min = 0.1
	particle_material.scale_max = 0.3

	particles.process_material = particle_material

	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_mesh.height = 0.1
	particles.draw_pass_1 = particle_mesh

	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true

	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

# ============================================================
# SPAWN DE MONEDAS (5-7 monedas, valor 5-15 cada una)
# ============================================================
func spawn_coin() -> void:
	# No hay escena Coin.tscn, usar siempre fallback por código
	var coin_count = randi_range(5, 7)
	
	for i in range(coin_count):
		var coin = create_coin_manual()
		
		if coin == null:
			continue
			
		get_tree().get_root().add_child(coin)
		
		# Calcular posición en el suelo
		var angle = (float(i) / float(coin_count)) * TAU + randf_range(-0.3, 0.3)
		var distance = randf_range(0.8, 2.5)
		var pos_x = global_position.x + cos(angle) * distance
		var pos_z = global_position.z + sin(angle) * distance
		
		var terrain_y = get_terrain_height_at(pos_x, pos_z)
		coin.global_position = Vector3(pos_x, terrain_y + 0.5, pos_z)
		
		# Valor aleatorio entre 5 y 15 Núcleos
		var value = randi_range(5, 15)
		if coin.has_method("set_value"):
			coin.set_value(value)

func create_coin_manual() -> Area3D:
	# Crear moneda básica si no hay escena
	var coin = Area3D.new()
	coin.name = "Coin"
	
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.4
	collision.shape = shape
	coin.add_child(collision)
	
	# Script
	var script = load("res://scripts/Coin.gd")
	if script:
		coin.set_script(script)
	
	return coin

func animate_coin_fall(coin: Node) -> void:
	# Obtener altura real del terreno en esa posición
	var terrain_y = get_terrain_height_at(coin.global_position.x, coin.global_position.z)
	var end_y = terrain_y + 0.4  # Un poco sobre el suelo, fácil de recoger
	
	# Animar caída
	var tween = create_tween()
	tween.tween_property(coin, "global_position:y", end_y, 0.5 + randf() * 0.3)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	
	await tween.finished
	
	# Pequeño rebote final
	if is_instance_valid(coin):
		var bounce = create_tween()
		bounce.tween_property(coin, "global_position:y", end_y + 0.1, 0.1)
		bounce.tween_property(coin, "global_position:y", end_y, 0.15)

func get_terrain_height_at(x: float, z: float) -> float:
	# Intentar obtener del Island
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.island and gm.island.has_method("get_terrain_height"):
		return gm.island.get_terrain_height(x, z)
	
	# Fallback: fórmula del terreno
	var dist = Vector2(x, z).length()
	var height = 12.0 + (sin(x * 0.05) * cos(z * 0.05) * 6.0) + (sin(x * 0.02) * 10.0)
	if dist > 120.0:
		height -= (dist - 120.0) * 1.5
	return height

# ============================================================
# UTILIDADES
# ============================================================
func update_attack_cooldown(delta: float) -> void:
	if not can_attack:
		attack_timer += delta
		if attack_timer >= ATTACK_COOLDOWN:
			can_attack = true
			attack_timer = 0.0

func look_at_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	var direction = (player.global_position - global_position).normalized()
	direction.y = 0
	if direction.length() > 0.001:
		rotation.y = atan2(direction.x, direction.z)  # ← Quitado el signo negativo de -direction.x

func rotate_towards_direction(direction: Vector3, delta: float) -> void:
	var target_dir = Vector2(direction.x, direction.z)
	if target_dir.length_squared() > 0.001:
		var target_angle = atan2(direction.x, direction.z)
		
		# Velocidad de giro según estado:
		# - Patrullando: lento (distraído)
		# - Persiguiendo: rápido (alerta)
		var current_rot_speed = ROTATION_SPEED
		if is_patrolling:
			current_rot_speed = ROTATION_SPEED * 0.4  # 40% de velocidad al girar
		
		rotation.y = rotate_toward(rotation.y, target_angle, current_rot_speed * delta)

func set_color(new_color: Color) -> void:
	if mesh_instance == null:
		return
	
	# ← NUEVO: Cambiar color de todas las partes del cuerpo (excepto ojos)
	var parts_to_color = ["Head", "LeftArm", "RightArm"]
	for part_name in parts_to_color:
		var part = mesh_instance.get_node_or_null(part_name)
		if part and part.get_surface_override_material(0):
			part.get_surface_override_material(0).albedo_color = new_color
	
	# El torso tiene su propio color (camisa), no lo cambiamos
	# Los ojos mantienen su brillo rojo

# ============================================================
# CREAR MODELO DETALLADO DEL ZOMBIE (FASE 2.6)
# ============================================================
func create_zombie_model() -> void:
	# Verificar si ya existe
	if has_node("ZombieModel"):
		return
	
	# Contenedor principal
	var model = Node3D.new()
	model.name = "ZombieModel"
	add_child(model)
	
	# --- MATERIALES ---
	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.45, 0.55, 0.38)
	skin_mat.roughness = 0.9
	
	var shirt_mat = StandardMaterial3D.new()
	shirt_mat.albedo_color = Color(0.25, 0.12, 0.08)
	shirt_mat.roughness = 0.95
	
	var pants_mat = StandardMaterial3D.new()
	pants_mat.albedo_color = Color(0.12, 0.12, 0.15)
	pants_mat.roughness = 0.9
	
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.9, 0.05, 0.05)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.9, 0.05, 0.05)
	eye_mat.emission_energy = 2.0
	
	var blood_mat = StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.4, 0.02, 0.02)
	blood_mat.roughness = 1.0
	
	var dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.2, 0.15, 0.1)
	dirt_mat.roughness = 1.0
	
	# --- CABEZA ---
	var head = MeshInstance3D.new()
	head.name = "Head"
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.set_surface_override_material(0, skin_mat)
	head.position = Vector3(0, 1.6, 0)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(head)
	
	# --- OJO IZQUIERDO ---
	var eye_left = MeshInstance3D.new()
	eye_left.name = "EyeLeft"
	var eye_mesh = SphereMesh.new()
	eye_mesh.radius = 0.06
	eye_mesh.height = 0.12
	eye_left.mesh = eye_mesh
	eye_left.set_surface_override_material(0, eye_mat)
	eye_left.position = Vector3(-0.08, 1.65, 0.18)
	eye_left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(eye_left)
	
	# --- OJO DERECHO ---
	var eye_right = MeshInstance3D.new()
	eye_right.name = "EyeRight"
	eye_right.mesh = eye_mesh.duplicate()
	eye_right.set_surface_override_material(0, eye_mat.duplicate())
	eye_right.position = Vector3(0.08, 1.65, 0.18)
	eye_right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(eye_right)
	
	# --- TORSO (encorvado) ---
	var torso = MeshInstance3D.new()
	torso.name = "Torso"
	var torso_mesh = CapsuleMesh.new()
	torso_mesh.radius = 0.28
	torso_mesh.height = 0.7
	torso.mesh = torso_mesh
	torso.set_surface_override_material(0, shirt_mat)
	torso.position = Vector3(0, 0.95, 0)
	torso.rotation.x = 0.25  # Encorvado hacia adelante
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(torso)
	
	# --- BRAZO IZQUIERDO ---
	var arm_mesh = CylinderMesh.new()
	arm_mesh.top_radius = 0.07
	arm_mesh.bottom_radius = 0.06
	arm_mesh.height = 0.75
	
	var left_arm = MeshInstance3D.new()
	left_arm.name = "LeftArm"
	left_arm.mesh = arm_mesh
	left_arm.set_surface_override_material(0, skin_mat.duplicate())
	left_arm.position = Vector3(-0.38, 1.0, 0.1)
	left_arm.rotation.z = 0.15
	left_arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(left_arm)
	
	# --- BRAZO DERECHO ---
	var right_arm = MeshInstance3D.new()
	right_arm.name = "RightArm"
	right_arm.mesh = arm_mesh.duplicate()
	right_arm.set_surface_override_material(0, skin_mat.duplicate())
	right_arm.position = Vector3(0.38, 1.0, 0.1)
	right_arm.rotation.z = -0.15
	right_arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(right_arm)
	
	# --- PIERNA IZQUIERDA ---
	var leg_mesh = CylinderMesh.new()
	leg_mesh.top_radius = 0.11
	leg_mesh.bottom_radius = 0.09
	leg_mesh.height = 0.85
	
	var left_leg = MeshInstance3D.new()
	left_leg.name = "LeftLeg"
	left_leg.mesh = leg_mesh
	left_leg.set_surface_override_material(0, pants_mat.duplicate())
	left_leg.position = Vector3(-0.14, 0.42, 0)
	left_leg.rotation.x = 0.05
	left_leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(left_leg)
	
	# --- PIERNA DERECHA ---
	var right_leg = MeshInstance3D.new()
	right_leg.name = "RightLeg"
	right_leg.mesh = leg_mesh.duplicate()
	right_leg.set_surface_override_material(0, pants_mat.duplicate())
	right_leg.position = Vector3(0.14, 0.42, 0)
	right_leg.rotation.x = -0.05
	right_leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(right_leg)
	
	# --- MANCHA DE SANGRE ---
	var blood = MeshInstance3D.new()
	blood.name = "BloodStain"
	var blood_mesh = SphereMesh.new()
	blood_mesh.radius = 0.15
	blood_mesh.height = 0.3
	blood.mesh = blood_mesh
	blood.set_surface_override_material(0, blood_mat)
	blood.position = Vector3(0.1, 1.05, 0.25)
	blood.scale = Vector3(0.15, 0.1, 0.12)
	blood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(blood)
	
	# --- MANCHA DE SUCIEDAD ---
	var dirt = MeshInstance3D.new()
	dirt.name = "DirtStain"
	var dirt_mesh = SphereMesh.new()
	dirt_mesh.radius = 0.18
	dirt_mesh.height = 0.36
	dirt.mesh = dirt_mesh
	dirt.set_surface_override_material(0, dirt_mat)
	dirt.position = Vector3(-0.15, 0.35, 0.2)
	dirt.scale = Vector3(0.18, 0.12, 0.15)
	dirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.add_child(dirt)

# ============================================================
# PATRULLA
# ============================================================
func start_patrol() -> void:
	is_patrolling = true
	pick_new_patrol_target()

func pick_new_patrol_target() -> void:
	var angle = randf() * TAU
	var distance = randf_range(5.0, 15.0)
	var target_x = global_position.x + cos(angle) * distance
	var target_z = global_position.z + sin(angle) * distance
	
	var terrain_y = get_terrain_height(target_x, target_z)
	patrol_target = Vector3(target_x, terrain_y + 1.0, target_z)
	patrol_wait_time = randf_range(1.0, 4.0)
	patrol_timer = 0.0

func get_terrain_height(x: float, z: float) -> float:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.island and gm.island.has_method("get_terrain_height"):
		return gm.island.get_terrain_height(x, z)
	
	var dist = Vector2(x, z).length()
	var height = 12.0 + (sin(x * 0.05) * cos(z * 0.05) * 6.0) + (sin(x * 0.02) * 10.0)
	if dist > 120.0:
		height -= (dist - 120.0) * 1.5
	return height

func patrol(delta: float) -> void:
	if not is_patrolling:
		start_patrol()
		return
	
	var dist_to_target = global_position.distance_to(patrol_target)
	if dist_to_target < 2.0:
		# Llegó al destino, esperar
		patrol_timer += delta
		velocity.x = move_toward(velocity.x, 0, patrol_speed)
		velocity.z = move_toward(velocity.z, 0, patrol_speed)
		
		if patrol_timer >= patrol_wait_time:
			pick_new_patrol_target()
		return
	
	# Moverse hacia el punto de patrulla
	var direction = (patrol_target - global_position).normalized()
	direction.y = 0
	
	velocity.x = direction.x * patrol_speed
	velocity.z = direction.z * patrol_speed
	
	rotate_towards_direction(direction, delta)

# ============================================================
# RETROCESO AL RECIBIR DAÑO
# ============================================================
func apply_damage_knockback() -> void:
	if player == null or not is_instance_valid(player):
		return
	
	# Empujar al zombie ligeramente hacia atrás del jugador
	var knockback_dir = (global_position - player.global_position).normalized()
	knockback_dir.y = 0
	
	# Aplicar velocidad de retroceso
	velocity.x = knockback_dir.x * 3.0
	velocity.z = knockback_dir.z * 3.0

# ============================================================
# DESTELLO DE DAÑO MEJORADO
# ============================================================
func flash_damage_effect() -> void:
	if mesh_instance == null:
		return
	
	# Guardar colores originales
	var original_colors = {}
	var parts_to_flash = ["Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]
	
	for part_name in parts_to_flash:
		var part = mesh_instance.get_node_or_null(part_name)
		if part and part.get_surface_override_material(0):
			var mat = part.get_surface_override_material(0)
			original_colors[part_name] = mat.albedo_color
			# Destello rojo brillante
			mat.albedo_color = Color(1.0, 0.1, 0.1)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.0, 0.0)
			mat.emission_energy = 1.5
	
	# Crear partículas de sangre al recibir daño
	spawn_blood_splash()
	
	# Restaurar colores después de 0.15 segundos
	await get_tree().create_timer(0.15).timeout
	
	for part_name in parts_to_flash:
		var part = mesh_instance.get_node_or_null(part_name)
		if part and part.get_surface_override_material(0):
			var mat = part.get_surface_override_material(0)
			if part_name in original_colors:
				mat.albedo_color = original_colors[part_name]
			mat.emission_enabled = false

# ============================================================
# PARTÍCULAS DE SANGRE AL RECIBIR DAÑO
# ============================================================
func spawn_blood_splash() -> void:
	# Verificar que el zombie sigue en el árbol
	if not is_inside_tree():
		return
	
	var particles = GPUParticles3D.new()
	particles.name = "BloodSplash"
	get_tree().get_root().add_child(particles)
	particles.global_position = global_position + Vector3(0, 1.0, 0)
	
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.3
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 60.0
	particle_material.initial_velocity_min = 1.0
	particle_material.initial_velocity_max = 4.0
	particle_material.gravity = Vector3(0, -9.8, 0)
	particle_material.color = Color(0.7, 0.05, 0.05, 1.0)
	particle_material.scale_min = 0.05
	particle_material.scale_max = 0.15
	
	particles.process_material = particle_material
	
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.03
	particle_mesh.height = 0.06
	particles.draw_pass_1 = particle_mesh
	
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.emitting = true
	
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func handle_zombie_sounds(delta: float) -> void:
	if is_dead:
		return
	
	# Sonido idle (gimiendo ocasionalmente)
	idle_sound_timer += delta
	if idle_sound_timer >= idle_sound_interval:
		idle_sound_timer = 0.0
		idle_sound_interval = randf_range(4.0, 8.0)  # Aleatorio entre 4-8 seg
		play_zombie_idle_sound()

func play_zombie_idle_sound() -> void:
	var stream = load("res://assets/audio/zombies/zombie_idle.ogg")
	if stream == null:
		return
	
	var audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = stream
	audio_player.volume_db = -8.0
	audio_player.unit_size = 10.0
	audio_player.max_distance = 30.0
	
	audio_player.finished.connect(func(): audio_player.queue_free())
	add_child(audio_player)
	
	audio_player.play()

func play_zombie_attack_sound() -> void:
	var stream = load("res://assets/audio/zombies/zombie_attack.wav")
	if stream == null:
		return
	
	var audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = stream
	audio_player.volume_db = -5.0
	
	audio_player.finished.connect(func(): audio_player.queue_free())
	add_child(audio_player)
	
	audio_player.play()
