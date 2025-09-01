extends Resource
class_name RoomData

@export var room_name: String = ""
@export var room_size: Vector2 = Vector2(1920, 1080)
@export var camera_bounds: Rect2 = Rect2(0, 0, 1920, 1080)

@export_group("生成點設定")
@export var spawn_points: Dictionary = {
	"LeftSpawn": Vector2(100, 500),
	"RightSpawn": Vector2(1820, 500),
	"TopSpawn": Vector2(960, 100),
	"BottomSpawn": Vector2(960, 980),
	"DefaultSpawn": Vector2(960, 540)
}

@export_group("房間連接")
@export var connections: Dictionary = {
	# "left": "target_room_name",
	# "right": "target_room_name",
	# "up": "target_room_name", 
	# "down": "target_room_name"
}

@export_group("房間屬性")
@export_enum("NORMAL", "BOSS", "TREASURE", "SAVE", "SHOP") var room_type: String = "NORMAL"
@export var requires_clear_to_exit: bool = false
@export var enemy_count: int = 0

@export_group("環境設定")
@export var background_music: String = ""
@export var ambient_sound: String = ""
@export var lighting_preset: String = "default"

func get_spawn_point(spawn_name: String) -> Vector2:
	return spawn_points.get(spawn_name, spawn_points.get("DefaultSpawn", Vector2.ZERO))

func get_connection(direction: String) -> String:
	return connections.get(direction, "")

func has_connection(direction: String) -> bool:
	return connections.has(direction) and not connections[direction].is_empty()

func is_boss_room() -> bool:
	return room_type == "BOSS"

func is_treasure_room() -> bool:
	return room_type == "TREASURE"

func is_save_room() -> bool:
	return room_type == "SAVE"

func is_shop_room() -> bool:
	return room_type == "SHOP"