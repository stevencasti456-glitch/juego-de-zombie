extends Node3D

@onready var terrain_mesh_instance: MeshInstance3D = $Terrain/MeshInstance3D
@onready var terrain_collision: CollisionShape3D = $Terrain/CollisionShape3D
@onready var rocks_container: Node3D = $RocksContainer
@onready var vegetation_container: Node3D = $VegetationContainer

const ISLAND_RADIUS: float = 150.0
const ROCK_COUNT: int = 25
const VEGETATION_COUNT: int = 500

var trees_container: Node3D
var bushes_container: Node3D
var flowers_container: Node3D
var logs_container: Node3D
var ruins_container: Node3D
var props_container: Node3D

var placed_items: Array = []


func _ready() -> void:
	global_position = Vector3.ZERO
	if has_node("Terrain"):
		$Terrain.position = Vector3.ZERO

	create_decoration_containers()
	generate_island_mesh()
	generate_decorations()

	call_deferred("bake_navigation_mesh_with_decorations")


func create_decoration_containers() -> void:
	trees_container = Node3D.new()
	trees_container.name = "TreesContainer"
	add_child(trees_container)

	bushes_container = Node3D.new()
	bushes_container.name = "BushesContainer"
	add_child(bushes_container)

	flowers_container = Node3D.new()
	flowers_container.name = "FlowersContainer"
	add_child(flowers_container)

	logs_container = Node3D.new()
	logs_container.name = "LogsContainer"
	add_child(logs_container)

	ruins_container = Node3D.new()
	ruins_container.name = "RuinsContainer"
	add_child(ruins_container)

	props_container = Node3D.new()
	props_container.name = "PropsContainer"
	add_child(props_container)


func get_terrain_height(x: float, z: float) -> float:
	var dist = Vector2(x, z).length()
	var height = 12.0 + (sin(x * 0.05) * cos(z * 0.05) * 6.0) + (sin(x * 0.02) * 10.0)
	if dist > ISLAND_RADIUS - 30.0:
		height -= (dist - (ISLAND_RADIUS - 30.0)) * 1.5
	return height


func generate_island_mesh() -> void:
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(ISLAND_RADIUS * 2, ISLAND_RADIUS * 2)
	plane_mesh.subdivide_width = 60
	plane_mesh.subdivide_depth = 60

	var surface_tool = SurfaceTool.new()
	surface_tool.create_from(plane_mesh, 0)
	var array_mesh = surface_tool.commit()

	var mdt = MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)

	# ← NUEVO: Referencia al BiomeManager
	var biome_manager = get_node_or_null("/root/Main/BiomeManager")

	for i in range(mdt.get_vertex_count()):
		var vertex = mdt.get_vertex(i)
		vertex.y = get_terrain_height(vertex.x, vertex.z)
		mdt.set_vertex(i, vertex)
		
		# ← NUEVO: Color del bioma para cada vértice
		if biome_manager:
			var biome_color = biome_manager.get_terrain_color(vertex)
			mdt.set_vertex_color(i, biome_color)
		else:
			# Color por defecto si no hay BiomeManager
			mdt.set_vertex_color(i, Color(0.08, 0.22, 0.06))

	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)

	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.create_from(array_mesh, 0)
	surface_tool.generate_normals()
	var final_mesh = surface_tool.commit()

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0)  # ← NUEVO: Blanco para que se vean los colores de vértice
	material.roughness = 0.95
	material.metallic = 0.0
	material.vertex_color_use_as_albedo = true  # ← NUEVO: Usar colores de vértice

	terrain_mesh_instance.mesh = final_mesh
	terrain_mesh_instance.set_surface_override_material(0, material)

	var trimesh_shape = final_mesh.create_trimesh_shape()
	if trimesh_shape and terrain_collision:
		terrain_collision.shape = trimesh_shape
		terrain_collision.position = Vector3.ZERO
		print("DEBUG: Colisión del terreno creada correctamente (trimesh)")
	else:
		push_warning("DEBUG: Falló la colisión del terreno, usando piso de respaldo")
		if terrain_collision:
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(ISLAND_RADIUS * 3.0, 100, ISLAND_RADIUS * 3.0)
			terrain_collision.shape = box_shape
			terrain_collision.position = Vector3(0, 25, 0)


