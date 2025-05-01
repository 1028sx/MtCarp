extends Area2D

#region 導出屬性
@export var bullet_speed = 300.0
@export var damage = 10
#endregion

#region 節點引用
@onready var animated_sprite = $AnimatedSprite2D
#endregion

var velocity = Vector2.ZERO
var bullet_color = "White"  # 默認顏色

# 新增：顏色字典，存儲所有顏色的 RGB 值和透明度
const COLOR_SETTINGS = {
	"Red": Color(1.5, 0.3, 0.3, 0.8),    # 鮮紅色
	"Orange": Color(1.5, 0.8, 0.3, 0.8),  # 橙色
	"Yellow": Color(1.5, 1.5, 0.3, 0.8),  # 黃色
	"Green": Color(0.3, 1.5, 0.3, 0.8),   # 綠色
	"Blue": Color(0.3, 0.3, 1.5, 0.8),    # 藍色
	"Purple": Color(1.2, 0.3, 1.2, 0.8),  # 紫色
	"Black": Color(0.2, 0.2, 0.2, 0.8),   # 黑色
	"White": Color(1.2, 1.2, 1.2, 0.8)    # 白色
}

func setup(direction: Vector2, speed: float, bullet_damage: int, color: String = "White"):
	velocity = direction * speed
	damage = bullet_damage
	bullet_color = color
	rotation = direction.angle()  # 設置旋轉以匹配移動方向
	
	# 立即應用顏色效果
	_apply_color_effect()

func _ready():
	# 設置碰撞層
	set_collision_layer_value(4, true)  # 設為攻擊層
	set_collision_mask_value(3, true)   # 檢測受傷層
	
	# 連接信號
	area_entered.connect(_on_area_entered)
	
	# 設置自動銷毀計時器
	var timer = get_tree().create_timer(5.0)  # 5秒後自動銷毀
	timer.timeout.connect(queue_free)
	
	# 播放動畫
	if animated_sprite:
		animated_sprite.play("shoot")
		# 確保顏色效果被應用
		_apply_color_effect()

# 新增：獨立的顏色應用函數
func _apply_color_effect():
	if animated_sprite and COLOR_SETTINGS.has(bullet_color):
		animated_sprite.modulate = COLOR_SETTINGS[bullet_color]
		# 強制更新視覺效果
		animated_sprite.queue_redraw()

func _physics_process(delta):
	position += velocity * delta

func _on_area_entered(area: Area2D):
	var body = area.get_parent()
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free() 

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()  # 離開螢幕時銷毀
