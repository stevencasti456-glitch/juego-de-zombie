extends Node
class_name ZombieAnimator

# Referencias
var zombie: CharacterBody3D = null
var mesh_instance: Node3D = null

# Estado
var current_animation: String = "idle"
var is_attacking: bool = false
var is_dying: bool = false

# Partes del cuerpo (para animar)
var head: MeshInstance3D = null
var torso: MeshInstance3D = null
var left_arm: MeshInstance3D = null
var right_arm: MeshInstance3D = null

func _init(p_zombie: CharacterBody3D) -> void:
	zombie = p_zombie

func setup() -> void:
	mesh_instance = zombie.get_node_or_null("ZombieMesh")
	if mesh_instance:
		# Buscar partes del cuerpo
		head = mesh_instance.get_node_or_null("Head")
		torso = mesh_instance.get_node_or_null("Torso")
		left_arm = mesh_instance.get_node_or_null("LeftArm")
		right_arm = mesh_instance.get_node_or_null("RightArm")
		print("ZombieAnimator: Mesh encontrado")

func play_animation(anim_name: String) -> void:
	if current_animation == anim_name or is_dying:
		return
	
	current_animation = anim_name
	
	match anim_name:
		"idle":
			play_idle()
		"walk":
			play_walk()
		"chase":
			play_chase()
		"attack":
			play_attack()
		"death":
			play_death()

func play_idle() -> void:
	# Zombie quieto, respiracion lenta
	if torso:
		var tween = zombie.create_tween()
		tween.set_loops()
		tween.tween_property(torso, "position:y", 0.05, 1.0)
		tween.tween_property(torso, "position:y", -0.05, 1.0)

func play_walk() -> void:
	# Zombie caminando lento, brazos balanceandose
	if left_arm and right_arm:
		var tween = zombie.create_tween()
		tween.set_loops()
		tween.tween_property(left_arm, "rotation:z", 0.3, 0.8)
		tween.tween_property(right_arm, "rotation:z", -0.3, 0.8)
		tween.tween_property(left_arm, "rotation:z", -0.3, 0.8)
		tween.tween_property(right_arm, "rotation:z", 0.3, 0.8)

func play_chase() -> void:
	# Zombie corriendo, brazos levantados
	if left_arm and right_arm:
		var tween = zombie.create_tween()
		tween.set_loops()
		tween.tween_property(left_arm, "rotation:x", -0.5, 0.4)
		tween.tween_property(right_arm, "rotation:x", -0.5, 0.4)
		tween.tween_property(left_arm, "rotation:x", 0.2, 0.4)
		tween.tween_property(right_arm, "rotation:x", 0.2, 0.4)

func play_attack() -> void:
	# Zombie atacando, brazos hacia adelante
	if is_attacking:
		return
	
	is_attacking = true
	
	if left_arm and right_arm:
		var tween = zombie.create_tween()
		tween.tween_property(left_arm, "rotation:x", -1.2, 0.15)
		tween.tween_property(right_arm, "rotation:x", -1.2, 0.15)
		tween.tween_property(left_arm, "rotation:x", 0.0, 0.3)
		tween.tween_property(right_arm, "rotation:x", 0.0, 0.3)
		await tween.finished
	
	is_attacking = false

func play_death() -> void:
	# Zombie muriendo, cae al suelo
	if is_dying:
		return
	
	is_dying = true
	
	if torso:
		var tween = zombie.create_tween()
		tween.tween_property(torso, "rotation:x", PI / 2, 0.5)
		tween.tween_property(torso, "position:y", -0.5, 0.5)
		await tween.finished

func update_animation(state: String) -> void:
	# state puede ser: "idle", "patrol", "chase", "attack", "death"
	match state:
		"idle", "patrol":
			play_animation("idle")
		"chase":
			play_animation("chase")
		"attack":
			play_animation("attack")
		"death":
			play_animation("death")
