extends Area2D

@export_multiline var display_text: String = "預設文字"
@onready var label = $Label

var can_interact := false
var fade_out_timer := 0.0
var fade_tween: Tween

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2

	if label:
		label.text = display_text
		label.modulate.a = 0
		label.show()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func set_text(new_text: String) -> void:
	display_text = new_text
	if label:
		label.text = new_text

func _process(delta: float) -> void:
	if fade_out_timer > 0:
		fade_out_timer -= delta
		if fade_out_timer <= 0:
			_fade_out()

func _fade_in() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(label, "modulate:a", 1.0, 0.3)

func _fade_out() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.3)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_interact = true
		fade_out_timer = 0
		_fade_in()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_interact = false
		fade_out_timer = 1.0
