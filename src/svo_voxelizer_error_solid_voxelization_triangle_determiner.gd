## Debug voxelizer that reports triangle provenance for tracked voxel solid flips.
@tool
extends SvoVoxelizer
class_name svo_voxelizer_error_solid_voxelization_triangle_determiner

@export var svolinks: PackedInt64Array = []


func _run_solid_voxelization(
	async_context: Signal,
	svo: SVO,
	triangles: PackedVector3Array,
	voxel_size: Vector3,
	flight_navigation_size: Vector3,
	support_float64: bool,
	solid_voxelization_top_left_edge_epsilon: float,
	debug_delete_flip_flag: bool,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority,
	depth: int) -> void:
	# Keep default behavior deterministic while collecting provenance.
	# Debug path intentionally runs sequentially.
	if multi_threading_enabled:
		push_warning("svo_voxelizer_error_solid_voxelization_triangle_determiner: forcing sequential solid voxelization for provenance tracking.")

	var tracked_pre_solid: Dictionary = _capture_tracked_solid_state(svo)
	var bit_provenance: Dictionary = {} # bit_key(int) -> Dictionary[int, bool] (triangle-index set)
	var flip_provenance: Array[Dictionary] = [] # layer -> {node_offset: triangle-set}
	var inside_provenance: Array[Dictionary] = [] # layer -> {node_offset: triangle-set}

	progress.emit(ProgressStep.SOLID_VOXELIZATION, svo, 0, 2)
	var x_column_flip_bitmask_by_subgrid_index = Fn3dLookupTable.x_column_flip_bitmask_by_subgrid_index
	var neighbor_node_x_column_bits_by_subgrid_index = Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index
	var bitmask_of_subgrid_voxels_on_face_xp = Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp
	var subgrid_voxel_indexes_on_face_xp: PackedInt32Array = Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"]

	#region YZ plane rasterization, and projection on x column
	progress.emit(ProgressStep.YZ_PLANE_RASTERIZATION, svo, 0, triangles.size() / 3)
	for triangle_index in range(triangles.size() / 3):
		_apply_triangle_yz_rasterization_with_provenance(
			triangle_index,
			svo,
			triangles,
			voxel_size,
			x_column_flip_bitmask_by_subgrid_index,
			flight_navigation_size,
			solid_voxelization_top_left_edge_epsilon,
			bit_provenance,
			support_float64)
	progress.emit(ProgressStep.YZ_PLANE_RASTERIZATION, svo, triangles.size() / 3, triangles.size() / 3)
	#endregion

	progress.emit(ProgressStep.SOLID_VOXELIZATION, svo, 1, 2)
	#region Hierarchical inside/outside propagation
	progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 0, 6)

	#region Prepare flip flags, inside flags, list head nodes
	progress.emit(ProgressStep.PREPARE_FLAGS_AND_HEAD_NODES, svo, 0, 3)
	var flip_flag: Array[PackedByteArray] = []
	flip_flag.resize(svo.morton.size())
	flip_provenance.resize(svo.morton.size())
	inside_provenance.resize(svo.morton.size())
	for i in range(1, svo.morton.size()):
		flip_flag[i].resize(svo.morton[i].size())
		flip_flag[i].fill(0)
		flip_provenance[i] = {}
	for i in range(0, svo.morton.size()):
		inside_provenance[i] = {}
	svo.flip = flip_flag

	progress.emit(ProgressStep.PREPARE_FLAGS_AND_HEAD_NODES, svo, 1, 3)
	svo.inside.resize(svo.morton.size())
	for i in range(0, svo.morton.size()):
		svo.inside[i].resize(svo.morton[i].size())
		svo.inside[i].fill(0)

	progress.emit(ProgressStep.PREPARE_FLAGS_AND_HEAD_NODES, svo, 2, 3)
	var list_head_node_offset_of_layer: Array[PackedInt64Array] = []
	list_head_node_offset_of_layer.resize(svo.morton.size())
	for layer in range(0, svo.morton.size()):
		list_head_node_offset_of_layer[layer] = svo.get_offsets_of_head_nodes_in_x_direction_of_layer(layer)
	progress.emit(ProgressStep.PREPARE_FLAGS_AND_HEAD_NODES, svo, 3, 3)
	#endregion

	progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 1, 6)
	#region Propagate bit flips in x+ direction (layer 0)
	progress.emit(ProgressStep.XP_BIT_FLIP_PROPAGATION, svo, 0, list_head_node_offset_of_layer[0].size())
	for i in range(list_head_node_offset_of_layer[0].size()):
		_propagate_bit_flip_with_provenance(
			i,
			list_head_node_offset_of_layer[0],
			subgrid_voxel_indexes_on_face_xp,
			svo.xp,
			svo.subgrid,
			neighbor_node_x_column_bits_by_subgrid_index,
			bit_provenance)
	progress.emit(ProgressStep.XP_BIT_FLIP_PROPAGATION, svo, list_head_node_offset_of_layer[0].size(), list_head_node_offset_of_layer[0].size())
	#endregion

	progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 2, 6)
	#region Flip bottom up layer 1
	progress.emit(ProgressStep.FLIP_BOTTOM_UP_LAYER_1, svo, 0, 2)
	progress.emit(ProgressStep.PREPARE_FLIP_FLAG_LAYER_1, svo, 0, flip_flag[1].size())
	for i in range(0, flip_flag[1].size()):
		var first_child_svolink = svo.first_child[1][i]
		if first_child_svolink == SvoLink64.singleton.null_link():
			continue
		if not _is_end_of_x_linked_node_string(1, i, svo.first_child, svo.xp):
			continue
		var first_child_offset = SvoLink64.singleton.get_offset(first_child_svolink)
		flip_flag[1][i] = _has_full_xp_face_in_all_children(
			first_child_offset,
			svo.subgrid,
			bitmask_of_subgrid_voxels_on_face_xp)
		if flip_flag[1][i] != 0:
			flip_provenance[1][i] = _collect_layer1_flip_provenance(first_child_offset, subgrid_voxel_indexes_on_face_xp, bit_provenance)
	progress.emit(ProgressStep.PREPARE_FLIP_FLAG_LAYER_1, svo, flip_flag[1].size(), flip_flag[1].size())

	progress.emit(ProgressStep.FLIP_BOTTOM_UP_LAYER_1, svo, 1, 2)
	progress.emit(ProgressStep.PROPAGATE_FLIP_INFORMATION_LAYER_1, svo, 0, list_head_node_offset_of_layer[1].size())
	for head_node_index in range(list_head_node_offset_of_layer[1].size()):
		_propagate_flip_and_inside_with_provenance(
			head_node_index,
			1,
			list_head_node_offset_of_layer,
			svo.xp,
			flip_flag,
			svo.inside,
			flip_provenance,
			inside_provenance)
	progress.emit(ProgressStep.PROPAGATE_FLIP_INFORMATION_LAYER_1, svo, list_head_node_offset_of_layer[1].size(), list_head_node_offset_of_layer[1].size())
	progress.emit(ProgressStep.FLIP_BOTTOM_UP_LAYER_1, svo, 2, 2)
	#endregion

	progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 3, 6)
	#region Flip bottom up from layer 2
	progress.emit(ProgressStep.FLIP_BOTTOM_UP_FROM_LAYER_2, svo, 0, flip_flag.size())
	for layer in range(2, flip_flag.size()):
		var flip_flag_layer = flip_flag[layer]
		var flip_flag_child_layer = flip_flag[layer - 1]
		progress.emit(ProgressStep.PREPARE_FLIP_FLAG_FROM_LAYER_2, svo, 0, flip_flag_layer.size())
		for i in range(0, flip_flag_layer.size()):
			var first_child_svolink = svo.first_child[layer][i]
			if first_child_svolink == SvoLink64.singleton.null_link():
				continue
			if not _is_end_of_x_linked_node_string(layer, i, svo.first_child, svo.xp):
				continue
			var first_child_offset = SvoLink64.singleton.get_offset(first_child_svolink)
			flip_flag_layer[i] = _all_xp_children_are_flipped(first_child_offset, flip_flag_child_layer)
			if flip_flag_layer[i] != 0:
				flip_provenance[layer][i] = _collect_upper_flip_provenance(layer - 1, first_child_offset, flip_provenance)
		progress.emit(ProgressStep.PREPARE_FLIP_FLAG_FROM_LAYER_2, svo, flip_flag_layer.size(), flip_flag_layer.size())

		progress.emit(ProgressStep.PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2, svo, 0, list_head_node_offset_of_layer[layer].size())
		for head_node_index in range(list_head_node_offset_of_layer[layer].size()):
			_propagate_flip_and_inside_with_provenance(
				head_node_index,
				layer,
				list_head_node_offset_of_layer,
				svo.xp,
				flip_flag,
				svo.inside,
				flip_provenance,
				inside_provenance)
		progress.emit(ProgressStep.PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2, svo, list_head_node_offset_of_layer[layer].size(), list_head_node_offset_of_layer[layer].size())
		progress.emit(ProgressStep.FLIP_BOTTOM_UP_FROM_LAYER_2, svo, layer, flip_flag.size())
	progress.emit(ProgressStep.FLIP_BOTTOM_UP_FROM_LAYER_2, svo, flip_flag.size(), flip_flag.size())
	#endregion

	progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 4, 6)
	#region Propagate inside flags topdown for tree nodes
	progress.emit(ProgressStep.PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES, svo, 0, depth - 1)
	for layer in range(depth - 1, 0, -1):
		for offset in range(svo.inside[layer].size()):
			if svo.inside[layer][offset] == 0:
				continue
			var first_child_svolink = svo.first_child[layer][offset]
			if first_child_svolink == SvoLink64.singleton.null_link():
				continue
			var first_child_offset = SvoLink64.singleton.get_offset(first_child_svolink)
			var source_set: Dictionary = _get_node_provenance(inside_provenance[layer], offset)
			for child in range(first_child_offset, first_child_offset + 8):
				svo.inside[layer - 1][child] = svo.inside[layer - 1][child] ^ 1
				_toggle_node_provenance(inside_provenance[layer - 1], child, source_set)
	progress.emit(ProgressStep.PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES, svo, depth - 1, depth - 1)
	#endregion

	progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 5, 6)
	#region Propagate inside flag to subgrid voxels
	progress.emit(ProgressStep.PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS, svo, 0, svo.inside[0].size())
	for node_offset in range(svo.inside[0].size()):
		if svo.inside[0][node_offset] == 0:
			continue
		svo.subgrid[node_offset] = ~svo.subgrid[node_offset]
		var source_set: Dictionary = _get_node_provenance(inside_provenance[0], node_offset)
		_toggle_mask_with_source(bit_provenance, node_offset, ~0, source_set)
	progress.emit(ProgressStep.PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS, svo, svo.inside[0].size(), svo.inside[0].size())
	#endregion

	progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 6, 6)
	#endregion

	progress.emit(ProgressStep.SOLID_VOXELIZATION, svo, 2, 2)
	if debug_delete_flip_flag:
		svo.flip.clear()

	_report_tracked_solid_flips(tracked_pre_solid, svo, triangles, bit_provenance)


