extends CharacterBody3D

# AGREGAR ESTA LÍNEA:
signal health_changed(new_health: int, new_max: int)

@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 8.0
@export var SENSITIVITY: float = 0.005
@export var CAMERA_DISTANCE: float = 8.0
@export var CAMERA_HEIGHT: float = 4.0

# Vida del jugador
@export var max_health: int = 100
var health: int = 100

# Flash de disparo
var muzzle_flash: OmniLight3D

# Referencias
var camera: Camera3D
var camera_pivot: Node3D
var mesh_instance: Node3D

# Estado
var can_shoot: bool = true
var shoot_cooldown: float = 0.5
var is_crouching: bool = false

# Controles táctiles
var move_input: Vector2 = Vector2.ZERO
var touch_look_input: Vector2 = Vector2.ZERO
var left_finger_index: int = -1
var right_finger_index: int = -1
var left_joystick_center: Vector2 = Vector2.ZERO

# Referencias a botones UI (para evitar que el input táctil los bloquee)
var jump_btn: Button
var crouch_btn: Button
var shoot_btn: Button

# ============================================================
# CREAR PERSONAJE HUMANOIDE (FASE 2.5)
# ============================================================
func create_humanoid_character() -> void:
	var old_mesh = get_node_or_null("MeshInstance3D")
	if old_mesh:
		remove_child(old_mesh)
		old_mesh.free()

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

	var head = MeshInstance3D.new()
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	head.mesh = head_mesh
	head.set_surface_override_material(0, skin_mat)
	head.position = Vector3(0, 1.7, 0)
	character.add_child(head)

	var torso = MeshInstance3D.new()
	var torso_mesh = CapsuleMesh.new()
	torso_mesh.radius = 0.3
	torso_mesh.height = 0.8
	torso.mesh = torso_mesh
	torso.set_surface_override_material(0, shirt_mat)
	torso.position = Vector3(0, 1.0, 0)
	character.add_child(torso)

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

	var rifle = MeshInstance3D.new()
	var rifle_mesh = BoxMesh.new()
	rifle_mesh.size = Vector3(0.08, 0.15, 0.6)
	rifle.mesh = rifle_mesh
	var rifle_mat = StandardMaterial3D.new()
	rifle_mat.albedo_color = Color(0.15, 0.15, 0.15)
	rifle_mat.roughness = 0.4
	rifle_mat.metallic = 0.8
	rifle.set_surface_override_material(0, rifle_mat)
	rifle.position = Vector3(0.25, 0.9, 0.4)
	rifle.rotation.x = -0.2
	character.add_child(rifle)

	mesh_instance = character

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	velocity = Vector3.ZERO
	health = max_health
	camera = get_node("CameraPivot/Camera3D")
	camera_pivot = get_node("CameraPivot")
	create_humanoid_character()
	setup_animations()
	setup_touch_controls()
	setup_muzzle_flash()

func setup_animations() -> void:
	pass

# ============================================================
# BOTONES TÁCTILES CON ANCLAJES (FASE 2.7)
# ============================================================
func setup_touch_controls() -> void:
	var ui = get_node_or_null("UI")
	if not ui:
		return

	# Eliminar panel anterior si existe
	var old_panel = ui.get_node_or_null("RightControlPanel")
	if old_panel:
		old_panel.queue_free()
		await get_tree().process_frame  # Esperar a que se elimine

	# Eliminar botones viejos individualmente también
	for old_name in ["JumpButton", "CrouchButton", "ShootButton"]:
		var old = ui.get_node_or_null(old_name)
		if old:
			old.free()

	# Crear panel contenedor
	var panel = Control.new()
	panel.name = "RightControlPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -210
	panel.offset_top = -290
	panel.offset_right = -10
	panel.offset_bottom = -10
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(panel)

	# Crear los 3 botones como Button normales (más confiables que TextureButton)
	# Disparar (grande, abajo derecha)
	shoot_btn = create_action_button("ShootButton", "🔫", Color(0.8, 0.2, 0.2))
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

	# Saltar (arriba del disparar)
	jump_btn = create_action_button("JumpButton", "⬆", Color(0.2, 0.5, 0.8))
	jump_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_btn.anchor_left = 1.0
	jump_btn.anchor_top = 1.0
	jump_btn.anchor_right = 1.0
	jump_btn.anchor_bottom = 1.0
	jump_btn.offset_left = -100
	jump_btn.offset_top = -200
	jump_btn.offset_right = 0
	jump_btn.offset_bottom = -110
	panel.add_child(jump_btn)

	# Agacharse (izquierda del disparar)
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

func create_action_button(name: String, text_label: String, bg_color: Color) -> Button:
	var btn = Button.new()
	btn.name = name
	btn.text = text_label
	btn.custom_minimum_size = Vector2(90, 90)
	btn.size = Vector2(90, 90)
	
	# Estilo del botón
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
	
	# Texto grande
	btn.add_theme_font_size_override("font_size", 36)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	
	# NO bloquear input del mouse/táctil para que pase al juego
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Conectar señales
	if name == "JumpButton":
		btn.pressed.connect(_on_jump_button_pressed)
	elif name == "CrouchButton":
		btn.button_down.connect(_on_crouch_button_button_down)
		btn.button_up.connect(_on_crouch_button_button_up)
	elif name == "ShootButton":
		btn.pressed.connect(_on_shoot_button_pressed)
	
	return btn

