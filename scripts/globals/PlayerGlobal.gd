extends Node

# Static reference to the single instance of PlayerGlobal
static var instance: PlayerGlobal = null

# Holds the reference to the actual player node
var player_node: CharacterBody2D = null

# Signal emitted when the player node is registered or becomes invalid
signal player_registration_changed(is_registered: bool)

func _enter_tree() -> void:
	if instance == null:
		instance = self
		# You might want to make this node process always,
		# or ensure it's correctly placed in the scene tree if it needs _process or _physics_process
		# process_mode = Node.PROCESS_MODE_ALWAYS 
		print("[PlayerGlobal] PlayerGlobal instance created.")
	else:
		# If another instance tries to register, queue_free the new one.
		# This can happen if the autoload is somehow added to the scene manually again.
		printerr("[PlayerGlobal] Another instance of PlayerGlobal tried to enter the tree. Freeing the new one.")
		queue_free()

# Called by the Player node to register itself
func register_player(p_player_node: CharacterBody2D) -> void:
	if is_instance_valid(p_player_node):
		player_node = p_player_node
		# Safer print statement
		var player_name_for_log : String
		if is_instance_valid(player_node):
			player_name_for_log = player_node.name
		else:
			player_name_for_log = "invalid_or_null_player_node"
		print("[PlayerGlobal] Player registered: ", player_name_for_log)
		player_registration_changed.emit(true)
	else:
		player_node = null
		printerr("[PlayerGlobal] Attempted to register an invalid player node.")
		player_registration_changed.emit(false)

# Called if the player node is freed or becomes invalid elsewhere
func unregister_player() -> void:
	# Safer print statement
	var player_name_for_log : String
	if is_instance_valid(player_node):
		player_name_for_log = player_node.name
	else:
		player_name_for_log = "invalid_or_null_player_node_at_unregister"
		
	if player_node != null: # Keep the original condition for logging message context
		print("[PlayerGlobal] Player unregistered: ", player_name_for_log)
	player_node = null
	player_registration_changed.emit(false)

# Static function to get the player node
static func get_player() -> CharacterBody2D:
	if instance and is_instance_valid(instance.player_node):
		return instance.player_node
	# Optional: Add a print warning if player is requested but not available
	# if instance:
	#     print_debug("[PlayerGlobal.get_player()] Player node requested but not available or invalid.")
	# else:
	#     print_debug("[PlayerGlobal.get_player()] PlayerGlobal instance not available.")
	return null

# Static function to check if the player is currently registered and valid
static func is_player_available() -> bool:
	return instance and is_instance_valid(instance.player_node)

# Optional: Connect to the player's tree_exiting signal if you want to auto-unregister
# func _on_player_tree_exiting():
#     unregister_player()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			print("[PlayerGlobal] PlayerGlobal instance being freed.")
			if is_instance_valid(player_node):
				# This might be redundant if the player is also being freed,
				# but good for cleanup if PlayerGlobal is removed for other reasons.
				player_node = null 
			instance = null
			player_registration_changed.emit(false) 
 
