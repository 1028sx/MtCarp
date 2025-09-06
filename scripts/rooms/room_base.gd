extends Node2D

class_name RoomBase

# 當房間準備好時自動檢查並生成loot
func _ready() -> void:
	# 延遲一幀確保所有子節點都準備好
	await get_tree().process_frame
	_check_and_spawn_room_loot()

func _check_and_spawn_room_loot() -> void:
	var reward_system = get_node_or_null("/root/RewardSystem")
	if not reward_system:
		return
	
	# 獲取當前房間的場景路徑
	var scene_file = scene_file_path
	if scene_file.is_empty():
		# 如果沒有scene_file_path，嘗試從MetSys獲取
		var current_room = MetSys.get_current_room_name() if MetSys else ""
		if current_room.is_empty():
			return
		scene_file = current_room
	
	# 設置房間獎勵（物品和戰利品）
	reward_system.setup_room_rewards(self, scene_file)

# 這個函數可以被手動調用來強制檢查loot生成
func force_check_loot() -> void:
	_check_and_spawn_room_loot()