func bake_navigation_mesh_with_decorations() -> void:
	var nav_region = get_parent() as NavigationRegion3D
	if not nav_region:
		push_error("No se encontro NavigationRegion3D como padre de Island")
		return

	await get_tree().process_frame

	var nav_mesh = NavigationMesh.new()
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_group_name = "navigation"
	nav_mesh.cell_size = 0.5
	nav_mesh.cell_height = 0.5
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	nav_region.navigation_mesh = nav_mesh
	nav_region.bake_navigation_mesh()
	print("NavMesh horneado con decoracion correctamente")


func check_space_and_place(x: float, z: float, radius: float) -> bool:
	for item in placed_items:
		var dist = sqrt(pow(x - item.x, 2) + pow(z - item.z, 2))
		if dist < (radius + item.r):
			return false
	if sqrt(x * x + z * z) < 15.0:
		return false
	placed_items.append({"x": x, "z": z, "r": radius})
	return true


func generate_decorations() -> void:
	generate_rocks()
	generate_grass()
	generate_trees()
	generate_bushes()
	generate_flowers()
	generate_logs()
	generate_ruins()
	generate_props()


func generate_rocks() -> void:
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.18, 0.16, 0.14)
	rock_mat.roughness = 0.85
	rock_mat.metallic = 0.0
	
	# Referencia al BiomeManager
	var biome_manager = get_node_or_null("/root/Main/BiomeManager")
	
	# Ajustar cantidad de rocas segun bioma
	var actual_rock_count = ROCK_COUNT
	if biome_manager:
		# Contar cuantas rocas por bioma
		var rocky_count = 0
		var other_count = 0
		for _i in range(ROCK_COUNT):
			var test_x = randf_range(-100.0, 100.0)
			var test_z = randf_range(-100.0, 100.0)
			var biome = biome_manager.get_biome_at_position(Vector3(test_x, 0, test_z))
			var weights = biome_manager.get_spawn_weights(biome)
			if weights.get("rocks", 1.0) > 1.5:
				rocky_count += 1
			else:
				other_count += 1
		# Mas rocas en zonas rocosas
		actual_rock_count = ROCK_COUNT + rocky_count

	var i = 0
	while i < actual_rock_count:
		var x = randf_range(-100.0, 100.0)
		var z = randf_range(-100.0, 100.0)
		var scale_factor = randf_range(1.5, 4.0)
		
		# Verificar peso de rocas en este bioma
		var should_place = true
		if biome_manager:
			var biome = biome_manager.get_biome_at_position(Vector3(x, 0, z))
			var weights = biome_manager.get_spawn_weights(biome)
			var rock_weight = weights.get("rocks", 1.0)
			if randf() > rock_weight * 0.4:
				should_place = false
		
		if not should_place:
			continue

		if check_space_and_place(x, z, scale_factor * 1.5):
			var static_body = StaticBody3D.new()
			static_body.add_to_group("navigation")

			var collision = CollisionShape3D.new()
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = scale_factor
			collision.shape = sphere_shape

			var mesh_instance = MeshInstance3D.new()
			var sphere_mesh = SphereMesh.new()
			sphere_mesh.radius = scale_factor
			sphere_mesh.height = scale_factor * 2.0
			mesh_instance.mesh = sphere_mesh
			
			# Color de roca segun bioma
			var rock_color_mat = StandardMaterial3D.new()
			if biome_manager:
				var biome = biome_manager.get_biome_at_position(Vector3(x, 0, z))
				if biome == 1:
					# ROCKY
					rock_color_mat.albedo_color = Color(0.25, 0.22, 0.18)
				elif biome == 3:
					# BEACH
					rock_color_mat.albedo_color = Color(0.30, 0.25, 0.20)
				else:
					rock_color_mat.albedo_color = Color(0.18, 0.16, 0.14)
			else:
				rock_color_mat.albedo_color = Color(0.18, 0.16, 0.14)
			
			rock_color_mat.roughness = 0.85
			rock_color_mat.metallic = 0.0
			
			mesh_instance.set_surface_override_material(0, rock_color_mat)

			static_body.add_child(mesh_instance)
			static_body.add_child(collision)
			rocks_container.add_child(static_body)

			var terrain_y = get_terrain_height(x, z)
			static_body.transform.origin = Vector3(x, terrain_y + scale_factor * 0.3, z)
			i += 1


