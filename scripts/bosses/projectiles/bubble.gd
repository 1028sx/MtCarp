extends CharacterBody2D

class_name BubbleProjectile

@export var move_speed: float = 100.0
@export var damage: float = 10.0
@export var lifetime: float = 8.0
@export var initial_phase_duration: float = 2.5  # 初始直線移動階段時長
@export var drift_speed: float = 30.0           # 飄動階段速度
@export var float_speed: float = 20.0           # 上浮速度

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visibility_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

# 運動狀態
enum BubbleState { INITIAL_MOVE, DRIFTING, IMPRISONING }
var current_state: BubbleState = BubbleState.INITIAL_MOVE

# 基本變量
var target_player: Node = null
var lifetime_timer: float = 0.0
var is_active: bool = false

# 運動變量
var initial_direction: Vector2 = Vector2.RIGHT  # 初始移動方向
var current_velocity: Vector2 = Vector2.ZERO    # 當前速度
var drift_direction: Vector2 = Vector2.ZERO     # 飄動方向
var drift_timer: float = 0.0                    # 飄動計時器
var drift_change_interval: float = 1.0          # 飄動方向改變間隔

# CharacterBody2D 專用 - 雙Area2D系統
var hitbox_area: Area2D          # 受擊區域（接收攻擊）
var touch_damage_area: Area2D    # 碰撞傷害區域（禁錮玩家）

# 禁錮系統變量
var imprisoned_player: Node = null              # 被禁錮的玩家
var imprisonment_hits_received: int = 0         # 已受到的攻擊次數
var imprisonment_scale: float = 1.4             # 禁錮時的泡泡放大倍數
var original_scale: Vector2 = Vector2.ONE       # 原始大小
var imprisonment_rotation_speed: float = 1.0    # 禁錮時的旋轉速度
var imprisonment_float_speed: float = 20.0      # 禁錮時的上浮速度

# 禁錮無敵時間機制
var imprisonment_grace_time: float = 0.3        # 禁錮後的無敵時間（秒）
var imprisonment_start_time: float = 0.0        # 禁錮開始時間
var is_in_imprisonment_grace: bool = false      # 是否在無敵時間內

# 生成無敵時間機制
var spawn_invincibility_time: float = 1.0       # 生成無敵時間（秒）
var spawn_time: float = 0.0                     # 生成時間記錄
var is_spawn_invincible: bool = false           # 是否在生成無敵時間內
var invincible_speed_multiplier: float = 2.0    # 無敵時移動速度倍數

# 狀態驗證計時器
var state_check_timer: float = 0.0
var state_check_interval: float = 1.0           # 每秒檢查一次

# 性能優化：緩存驗證結果
var player_validity_cache: bool = true          # 緩存玩家有效性
var last_validity_check: float = 0.0            # 上次檢查時間
var validity_cache_duration: float = 0.1        # 緩存持續時間（100ms）

func _ready():
	# 設置信號連接
	visibility_notifier.screen_exited.connect(_on_screen_exited)
	
	# 先獲取 Area2D 節點引用
	hitbox_area = get_node("Hitbox")
	touch_damage_area = get_node("TouchDamageArea")
	
	# 設置共用碰撞形狀系統（現在有正確的節點引用）
	_setup_shared_collision_shapes()
	
	# 建立 hitbox 用於檢測與玩家的交互
	_setup_hitbox_area()
	
	# 播放出現動畫
	if animated_sprite and animated_sprite.sprite_frames.has_animation("appear"):
		animated_sprite.play("appear")
		animated_sprite.animation_finished.connect(_on_appear_finished)
	else:
		_start_default_behavior()

func initialize(player: Node):
	"""標準初始化函數（向後兼容）"""
	initialize_with_direction(player, Vector2.RIGHT)

func initialize_with_direction(player: Node, direction: Vector2):
	"""帶方向的初始化函數（用於扇形攻擊）"""
	target_player = player
	initial_direction = direction.normalized()
	current_velocity = initial_direction * move_speed
	lifetime_timer = 0.0
	is_active = true
	current_state = BubbleState.INITIAL_MOVE
	drift_timer = 0.0
	
	# 設置生成無敵狀態
	spawn_time = Time.get_ticks_msec() / 1000.0
	is_spawn_invincible = true
	
	# 無敵時視覺效果 - 變白並略微高亮
	animated_sprite.modulate = Color.WHITE * 1.5
	
	
	# 初始化完成

