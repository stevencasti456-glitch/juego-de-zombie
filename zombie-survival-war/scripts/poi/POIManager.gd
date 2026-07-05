extends Node

# ============================================================
# POI MANAGER - Controla los Puntos de Interes
# ============================================================

# Tipos de POI
enum POIType {
	ABANDONED_HOUSE,   # Casa abandonada
	GAS_STATION,       # Gasolinera
	MEDICAL_POST,      # Puesto medico
	CAMPSITE,          # Campamento
	WATCHTOWER,        # Torre de vigilancia
	CABIN              # Cabana
}

# Configuracion de cada tipo de POI
var poi_configs: Dictionary = {
	POIType.ABANDONED_HOUSE: {
		"name": "Casa Abandonada",
		"description": "Una casa vieja y deteriorada",
		"loot_type": "medkit",      # Botiquines
		"loot_chance": 0.7,          # 70% probabilidad
		"loot_amount": 1,
		"zombie_multiplier": 1.2,    # 20% mas zombies
		"color": Color(0.4, 0.3, 0.2)  # Marron viejo
	},
	POIType.GAS_STATION: {
		"name": "Gasolinera",
		"description": "Una estacion de servicio abandonada",
		"loot_type": "ammo",           # Municion
		"loot_chance": 0.8,
		"loot_amount": 2,
		"zombie_multiplier": 1.0,
		"color": Color(0.6, 0.2, 0.1)  # Rojo oxidado
	},
	POIType.MEDICAL_POST: {
		"name": "Puesto Medico",
		"description": "Un pequeno puesto de primeros auxilios",
		"loot_type": "medkit",
		"loot_chance": 0.9,
		"loot_amount": 2,
		"zombie_multiplier": 0.8,
		"color": Color(0.9, 0.9, 0.95)  # Blanco medico
	},
	POIType.CAMPSITE: {
		"name": "Campamento",
		"description": "Un campamento de supervivientes",
		"loot_type": "weapon",         # Armas futuras
		"loot_chance": 0.5,
		"loot_amount": 1,
		"zombie_multiplier": 1.5,     # Muchos zombies
		"color": Color(0.3, 0.25, 0.15)  # Marron tienda
	},
	POIType.WATCHTOWER: {
		"name": "Torre de Vigilancia",
		"description": "Una torre alta para vigilar la zona",
		"loot_type": "ammo",
		"loot_chance": 0.6,
		"loot_amount": 1,
		"zombie_multiplier": 0.5,      # Pocos zombies
		"color": Color(0.35, 0.3, 0.25)  # Metal oxidado
	},
	POIType.CABIN: {
		"name": "Cabana",
		"description": "Una pequena cabana en el bosque",
		"loot_type": "mixed",          # Mix de loot
		"loot_chance": 0.6,
		"loot_amount": 2,
		"zombie_multiplier": 1.0,
		"color": Color(0.3, 0.2, 0.1)   # Madera oscura
	}
}

# Referencias
var island: Node3D = null
var poi_container: Node3D = null

# Lista de POIs activos
var active_pois: Array = []

# Señal cuando el jugador entra a un POI
signal player_entered_poi(poi_name: String, poi_type: int)

func _ready() -> void:
	print("POIManager iniciado")
	print("POIs disponibles: Casa Abandonada, Gasolinera, Puesto Medico, Campamento, Torre, Cabana")
	
	# Crear contenedor para todos los POIs
	poi_container = Node3D.new()
	poi_container.name = "POIContainer"
	add_child(poi_container)
	
	# Buscar la isla
	island = get_tree().get_root().find_child("Island", true, false)
	
	# Generar POIs
	await get_tree().create_timer(0.5).timeout
	generate_all_pois()