func generate_grass() -> void:
	var multimesh_instance = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D

	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.5, 1.0)
	mm.mesh = quad_mesh
	
	# ← NUEVO: Referencia al BiomeManager
	var biome_manager = get_node_or_null("/root/Main/BiomeManager")
	
	# ← NUEVO: Color base de hierba según bioma (usamos verde bosque por defecto)
	var grass_color = Color(0.12, 0.35, 0.08)
	if biome_manager:
		# Promedio de colores de vegetación
		var avg_color = Color(0, 0, 0)
		var sample_count = 0
		for _s in range(20):
			var sx = randf_range(-100.0, 100.0)
			var sz = randf_range(-100.0, 100.0)
			var c = biome_manager.get_vegetation_color(Vector3(sx, 0, sz))
			avg_color += c
			sample_count += 1
		if sample_count > 0:
			grass_color = avg_color / sample_count

	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = grass_color
	grass_mat.roughness = 0.8
	grass_mat.metallic = 0.0
	grass_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	grass_mat.alpha_scissor_threshold = 0.5
	grass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR

	mm.instance_count = VEGETATION_COUNT
	multimesh_instance.multimesh = mm
	multimesh_instance.material_override = grass_mat
	vegetation_container.add_child(multimesh_instance)

	var grass_placed = 0
	while grass_placed < VEGETATION_COUNT:
		var x = randf_range(-120.0, 120.0)
		var z = randf_range(-120.0, 120.0)

		var dist_from_center = sqrt(x * x + z * z)
		if dist_from_center < ISLAND_RADIUS - 10.0:
			var terrain_y = get_terrain_height(x, z)

			var t = Transform3D()
			var random_height = randf_range(0.6, 1.3)
			var random_rotation = randf_range(0, PI * 2)
			
			# ← NUEVO: Ajustar altura según bioma (menos hierba en rocoso)
			if biome_manager:
				var biome = biome_manager.get_biome_at_position(Vector3(x, 0, z))
				var weights = biome_manager.get_spawn_weights(biome)
				var bush_weight = weights.get("bushes", 1.0)
				random_height *= bush_weight

			t = t.scaled(Vector3(1.0, random_height, 1.0))
			t = t.rotated(Vector3.UP, random_rotation)
			t.origin = Vector3(x, terrain_y + 0.25, z)

			mm.set_instance_transform(grass_placed, t)
			grass_placed += 1


func generate_trees() -> void:
	var tree_count = 30
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.25, 0.15, 0.08)
	trunk_mat.roughness = 0.9
	
	# ← NUEVO: Referencia al BiomeManager
	var biome_manager = get_node_or_null("/root/Main/BiomeManager")

	for i in range(tree_count):
		var x = randf_range(-90.0, 90.0)
		var z = randf_range(-90.0, 90.0)
		
		# ← NUEVO: Obtener pesos del bioma para decidir si poner árbol
		var should_place = true
		if biome_manager:
			var pos = Vector3(x, 0, z)
			var biome = biome_manager.get_biome_at_position(pos)
			var weights = biome_manager.get_spawn_weights(biome)
			var tree_weight = weights.get("trees", 1.0)
			# Si el peso es bajo, hay menos probabilidad de árbol
			if randf() > tree_weight * 0.5:
				should_place = false
		
		if not should_place:
			continue

		if check_space_and_place(x, z, 3.0):
			var tree = StaticBody3D.new()
			tree.name = "Tree_" + str(i)
			tree.add_to_group("navigation")

			var trunk = MeshInstance3D.new()
			var trunk_mesh = CylinderMesh.new()
			trunk_mesh.top_radius = 0.3
			trunk_mesh.bottom_radius = 0.5
			trunk_mesh.height = 4.0
			trunk.mesh = trunk_mesh
			trunk.set_surface_override_material(0, trunk_mat)
			trunk.position = Vector3(0, 2.0, 0)
			tree.add_child(trunk)

			var trunk_collision = CollisionShape3D.new()
			var trunk_shape = CylinderShape3D.new()
			trunk_shape.radius = 0.5
			trunk_shape.height = 4.0
			trunk_collision.shape = trunk_shape
			trunk_collision.position = Vector3(0, 2.0, 0)
			tree.add_child(trunk_collision)

			# ← NUEVO: Hojas con color del bioma
			var leaves = MeshInstance3D.new()
			var leaves_mesh = SphereMesh.new()
			leaves_mesh.radius = 2.5
			leaves_mesh.height = 5.0
			leaves.mesh = leaves_mesh
			
			var leaves_mat = StandardMaterial3D.new()
			if biome_manager:
				var pos = Vector3(x, 0, z)
				leaves_mat.albedo_color = biome_manager.get_vegetation_color(pos)
			else:
				leaves_mat.albedo_color = Color(0.08, 0.25, 0.06)
			leaves_mat.roughness = 0.8
			leaves.set_surface_override_material(0, leaves_mat)
			
			leaves.position = Vector3(0, 5.0, 0)
			tree.add_child(leaves)

			var terrain_y = get_terrain_height(x, z)
			tree.position = Vector3(x, terrain_y, z)
			trees_container.add_child(tree)