func _on_appear_finished():
	animated_sprite.animation_finished.disconnect(_on_appear_finished)
	_start_default_behavior()

func _start_default_behavior():
	if animated_sprite and animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")
	is_active = true

func _physics_process(delta: float):
	if not is_active:
		return
		
	lifetime_timer += delta
	if lifetime_timer >= lifetime:
		_destroy()
		return
	
	# 更新生成無敵時間和禁錮無敵時間
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if is_spawn_invincible:
		if current_time - spawn_time >= spawn_invincibility_time:
			is_spawn_invincible = false
			# 恢復正常顏色
			animated_sprite.modulate = Color.WHITE
	
	if is_in_imprisonment_grace:
		if current_time - imprisonment_start_time >= imprisonment_grace_time:
			is_in_imprisonment_grace = false
	
	# 定期狀態檢查（直接驗證，不需要額外函數）
	state_check_timer += delta
	if state_check_timer >= state_check_interval:
		_validate_imprisonment_state()
		state_check_timer = 0.0
	
	# 三階段運動邏輯
	match current_state:
		BubbleState.INITIAL_MOVE:
			_process_initial_movement()
		BubbleState.DRIFTING:
			_process_drifting_movement(delta)
		BubbleState.IMPRISONING:
			_process_imprisonment_movement(delta)
	
	# CharacterBody2D 的 move_and_slide() 會自動處理碰撞
	
	# 使用 CharacterBody2D 的精確移動，自動處理碰撞
	velocity = current_velocity
	move_and_slide()


func _process_initial_movement():
	"""初始直線移動階段：按方向直線移動"""
	# 檢查是否該轉換到飄動階段
	if lifetime_timer >= initial_phase_duration:
		_enter_drifting_phase()
		return
	
	# 計算移動速度（無敵時加倍）
	var speed_modifier = invincible_speed_multiplier if is_spawn_invincible else 1.0
	current_velocity = initial_direction * move_speed * speed_modifier

func _process_drifting_movement(delta: float):
	"""飄動階段：減速後隨機飄動並上浮"""
	drift_timer += delta
	
	# 減速至停止（如果還有水平速度）
	var horizontal_velocity = Vector2(current_velocity.x, 0)
	if horizontal_velocity.length() > 5.0:  # 還有明顯水平速度
		# 逐漸減速
		current_velocity.x = move_toward(current_velocity.x, 0, move_speed * 2.0 * delta)
	else:
		# 已停止水平移動，開始飄動
		_update_drift_movement(delta)

func _update_drift_movement(delta: float):
	"""處理隨機飄動和上浮"""
	# 更新飄動計時器
	drift_timer += delta
	
	# 每隔一段時間改變飄動方向
	if drift_timer >= drift_change_interval:
		_change_drift_direction()
		drift_timer = 0.0
	
	# 隨機左右飄動 + 緩慢上浮
	var speed_modifier = invincible_speed_multiplier if is_spawn_invincible else 1.0
	var drift_x = drift_direction.x * drift_speed * speed_modifier
	var float_y = -float_speed * speed_modifier  # 負值表示向上
	
	current_velocity = Vector2(drift_x, float_y)

func _enter_drifting_phase():
	"""進入飄動階段"""
	current_state = BubbleState.DRIFTING
	drift_timer = 0.0
	_change_drift_direction()

func _change_drift_direction():
	"""改變飄動方向"""
	# 隨機左右飄動方向
	var random_x = randf_range(-1.0, 1.0)
	drift_direction = Vector2(random_x, 0).normalized()
	
	# 隨機改變下次方向變化的時間間隔
	drift_change_interval = randf_range(0.8, 1.5)
	
	# 改變飄動方向

func _setup_hitbox_area():
	"""設置雙Area2D系統 - 連接信號"""
	# 連接受擊區域信號（接收玩家攻擊）
	if hitbox_area:
		hitbox_area.area_entered.connect(_on_hitbox_area_entered)
	
	# 連接碰撞傷害區域信號（禁錮玩家）
	if touch_damage_area:
		touch_damage_area.body_entered.connect(_on_touch_damage_body_entered)

