extends Area2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var shield_effect = $ShieldEffect
@onready var hitbox = $Hitbox
@onready var interaction_label = $InteractionLabel

var idle_timer := 0.0
var dialogue_cooldown := 0.0
var can_play_random_idle := true
var current_state := "idle"
var current_tween: Tween
var player_in_range := false
var current_dialogue_index := 0
var is_in_dialogue := false
var has_special_dialogue_played := false

const SPECIAL_DIALOGUE = [
	"我是一個商人",
	"但我並沒有什麼東西能賣給你",
	"唯一能給你的",
	"就是我火熱的心……",
	"※血量跟重生次數恢復了！"
]

const NORMAL_DIALOGUE = [
	"這塊石頭感覺可以賣？",
	"好冷……好想離開……",
	"前面感覺很危險……",
	"我到底怎麼走到這來的？",
	"如果我是你就不會再往前了",
	"那真是把好刀",
	"不錯的髮型",
	"Zzz......",
	"現在是白天還是晚上？",
	"終於見到人類了"
]

@export var fade_duration := 0.3
@export var fade_alpha := 0.5
const KNOCKBACK_FORCE := Vector2(800, 0)

func _ready():
	collision_shape.disabled = false
	
	# 設置碰撞層
	collision_layer = 4  # 第3層(受傷區域) = 2^2 = 4
	collision_mask = 10   # 第2層(玩家)和第4層(攻擊區域) = 2^1 + 2^3 = 2 + 8 = 10
	
	animated_sprite.modulate.a = 1.0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_hitbox_area_entered)
	animated_sprite.play("idle")
	
	if shield_effect:
		shield_effect.visible = false
		shield_effect.z_index = 2
		
	if interaction_label:
		interaction_label.text = "按 S 互動"
		interaction_label.visible = false

func _process(delta):
	match current_state:
		"idle":
			_handle_idle_state(delta)
		"dialogue":
			_handle_dialogue_state(delta)
		"approval":
			if not animated_sprite.is_playing():
				_change_state("idle")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if not is_in_dialogue:
			start_dialogue()
		if current_tween and current_tween.is_valid():
			current_tween.kill()
		current_tween = create_tween()
		current_tween.tween_property(animated_sprite, "modulate:a", fade_alpha, fade_duration * 2)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if interaction_label:
			interaction_label.visible = false
		if current_tween and current_tween.is_valid():
			current_tween.kill()
		current_tween = create_tween()
		current_tween.tween_property(animated_sprite, "modulate:a", 1.0, fade_duration)

func start_dialogue():
	is_in_dialogue = true
	
	if not has_special_dialogue_played:
		# 播放特殊對話
		current_dialogue_index = 0
		_show_special_dialogue()
	else:
		# 播放隨機普通對話
		_show_normal_dialogue()

func _show_special_dialogue():
	if current_dialogue_index >= SPECIAL_DIALOGUE.size():
		is_in_dialogue = false
		has_special_dialogue_played = true
		if interaction_label:
			interaction_label.visible = true
		# 在對話結束時恢復玩家血量和重生次數
		var player = get_tree().get_first_node_in_group("player")
		if player:
			if player.has_method("restore_health"):
				player.restore_health()
			if player.has_method("restore_lives"):
				player.restore_lives()
		return
	
	if interaction_label:
		interaction_label.text = SPECIAL_DIALOGUE[current_dialogue_index]
		interaction_label.visible = true
	
	await get_tree().create_timer(2.0).timeout
	current_dialogue_index += 1
	_show_special_dialogue()

func _show_normal_dialogue():
	if interaction_label:
		# 隨機選擇一個普通對話
		var random_dialogue = NORMAL_DIALOGUE[randi() % NORMAL_DIALOGUE.size()]
		interaction_label.text = random_dialogue
		interaction_label.visible = true
		interaction_label.modulate.a = 0.0
		
		# 淡入效果
		var fade_in_tween = create_tween()
		fade_in_tween.set_trans(Tween.TRANS_SINE)
		fade_in_tween.set_ease(Tween.EASE_OUT)
		fade_in_tween.tween_property(interaction_label, "modulate:a", 1.0, 0.3)
		
		# 等待顯示時間
		await get_tree().create_timer(2.0).timeout
		
		# 淡出效果
		var fade_out_tween = create_tween()
		fade_out_tween.set_trans(Tween.TRANS_SINE)
		fade_out_tween.set_ease(Tween.EASE_IN)
		fade_out_tween.tween_property(interaction_label, "modulate:a", 0.0, 0.3)
		await fade_out_tween.finished
		
		is_in_dialogue = false
		interaction_label.visible = false

func _handle_idle_state(delta):
	if can_play_random_idle:
		idle_timer += delta
		if idle_timer >= 1.0:
			idle_timer = 0.0
			
			if randf() < 0.2:
				var random_idle = "idle2" if randf() < 0.5 else "idle3"
				animated_sprite.play(random_idle)
				await animated_sprite.animation_finished
			
			animated_sprite.play("idle")
			can_play_random_idle = true

func _handle_dialogue_state(delta):
	dialogue_cooldown -= delta
	if dialogue_cooldown <= 0:
		if randf() < 0.3:
			animated_sprite.play("dialogue")
			await animated_sprite.animation_finished
			animated_sprite.play("dialogue")
			dialogue_cooldown = 4.0
		else:
			animated_sprite.play("dialogue")
			dialogue_cooldown = 2.0
		
		_change_state("idle")

func play_approval():
	_change_state("approval")
	animated_sprite.play("approval")

func _change_state(new_state: String):
	current_state = new_state

func take_damage() -> void:
	# 播放護盾特效，帶淡入淡出效果
	if shield_effect:
		# 先重置透明度並顯示
		shield_effect.modulate.a = 0
		shield_effect.visible = true
		shield_effect.play("default")
		
		# 淡入效果
		var fade_in_tween = create_tween()
		fade_in_tween.tween_property(shield_effect, "modulate:a", 1.0, 0.2)
		
		# 創建一個計時器來觸發淡出效果
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(func():
			# 淡出效果
			var fade_out_tween = create_tween()
			fade_out_tween.tween_property(shield_effect, "modulate:a", 0.0, 0.2)
			fade_out_tween.tween_callback(func():
				shield_effect.stop()
				shield_effect.visible = false
			)
		)
	
	# 擊退玩家（只有水平方向）
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_knockback"):
		var direction = sign(player.global_position.x - global_position.x)  # 只取水平方向
		var knockback = Vector2(direction * KNOCKBACK_FORCE.x, 0)  # 只有水平擊退
		player.apply_knockback(knockback)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(4):  # 檢查是否是攻擊區域
		var parent = area.get_parent()
		if parent.is_in_group("player"):
			# 直接檢查玩家的攻擊狀態
			if area.name == "AttackArea" and parent.is_attacking:
				take_damage()
			elif area.name == "SpecialAttackArea" and parent.is_special_attacking:
				take_damage()