func _capture_tracked_solid_state(svo: SVO) -> Dictionary:
	var result: Dictionary = {}
	for tracked_link in svolinks:
		result[tracked_link] = _is_voxel_link_solid(svo, tracked_link)
	return result


func _is_voxel_link_solid(svo: SVO, voxel_link: int) -> bool:
	if voxel_link == SvoLink64.singleton.null_link():
		return false
	var layer: int = SvoLink64.singleton.get_layer(voxel_link)
	if layer != 0:
		return false
	var offset: int = SvoLink64.singleton.get_offset(voxel_link)
	if offset < 0 or offset >= svo.subgrid.size():
		return false
	var subgrid_index: int = SvoLink64.singleton.get_subgrid(voxel_link)
	return (svo.subgrid[offset] & (1 << subgrid_index)) != 0


func _apply_triangle_yz_rasterization_with_provenance(
	triangle_index: int,
	svo: SVO,
	triangles: PackedVector3Array,
	voxel_size: Vector3,
	x_column_flip_bitmask_by_subgrid_index: PackedInt64Array,
	flight_navigation_size: Vector3,
	solid_voxelization_top_left_edge_epsilon: float,
	bit_provenance: Dictionary,
	support_float64: bool) -> void:
	# Equivalent rasterization used for both mutation and provenance bookkeeping.
	# Float64 path currently reuses float32 math for instrumentation consistency.
	if support_float64:
		pass
	var triangle_start_idx: int = triangle_index * 3
	var voxel_size_yz: Vector2 = Vector2(voxel_size.y, voxel_size.z)
	var v0: Vector3 = triangles[triangle_start_idx]
	var v1: Vector3 = triangles[triangle_start_idx + 1]
	var v2: Vector3 = triangles[triangle_start_idx + 2]
	var e0xyz: Vector3 = v1 - v0
	var e1xyz: Vector3 = v2 - v1
	var e2xyz: Vector3 = v0 - v2
	var v0yz: Vector2 = Vector2(v0.y, v0.z)
	var v1yz: Vector2 = Vector2(v1.y, v1.z)
	var v2yz: Vector2 = Vector2(v2.y, v2.z)

	if e2xyz.y * e0xyz.z - e0xyz.y * e2xyz.z < 0:
		var v_temp = v1yz
		v1yz = v2yz
		v2yz = v_temp
		e0xyz = v2 - v0
		e1xyz = v1 - v2
		e2xyz = v0 - v1

	var n: Vector3 = e0xyz.cross(e1xyz)
	if is_zero_approx(n.x):
		return

	var n_yz_e0: Vector2 = Vector2(-e0xyz.z, e0xyz.y)
	var n_yz_e1: Vector2 = Vector2(-e1xyz.z, e1xyz.y)
	var n_yz_e2: Vector2 = Vector2(-e2xyz.z, e2xyz.y)
	if n.x < 0:
		n_yz_e0 = Vector2(e0xyz.z, -e0xyz.y)
		n_yz_e1 = Vector2(e1xyz.z, -e1xyz.y)
		n_yz_e2 = Vector2(e2xyz.z, -e2xyz.y)

	var d_yz_e0: float = -n_yz_e0.dot(v0yz)
	var d_yz_e1: float = -n_yz_e1.dot(v1yz)
	var d_yz_e2: float = -n_yz_e2.dot(v2yz)
	var f_yz_e0: float = solid_voxelization_top_left_edge_epsilon if (n_yz_e0.x > 0 or (n_yz_e0.x == 0.0 and n_yz_e0.y < 0)) else 0.0
	var f_yz_e1: float = solid_voxelization_top_left_edge_epsilon if (n_yz_e1.x > 0 or (n_yz_e1.x == 0.0 and n_yz_e1.y < 0)) else 0.0
	var f_yz_e2: float = solid_voxelization_top_left_edge_epsilon if (n_yz_e2.x > 0 or (n_yz_e2.x == 0.0 and n_yz_e2.y < 0)) else 0.0

	var rect2i: Rect2i = Rect2i()
	rect2i.position = Vector2i(
		ceili(min(v0yz.x, v1yz.x, v2yz.x) / voxel_size_yz.x - 0.5),
		ceili(min(v0yz.y, v1yz.y, v2yz.y) / voxel_size_yz.y - 0.5))
	rect2i.end = Vector2i(
		floori(max(v0yz.x, v1yz.x, v2yz.x) / voxel_size_yz.x + 0.5),
		floori(max(v0yz.y, v1yz.y, v2yz.y) / voxel_size_yz.y + 0.5))
	if not rect2i.has_area():
		return

	var plane_equation_d: float = -n.dot(v0)
	var source_set: Dictionary = _set_with_triangle(triangle_index)
	for voxel_y in range(rect2i.position.x, rect2i.end.x):
		for voxel_z in range(rect2i.position.y, rect2i.end.y):
			var voxel_center_yz: Vector2 = Vector2((voxel_y + 0.5) * voxel_size_yz.x, (voxel_z + 0.5) * voxel_size_yz.y)
			var edge_value_e0: float = n_yz_e0.dot(voxel_center_yz) + d_yz_e0 + f_yz_e0
			var edge_value_e1: float = n_yz_e1.dot(voxel_center_yz) + d_yz_e1 + f_yz_e1
			var edge_value_e2: float = n_yz_e2.dot(voxel_center_yz) + d_yz_e2 + f_yz_e2
			if not (edge_value_e0 > 0.0 and edge_value_e1 > 0.0 and edge_value_e2 > 0.0):
				continue
			var voxel_x: int = floori(0.5 - (n.y * voxel_center_yz.x + n.z * voxel_center_yz.y + plane_equation_d) / (n.x * voxel_size.x))
			var grid_x: int = int(flight_navigation_size.x / voxel_size.x)
			voxel_x = clamp(voxel_x, 0, grid_x - 1)
			var voxel_morton: int = Morton3.encode64(voxel_x, voxel_y, voxel_z)
			var voxel_svolink: int = svo.get_svolink_from_voxel_morton(voxel_morton)
			if voxel_svolink == SvoLink64.singleton.null_link():
				continue
			var node_offset: int = SvoLink64.singleton.get_offset(voxel_svolink)
			var subgrid_index: int = SvoLink64.singleton.get_subgrid(voxel_svolink)
			var flip_mask: int = x_column_flip_bitmask_by_subgrid_index[subgrid_index]
			svo.subgrid[node_offset] = svo.subgrid[node_offset] ^ flip_mask
			_toggle_mask_with_source(bit_provenance, node_offset, flip_mask, source_set)