# ============================================================
# GENERAR TODOS LOS POIS
# ============================================================
func generate_all_pois() -> void:
	print("Generando POIs...")
	
	# Generar un POI de cada tipo en posiciones aleatorias
	var poi_types = [POIType.ABANDONED_HOUSE, POIType.GAS_STATION, 
		POIType.MEDICAL_POST, POIType.CAMPSITE, 
		POIType.WATCHTOWER, POIType.CABIN]
	
	for poi_type in poi_types:
		var pos = find_valid_poi_position()
		if pos != Vector3.ZERO:
			create_poi(poi_type, pos)
			await get_tree().create_timer(0.1).timeout
	
	print("POIs generados: ", active_pois.size())

# ============================================================
# ENCONTRAR POSICION VALIDA PARA POI
# ============================================================
func find_valid_poi_position() -> Vector3:
	var max_attempts = 30
	
	for _i in range(max_attempts):
		var angle = randf() * PI * 2
		var distance = randf_range(30.0, 100.0)
		var x = cos(angle) * distance
		var z = sin(angle) * distance
		
		# Verificar que no este muy cerca de otro POI
		var too_close = false
		for poi in active_pois:
			if poi.global_position.distance_to(Vector3(x, 0, z)) < 25.0:
				too_close = true
				break
		
		if not too_close:
			var y = get_terrain_height(x, z)
			return Vector3(x, y, z)
	
	return Vector3.ZERO

# ============================================================
# OBTENER ALTURA DEL TERRENO
# ============================================================
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
# CREAR UN POI
# ============================================================
func create_poi(poi_type: int, pos: Vector3) -> void:
	var config = poi_configs[poi_type]
	var poi_name = config["name"]
	
	print("Creando POI: ", poi_name, " en ", pos)
	
	var poi_root = Node3D.new()
	poi_root.name = poi_name.replace(" ", "_")
	poi_root.position = pos
	
	# Guardar datos del POI
	poi_root.set_meta("poi_type", poi_type)
	poi_root.set_meta("poi_name", poi_name)
	poi_root.set_meta("loot_type", config["loot_type"])
	poi_root.set_meta("loot_chance", config["loot_chance"])
	poi_root.set_meta("loot_amount", config["loot_amount"])
	poi_root.set_meta("zombie_multiplier", config["zombie_multiplier"])
	
	# Construir la estructura segun el tipo
	match poi_type:
		POIType.ABANDONED_HOUSE:
			build_abandoned_house(poi_root, config)
		POIType.GAS_STATION:
			build_gas_station(poi_root, config)
		POIType.MEDICAL_POST:
			build_medical_post(poi_root, config)
		POIType.CAMPSITE:
			build_campsite(poi_root, config)
		POIType.WATCHTOWER:
			build_watchtower(poi_root, config)
		POIType.CABIN:
			build_cabin(poi_root, config)
	
		# Agregar area de deteccion para el jugador (radio de influencia del POI)
	var area = Area3D.new()
	area.name = "DetectionArea"
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 25.0  # Radio de influencia del POI
	collision.shape = sphere
	area.add_child(collision)
	area.body_entered.connect(_on_poi_area_entered.bind(poi_root))
	poi_root.add_child(area)
	
	# Area de spawn de zombies (mas pequena, cerca del POI)
	var zombie_area = Area3D.new()
	zombie_area.name = "ZombieSpawnArea"
	var zombie_collision = CollisionShape3D.new()
	var zombie_sphere = SphereShape3D.new()
	zombie_sphere.radius = 15.0
	zombie_collision.shape = zombie_sphere
	zombie_area.add_child(zombie_collision)
	poi_root.add_child(zombie_area)
	
		# Generar loot dentro del POI
	spawn_loot_for_poi(poi_root, config)
	
	poi_container.add_child(poi_root)
	active_pois.append(poi_root)

