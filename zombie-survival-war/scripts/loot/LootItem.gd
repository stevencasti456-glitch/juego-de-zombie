extends Area3D

# ============================================================
# LOOT ITEM - Objeto recogible por el jugador
# ============================================================

enum LootType {
	AMMO,      # Municion
	MEDKIT,    # Botiquin
	COIN,      # Moneda (ya existe, pero la integramos)
	WEAPON     # Arma futura (placeholder)
}

@export var loot_type: int = LootType.AMMO
@export var amount: int = 15

# Referencias
var player: Node3D = null
var mesh_instance: MeshInstance3D = null
var label_3d: Label3D = null

# Colores por tipo
var loot_colors: Dictionary = {
	LootType.AMMO: Color(1.0, 0.8, 0.0),     # Amarillo/dorado
	LootType.MEDKIT: Color(0.9, 0.1, 0.1),    # Rojo
	LootType.COIN: Color(1.0, 0.85, 0.15),    # Dorado
	LootType.WEAPON: Color(0.3, 0.3, 0.3),     # Gris metal
}

var loot_names: Dictionary = {
	LootType.AMMO: "Municion",
	LootType.MEDKIT: "Vida",
	LootType.COIN: "Moneda",
	LootType.WEAPON: "Arma",
}

func _ready() -> void:
	# Buscar jugador
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		player = get_tree().get_root().find_child("Player", true, false)
	
	# Crear forma de collision
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var sphere = SphereShape3D.new()
	sphere.radius = 1.0
	collision.shape = sphere
	add_child(collision)
	
	# Crear mesh visual
	create_visual_mesh()
	
	# Crear label flotante
	create_floating_label()
	
	# Conectar senales
	body_entered.connect(_on_body_entered)
	
	# Animacion de flotacion
	animate_float()

func create_visual_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "VisualMesh"
	
	var color = loot_colors.get(loot_type, Color(1, 1, 1))
	
	match loot_type:
		LootType.AMMO:
			# Caja de municion (cubo pequeno amarillo)
			var box = BoxMesh.new()
			box.size = Vector3(0.5, 0.35, 0.7)
			mesh_instance.mesh = box
			
		LootType.MEDKIT:
			# Botiquin: caja ROJA con CRUZ BLANCA
			# Primero la caja base
			var box = BoxMesh.new()
			box.size = Vector3(0.6, 0.25, 0.6)
			mesh_instance.mesh = box
			
			# Cruz blanca (dos planos delgados)
			var cross_v = MeshInstance3D.new()
			var cross_v_box = BoxMesh.new()
			cross_v_box.size = Vector3(0.08, 0.08, 0.5)
			cross_v.mesh = cross_v_box
			cross_v.position = Vector3(0, 0.15, 0)
			var cross_mat = StandardMaterial3D.new()
			cross_mat.albedo_color = Color(1, 1, 1)
			cross_v.set_surface_override_material(0, cross_mat)
			mesh_instance.add_child(cross_v)
			
			var cross_h = MeshInstance3D.new()
			var cross_h_box = BoxMesh.new()
			cross_h_box.size = Vector3(0.5, 0.08, 0.08)
			cross_h.mesh = cross_h_box
			cross_h.position = Vector3(0, 0.15, 0)
			cross_h.set_surface_override_material(0, cross_mat)
			mesh_instance.add_child(cross_h)
			
		LootType.COIN:
			# Moneda (cilindro delgado dorado)
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.25
			cyl.bottom_radius = 0.25
			cyl.height = 0.08
			mesh_instance.mesh = cyl
			mesh_instance.rotation.x = PI / 2
			
		LootType.WEAPON:
			# Placeholder: caja gris mas grande
			var box = BoxMesh.new()
			box.size = Vector3(0.7, 0.25, 0.35)
			mesh_instance.mesh = box
	
	# Material principal
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy = 0.5
	mesh_instance.set_surface_override_material(0, mat)
	
	# Hacer que el mesh sea mas visible (escala base)
	mesh_instance.scale = Vector3(1.5, 1.5, 1.5)
	
	add_child(mesh_instance)

func create_floating_label() -> void:
	label_3d = Label3D.new()
	label_3d.name = "FloatingLabel"
	label_3d.text = loot_names.get(loot_type, "Loot")
	label_3d.font_size = 48
	label_3d.modulate = loot_colors.get(loot_type, Color(1, 1, 1))
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.position = Vector3(0, 0.8, 0)
	label_3d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label_3d)

func animate_float() -> void:
	# Animacion de flotacion suave
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(mesh_instance, "position:y", 0.3, 1.0)
	tween.tween_property(mesh_instance, "position:y", 0.1, 1.0)
	
	# Rotacion lenta
	var rot_tween = create_tween()
	rot_tween.set_loops()
	rot_tween.tween_property(mesh_instance, "rotation:y", PI * 2, 4.0)
	rot_tween.tween_property(mesh_instance, "rotation:y", 0.0, 0.0)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" or body.is_in_group("Player"):
		collect_loot(body)

