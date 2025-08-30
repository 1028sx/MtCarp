extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name SmallBirdPatrolState

var patrol_target_position: Vector2
var action_timer: Timer
var last_mode_switch_time: float = 0.0
var mode_switch_cooldown: float = 6.0  # 6秒冷卻時間，大幅減少切換頻率
var ground_walk_timer: float = 0.0  # 地面行走計時器
var max_ground_walk_time: float = 5.0  # 最大地面行走時間

enum SubState { IDLE, FLYING, LANDING, WALKING, TAKING_OFF }
var sub_state: SubState = SubState.FLYING

func on_enter() -> void:
	super.on_enter()
	action_timer = Timer.new()
	action_timer.one_shot = true
	action_timer.timeout.connect(_on_action_timer_timeout)
	owner.add_child(action_timer)
	sub_state = SubState.FLYING
	_pick_new_action()

func on_exit() -> void:
	action_timer.stop()
	if action_timer and is_instance_valid(action_timer):
		action_timer.queue_free()
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)

	match sub_state:
		SubState.FLYING:
			_process_flying(delta)
		SubState.WALKING:
			_process_walking(delta)

func _process_flying(delta: float) -> void:
	# 使用新的飛行方法
	owner.fly_towards_target(patrol_target_position, owner.patrol_speed, delta)
	owner.animated_sprite.play(owner._get_fly_animation())
	
	if owner.global_position.distance_to(patrol_target_position) < 20:
		_pick_new_patrol_target()

func _process_walking(delta: float) -> void:
	ground_walk_timer += delta  # 累計地面行走時間
	
	var direction_to_target = patrol_target_position - owner.global_position
	var horizontal_direction = sign(direction_to_target.x)
	
	# 地面行走時確保只有水平移動
	if abs(direction_to_target.x) > 10:  # 只在距離足夠時移動
		owner.velocity.x = move_toward(owner.velocity.x, horizontal_direction * owner.patrol_speed * 0.5, owner.acceleration * delta)
	else:
		owner.velocity.x = move_toward(owner.velocity.x, 0, owner.acceleration * delta)
	
	owner.animated_sprite.play(owner._get_walk_animation())
	
	# 手動更新地面行走的外觀朝向
	owner.update_ground_walking_orientation()
	
	# 檢查是否應該起飛（超時或到達目標）
	if ground_walk_timer >= max_ground_walk_time:
		# 地面行走超時，強制起飛
		_switch_to_flying()
	elif owner.global_position.distance_to(patrol_target_position) < 20:
		_on_action_timer_timeout()

func _pick_new_action() -> void:
	var current_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	var can_switch_mode = (current_time - last_mode_switch_time) >= mode_switch_cooldown
	
	# 檢查是否有玩家在視野內
	var player_detected = is_instance_valid(owner.player) and owner.player in owner.detection_area.get_overlapping_bodies()
	
	# 如果玩家在視野內，傾向飛行
	if player_detected:
		if sub_state != SubState.FLYING:
			_switch_to_flying()
		return
	
	var rand = randf()
	
	# 如果在冷卻期間，保持當前模式
	if not can_switch_mode:
		if sub_state == SubState.FLYING:
			# 繼續飛行
			_pick_new_patrol_target()
			owner.animated_sprite.play(owner._get_fly_animation())
			action_timer.start(randf_range(4.0, 7.0))  # 增加飛行時間
			return
		elif sub_state == SubState.WALKING:
			# 繼續地面行走
			_pick_new_ground_patrol_target()
			action_timer.start(randf_range(2.0, 4.0))
			return
	
	# 冷卻期過後才允許切換模式
	if rand < 0.75:  # 提高飛行機率，鳥類主要應該飛行
		_switch_to_flying()
	elif rand < 0.85 and _check_safe_landing_spot():  # 只在有安全地面時才降落
		sub_state = SubState.LANDING
		owner.set_flight_mode(false)  # 開始降落，準備行走
		owner.velocity = Vector2(0, 200)
		owner.animated_sprite.play(owner._get_land_animation())
		last_mode_switch_time = current_time
		ground_walk_timer = 0.0  # 重置地面行走計時器
	else:
		sub_state = SubState.IDLE
		owner.set_flight_mode(false)  # 休息時在地面
		owner.velocity = Vector2.ZERO
		owner.animated_sprite.play(owner._get_idle_animation())
		action_timer.start(randf_range(1.0, 3.0))
		last_mode_switch_time = current_time