static func _is_end_of_x_linked_node_string(
	layer: int,
	node_offset: int,
	svo_first_child: Array[PackedInt64Array],
	svo_xp: Array[PackedInt64Array]) -> bool:
	var xp_svolink = svo_xp[layer][node_offset]
	if xp_svolink == SvoLink64.singleton.null_link():
		return true
	var xp_layer = SvoLink64.singleton.get_layer(xp_svolink)
	var xp_offset = SvoLink64.singleton.get_offset(xp_svolink)
	var xp_first_child = svo_first_child[layer][xp_offset]
	return not (xp_layer == layer and xp_first_child != SvoLink64.singleton.null_link())


static func _has_full_xp_face_in_all_children(
	first_child_offset: int,
	svo_subgrid: PackedInt64Array,
	xp_face_bitmask: int) -> int:
	var flip: int = 1
	for xp_offset in [1, 3, 5, 7]:
		var child_subgrid = svo_subgrid[first_child_offset + xp_offset]
		flip = flip & int(xp_face_bitmask == (child_subgrid & xp_face_bitmask))
	return flip


static func _all_xp_children_are_flipped(
	first_child_offset: int,
	flip_flag_child_layer: PackedByteArray) -> int:
	var flip: int = 1
	for xp_offset in [1, 3, 5, 7]:
		flip = flip & flip_flag_child_layer[first_child_offset + xp_offset]
	return flip


