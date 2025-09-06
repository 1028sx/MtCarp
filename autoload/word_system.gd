extends Node

signal words_updated(words: Array)
signal idiom_unlocked(idiom: String)

# 配置資源
const WordConfig = preload("res://resources/word_configs/word_data.gd")

# 遊戲狀態
var unlocked_idiom_effects = {}
var active_idiom_effects = {}
var collected_words = []

func _init():
	add_to_group("word_system")

func _ready():
	_initialize_system()

func _initialize_system():
	collected_words = WordConfig.INITIAL_WORDS.duplicate()
	unlocked_idiom_effects.clear()
	active_idiom_effects.clear()
	words_updated.emit(collected_words)

# 字詞收集系統
func collect_word(word: String) -> void:
	if word.is_empty():
		return
		
	if not collected_words.has(word):
		collected_words.append(word)
		words_updated.emit(collected_words)
		_check_new_idioms()

func _check_new_idioms() -> void:
	var available_idioms = check_idioms()
	for idiom in available_idioms:
		if not unlocked_idiom_effects.has(idiom):
			idiom_unlocked.emit(idiom)

# 字詞掉落計算 - 重構並簡化邏輯
func calculate_word_drops(enemy_type: String) -> Array:
	var drops = []
	
	if not enemy_type in WordConfig.ENEMY_WORDS:
		push_warning("Unknown enemy type: " + enemy_type)
		return drops
	
	# 計算普通字詞掉落
	drops.append_array(_calculate_common_drops(enemy_type))
	
	# 計算稀有字詞掉落
	drops.append_array(_calculate_rare_drops(enemy_type))
	
	# 計算通用字詞掉落
	drops.append_array(_calculate_universal_drops())
	
	return drops

func _calculate_common_drops(enemy_type: String) -> Array:
	var drops = []
	var available_words = WordConfig.ENEMY_WORDS[enemy_type].filter(func(word): return not word.is_empty())
	
	if available_words.is_empty():
		return drops
	
	var drop_count = 0
	var current_prob = 1.0
	
	while drop_count < available_words.size():
		if randf() <= current_prob:
			drop_count += 1
			current_prob -= 0.2
		else:
			break
	
	# 隨機選擇要掉落的字詞
	var selected_indices = []
	for i in range(drop_count):
		var valid_indices = []
		for j in range(available_words.size()):
			if j not in selected_indices:
				valid_indices.append(j)
		
		if valid_indices.size() > 0:
			var random_index = valid_indices[randi() % valid_indices.size()]
			selected_indices.append(random_index)
			drops.append(available_words[random_index])
	
	return drops

func _calculate_rare_drops(enemy_type: String) -> Array:
	var drops = []
	
	if enemy_type in WordConfig.RARE_ENEMY_WORDS:
		for word in WordConfig.RARE_ENEMY_WORDS[enemy_type]:
			if not word.is_empty() and randf() < WordConfig.DROP_RATES.rare:
				drops.append(word)
	
	return drops

func _calculate_universal_drops() -> Array:
	var drops = []
	
	if randf() < WordConfig.DROP_RATES.universal:
		var valid_universals = WordConfig.UNIVERSAL_WORDS.filter(func(word): return not word.is_empty())
		if not valid_universals.is_empty():
			var random_universal = valid_universals[randi() % valid_universals.size()]
			drops.append(random_universal)
	
	return drops

# 成語系統
func check_idioms() -> Array:
	var available_idioms = []
	
	for idiom in WordConfig.IDIOMS:
		if idiom in WordConfig.IDIOM_EFFECTS:
			var required_words = WordConfig.IDIOM_EFFECTS[idiom].words
			var has_all_characters = true
			
			for character in required_words:
				if not collected_words.has(character):
					has_all_characters = false
					break
			
			if has_all_characters:
				available_idioms.append(idiom)
	
	return available_idioms

# 獲取所有成語列表
func get_all_idioms() -> Array:
	return WordConfig.IDIOMS.duplicate()

# 檢查是否為有效成語
func is_valid_idiom(combination: String) -> bool:
	return combination in WordConfig.IDIOMS

func unlock_idiom_effect(idiom: String) -> Dictionary:
	if not idiom in WordConfig.IDIOM_EFFECTS:
		push_error("Unknown idiom: " + idiom)
		return {}
	
	var effect_data = WordConfig.IDIOM_EFFECTS[idiom]
	unlocked_idiom_effects[idiom] = effect_data
	active_idiom_effects[idiom] = effect_data
	_apply_idiom_effect(effect_data)
	
	return effect_data

