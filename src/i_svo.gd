## Interface-like base for SVO resources.
@tool
extends Resource
class_name ISvo


func support_query_solid() -> bool:
	printerr("ISvo.support_query_solid() is abstract.")
	return false


func support_query_coverage() -> bool:
	printerr("ISvo.support_query_coverage() is abstract.")
	return false


func get_layer_count() -> int:
	printerr("ISvo.get_layer_count() is abstract.")
	return 0


func set_layer_count(_layer_count: int):
	printerr("ISvo.set_layer_count() is abstract.")


func get_node_count_in_layer(_layer: int) -> int:
	printerr("ISvo.get_node_count_in_layer() is abstract.")
	return 0


func set_node_count_in_layer(_layer: int, _node_count: int):
	printerr("ISvo.set_node_count_in_layer() is abstract.")


func get_morton(_layer: int, _index: int) -> int:
	printerr("ISvo.get_morton() is abstract.")
	return 0


func set_morton(_layer: int, _index: int, _morton3_value: int):
	printerr("ISvo.set_morton() is abstract.")


func get_parent(_layer: int, _index: int) -> int:
	printerr("ISvo.get_parent() is abstract.")
	return ~0


func set_parent(_layer: int, _index: int, _parent_svolink: int):
	printerr("ISvo.set_parent() is abstract.")


func get_first_child(_layer: int, _index: int) -> int:
	printerr("ISvo.get_first_child() is abstract.")
	return ~0


func set_first_child(_layer: int, _index: int, _first_child_svolink: int):
	printerr("ISvo.set_first_child() is abstract.")


func get_subgrid(_index: int) -> int:
	printerr("ISvo.get_subgrid() is abstract.")
	return 0


func set_subgrid(_index: int, _subgrid_bitmask: int):
	printerr("ISvo.set_subgrid() is abstract.")


func get_xp_neighbor(_layer: int, _index: int) -> int:
	printerr("ISvo.get_xp_neighbor() is abstract.")
	return ~0


func set_xp_neighbor(_layer: int, _index: int, _xp_svolink: int):
	printerr("ISvo.set_xp_neighbor() is abstract.")


func get_yp_neighbor(_layer: int, _index: int) -> int:
	printerr("ISvo.get_yp_neighbor() is abstract.")
	return ~0


func set_yp_neighbor(_layer: int, _index: int, _yp_svolink: int):
	printerr("ISvo.set_yp_neighbor() is abstract.")


func get_zp_neighbor(_layer: int, _index: int) -> int:
	printerr("ISvo.get_zp_neighbor() is abstract.")
	return ~0


func set_zp_neighbor(_layer: int, _index: int, _zp_svolink: int):
	printerr("ISvo.set_zp_neighbor() is abstract.")


func get_xn_neighbor(_layer: int, _index: int) -> int:
	printerr("ISvo.get_xn_neighbor() is abstract.")
	return ~0


func set_xn_neighbor(_layer: int, _index: int, _xn_svolink: int):
	printerr("ISvo.set_xn_neighbor() is abstract.")


func get_yn_neighbor(_layer: int, _index: int) -> int:
	printerr("ISvo.get_yn_neighbor() is abstract.")
	return ~0


func set_yn_neighbor(_layer: int, _index: int, _yn_svolink: int):
	printerr("ISvo.set_yn_neighbor() is abstract.")


func get_zn_neighbor(_layer: int, _index: int) -> int:
	printerr("ISvo.get_zn_neighbor() is abstract.")
	return ~0


func set_zn_neighbor(_layer: int, _index: int, _zn_svolink: int):
	printerr("ISvo.set_zn_neighbor() is abstract.")


func get_flag_inside(_layer: int, _index: int) -> bool:
	printerr("ISvo.get_flag_inside() is abstract.")
	return false


func set_flag_inside(_layer: int, _index: int, _inside: bool):
	printerr("ISvo.set_flag_inside() is abstract.")


func get_flag_flip(_layer: int, _index: int) -> bool:
	printerr("ISvo.get_flag_flip() is abstract.")
	return false


func set_flag_flip(_layer: int, _index: int, _flip: bool):
	printerr("ISvo.set_flag_flip() is abstract.")


func get_coverage(_layer: int, _index: int) -> float:
	printerr("ISvo.get_coverage() is abstract.")
	return NAN


func set_coverage(_layer: int, _index: int, _coverage_value: float):
	printerr("ISvo.set_coverage() is abstract.")


func get_node_center(_svolink: int) -> Vector3:
	printerr("ISvo.get_node_center() is abstract.")
	return Vector3.ZERO


func get_voxel_center(_svolink: int) -> Vector3:
	printerr("ISvo.get_voxel_center() is abstract.")
	return Vector3.ZERO


func get_voxels_and_nodes_on_face_xp(_svolink: int) -> PackedInt64Array:
	printerr("ISvo.get_voxels_and_nodes_on_face_xp() is abstract.")
	return []


func get_voxels_and_nodes_on_face_yp(_svolink: int) -> PackedInt64Array:
	printerr("ISvo.get_voxels_and_nodes_on_face_yp() is abstract.")
	return []


func get_voxels_and_nodes_on_face_zp(_svolink: int) -> PackedInt64Array:
	printerr("ISvo.get_voxels_and_nodes_on_face_zp() is abstract.")
	return []


func get_voxels_and_nodes_on_face_xn(_svolink: int) -> PackedInt64Array:
	printerr("ISvo.get_voxels_and_nodes_on_face_xn() is abstract.")
	return []


func get_voxels_and_nodes_on_face_yn(_svolink: int) -> PackedInt64Array:
	printerr("ISvo.get_voxels_and_nodes_on_face_yn() is abstract.")
	return []


func get_voxels_and_nodes_on_face_zn(_svolink: int) -> PackedInt64Array:
	printerr("ISvo.get_voxels_and_nodes_on_face_zn() is abstract.")
	return []


func get_svolink_from_node_morton(_layer: int, _morton3_value: int) -> int:
	printerr("ISvo.get_svolink_from_node_morton() is abstract.")
	return ~0


func get_svolink_from_voxel_morton(_morton3_value: int) -> int:
	printerr("ISvo.get_svolink_from_voxel_morton() is abstract.")
	return ~0


func get_neighbors_of(_svolink: int) -> PackedInt64Array:
	printerr("ISvo.get_neighbors_of() is abstract.")
	return []


func is_solid(_layer_or_svolink: int, _index: int = -1) -> bool:
	printerr("ISvo.is_solid() is abstract.")
	return false


func get_offsets_of_head_nodes_in_x_direction_of_layer(
	_layer: int) -> PackedInt64Array:
	printerr(
		"ISvo.get_offsets_of_head_nodes_in_x_direction_of_layer() is abstract."
	)
	return []


func get_solid_bit_counts_by_subgrid() -> PackedInt32Array:
	printerr("ISvo.get_solid_bit_counts_by_subgrid() is abstract.")
	return []


func parallel_get_solid_bit_counts_by_subgrid(
	_async_context: Signal,
	_thread_priority: Thread.Priority) -> PackedInt32Array:
	printerr("ISvo.parallel_get_solid_bit_counts_by_subgrid() is abstract.")
	return []
