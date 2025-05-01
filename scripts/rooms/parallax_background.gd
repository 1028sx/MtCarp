extends ParallaxBackground

#region 導出參數
# 基礎設置
@export_group("Basic Settings")
@export var scroll_speed := 0.5
@export var player_influence := 0.3

# 視差層級設置
@export_group("Layer Motion Scales")
@export var layer1_scale := 0.1  # 最遠層
@export var layer2_scale := 0.2
@export var layer3_scale := 0.3  # FX層
@export var layer4_scale := 0.4
@export var layer5_scale := 0.5
@export var layer6_scale := 0.6  # FX層
@export var layer7_scale := 0.7
@export var layer8_scale := 0.8  # FX層
@export var layer9_scale := 0.9  # 最近層

# 特效設置
@export_group("FX Settings")
@export var fx_pulse_speed := 1.5
@export var fx_min_alpha := 0.3
@export var fx_max_alpha := 1.0
@export var fx_phase_shift := PI/2

# 顏色設置
@export_group("Color Settings")
@export var base_color := Color.from_hsv(0.98, 0.7, 0.4)
@export var far_layers_tint := Color.from_hsv(0.98, 0.6, 0.5)
@export var near_layers_tint := Color.from_hsv(0.98, 0.8, 0.3)
@export var fx_layers_tint := Color(0.8, 0.65, 0.4, 1.0)

# 背景設置
@export_group("Background Settings")
@export var background_scale := Vector2(0.7, 0.7)
@export var background_offset := Vector2(200, 100)
@export var adjust_scale_per_layer := 0.0
#endregion

#region 變量
var player: CharacterBody2D
var time_passed := 0.0
#endregion

#region 生命週期函數
func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	player = get_tree().get_first_node_in_group("player")
	_initialize_layers()

func _process(delta: float) -> void:
	if player:
		_update_scroll(delta)
	time_passed += delta
	_update_fx_layers()
#endregion

#region 初始化
func _initialize_layers() -> void:
	for i in range(9):
		var parallax_layer = _get_layer_by_name("Layer" + str(i + 1))
		if not parallax_layer:
			continue
			
		_setup_layer_motion(parallax_layer, i)
		_setup_layer_sprites(parallax_layer, i)
#endregion

#region 層級設置
func _setup_layer_motion(parallax_layer: ParallaxLayer, layer_index: int) -> void:
	var motion_scale = get("layer" + str(layer_index + 1) + "_scale")
	parallax_layer.motion_scale = Vector2(motion_scale, motion_scale * 0.5)

func _setup_layer_sprites(parallax_layer: ParallaxLayer, layer_index: int) -> void:
	var original_sprite = parallax_layer.get_child(0) if parallax_layer.get_child_count() > 0 else null
	if not original_sprite or not original_sprite is Sprite2D:
		return
		
	_create_additional_sprites(parallax_layer, original_sprite, layer_index)
	_setup_original_sprite(original_sprite, layer_index)
	
	if layer_index + 1 in [3, 6, 8]:
		_set_layer_alpha(parallax_layer, fx_min_alpha)

func _create_additional_sprites(parallax_layer: ParallaxLayer, original_sprite: Sprite2D, layer_index: int) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var sprite_size = original_sprite.texture.get_size() * background_scale
	var sprites_needed = ceil(viewport_size.x / sprite_size.x) + 2
	
	for j in range(sprites_needed - 1):
		var new_sprite = _create_sprite(original_sprite, layer_index)
		new_sprite.position = background_offset + Vector2(sprite_size.x * (j + 1), 0)
		parallax_layer.add_child(new_sprite)

func _setup_original_sprite(sprite: Sprite2D, layer_index: int) -> void:
	sprite.scale = background_scale
	sprite.position = background_offset
	sprite.modulate = _get_layer_color(layer_index + 1)
#endregion

#region 更新函數
func _update_scroll(delta: float) -> void:
	var player_velocity = player.velocity.x * delta * player_influence
	scroll_offset.x -= player_velocity
	
	for i in range(9):
		var parallax_layer = _get_layer_by_name("Layer" + str(i + 1))
		if parallax_layer:
			_check_and_reset_sprites(parallax_layer)

func _update_fx_layers() -> void:
	var fx_layers = [3, 6, 8]
	for i in range(fx_layers.size()):
		var layer_num = fx_layers[i]
		var parallax_layer = _get_layer_by_name("Layer" + str(layer_num))
		if parallax_layer:
			var phase = fx_phase_shift * i
			var alpha = lerp(fx_min_alpha, fx_max_alpha, 
						   (sin(time_passed * fx_pulse_speed + phase) + 1.0) * 0.5)
			_set_layer_alpha(parallax_layer, alpha)
#endregion

#region 輔助函數
func _create_sprite(original: Sprite2D, layer_index: int) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = original.texture
	sprite.scale = background_scale
	sprite.modulate = _get_layer_color(layer_index + 1)
	return sprite

func _get_layer_color(layer_num: int) -> Color:
	if layer_num in [3, 6, 8]:
		return fx_layers_tint
	elif layer_num < 4:
		return far_layers_tint
	elif layer_num > 6:
		return near_layers_tint
	return base_color

func _check_and_reset_sprites(parallax_layer: ParallaxLayer) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var sprite_size = parallax_layer.get_child(0).texture.get_size() * background_scale
	
	for sprite in parallax_layer.get_children():
		if not sprite is Sprite2D:
			continue
			
		var screen_pos = sprite.position + scroll_offset * parallax_layer.motion_scale
		if screen_pos.x + sprite_size.x < 0:
			sprite.position.x = _get_rightmost_sprite_position(parallax_layer).x + sprite_size.x
		elif screen_pos.x > viewport_size.x + sprite_size.x:
			sprite.position.x = _get_leftmost_sprite_position(parallax_layer).x - sprite_size.x

func _get_rightmost_sprite_position(parallax_layer: ParallaxLayer) -> Vector2:
	var rightmost_pos = Vector2.ZERO
	for sprite in parallax_layer.get_children():
		if sprite is Sprite2D:
			rightmost_pos.x = max(rightmost_pos.x, sprite.position.x)
	return rightmost_pos

func _get_leftmost_sprite_position(parallax_layer: ParallaxLayer) -> Vector2:
	var leftmost_pos = Vector2(INF, 0)
	for sprite in parallax_layer.get_children():
		if sprite is Sprite2D:
			leftmost_pos.x = min(leftmost_pos.x, sprite.position.x)
	return leftmost_pos

func _get_layer_by_name(layer_name: String) -> ParallaxLayer:
	for child in get_children():
		if child is ParallaxLayer and child.name == layer_name:
			return child
	return null

func _set_layer_alpha(parallax_layer: ParallaxLayer, alpha: float) -> void:
	for sprite in parallax_layer.get_children():
		if sprite is Sprite2D:
			sprite.modulate.a = alpha
#endregion

#region 公共接口
func adjust_background_settings(new_scale: Vector2, new_offset: Vector2) -> void:
	background_scale = new_scale
	background_offset = new_offset
	_initialize_layers()
#endregion
