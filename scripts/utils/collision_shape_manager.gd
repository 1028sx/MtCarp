extends RefCounted

class_name CollisionShapeManager

## 碰撞形狀管理器 - 統一的碰撞形狀共享系統
## 用於 EnemyAIBase、BossBase、Bubble 等所有需要 Hitbox 和 TouchDamageArea 的類別

## 為目標 Area2D 更新碰撞形狀
static func update_area_shape(target_area: Area2D, source_shape_node: CollisionShape2D, owner_name: String = "") -> void:
	if not is_instance_valid(target_area):
		if owner_name != "":
			push_warning("[%s] CollisionShapeManager: target_area 無效" % owner_name)
		return
	
	if not source_shape_node or not source_shape_node.shape:
		if owner_name != "":
			push_warning("[%s] CollisionShapeManager: 無法更新 '%s' 的形狀，因為來源形狀無效。" % [owner_name, target_area.name])
		return

	# 清理現有的 CollisionShape2D
	for child in target_area.get_children():
		if child is CollisionShape2D:
			child.queue_free()
	
	var new_shape_node := CollisionShape2D.new()
	new_shape_node.shape = source_shape_node.shape.duplicate()
	
	# 使用延遲調用避免物理查詢衝突
	target_area.call_deferred("add_child", new_shape_node)
	
	if owner_name != "":
		print("[%s] CollisionShapeManager: 為 %s 創建了 CollisionShape2D，形狀: %s" % [owner_name, target_area.name, new_shape_node.shape])

## 查找第一個啟用的 CollisionShape2D
static func find_active_shape(parent_node: Node) -> CollisionShape2D:
	for child in parent_node.get_children():
		if child is CollisionShape2D and not child.disabled:
			return child
	return null

## 初始化形狀共享系統
static func initialize_shape_sharing(
	owner_node: Node, 
	hitbox_area: Area2D = null, 
	touch_damage_area: Area2D = null
) -> CollisionShape2D:
	var source_shape_node = find_active_shape(owner_node)
	
	if not is_instance_valid(source_shape_node):
		push_warning("[%s] CollisionShapeManager: 找不到任何可用的來源 CollisionShape2D。形狀共享功能將無法運作。" % owner_node.name)
		return null
		
	if not source_shape_node.shape:
		push_warning("[%s] CollisionShapeManager: 來源 CollisionShape2D '%s' 沒有指定有效的 shape。" % [owner_node.name, source_shape_node.name])
		return null

	update_area_shape(touch_damage_area, source_shape_node, owner_node.name)
	update_area_shape(hitbox_area, source_shape_node, owner_node.name)
	
	return source_shape_node

## 更新共享形狀
static func update_shared_shapes(
	owner_node: Node,
	hitbox_area: Area2D = null,
	touch_damage_area: Area2D = null,
	source_shape_node: CollisionShape2D = null
) -> CollisionShape2D:
	var actual_source_shape: CollisionShape2D = source_shape_node
	
	if not actual_source_shape:
		actual_source_shape = find_active_shape(owner_node)
	
	if not is_instance_valid(actual_source_shape):
		push_warning("[%s] CollisionShapeManager: 呼叫 update_shared_shapes 時找不到啟用的來源碰撞體。" % owner_node.name)
		return null
	
	if not actual_source_shape.shape:
		push_warning("[%s] CollisionShapeManager: 新的來源 CollisionShape2D '%s' 沒有指定有效的 shape。" % [owner_node.name, actual_source_shape.name])
		return null
	
	update_area_shape(touch_damage_area, actual_source_shape, owner_node.name)
	update_area_shape(hitbox_area, actual_source_shape, owner_node.name)
	
	return actual_source_shape
