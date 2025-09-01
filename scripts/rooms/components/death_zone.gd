extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var current_room = get_parent()
		while current_room and not current_room.is_in_group("room"):
			current_room = current_room.get_parent()
			
		if current_room:
			var left_spawn = current_room.get_node_or_null("SpawnPoints/LeftSpawn")
			if left_spawn:
				body.global_position = left_spawn.global_position

	elif body.is_in_group("enemy"):
		body.queue_free()
