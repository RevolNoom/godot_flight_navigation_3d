@tool
extends SceneTree


const InvestigationLib = preload("res://tests/investigation/voxelization_investigation_lib.gd")
const REPORT_PATH: String = "user://investigation/reported_solid_propagation_bug.json"
const REPORTED_TARGETS: Array[Dictionary] = [
	{"label": "L1_1789_0", "layer": 1, "offset": 1789, "subgrid": 0},
	{"label": "L1_1785_0", "layer": 1, "offset": 1785, "subgrid": 0},
	{"label": "L1_1459_0", "layer": 1, "offset": 1459, "subgrid": 0},
	{"label": "L0_4811_63", "layer": 0, "offset": 4811, "subgrid": 63},
	{"label": "L0_4841_47", "layer": 0, "offset": 4841, "subgrid": 47},
	{"label": "L0_3811_45", "layer": 0, "offset": 3811, "subgrid": 45},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var context := await InvestigationLib.setup_demo(self)
	if context.is_empty():
		quit(1)
		return

	var flight_navigation := context["flight_navigation"] as FlightNavigation3D
	var voxelizer := context["voxelizer"] as SvoVoxelizer
	var targets := context["targets"] as Array[VoxelizationTarget]
	await flight_navigation.build_navigation()
	var final_svo := flight_navigation.sparse_voxel_octree
	if final_svo == null:
		printerr("trace_reported_solid_propagation_bug: demo scene has no sparse_voxel_octree.")
		InvestigationLib.teardown_demo(context)
		await process_frame
		quit(1)
		return

	var voxel_size: Vector3 = FlightNavigation3D.calculate_node_size(
		flight_navigation.size,
		-2,
		voxelizer.layer_count
	)
	var prepared_triangles: PackedVector3Array = await voxelizer._prepare_triangles(
		flight_navigation,
		process_frame,
		InvestigationLib.duplicate_target_array(targets),
		voxelizer.voxelization_mask,
		voxelizer.debug_delete_csg,
		voxelizer.remove_thin_triangles,
		voxelizer.multi_threading_enabled,
		voxelizer.multi_threading_priority,
		-flight_navigation.size / 2.0
	)

	var raw_triangles := await InvestigationLib.build_raw_triangles(flight_navigation, targets)
	var target_reports := await InvestigationLib.build_target_triangle_reports(flight_navigation, targets)

	var factory_triangle_box_test: IFactoryTriangleBoxOverlapCheck
	if voxelizer.support_float64:
		factory_triangle_box_test = FactoryTriangleBoxOverlapCheckF64.new()
	else:
		factory_triangle_box_test = FactoryTriangleBoxOverlapCheckF32.new()

	var active_layer_1_result := await voxelizer._determine_active_layer_1_nodes(
		process_frame,
		prepared_triangles,
		factory_triangle_box_test,
		voxel_size,
		voxelizer.surface_voxelization_float_error_margin,
		flight_navigation.size,
		voxelizer.multi_threading_enabled,
		voxelizer.multi_threading_priority
	)
	if active_layer_1_result.is_empty():
		printerr("trace_reported_solid_propagation_bug: failed to determine active layer-1 nodes.")
		InvestigationLib.teardown_demo(context)
		await process_frame
		quit(1)
		return

	var base_svo := await voxelizer._construct_svo(
		process_frame,
		active_layer_1_result["list_node_1_morton_grouped"],
		voxelizer.layer_count,
		voxelizer.multi_threading_enabled,
		voxelizer.multi_threading_priority
	)
	if base_svo == null:
		printerr("trace_reported_solid_propagation_bug: failed to construct base SVO.")
		InvestigationLib.teardown_demo(context)
		await process_frame
		quit(1)
		return

	var target_details := _build_target_details(final_svo, voxel_size)
	var layer0_targets := _filter_targets_by_layer(target_details, 0)
	var layer1_targets := _filter_targets_by_layer(target_details, 1)
	var layer0_target_offsets := _collect_offsets(layer0_targets)
	var layer1_target_offsets := _collect_offsets(layer1_targets)
	var layer0_chain_offsets := _build_chain_offsets_for_targets(base_svo, 0, layer0_target_offsets)
	var layer1_chain_offsets := _build_chain_offsets_for_targets(base_svo, 1, layer1_target_offsets)
	var watch_mask_by_leaf_offset := _build_leaf_watch_mask(
		base_svo,
		layer0_targets,
		layer0_chain_offsets,
		layer1_chain_offsets
	)

	var stage_subgrid: PackedInt64Array = base_svo.subgrid.duplicate()
	base_svo.subgrid = stage_subgrid
	var leaf_bit_provenance: Dictionary = {}
	var rasterization_events: Array[Dictionary] = []
	var rasterization_callable: Callable = SvoVoxelizer._parallel_yz_plane_rasterization_f32
	if voxelizer.support_float64:
		rasterization_callable = SvoVoxelizer._parallel_yz_plane_rasterization_f64

	for triangle_index in range(prepared_triangles.size() / 3):
		var before_masks := _snapshot_masks(stage_subgrid, watch_mask_by_leaf_offset)
		rasterization_callable.call(
			triangle_index,
			base_svo,
			prepared_triangles,
			voxel_size,
			Fn3dLookupTable.x_column_flip_bitmask_by_subgrid_index,
			flight_navigation.size,
			voxelizer.solid_voxelization_top_left_edge_epsilon
		)
		var event := _capture_mask_delta_event(
			triangle_index,
			before_masks,
			stage_subgrid,
			watch_mask_by_leaf_offset,
			leaf_bit_provenance
		)
		if not event.is_empty():
			rasterization_events.push_back(event)

	var layer0_after_rasterization := _build_layer0_target_report(layer0_targets, stage_subgrid, leaf_bit_provenance)
	var leaf_propagation_events := _propagate_all_leaf_x_chains_with_provenance(
		base_svo,
		stage_subgrid,
		watch_mask_by_leaf_offset,
		leaf_bit_provenance
	)
	var layer0_after_leaf_propagation := _build_layer0_target_report(layer0_targets, stage_subgrid, leaf_bit_provenance)

	var list_head_node_offset_of_layer := _build_head_offsets(base_svo)
	var flip_flag := _create_flag_layers(base_svo, false)
	var inside_flag := _create_flag_layers(base_svo, true)
	var flip_candidate_provenance := _create_candidate_provenance_layers(base_svo)
	var inside_candidate_provenance := _create_candidate_provenance_layers(base_svo)

	_prepare_layer_1_flip_flags(
		base_svo,
		stage_subgrid,
		flip_flag,
		flip_candidate_provenance,
		leaf_bit_provenance
	)
	_propagate_flip_and_inside_with_candidates(
		base_svo,
		1,
		list_head_node_offset_of_layer,
		flip_flag,
		inside_flag,
		flip_candidate_provenance,
		inside_candidate_provenance
	)
	var layer1_after_layer1_propagation := _build_layer1_target_report(
		layer1_targets,
		inside_flag,
		inside_candidate_provenance,
		"layer1_flip_propagation"
	)

	for layer in range(2, base_svo.morton.size()):
		_prepare_upper_layer_flip_flags(
			base_svo,
			layer,
			flip_flag,
			flip_candidate_provenance
		)
		_propagate_flip_and_inside_with_candidates(
			base_svo,
			layer,
			list_head_node_offset_of_layer,
			flip_flag,
			inside_flag,
			flip_candidate_provenance,
			inside_candidate_provenance
		)

	var layer1_before_topdown := _build_layer1_target_report(
		layer1_targets,
		inside_flag,
		inside_candidate_provenance,
		"before_topdown"
	)
	_propagate_inside_topdown_with_candidates(base_svo, inside_flag, inside_candidate_provenance)
	var layer1_after_topdown := _build_layer1_target_report(
		layer1_targets,
		inside_flag,
		inside_candidate_provenance,
		"after_topdown"
	)
	_apply_inside_to_watched_leaf_bits(
		stage_subgrid,
		watch_mask_by_leaf_offset,
		inside_flag[0],
		leaf_bit_provenance,
		inside_candidate_provenance[0]
	)
	var layer0_after_full_pipeline := _build_layer0_target_report(layer0_targets, stage_subgrid, leaf_bit_provenance)

	var target_summaries: Array[Dictionary] = []
	var candidate_triangle_union: Dictionary = {}
	for detail in target_details:
		var summary := _build_target_summary(
			detail,
			layer0_after_rasterization,
			layer0_after_leaf_propagation,
			layer0_after_full_pipeline,
			layer1_after_layer1_propagation,
			layer1_before_topdown,
			layer1_after_topdown,
			base_svo,
			flip_flag,
			flip_candidate_provenance,
			inside_flag,
			inside_candidate_provenance
		)
		for triangle_index_variant in summary.get("candidate_triangle_indices", []):
			candidate_triangle_union[int(triangle_index_variant)] = true
		target_summaries.push_back(summary)

	var candidate_triangle_indices: Array[int] = []
	for triangle_index_variant in candidate_triangle_union.keys():
		candidate_triangle_indices.push_back(int(triangle_index_variant))
	candidate_triangle_indices.sort()
	var candidate_triangle_sources := _build_triangle_source_reports(
		prepared_triangles,
		raw_triangles,
		target_reports,
		candidate_triangle_indices,
		flight_navigation.size / 2.0
	)

	var report := {
		"scene_path": InvestigationLib.DEMO_SCENE_PATH,
		"global_report_path": ProjectSettings.globalize_path(REPORT_PATH),
		"reported_targets": REPORTED_TARGETS,
		"prepared_triangle_count": prepared_triangles.size() / 3,
		"support_float64": voxelizer.support_float64,
		"layer_count": voxelizer.layer_count,
		"voxel_size": InvestigationLib.vec3_to_array(voxel_size),
		"watch_leaf_offset_count": watch_mask_by_leaf_offset.size(),
		"rasterization_event_count": rasterization_events.size(),
		"leaf_propagation_event_count": leaf_propagation_events.size(),
		"layer0_chain_offsets": layer0_chain_offsets,
		"layer1_chain_offsets": layer1_chain_offsets,
		"target_summaries": target_summaries,
		"candidate_triangle_indices": candidate_triangle_indices,
		"candidate_triangle_sources": candidate_triangle_sources,
	}

	InvestigationLib.write_json_report(REPORT_PATH, report)
	print("Reported solid propagation investigation report written to: %s" % ProjectSettings.globalize_path(REPORT_PATH))
	print("Reported solid propagation investigation target summaries: %s" % JSON.stringify(target_summaries))
	print("Reported solid propagation investigation candidate triangles: %s" % var_to_str(candidate_triangle_indices))

	InvestigationLib.teardown_demo(context)
	await process_frame
	quit()


func _build_target_details(svo: SVO, voxel_size: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for target in REPORTED_TARGETS:
		var detail := target.duplicate(true)
		var layer: int = int(detail["layer"])
		var offset: int = int(detail["offset"])
		var subgrid: int = int(detail["subgrid"])
		var layer_size: int = svo.morton[layer].size() if layer >= 0 and layer < svo.morton.size() else -1
		detail["layer_size"] = layer_size
		if offset < 0 or offset >= layer_size:
			detail["exists"] = false
			result.push_back(detail)
			continue

		var svolink: int = SvoLink64.singleton.create(layer, offset, subgrid)
		var node_morton: int = svo.morton[layer][offset]
		var has_children: bool = false
		if layer > 0 and offset < svo.first_child[layer].size():
			has_children = svo.first_child[layer][offset] != SvoLink64.singleton.null_link()
		detail["exists"] = true
		detail["svolink"] = svolink
		detail["node_morton"] = node_morton
		detail["node_coords"] = InvestigationLib.vec3i_to_array(Morton3.decode_vec3i(node_morton))
		detail["has_children"] = has_children
		detail["inside_flag"] = bool(svo.inside[layer][offset]) if svo.support_inside and layer < svo.inside.size() and offset < svo.inside[layer].size() else false
		detail["final_is_solid"] = bool(svo.is_solid(svolink))
		if layer == 0:
			var voxel_morton: int = (node_morton << 6) | subgrid
			var voxel_coords: Vector3i = Morton3.decode_vec3i(voxel_morton)
			detail["voxel_morton"] = voxel_morton
			detail["voxel_coords"] = InvestigationLib.vec3i_to_array(voxel_coords)
			detail["local_center"] = InvestigationLib.vec3_to_array((Vector3(voxel_coords) + Vector3.ONE * 0.5) * voxel_size)
		result.push_back(detail)
	return result


func _filter_targets_by_layer(target_details: Array[Dictionary], layer: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for detail in target_details:
		if int(detail.get("layer", -1)) == layer and bool(detail.get("exists", false)):
			result.push_back(detail)
	return result


func _collect_offsets(targets: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	for detail in targets:
		result.push_back(int(detail["offset"]))
	result.sort()
	return result


func _build_chain_offsets_for_targets(svo: SVO, layer: int, target_offsets: Array[int]) -> Array[int]:
	var offset_set: Dictionary = {}
	for target_offset in target_offsets:
		for chain_offset in _build_full_chain_for_offset(svo, layer, target_offset):
			offset_set[int(chain_offset)] = true
	var result: Array[int] = []
	for offset_variant in offset_set.keys():
		result.push_back(int(offset_variant))
	result.sort()
	return result


func _build_full_chain_for_offset(svo: SVO, layer: int, target_offset: int) -> Array[int]:
	if target_offset < 0 or target_offset >= svo.morton[layer].size():
		return []
	var head_offset: int = target_offset
	while true:
		var neighbor_svolink: int = svo.xn[layer][head_offset]
		if neighbor_svolink == SvoLink64.singleton.null_link():
			break
		if SvoLink64.singleton.get_layer(neighbor_svolink) != layer:
			break
		head_offset = SvoLink64.singleton.get_offset(neighbor_svolink)
	var result: Array[int] = [head_offset]
	var current_offset: int = head_offset
	while true:
		var neighbor_svolink: int = svo.xp[layer][current_offset]
		if neighbor_svolink == SvoLink64.singleton.null_link():
			break
		if SvoLink64.singleton.get_layer(neighbor_svolink) != layer:
			break
		current_offset = SvoLink64.singleton.get_offset(neighbor_svolink)
		result.push_back(current_offset)
	return result


func _build_leaf_watch_mask(
	svo: SVO,
	layer0_targets: Array[Dictionary],
	layer0_chain_offsets: Array[int],
	layer1_chain_offsets: Array[int]
) -> Dictionary:
	var watch_mask_by_offset: Dictionary = {}
	for detail in layer0_targets:
		var offset: int = int(detail["offset"])
		var subgrid: int = int(detail["subgrid"])
		watch_mask_by_offset[offset] = int(watch_mask_by_offset.get(offset, 0)) | (1 << subgrid)
	for offset in layer0_chain_offsets:
		watch_mask_by_offset[offset] = int(watch_mask_by_offset.get(offset, 0)) | Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp
	for offset in layer1_chain_offsets:
		var first_child_svolink: int = svo.first_child[1][offset]
		if first_child_svolink == SvoLink64.singleton.null_link():
			continue
		var first_child_offset: int = SvoLink64.singleton.get_offset(first_child_svolink)
		for child_delta in [1, 3, 5, 7]:
			var child_offset: int = first_child_offset + child_delta
			watch_mask_by_offset[child_offset] = int(watch_mask_by_offset.get(child_offset, 0)) | Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp
	return watch_mask_by_offset


func _snapshot_masks(subgrid: PackedInt64Array, watch_mask_by_offset: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	for offset_variant in watch_mask_by_offset.keys():
		var offset: int = int(offset_variant)
		snapshot[offset] = subgrid[offset] & int(watch_mask_by_offset[offset])
	return snapshot


func _capture_mask_delta_event(
	triangle_index: int,
	before_masks: Dictionary,
	subgrid: PackedInt64Array,
	watch_mask_by_offset: Dictionary,
	leaf_bit_provenance: Dictionary
) -> Dictionary:
	var delta_by_offset: Array[Dictionary] = []
	for offset_variant in watch_mask_by_offset.keys():
		var offset: int = int(offset_variant)
		var mask: int = int(watch_mask_by_offset[offset])
		var before_value: int = int(before_masks.get(offset, 0))
		var after_value: int = subgrid[offset] & mask
		var delta: int = before_value ^ after_value
		if delta == 0:
			continue
		var toggled_subgrids := _extract_set_bits(delta)
		for subgrid_index in toggled_subgrids:
			_toggle_triangle_in_leaf_bit_provenance(leaf_bit_provenance, offset, subgrid_index, triangle_index)
		delta_by_offset.push_back({
			"offset": offset,
			"before_masked": before_value,
			"after_masked": after_value,
			"delta_mask": delta,
			"toggled_subgrids": toggled_subgrids,
		})
	if delta_by_offset.is_empty():
		return {}
	return {
		"triangle_index": triangle_index,
		"delta_by_offset": delta_by_offset,
	}


func _propagate_all_leaf_x_chains_with_provenance(
	svo: SVO,
	subgrid: PackedInt64Array,
	watch_mask_by_offset: Dictionary,
	leaf_bit_provenance: Dictionary
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var head_offsets: PackedInt64Array = svo.get_offsets_of_head_nodes_in_x_direction_of_layer(0)
	for head_index in range(head_offsets.size()):
		var current_offset: int = head_offsets[head_index]
		while true:
			var neighbor_svolink: int = svo.xp[0][current_offset]
			if neighbor_svolink == SvoLink64.singleton.null_link():
				break
			if SvoLink64.singleton.get_layer(neighbor_svolink) != 0:
				break
			var neighbor_offset: int = SvoLink64.singleton.get_offset(neighbor_svolink)
			if _should_skip_leaf_tail_x_propagation(
					neighbor_offset,
					svo.xp[0]
				):
				current_offset = neighbor_offset
				continue
			var neighbor_watch_mask: int = int(watch_mask_by_offset.get(neighbor_offset, 0))
			var flip_buffer: int = 0
			var source_details: Array[Dictionary] = []
			for source_subgrid in Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"]:
				var source_bitmask: int = 1 << source_subgrid
				if subgrid[current_offset] & source_bitmask == 0:
					continue
				var propagated_mask: int = Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index[source_subgrid]
				flip_buffer |= propagated_mask
				var watched_overlap: int = propagated_mask & neighbor_watch_mask
				if watched_overlap != 0:
					for target_subgrid in _extract_set_bits(watched_overlap):
						_xor_leaf_bit_provenance_from_source(
							leaf_bit_provenance,
							neighbor_offset,
							target_subgrid,
							current_offset,
							source_subgrid
						)
					source_details.push_back({
						"source_offset": current_offset,
						"source_subgrid": source_subgrid,
						"target_offset": neighbor_offset,
						"target_subgrids": _extract_set_bits(watched_overlap),
						"source_triangles": _get_sorted_leaf_provenance_triangles(leaf_bit_provenance, current_offset, source_subgrid),
					})
			if flip_buffer != 0:
				var before_value: int = subgrid[neighbor_offset] & neighbor_watch_mask
				subgrid[neighbor_offset] = subgrid[neighbor_offset] ^ flip_buffer
				var after_value: int = subgrid[neighbor_offset] & neighbor_watch_mask
				var delta_mask: int = before_value ^ after_value
				if delta_mask != 0:
					events.push_back({
						"source_offset": current_offset,
						"target_offset": neighbor_offset,
						"delta_mask": delta_mask,
						"toggled_subgrids": _extract_set_bits(delta_mask),
						"source_details": source_details,
					})
			current_offset = neighbor_offset
	return events


func _should_skip_leaf_tail_x_propagation(
	target_leaf_offset: int,
	svo_xp_layer_0: PackedInt64Array
) -> bool:
	var target_xp_svolink: int = svo_xp_layer_0[target_leaf_offset]
	if target_xp_svolink == SvoLink64.singleton.null_link():
		return false
	return SvoLink64.singleton.get_layer(target_xp_svolink) > 0


func _build_head_offsets(svo: SVO) -> Array[PackedInt64Array]:
	var result: Array[PackedInt64Array] = []
	result.resize(svo.morton.size())
	for layer in range(svo.morton.size()):
		result[layer] = svo.get_offsets_of_head_nodes_in_x_direction_of_layer(layer)
	return result


func _create_flag_layers(svo: SVO, include_layer_0: bool) -> Array[PackedByteArray]:
	var result: Array[PackedByteArray] = []
	result.resize(svo.morton.size())
	for layer in range(svo.morton.size()):
		result[layer] = PackedByteArray()
		if not include_layer_0 and layer == 0:
			continue
		result[layer].resize(svo.morton[layer].size())
		result[layer].fill(0)
	return result


func _create_candidate_provenance_layers(svo: SVO) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.resize(svo.morton.size())
	for layer in range(svo.morton.size()):
		result[layer] = {}
	return result


func _prepare_layer_1_flip_flags(
	svo: SVO,
	subgrid: PackedInt64Array,
	flip_flag: Array[PackedByteArray],
	flip_candidate_provenance: Array[Dictionary],
	leaf_bit_provenance: Dictionary
) -> void:
	for offset in range(svo.morton[1].size()):
		var first_child_svolink: int = svo.first_child[1][offset]
		if first_child_svolink == SvoLink64.singleton.null_link():
			continue
		if not SvoVoxelizer._is_end_of_x_linked_node_string(1, offset, svo.first_child, svo.xp):
			continue
		var first_child_offset: int = SvoLink64.singleton.get_offset(first_child_svolink)
		flip_flag[1][offset] = SvoVoxelizer._has_full_xp_face_in_all_children(
			first_child_offset,
			subgrid,
			Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp
		)
		if flip_flag[1][offset] == 0:
			continue
		var candidate_set: Dictionary = {}
		for child_delta in [1, 3, 5, 7]:
			var child_offset: int = first_child_offset + child_delta
			for source_subgrid in Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"]:
				_union_leaf_bit_provenance_into(candidate_set, leaf_bit_provenance, child_offset, source_subgrid)
		flip_candidate_provenance[1][offset] = candidate_set


func _prepare_upper_layer_flip_flags(
	svo: SVO,
	layer: int,
	flip_flag: Array[PackedByteArray],
	flip_candidate_provenance: Array[Dictionary]
) -> void:
	for offset in range(svo.morton[layer].size()):
		var first_child_svolink: int = svo.first_child[layer][offset]
		if first_child_svolink == SvoLink64.singleton.null_link():
			continue
		if not SvoVoxelizer._is_end_of_x_linked_node_string(layer, offset, svo.first_child, svo.xp):
			continue
		var first_child_offset: int = SvoLink64.singleton.get_offset(first_child_svolink)
		flip_flag[layer][offset] = SvoVoxelizer._all_xp_children_are_flipped(
			first_child_offset,
			flip_flag[layer - 1]
		)
		if flip_flag[layer][offset] == 0:
			continue
		var candidate_set: Dictionary = {}
		for child_delta in [1, 3, 5, 7]:
			_union_candidate_set(candidate_set, _get_candidate_set(flip_candidate_provenance[layer - 1], first_child_offset + child_delta))
		flip_candidate_provenance[layer][offset] = candidate_set


func _propagate_flip_and_inside_with_candidates(
	svo: SVO,
	layer: int,
	list_head_node_offset_of_layer: Array[PackedInt64Array],
	flip_flag: Array[PackedByteArray],
	inside_flag: Array[PackedByteArray],
	flip_candidate_provenance: Array[Dictionary],
	inside_candidate_provenance: Array[Dictionary]
) -> void:
	for head_node_index in range(list_head_node_offset_of_layer[layer].size()):
		var current_node_offset: int = list_head_node_offset_of_layer[layer][head_node_index]
		while true:
			var neighbor_svolink: int = svo.xp[layer][current_node_offset]
			if neighbor_svolink == SvoLink64.singleton.null_link():
				break
			if SvoLink64.singleton.get_layer(neighbor_svolink) != layer:
				break
			var neighbor_offset: int = SvoLink64.singleton.get_offset(neighbor_svolink)
			if flip_flag[layer][current_node_offset]:
				flip_flag[layer][neighbor_offset] = flip_flag[layer][neighbor_offset] ^ 1
				inside_flag[layer][neighbor_offset] = inside_flag[layer][neighbor_offset] ^ 1
				_union_candidate_set(
					_ensure_candidate_set(inside_candidate_provenance[layer], neighbor_offset),
					_get_candidate_set(flip_candidate_provenance[layer], current_node_offset)
				)
			current_node_offset = neighbor_offset


func _propagate_inside_topdown_with_candidates(
	svo: SVO,
	inside_flag: Array[PackedByteArray],
	inside_candidate_provenance: Array[Dictionary]
) -> void:
	for layer in range(svo.morton.size() - 1, 0, -1):
		for offset in range(inside_flag[layer].size()):
			if inside_flag[layer][offset] == 0:
				continue
			var first_child_svolink: int = svo.first_child[layer][offset]
			if first_child_svolink == SvoLink64.singleton.null_link():
				continue
			var first_child_offset: int = SvoLink64.singleton.get_offset(first_child_svolink)
			for child_offset in range(first_child_offset, first_child_offset + 8):
				inside_flag[layer - 1][child_offset] = inside_flag[layer - 1][child_offset] ^ 1
				_union_candidate_set(
					_ensure_candidate_set(inside_candidate_provenance[layer - 1], child_offset),
					_get_candidate_set(inside_candidate_provenance[layer], offset)
				)


func _apply_inside_to_watched_leaf_bits(
	subgrid: PackedInt64Array,
	watch_mask_by_offset: Dictionary,
	inside_flag_layer_0: PackedByteArray,
	leaf_bit_provenance: Dictionary,
	inside_candidate_layer_0: Dictionary
) -> void:
	for offset_variant in watch_mask_by_offset.keys():
		var offset: int = int(offset_variant)
		if inside_flag_layer_0[offset] == 0:
			continue
		var watch_mask: int = int(watch_mask_by_offset[offset])
		for subgrid_index in _extract_set_bits(watch_mask):
			var candidate_set: Dictionary = _get_candidate_set(inside_candidate_layer_0, offset)
			for triangle_index_variant in candidate_set.keys():
				_toggle_triangle_in_leaf_bit_provenance(
					leaf_bit_provenance,
					offset,
					subgrid_index,
					int(triangle_index_variant)
				)
		subgrid[offset] = ~subgrid[offset]


func _build_layer0_target_report(
	targets: Array[Dictionary],
	subgrid: PackedInt64Array,
	leaf_bit_provenance: Dictionary
) -> Dictionary:
	var report: Dictionary = {}
	for detail in targets:
		var offset: int = int(detail["offset"])
		var subgrid_index: int = int(detail["subgrid"])
		var label: String = String(detail["label"])
		report[label] = {
			"is_solid": (subgrid[offset] & (1 << subgrid_index)) != 0,
			"candidate_triangle_indices": _get_sorted_leaf_provenance_triangles(leaf_bit_provenance, offset, subgrid_index),
		}
	return report


func _build_layer1_target_report(
	targets: Array[Dictionary],
	inside_flag: Array[PackedByteArray],
	inside_candidate_provenance: Array[Dictionary],
	stage_name: String
) -> Dictionary:
	var report: Dictionary = {}
	for detail in targets:
		var offset: int = int(detail["offset"])
		var label: String = String(detail["label"])
		report[label] = {
			"stage": stage_name,
			"inside": inside_flag[1][offset] != 0,
			"candidate_triangle_indices": _sorted_candidate_set(_get_candidate_set(inside_candidate_provenance[1], offset)),
		}
	return report


func _build_target_summary(
	detail: Dictionary,
	layer0_after_rasterization: Dictionary,
	layer0_after_leaf_propagation: Dictionary,
	layer0_after_full_pipeline: Dictionary,
	layer1_after_layer1_propagation: Dictionary,
	layer1_before_topdown: Dictionary,
	layer1_after_topdown: Dictionary,
	base_svo: SVO,
	flip_flag: Array[PackedByteArray],
	flip_candidate_provenance: Array[Dictionary],
	inside_flag: Array[PackedByteArray],
	inside_candidate_provenance: Array[Dictionary]
) -> Dictionary:
	var summary := detail.duplicate(true)
	if not bool(detail.get("exists", false)):
		summary["confirmed_stage"] = "missing_offset"
		summary["candidate_triangle_indices"] = []
		return summary

	var label: String = String(detail["label"])
	var layer: int = int(detail["layer"])
	if layer == 0:
		var raster_item: Dictionary = layer0_after_rasterization.get(label, {})
		var leaf_item: Dictionary = layer0_after_leaf_propagation.get(label, {})
		var final_item: Dictionary = layer0_after_full_pipeline.get(label, {})
		var confirmed_stage: String = "not_reproduced"
		if bool(final_item.get("is_solid", false)):
			if bool(raster_item.get("is_solid", false)):
				confirmed_stage = "rasterization"
			elif bool(leaf_item.get("is_solid", false)):
				confirmed_stage = "leaf_x_propagation"
			else:
				confirmed_stage = "higher_layer_inside_propagation"
		summary["confirmed_stage"] = confirmed_stage
		summary["simulated_after_rasterization"] = raster_item
		summary["simulated_after_leaf_propagation"] = leaf_item
		summary["simulated_after_full_pipeline"] = final_item
		summary["candidate_triangle_indices"] = final_item.get("candidate_triangle_indices", [])
		return summary

	var layer1_item: Dictionary = layer1_after_layer1_propagation.get(label, {})
	var before_topdown_item: Dictionary = layer1_before_topdown.get(label, {})
	var after_topdown_item: Dictionary = layer1_after_topdown.get(label, {})
	var offset: int = int(detail["offset"])
	var confirmed_stage_layer1: String = "not_reproduced"
	if bool(detail.get("final_is_solid", false)):
		if bool(layer1_item.get("inside", false)):
			confirmed_stage_layer1 = "layer1_flip_propagation"
		elif bool(after_topdown_item.get("inside", false)):
			confirmed_stage_layer1 = "higher_layer_topdown_propagation"
	summary["confirmed_stage"] = confirmed_stage_layer1
	summary["simulated_after_layer1_propagation"] = layer1_item
	summary["simulated_before_topdown"] = before_topdown_item
	summary["simulated_after_topdown"] = after_topdown_item
	summary["final_simulated_inside"] = inside_flag[1][offset] != 0
	summary["final_flip_flag"] = flip_flag[1][offset] if flip_flag.size() > 1 and offset < flip_flag[1].size() else 0
	summary["candidate_triangle_indices"] = _sorted_candidate_set(_get_candidate_set(inside_candidate_provenance[1], offset))
	summary["flip_source_triangle_indices"] = _sorted_candidate_set(_get_candidate_set(flip_candidate_provenance[1], offset))
	return summary


func _build_triangle_source_reports(
	prepared_triangles: PackedVector3Array,
	raw_triangles: PackedVector3Array,
	target_reports: Array[Dictionary],
	triangle_indices: Array[int],
	coordinate_offset: Vector3
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for triangle_index in triangle_indices:
		var start: int = triangle_index * 3
		var raw_match_index: int = _find_raw_triangle_match(
			raw_triangles,
			prepared_triangles[start],
			prepared_triangles[start + 1],
			prepared_triangles[start + 2],
			coordinate_offset
		)
		var source_info := _locate_target_for_raw_triangle(raw_match_index, target_reports)
		result.push_back({
			"triangle_index": triangle_index,
			"v0": InvestigationLib.vec3_to_array(prepared_triangles[start]),
			"v1": InvestigationLib.vec3_to_array(prepared_triangles[start + 1]),
			"v2": InvestigationLib.vec3_to_array(prepared_triangles[start + 2]),
			"raw_triangle_index": raw_match_index,
			"source_target_path": source_info.get("target_path", ""),
			"source_parent_path": source_info.get("parent_path", ""),
			"source_parent_type": source_info.get("parent_type", ""),
			"source_target_triangle_index": int(source_info.get("target_triangle_index", -1)),
		})
	return result


func _find_raw_triangle_match(
	raw_triangles: PackedVector3Array,
	prepared_v0: Vector3,
	prepared_v1: Vector3,
	prepared_v2: Vector3,
	coordinate_offset: Vector3
) -> int:
	var prepared_sorted := [prepared_v0, prepared_v1, prepared_v2]
	prepared_sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		if not is_equal_approx(a.x, b.x):
			return a.x < b.x
		if not is_equal_approx(a.y, b.y):
			return a.y < b.y
		return a.z < b.z
	)
	for raw_triangle_index in range(raw_triangles.size() / 3):
		var start: int = raw_triangle_index * 3
		var raw_sorted := [
			raw_triangles[start] + coordinate_offset,
			raw_triangles[start + 1] + coordinate_offset,
			raw_triangles[start + 2] + coordinate_offset,
		]
		raw_sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			if not is_equal_approx(a.x, b.x):
				return a.x < b.x
			if not is_equal_approx(a.y, b.y):
				return a.y < b.y
			return a.z < b.z
		)
		if _triangle_vertices_match(prepared_sorted, raw_sorted):
			return raw_triangle_index
	return -1


func _triangle_vertices_match(lhs: Array, rhs: Array) -> bool:
	if lhs.size() != rhs.size():
		return false
	for index in range(lhs.size()):
		if not lhs[index].is_equal_approx(rhs[index]):
			return false
	return true


func _locate_target_for_raw_triangle(raw_triangle_index: int, target_reports: Array[Dictionary]) -> Dictionary:
	if raw_triangle_index < 0:
		return {}
	var running_start: int = 0
	for target_report in target_reports:
		var triangle_count: int = int(target_report.get("triangle_count", 0))
		var running_end: int = running_start + triangle_count
		if raw_triangle_index >= running_start and raw_triangle_index < running_end:
			var result := target_report.duplicate(true)
			result["target_triangle_index"] = raw_triangle_index - running_start
			return result
		running_start = running_end
	return {}


func _toggle_triangle_in_leaf_bit_provenance(
	leaf_bit_provenance: Dictionary,
	offset: int,
	subgrid_index: int,
	triangle_index: int
) -> void:
	var key: String = _leaf_bit_key(offset, subgrid_index)
	var triangle_set: Dictionary = leaf_bit_provenance.get(key, {})
	if triangle_set.has(triangle_index):
		triangle_set.erase(triangle_index)
	else:
		triangle_set[triangle_index] = true
	leaf_bit_provenance[key] = triangle_set


func _xor_leaf_bit_provenance_from_source(
	leaf_bit_provenance: Dictionary,
	target_offset: int,
	target_subgrid: int,
	source_offset: int,
	source_subgrid: int
) -> void:
	var source_key: String = _leaf_bit_key(source_offset, source_subgrid)
	if not leaf_bit_provenance.has(source_key):
		return
	for triangle_index_variant in leaf_bit_provenance[source_key].keys():
		_toggle_triangle_in_leaf_bit_provenance(
			leaf_bit_provenance,
			target_offset,
			target_subgrid,
			int(triangle_index_variant)
		)


func _get_sorted_leaf_provenance_triangles(
	leaf_bit_provenance: Dictionary,
	offset: int,
	subgrid_index: int
) -> Array[int]:
	var key: String = _leaf_bit_key(offset, subgrid_index)
	if not leaf_bit_provenance.has(key):
		return []
	var result: Array[int] = []
	for triangle_index_variant in leaf_bit_provenance[key].keys():
		result.push_back(int(triangle_index_variant))
	result.sort()
	return result


func _union_leaf_bit_provenance_into(candidate_set: Dictionary, leaf_bit_provenance: Dictionary, offset: int, subgrid_index: int) -> void:
	var key: String = _leaf_bit_key(offset, subgrid_index)
	if not leaf_bit_provenance.has(key):
		return
	for triangle_index_variant in leaf_bit_provenance[key].keys():
		candidate_set[int(triangle_index_variant)] = true


func _ensure_candidate_set(container: Dictionary, offset: int) -> Dictionary:
	if not container.has(offset):
		container[offset] = {}
	return container[offset]


func _get_candidate_set(container: Dictionary, offset: int) -> Dictionary:
	return container.get(offset, {})


func _union_candidate_set(target_set: Dictionary, source_set: Dictionary) -> void:
	for triangle_index_variant in source_set.keys():
		target_set[int(triangle_index_variant)] = true


func _sorted_candidate_set(candidate_set: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for triangle_index_variant in candidate_set.keys():
		result.push_back(int(triangle_index_variant))
	result.sort()
	return result


func _extract_set_bits(mask: int) -> Array[int]:
	var bits: Array[int] = []
	for bit_index in range(64):
		if mask & (1 << bit_index):
			bits.push_back(bit_index)
	return bits


func _leaf_bit_key(offset: int, subgrid_index: int) -> String:
	return "%d:%d" % [offset, subgrid_index]
