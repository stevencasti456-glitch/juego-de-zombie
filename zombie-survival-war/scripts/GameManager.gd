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

# --- Spawn Inteligente ---
var biome_manager: Node = null
var poi_manager: Node = null
var spawn_zombies_outside_waves: bool = true  # Zombies extra por exploracion
var ambient_zombie_timer: float = 0.0
var ambient_zombie_interval: float = 8.0  # Cada 8 segundos un zombie ambiental

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

	# Buscar managers para spawn inteligente
	biome_manager = get_tree().get_root().find_child("BiomeManager", true, false)
	poi_manager = get_tree().get_root().find_child("POIManager", true, false)
	
	if biome_manager:
		print("Spawn Inteligente: BiomeManager conectado")
	if poi_manager:
		print("Spawn Inteligente: POIManager conectado")

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
	# Spawn ambiental de zombies segun exploracion
	if spawn_zombies_outside_waves:
		handle_ambient_zombies(delta)
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
	# Ajustar cantidad de zombies segun bioma del jugador
	if biome_manager and player:
		var biome = biome_manager.get_biome_at_position(player.global_position)
		var weights = biome_manager.get_spawn_weights(biome)
		var zombie_mult = weights.get("zombies", 1.0)
		
		var adjusted_count = int(zombie_count * zombie_mult)
		if adjusted_count != zombie_count:
			print("Spawn Inteligente: Oleada ajustada de ", zombie_count, " a ", adjusted_count, " (bioma: ", biome, ")")
			total_zombies_in_wave = adjusted_count
			zombies_alive = adjusted_count
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
	var max_attempts = 30

	while attempts < max_attempts:
		attempts += 1

		# Posicion base: aleatoria en circulo alrededor del jugador
		var angle = randf() * PI * 2
		var base_distance = randf_range(20.0, 80.0)
		
		# Ajustar distancia segun bioma
		var distance = base_distance
		if biome_manager:
			var biome = biome_manager.get_biome_at_position(player.global_position)
			match biome:
				0:  # FOREST - Bosque: zombies mas cerca (peligroso)
					distance = randf_range(15.0, 50.0)
				1:  # ROCKY - Rocoso: zombies mas lejos (espacios abiertos)
					distance = randf_range(30.0, 80.0)
				2:  # PRAIRIE - Pradera: distancia normal
					distance = randf_range(20.0, 60.0)
				3:  # BEACH - Playa: zombies lejos (zona segura)
					distance = randf_range(40.0, 90.0)
		
		var x = player.global_position.x + cos(angle) * distance
		var z = player.global_position.z + sin(angle) * distance

		var pos = Vector3(x, 0, z)
		var dist_to_player = pos.distance_to(player.global_position)

		# Verificar distancia minima
		if dist_to_player < 15.0:
			continue
		
		# Verificar que no este demasiado cerca de un POI (zona segura temporal)
		if poi_manager and poi_manager.active_pois:
			for poi in poi_manager.active_pois:
				var poi_type = poi.get_meta("poi_type", -1)
				var dist_to_poi = pos.distance_to(poi.global_position)
				
				# Algunos POIs atraen zombies (campamento), otros los alejan
				match poi_type:
					3:  # CAMPSITE - Campamento: mas zombies cerca
						if dist_to_poi < 15.0:
							# Aceptar esta posicion (zona de riesgo)
							pass
					4:  # WATCHTOWER - Torre: menos zombies cerca
						if dist_to_poi < 12.0:
							continue  # Zona segura, no spawnear
					1:  # GAS_STATION - Gasolinera: normal
						pass
					_:
						if dist_to_poi < 8.0:
							continue  # No spawnear encima de POIs

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

# ============================================================
# SPAWN AMBIENTAL INTELIGENTE
# Zombies extra que aparecen mientras exploras
# ============================================================
func handle_ambient_zombies(delta: float) -> void:
	if not is_wave_active:
		return  # Solo durante oleadas activas
	
	ambient_zombie_timer += delta
	if ambient_zombie_timer < ambient_zombie_interval:
		return
	
	ambient_zombie_timer = 0.0
	
	# Calcular probabilidad de spawn ambiental segun bioma
	var spawn_chance = 0.3  # 30% base
	var max_ambient = 2     # Max 2 zombies ambientales por intervalo
	
	if biome_manager and player:
		var biome = biome_manager.get_biome_at_position(player.global_position)
		match biome:
			0:  # FOREST - Bosque: mas spawn ambiental
				spawn_chance = 0.6
				max_ambient = 3
			1:  # ROCKY - Rocoso: menos spawn
				spawn_chance = 0.2
				max_ambient = 1
			2:  # PRAIRIE - Pradera: normal
				spawn_chance = 0.4
				max_ambient = 2
			3:  # BEACH - Playa: muy poco spawn
				spawn_chance = 0.1
				max_ambient = 1
	
	# Verificar POIs cercanos para multiplicador adicional
	var poi_multiplier = 1.0
	if poi_manager and poi_manager.active_pois:
		for poi in poi_manager.active_pois:
			var dist = poi.global_position.distance_to(player.global_position)
			if dist < 25.0:
				var poi_type = poi.get_meta("poi_type", -1)
				var poi_zombie_mult = poi.get_meta("zombie_multiplier", 1.0)
				if poi_zombie_mult > 1.0:
					poi_multiplier = max(poi_multiplier, poi_zombie_mult)
					print("Spawn Inteligente: Cerca de ", poi.get_meta("poi_name", "POI"), 
						  " | Multiplicador: ", poi_zombie_mult)
	
	# Aplicar multiplicador de POI
	spawn_chance *= poi_multiplier
	max_ambient = int(max_ambient * poi_multiplier)
	
	# Spawnear zombies ambientales
	if randf() < spawn_chance:
		var count = randi_range(1, max_ambient)
		print("Spawn Inteligente: ", count, " zombie(s) ambiental(es) en ", 
			  biome_manager.get_biome_name(player.global_position) if biome_manager else "desconocido")
		
		for _i in range(count):
			spawn_single_zombie()
			await get_tree().create_timer(0.3).timeout