func _propagate_bit_flip_with_provenance(
	head_node_index: int,
	list_head_node_offset_of_layer_0: PackedInt64Array,
	subgrid_voxel_indexes_on_face_direction: PackedInt32Array,
	neighbor_direction_to_flip: Array[PackedInt64Array],
	svo_subgrid: PackedInt64Array,
	neighbor_node_x_column_bits_by_subgrid_index: Dictionary,
	bit_provenance: Dictionary) -> void:
	var current_node_offset = list_head_node_offset_of_layer_0[head_node_index]
	while true:
		var neighbor_svolink = neighbor_direction_to_flip[0][current_node_offset]
		if neighbor_svolink == SvoLink64.singleton.null_link():
			break
		var neighbor_layer = SvoLink64.singleton.get_layer(neighbor_svolink)
		if neighbor_layer != 0:
			break

		var flip_buffer: int = 0
		var source_accumulated: Dictionary = {}
		for subgrid_index in subgrid_voxel_indexes_on_face_direction:
			var last_bit_in_the_column_is_solid = svo_subgrid[current_node_offset] & (1 << subgrid_index)
			if last_bit_in_the_column_is_solid == 0:
				continue
			var mask_to_neighbor: int = neighbor_node_x_column_bits_by_subgrid_index[subgrid_index]
			flip_buffer = flip_buffer | mask_to_neighbor
			_set_union_into(source_accumulated, _get_bit_provenance(bit_provenance, current_node_offset, subgrid_index))

		var neighbor_offset: int = SvoLink64.singleton.get_offset(neighbor_svolink)
		svo_subgrid[neighbor_offset] = svo_subgrid[neighbor_offset] ^ flip_buffer
		_toggle_mask_with_source(bit_provenance, neighbor_offset, flip_buffer, source_accumulated)
		current_node_offset = neighbor_offset