# ============================================================
# JUGADOR ENTRA EN AREA DE POI
# ============================================================
func _on_poi_area_entered(body: Node3D, poi_root: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		var poi_name = poi_root.get_meta("poi_name")
		var poi_type = poi_root.get_meta("poi_type")
		print("Jugador entro a: ", poi_name)
		player_entered_poi.emit(poi_name, poi_type)

# ============================================================
# CONSTRUIR CASA ABANDONADA
# ============================================================
func build_abandoned_house(poi_root: Node3D, config: Dictionary) -> void:
	var main_color = config["color"]
	
	# Piso
	var floor_mesh = MeshInstance3D.new()
	var floor_box = BoxMesh.new()
	floor_box.size = Vector3(6.0, 0.2, 5.0)
	floor_mesh.mesh = floor_box
	floor_mesh.position = Vector3(0, 0.1, 0)
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.25, 0.2)
	floor_mesh.set_surface_override_material(0, floor_mat)
	poi_root.add_child(floor_mesh)
	
	# Paredes
	var wall_positions = [
		Vector3(-2.9, 1.5, 0),    # Izquierda
		Vector3(2.9, 1.5, 0),     # Derecha
		Vector3(0, 1.5, -2.4),    # Atras
	]
	var wall_sizes = [
		Vector3(0.2, 3.0, 5.0),
		Vector3(0.2, 3.0, 5.0),
		Vector3(6.0, 3.0, 0.2),
	]
	
	for i in range(wall_positions.size()):
		var wall = MeshInstance3D.new()
		var wall_box = BoxMesh.new()
		wall_box.size = wall_sizes[i]
		wall.mesh = wall_box
		wall.position = wall_positions[i]
		var wall_mat = StandardMaterial3D.new()
		wall_mat.albedo_color = main_color
		wall.set_surface_override_material(0, wall_mat)
		poi_root.add_child(wall)
	
	# Pared frontal con puerta (dos mitades)
	var front_wall_left = MeshInstance3D.new()
	var front_left_box = BoxMesh.new()
	front_left_box.size = Vector3(2.0, 3.0, 0.2)
	front_wall_left.mesh = front_left_box
	front_wall_left.position = Vector3(-2.0, 1.5, 2.4)
	var front_mat = StandardMaterial3D.new()
	front_mat.albedo_color = main_color
	front_wall_left.set_surface_override_material(0, front_mat)
	poi_root.add_child(front_wall_left)
	
	var front_wall_right = MeshInstance3D.new()
	var front_right_box = BoxMesh.new()
	front_right_box.size = Vector3(2.0, 3.0, 0.2)
	front_wall_right.mesh = front_right_box
	front_wall_right.position = Vector3(2.0, 1.5, 2.4)
	front_wall_right.set_surface_override_material(0, front_mat)
	poi_root.add_child(front_wall_right)
	
	# Techo
	var roof = MeshInstance3D.new()
	var roof_box = BoxMesh.new()
	roof_box.size = Vector3(6.5, 0.3, 5.5)
	roof.mesh = roof_box
	roof.position = Vector3(0, 3.15, 0)
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.2, 0.15, 0.1)
	roof.set_surface_override_material(0, roof_mat)
	poi_root.add_child(roof)
	
	# Ventana (representada con un plano azul oscuro)
	var window = MeshInstance3D.new()
	var window_mesh = BoxMesh.new()
	window_mesh.size = Vector3(1.5, 1.0, 0.1)
	window.mesh = window_mesh
	window.position = Vector3(0, 2.0, -2.35)
	var window_mat = StandardMaterial3D.new()
	window_mat.albedo_color = Color(0.1, 0.15, 0.25)
	window_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	window_mat.albedo_color.a = 0.6
	window.set_surface_override_material(0, window_mat)
	poi_root.add_child(window)
	
	# Colisiones para las paredes
	var collision_body = StaticBody3D.new()
	collision_body.name = "WallsCollision"
	
	var collision_shape = CollisionShape3D.new()
	var collision_box = BoxShape3D.new()
	collision_box.size = Vector3(6.0, 3.0, 5.0)
	collision_shape.shape = collision_box
	collision_shape.position = Vector3(0, 1.5, 0)
	collision_body.add_child(collision_shape)
	poi_root.add_child(collision_body)

