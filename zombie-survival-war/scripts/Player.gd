extends CharacterBody3D

signal health_changed(new_health: int, new_max: int)
signal player_died

@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 8.0
@export var SENSITIVITY: float = 0.005
@export var CAMERA_DISTANCE: float = 8.0
@export var CAMERA_HEIGHT: float = 4.0

@export var max_health: int = 100
var health: int = 100

var footstep_timer: float = 0.0
var footstep_interval: float = 0.4  # Segundos entre pasos

var camera: Camera3D
var camera_pivot: Node3D
var mesh_instance: Node3D
var weapon_system: WeaponSystem
var animator: PlayerAnimator = null

var is_crouching: bool = false
var is_dead: bool = false

var recoil_offset: Vector3 = Vector3.ZERO
var recoil_recovery_speed: float = 5.0

var move_input: Vector2 = Vector2.ZERO
var touch_look_input: Vector2 = Vector2.ZERO
var left_finger_index: int = -1
var right_finger_index: int = -1
var left_joystick_center: Vector2 = Vector2.ZERO

var jump_btn: Button
var crouch_btn: Button
var shoot_btn: Button

func _ready() -> void:
	velocity = Vector3.ZERO
	health = max_health
	camera = get_node("CameraPivot/Camera3D")
	camera_pivot = get_node("CameraPivot")
	create_humanoid_character()
	setup_weapon_system()
	setup_touch_controls()
	
	# Inicializar animador
	animator = PlayerAnimator.new(self)
	animator.setup()

func setup_weapon_system() -> void:
	print("=== CREANDO ARMA DIRECTAMENTE ===")
	
	# 1. Crear WeaponSystem
	weapon_system = WeaponSystem.new()
	weapon_system.name = "WeaponSystem"
	add_child(weapon_system)
	
	# 2. Crear punto de salida de balas
	var muzzle = Marker3D.new()
	muzzle.name = "MuzzlePoint"
	muzzle.position = Vector3(0.3, 1.35, 0.55)
	add_child(muzzle)
	
	weapon_system.muzzle_point = muzzle
	weapon_system.weapon_holder = muzzle
	
	# 3. Crear la pistola DIRECTAMENTE (sin .tscn)
	var pistol = Pistol.new()
	pistol.name = "Pistol"
	pistol.owner_player = self
	pistol.muzzle_point = muzzle
	
	# 4. Cargar datos del arma
	var data = load("res://data/weapons/pistol_data.tres")
	if data:
		pistol.weapon_data = data
		print("Datos cargados: ", data.weapon_name)
	else:
		push_warning("No se encontraron datos del arma, usando defaults")
	
	# 5. Añadir al weapon system
	muzzle.add_child(pistol)
	weapon_system.current_weapon = pistol
	weapon_system.weapons.append(pistol)
	
	# 6. Conectar señal de municion al HUD
	pistol.ammo_changed.connect(_on_ammo_updated)
	
	print("=== ARMA LISTA ===")
	print("Nombre: ", pistol.weapon_data.weapon_name if pistol.weapon_data else "sin datos")
	print("Municion: ", pistol.current_ammo, "/", pistol.total_ammo)

