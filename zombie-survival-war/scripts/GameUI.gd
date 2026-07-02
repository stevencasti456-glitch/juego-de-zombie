extends CanvasLayer

# ============================================================
# HUD MODERNO - FASE 2.7 (CORREGIDO v2)
# ============================================================

var health_bar: ProgressBar
var health_label: Label
var zombies_icon: Control
var wave_icon: Control
var nucleo_icon: Control
var crosshair: Control

var current_health: int = 100
var max_health: int = 100
var current_zombies: int = 0
var current_wave: int = 1
var current_nucleos: int = 0
var target_nucleos: int = 0

var nucleo_animation_active: bool = false
var nucleo_animation_speed: float = 10.0

# Referencia al jugador
var player: Node3D

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	# Buscar jugador
	player = get_node_or_null("/root/Main/Player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		current_health = player.health
		max_health = player.max_health

	create_health_bar()
	create_counters()
	create_crosshair()

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.coins_changed.connect(_on_coins_changed)
		gm.wave_started.connect(_on_wave_started)
		gm.zombie_killed.connect(_on_zombie_killed)
		gm.wave_completed.connect(_on_wave_completed)

# ============================================================
# BARRA DE VIDA - ABAJO CENTRADA CON ANCLAJES
# ============================================================
func create_health_bar() -> void:
	var container = Control.new()
	container.name = "HealthContainer"
	container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	container.anchor_left = 0.2
	container.anchor_top = 1.0
	container.anchor_right = 0.8
	container.anchor_bottom = 1.0
	container.offset_left = 0
	container.offset_top = -38
	container.offset_right = 0
	container.offset_bottom = -8
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(container)

	# Icono de corazón
	var heart_icon = create_heart_icon()
	heart_icon.name = "HealthIcon"
	heart_icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	heart_icon.offset_left = 6
	heart_icon.offset_top = -10
	heart_icon.offset_right = 30
	heart_icon.offset_bottom = 10
	container.add_child(heart_icon)

	# Barra de vida
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	health_bar.offset_left = 36
	health_bar.offset_top = 4
	health_bar.offset_right = -10
	health_bar.offset_bottom = -4
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.05, 0.6)
	bg_style.corner_radius_top_left = 10
	bg_style.corner_radius_top_right = 10
	bg_style.corner_radius_bottom_left = 10
	bg_style.corner_radius_bottom_right = 10
	health_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.8, 0.2)
	fill_style.corner_radius_top_left = 10
	fill_style.corner_radius_top_right = 10
	fill_style.corner_radius_bottom_left = 10
	fill_style.corner_radius_bottom_right = 10
	health_bar.add_theme_stylebox_override("fill", fill_style)
	container.add_child(health_bar)
	
	# NO agregamos Label con números - solo la barra visual

func create_heart_icon() -> Control:
	var icon = Control.new()
	icon.custom_minimum_size = Vector2(24, 24)

	var heart = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(12, 6),
		Vector2(18, 2),
		Vector2(22, 6),
		Vector2(22, 12),
		Vector2(12, 22),
		Vector2(2, 12),
		Vector2(2, 6),
		Vector2(6, 2)
	])
	heart.polygon = points
	heart.color = Color(0.9, 0.1, 0.1)
	icon.add_child(heart)
	return icon

# ============================================================
# CONTADORES - ARRIBA SEPARADOS SIN SOLAPARSE
# ============================================================
func create_counters() -> void:
	# Panel contenedor
	var top_panel = Control.new()
	top_panel.name = "TopPanel"
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.anchor_left = 0.0
	top_panel.anchor_top = 0.0
	top_panel.anchor_right = 1.0
	top_panel.anchor_bottom = 0.0
	top_panel.offset_top = 8
	top_panel.offset_bottom = 48
	top_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(top_panel)

	# Zombies (izquierda)
	zombies_icon = create_counter_icon("skull")
	zombies_icon.name = "ZombiesCounter"
	zombies_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	zombies_icon.offset_left = 12
	zombies_icon.offset_top = 0
	zombies_icon.offset_right = 90
	zombies_icon.offset_bottom = 40
	top_panel.add_child(zombies_icon)

	# Wave (centro)
	wave_icon = create_counter_icon("shield")
	wave_icon.name = "WaveCounter"
	wave_icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_icon.offset_left = -45
	wave_icon.offset_top = 0
	wave_icon.offset_right = 45
	wave_icon.offset_bottom = 40
	top_panel.add_child(wave_icon)

	# Nucleos (derecha)
	nucleo_icon = create_nucleo_counter()
	nucleo_icon.name = "NucleoCounter"
	nucleo_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	nucleo_icon.offset_left = -90
	nucleo_icon.offset_top = 0
	nucleo_icon.offset_right = -12
	nucleo_icon.offset_bottom = 40
	top_panel.add_child(nucleo_icon)

