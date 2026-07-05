extends Area3D

# ============================================================
# NÚCLEO (MONEDA) - Diseño estético completo
# ============================================================

@export var coin_value: int = 10
@export var rotation_speed: float = 3.0
@export var collection_distance: float = 2.0

var is_collected: bool = false
var float_offset: float = 0.0
var float_speed: float = 2.0
var float_amplitude: float = 0.15

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	# Crear el diseño visual completo de la moneda
	create_coin_visual()
	
	# Asegurar colisión
	if not has_node("CollisionShape3D"):
		var collision = CollisionShape3D.new()
		var shape = SphereShape3D.new()
		shape.radius = 0.5
		collision.shape = shape
		add_child(collision)
	
	# Conectar señal
	body_entered.connect(_on_body_entered)
	
	# Offset aleatorio para que no floten todas sincronizadas
	float_offset = randf() * TAU

# ============================================================
# CREAR DISEÑO VISUAL DE LA MONEDA
# ============================================================
func create_coin_visual() -> void:
	var coin_root = Node3D.new()
	coin_root.name = "CoinVisual"
	add_child(coin_root)
	
	# --- 1. BORDE EXTERNO PLATEADO (anillo) ---
	var outer_ring = MeshInstance3D.new()
	outer_ring.name = "OuterRing"
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.32
	ring_mesh.outer_radius = 0.42
	outer_ring.mesh = ring_mesh
	
	var silver_mat = StandardMaterial3D.new()
	silver_mat.albedo_color = Color(0.75, 0.78, 0.82)
	silver_mat.metallic = 0.9
	silver_mat.roughness = 0.15
	silver_mat.emission_enabled = true
	silver_mat.emission = Color(0.3, 0.35, 0.4)
	silver_mat.emission_energy = 0.3
	outer_ring.set_surface_override_material(0, silver_mat)
	coin_root.add_child(outer_ring)
	
	# --- 2. DISCO BASE (cara de la moneda) ---
	var base = MeshInstance3D.new()
	base.name = "Base"
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.32
	base_mesh.bottom_radius = 0.32
	base_mesh.height = 0.06
	base.mesh = base_mesh
	
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.15, 0.15, 0.2)
	base_mat.metallic = 0.6
	base_mat.roughness = 0.3
	base.set_surface_override_material(0, base_mat)
	base.rotation.x = PI / 2
	coin_root.add_child(base)
	
	# --- 3. HEXÁGONO CENTRAL ---
	var hexagon = MeshInstance3D.new()
	hexagon.name = "Hexagon"
	var hex_mesh = CylinderMesh.new()
	hex_mesh.top_radius = 0.18
	hex_mesh.bottom_radius = 0.18
	hex_mesh.height = 0.08
	hex_mesh.radial_segments = 6  # ¡Hexágono!
	hexagon.mesh = hex_mesh
	
	var hex_mat = StandardMaterial3D.new()
	hex_mat.albedo_color = Color(0.9, 0.5, 0.05)
	hex_mat.metallic = 0.8
	hex_mat.roughness = 0.2
	hex_mat.emission_enabled = true
	hex_mat.emission = Color(1.0, 0.6, 0.1)
	hex_mat.emission_energy = 0.8
	hexagon.set_surface_override_material(0, hex_mat)
	hexagon.rotation.x = PI / 2
	coin_root.add_child(hexagon)
	
	# --- 4. NÚCLEO BRILLANTE (centro) ---
	var core = MeshInstance3D.new()
	core.name = "Core"
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.1
	core_mesh.height = 0.2
	core.mesh = core_mesh
	
	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.95, 0.7)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.9, 0.4)
	core_mat.emission_energy = 2.5
	core.set_surface_override_material(0, core_mat)
	coin_root.add_child(core)
	
	# --- 5. DETALLES TECNOLÓGICOS (líneas circulares) ---
	for i in range(3):
		var detail = MeshInstance3D.new()
		detail.name = "Detail" + str(i)
		var detail_mesh = TorusMesh.new()
		detail_mesh.inner_radius = 0.22 + (i * 0.03)
		detail_mesh.outer_radius = 0.23 + (i * 0.03)
		detail.mesh = detail_mesh
		
		var detail_mat = StandardMaterial3D.new()
		detail_mat.albedo_color = Color(0.5, 0.55, 0.6)
		detail_mat.metallic = 0.7
		detail_mat.roughness = 0.4
		detail_mat.emission_enabled = true
		detail_mat.emission = Color(0.2, 0.25, 0.3)
		detail_mat.emission_energy = 0.2
		detail.set_surface_override_material(0, detail_mat)
		coin_root.add_child(detail)
	
	# --- 6. LUZ PUNTUAL (brillo sutil) ---
	var light = OmniLight3D.new()
	light.name = "CoinLight"
	light.light_color = Color(1.0, 0.85, 0.3)
	light.light_energy = 0.6
	light.omni_range = 2.0
	light.omni_attenuation = 2.0
	coin_root.add_child(light)
	
	# Guardar referencia para animar
	coin_root.set_meta("visual_root", true)