# ============================================================
# CONSTRUIR GASOLINERA
# ============================================================
func build_gas_station(poi_root: Node3D, config: Dictionary) -> void:
	var main_color = config["color"]
	
	# Edificio principal
	var building = MeshInstance3D.new()
	var building_box = BoxMesh.new()
	building_box.size = Vector3(5.0, 2.5, 4.0)
	building.mesh = building_box
	building.position = Vector3(0, 1.25, 0)
	var building_mat = StandardMaterial3D.new()
	building_mat.albedo_color = Color(0.5, 0.5, 0.5)
	building.set_surface_override_material(0, building_mat)
	poi_root.add_child(building)
	
	# Techo
	var roof = MeshInstance3D.new()
	var roof_box = BoxMesh.new()
	roof_box.size = Vector3(5.5, 0.2, 4.5)
	roof.mesh = roof_box
	roof.position = Vector3(0, 2.6, 0)
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.3, 0.3, 0.3)
	roof.set_surface_override_material(0, roof_mat)
	poi_root.add_child(roof)
	
	# Bombas de gasolina (cilindros rojos)
	for i in range(2):
		var pump = MeshInstance3D.new()
		var pump_cyl = CylinderMesh.new()
		pump_cyl.top_radius = 0.3
		pump_cyl.bottom_radius = 0.3
		pump_cyl.height = 1.5
		pump.mesh = pump_cyl
		pump.position = Vector3(-1.5 + (i * 3.0), 0.75, 2.5)
		var pump_mat = StandardMaterial3D.new()
		pump_mat.albedo_color = main_color
		pump.set_surface_override_material(0, pump_mat)
		poi_root.add_child(pump)
	
	# Colision
	var collision_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var collision_box = BoxShape3D.new()
	collision_box.size = Vector3(5.0, 2.5, 4.0)
	collision_shape.shape = collision_box
	collision_shape.position = Vector3(0, 1.25, 0)
	collision_body.add_child(collision_shape)
	poi_root.add_child(collision_body)

# ============================================================
# CONSTRUIR PUESTO MEDICO
# ============================================================
func build_medical_post(poi_root: Node3D, config: Dictionary) -> void:
	var main_color = config["color"]
	
	# Estructura principal
	var building = MeshInstance3D.new()
	var building_box = BoxMesh.new()
	building_box.size = Vector3(4.0, 2.0, 3.5)
	building.mesh = building_box
	building.position = Vector3(0, 1.0, 0)
	var building_mat = StandardMaterial3D.new()
	building_mat.albedo_color = main_color
	building.set_surface_override_material(0, building_mat)
	poi_root.add_child(building)
	
	# Cruz roja en el techo
	var cross_v = MeshInstance3D.new()
	var cross_v_box = BoxMesh.new()
	cross_v_box.size = Vector3(0.3, 1.0, 0.3)
	cross_v.mesh = cross_v_box
	cross_v.position = Vector3(0, 2.8, 0)
	var cross_mat = StandardMaterial3D.new()
	cross_mat.albedo_color = Color(0.8, 0.1, 0.1)
	cross_v.set_surface_override_material(0, cross_mat)
	poi_root.add_child(cross_v)
	
	var cross_h = MeshInstance3D.new()
	var cross_h_box = BoxMesh.new()
	cross_h_box.size = Vector3(1.0, 0.3, 0.3)
	cross_h.mesh = cross_h_box
	cross_h.position = Vector3(0, 2.8, 0)
	cross_h.set_surface_override_material(0, cross_mat)
	poi_root.add_child(cross_h)
	
	# Colision
	var collision_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var collision_box = BoxShape3D.new()
	collision_box.size = Vector3(4.0, 2.0, 3.5)
	collision_shape.shape = collision_box
	collision_shape.position = Vector3(0, 1.0, 0)
	collision_body.add_child(collision_shape)
	poi_root.add_child(collision_body)

