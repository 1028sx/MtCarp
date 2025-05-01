extends Area2D

var player_ref: CharacterBody2D = null
var platform_collision: StaticBody2D = null

func _ready() -> void:
	collision_layer = 0  # 不設置碰撞層
	collision_mask = 2   # 檢測玩家層
	
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# 創建一個 StaticBody2D 作為實際的平台
	platform_collision = StaticBody2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = $CollisionShape2D.shape  # 複製 Area2D 的形狀
	collision_shape.one_way_collision = true  # 設置為單向碰撞
	collision_shape.one_way_collision_margin = 8  # 設置單向碰撞邊緣
	platform_collision.add_child(collision_shape)
	add_child(platform_collision)

func _physics_process(_delta: float) -> void:
	if player_ref and platform_collision:
		# 檢查玩家是否在平台上方
		if player_ref.global_position.y + player_ref.get_node("CollisionShape2D").shape.size.y/2 < global_position.y:
			# 啟用碰撞
			platform_collision.collision_layer = 1  # 設為地形層
		else:
			# 禁用碰撞
			platform_collision.collision_layer = 0  # 不作為地形層

func _on_area_entered(area: Area2D) -> void:
	var body = area.get_parent()
	if body.is_in_group("player"):
		player_ref = body

func _on_area_exited(area: Area2D) -> void:
	var body = area.get_parent()
	if body.is_in_group("player"):
		player_ref = null
		if platform_collision:
			platform_collision.collision_layer = 1  # 恢復碰撞
