class_name Word_Data
extends Resource

# 字詞系統配置數據

const INITIAL_WORDS = ["一", "箭", "雙", "鵰", "驚", "箭", "雙", "生", "活"]

const ENEMY_WORDS = {
	"Archer": ["弓", "箭", "射"],
	"Boar": ["衝", "撞", "野"],
	"Chicken": ["雞", "翼", "驚", "鳴"],
	"Bird": ["鳥", "鬼", "鵰", "飛"]
}

const RARE_ENEMY_WORDS = {
	"Archer": ["神"],
	"Boar": ["猛", "兇"],
	"Chicken": ["鳳", "卵"],
	"Bird": ["影", "舞"]
}

const UNIVERSAL_WORDS = ["一", "風", "睛", "水", "殺", "土", "死"]

const DROP_RATES = {
	"rare": 0.1,
	"universal": 0.05
}

const IDIOM_EFFECTS = {
	"生龍活虎": {
		"words": ["生", "龍", "活", "虎"],
		"effect": "all_boost",
		"move_speed_bonus": 1.2,
		"attack_speed_bonus": 1.2,
		"damage_bonus": 1.2,
		"jump_height_bonus": 1.1,
		"description": "移動速度、攻擊速度和攻擊傷害提升"
	},
	"一鳴驚人": {
		"words": ["一", "鳴", "驚", "人"],
		"effect": "charge_attack_movement",
		"move_speed_multiplier": 0.7,
		"dash_distance_multiplier": 2.0,
		"max_charge_bonus": 5.0,
		"charge_rate": 0.8,
		"description": "移動速度降低但衝刺距離變長，且蓄力越久攻擊傷害越高"
	},
	"一箭雙鵰": {
		"words": ["一", "箭", "雙", "鵰"],
		"effect": "double_rewards",
		"chance": 0.8,
		"description": "所有獎勵都有機率變成兩倍"
	},
	"殺雞取卵": {
		"words": ["殺", "雞", "取", "卵"],
		"effect": "all_drops_once",
		"description": "本層所有敵人必定掉落戰利品，但之後無法獲得任何戰利品"
	}
}

const IDIOMS = ["生龍活虎", "一鳴驚人", "一箭雙鵰", "殺雞取卵"]