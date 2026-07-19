## Interface-like base for SVO resources.
@tool
extends Resource
class_name ASvo


func support_query_solid() -> bool:
	assert(false, "Not implemented")
	return false


func support_query_coverage() -> bool:
	assert(false, "Not implemented")
	return false


func get_layer_count() -> int:
	assert(false, "Not implemented")
	return 0


func set_layer_count(_layer_count: int) -> void:
	assert(false, "Not implemented")


func get_node_count_in_layer(_layer: int) -> int:
	assert(false, "Not implemented")
	return 0


func set_node_count_in_layer(_layer: int, _node_count: int) -> void:
	assert(false, "Not implemented")


func get_morton(_layer: int, _index: int) -> int:
	assert(false, "Not implemented")
	return 0


func set_morton(_layer: int, _index: int, _morton3_value: int) -> void:
	assert(false, "Not implemented")


func get_parent(_layer: int, _index: int) -> int:
	assert(false, "Not implemented")
	return ~0


func set_parent(_layer: int, _index: int, _parent_svolink: int) -> void:
	assert(false, "Not implemented")


func get_first_child(_layer: int, _index: int) -> int:
	assert(false, "Not implemented")
	return ~0


func set_first_child(_layer: int, _index: int, _first_child_svolink: int) -> void:
	assert(false, "Not implemented")


func get_subgrid(_index: int) -> int:
	assert(false, "Not implemented")
	return 0


func set_subgrid(_index: int, _subgrid_bitmask: int) -> void:
	assert(false, "Not implemented")


func get_xp_neighbor(_layer: int, _index: int) -> int:
	assert(false, "Not implemented")
	return ~0


func set_xp_neighbor(_layer: int, _index: int, _xp_svolink: int) -> void:
	assert(false, "Not implemented")


func get_yp_neighbor(_layer: int, _index: int) -> int:
	assert(false, "Not implemented")
	return ~0


func set_yp_neighbor(_layer: int, _index: int, _yp_svolink: int) -> void:
	assert(false, "Not implemented")


func get_zp_neighbor(_layer: int, _index: int) -> int:
	assert(false, "Not implemented")
	return ~0


func set_zp_neighbor(_layer: int, _index: int, _zp_svolink: int) -> void:
	assert(false, "Not implemented")


func get_xn_neighbor(_layer: int, _index: int) -> int:
	assert(false, "Not implemented")
	return ~0


func set_xn_neighbor(_layer: int, _index: int, _xn_svolink: int) -> void:
	assert(false, "Not implemented")


func get_yn_neighbor(_layer: int, _index: int) -> int:
	assert(false, "Not implemented")
	return ~0


func set_yn_neighbor(_layer: int, _index: int, _yn_svolink: int) -> void:
	assert(false, "Not implemented")


func get_zn_neighbor(_layer: int, _index: int) -> int:
	assert(false, "Not implemented")
	return ~0


func set_zn_neighbor(_layer: int, _index: int, _zn_svolink: int) -> void:
	assert(false, "Not implemented")


func get_flag_inside(_layer: int, _index: int) -> bool:
	assert(false, "Not implemented")
	return false


func set_flag_inside(_layer: int, _index: int, _inside: bool) -> void:
	assert(false, "Not implemented")


func get_flag_flip(_layer: int, _index: int) -> bool:
	assert(false, "Not implemented")
	return false


func set_flag_flip(_layer: int, _index: int, _flip: bool) -> void:
	assert(false, "Not implemented")


func get_coverage(_layer: int, _index: int) -> float:
	assert(false, "Not implemented")
	return NAN


func set_coverage(_layer: int, _index: int, _coverage_value: float) -> void:
	assert(false, "Not implemented")


func get_node_center(_svolink: int) -> Vector3:
	assert(false, "Not implemented")
	return Vector3.ZERO


func get_voxel_center(_svolink: int) -> Vector3:
	assert(false, "Not implemented")
	return Vector3.ZERO


func get_voxels_and_nodes_on_face_xp(_svolink: int) -> PackedInt64Array:
	assert(false, "Not implemented")
	return []


func get_voxels_and_nodes_on_face_yp(_svolink: int) -> PackedInt64Array:
	assert(false, "Not implemented")
	return []


func get_voxels_and_nodes_on_face_zp(_svolink: int) -> PackedInt64Array:
	assert(false, "Not implemented")
	return []


func get_voxels_and_nodes_on_face_xn(_svolink: int) -> PackedInt64Array:
	assert(false, "Not implemented")
	return []


func get_voxels_and_nodes_on_face_yn(_svolink: int) -> PackedInt64Array:
	assert(false, "Not implemented")
	return []


func get_voxels_and_nodes_on_face_zn(_svolink: int) -> PackedInt64Array:
	assert(false, "Not implemented")
	return []


func get_svolink_from_node_morton(_layer: int, _morton3_value: int) -> int:
	assert(false, "Not implemented")
	return ~0


func get_svolink_from_voxel_morton(_morton3_value: int) -> int:
	assert(false, "Not implemented")
	return ~0


func get_neighbors_of(_svolink: int) -> PackedInt64Array:
	assert(false, "Not implemented")
	return []


func is_solid(_layer_or_svolink: int, _index: int = -1) -> bool:
	assert(false, "Not implemented")
	return false


func get_offsets_of_head_nodes_in_x_direction_of_layer(_layer: int) -> PackedInt64Array:
	assert(false, "Not implemented")
	return []


func get_solid_bit_counts_by_subgrid() -> PackedInt32Array:
	assert(false, "Not implemented")
	return []


func parallel_get_solid_bit_counts_by_subgrid(
	_async_context: Signal,
	_thread_priority: Thread.Priority
) -> PackedInt32Array:
	assert(false, "Not implemented")
	return []
