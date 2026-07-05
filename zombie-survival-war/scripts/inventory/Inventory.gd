extends CanvasLayer

# ============================================================
# INVENTORY - Panel sencillo de inventario
# ============================================================

var is_open: bool = false

# Referencias
var player: Node3D = null
var weapon_system: Node = null
var game_manager: Node = null

# Contadores
var medkit_count: int = 0

# UI Elements
var inventory_panel: Panel
var slots_container: GridContainer
var weapon_slot: Control
var ammo_slot: Control
var medkit_slot: Control
var coin_slot: Control

func _ready() -> void:
	# Buscar referencias
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		player = get_tree().get_root().find_child("Player", true, false)
	
	game_manager = get_node_or_null("/root/GameManager")
	
	# Crear UI
	create_inventory_ui()
	
	# Ocultar al inicio
	inventory_panel.visible = false
	
	print("Inventario listo")

func create_inventory_ui() -> void:
	# Panel principal del inventario
	inventory_panel = Panel.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.anchor_left = 0.5
	inventory_panel.anchor_top = 0.5
	inventory_panel.anchor_right = 0.5
	inventory_panel.anchor_bottom = 0.5
	inventory_panel.offset_left = -140
	inventory_panel.offset_top = -100
	inventory_panel.offset_right = 140
	inventory_panel.offset_bottom = 100
	inventory_panel.custom_minimum_size = Vector2(280, 200)
	
	# Fondo del panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.05, 0.9)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.3, 0.3)
	inventory_panel.add_theme_stylebox_override("panel", panel_style)
	
	add_child(inventory_panel)
	
	# Titulo
	var title = Label.new()
	title.name = "Title"
	title.text = "INVENTARIO"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.anchor_top = 0.0
	title.anchor_bottom = 0.0
	title.offset_top = 8
	title.offset_bottom = 32
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	inventory_panel.add_child(title)
	
	# Grid de slots
	slots_container = GridContainer.new()
	slots_container.name = "SlotsContainer"
	slots_container.columns = 2
	slots_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	slots_container.offset_left = 10
	slots_container.offset_top = 40
	slots_container.offset_right = -10
	slots_container.offset_bottom = -10
	inventory_panel.add_child(slots_container)
	
	# Crear los 4 slots
	weapon_slot = create_slot("ARMA", "pistol")
	ammo_slot = create_slot("MUNICION", "ammo")
	medkit_slot = create_slot("BOTIQUINES", "medkit")
	coin_slot = create_slot("MONEDAS", "coin")
	
	slots_container.add_child(weapon_slot)
	slots_container.add_child(ammo_slot)
	slots_container.add_child(medkit_slot)
	slots_container.add_child(coin_slot)

func create_slot(label_text: String, icon_type: String) -> Control:
	var slot = Control.new()
	slot.custom_minimum_size = Vector2(120, 70)
	
	# Fondo del slot
	var bg = Panel.new()
	bg.name = "SlotBG"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg.add_theme_stylebox_override("panel", bg_style)
	slot.add_child(bg)
	
	# Icono
	var icon = create_icon(icon_type)
	icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	icon.offset_left = 8
	icon.offset_top = 8
	icon.offset_right = 32
	icon.offset_bottom = 32
	slot.add_child(icon)
	
	# Label del tipo
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.text = label_text
	type_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	type_label.offset_left = 40
	type_label.offset_top = 8
	type_label.offset_right = 110
	type_label.offset_bottom = 24
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	slot.add_child(type_label)
	
	# Label del valor
	var value_label = Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "0"
	value_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	value_label.offset_left = 40
	value_label.offset_top = 28
	value_label.offset_right = 110
	value_label.offset_bottom = 50
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", Color(1, 1, 1))
	slot.add_child(value_label)
	
	return slot