func create_humanoid_character() -> void:
	var old_mesh = get_node_or_null("MeshInstance3D")
	if old_mesh:
		remove_child(old_mesh)
		old_mesh.free()
	
	var old_model = get_node_or_null("CharacterModel")
	if old_model:
		remove_child(old_model)
		old_model.free()

	var character = Node3D.new()
	character.name = "CharacterModel"
	add_child(character)

	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.9, 0.7, 0.5)
	skin_mat.roughness = 0.8

	var shirt_mat = StandardMaterial3D.new()
	shirt_mat.albedo_color = Color(0.2, 0.3, 0.5)
	shirt_mat.roughness = 0.7

	var pants_mat = StandardMaterial3D.new()
	pants_mat.albedo_color = Color(0.15, 0.15, 0.2)
	pants_mat.roughness = 0.9

	var boots_mat = StandardMaterial3D.new()
	boots_mat.albedo_color = Color(0.1, 0.08, 0.05)
	boots_mat.roughness = 0.6

	# Cabeza
	var head = MeshInstance3D.new()
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	head.mesh = head_mesh
	head.set_surface_override_material(0, skin_mat)
	head.position = Vector3(0, 1.7, 0)
	character.add_child(head)

	# Torso
	var torso = MeshInstance3D.new()
	var torso_mesh = CapsuleMesh.new()
	torso_mesh.radius = 0.3
	torso_mesh.height = 0.8
	torso.mesh = torso_mesh
	torso.set_surface_override_material(0, shirt_mat)
	torso.position = Vector3(0, 1.0, 0)
	character.add_child(torso)

	# Brazos
	var arm_mesh = CylinderMesh.new()
	arm_mesh.top_radius = 0.08
	arm_mesh.bottom_radius = 0.07
	arm_mesh.height = 0.7

	var left_arm = MeshInstance3D.new()
	left_arm.mesh = arm_mesh
	left_arm.set_surface_override_material(0, skin_mat)
	left_arm.position = Vector3(-0.4, 1.2, 0)
	left_arm.rotation.z = 0.2
	character.add_child(left_arm)

	var right_arm = MeshInstance3D.new()
	right_arm.mesh = arm_mesh
	right_arm.set_surface_override_material(0, skin_mat)
	right_arm.position = Vector3(0.4, 1.2, 0)
	right_arm.rotation.z = -0.2
	character.add_child(right_arm)

	# Piernas
	var leg_mesh = CylinderMesh.new()
	leg_mesh.top_radius = 0.12
	leg_mesh.bottom_radius = 0.1
	leg_mesh.height = 0.9

	var left_leg = MeshInstance3D.new()
	left_leg.mesh = leg_mesh
	left_leg.set_surface_override_material(0, pants_mat)
	left_leg.position = Vector3(-0.15, 0.45, 0)
	character.add_child(left_leg)

	var right_leg = MeshInstance3D.new()
	right_leg.mesh = leg_mesh
	right_leg.set_surface_override_material(0, pants_mat)
	right_leg.position = Vector3(0.15, 0.45, 0)
	character.add_child(right_leg)

	# Botas
	var boot_mesh = CylinderMesh.new()
	boot_mesh.top_radius = 0.11
	boot_mesh.bottom_radius = 0.13
	boot_mesh.height = 0.3

	var left_boot = MeshInstance3D.new()
	left_boot.mesh = boot_mesh
	left_boot.set_surface_override_material(0, boots_mat)
	left_boot.position = Vector3(-0.15, 0.15, 0)
	character.add_child(left_boot)

	var right_boot = MeshInstance3D.new()
	right_boot.mesh = boot_mesh
	right_boot.set_surface_override_material(0, boots_mat)
	right_boot.position = Vector3(0.15, 0.15, 0)
	character.add_child(right_boot)

	# Cargar modelo de pistola
	var pistol_model = load("res://scenes/weapons/PistolModel.tscn")
	if pistol_model:
		var pistol_instance = pistol_model.instantiate()
		pistol_instance.name = "VisualWeapon"
		pistol_instance.position = Vector3(0.3, 1.3, 0.3)
		pistol_instance.rotation.y = -0.2
		character.add_child(pistol_instance)
		print("Player: Modelo de pistola cargado")
	else:
		push_warning("Player: No se pudo cargar PistolModel.tscn")

	mesh_instance = character

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if not is_on_floor():
		velocity.y -= 15.0 * delta

	handle_input(delta)
	
	# Actualizar animaciones segun movimiento
	if animator:
		animator.update_animation(velocity, is_crouching)
	
	move_and_slide()
	update_camera(delta)

 # Sonido de pasos
	handle_footsteps(delta)
	
	move_and_slide()
	update_camera(delta)