func _setup_shared_collision_shapes():
	"""設置共用碰撞形狀系統 - 使用統一的 CollisionShapeManager"""
	CollisionShapeManager.initialize_shape_sharing(self, hitbox_area, touch_damage_area)

func _on_touch_damage_body_entered(body: Node2D):
	"""碰撞傷害區域 - 處理禁錮玩家"""
	if body == target_player:
		_hit_player(body)

func _on_hitbox_area_entered(area: Area2D):
	"""受擊區域 - 處理玩家攻擊"""
	# 檢查生成無敵時間
	if is_spawn_invincible:
		return
	
	# 檢查是否為玩家攻擊區域
	if area.get_parent() == target_player:
		if area.name == "AttackArea" or area.name == "SpecialAttackArea":
			# 根據當前狀態決定攻擊處理
			match current_state:
				BubbleState.IMPRISONING:
					# 檢查是否在無敵時間內
					if is_in_imprisonment_grace:
						return
					
					# 禁錮狀態下需要多次攻擊才能破壞
					imprisonment_hits_received += 1
					
					if imprisonment_hits_received >= 3:
						_destroy()
					else:
						# 播放受擊效果但不破壞
						_play_hit_effect()
				_:
					# 其他狀態下直接破壞
					_destroy()
			return

func _hit_player(player: Node):
	
	# 原子性檢查：防止多個泡泡同時禁錮玩家
	if not player or not player.has_method("enter_imprisonment"):
		return
	
	# 立即檢查並設置狀態，防止競爭條件
	if player.is_imprisoned:
		return
	
	# 立即設置狀態，防止其他泡泡搶奪
	player.is_imprisoned = true
	player.imprisoning_source = self
	
	# 進入禁錮狀態
	_enter_imprisonment_state(player)

func _play_hit_effect():
	"""播放受擊效果 - 給玩家視覺反饋"""
	# 短暫閃爍效果
	var flash_tween = create_tween()
	flash_tween.set_loops(2)
	flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE * 1.5, 0.1)
	flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)

func _on_screen_exited():
	_destroy()

func _destroy():
	if not is_active:
		return
		
	is_active = false
	# 開始銷毀
	
	# 關鍵修復：銷毀前必須釋放任何被禁錮的玩家
	if current_state == BubbleState.IMPRISONING and imprisoned_player:
		_force_release_player()
	
	# 播放消失動畫
	if animated_sprite and animated_sprite.sprite_frames.has_animation("disappear"):
		animated_sprite.play("disappear")
		animated_sprite.animation_finished.connect(_on_destroy_finished)
	else:
		_on_destroy_finished()

func _on_destroy_finished():
	queue_free()

# SpawnableManager 類型檢測
func get_spawnable_type() -> String:
	return "bubble"

func reset():
	"""物件池重置函數"""
	target_player = null
	lifetime_timer = 0.0
	is_active = false
	visible = true
	
	# 重置運動狀態
	current_state = BubbleState.INITIAL_MOVE
	initial_direction = Vector2.RIGHT
	current_velocity = Vector2.ZERO
	drift_direction = Vector2.ZERO
	drift_timer = 0.0
	drift_change_interval = 1.0
	
	# 重置禁錮狀態
	imprisoned_player = null
	imprisonment_hits_received = 0
	original_scale = Vector2.ONE
	state_check_timer = 0.0
	_invalidate_player_cache()  # 重置緩存
	
	# 重置生成無敵狀態
	spawn_time = 0.0
	is_spawn_invincible = false

# 禁錮系統函數
func _enter_imprisonment_state(player: Node):
	"""進入禁錮狀態"""
	
	# 雙重檢查：確保狀態已經正確設置
	if not player.is_imprisoned or player.imprisoning_source != self:
		# 禁錮狀態設置不正確，重新設置
		player.is_imprisoned = true
		player.imprisoning_source = self
	
	# 保存原始大小
	original_scale = scale
	
	# 設置禁錮狀態
	current_state = BubbleState.IMPRISONING
	imprisoned_player = player
	imprisonment_hits_received = 0
	_invalidate_player_cache()  # 緩存失效，因為玩家狀態改變
	
	# 啟動無敵時間
	imprisonment_start_time = Time.get_ticks_msec() / 1000.0
	is_in_imprisonment_grace = true
	
	# 放大泡泡
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", original_scale * imprisonment_scale, 0.3)
	
	# 禁錮玩家
	if player.has_method("enter_imprisonment"):
		player.enter_imprisonment(self)
	