func create_icon(type: String) -> Control:
	var icon = Control.new()
	icon.custom_minimum_size = Vector2(24, 24)
	
	match type:
		"pistol":
			# Forma de pistola (rectangulo con mango)
			var body = Polygon2D.new()
			body.polygon = PackedVector2Array([
				Vector2(4, 8), Vector2(20, 8), Vector2(20, 14), Vector2(4, 14)
			])
			body.color = Color(0.6, 0.6, 0.6)
			icon.add_child(body)
			
			var handle = Polygon2D.new()
			handle.polygon = PackedVector2Array([
				Vector2(8, 14), Vector2(14, 14), Vector2(12, 22), Vector2(6, 22)
			])
			handle.color = Color(0.4, 0.3, 0.2)
			icon.add_child(handle)
			
		"ammo":
			# Bala (rectangulo dorado)
			var bullet = Polygon2D.new()
			bullet.polygon = PackedVector2Array([
				Vector2(10, 4), Vector2(16, 4), Vector2(16, 20), Vector2(10, 20)
			])
			bullet.color = Color(1.0, 0.8, 0.0)
			icon.add_child(bullet)
			
			var tip = Polygon2D.new()
			tip.polygon = PackedVector2Array([
				Vector2(10, 4), Vector2(13, 0), Vector2(16, 4)
			])
			tip.color = Color(0.8, 0.6, 0.0)
			icon.add_child(tip)
			
		"medkit":
			# Cruz roja
			var cross_v = Polygon2D.new()
			cross_v.polygon = PackedVector2Array([
				Vector2(10, 4), Vector2(14, 4), Vector2(14, 20), Vector2(10, 20)
			])
			cross_v.color = Color(0.9, 0.1, 0.1)
			icon.add_child(cross_v)
			
			var cross_h = Polygon2D.new()
			cross_h.polygon = PackedVector2Array([
				Vector2(4, 10), Vector2(20, 10), Vector2(20, 14), Vector2(4, 14)
			])
			cross_h.color = Color(0.9, 0.1, 0.1)
			icon.add_child(cross_h)
			
		"coin":
			# Circulo dorado
			var coin = Polygon2D.new()
			var points = PackedVector2Array()
			for i in range(16):
				var angle = (i / 16.0) * TAU
				points.append(Vector2(12 + cos(angle) * 10, 12 + sin(angle) * 10))
			coin.polygon = points
			coin.color = Color(1.0, 0.85, 0.15)
			icon.add_child(coin)
			
			var inner = Polygon2D.new()
			var inner_points = PackedVector2Array()
			for i in range(16):
				var angle = (i / 16.0) * TAU
				inner_points.append(Vector2(12 + cos(angle) * 6, 12 + sin(angle) * 6))
			inner.polygon = inner_points
			inner.color = Color(1.0, 0.95, 0.4)
			icon.add_child(inner)
	
	return icon

func toggle_inventory() -> void:
	is_open = not is_open
	inventory_panel.visible = is_open
	
	if is_open:
		update_inventory()
		print("Inventario ABIERTO")
	else:
		print("Inventario CERRADO")

func update_inventory() -> void:
	# Actualizar cada slot
	update_weapon_slot()
	update_ammo_slot()
	update_medkit_slot()
	update_coin_slot()

func update_weapon_slot() -> void:
	var value_label = weapon_slot.get_node("ValueLabel")
	if player and player.has_node("WeaponSystem"):
		var ws = player.get_node("WeaponSystem")
		if ws and ws.current_weapon and ws.current_weapon.weapon_data:
			var weapon_name = ws.current_weapon.weapon_data.weapon_name
			value_label.text = weapon_name
		else:
			value_label.text = "Pistola"
	else:
		value_label.text = "Pistola"

func update_ammo_slot() -> void:
	var value_label = ammo_slot.get_node("ValueLabel")
	if player and player.has_node("WeaponSystem"):
		var ws = player.get_node("WeaponSystem")
		if ws and ws.current_weapon:
			var weapon = ws.current_weapon
			var current = 0
			var total = 0
			
			if "current_ammo" in weapon:
				current = weapon.current_ammo
			if "total_ammo" in weapon:
				total = weapon.total_ammo
			
			value_label.text = str(current) + " / " + str(total)
		else:
			value_label.text = "-- / --"
	else:
		value_label.text = "-- / --"

func update_medkit_slot() -> void:
	var value_label = medkit_slot.get_node("ValueLabel")
	value_label.text = str(medkit_count)

func update_coin_slot() -> void:
	var value_label = coin_slot.get_node("ValueLabel")
	if game_manager:
		value_label.text = str(game_manager.get_total_coins())
	else:
		value_label.text = "0"

# ============================================================
# AGREGAR BOTIQUIN AL INVENTARIO
# ============================================================
func add_medkit(amount: int = 1) -> void:
	medkit_count += amount
	print("Botiquines: +", amount, " | Total: ", medkit_count)
	if is_open:
		update_medkit_slot()

# ============================================================
# USAR BOTIQUIN
# ============================================================
func use_medkit() -> void:
	if medkit_count <= 0:
		print("No hay botiquines")
		return
	
	if player and player.has_method("heal"):
		player.heal(25)
		medkit_count -= 1
		print("Botiquin usado | Restantes: ", medkit_count)
		if is_open:
			update_medkit_slot()
	else:
		print("No se pudo usar botiquin")