func handle_input(_delta: float) -> void:
	var input_dir = Vector3.ZERO

	if move_input.length() > 0:
		input_dir.x = move_input.x
		input_dir.z = move_input.y
	else:
		input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_dir.z = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")

	var input_magnitude = input_dir.length()
	if input_magnitude > 0:
		input_dir = input_dir.normalized()

	var joystick_intensity = minf(move_input.length(), 1.0) if move_input.length() > 0 else 1.0

	var speed_multiplier
	if joystick_intensity < 0.5:
		speed_multiplier = 0.4 + (joystick_intensity * 0.4)
	else:
		speed_multiplier = 0.6 + ((joystick_intensity - 0.5) * 0.8)

	var current_speed = SPEED * speed_multiplier

	var camera_forward = -camera.global_transform.basis.z
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()

	var camera_right = camera.global_transform.basis.x
	camera_right.y = 0
	camera_right = camera_right.normalized()

	var direction = (camera_forward * -input_dir.z + camera_right * input_dir.x).normalized()

	velocity.x = move_toward(velocity.x, direction.x * current_speed, SPEED * 0.08)
	velocity.z = move_toward(velocity.z, direction.z * current_speed, SPEED * 0.08)

	if Input.is_action_just_pressed("reload"):
		if weapon_system:
			weapon_system.reload()

func update_camera(delta: float) -> void:
	if camera_pivot:
		var target_pos = global_position + Vector3(0, CAMERA_HEIGHT, 0)
		camera_pivot.global_position = camera_pivot.global_position.lerp(target_pos, 0.12)
		recoil_offset = recoil_offset.lerp(Vector3.ZERO, recoil_recovery_speed * delta)
		camera_pivot.position += recoil_offset

func apply_weapon_recoil(strength: float) -> void:
	recoil_offset.z -= strength * 0.5
	recoil_offset.y += strength * 0.2
	if OS.has_feature("android"):
		Input.vibrate_handheld(int(strength * 50))

