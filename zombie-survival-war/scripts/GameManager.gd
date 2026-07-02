extends Node

# ============================================================
# GAME MANAGER - Controlador Único del Juego
# ============================================================

# --- Contadores ---
var zombies_killed: int = 0
var total_coins: int = 0
var current_wave: int = 0

# --- Configuración de Oleadas ---
@export var time_between_waves: float = 5.0
@export var zombies_first_wave: int = 3
@export var wave_increment: int = 2

# --- Variables internas ---
var zombies_alive: int = 0
var total_zombies_in_wave: int = 0
var is_wave_active: bool = false
var wave_timer: float = 0.0
var is_spawning: bool = false

# --- Referencias ---
var player: Node3D = null
var island: Node3D = null

# --- Señales ---
signal zombie_killed(count: int)
signal coins_changed(amount: int)
signal wave_started(wave_number: int, zombie_count: int)
signal wave_completed(wave_number: int)

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	# Añadir al grupo para que otros scripts puedan encontrarnos
	add_to_group("GameManager")

	print("========================================")
	print("GAME MANAGER INICIADO")
	print("========================================")

	# Buscar referencias
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		player = get_tree().get_root().find_child("Player", true, false)

	island = get_tree().get_root().find_child("Island", true, false)

	# Iniciar primera oleada después de 3 segundos
	await get_tree().create_timer(3.0).timeout
	start_next_wave()

# ============================================================
# PROCESS - Control de oleadas
# ============================================================
func _process(delta: float) -> void:
	# Si no hay oleada activa, esperar para la siguiente
	if not is_wave_active:
		wave_timer += delta
		if wave_timer >= time_between_waves:
			start_next_wave()
		return

	# Verificar si todos los zombies murieron
	# (solo si ya terminamos de spawner y no quedan vivos)
	if not is_spawning and zombies_alive <= 0 and total_zombies_in_wave > 0:
		wave_finished()

# ============================================================
# INICIAR OLEADA
# ============================================================
func start_next_wave() -> void:
	current_wave += 1
	var zombie_count = zombies_first_wave + ((current_wave - 1) * wave_increment)

	print("========================================")
	print("OLEADA ", current_wave, " INICIADA")
	print("Zombies a spawnear: ", zombie_count)
	print("========================================")

	# Configurar oleada
	total_zombies_in_wave = zombie_count
	zombies_alive = zombie_count
	is_wave_active = true
	wave_timer = 0.0
	is_spawning = true

	# Spawnear zombies
	await spawn_zombies(zombie_count)

	is_spawning = false

	wave_started.emit(current_wave, zombie_count)

# ============================================================
# OLEADA COMPLETADA
# ============================================================
func wave_finished() -> void:
	is_wave_active = false
	wave_timer = 0.0

	print("========================================")
	print("OLEADA ", current_wave, " COMPLETADA")
	print("Siguiente oleada en ", time_between_waves, " segundos")
	print("========================================")

	wave_completed.emit(current_wave)

# ============================================================
# ZOMBIE MUERE
# ============================================================
func zombie_died() -> void:
	zombies_alive -= 1
	if zombies_alive < 0:
		zombies_alive = 0

	print("Zombie muerto | Restantes: ", zombies_alive, "/", total_zombies_in_wave)

	zombies_killed += 1
	zombie_killed.emit(zombies_killed)

# ============================================================
# MONEDAS
# ============================================================
func add_coins(amount: int) -> void:
	total_coins += amount
	print("MONEDAS: +", amount, " | Total: ", total_coins)
	coins_changed.emit(total_coins)

func get_total_coins() -> int:
	return total_coins

# ============================================================
# GETTERS
# ============================================================
func get_zombies_killed() -> int:
	return zombies_killed

func get_current_wave() -> int:
	return current_wave

func get_zombies_alive() -> int:
	return zombies_alive

# ============================================================
# SPAWNER DE ZOMBIES
# ============================================================
func spawn_zombies(count: int) -> void:
	print("SPAWNEANDO ", count, " ZOMBIES...")

	for i in range(count):
		spawn_single_zombie()
		# Pequeña pausa entre spawns para no sobrecargar
		await get_tree().create_timer(0.3).timeout

	print("SPAWN COMPLETADO")

func spawn_single_zombie() -> void:
	var spawn_pos = find_valid_spawn_position()
	if spawn_pos == Vector3.ZERO:
		push_error("NO SE ENCONTRÓ POSICIÓN VÁLIDA")
		return

	var zombie = create_zombie()
	if zombie == null:
		return

	zombie.global_position = spawn_pos
	print("Zombie spawnado en: ", spawn_pos)

func create_zombie() -> Node:
	# Intentar cargar desde escena primero
	var scene = load("res://scenes/Zombie.tscn")
	if scene:
		var zombie = scene.instantiate()
		if zombie:
			get_tree().get_root().add_child(zombie)
			zombie.add_to_group("Zombie")
			return zombie

	# Si no hay escena, crear manualmente
	print("No hay escena Zombie.tscn, creando manualmente...")
	return create_zombie_manual()

func create_zombie_manual() -> Node:
	var script = load("res://scripts/Zombie.gd")
	if script == null:
		push_error("NO SE PUDO CARGAR Zombie.gd")
		return null

	var zombie = script.new()
	zombie.name = "Zombie"

	# Collision
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 2.0
	collision.shape = shape
	zombie.add_child(collision)

	# Mesh
	var mesh = MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.4
	cylinder.bottom_radius = 0.4
	cylinder.height = 2.0
	mesh.mesh = cylinder
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.186, 0.392, 0.241)
	mesh.set_surface_override_material(0, mat)
	zombie.add_child(mesh)

	# Navigation Agent
	var nav = NavigationAgent3D.new()
	nav.name = "NavigationAgent3D"
	zombie.add_child(nav)

	# Agregar al árbol
	get_tree().get_root().add_child(zombie)
	zombie.add_to_group("Zombie")

	return zombie

# ============================================================
# POSICIÓN DE SPAWN
# ============================================================
func find_valid_spawn_position() -> Vector3:
	if player == null:
		return Vector3.ZERO

	var attempts = 0
	var max_attempts = 20

	while attempts < max_attempts:
		attempts += 1

		# Posición aleatoria en círculo alrededor del jugador
		var angle = randf() * PI * 2
		var distance = randf_range(20.0, 80.0)
		var x = player.global_position.x + cos(angle) * distance
		var z = player.global_position.z + sin(angle) * distance

		var pos = Vector3(x, 0, z)
		var dist_to_player = pos.distance_to(player.global_position)

		if dist_to_player >= 15.0:
			var y = get_terrain_height(x, z)
			return Vector3(x, y + 1.0, z)

	return Vector3.ZERO

func get_terrain_height(x: float, z: float) -> float:
	if island and island.has_method("get_terrain_height"):
		return island.get_terrain_height(x, z)

	# Altura por defecto
	var dist = Vector2(x, z).length()
	var height = 12.0 + (sin(x * 0.05) * cos(z * 0.05) * 6.0) + (sin(x * 0.02) * 10.0)
	if dist > 120.0:
		height -= (dist - 120.0) * 1.5
	return height
