extends Node

# ============================================================
# BIOME MANAGER - Controla los biomas de la isla
# ============================================================

# Tipos de bioma
enum BiomeType {
	FOREST,      # Bosque - Centro-Norte
	ROCKY,       # Zona rocosa - Este
	PRAIRIE,     # Pradera - Oeste
	BEACH        # Playa - Sur (borde)
}

# Colores de terreno para cada bioma
var biome_colors: Dictionary = {
	BiomeType.FOREST:   Color(0.06, 0.18, 0.04),   # Verde oscuro
	BiomeType.ROCKY:    Color(0.20, 0.18, 0.14),   # Grisáceo pardo
	BiomeType.PRAIRIE:  Color(0.15, 0.35, 0.08),   # Verde claro
	BiomeType.BEACH:    Color(0.35, 0.30, 0.18),   # Arena
}

# Colores de vegetación para cada bioma
var vegetation_colors: Dictionary = {
	BiomeType.FOREST:   Color(0.08, 0.25, 0.06),   # Verde bosque
	BiomeType.ROCKY:    Color(0.12, 0.20, 0.08),   # Verde seco
	BiomeType.PRAIRIE:  Color(0.18, 0.40, 0.10),   # Verde pradera
	BiomeType.BEACH:    Color(0.25, 0.35, 0.15),   # Verde salado
}

# Nombres legibles
var biome_names: Dictionary = {
	BiomeType.FOREST:  "Bosque",
	BiomeType.ROCKY:   "Zona Rocoso",
	BiomeType.PRAIRIE: "Pradera",
	BiomeType.BEACH:   "Playa",
}

# Referencias
var island: Node3D = null
var player: Node3D = null

# Señal para notificar cambio de bioma
signal biome_changed(biome_type: int, biome_name: String)

var current_biome: int = BiomeType.FOREST
var current_biome_name: String = "Bosque"

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	# Buscar la isla
	island = get_tree().get_root().find_child("Island", true, false)
	# Buscar el jugador
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		player = get_tree().get_root().find_child("Player", true, false)
	
	print("BiomeManager iniciado")
	print("Biomas disponibles: Bosque, Rocoso, Pradera, Playa")

# ============================================================
# OBTENER BIOMA SEGUN POSICION
# ============================================================
func get_biome_at_position(pos: Vector3) -> int:
	var x = pos.x
	var z = pos.z
	var dist = Vector2(x, z).length()
	
	# Playa: borde de la isla (últimos 30 metros)
	if dist > 120.0:
		return BiomeType.BEACH
	
	# Determinar bioma por ángulo (sectores)
	var angle = atan2(z, x)  # Ángulo en radianes (-PI a PI)
	var degrees = rad_to_deg(angle)
	if degrees < 0:
		degrees += 360.0  # Convertir a 0-360
	
	# Sectores:
	# 0-90°   = Este  (Rocoso)
	# 90-180° = Norte (Bosque)
	# 180-270°= Oeste (Pradera)
	# 270-360°= Sur   (pero ya filtramos playa arriba)
	
	if degrees >= 45 and degrees < 135:
		return BiomeType.FOREST      # Norte
	elif degrees >= 135 and degrees < 225:
		return BiomeType.PRAIRIE     # Oeste
	elif degrees >= 225 and degrees < 315:
		# Sur - pero solo si no es playa
		if dist > 100.0:
			return BiomeType.BEACH
		return BiomeType.PRAIRIE     # Sur interior = pradera
	else:
		return BiomeType.ROCKY       # Este

# ============================================================
# OBTENER COLOR DE TERRENO
# ============================================================
func get_terrain_color(pos: Vector3) -> Color:
	var biome = get_biome_at_position(pos)
	return biome_colors[biome]

# ============================================================
# OBTENER COLOR DE VEGETACION
# ============================================================
func get_vegetation_color(pos: Vector3) -> Color:
	var biome = get_biome_at_position(pos)
	return vegetation_colors[biome]

# ============================================================
# OBTENER NOMBRE DEL BIOMA
# ============================================================
func get_biome_name(pos: Vector3) -> String:
	var biome = get_biome_at_position(pos)
	return biome_names[biome]

# ============================================================
# VERIFICAR SI UN PUNTO ESTA EN UN BIOMA ESPECIFICO
# ============================================================
func is_in_biome(pos: Vector3, biome: int) -> bool:
	return get_biome_at_position(pos) == biome

# ============================================================
# OBTENER PROBABILIDAD DE SPAWN SEGUN BIOMA
# (Para la Fase 4.5 - Spawn Inteligente)
# ============================================================
func get_spawn_weights(biome: int) -> Dictionary:
	match biome:
		BiomeType.FOREST:
			return {
				"zombies": 1.5,      # Más zombies
				"trees": 1.2,        # Más árboles
				"rocks": 0.3,        # Menos rocas
				"bushes": 0.8,
			}
		BiomeType.ROCKY:
			return {
				"zombies": 0.8,       # Menos zombies
				"trees": 0.2,         # Pocos árboles
				"rocks": 2.0,         # Muchas rocas
				"bushes": 0.4,
			}
		BiomeType.PRAIRIE:
			return {
				"zombies": 1.0,       # Normal
				"trees": 0.5,         # Algunos árboles
				"rocks": 0.4,
				"bushes": 1.2,        # Más arbustos
			}
		BiomeType.BEACH:
			return {
				"zombies": 0.5,       # Pocos zombies
				"trees": 0.1,         # Casi ningún árbol
				"rocks": 0.6,
				"bushes": 0.3,
			}
		_:
			return {"zombies": 1.0, "trees": 1.0, "rocks": 1.0, "bushes": 1.0}

# ============================================================
# DEBUG: Mostrar bioma actual del jugador
# ============================================================
func _process(_delta: float) -> void:
	if player and is_instance_valid(player):
		var biome = get_biome_at_position(player.global_position)
		var biome_name = biome_names[biome]
		
		if biome != current_biome:
			current_biome = biome
			current_biome_name = biome_name
			biome_changed.emit(biome, biome_name)
			print("Jugador entra en: ", biome_name)
