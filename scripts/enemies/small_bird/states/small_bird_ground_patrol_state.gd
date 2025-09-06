extends "res://scripts/enemies/base/states/common/enemy_state_base.gd"

class_name SmallBirdGroundPatrolState

var current_target: Vector2
var threat_timer: float = 0.0
var threat_duration: float = 0.0  # 隨機生成的威脅檢測時間
var idle_timer: float = 0.0
var idle_duration: float = 0.0  # 隨機休息時間
var is_idle: bool = false
var call_timer: float = 0.0
var next_call_time: float = 0.0

# 逃離模式相關
var is_escaping: bool = false  # 是否在逃離模式
var escape_target: Vector2

func on_enter() -> void:
	super.on_enter()
	
	# 確保地面模式
	owner.set_ground_mode()
	
	# 重置角度
	if is_instance_valid(owner.animated_sprite):
		owner.animated_sprite.rotation_degrees = 0
	
	# 檢查是否從Landing狀態轉入，以提供更敏感的威脅檢測
	var from_landing = (owner.last_state_name == "Landing")
	
	# 重置威脅檢測
	threat_timer = 0.0
	if from_landing:
		# 剛降落時給予時間遠離，之後才檢測威脅
		threat_duration = randf_range(1.5, 2.5)
	else:
		threat_duration = randf_range(owner.threat_detection_time_min, owner.threat_detection_time_max)
	
	# 初始化叫聲計時器
	call_timer = 0.0
	next_call_time = randf_range(5.0, 15.0)

	# 初始化狀態
	is_escaping = false
	escape_target = Vector2.ZERO
	
	# 選擇初始目標或進入休息
	if from_landing:
		# 剛降落的鳥立即選擇遠離目標（可能需要進入逃離模式）
		var player_detected = is_instance_valid(owner.player) and owner.player in owner.detection_area.get_overlapping_bodies()
		if player_detected:
			enter_escape_mode()
		else:
			choose_normal_patrol_target()
	elif randf() < 0.3:
		enter_idle_state()
	else:
		choose_normal_patrol_target()
	
	# 播放對應動畫
	update_animation()

func on_exit() -> void:
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	# 威脅檢測邏輯
	handle_threat_detection(delta)
	
	# 叫聲邏輯處理
	handle_call_behavior(delta)
	
	# 根據當前狀態執行行為
	if is_idle:
		handle_idle_behavior(delta)
	else:
		handle_walking_behavior()

## 處理叫聲行為
func handle_call_behavior(delta: float) -> void:
	call_timer += delta
	
	# 當達到叫聲時間且沒有威脅時，隨機播放叫聲動畫
	if call_timer >= next_call_time and threat_timer == 0.0:
		if randf() < 0.6:
			var call_anim = ""
			if owner.animated_sprite.animation == "sit_idle":
				call_anim = "sit_call"
			else:
				call_anim = "idle_call"
			
			# 播放叫聲動畫
			if owner.animated_sprite.animation != call_anim:
				owner.animated_sprite.play(call_anim)
		
		# 重置叫聲計時器
		call_timer = 0.0
		next_call_time = randf_range(8.0, 20.0)

## 處理威脅檢測和模式切換
func handle_threat_detection(delta: float) -> void:
	var player_detected = is_instance_valid(owner.player) and owner.player in owner.detection_area.get_overlapping_bodies()
	
	if player_detected:
		# 進入逃離模式
		if not is_escaping:
			enter_escape_mode()
		
		threat_timer += delta
		# 威脅持續超過閾值時間，準備起飛
		if threat_timer >= threat_duration:
			transition_to("Takeoff")
			return
	else:
		# 退出逃離模式
		if is_escaping:
			exit_escape_mode()
		
		# 玩家離開，重置威脅計時器
		threat_timer = 0.0
		# 重新隨機化威脅檢測時間
		threat_duration = randf_range(owner.threat_detection_time_min, owner.threat_detection_time_max)

## 處理休息行為
func handle_idle_behavior(delta: float) -> void:
	# 休息時保持靜止
	owner.velocity.x = 0
	
	idle_timer += delta
	if idle_timer >= idle_duration:
		# 休息完畢，選擇新目標開始移動
		is_idle = false
		
		# 檢查是否需要進入逃離模式
		var player_detected = is_instance_valid(owner.player) and owner.player in owner.detection_area.get_overlapping_bodies()
		if player_detected:
			enter_escape_mode()
		else:
			choose_normal_patrol_target()

