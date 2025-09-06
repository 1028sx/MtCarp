extends Node

# ProgressSystem - 遊戲進度、分數和統計管理系統
# 職責：關卡進度、分數系統、統計數據、遊戲時間

# 遊戲進度數據
var current_level := 1
var current_difficulty := 1
var score := 0
var gold := 0
var play_time := 0.0

# 統計數據
var session_start_time := 0.0
var best_score := 0
var total_play_time := 0.0
var games_played := 0

# 信號
signal level_changed(new_level: int)
signal difficulty_changed(new_difficulty: int)
signal score_changed(new_score: int)
signal gold_changed(new_gold: int)
signal progress_updated(progress_data: Dictionary)
signal milestone_achieved(milestone: String, value: int)

func _init():
	add_to_group("progress_system")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready():
	name = "progress_system"
	session_start_time = Time.get_time_dict_from_system()["hour"] * 3600.0 + \
						Time.get_time_dict_from_system()["minute"] * 60.0 + \
						Time.get_time_dict_from_system()["second"]
	_load_persistent_stats()

func _process(delta: float) -> void:
	# 只在遊戲進行時累計遊戲時間
	var game_core = get_node_or_null("/root/GameCore")
	if game_core and game_core.has_method("is_playing") and game_core.is_playing():
		if not get_tree().paused:
			play_time += delta

# 關卡和難度管理
func next_level():
	current_level += 1
	level_changed.emit(current_level)
	progress_updated.emit(get_progress_data())
	_check_level_milestone()

func set_level(level: int):
	if level != current_level:
		current_level = max(1, level)
		level_changed.emit(current_level)
		progress_updated.emit(get_progress_data())

func increase_difficulty():
	current_difficulty += 1
	difficulty_changed.emit(current_difficulty)
	progress_updated.emit(get_progress_data())
	_check_difficulty_milestone()

func set_difficulty(difficulty: int):
	if difficulty != current_difficulty:
		current_difficulty = max(1, difficulty)
		difficulty_changed.emit(current_difficulty)
		progress_updated.emit(get_progress_data())

# 分數系統
func add_score(points: int):
	if points > 0:
		score += points
		score_changed.emit(score)
		progress_updated.emit(get_progress_data())
		_check_score_milestone()

func set_score(new_score: int):
	if new_score != score:
		score = max(0, new_score)
		score_changed.emit(score)
		progress_updated.emit(get_progress_data())

func reset_score():
	set_score(0)

# 金幣系統
func add_gold(amount: int):
	if amount > 0:
		gold += amount
		gold_changed.emit(gold)
		progress_updated.emit(get_progress_data())

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		progress_updated.emit(get_progress_data())
		return true
	return false

func set_gold(new_gold: int):
	if new_gold != gold:
		gold = max(0, new_gold)
		gold_changed.emit(gold)
		progress_updated.emit(get_progress_data())

# 進度重置
func reset_progress():
	current_level = 1
	current_difficulty = 1
	score = 0
	gold = 0
	play_time = 0.0
	
	# 發出所有變更信號
	level_changed.emit(current_level)
	difficulty_changed.emit(current_difficulty)
	score_changed.emit(score)
	gold_changed.emit(gold)
	progress_updated.emit(get_progress_data())

func reset_session_progress():
	# 只重置當前遊戲的進度，保留總體統計
	score = 0
	play_time = 0.0
	score_changed.emit(score)
	progress_updated.emit(get_progress_data())

# 統計數據管理
func start_new_game():
	games_played += 1
	session_start_time = Time.get_time_dict_from_system()["hour"] * 3600.0 + \
						Time.get_time_dict_from_system()["minute"] * 60.0 + \
						Time.get_time_dict_from_system()["second"]
	reset_session_progress()

func finish_game():
	# 更新最佳分數
	if score > best_score:
		best_score = score
		milestone_achieved.emit("new_best_score", best_score)
	
	# 累計總遊戲時間
	total_play_time += play_time
	_save_persistent_stats()

# 成就檢查
func _check_score_milestone():
	var milestones = [100, 500, 1000, 2500, 5000, 10000]
	for milestone in milestones:
		if score >= milestone and (score - milestone) < 100:  # 剛達到里程碑
			milestone_achieved.emit("score_milestone", milestone)

func _check_level_milestone():
	if current_level % 5 == 0:  # 每5關一個里程碑
		milestone_achieved.emit("level_milestone", current_level)

func _check_difficulty_milestone():
	var milestones = [5, 10, 15, 20, 25]
	if current_difficulty in milestones:
		milestone_achieved.emit("difficulty_milestone", current_difficulty)

# 數據存取
func get_progress_data() -> Dictionary:
	return {
		"level": current_level,
		"difficulty": current_difficulty,
		"score": score,
		"gold": gold,
		"play_time": play_time
	}

func get_statistics_data() -> Dictionary:
	return {
		"best_score": best_score,
		"total_play_time": total_play_time,
		"games_played": games_played,
		"current_session_time": play_time
	}

func set_progress_data(data: Dictionary):
	if data.has("level"):
		set_level(data.level)
	if data.has("difficulty"):
		set_difficulty(data.difficulty)
	if data.has("score"):
		set_score(data.score)
	if data.has("gold"):
		set_gold(data.gold)
	if data.has("play_time"):
		play_time = data.play_time

# 持久化統計數據
func _save_persistent_stats():
	var stats = {
		"best_score": best_score,
		"total_play_time": total_play_time,
		"games_played": games_played
	}
	var file = FileAccess.open("user://progress_stats.save", FileAccess.WRITE)
	if file:
		file.store_var(stats)
		file.close()

func _load_persistent_stats():
	if FileAccess.file_exists("user://progress_stats.save"):
		var file = FileAccess.open("user://progress_stats.save", FileAccess.READ)
		if file:
			var stats = file.get_var()
			file.close()
			if stats and typeof(stats) == TYPE_DICTIONARY:
				best_score = stats.get("best_score", 0)
				total_play_time = stats.get("total_play_time", 0.0)
				games_played = stats.get("games_played", 0)

# 查詢方法
func get_current_level() -> int:
	return current_level

func get_current_difficulty() -> int:
	return current_difficulty

func get_score() -> int:
	return score

func get_gold() -> int:
	return gold

func get_play_time() -> float:
	return play_time

func get_play_time_formatted() -> String:
	var hours = int(play_time) / 3600.0
	var minutes = (int(play_time) % 3600) / 60.0
	var seconds = int(play_time) % 60
	return "%02d:%02d:%02d" % [int(hours), int(minutes), seconds]

func can_afford(cost: int) -> bool:
	return gold >= cost
