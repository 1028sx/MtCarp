extends Area2D

signal collected

@onready var sprite = $AnimatedSprite2D
@onready var interaction_prompt = $InteractionPrompt

# Loot 屬性
var ability_key: String = ""
var ability_name: String = ""
var ability_description: String = ""

# 狀態管理
var _can_interact := false
var _is_collected := false
var _fade_out_timer := 0.0
var _fade_tween: Tween

func _ready() -> void:
	add_to_group("loot")
	_setup_collision()
	_setup_sprite()
	_setup_interaction_prompt()
	_connect_signals()

func _process(delta: float) -> void:
	if _fade_out_timer > 0:
		_fade_out_timer -= delta
		if _fade_out_timer <= 0:
			_fade_out()

func _fade_in() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(interaction_prompt, "modulate:a", 1.0, 0.3)

func _fade_out() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.set_ease(Tween.EASE_IN)
	_fade_tween.tween_property(interaction_prompt, "modulate:a", 0.0, 0.3)


func _input(event: InputEvent) -> void:
	if not _can_interact or _is_collected:
		return
		
	if event.is_action_pressed("interact"):
		_handle_interaction()

func _handle_interaction() -> void:
	if ability_key.is_empty():
		push_warning("Loot 沒有設定 ability_key")
		return
	
	_is_collected = true
	
	# 通過RewardSystem處理收集
	var reward_system = get_node_or_null("/root/RewardSystem")
	if reward_system and reward_system.has_method("collect_loot"):
		if has_meta("loot_id"):
			# 由RewardSystem統一處理loot收集和能力解鎖
			var loot_id = get_meta("loot_id")
			reward_system.collect_loot(loot_id, ability_key)
		else:
			# 手動loot收集
			reward_system.collect_loot("manual_" + ability_key, ability_key)
	else:
		push_error("RewardSystem不存在，無法處理戰利品收集")
	
	collected.emit()
	_fade_out_and_destroy()

func setup_ability(p_ability_key: String, p_ability_name: String, p_ability_description: String) -> void:
	ability_key = p_ability_key
	ability_name = p_ability_name
	ability_description = p_ability_description

func _fade_out_and_destroy() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0, 0.3)
	_fade_tween.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _is_collected:
		_can_interact = true
		_fade_in()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_interact = false
		if interaction_prompt:
			interaction_prompt.modulate.a = 0.0

func collect() -> void:
	await get_tree().create_timer(1.0).timeout
	queue_free()


# 私有輔助方法
func _setup_collision() -> void:
	collision_layer = 0
	collision_mask = 2

func _setup_sprite() -> void:
	if sprite:
		sprite.play("default")

func _setup_interaction_prompt() -> void:
	if not interaction_prompt:
		return
		
	interaction_prompt.text = "按下S以收集"
	interaction_prompt.modulate.a = 0
	interaction_prompt.show()

func _connect_signals() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
