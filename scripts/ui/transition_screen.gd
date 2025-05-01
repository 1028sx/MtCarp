extends CanvasLayer

@onready var animation_player = $"AnimationPlayer"
@onready var black_rect = $"ColorRect"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if black_rect:
		black_rect.color = Color(0, 0, 0, 0)
		black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		black_rect.z_index = 100

func fade_to_black():
	if animation_player:
		animation_player.play("fade_to_black")
		await animation_player.animation_finished

func fade_from_black():
	if animation_player:
		animation_player.play("fade_from_black")
		await animation_player.animation_finished 