func create_counter_icon(type: String) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 40)

	# Icono
	var icon = create_icon(type)
	icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = 36
	icon.offset_bottom = 36
	container.add_child(icon)

	# Número (solo el número, sin texto tipo)
	var num_label = Label.new()
	num_label.name = "NumberLabel"
	num_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	num_label.offset_left = -42
	num_label.offset_top = 2
	num_label.offset_right = -4
	num_label.offset_bottom = 38
	num_label.add_theme_font_size_override("font_size", 24)
	num_label.add_theme_color_override("font_color", Color(1, 1, 1))
	num_label.text = "0"
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(num_label)

	return container

func create_icon(type: String) -> Control:
	var icon = Control.new()
	icon.custom_minimum_size = Vector2(32, 32)

	if type == "skull":
		var skull = Polygon2D.new()
		skull.polygon = PackedVector2Array([
			Vector2(16, 3), Vector2(23, 7), Vector2(26, 16),
			Vector2(23, 23), Vector2(16, 27), Vector2(9, 23),
			Vector2(6, 16), Vector2(9, 7)
		])
		skull.color = Color(0.75, 0.75, 0.75)
		icon.add_child(skull)

		var eye_left = Polygon2D.new()
		eye_left.polygon = PackedVector2Array([
			Vector2(11, 13), Vector2(14, 13), Vector2(14, 16), Vector2(11, 16)
		])
		eye_left.color = Color(0.1, 0.1, 0.1)
		icon.add_child(eye_left)

		var eye_right = Polygon2D.new()
		eye_right.polygon = PackedVector2Array([
			Vector2(18, 13), Vector2(21, 13), Vector2(21, 16), Vector2(18, 16)
		])
		eye_right.color = Color(0.1, 0.1, 0.1)
		icon.add_child(eye_right)

	elif type == "shield":
		var shield = Polygon2D.new()
		shield.polygon = PackedVector2Array([
			Vector2(16, 2), Vector2(26, 7), Vector2(26, 18),
			Vector2(16, 28), Vector2(6, 18), Vector2(6, 7)
		])
		shield.color = Color(0.25, 0.55, 0.9)
		icon.add_child(shield)

	return icon

func create_nucleo_counter() -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 40)

	var icon = create_nucleo_icon()
	icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = 36
	icon.offset_bottom = 36
	container.add_child(icon)

	var label = Label.new()
	label.name = "NucleoLabel"
	label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	label.offset_left = -42
	label.offset_top = 2
	label.offset_right = -4
	label.offset_bottom = 38
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.15))
	label.text = "0"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	return container

func create_nucleo_icon() -> Control:
	var icon = Control.new()
	icon.custom_minimum_size = Vector2(32, 32)

	var outer_ring = Polygon2D.new()
	var outer_points = PackedVector2Array()
	for i in range(32):
		var angle = (i / 32.0) * TAU
		outer_points.append(Vector2(16 + cos(angle) * 15, 16 + sin(angle) * 15))
	outer_ring.polygon = outer_points
	outer_ring.color = Color(0.75, 0.75, 0.8)
	icon.add_child(outer_ring)

	var glow = Polygon2D.new()
	var glow_points = PackedVector2Array()
	for i in range(32):
		var angle = (i / 32.0) * TAU
		glow_points.append(Vector2(16 + cos(angle) * 12, 16 + sin(angle) * 12))
	glow.polygon = glow_points
	glow.color = Color(1, 0.9, 0.3, 0.4)
	icon.add_child(glow)

	var hexagon = Polygon2D.new()
	var hex_points = PackedVector2Array()
	for i in range(6):
		var angle = (i / 6.0) * TAU - PI / 6
		hex_points.append(Vector2(16 + cos(angle) * 9, 16 + sin(angle) * 9))
	hexagon.polygon = hex_points
	hexagon.color = Color(1, 0.6, 0.0)
	icon.add_child(hexagon)

	var core = Polygon2D.new()
	var core_points = PackedVector2Array()
	for i in range(32):
		var angle = (i / 32.0) * TAU
		core_points.append(Vector2(16 + cos(angle) * 4, 16 + sin(angle) * 4))
	core.polygon = core_points
	core.color = Color(1, 0.95, 0.5)
	icon.add_child(core)

	return icon

