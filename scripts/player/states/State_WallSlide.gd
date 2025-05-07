# scripts/player/states/State_WallSlide.gd
class_name State_WallSlide
extends PlayerState

@export var fall_state: PlayerState
@export var jump_state: PlayerState
@export var idle_state: PlayerState # 用於滑到底部落地

var _wants_to_jump := false # 新增：標記是否收到跳躍輸入

func enter() -> void:
	player.animated_sprite.play("wall_slide")
	player.jump_count = 0 # 碰到牆壁，重置跳躍次數 (根據需求)
	player.last_jump_was_wall_jump = false # 確保不是連續蹬牆跳
	player.is_wall_sliding = true
	# 可以選擇性地稍微減緩進入滑牆時的垂直速度，使其更自然
	# player.velocity.y = move_toward(player.velocity.y, 0, 50)
	_wants_to_jump = false # 進入狀態時重置標記

func exit() -> void:
	player.is_wall_sliding = false

# 新增：處理輸入事件
func _input(event: InputEvent) -> void:
	# 修改：直接檢查全域 Input 單例，而不是 event 物件
	if Input.is_action_just_pressed("jump"):
		_wants_to_jump = true

func process_physics(delta: float) -> void:
	# 應用滑牆速度
	# 保持向下的速度，但不讓其無限增加 (或者設置一個固定的滑落速度)
	player.velocity.y = move_toward(player.velocity.y, player.wall_slide_speed, player.gravity * delta * 0.5) # 稍微減緩重力影響

	# 玩家滑牆時通常沒有水平移動控制，或者有一個很小的推離牆壁的力
	# 這裡我們先簡單地讓水平速度歸零
	player.velocity.x = 0 # 貼在牆上，水平速度為0

	# 根據牆壁方向翻轉角色圖像
	var wall_normal = player.get_raycast_wall_normal()
	if wall_normal != Vector2.ZERO:
		player.animated_sprite.flip_h = wall_normal == Vector2.LEFT

	# 執行移動
	player.move_and_slide()

func get_transition() -> PlayerState:
	# 1. 檢查是否落地
	if player.is_on_floor():
		return idle_state

	# 2. 檢查是否不再接觸牆壁 或 玩家向遠離牆壁的方向移動
	var wall_normal = player.get_raycast_wall_normal()
	var input_direction = Input.get_axis("move_left", "move_right")

	# 如果射線未檢測到牆壁 (wall_normal為零)，或者檢測到牆壁但玩家試圖向外移動
	if wall_normal == Vector2.ZERO or (wall_normal.x != 0 and input_direction != 0 and sign(input_direction) == sign(wall_normal.x)):
		return fall_state

	# 3. 檢查跳躍輸入 (蹬牆跳) - 檢查標記
	if _wants_to_jump and jump_state:
		_wants_to_jump = false # 消耗標記
		player.last_jump_was_wall_jump = true
		return jump_state

	return null # 保持在滑牆狀態