# ============================================================
# CONSTRUIR CAMPAMENTO
# ============================================================
func build_campsite(poi_root: Node3D, config: Dictionary) -> void:
	var main_color = config["color"]
	
	# Tiendas de campana (conos)
	for i in range(3):
		var tent = MeshInstance3D.new()
		var tent_cone = CylinderMesh.new()
		tent_cone.top_radius = 0.0
		tent_cone.bottom_radius = 1.2
		tent_cone.height = 1.5
		tent.mesh = tent_cone
		var angle = (i / 3.0) * PI * 2
		tent.position = Vector3(cos(angle) * 3.0, 0.75, sin(angle) * 3.0)
		var tent_mat = StandardMaterial3D.new()
		tent_mat.albedo_color = main_color
		tent.set_surface_override_material(0, tent_mat)
		poi_root.add_child(tent)
	
	# Fogata en el centro
	var fire_pit = MeshInstance3D.new()
	var fire_cyl = CylinderMesh.new()
	fire_cyl.top_radius = 0.5
	fire_cyl.bottom_radius = 0.6
	fire_cyl.height = 0.3
	fire_pit.mesh = fire_cyl
	fire_pit.position = Vector3(0, 0.15, 0)
	var fire_mat = StandardMaterial3D.new()
	fire_mat.albedo_color = Color(0.2, 0.2, 0.2)
	fire_pit.set_surface_override_material(0, fire_mat)
	poi_root.add_child(fire_pit)
	
	# "Fuego" (esfera naranja)
	var fire = MeshInstance3D.new()
	var fire_sphere = SphereMesh.new()
	fire_sphere.radius = 0.3
	fire_sphere.height = 0.6
	fire.mesh = fire_sphere
	fire.position = Vector3(0, 0.5, 0)
	var fire_color = StandardMaterial3D.new()
	fire_color.albedo_color = Color(1.0, 0.4, 0.0)
	fire_color.emission_enabled = true
	fire_color.emission = Color(1.0, 0.3, 0.0)
	fire_color.emission_energy = 1.0
	fire.set_surface_override_material(0, fire_color)
	poi_root.add_child(fire)
	
	# Colisiones para tiendas
	for i in range(3):
		var collision_body = StaticBody3D.new()
		var collision_shape = CollisionShape3D.new()
		var collision_box = BoxShape3D.new()
		collision_box.size = Vector3(2.0, 1.5, 2.0)
		collision_shape.shape = collision_box
		var angle = (i / 3.0) * PI * 2
		collision_shape.position = Vector3(cos(angle) * 3.0, 0.75, sin(angle) * 3.0)
		collision_body.add_child(collision_shape)
		poi_root.add_child(collision_body)