func _collect_layer1_flip_provenance(
	first_child_offset: int,
	subgrid_voxel_indexes_on_face_xp: PackedInt32Array,
	bit_provenance: Dictionary) -> Dictionary:
	var source_set: Dictionary = {}
	for xp_child_offset in [1, 3, 5, 7]:
		var node_offset: int = first_child_offset + xp_child_offset
		for subgrid_index in subgrid_voxel_indexes_on_face_xp:
			_set_union_into(source_set, _get_bit_provenance(bit_provenance, node_offset, subgrid_index))
	return source_set


func _collect_upper_flip_provenance(child_layer: int, first_child_offset: int, flip_provenance: Array[Dictionary]) -> Dictionary:
	var source_set: Dictionary = {}
	for xp_child_offset in [1, 3, 5, 7]:
		_set_union_into(source_set, _get_node_provenance(flip_provenance[child_layer], first_child_offset + xp_child_offset))
	return source_set


func _propagate_flip_and_inside_with_provenance(
	head_node_offset: int,
	layer: int,
	list_head_node_offset_of_layer: Array[PackedInt64Array],
	neighbor_direction: Array[PackedInt64Array],
	flip_flag: Array[PackedByteArray],
	svo_inside: Array[PackedByteArray],
	flip_provenance: Array[Dictionary],
	inside_provenance: Array[Dictionary]) -> void:
	var neighbor_direction_layer = neighbor_direction[layer]
	var flip_flag_layer = flip_flag[layer]
	var svo_inside_layer = svo_inside[layer]
	var current_node_offset = list_head_node_offset_of_layer[layer][head_node_offset]
	while true:
		var neighbor_svolink = neighbor_direction_layer[current_node_offset]
		if neighbor_svolink == SvoLink64.singleton.null_link():
			break
		var neighbor_layer = SvoLink64.singleton.get_layer(neighbor_svolink)
		if neighbor_layer != layer:
			break

		var neighbor_offset = SvoLink64.singleton.get_offset(neighbor_svolink)
		if flip_flag_layer[current_node_offset] != 0:
			flip_flag_layer[neighbor_offset] = flip_flag_layer[neighbor_offset] ^ 1
			svo_inside_layer[neighbor_offset] = svo_inside_layer[neighbor_offset] ^ 1
			var source_set: Dictionary = _get_node_provenance(flip_provenance[layer], current_node_offset)
			_toggle_node_provenance(flip_provenance[layer], neighbor_offset, source_set)
			_toggle_node_provenance(inside_provenance[layer], neighbor_offset, source_set)
		current_node_offset = neighbor_offset