# ============================================================
# FÍSICA
# ============================================================
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 15.0 * delta

	handle_input(delta)
	move_and_slide()
	update_camera()

	if global_position.y < -5:
		print("DEBUG: ¡Personaje cayendo al vacío! Y: ", global_position.y)

# ============================================================
# INPUT - RESTAURADO PARA MÓVIL Y PC
# ============================================================
func handle_input(_delta: float) -> void:
	var input_dir = Vector3.ZERO

	# --- MÓVIL: Joystick virtual ---
	if move_input.length() > 0:
		input_dir.x = move_input.x
		input_dir.z = move_input.y
	else:
		# --- PC: Teclado ---
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
		
		
		# Aceleración más suave
		velocity.x = move_toward(velocity.x, direction.x * current_speed, SPEED * 0.08)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, SPEED * 0.08)
	else:
		# Frenado suave
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.12)
		velocity.z = move_toward(velocity.z, 0, SPEED * 0.12)

func update_camera() -> void:
	if camera_pivot:
		var target_pos = global_position + Vector3(0, CAMERA_HEIGHT, 0)
		# Suavizado: la cámara se mueve un 12% del camino restante cada frame
		camera_pivot.global_position = camera_pivot.global_position.lerp(target_pos, 0.12)

# ============================================================
# BOTONES UI - MÉTODOS CONECTADOS
# ============================================================
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
	if can_shoot:
		shoot()

func shoot() -> void:
	can_shoot = false
	get_tree().create_timer(shoot_cooldown).timeout.connect(func(): can_shoot = true)

	trigger_muzzle_flash()  # ← AGREGAR ESTA LÍNEA

	print("DISPARO!")  # AGREGAR ESTO PARA DEBUG

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()

	var camera_forward = -camera.global_transform.basis.z.normalized()
	var origin = camera.global_position + camera_forward * 1.5
	query.from = origin
	query.to = origin + camera_forward * 100.0
	query.exclude = [self]

	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		print("Impacto en: ", collider.name)  # AGREGAR ESTO PARA DEBUG
		if collider.has_method("take_damage"):
			collider.take_damage(25)

func take_damage(amount: int) -> void:
	health -= amount
	if health < 0:
		health = 0
	
	print("Jugador herido! Vida: ", health, "/", max_health)
	
	# AGREGAR ESTA LÍNEA - Notificar al HUD:
	health_changed.emit(health, max_health)

	if health <= 0:
		die()

func die() -> void:
	print("JUGADOR MUERE")
	set_physics_process(false)

	var tween = create_tween()
	tween.tween_property(self, "rotation:x", PI / 2, 0.5)
	await tween.finished

	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func get_health() -> int:
	return health

# ============================================================
# CONTROLES TÁCTILES - CORREGIDOS PARA NO BLOQUEAR BOTONES
# ============================================================
# ============================================================
# CONTROLES TÁCTILES - NO BLOQUEAR BOTONES
# ============================================================
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.is_pressed():
			# Verificar si el toque está sobre algún botón
			if is_touch_over_button(event.position):
				return  # El botón manejará el evento

			# Dedo izquierdo = mover
			if event.position.x <= get_viewport().size.x / 2 and left_finger_index == -1:
				left_finger_index = event.index
				left_joystick_center = event.position
			# Dedo derecho = mirar (SOLO si no está sobre botón)
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
	
	# Verificar cada botón dentro del panel
	for child in panel.get_children():
		if child is Button:
			var btn = child as Button
			var global_pos = btn.global_position
			var rect = Rect2(global_pos, btn.size)
			if rect.has_point(pos):
				return true
	return false

func setup_muzzle_flash() -> void:
	muzzle_flash = OmniLight3D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.light_color = Color(1.0, 0.85, 0.7)  # Blanco cálido con tono rojizo
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 15.0
	muzzle_flash.omni_attenuation = 1.5
	muzzle_flash.shadow_enabled = false
	
	# Agregar al PIVOTE de la cámara (no a la cámara misma)
	# Así la luz está en la posición del jugador y brilla hacia adelante
	camera_pivot.add_child(muzzle_flash)
	muzzle_flash.position = Vector3(0.4, -2.5, -3.0)  # Frente al jugador, a la derecha del rifle

func trigger_muzzle_flash() -> void:
	if not muzzle_flash:
		return
	
	# Encender con intensidad alta
	muzzle_flash.light_energy = 5.0
	
	# Pequeño retroceso visual de cámara
	var recoil_tween = create_tween()
	recoil_tween.tween_property(camera_pivot, "position:z", -0.3, 0.02)
	recoil_tween.tween_property(camera_pivot, "position:z", 0.0, 0.1)
	
	# Apagar luz rápidamente
	var light_tween = create_tween()
	light_tween.tween_property(muzzle_flash, "light_energy", 0.0, 0.05)
