class_name Room_Data
extends Resource

# 房間系統配置數據

#region 房間配置
const EXISTING_ROOMS = {
	"beginning": [
		"beginning/beginning1.tscn",
		"beginning/beginning2.tscn", 
		"beginning/beginning3.tscn",
		"beginning/beginning4.tscn",
		"beginning/beginning5.tscn"
	],
	"jungle": [
		"jungle/jungle1.tscn",
		"jungle/jungle2.tscn",
		"jungle/jungle3.tscn", 
		"jungle/jungle4.tscn",
		"jungle/jungle5.tscn",
		"jungle/jungle6.tscn"
	],
	"fortress": [
		"fortress/fortress1.tscn",
		"fortress/fortress2.tscn",
		"fortress/fortress3.tscn",
		"fortress/fortress4.tscn"
	],
	"mountain": [
		"mountain/mountain1.tscn"
	],
	"village": [
		"village/village1.tscn",
		"village/village2.tscn",
		"village/village3.tscn",
		"village/village4.tscn"
	]
}
#endregion

#region 房間獎勵配置
const ROOM_REWARDS = {
	"jungle/jungle1.tscn": {
		"ability_key": "wall_jump", 
		"name": "蹬牆跳",
		"description": "可以在牆上滑行並跳躍"
	},
	"jungle/jungle5.tscn": {
		"ability_key": "ground_slam",
		"name": "地面衝擊", 
		"description": "可在空中向下衝撞攻擊敵人"
	}
}

# 起始房間配置
const START_ROOM = "beginning/beginning1.tscn"

# BOSS獎勵配置
const BOSS_REWARDS = {
	"giant_fish": {
		"ability_key": "respawn_unlock",
		"name": "啟用重生點", 
		"description": "啟用遊戲中的重生點系統"
	}
}
#endregion

#region 工具函數
# 獲取完整房間路徑
static func get_room_path(room_relative_path: String) -> String:
	if room_relative_path.begins_with("res://"):
		return room_relative_path
	return "res://scenes/rooms/" + room_relative_path

# 獲取房間獎勵配置
static func get_room_reward(room_path: String) -> Dictionary:
	var clean_path = room_path.replace("res://scenes/rooms/", "")
	return ROOM_REWARDS.get(clean_path, {})

# 驗證房間路徑是否有效
static func is_valid_room(room_path: String) -> bool:
	var full_path = get_room_path(room_path)
	return FileAccess.file_exists(full_path)

# 獲取所有房間列表
static func get_all_rooms() -> Array:
	var all_rooms = []
	for category in EXISTING_ROOMS.values():
		all_rooms.append_array(category)
	return all_rooms
#endregion