func _report_tracked_solid_flips(
	tracked_pre_solid: Dictionary,
	svo: SVO,
	triangles: PackedVector3Array,
	bit_provenance: Dictionary) -> void:
	for tracked_link in svolinks:
		var was_solid: bool = tracked_pre_solid.get(tracked_link, false)
		var is_solid: bool = _is_voxel_link_solid(svo, tracked_link)
		if was_solid or not is_solid:
			continue
		var layer: int = SvoLink64.singleton.get_layer(tracked_link)
		if layer != 0:
			print("[SVO_SOLID_FLIP_DEBUG] tracked_svolink=", tracked_link, " layer=", layer, " status=unsupported_non_leaf_link")
			continue
		var node_offset: int = SvoLink64.singleton.get_offset(tracked_link)
		var subgrid_index: int = SvoLink64.singleton.get_subgrid(tracked_link)
		var source_set: Dictionary = _get_bit_provenance(bit_provenance, node_offset, subgrid_index)
		var source_triangle_indexes: Array = source_set.keys()
		source_triangle_indexes.sort()
		print("[SVO_SOLID_FLIP_DEBUG] tracked_svolink=", tracked_link, " node_offset=", node_offset, " subgrid_index=", subgrid_index, " flip=0->1", " triangles=", source_triangle_indexes)
		for triangle_index_variant in source_triangle_indexes:
			var triangle_index: int = int(triangle_index_variant)
			if triangle_index < 0 or triangle_index * 3 + 2 >= triangles.size():
				continue
			var v0: Vector3 = triangles[triangle_index * 3]
			var v1: Vector3 = triangles[triangle_index * 3 + 1]
			var v2: Vector3 = triangles[triangle_index * 3 + 2]
			print("[SVO_SOLID_FLIP_DEBUG] triangle_index=", triangle_index, " v0=", v0, " v1=", v1, " v2=", v2)