# ============================================================
# CONSTRUIR TORRE DE VIGILANCIA
# ============================================================
func build_watchtower(poi_root: Node3D, config: Dictionary) -> void:
	var main_color = config["color"]
	
	# Base (4 pilares)
	for i in range(4):
		var pillar = MeshInstance3D.new()
		var pillar_box = BoxMesh.new()
		pillar_box.size = Vector3(0.3, 4.0, 0.3)
		pillar.mesh = pillar_box
		var px = 1.5 if i % 2 == 0 else -1.5
		var pz = 1.5 if i < 2 else -1.5
		pillar.position = Vector3(px, 2.0, pz)
		var pillar_mat = StandardMaterial3D.new()
		pillar_mat.albedo_color = main_color
		pillar.set_surface_override_material(0, pillar_mat)
		poi_root.add_child(pillar)
	
	# Plataforma
	var platform = MeshInstance3D.new()
	var platform_box = BoxMesh.new()
	platform_box.size = Vector3(3.5, 0.3, 3.5)
	platform.mesh = platform_box
	platform.position = Vector3(0, 4.15, 0)
	var plat_mat = StandardMaterial3D.new()
	plat_mat.albedo_color = Color(0.3, 0.25, 0.2)
	platform.set_surface_override_material(0, plat_mat)
	poi_root.add_child(platform)
	
	# Barandilla
	for i in range(4):
		var rail = MeshInstance3D.new()
		var rail_box = BoxMesh.new()
		if i < 2:
			rail_box.size = Vector3(3.5, 0.8, 0.1)
		else:
			rail_box.size = Vector3(0.1, 0.8, 3.5)
		rail.mesh = rail_box
		var rx = 0.0 if i < 2 else (1.7 if i == 2 else -1.7)
		var rz = 1.7 if i == 0 else (-1.7 if i == 1 else 0.0)
		rail.position = Vector3(rx, 4.8, rz)
		var rail_mat = StandardMaterial3D.new()
		rail_mat.albedo_color = main_color
		rail.set_surface_override_material(0, rail_mat)
		poi_root.add_child(rail)
	
	# Techo
	var roof = MeshInstance3D.new()
	var roof_box = BoxMesh.new()
	roof_box.size = Vector3(4.0, 0.2, 4.0)
	roof.mesh = roof_box
	roof.position = Vector3(0, 5.3, 0)
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.25, 0.2, 0.15)
	roof.set_surface_override_material(0, roof_mat)
	poi_root.add_child(roof)
	
	# Escalera (representada como rampa)
	var ladder = MeshInstance3D.new()
	var ladder_box = BoxMesh.new()
	ladder_box.size = Vector3(0.5, 4.0, 0.1)
	ladder.mesh = ladder_box
	ladder.position = Vector3(0, 2.0, 1.8)
	var ladder_mat = StandardMaterial3D.new()
	ladder_mat.albedo_color = Color(0.4, 0.3, 0.2)
	ladder.set_surface_override_material(0, ladder_mat)
	poi_root.add_child(ladder)
	
	# Colision general
	var collision_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var collision_box = BoxShape3D.new()
	collision_box.size = Vector3(3.5, 5.0, 3.5)
	collision_shape.shape = collision_box
	collision_shape.position = Vector3(0, 2.5, 0)
	collision_body.add_child(collision_shape)
	poi_root.add_child(collision_body)

# ============================================================
# CONSTRUIR CABANA
# ============================================================
func build_cabin(poi_root: Node3D, config: Dictionary) -> void:
	var main_color = config["color"]
	
	# Paredes (madera)
	var wall_positions = [
		Vector3(-2.0, 1.2, 0),
		Vector3(2.0, 1.2, 0),
		Vector3(0, 1.2, -1.5),
		Vector3(0, 1.2, 1.5),
	]
	var wall_sizes = [
		Vector3(0.2, 2.4, 3.0),
		Vector3(0.2, 2.4, 3.0),
		Vector3(4.0, 2.4, 0.2),
		Vector3(4.0, 2.4, 0.2),
	]
	
	for i in range(wall_positions.size()):
		var wall = MeshInstance3D.new()
		var wall_box = BoxMesh.new()
		wall_box.size = wall_sizes[i]
		wall.mesh = wall_box
		wall.position = wall_positions[i]
		var wall_mat = StandardMaterial3D.new()
		wall_mat.albedo_color = main_color
		wall.set_surface_override_material(0, wall_mat)
		poi_root.add_child(wall)
	
		# Techo inclinado (dos planos que se juntan arriba)
	var roof_left = MeshInstance3D.new()
	var roof_left_box = BoxMesh.new()
	roof_left_box.size = Vector3(4.5, 0.2, 2.0)
	roof_left.mesh = roof_left_box
	roof_left.position = Vector3(0, 2.6, -0.8)
	roof_left.rotation.x = -0.4  # ← CAMBIADO: de 0.4 a -0.4
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.2, 0.15, 0.1)
	roof_left.set_surface_override_material(0, roof_mat)
	poi_root.add_child(roof_left)
	
	var roof_right = MeshInstance3D.new()
	var roof_right_box = BoxMesh.new()
	roof_right_box.size = Vector3(4.5, 0.2, 2.0)
	roof_right.mesh = roof_right_box
	roof_right.position = Vector3(0, 2.6, 0.8)
	roof_right.rotation.x = 0.4  # ← CAMBIADO: de -0.4 a 0.4
	roof_right.set_surface_override_material(0, roof_mat)
	poi_root.add_child(roof_right)
	
	# Chimenea
	var chimney = MeshInstance3D.new()
	var chimney_box = BoxMesh.new()
	chimney_box.size = Vector3(0.5, 1.5, 0.5)
	chimney.mesh = chimney_box
	chimney.position = Vector3(1.0, 3.0, -0.5)
	var chimney_mat = StandardMaterial3D.new()
	chimney_mat.albedo_color = Color(0.4, 0.3, 0.25)
	chimney.set_surface_override_material(0, chimney_mat)
	poi_root.add_child(chimney)
	
	# Colision
	var collision_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var collision_box = BoxShape3D.new()
	collision_box.size = Vector3(4.0, 2.5, 3.0)
	collision_shape.shape = collision_box
	collision_shape.position = Vector3(0, 1.25, 0)
	collision_body.add_child(collision_shape)
	poi_root.add_child(collision_body)

