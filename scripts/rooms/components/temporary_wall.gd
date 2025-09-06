extends StaticBody2D

class_name TemporaryWall

signal spawn_animation_finished
signal despawn_animation_finished

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var is_spawning: bool = false
var is_despawning: bool = false

func _ready() -> void:
	add_to_group("temporary_walls")
	
	# 設置初始狀態（隱藏且禁用碰撞）
	if animated_sprite:
		animated_sprite.visible = false
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")
			animated_sprite.stop()
	if collision:
		collision.disabled = true
	
	# 連接動畫信號
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)

func play_spawn_animation() -> void:
	if is_spawning or is_despawning:
		return
	is_spawning = true
	collision.disabled = false
	
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("appear"):
		animated_sprite.visible = true
		animated_sprite.play("appear")
	else:
		_play_fallback_spawn_animation()

func play_despawn_animation() -> void:
	if is_despawning or is_spawning:
		return
	
	is_despawning = true
	collision.disabled = true
	
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("disappear"):
		animated_sprite.play("disappear")
	else:
		# 後備：直接隱藏
		_play_fallback_despawn_animation()

func _play_fallback_spawn_animation() -> void:
	if animated_sprite:
		animated_sprite.visible = true
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")
	_on_spawn_animation_complete()

func _play_fallback_despawn_animation() -> void:
	if animated_sprite:
		animated_sprite.visible = false
	_on_despawn_animation_complete()

func _on_animation_finished() -> void:
	var anim_name = animated_sprite.animation
	match anim_name:
		"appear":
			# appear動畫結束後播放default動畫
			if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("default"):
				animated_sprite.play("default")
			_on_spawn_animation_complete()
		"disappear":
			animated_sprite.visible = false
			_on_despawn_animation_complete()

func _on_spawn_animation_complete() -> void:
	is_spawning = false
	if animated_sprite:
		animated_sprite.visible = true
	collision.disabled = false
	spawn_animation_finished.emit()

func _on_despawn_animation_complete() -> void:
	is_despawning = false
	if animated_sprite:
		animated_sprite.visible = false
	collision.disabled = true
	despawn_animation_finished.emit()

# 檢查是否處於動畫狀態
func is_animating() -> bool:
	return is_spawning or is_despawning

# 強制停止所有動畫
func stop_animations() -> void:
	if animated_sprite and animated_sprite.is_playing():
		animated_sprite.stop()
	
	is_spawning = false
	is_despawning = false