static func _bit_key(node_offset: int, subgrid_index: int) -> int:
	return (node_offset << 6) | subgrid_index


static func _set_with_triangle(triangle_index: int) -> Dictionary:
	return {triangle_index: true}


static func _set_union_into(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = true


static func _set_toggle_into(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		if target.has(key):
			target.erase(key)
		else:
			target[key] = true


func _get_bit_provenance(bit_provenance: Dictionary, node_offset: int, subgrid_index: int) -> Dictionary:
	var key: int = _bit_key(node_offset, subgrid_index)
	if not bit_provenance.has(key):
		return {}
	return (bit_provenance[key] as Dictionary).duplicate(true)


func _toggle_mask_with_source(bit_provenance: Dictionary, node_offset: int, mask: int, source_set: Dictionary) -> void:
	if source_set.is_empty():
		return
	for subgrid_index in range(64):
		if (mask & (1 << subgrid_index)) == 0:
			continue
		var key: int = _bit_key(node_offset, subgrid_index)
		if bit_provenance.has(key):
			var toggled_set: Dictionary = bit_provenance[key]
			_set_toggle_into(toggled_set, source_set)
			if toggled_set.is_empty():
				bit_provenance.erase(key)
			else:
				bit_provenance[key] = toggled_set
		else:
			bit_provenance[key] = source_set.duplicate(true)


func _get_node_provenance(node_provenance: Dictionary, node_offset: int) -> Dictionary:
	if not node_provenance.has(node_offset):
		return {}
	return (node_provenance[node_offset] as Dictionary).duplicate(true)


func _toggle_node_provenance(node_provenance: Dictionary, node_offset: int, source_set: Dictionary) -> void:
	if source_set.is_empty():
		return
	if node_provenance.has(node_offset):
		var toggled_set: Dictionary = node_provenance[node_offset]
		_set_toggle_into(toggled_set, source_set)
		if toggled_set.is_empty():
			node_provenance.erase(node_offset)
		else:
			node_provenance[node_offset] = toggled_set
	else:
		node_provenance[node_offset] = source_set.duplicate(true)