func _process_imprisonment_movement(delta: float):
	"""處理禁錮時的移動邏輯"""
	# 使用緩存的快速檢查，避免每幀調用 is_instance_valid()
	if not imprisoned_player or not _is_imprisoned_player_valid_cached():
		_release_player()
		return
	
	# 緩慢上浮
	current_velocity = Vector2(0, -imprisonment_float_speed)
	
	# 旋轉效果
	rotation += imprisonment_rotation_speed * delta
	
	# 同步玩家位置（讓玩家跟隨泡泡）
	if imprisoned_player.has_method("_process_imprisonment_movement"):
		imprisoned_player._process_imprisonment_movement()


func _release_player():
	"""釋放玩家"""
	if not imprisoned_player:
		return
	
	
	# 釋放玩家狀態
	if imprisoned_player.has_method("exit_imprisonment"):
		imprisoned_player.exit_imprisonment()
	
	# 重置狀態
	imprisoned_player = null
	imprisonment_hits_received = 0
	_invalidate_player_cache()  # 緩存失效，因為玩家狀態改變
	
	# 播放消失效果並銷毀
	_destroy()

func _force_release_player():
	"""強制釋放玩家 - 用於泡泡意外銷毀時的緊急清理"""
	if not imprisoned_player:
		return
	
	
	# 更強健的釋放邏輯，即使玩家狀態異常也要執行
	if is_instance_valid(imprisoned_player):
		# 嘗試正常釋放
		if imprisoned_player.has_method("exit_imprisonment"):
			imprisoned_player.exit_imprisonment()
		else:
			# 如果正常方法失效，強制清理玩家狀態
			# 直接設置屬性（避免使用has_method檢查屬性）
			if "is_imprisoned" in imprisoned_player:
				imprisoned_player.is_imprisoned = false
			if "imprisoning_source" in imprisoned_player:  
				imprisoned_player.imprisoning_source = null
			# 強制重置視覺效果
			imprisoned_player.modulate = Color.WHITE
			imprisoned_player.rotation = 0.0
	
	# 清理泡泡本地狀態
	imprisoned_player = null
	imprisonment_hits_received = 0
	current_state = BubbleState.DRIFTING  # 回到安全狀態
	_invalidate_player_cache()  # 緩存失效，因為玩家狀態改變

func _validate_imprisonment_state() -> bool:
	"""驗證禁錮狀態的一致性（泡泡端）"""
	if current_state != BubbleState.IMPRISONING:
		return true  # 不在禁錮狀態，無需驗證
	
	if not imprisoned_player:
		# 狀態修復 - 處於禁錮狀態但無玩家對象
		current_state = BubbleState.DRIFTING
		return false
		
	if not is_instance_valid(imprisoned_player):
		# 狀態修復 - 玩家對象已失效
		imprisoned_player = null
		imprisonment_hits_received = 0
		current_state = BubbleState.DRIFTING
		return false
		
	# 檢查玩家端狀態是否與泡泡端一致
	if not imprisoned_player.is_imprisoned or imprisoned_player.imprisoning_source != self:
		# 狀態不同步
		# 詳細信息略
		# 玩家端狀態不一致，釋放並清理
		_force_release_player()
		return false
	
	return true  # 狀態一致

func _is_imprisoned_player_valid_cached() -> bool:
	"""緩存的玩家有效性檢查，減少頻繁的 is_instance_valid() 調用"""
	if not imprisoned_player:
		player_validity_cache = false
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 如果緩存還在有效期內，直接返回緩存結果
	if current_time - last_validity_check < validity_cache_duration:
		return player_validity_cache
	
	# 緩存過期，重新檢查
	last_validity_check = current_time
	player_validity_cache = is_instance_valid(imprisoned_player)
	
	return player_validity_cache

func _invalidate_player_cache():
	"""使玩家有效性緩存失效（在狀態改變時調用）"""
	player_validity_cache = false
	last_validity_check = 0.0