# ============================================================
# GENERAR LOOT PARA UN POI
# ============================================================
func spawn_loot_for_poi(poi_root: Node3D, config: Dictionary) -> void:
	var loot_chance = config.get("loot_chance", 0.5)
	var loot_amount = config.get("loot_amount", 1)
	var loot_type_str = config.get("loot_type", "ammo")
	
	print("DEBUG POI: ", poi_root.name, " | loot_type: ", loot_type_str, 
		  " | chance: ", loot_chance, " | amount: ", loot_amount)
	
	# Decidir si generar loot
	var roll = randf()
	print("DEBUG: randf() = ", roll, " | necesita <= ", loot_chance)
	if roll > loot_chance:
		print("DEBUG: No genera loot (fallo el chance)")
		return
	
	# Determinar tipo de loot
	var loot_scene_path = ""
	match loot_type_str:
		"ammo":
			loot_scene_path = "res://scenes/loot/AmmoLoot.tscn"
			print("DEBUG: Tipo seleccionado: AMMO")
		"medkit":
			loot_scene_path = "res://scenes/loot/MedkitLoot.tscn"
			print("DEBUG: Tipo seleccionado: MEDKIT")
		"mixed":
			if randf() > 0.5:
				loot_scene_path = "res://scenes/loot/AmmoLoot.tscn"
				print("DEBUG: Tipo seleccionado (mixed): AMMO")
			else:
				loot_scene_path = "res://scenes/loot/MedkitLoot.tscn"
				print("DEBUG: Tipo seleccionado (mixed): MEDKIT")
		_:
			loot_scene_path = "res://scenes/loot/AmmoLoot.tscn"
			print("DEBUG: Tipo default: AMMO")
	
	print("DEBUG: Intentando cargar: ", loot_scene_path)
	var scene = load(loot_scene_path)
	if not scene:
		push_warning("No se pudo cargar escena de loot: " + loot_scene_path)
		print("DEBUG: ERROR - No se pudo cargar escena!")
		return
	
	print("DEBUG: Escena cargada correctamente, generando ", loot_amount, " items")
	
	# Generar loot alrededor del POI
	for i in range(loot_amount):
		var loot = scene.instantiate()
		
		# Posicion aleatoria cerca del POI
		var offset = Vector3(randf_range(-3.0, 3.0), 0.5, randf_range(-3.0, 3.0))
		loot.position = poi_root.position + offset
		
		# Ajustar altura al terreno
		var terrain_y = get_terrain_height(loot.position.x, loot.position.z)
		loot.position.y = terrain_y + 0.5
		
		poi_container.add_child(loot)
		print("DEBUG: Loot #", i+1, " generado: ", loot_type_str, " en ", loot.position)