func generate_bushes() -> void:
	var bush_count = 40
	var bush_mat = StandardMaterial3D.new()
	bush_mat.albedo_color = Color(0.1, 0.3, 0.05)
	bush_mat.roughness = 0.85

	for i in range(bush_count):
		var x = randf_range(-100.0, 100.0)
		var z = randf_range(-100.0, 100.0)

		if check_space_and_place(x, z, 1.5):
			var bush = StaticBody3D.new()
			bush.name = "Bush_" + str(i)
			bush.add_to_group("navigation")

			var bush_mesh = SphereMesh.new()
			bush_mesh.radius = randf_range(0.8, 1.5)
			bush_mesh.height = bush_mesh.radius * 2.0

			var mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = bush_mesh
			mesh_instance.set_surface_override_material(0, bush_mat)
			bush.add_child(mesh_instance)

			var collision = CollisionShape3D.new()
			var shape = SphereShape3D.new()
			shape.radius = bush_mesh.radius
			collision.shape = shape
			bush.add_child(collision)

			var terrain_y = get_terrain_height(x, z)
			bush.position = Vector3(x, terrain_y + bush_mesh.radius * 0.5, z)
			bushes_container.add_child(bush)


func generate_flowers() -> void:
	var flower_count = 200
	var multimesh_instance = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D

	var flower_mesh = SphereMesh.new()
	flower_mesh.radius = 0.15
	flower_mesh.height = 0.3

	var flower_mat = StandardMaterial3D.new()
	flower_mat.albedo_color = Color(0.9, 0.3, 0.5)
	flower_mat.roughness = 0.6
	flower_mat.metallic = 0.0

	mm.mesh = flower_mesh
	mm.instance_count = flower_count
	multimesh_instance.multimesh = mm
	multimesh_instance.material_override = flower_mat
	flowers_container.add_child(multimesh_instance)

	var placed = 0
	while placed < flower_count:
		var x = randf_range(-110.0, 110.0)
		var z = randf_range(-110.0, 110.0)

		var dist_from_center = sqrt(x * x + z * z)
		if dist_from_center < ISLAND_RADIUS - 15.0:
			var terrain_y = get_terrain_height(x, z)

			var t = Transform3D()
			t.origin = Vector3(x, terrain_y + 0.15, z)
			mm.set_instance_transform(placed, t)
			placed += 1


func generate_logs() -> void:
	var log_count = 8
	var log_mat = StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.3, 0.2, 0.1)
	log_mat.roughness = 0.9

	for i in range(log_count):
		var x = randf_range(-80.0, 80.0)
		var z = randf_range(-80.0, 80.0)

		if check_space_and_place(x, z, 2.0):
			var fallen_log = StaticBody3D.new()
			fallen_log.name = "Log_" + str(i)
			fallen_log.add_to_group("navigation")

			var log_mesh = CylinderMesh.new()
			log_mesh.top_radius = 0.3
			log_mesh.bottom_radius = 0.3
			log_mesh.height = 3.0

			var mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = log_mesh
			mesh_instance.set_surface_override_material(0, log_mat)
			fallen_log.add_child(mesh_instance)

			var collision = CollisionShape3D.new()
			var shape = CylinderShape3D.new()
			shape.radius = 0.3
			shape.height = 3.0
			collision.shape = shape
			fallen_log.add_child(collision)

			var terrain_y = get_terrain_height(x, z)
			fallen_log.position = Vector3(x, terrain_y + 0.3, z)
			fallen_log.rotation.z = PI / 2
			fallen_log.rotation.y = randf_range(0, PI * 2)
			logs_container.add_child(fallen_log)