# ============================================================
# PROCESS - Gira y flota
# ============================================================
func _process(delta: float) -> void:
	if is_collected:
		return
	
	# Girar sobre sí misma (eje Y)
	rotate_y(delta * rotation_speed)
	
	# Efecto de flotación suave (solo en Y)
	var coin_visual = get_node_or_null("CoinVisual")
	if coin_visual:
		var time = Time.get_time_dict_from_system()
		var float_y = sin((time["second"] + float_offset) * float_speed) * float_amplitude
		coin_visual.position.y = float_y
		
		# Brillo pulsante del núcleo
		var core = coin_visual.get_node_or_null("Core")
		if core and core.get_surface_override_material(0):
			var mat = core.get_surface_override_material(0)
			var pulse = 2.0 + sin((time["second"] + float_offset) * 3.0) * 0.8
			mat.emission_energy = pulse

# ============================================================
# DETECCIÓN DE COLISIÓN
# ============================================================
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		# Sonido de moneda
		play_coin_sound()
	if is_collected:
		return
	
	if not body.is_in_group("Player"):
		return
	
	collect_coin()

# ============================================================
# RECOLECCIÓN
# ============================================================
func collect_coin() -> void:
	if is_collected:
		return
	
	is_collected = true
	print("💰 NÚCLEO RECOGIDO: +", coin_value)
	
	# Notificar al GameManager
	var game_manager = get_game_manager()
	if game_manager and game_manager.has_method("add_coins"):
		game_manager.add_coins(coin_value)
	
	# Animación de recolección
	disappear()

# Sonido de moneda
	play_coin_sound()

func play_coin_sound() -> void:
	var stream = load("res://assets/audio/ui/coin_pickup.wav")
	if stream == null:
		return
	
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.volume_db = -5.0
	audio_player.pitch_scale = randf_range(1.0, 1.2)
	
	audio_player.finished.connect(func(): audio_player.queue_free())
	get_tree().get_root().add_child(audio_player)
	
	audio_player.play()

# ============================================================
# DESAPARICIÓN
# ============================================================
func disappear() -> void:
	set_deferred("monitoring", false)
	
	var coin_visual = get_node_or_null("CoinVisual")
	var target = coin_visual if coin_visual else self
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tween.tween_property(self, "position:y", position.y + 1.5, 0.25)
	
	# Desvanecer la luz
	var light = coin_visual.get_node_or_null("CoinLight") if coin_visual else null
	if light:
		tween.tween_property(light, "light_energy", 0.0, 0.25)
	
	await tween.finished
	
	if is_instance_valid(self):
		queue_free()

# ============================================================
# BUSCAR GAME MANAGER
# ============================================================
func get_game_manager() -> Node:
	var autoload = get_node_or_null("/root/GameManager")
	if autoload != null and is_instance_valid(autoload):
		return autoload
	
	var gm = get_tree().get_first_node_in_group("GameManager")
	if gm != null and is_instance_valid(gm):
		return gm
	
	return null

func set_value(val: int) -> void:
	coin_value = val