func setup_touch_controls() -> void:
	var ui = get_node_or_null("UI")
	if not ui:
		return

	var old_panel = ui.get_node_or_null("RightControlPanel")
	if old_panel:
		old_panel.queue_free()
		await get_tree().process_frame

	for old_name in ["JumpButton", "CrouchButton", "ShootButton", "ReloadButton"]:
		var old = ui.get_node_or_null(old_name)
		if old:
			old.free()

	var panel = Control.new()
	panel.name = "RightControlPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -210
	panel.offset_top = -380
	panel.offset_right = -10
	panel.offset_bottom = -10
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(panel)

	shoot_btn = create_action_button("ShootButton", "", Color(0.8, 0.2, 0.2))
	# BOTON DE DISPARO CON CONTADOR DE MUNICION
	shoot_btn = Button.new()
	shoot_btn.name = "ShootButton"
	shoot_btn.custom_minimum_size = Vector2(90, 90)
	shoot_btn.size = Vector2(90, 90)
	
	# Fondo del boton
	var shoot_normal = StyleBoxFlat.new()
	shoot_normal.bg_color = Color(0.8, 0.2, 0.2)
	shoot_normal.bg_color.a = 0.6
	shoot_normal.corner_radius_top_left = 15
	shoot_normal.corner_radius_top_right = 15
	shoot_normal.corner_radius_bottom_left = 15
	shoot_normal.corner_radius_bottom_right = 15
	shoot_btn.add_theme_stylebox_override("normal", shoot_normal)
	
	var shoot_hover = StyleBoxFlat.new()
	shoot_hover.bg_color = Color(0.8, 0.2, 0.2)
	shoot_hover.bg_color.a = 0.8
	shoot_hover.corner_radius_top_left = 15
	shoot_hover.corner_radius_top_right = 15
	shoot_hover.corner_radius_bottom_left = 15
	shoot_hover.corner_radius_bottom_right = 15
	shoot_btn.add_theme_stylebox_override("hover", shoot_hover)
	
	var shoot_pressed = StyleBoxFlat.new()
	shoot_pressed.bg_color = Color(0.8, 0.2, 0.2)
	shoot_pressed.bg_color.a = 1.0
	shoot_pressed.corner_radius_top_left = 15
	shoot_pressed.corner_radius_top_right = 15
	shoot_pressed.corner_radius_bottom_left = 15
	shoot_pressed.corner_radius_bottom_right = 15
	shoot_btn.add_theme_stylebox_override("pressed", shoot_pressed)
	
	# TEXTO DEL BOTON
	shoot_btn.add_theme_font_size_override("font_size", 22)
	shoot_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	shoot_btn.text = "FIRE\n12/12"
	
	shoot_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	shoot_btn.pressed.connect(_on_shoot_button_pressed)
	
	shoot_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	shoot_btn.anchor_left = 1.0
	shoot_btn.anchor_top = 1.0
	shoot_btn.anchor_right = 1.0
	shoot_btn.anchor_bottom = 1.0
	shoot_btn.offset_left = -100
	shoot_btn.offset_top = -100
	shoot_btn.offset_right = 0
	shoot_btn.offset_bottom = 0
	panel.add_child(shoot_btn)

	var reload_btn = create_action_button("ReloadButton", "🔄", Color(0.2, 0.6, 0.3))
	reload_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	reload_btn.anchor_left = 1.0
	reload_btn.anchor_top = 1.0
	reload_btn.anchor_right = 1.0
	reload_btn.anchor_bottom = 1.0
	reload_btn.offset_left = -100
	reload_btn.offset_top = -200
	reload_btn.offset_right = 0
	reload_btn.offset_bottom = -110
	reload_btn.pressed.connect(_on_reload_button_pressed)
	panel.add_child(reload_btn)

	jump_btn = create_action_button("JumpButton", "⬆", Color(0.2, 0.5, 0.8))
	jump_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_btn.anchor_left = 1.0
	jump_btn.anchor_top = 1.0
	jump_btn.anchor_right = 1.0
	jump_btn.anchor_bottom = 1.0
	jump_btn.offset_left = -100
	jump_btn.offset_top = -290
	jump_btn.offset_right = 0
	jump_btn.offset_bottom = -200
	panel.add_child(jump_btn)

	crouch_btn = create_action_button("CrouchButton", "⬇", Color(0.3, 0.3, 0.3))
	crouch_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	crouch_btn.anchor_left = 1.0
	crouch_btn.anchor_top = 1.0
	crouch_btn.anchor_right = 1.0
	crouch_btn.anchor_bottom = 1.0
	crouch_btn.offset_left = -200
	crouch_btn.offset_top = -100
	crouch_btn.offset_right = -110
	crouch_btn.offset_bottom = 0
	panel.add_child(crouch_btn)

	# Boton de inventario
	var inv_btn = Button.new()
	inv_btn.name = "InventoryButton"
	inv_btn.text = "🎒"
	inv_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inv_btn.anchor_left = 1.0
	inv_btn.anchor_right = 1.0
	inv_btn.offset_left = -60
	inv_btn.offset_top = 70
	inv_btn.offset_right = -10
	inv_btn.offset_bottom = 120
	inv_btn.add_theme_font_size_override("font_size", 28)
	
	var inv_style = StyleBoxFlat.new()
	inv_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	inv_style.corner_radius_top_left = 10
	inv_style.corner_radius_top_right = 10
	inv_style.corner_radius_bottom_left = 10
	inv_style.corner_radius_bottom_right = 10
	inv_btn.add_theme_stylebox_override("normal", inv_style)
	
	inv_btn.pressed.connect(_on_inventory_pressed)
	ui.add_child(inv_btn)

func create_action_button(name: String, text_label: String, bg_color: Color) -> Button:
	var btn = Button.new()
	btn.name = name
	btn.text = text_label
	btn.custom_minimum_size = Vector2(90, 90)
	btn.size = Vector2(90, 90)

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = bg_color
	normal_style.bg_color.a = 0.6
	normal_style.corner_radius_top_left = 15
	normal_style.corner_radius_top_right = 15
	normal_style.corner_radius_bottom_left = 15
	normal_style.corner_radius_bottom_right = 15
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = bg_color
	hover_style.bg_color.a = 0.8
	hover_style.corner_radius_top_left = 15
	hover_style.corner_radius_top_right = 15
	hover_style.corner_radius_bottom_left = 15
	hover_style.corner_radius_bottom_right = 15
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = bg_color
	pressed_style.bg_color.a = 1.0
	pressed_style.corner_radius_top_left = 15
	pressed_style.corner_radius_top_right = 15
	pressed_style.corner_radius_bottom_left = 15
	pressed_style.corner_radius_bottom_right = 15
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_font_size_override("font_size", 36)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.mouse_filter = Control.MOUSE_FILTER_PASS

	if name == "JumpButton":
		btn.pressed.connect(_on_jump_button_pressed)
	elif name == "CrouchButton":
		btn.button_down.connect(_on_crouch_button_button_down)
		btn.button_up.connect(_on_crouch_button_button_up)
	elif name == "ShootButton":
		btn.pressed.connect(_on_shoot_button_pressed)

	return btn

