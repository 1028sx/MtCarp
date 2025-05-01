extends Node

func _init():
	add_to_group("word_system")

const INITIAL_WORDS = ["一", "箭" ,"雙", "鵰", "驚", "箭", "雙", "生", "活"]
#["人", "龍" ,"一", "虎", "驚", "箭", "雙", "生", "活"]
#手足之
const ENEMY_WORDS = {
	"DeerSpirit": ["", "", "", ""],
	"DeerBoss": ["", "", "", ""],
	"Archer": ["弓", "箭", "射", ""],
	"Boar": ["", "衝", "撞", "野"],
	"Chicken": ["雞", "翼", "驚", "鳴"],
	"Bird": ["鳥", "鬼", "鵰", "飛"]
}

const RARE_ENEMY_WORDS = {
	"DeerSpirit": ["", ""],
	"DeerBoss": ["", ""],
	"Archer": ["神", ""],
	"Boar": ["猛", "兇"],
	"Chicken": ["鳳", "卵"],
	"Bird": ["影", "舞"]
}

const UNIVERSAL_WORDS = ["", "一", "風", "睛", "水", "殺", "土", "死"]

const DROP_RATES = {
	"rare": 0.1,
	"universal": 0.05
}

const _IDIOM_EFFECTS = {
	"生龍活虎": {
		"effect": "all_boost",
		"move_speed_bonus": 1.2,
		"attack_speed_bonus": 1.2,
		"damage_bonus": 1.2,
		"jump_height_bonus": 1.1,
		"description": "移動速度、攻擊速度和攻擊傷害提升"
	},
	"一鳴驚人": {
		"effect": "charge_attack_movement",
		"move_speed_multiplier": 0.7,
		"dash_distance_multiplier": 2.0,
		"max_charge_bonus": 5.0,
		"charge_rate": 0.8,
		"description": "移動速度降低但衝刺距離變長，且蓄力越久攻擊傷害越高"
	},
	"一箭雙鵰": {
		"effect": "double_rewards",
		"chance": 0.8,
		"description": "所有獎勵都有機率變成兩倍"
	},
	"殺雞取卵": {
		"effect": "all_drops_once",
		"description": "本層所有敵人必定掉落戰利品，但之後無法獲得任何戰利品"
	}
}

const IDIOMS = ["生龍活虎", "一鳴驚人", "一箭雙鵰", "殺雞取卵"]

var unlocked_idiom_effects = {}
var active_idiom_effects = {}
var collected_words = []

signal words_updated(words: Array)

func _ready():
	collected_words = INITIAL_WORDS.duplicate()
	unlocked_idiom_effects.clear()
	active_idiom_effects.clear()
	words_updated.emit(collected_words)

func calculate_word_drops(enemy_type: String) -> Array:
	var drops = []
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	if enemy_type in ENEMY_WORDS:
		var available_words = ENEMY_WORDS[enemy_type].filter(func(word): return word != "")
		if available_words.size() > 0:
			var drop_count = 0
			var current_prob = 1.0
			
			while drop_count < available_words.size():
				if rng.randf() <= current_prob:
					drop_count += 1
					current_prob -= 0.2
				else:
					break
			
			var selected_indices = []
			for i in range(drop_count):
				var valid_indices = []
				for j in range(available_words.size()):
					if j not in selected_indices:
						valid_indices.append(j)
				
				if valid_indices.size() > 0:
					var random_index = valid_indices[rng.randi() % valid_indices.size()]
					selected_indices.append(random_index)
					drops.append(available_words[random_index])
	
	if enemy_type in RARE_ENEMY_WORDS:
		for word in RARE_ENEMY_WORDS[enemy_type]:
			if word != "" and rng.randf() < DROP_RATES.rare:
				drops.append(word)
	
	if rng.randf() < DROP_RATES.universal:
		var random_universal = UNIVERSAL_WORDS[rng.randi() % UNIVERSAL_WORDS.size()]
		drops.append(random_universal)
	
	return drops

func collect_word(word: String) -> void:
	if not collected_words.has(word):
		collected_words.append(word)
		words_updated.emit(collected_words)

func check_idioms() -> Array:
	var available_idioms = []
	for idiom in IDIOMS:
		var characters = idiom.split("")
		var has_all_characters = true
		for character in characters:
			if not collected_words.has(character):
				has_all_characters = false
				break
		
		if has_all_characters:
			available_idioms.append(idiom)
	
	return available_idioms