func get_idiom_description(idiom: String) -> String:
	if idiom in unlocked_idiom_effects:
		return unlocked_idiom_effects[idiom].description
	return "???"

# 效果應用系統
func _apply_idiom_effect(effect_data: Dictionary) -> void:
	match effect_data.effect:
		"all_boost":
			_apply_all_boost_effect(effect_data)
		"charge_attack_movement":
			_apply_charge_attack_effect(effect_data)
		"double_rewards":
			_apply_double_rewards_effect(effect_data)
		"all_drops_once":
			_apply_all_drops_once_effect()
		_:
			push_warning("Unknown effect type: " + str(effect_data.effect))

func _apply_all_boost_effect(effect_data: Dictionary) -> void:
	var player = PlayerSystem.get_player()
	if not player:
		return
	
	if player.has_method("boost_move_speed"):
		player.boost_move_speed(effect_data.move_speed_bonus)
	if player.has_method("boost_attack_speed"):
		player.boost_attack_speed(effect_data.attack_speed_bonus)
	if player.has_method("boost_damage"):
		player.boost_damage(effect_data.damage_bonus)
	if player.has_method("boost_jump_height"):
		player.boost_jump_height(effect_data.jump_height_bonus)

func _apply_charge_attack_effect(effect_data: Dictionary) -> void:
	var player = PlayerSystem.get_player()
	if not player:
		return
	
	if player.has_method("boost_move_speed"):
		player.boost_move_speed(effect_data.move_speed_multiplier)
	if player.has_method("boost_dash_distance"):
		player.boost_dash_distance(effect_data.dash_distance_multiplier)
	if player.has_method("enable_charge_attack"):
		player.enable_charge_attack(effect_data.max_charge_bonus, effect_data.charge_rate)

func _apply_double_rewards_effect(effect_data: Dictionary) -> void:
	# 設定獎勵倍率
	if CombatSystem:
		CombatSystem.set_double_rewards_chance(effect_data.chance)

func _apply_all_drops_once_effect() -> void:
	# 啟用全掉落效果
	if CombatSystem:
		CombatSystem.enable_all_drops_once()

# 效果重置系統
func reset_to_base_state() -> void:
	var player = PlayerSystem.get_player()
	if not player:
		return
	
	if player.has_method("reset_all_stats"):
		player.reset_all_stats()
	else:
		_reset_individual_stats(player)
	
	if player.has_method("reset_dash_distance"):
		player.reset_dash_distance()
	if player.has_method("disable_charge_attack"):
		player.disable_charge_attack()
	
	if CombatSystem:
		CombatSystem.set_double_rewards_chance(0.0)
		CombatSystem.disable_all_drops_once()

func _reset_individual_stats(player: Node) -> void:
	if player.has_method("reset_move_speed"):
		player.reset_move_speed()
	if player.has_method("reset_attack_speed"):
		player.reset_attack_speed()
	if player.has_method("reset_damage"):
		player.reset_damage()
	if player.has_method("reset_jump_height"):
		player.reset_jump_height()

func update_active_effects(current_idiom: String) -> void:
	reset_to_base_state()
	active_idiom_effects.clear()
	
	if current_idiom in WordConfig.IDIOM_EFFECTS:
		var effect_data = WordConfig.IDIOM_EFFECTS[current_idiom]
		active_idiom_effects[current_idiom] = effect_data
		unlocked_idiom_effects[current_idiom] = effect_data
		_apply_idiom_effect(effect_data)

# 敵人掉落處理 - 分離職責
func handle_enemy_drops(enemy_type: String, _enemy_position: Vector2) -> void:
	# 處理字詞掉落
	var word_drops = calculate_word_drops(enemy_type)
	for word in word_drops:
		collect_word(word)
	
	# 處理金錢獎勵
	_handle_gold_reward(enemy_type)

func _handle_gold_reward(enemy_type: String) -> void:
	var player = PlayerSystem.get_player()
	if not player:
		return
	
	# 金錢配置
	const ItemConfig = preload("res://resources/item_configs/item_data.gd")
	var base_gold = ItemConfig.ENEMY_GOLD_REWARDS.get(enemy_type, ItemConfig.ENEMY_GOLD_REWARDS.default)
	var combat_system = get_node_or_null("/root/CombatSystem")
	
	if combat_system and randf() < combat_system.double_rewards_chance:
		# 雙倍獎勵處理
		var extra_drops = calculate_word_drops(enemy_type)
		for word in extra_drops:
			collect_word(word)
		player.add_gold(base_gold * 2)
	else:
		player.add_gold(base_gold)