func generate_ruins() -> void:
	var ruin_mat = StandardMaterial3D.new()
	ruin_mat.albedo_color = Color(0.5, 0.48, 0.45)
	ruin_mat.roughness = 0.95

	for i in range(3):
		var wall = StaticBody3D.new()
		wall.name = "RuinWall_" + str(i)
		wall.add_to_group("navigation")

		var wall_mesh = BoxMesh.new()
		wall_mesh.size = Vector3(4.0, randf_range(2.0, 4.0), 0.5)

		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = wall_mesh
		mesh_instance.set_surface_override_material(0, ruin_mat)
		wall.add_child(mesh_instance)

		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = wall_mesh.size
		collision.shape = shape
		wall.add_child(collision)

		var x = randf_range(-60.0, 60.0)
		var z = randf_range(-60.0, 60.0)
		var terrain_y = get_terrain_height(x, z)
		wall.position = Vector3(x, terrain_y + wall_mesh.size.y / 2, z)
		wall.rotation.y = randf_range(-0.3, 0.3)
		ruins_container.add_child(wall)

	for i in range(2):
		var pillar = StaticBody3D.new()
		pillar.name = "RuinPillar_" + str(i)
		pillar.add_to_group("navigation")

		var pillar_mesh = CylinderMesh.new()
		pillar_mesh.top_radius = 0.4
		pillar_mesh.bottom_radius = 0.5
		pillar_mesh.height = 2.0

		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = pillar_mesh
		mesh_instance.set_surface_override_material(0, ruin_mat)
		pillar.add_child(mesh_instance)

		var collision = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = 0.5
		shape.height = 2.0
		collision.shape = shape
		pillar.add_child(collision)

		var x = randf_range(-60.0, 60.0)
		var z = randf_range(-60.0, 60.0)
		var terrain_y = get_terrain_height(x, z)
		pillar.position = Vector3(x, terrain_y + 0.5, z)
		pillar.rotation.z = randf_range(0.2, 0.8)
		ruins_container.add_child(pillar)


func generate_props() -> void:
	var barrel_mat = StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.4, 0.25, 0.05)
	barrel_mat.roughness = 0.7
	barrel_mat.metallic = 0.3

	var crate_mat = StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.55, 0.4, 0.25)
	crate_mat.roughness = 0.8

	for i in range(5):
		var x = randf_range(-70.0, 70.0)
		var z = randf_range(-70.0, 70.0)

		if check_space_and_place(x, z, 1.0):
			var barrel = StaticBody3D.new()
			barrel.name = "Barrel_" + str(i)
			barrel.add_to_group("navigation")

			var barrel_mesh = CylinderMesh.new()
			barrel_mesh.top_radius = 0.5
			barrel_mesh.bottom_radius = 0.5
			barrel_mesh.height = 1.2

			var mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = barrel_mesh
			mesh_instance.set_surface_override_material(0, barrel_mat)
			barrel.add_child(mesh_instance)

			var collision = CollisionShape3D.new()
			var shape = CylinderShape3D.new()
			shape.radius = 0.5
			shape.height = 1.2
			collision.shape = shape
			barrel.add_child(collision)

			var terrain_y = get_terrain_height(x, z)
			barrel.position = Vector3(x, terrain_y + 0.6, z)
			props_container.add_child(barrel)

	for i in range(5):
		var x = randf_range(-70.0, 70.0)
		var z = randf_range(-70.0, 70.0)

		if check_space_and_place(x, z, 1.0):
			var crate = StaticBody3D.new()
			crate.name = "Crate_" + str(i)
			crate.add_to_group("navigation")

			var crate_mesh = BoxMesh.new()
			crate_mesh.size = Vector3(1.0, 1.0, 1.0)

			var mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = crate_mesh
			mesh_instance.set_surface_override_material(0, crate_mat)
			crate.add_child(mesh_instance)

			var collision = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = crate_mesh.size
			collision.shape = shape
			crate.add_child(collision)

			var terrain_y = get_terrain_height(x, z)
			crate.position = Vector3(x, terrain_y + 0.5, z)
			crate.rotation.y = randf_range(0, PI * 2)
			props_container.add_child(crate)