func _on_jump_button_pressed() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY

func _on_crouch_button_button_down() -> void:
	if not is_crouching:
		is_crouching = true
		scale.y = 0.5

func _on_crouch_button_button_up() -> void:
	if is_crouching:
		is_crouching = false
		scale.y = 1.0

func _on_shoot_button_pressed() -> void:
	if weapon_system:
		weapon_system.fire()
		# Animacion de disparo
		if animator:
			animator.play_animation("shoot")

func _on_reload_button_pressed() -> void:
	if weapon_system:
		weapon_system.reload()
		# Animacion de recarga
		if animator:
			animator.play_animation("reload")

func take_damage(amount: int) -> void:
	if is_dead:
		return
	
	health -= amount
	if health < 0:
		health = 0

 # Sonido de daño
	play_hurt_sound()
	
	print("Jugador herido! Vida: ", health, "/", max_health)
	health_changed.emit(health, max_health)
	
	if health <= 0:
		die()

	print("Jugador herido! Vida: ", health, "/", max_health)
	health_changed.emit(health, max_health)

	if health <= 0:
		die()

func heal(amount: int) -> void:
	if is_dead:
		return
	
	health += amount
	if health > max_health:
		health = max_health
	
	print("Jugador curado: +", amount, " | Vida: ", health, "/", max_health)
	health_changed.emit(health, max_health)
	
	# Efecto visual de curacion (destello verde)
	flash_heal_effect()

func flash_heal_effect() -> void:
	# Destello verde breve en el personaje
	if mesh_instance:
		for child in mesh_instance.get_children():
			if child is MeshInstance3D and child.get_surface_override_material(0):
				var mat = child.get_surface_override_material(0)
				var original = mat.albedo_color
				mat.albedo_color = Color(0.2, 1.0, 0.2)
				await get_tree().create_timer(0.2).timeout
				mat.albedo_color = original

func die() -> void:
	is_dead = true
	print("JUGADOR MUERE")
	set_physics_process(false)
	player_died.emit()

	var tween = create_tween()
	tween.tween_property(self, "rotation:x", PI / 2, 0.5)
	await tween.finished

	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func get_health() -> int:
	return health

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.is_pressed():
			if is_touch_over_button(event.position):
				return

			if event.position.x <= get_viewport().size.x / 2 and left_finger_index == -1:
				left_finger_index = event.index
				left_joystick_center = event.position
			elif event.position.x > get_viewport().size.x / 2 and right_finger_index == -1:
				right_finger_index = event.index
		else:
			if event.index == right_finger_index:
				right_finger_index = -1
				touch_look_input = Vector2.ZERO
			elif event.index == left_finger_index:
				left_finger_index = -1
				move_input = Vector2.ZERO

	if event is InputEventScreenDrag:
		if event.index == right_finger_index:
			touch_look_input = event.relative
			rotate_y(-touch_look_input.x * SENSITIVITY)
			if camera_pivot:
				camera_pivot.rotate_x(-touch_look_input.y * SENSITIVITY)
				camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-45), deg_to_rad(30))
		elif event.index == left_finger_index:
			var drag_vector = event.position - left_joystick_center
			var max_range = 100.0
			move_input = drag_vector.limit_length(max_range) / max_range

func is_touch_over_button(pos: Vector2) -> bool:
	var ui = get_node_or_null("UI")
	if not ui:
		return false

	var panel = ui.get_node_or_null("RightControlPanel")
	if not panel:
		return false

	for child in panel.get_children():
		if child is Button:
			var btn = child as Button
			var global_pos = btn.global_position
			var rect = Rect2(global_pos, btn.size)
			if rect.has_point(pos):
				return true
	return false

