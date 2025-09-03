class_name PlayerHealingState
extends PlayerState

signal healing_completed

var healing_duration: float = 2.0
var healing_timer: float = 0.0
var animation_finished: bool = false
var healing_source: String = "unknown"

@onready var idle_state = $"../Idle"
@onready var fall_state = $"../Fall"

func enter() -> void:
	super.enter()
	if player and player.animated_sprite:
		# 停止玩家移動
		player.velocity = Vector2.ZERO
		
		# 播放治療動畫
		player.animated_sprite.play("healing")
		
		# 連接動畫完成信號
		if not player.animated_sprite.animation_finished.is_connected(_on_healing_animation_finished):
			player.animated_sprite.animation_finished.connect(_on_healing_animation_finished)
	
	# 重置狀態變數
	animation_finished = false
	healing_timer = 0.0

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	# 應用重力（如果玩家在空中）
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	
	# 確保玩家不會移動
	player.velocity.x = 0
	player.move_and_slide()
	
	# 更新計時器
	healing_timer += delta

func get_transition() -> PlayerState:
	# 當動畫完成時轉換狀態
	if animation_finished:
		if player.is_on_floor():
			return idle_state
		else:
			return fall_state
	
	return null

func _on_healing_animation_finished():
	# 斷開信號連接
	if player.animated_sprite.animation_finished.is_connected(_on_healing_animation_finished):
		player.animated_sprite.animation_finished.disconnect(_on_healing_animation_finished)
	
	# 標記動畫完成
	animation_finished = true
	
	# 發出治療完成信號
	healing_completed.emit()

func exit() -> void:
	super.exit()
	
	# 確保信號已斷開
	if player and player.animated_sprite and player.animated_sprite.animation_finished.is_connected(_on_healing_animation_finished):
		player.animated_sprite.animation_finished.disconnect(_on_healing_animation_finished)
	
	# 重置到 idle 動畫
	if player and player.animated_sprite:
		player.animated_sprite.play("idle")

func set_healing_source(source: String) -> void:
	healing_source = source