func collect_loot(player_body: Node3D) -> void:
	var loot_name = loot_names.get(loot_type, "Loot")
	print("Recogido: ", loot_name, " x", amount)
	
	# Aplicar efecto segun tipo
	match loot_type:
		LootType.AMMO:
			# Dar municion al arma actual
			give_ammo(player_body)
		LootType.MEDKIT:
			# Agregar al inventario en lugar de curar automaticamente
			var inventory = get_node_or_null("/root/Main/Inventory")
			if inventory and inventory.has_method("add_medkit"):
				inventory.add_medkit(1)
			else:
				# Fallback: curar directamente si no hay inventario
				heal_player(player_body)
		LootType.COIN:
			# Dar monedas (usar GameManager)
			give_coins()
		LootType.WEAPON:
			# Placeholder - mostrar mensaje
			show_loot_message("Arma encontrada (placeholder)")
	
	# Mostrar mensaje flotante
	show_loot_message("+" + str(amount) + " " + loot_name)
	
	# Efecto visual de recogida
	play_collect_effect()
	
	# Eliminar el objeto
	queue_free()

func give_ammo(player_body: Node3D) -> void:
	# Buscar el WeaponSystem del jugador
	if player_body.has_node("WeaponSystem"):
		var ws = player_body.get_node("WeaponSystem")
		if ws and ws.current_weapon:
			var weapon = ws.current_weapon
			
			# Intentar diferentes formas de dar municion
			var ammo_given = false
			
			# Metodo 1: Usar add_ammo si existe
			if weapon.has_method("add_ammo"):
				weapon.add_ammo(amount)
				ammo_given = true
				print("Municion dada (add_ammo): ", amount)
			
			# Metodo 2: Acceder a total_ammo directamente
			elif "total_ammo" in weapon:
				weapon.total_ammo += amount
				ammo_given = true
				print("Municion dada (total_ammo): ", amount)
			
			# Metodo 3: Acceder a current_ammo y max_ammo
			elif "current_ammo" in weapon and "max_ammo" in weapon:
				weapon.current_ammo = min(weapon.current_ammo + amount, weapon.max_ammo)
				ammo_given = true
				print("Municion dada (current_ammo): ", amount)
			
			# Metodo 4: Revisar si tiene weapon_data con municion
			elif "weapon_data" in weapon and weapon.weapon_data != null:
				var data = weapon.weapon_data
				if "max_ammo" in data and "current_ammo" in weapon:
					weapon.current_ammo = min(weapon.current_ammo + amount, data.max_ammo)
					ammo_given = true
					print("Municion dada (weapon_data): ", amount)
			
			# Notificar al arma que cambio la municion
			if ammo_given and weapon.has_signal("ammo_changed"):
				weapon.ammo_changed.emit()
			
			# Notificar al HUD si existe
			var ui = get_node_or_null("/root/Main/Player/UI")
			if ui and ui.has_method("_on_ammo_updated"):
				# Intentar obtener valores actuales
				var current = 0
				var total = 0
				if "current_ammo" in weapon:
					current = weapon.current_ammo
				if "total_ammo" in weapon:
					total = weapon.total_ammo
				ui._on_ammo_updated(current, total)
	
	# Notificar al GameManager (para estadisticas futuras)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		pass  # Aqui podriamos trackear municion recogida

func heal_player(player_body: Node3D) -> void:
	if player_body.has_method("heal"):
		player_body.heal(amount)
	else:
		# Fallback: modificar health directamente
		if "health" in player_body:
			player_body.health += amount
			if player_body.health > player_body.max_health:
				player_body.health = player_body.max_health
			# Emitir senal de cambio de vida
			if player_body.has_signal("health_changed"):
				player_body.health_changed.emit(player_body.health, player_body.max_health)
	print("Vida curada: ", amount)

func give_coins() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("add_coins"):
		gm.add_coins(amount)

func show_loot_message(text: String) -> void:
	# Crear label temporal que flota hacia arriba
	var msg = Label3D.new()
	msg.text = text
	msg.font_size = 64
	msg.modulate = Color(1, 1, 1)
	msg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	msg.position = global_position + Vector3(0, 1.0, 0)
	get_tree().get_root().add_child(msg)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(msg, "position:y", msg.position.y + 1.5, 1.5)
	tween.tween_property(msg, "modulate:a", 0.0, 1.5)
	
	await tween.finished
	msg.queue_free()

func play_collect_effect() -> void:
	# Particulas de recogida
	var particles = GPUParticles3D.new()
	particles.position = global_position
	get_tree().get_root().add_child(particles)
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -5, 0)
	mat.color = loot_colors.get(loot_type, Color(1, 1, 1))
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	
	particles.process_material = mat
	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh
	particles.amount = 15
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	
	await get_tree().create_timer(0.6).timeout
	particles.queue_free()
