extends Area2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var current_room = get_parent()
		while current_room and not current_room.name.begins_with("Room"):
			current_room = current_room.get_parent()

		if current_room:
			var left_spawn = current_room.get_node("SpawnPoints/LeftSpawn")
			if left_spawn:
				body.global_position = left_spawn.global_position

	elif body.is_in_group("enemy"):
		body.queue_free()
