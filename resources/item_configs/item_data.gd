class_name Item_Data
extends Resource

# 道具場景配置
const ITEM_SCENES = {
	"word": "res://scenes/items/word.tscn",
	"loot": "res://scenes/ui/loot.tscn"
}

# 道具生成規則
const SPAWN_RULES = {
	"items_per_difficulty": {
		"base": 1,
		"multiplier": 0.5
	}
}

# 敵人掉落金錢配置
const ENEMY_GOLD_REWARDS = {
	"Boar": 500,
	"Archer": 30,
	"Bird": 20,
	"Chicken": 15,
	"default": 10
}

# 能力解鎖配置
const ABILITY_UNLOCKS = [
	{
		"name": "蹬牆跳",
		"ability_key": "wall_jump", 
		"description": "可以在牆上滑行並跳躍",
		"icon": "res://assets/icons/wall_jump.png"
	},
	{
		"name": "二段跳",
		"ability_key": "double_jump",
		"description": "可以在空中進行第二次跳躍",
		"icon": "res://assets/icons/double_jump.png"
	},
	{
		"name": "地面衝擊", 
		"ability_key": "ground_slam",
		"description": "特殊攻擊產生地面衝擊波",
		"icon": "res://assets/icons/ground_slam.png"
	},
	{
		"name": "敏捷衝刺",
		"ability_key": "agile_dash", 
		"description": "衝刺後三次攻擊速度提升",
		"icon": "res://assets/icons/agile_dash.png"
	}
]

# 房間道具生成配置
const ROOM_SPAWN_CONFIG = {
	"spawn_point_node": "ItemSpawnPoints",
	"max_items_per_room": 5,
	"min_items_per_room": 1
}