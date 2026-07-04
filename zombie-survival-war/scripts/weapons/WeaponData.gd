extends Resource
class_name WeaponData

@export_group("Identidad")
@export var weapon_name: String = "Arma"
@export var description: String = ""
@export var weapon_type: WeaponType = WeaponType.PISTOL

@export_group("Combate")
@export var damage: int = 25
@export var fire_rate: float = 0.5
@export var range: float = 100.0
@export var accuracy: float = 1.0
@export var recoil_strength: float = 0.3

@export_group("Munición")
@export var magazine_size: int = 12
@export var max_ammo: int = 120
@export var reload_time: float = 1.5
@export var auto_reload: bool = true

@export_group("Audio")
@export var shoot_sound: AudioStream
@export var reload_sound: AudioStream
@export var empty_sound: AudioStream

@export_group("Visual")
@export var muzzle_flash_scene: PackedScene
@export var shell_eject_scene: PackedScene
@export var impact_effect_scene: PackedScene

enum WeaponType {
	PISTOL,
	RIFLE,
	SHOTGUN,
	SMG,
	SNIPER
}
