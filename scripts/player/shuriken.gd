extends Area2D

@export var speed = 400
@export var damage = 15
@export var lifetime = 5.0

var direction = Vector2.ZERO
var timer: Timer

func _ready():
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_on_lifetime_timeout)
	timer.set_one_shot(true)
	timer.start(lifetime)
	var notifier = VisibleOnScreenNotifier2D.new()
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)

func _physics_process(delta):
	position += direction * speed * delta

func set_direction(new_direction: Vector2):
	direction = new_direction.normalized()
	rotation = direction.angle()

func _on_body_entered(body):
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	elif body.get_collision_layer_value(1):
		queue_free()

func _on_lifetime_timeout():
	queue_free()

func _on_screen_exited():
	queue_free()
