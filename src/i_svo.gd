## Interface-like base for SVO resources.
@tool
extends Resource
class_name ISvo


func _abstract_fail(method_name: String) -> void:
	var message: String = "ISvo.%s() is abstract. Override in subclass." % method_name
	push_error(message)
	assert(false, message)


func support_query_solid() -> bool:
	_abstract_fail("support_query_solid")
	return false


func support_query_coverage() -> bool:
	_abstract_fail("support_query_coverage")
	return false


func get_layer_count() -> int:
	_abstract_fail("get_layer_count")
	return 0


func set_layer_count(_layer_count: int) -> void:
	_abstract_fail("set_layer_count")


func get_node_count_in_layer(_layer: int) -> int:
	_abstract_fail("get_node_count_in_layer")
	return 0


func set_node_count_in_layer(_layer: int, _node_count: int) -> void:
	_abstract_fail("set_node_count_in_layer")


func get_morton(_layer: int, _index: int) -> int:
	_abstract_fail("get_morton")
	return 0


func set_morton(_layer: int, _index: int, _morton3_value: int) -> void:
	_abstract_fail("set_morton")


func get_parent(_layer: int, _index: int) -> int:
	_abstract_fail("get_parent")
	return ~0


func set_parent(_layer: int, _index: int, _parent_svolink: int) -> void:
	_abstract_fail("set_parent")


func get_first_child(_layer: int, _index: int) -> int:
	_abstract_fail("get_first_child")
	return ~0


func set_first_child(_layer: int, _index: int, _first_child_svolink: int) -> void:
	_abstract_fail("set_first_child")


func get_subgrid(_index: int) -> int:
	_abstract_fail("get_subgrid")
	return 0


func set_subgrid(_index: int, _subgrid_bitmask: int) -> void:
	_abstract_fail("set_subgrid")


func get_xp_neighbor(_layer: int, _index: int) -> int:
	_abstract_fail("get_xp_neighbor")
	return ~0


func set_xp_neighbor(_layer: int, _index: int, _xp_svolink: int) -> void:
	_abstract_fail("set_xp_neighbor")


func get_yp_neighbor(_layer: int, _index: int) -> int:
	_abstract_fail("get_yp_neighbor")
	return ~0


func set_yp_neighbor(_layer: int, _index: int, _yp_svolink: int) -> void:
	_abstract_fail("set_yp_neighbor")


func get_zp_neighbor(_layer: int, _index: int) -> int:
	_abstract_fail("get_zp_neighbor")
	return ~0


func set_zp_neighbor(_layer: int, _index: int, _zp_svolink: int) -> void:
	_abstract_fail("set_zp_neighbor")


func get_xn_neighbor(_layer: int, _index: int) -> int:
	_abstract_fail("get_xn_neighbor")
	return ~0


func set_xn_neighbor(_layer: int, _index: int, _xn_svolink: int) -> void:
	_abstract_fail("set_xn_neighbor")


func get_yn_neighbor(_layer: int, _index: int) -> int:
	_abstract_fail("get_yn_neighbor")
	return ~0


func set_yn_neighbor(_layer: int, _index: int, _yn_svolink: int) -> void:
	_abstract_fail("set_yn_neighbor")


func get_zn_neighbor(_layer: int, _index: int) -> int:
	_abstract_fail("get_zn_neighbor")
	return ~0


func set_zn_neighbor(_layer: int, _index: int, _zn_svolink: int) -> void:
	_abstract_fail("set_zn_neighbor")


func get_flag_inside(_layer: int, _index: int) -> bool:
	_abstract_fail("get_flag_inside")
	return false


func set_flag_inside(_layer: int, _index: int, _inside: bool) -> void:
	_abstract_fail("set_flag_inside")


func get_flag_flip(_layer: int, _index: int) -> bool:
	_abstract_fail("get_flag_flip")
	return false


func set_flag_flip(_layer: int, _index: int, _flip: bool) -> void:
	_abstract_fail("set_flag_flip")


func get_coverage(_layer: int, _index: int) -> float:
	_abstract_fail("get_coverage")
	return NAN


func set_coverage(_layer: int, _index: int, _coverage_value: float) -> void:
	_abstract_fail("set_coverage")


func get_node_center(_svolink: int) -> Vector3:
	_abstract_fail("get_node_center")
	return Vector3.ZERO


func get_voxel_center(_svolink: int) -> Vector3:
	_abstract_fail("get_voxel_center")
	return Vector3.ZERO


func get_voxels_and_nodes_on_face_xp(_svolink: int) -> PackedInt64Array:
	_abstract_fail("get_voxels_and_nodes_on_face_xp")
	return []


func get_voxels_and_nodes_on_face_yp(_svolink: int) -> PackedInt64Array:
	_abstract_fail("get_voxels_and_nodes_on_face_yp")
	return []


func get_voxels_and_nodes_on_face_zp(_svolink: int) -> PackedInt64Array:
	_abstract_fail("get_voxels_and_nodes_on_face_zp")
	return []


func get_voxels_and_nodes_on_face_xn(_svolink: int) -> PackedInt64Array:
	_abstract_fail("get_voxels_and_nodes_on_face_xn")
	return []


func get_voxels_and_nodes_on_face_yn(_svolink: int) -> PackedInt64Array:
	_abstract_fail("get_voxels_and_nodes_on_face_yn")
	return []


func get_voxels_and_nodes_on_face_zn(_svolink: int) -> PackedInt64Array:
	_abstract_fail("get_voxels_and_nodes_on_face_zn")
	return []


func get_svolink_from_node_morton(_layer: int, _morton3_value: int) -> int:
	_abstract_fail("get_svolink_from_node_morton")
	return ~0


func get_svolink_from_voxel_morton(_morton3_value: int) -> int:
	_abstract_fail("get_svolink_from_voxel_morton")
	return ~0


func get_neighbors_of(_svolink: int) -> PackedInt64Array:
	_abstract_fail("get_neighbors_of")
	return []


func is_solid(_layer_or_svolink: int, _index: int = -1) -> bool:
	_abstract_fail("is_solid")
	return false


func get_offsets_of_head_nodes_in_x_direction_of_layer(_layer: int) -> PackedInt64Array:
	_abstract_fail("get_offsets_of_head_nodes_in_x_direction_of_layer")
	return []


func get_solid_bit_counts_by_subgrid() -> PackedInt32Array:
	_abstract_fail("get_solid_bit_counts_by_subgrid")
	return []


func parallel_get_solid_bit_counts_by_subgrid(
	_async_context: Signal,
	_thread_priority: Thread.Priority
) -> PackedInt32Array:
	_abstract_fail("parallel_get_solid_bit_counts_by_subgrid")
	return []
