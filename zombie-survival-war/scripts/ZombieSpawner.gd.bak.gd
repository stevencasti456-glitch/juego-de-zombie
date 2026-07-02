extends Node

# ============================================================
# ZOMBIE SPAWNER - CREA ZOMBIES EN POSICIONES ALEATORIAS
# ============================================================

@export var zombie_scene_path: String = "res://scenes/Zombie.tscn"  # Ruta a la escena del zombie
@export var spawn_radius: float = 80.0        # Radio donde aparecen los zombies
@export var min_distance_from_player: float = 20.0  # No spawnear cerca del jugador

var player: Node3D = null
var island: Node3D = null                       # Referencia a la isla para altura del terreno

func _ready() -> void:
	# Buscar jugador
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		player = get_tree().get_root().find_child("Player", true, false)
	
	# Buscar isla para altura del terreno
	island = get_tree().get_root().find_child("Island", true, false)
	
	print("ZOMBIE SPAWNER LISTO")

func spawn_zombies(count: int) -> void:
	print("SPAWNEANDO ", count, " ZOMBIES...")
	
	for i in range(count):
		spawn_single_zombie()
		# Pequeña pausa entre spawns para no sobrecargar
		await get_tree().create_timer(0.2).timeout
	
	print("SPAWN COMPLETADO")

func spawn_single_zombie() -> void:
	# Buscar posición válida
	var spawn_pos = find_valid_spawn_position()
	if spawn_pos == Vector3.ZERO:
		push_error("NO SE ENCONTRÓ POSICIÓN VÁLIDA PARA SPAWN")
		return
	
	# Crear zombie
	var zombie = create_zombie_instance()
	if zombie == null:
		return
	
	# Posicionar zombie
	zombie.global_position = spawn_pos
	
	# Agregar a la escena
	get_tree().get_root().add_child(zombie)
	
	print("Zombie spawnado en: ", spawn_pos)

func find_valid_spawn_position() -> Vector3:
	if player == null:
		return Vector3.ZERO
	
	var attempts = 0
	var max_attempts = 20
	
	while attempts < max_attempts:
		attempts += 1
		
		# Posición aleatoria en círculo
		var angle = randf() * PI * 2
		var distance = randf_range(min_distance_from_player, spawn_radius)
		var x = player.global_position.x + cos(angle) * distance
		var z = player.global_position.z + sin(angle) * distance
		
		# Verificar que no esté demasiado cerca del jugador
		var pos = Vector3(x, 0, z)
		var dist_to_player = pos.distance_to(player.global_position)
		
		if dist_to_player >= min_distance_from_player:
			# Obtener altura del terreno
			var y = get_terrain_height(x, z)
			return Vector3(x, y + 1.0, z)  # +1.0 para que no esté enterrado
	
	return Vector3.ZERO

func get_terrain_height(x: float, z: float) -> float:
	# Si tenemos referencia a la isla, usar su función
	if island and island.has_method("get_terrain_height"):
		return island.get_terrain_height(x, z)
	
	# Altura por defecto si no hay isla
	var dist = Vector2(x, z).length()
	var height = 12.0 + (sin(x * 0.05) * cos(z * 0.05) * 6.0) + (sin(x * 0.02) * 10.0)
	if dist > 120.0:
		height -= (dist - 120.0) * 1.5
	return height

func create_zombie_instance() -> Node:
	# Método 1: Instanciar desde escena guardada
	var scene = load(zombie_scene_path)
	if scene:
		return scene.instantiate()
	
	# Método 2: Crear manualmente si no hay escena
	print("No hay escena de zombie, creando manualmente...")
	return create_zombie_manual()

func create_zombie_manual() -> Node:
	# Crear zombie básico manualmente (igual al que tienes en main.tscn)
	var zombie = CharacterBody3D.new()
	zombie.name = "Zombie"
	zombie.add_to_group("Zombie")
	
	# Collision
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 2.0
	collision.shape = shape
	zombie.add_child(collision)
	
	# Mesh
	var mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.radius = 0.4
	cylinder.height = 2.0
	mesh.mesh = cylinder
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.186, 0.392, 0.241)
	mesh.set_surface_override_material(0, mat)
	zombie.add_child(mesh)
	
	# Navigation Agent
	var nav = NavigationAgent3D.new()
	zombie.add_child(nav)
	
	# Script
	var script = load("res://scripts/Zombie.gd")
	if script:
		zombie.set_script(script)
	
	return zombie
