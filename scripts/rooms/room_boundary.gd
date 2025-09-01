extends Area2D
class_name RoomBoundary

@export var target_room: String = ""
@export var entrance_side: String = "right"
@export var spawn_point_name: String = ""

var is_transitioning = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # 玩家層
	# 使用 call_deferred 避免物理系統錯誤
	call_deferred("_setup_monitoring")
	
	body_entered.connect(_on_body_entered)

func _setup_monitoring() -> void:
	monitorable = false
	monitoring = true

func _on_body_entered(body: Node2D) -> void:
	if is_transitioning:
		return
		
	if not body.is_in_group("player"):
		return
		
	if target_room.is_empty():
		printerr("RoomBoundary: target_room 未設定！")
		return
	
	is_transitioning = true
	_transition_to_room()

func _transition_to_room() -> void:
	# 通知RoomManager處理房間轉換
	if not RoomManager:
		printerr("RoomBoundary: 找不到RoomManager！")
		is_transitioning = false
		return
	
	if not target_room or target_room.is_empty():
		printerr("RoomBoundary: target_room未設定！")
		is_transitioning = false
		return
	
	print("RoomBoundary: 請求轉換到房間 ", target_room, " 從 ", entrance_side, " 側")
	
	# 檢查RoomManager是否有房間轉換方法
	if RoomManager.has_method("change_to_room"):
		RoomManager.change_to_room(target_room, get_spawn_point_name())
	else:
		# 發出信號讓主場景處理
		if RoomManager.has_signal("room_change_requested"):
			RoomManager.emit_signal("room_change_requested", target_room, get_spawn_point_name())
		else:
			printerr("RoomBoundary: RoomManager沒有適當的房間轉換方法或信號！")
	
	is_transitioning = false

func get_spawn_point_name() -> String:
	if not spawn_point_name.is_empty():
		return spawn_point_name
	
	# 根據entrance_side自動決定生成點名稱
	match entrance_side:
		"left":
			return "RightSpawn"  # 從左邊進入，生成在右側
		"right":
			return "LeftSpawn"   # 從右邊進入，生成在左側
		"up":
			return "BottomSpawn" # 從上邊進入，生成在下方
		"down":
			return "TopSpawn"    # 從下邊進入，生成在上方
		_:
			return "DefaultSpawn"
