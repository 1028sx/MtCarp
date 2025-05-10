class_name State_WallSlide
extends PlayerState

@export var fall_state: PlayerState
@export var jump_state: PlayerState
@export var idle_state: PlayerState

var _wants_to_jump := false
var _wall_jump_grace_time := 0.15
var _wall_jump_grace_timer := 0.0

func enter() -> void:
	player.animated_sprite.play("wall_slide")
	player.jump_count = 0
	player.last_jump_was_wall_jump = false
	player.is_wall_sliding = true
	_wants_to_jump = false
	_wall_jump_grace_timer = 0.0

func exit() -> void:
	player.is_wall_sliding = false

func process_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_wants_to_jump = true

func process_physics(delta: float) -> void:
	player.velocity.y = move_toward(player.velocity.y, player.wall_slide_speed, player.gravity * delta * 0.5)
	
	# 允許少量水平移動以防止卡在牆上
	var direction = Input.get_axis("move_left", "move_right")
	var wall_normal = player.get_raycast_wall_normal()
	
	if wall_normal != Vector2.ZERO:
		player.animated_sprite.flip_h = wall_normal == Vector2.LEFT
		
		# 如果玩家正嘗試遠離牆壁，允許一點水平移動
		if direction != 0 and sign(direction) == sign(wall_normal.x):
			player.velocity.x = direction * player.speed * 0.2
		else:
			player.velocity.x = 0
	else:
		# 如果不再有牆，更新牆跳跳躍寬限計時器
		_wall_jump_grace_timer += delta
	
	player.move_and_slide()

func get_transition() -> PlayerState:
	# 已經在地面上
	if player.is_on_floor():
		return idle_state

	var wall_normal = player.get_raycast_wall_normal()
	var input_direction = Input.get_axis("move_left", "move_right")
	
	# 處理牆壁跳躍
	if _wants_to_jump:
		_wants_to_jump = false
		
		# 即使剛離開牆壁也允許短時間內跳躍（寬限時間）
		if wall_normal != Vector2.ZERO or _wall_jump_grace_timer <= _wall_jump_grace_time:
			# 重設寬限計時器
			_wall_jump_grace_timer = _wall_jump_grace_time + 1.0
			
			if jump_state:
				player.last_jump_was_wall_jump = true
				return jump_state
	
	# 從牆壁脫離的條件
	if wall_normal == Vector2.ZERO or (wall_normal.x != 0 and input_direction != 0 and sign(input_direction) == sign(wall_normal.x)):
		if _wall_jump_grace_timer > _wall_jump_grace_time:
			return fall_state

	return null
