extends Node

# ============================================================
# WAVE MANAGER - CONTROLADOR DE OLEADAS
# ============================================================

@export var time_between_waves: float = 5.0      # Segundos entre oleadas
@export var zombies_per_wave: int = 3              # Zombies en primera oleada
@export var wave_increment: int = 2                # Cuántos zombies aumenta cada oleada

var current_wave: int = 0                          # Oleada actual
var zombies_alive: int = 0                       # Zombies vivos en esta oleada
var total_zombies_in_wave: int = 0               # Total de zombies en oleada actual
var is_wave_active: bool = false                 # ¿Hay una oleada en curso?
var wave_timer: float = 0.0                      # Temporizador entre oleadas

var spawner: Node = null                         # Referencia al spawner
var game_manager: Node = null                    # Referencia al Game Manager

func _ready() -> void:
	print("WAVE MANAGER INICIADO")
	
	# Buscar spawner
	spawner = get_tree().get_first_node_in_group("ZombieSpawner")
	if spawner == null:
		spawner = get_tree().get_root().find_child("ZombieSpawner", true, false)
	
	# Buscar game manager
	game_manager = get_tree().get_first_node_in_group("GameManager")
	if game_manager == null:
		game_manager = get_tree().get_root().find_child("GameManager", true, false)
	
	# Iniciar primera oleada después de 3 segundos
	await get_tree().create_timer(3.0).timeout
	start_next_wave()

func _process(delta: float) -> void:
	# Si no hay oleada activa, esperar para la siguiente
	if not is_wave_active:
		wave_timer += delta
		if wave_timer >= time_between_waves:
			start_next_wave()
		return
	
	# Verificar si todos los zombies de la oleada murieron
	if zombies_alive <= 0 and total_zombies_in_wave > 0:
		wave_completed()

func start_next_wave() -> void:
	current_wave += 1
	var zombie_count = zombies_per_wave + ((current_wave - 1) * wave_increment)
	
	print("========================================")
	print("OLEADA ", current_wave, " INICIADA")
	print("Zombies a spawnear: ", zombie_count)
	print("========================================")
	
	# Actualizar Game Manager
	if game_manager and game_manager.has_method("set_current_wave"):
		game_manager.set_current_wave(current_wave)
	
	# Configurar oleada
	total_zombies_in_wave = zombie_count
	zombies_alive = zombie_count
	is_wave_active = true
	wave_timer = 0.0
	
	# Spawnear zombies
	if spawner and spawner.has_method("spawn_zombies"):
		spawner.spawn_zombies(zombie_count)
	else:
		push_error("NO HAY SPAWNER para crear zombies")

func wave_completed() -> void:
	is_wave_active = false
	wave_timer = 0.0
	
	print("========================================")
	print("OLEADA ", current_wave, " COMPLETADA")
	print("Siguiente oleada en ", time_between_waves, " segundos")
	print("========================================")

func zombie_died() -> void:
	zombies_alive -= 1
	if zombies_alive < 0:
		zombies_alive = 0
	
	print("Zombie muerto en oleada | Restantes: ", zombies_alive, "/", total_zombies_in_wave)
