extends RigidBody3D

func _ready() -> void:
	# Desaparecer después de 3 segundos
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		queue_free()