# ============================================================
# CROSSHAIR - CENTRADA CON ANCLAJES
# ============================================================
func create_crosshair() -> Control:
	crosshair = Control.new()
	crosshair.name = "Crosshair"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -12
	crosshair.offset_top = -12
	crosshair.offset_right = 12
	crosshair.offset_bottom = 12
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	crosshair.z_index = 100
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)

	# Punto central blanco
	var dot = ColorRect.new()
	dot.name = "Dot"
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -2
	dot.offset_top = -2
	dot.offset_right = 2
	dot.offset_bottom = 2
	dot.color = Color(1, 1, 1, 0.95)
	crosshair.add_child(dot)

	# Círculo sutil
	var circle = Polygon2D.new()
	var circle_points = PackedVector2Array()
	for i in range(32):
		var angle = (i / 32.0) * TAU
		circle_points.append(Vector2(12 + cos(angle) * 8, 12 + sin(angle) * 8))
	circle.polygon = circle_points
	circle.color = Color(1, 1, 1, 0.25)
	crosshair.add_child(circle)

	return crosshair

# ============================================================
# ACTUALIZAR DATOS
# ============================================================
func update_health_display() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	# Eliminado: health_label.text = ...

	var fill_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		var health_percent = float(current_health) / max_health
		if health_percent > 0.6:
			fill_style.bg_color = Color(0.2, 0.8, 0.2)
		elif health_percent > 0.3:
			fill_style.bg_color = Color(0.9, 0.8, 0.1)
		else:
			fill_style.bg_color = Color(0.9, 0.1, 0.1)

func update_zombies(count: int) -> void:
	current_zombies = count
	if zombies_icon and zombies_icon.has_node("NumberLabel"):
		zombies_icon.get_node("NumberLabel").text = str(count)

func update_wave(wave: int) -> void:
	current_wave = wave
	if wave_icon and wave_icon.has_node("NumberLabel"):
		wave_icon.get_node("NumberLabel").text = str(wave)

func update_nucleos(amount: int) -> void:
	target_nucleos = amount
	if not nucleo_animation_active:
		nucleo_animation_active = true

# ============================================================
# SEÑALES
# ============================================================
func _on_player_health_changed(new_health: int, new_max: int) -> void:
	current_health = new_health
	max_health = new_max
	update_health_display()

func _on_coins_changed(new_amount: int) -> void:
	update_nucleos(new_amount)

func _on_wave_started(wave_number: int, _zombie_count: int) -> void:
	update_wave(wave_number)

# ============================================================
# ANIMACIÓN DE MONEDAS
# ============================================================
func _process(delta: float) -> void:
	if nucleo_animation_active and nucleo_icon:
		var label = nucleo_icon.get_node("NucleoLabel")
		if label:
			var diff = target_nucleos - current_nucleos
			if abs(diff) < 1:
				current_nucleos = target_nucleos
				label.text = str(current_nucleos)
				nucleo_animation_active = false
			else:
				current_nucleos += diff * nucleo_animation_speed * delta
				label.text = str(int(current_nucleos))

func _on_zombie_killed(total_killed: int) -> void:
	update_zombies(total_killed)

func _on_wave_completed(wave_number: int) -> void:
	# Opcional: mostrar algún feedback visual de oleada completada
	print("Oleada ", wave_number, " completada - UI notificada")