func unlock_idiom_effect(idiom: String) -> Dictionary:
	if idiom in _IDIOM_EFFECTS:
		unlocked_idiom_effects[idiom] = _IDIOM_EFFECTS[idiom]
		active_idiom_effects[idiom] = _IDIOM_EFFECTS[idiom]
		apply_idiom_effect(idiom)
		return _IDIOM_EFFECTS[idiom]
	return {}

func get_idiom_description(idiom: String) -> String:
	if idiom in unlocked_idiom_effects:
		return unlocked_idiom_effects[idiom].description
	return "???"

func apply_idiom_effect(idiom: String) -> void:
	if not (idiom in _IDIOM_EFFECTS):
		return
		
	var effect = _IDIOM_EFFECTS[idiom]
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
		
	match effect.effect:
		"all_boost":
			if player.has_method("boost_move_speed"):
				player.boost_move_speed(effect.move_speed_bonus)
			if player.has_method("boost_attack_speed"):
				player.boost_attack_speed(effect.attack_speed_bonus)
			if player.has_method("boost_damage"):
				player.boost_damage(effect.damage_bonus)
			if player.has_method("boost_jump_height"):
				player.boost_jump_height(effect.jump_height_bonus)
			
		"charge_attack_movement":
			if player.has_method("boost_move_speed"):
				player.boost_move_speed(effect.move_speed_multiplier)
			if player.has_method("boost_dash_distance"):
				player.boost_dash_distance(effect.dash_distance_multiplier)
			if player.has_method("enable_charge_attack"):
				player.enable_charge_attack(effect.max_charge_bonus, effect.charge_rate)
		
		"double_rewards":
			var game_manager = get_tree().get_first_node_in_group("game_manager")
			if game_manager:
				game_manager.set_double_rewards_chance(effect.chance)
		
		"all_drops_once":
			var game_manager = get_tree().get_first_node_in_group("game_manager")
			if game_manager:
				game_manager.enable_all_drops_once()

func reset_to_base_state() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	if player.has_method("reset_all_stats"):
		player.reset_all_stats()
	else:
		if player.has_method("reset_move_speed"):
			player.reset_move_speed()
		if player.has_method("reset_attack_speed"):
			player.reset_attack_speed()
		if player.has_method("reset_damage"):
			player.reset_damage()
		if player.has_method("reset_jump_height"):
			player.reset_jump_height()
	
	if player.has_method("reset_dash_distance"):
		player.reset_dash_distance()
	if player.has_method("disable_charge_attack"):
		player.disable_charge_attack()
	
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.set_double_rewards_chance(0)
		game_manager.disable_all_drops_once()

func update_active_effects(current_idiom: String) -> void:
	reset_to_base_state()
	active_idiom_effects.clear()
	
	if current_idiom in _IDIOM_EFFECTS:
		active_idiom_effects[current_idiom] = _IDIOM_EFFECTS[current_idiom]
		unlocked_idiom_effects[current_idiom] = _IDIOM_EFFECTS[current_idiom]
		apply_idiom_effect(current_idiom)

func _on_word_collected(word: String) -> void:
	collected_words.append(word)
	words_updated.emit(collected_words)
	check_idioms()

func handle_enemy_drops(enemy_type: String, enemy_position: Vector2) -> void:
	# 處理文字掉落
	var drops = calculate_word_drops(enemy_type)
	for word in drops:
		collect_word(word)
	
	# 處理金錢獎勵
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var base_gold = 10
		match enemy_type:
			"Boar": base_gold = 500
			"Archer": base_gold = 30
			"Bird": base_gold = 20
			"Chicken": base_gold = 15
		
		# 檢查是否觸發雙倍獎勵
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager and randf() < game_manager.double_rewards_chance:
			# 處理雙倍獎勵
			var extra_drops = calculate_word_drops(enemy_type)
			for word in extra_drops:
				collect_word(word)
			
			# 雙倍金錢
			player.add_gold(base_gold * 2)
			
			# 生成額外戰利品
			var item_manager = get_tree().get_first_node_in_group("item_manager")
			if item_manager and item_manager.has_method("spawn_loot_at_position"):
				if game_manager.should_spawn_loot():
					item_manager.spawn_loot_at_position(enemy_position)
		else:
			# 正常金錢獎勵
			player.add_gold(base_gold)