func _pick_new_patrol_target() -> void:
	patrol_target_position = owner.pick_random_patrol_target()

## 選擇地面巡邏目標（保持在同一水平線）
func _pick_new_ground_patrol_target() -> void:
	# 地面巡邏時只在水平方向移動
	var current_y = owner.global_position.y
	var patrol_range = 100.0  # 水平巡邏範圍
	var offset_x = randf_range(-patrol_range, patrol_range)
	patrol_target_position = Vector2(owner.patrol_center.x + offset_x, current_y)

## 強制重新選擇巡邏目標（被解困系統調用）
func force_new_patrol_target() -> void:
	_pick_new_patrol_target()
	# 重新開始巡邏行為
	sub_state = SubState.FLYING
	action_timer.stop()
	action_timer.start(randf_range(3.0, 6.0))


## 強制切換到地面模式（飛行時碰地調用）
func force_ground_mode() -> void:
	# 檢查是否已經在地面行走模式，避免重複切換
	if sub_state == SubState.WALKING:
		return
	
	
	# 停止當前計時器
	action_timer.stop()
	
	# 切換到地面行走
	sub_state = SubState.WALKING
	owner.set_flight_mode(false)
	
	# 清零垂直速度，避免彈跳
	owner.velocity.y = 0
	
	# 選擇新的地面巡邏目標（確保在同一水平線）
	_pick_new_ground_patrol_target()
	
	# 設置地面行走時間
	action_timer.start(randf_range(2.0, 4.0))

func _on_action_timer_timeout() -> void:
	_pick_new_action()

func on_animation_finished() -> void:
	super.on_animation_finished()
	match owner.animated_sprite.animation:
		"land":
			sub_state = SubState.WALKING
			owner.set_flight_mode(false)  # 確保行走時有重力
			owner.velocity = Vector2.ZERO
			_pick_new_ground_patrol_target()  # 使用地面巡邏目標
			action_timer.start(randf_range(2.0, 4.0))
		"takeoff":
			sub_state = SubState.FLYING
			owner.set_flight_mode(true)  # 起飛時切換飛行模式
			_pick_new_action()

func on_player_detected(_body: Node) -> void:
	super.on_player_detected(_body)
	# 如果在地面行走，立即起飛追擊
	if sub_state == SubState.WALKING:
		_switch_to_flying()
	transition_to("Chase")

## 切換到飛行模式
func _switch_to_flying() -> void:
	var current_time = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	
	sub_state = SubState.FLYING
	owner.set_flight_mode(true)
	_pick_new_patrol_target()
	owner.animated_sprite.play(owner._get_fly_animation())
	action_timer.start(randf_range(4.0, 7.0))
	last_mode_switch_time = current_time
	ground_walk_timer = 0.0  # 重置地面行走計時器

## 檢查是否有安全的降落地點
func _check_safe_landing_spot() -> bool:
	# 使用射線檢查下方是否有地面
	var space_state = owner.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.new()
	query.from = owner.global_position
	query.to = owner.global_position + Vector2(0, 150)  # 檢查下方150像素
	query.collision_mask = owner.collision_mask
	
	var result = space_state.intersect_ray(query)
	# 有地面且距離適中
	return result and result.position.distance_to(owner.global_position) > 50 and result.position.distance_to(owner.global_position) < 120 