func create_shoot_button() -> Button:
	var btn = Button.new()
	btn.name = "ShootButton"
	btn.custom_minimum_size = Vector2(90, 90)
	btn.size = Vector2(90, 90)
	
	# Fondo del boton
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.8, 0.2, 0.2)
	normal_style.bg_color.a = 0.6
	normal_style.corner_radius_top_left = 15
	normal_style.corner_radius_top_right = 15
	normal_style.corner_radius_bottom_left = 15
	normal_style.corner_radius_bottom_right = 15
	btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.8, 0.2, 0.2)
	hover_style.bg_color.a = 0.8
	hover_style.corner_radius_top_left = 15
	hover_style.corner_radius_top_right = 15
	hover_style.corner_radius_bottom_left = 15
	hover_style.corner_radius_bottom_right = 15
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.8, 0.2, 0.2)
	pressed_style.bg_color.a = 1.0
	pressed_style.corner_radius_top_left = 15
	pressed_style.corner_radius_top_right = 15
	pressed_style.corner_radius_bottom_left = 15
	pressed_style.corner_radius_bottom_right = 15
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	# TEXTO DEL BOTON: icono arriba, municion abajo
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.text = "🔫\n12/12"  # Icono + municion
	
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.pressed.connect(_on_shoot_button_pressed)
	
	return btn

func _on_ammo_updated(current: int, magazine: int, total: int, is_reloading: bool) -> void:
	if shoot_btn == null:
		return
	
	if is_reloading:
		shoot_btn.text = "FIRE\n..."
	else:
		# Mostrar: cargador / inventario
		shoot_btn.text = "FIRE\n" + str(current) + "/" + str(total)

func handle_footsteps(delta: float) -> void:
	var speed = Vector2(velocity.x, velocity.z).length()
	
	if speed < 0.5:
		footstep_timer = 0.0
		return
	
	# Ajustar intervalo segun velocidad
	var interval = footstep_interval
	if speed > 4.0:
		interval = 0.25  # Corriendo = pasos mas rapidos
	
	footstep_timer += delta
	
	if footstep_timer >= interval:
		footstep_timer = 0.0
		play_footstep_sound()

func play_footstep_sound() -> void:
	var stream = load("res://assets/audio/player/footstep.wav")
	if stream == null:
		return
	
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.volume_db = -10.0  # Mas bajo que el disparo
	audio_player.pitch_scale = randf_range(0.9, 1.1)  # Variacion aleatoria
	
	audio_player.finished.connect(func(): audio_player.queue_free())
	get_tree().get_root().add_child(audio_player)
	
	audio_player.play()

func play_hurt_sound() -> void:
	var stream = load("res://assets/audio/player/player_hurt.wav")
	if stream == null:
		return
	
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.volume_db = -2.0
	
	audio_player.finished.connect(func(): audio_player.queue_free())
	get_tree().get_root().add_child(audio_player)
	
	audio_player.play()

func _on_inventory_pressed() -> void:
	print("=== BOTON INVENTARIO PRESIONADO ===")
	
	# Intento 1: Ruta directa
	var inv1 = get_node_or_null("/root/Main/Inventory")
	print("Intento 1 (/root/Main/Inventory): ", inv1)
	
	# Intento 2: Desde el árbol de escenas
	var inv2 = get_tree().get_root().find_child("Inventory", true, false)
	print("Intento 2 (find_child): ", inv2)
	
	# Intento 3: Desde el nodo padre del jugador
	var inv3 = get_parent().get_node_or_null("Inventory")
	print("Intento 3 (get_parent): ", inv3)
	
	# Intento 4: Buscar en todos los nodos CanvasLayer
	var inv4 = null
	for child in get_tree().get_root().get_children():
		if child.name == "Inventory":
			inv4 = child
			break
	print("Intento 4 (bucle): ", inv4)
	
	# Usar el primero que funcione
	var inventory = inv1 if inv1 else (inv2 if inv2 else (inv3 if inv3 else inv4))
	
	if inventory and inventory.has_method("toggle_inventory"):
		print("Inventario encontrado, llamando toggle_inventory")
		inventory.toggle_inventory()
	else:
		print("ERROR: No se pudo encontrar el inventario")
		if inventory:
			print("  Tiene toggle_inventory? ", inventory.has_method("toggle_inventory"))