## 處理行走行為（根據模式分離）
func handle_walking_behavior() -> void:
	if is_escaping:
		handle_escape_behavior()
	else:
		handle_normal_patrol_behavior()

## 逃離模式處理
func handle_escape_behavior() -> void:
	if escape_target == Vector2.ZERO:
		choose_escape_target()
		return
	
	# 朝逃離目標移動
	var reached = owner.walk_to_point(escape_target)
	
	if reached:
		# 到達逃離目標，選擇新的逃離位置繼續遠離
		choose_escape_target()

## 正常巡邏處理  
func handle_normal_patrol_behavior() -> void:
	if current_target == Vector2.ZERO:
		enter_idle_state()
		return
	
	# 使用基類的地面移動方法
	var reached = owner.walk_to_point(current_target)
	
	if reached:
		# 到達目標，隨機決定下一步行動
		if randf() < 0.4:
			enter_idle_state()
		else:
			choose_normal_patrol_target()

## 進入逃離模式
func enter_escape_mode() -> void:
	is_escaping = true
	is_idle = false  # 取消休息狀態
	choose_escape_target()

## 退出逃離模式
func exit_escape_mode() -> void:
	is_escaping = false
	escape_target = Vector2.ZERO
	# 回到正常巡邏，選擇新目標
	choose_normal_patrol_target()

## 選擇逃離目標
func choose_escape_target() -> void:
	if not is_instance_valid(owner.player):
		escape_target = Vector2.ZERO
		return
	
	var horizontal_distance = randf_range(100.0, 200.0)
	
	# 計算遠離玩家的方向
	var escape_direction = sign(owner.global_position.x - owner.player.global_position.x)
	if escape_direction == 0:
		escape_direction = 1 if randf() > 0.5 else -1
	
	horizontal_distance *= escape_direction
	escape_target = owner.get_ground_target(horizontal_distance)
	current_target = escape_target  # 同步給動畫系統
	update_animation()

## 選擇正常巡邏目標
func choose_normal_patrol_target() -> void:
	var horizontal_distance = randf_range(50.0, 120.0)
	horizontal_distance *= (1 if randf() > 0.5 else -1)
	
	current_target = owner.get_ground_target(horizontal_distance)
	update_animation()

## 進入休息狀態
func enter_idle_state() -> void:
	is_idle = true
	idle_timer = 0.0
	idle_duration = randf_range(1.0, 3.0)
	current_target = Vector2.ZERO
	update_animation()

## 更新動畫
func update_animation() -> void:
	if not is_instance_valid(owner.animated_sprite):
		return
	
	# 如果正在播放叫聲動畫，不要打斷
	var current_anim = owner.animated_sprite.animation
	if current_anim == "idle_call" or current_anim == "sit_call":
		return
	
	var target_anim = ""
	
	# 基於行為意圖而非實際速度選擇動畫
	if is_idle:
		# 隨機在 idle 和 sit_idle 之間選擇
		if randf() < 0.3 and current_anim != "sit_idle":
			target_anim = "sit_idle"
		else:
			target_anim = owner._get_idle_animation()
	else:
		# 如果有目標且距離目標較遠，播放行走動畫
		if current_target != Vector2.ZERO:
			var distance_to_target = owner.global_position.distance_to(current_target)
			if distance_to_target > 20.0:
				target_anim = owner._get_walk_animation()
			else:
				target_anim = owner._get_idle_animation()
		else:
			target_anim = owner._get_idle_animation()
	
	# 避免重複播放相同動畫
	if current_anim != target_anim:
		owner.animated_sprite.play(target_anim)

## 動畫完成回調
func on_animation_finished() -> void:
	super.on_animation_finished()
	
	var current_anim = owner.animated_sprite.animation
	# 叫聲動畫完成後回到正常動畫
	if current_anim == "idle_call":
		owner.animated_sprite.play(owner._get_idle_animation())
	elif current_anim == "sit_call":
		owner.animated_sprite.play("sit_idle")
