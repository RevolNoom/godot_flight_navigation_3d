@tool
extends SceneTree


const InvestigationLib = preload("res://tests/investigation/voxelization_investigation_lib.gd")
const REPORT_PATH: String = "user://investigation/bad_x_column_provenance.json"


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
	var final_svo := flight_navigation.sparse_voxel_octree
	if final_svo == null:
		printerr("trace_bad_x_column_provenance: demo scene has no sparse_voxel_octree.")
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
		printerr("trace_bad_x_column_provenance: failed to determine active layer-1 nodes.")
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
		printerr("trace_bad_x_column_provenance: failed to construct base SVO.")
		InvestigationLib.teardown_demo(context)
		await process_frame
		quit(1)
		return

	var bad_link_details := InvestigationLib.inspect_svolinks(
		final_svo,
		voxel_size,
		InvestigationLib.BAD_SVOLINKS
	)
	var target_mask_by_offset := _build_target_mask_by_offset(bad_link_details)
	var target_offsets := target_mask_by_offset.keys()
	target_offsets.sort()
	var target_chain_offsets := _build_chain_offsets(base_svo, target_offsets)
	var watch_mask_by_offset := _build_watch_mask_by_offset(target_chain_offsets, target_mask_by_offset)

	var stage_subgrid: PackedInt64Array = base_svo.subgrid.duplicate()
	base_svo.subgrid = stage_subgrid

	var provenance: Dictionary = {}
	var rasterization_events: Array[Dictionary] = []
	var rasterization_callable: Callable = SvoVoxelizer._parallel_yz_plane_rasterization_f32
	if voxelizer.support_float64:
		rasterization_callable = SvoVoxelizer._parallel_yz_plane_rasterization_f64

	for triangle_index in range(prepared_triangles.size() / 3):
		var before_masks := _snapshot_masks(stage_subgrid, watch_mask_by_offset)
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
			watch_mask_by_offset,
			provenance
		)
		if not event.is_empty():
			rasterization_events.push_back(event)

	var rasterization_target_report := _build_target_bit_report(
		bad_link_details,
		stage_subgrid,
		target_mask_by_offset,
		provenance
	)
	var propagation_events := _propagate_chain_with_provenance(
		base_svo,
		stage_subgrid,
		target_chain_offsets,
		watch_mask_by_offset,
		provenance
	)
	var propagated_target_report := _build_target_bit_report(
		bad_link_details,
		stage_subgrid,
		target_mask_by_offset,
		provenance
	)
	var final_target_report := _build_target_bit_report(
		bad_link_details,
		final_svo.subgrid,
		target_mask_by_offset,
		{}
	)
	var parent_aggregation_report := _build_parent_aggregation_report(
		base_svo,
		stage_subgrid,
		target_offsets
	)

	var raster_target_solid_count: int = _count_solid_target_bits(rasterization_target_report)
	var propagated_target_solid_count: int = _count_solid_target_bits(propagated_target_report)
	var final_target_solid_count: int = _count_solid_target_bits(final_target_report)
	var probable_origin_stage: String = "undetermined"
	if raster_target_solid_count == 0 and propagated_target_solid_count == final_target_solid_count:
		probable_origin_stage = "x_plus_bit_flip_propagation"
	elif raster_target_solid_count > 0:
		probable_origin_stage = "direct_triangle_rasterization_or_layer0_accumulation"

	var candidate_triangle_union := _collect_union_of_target_provenance(propagated_target_report)
	var minimal_candidate: Array[int] = []
	if not candidate_triangle_union.is_empty() and candidate_triangle_union.size() <= 3:
		minimal_candidate = candidate_triangle_union
	var candidate_triangle_reports: Array[Dictionary] = []
	for triangle_index in candidate_triangle_union:
		candidate_triangle_reports.push_back(_triangle_report(prepared_triangles, triangle_index))

	var report := {
		"scene_path": InvestigationLib.DEMO_SCENE_PATH,
		"prepared_triangle_count": prepared_triangles.size() / 3,
		"support_float64": voxelizer.support_float64,
		"voxel_size": InvestigationLib.vec3_to_array(voxel_size),
		"bad_svolink_details": bad_link_details,
		"target_offsets": target_offsets,
		"target_chain_offsets": target_chain_offsets,
		"target_mask_by_offset": _stringify_int_dictionary(target_mask_by_offset),
		"watch_mask_by_offset": _stringify_int_dictionary(watch_mask_by_offset),
		"rasterization_event_count": rasterization_events.size(),
		"rasterization_events": rasterization_events,
		"rasterization_target_report": rasterization_target_report,
		"propagation_event_count": propagation_events.size(),
		"propagation_events": propagation_events,
		"propagated_target_report": propagated_target_report,
		"final_target_report": final_target_report,
		"parent_aggregation_report": parent_aggregation_report,
		"probable_origin_stage": probable_origin_stage,
		"candidate_triangle_union": candidate_triangle_union,
		"minimal_candidate_triangle_set": minimal_candidate,
		"candidate_triangle_reports": candidate_triangle_reports,
		"leaf_voxel_solidness_note": "Layer-0 bad SVOLinks read solidness directly from SVO.subgrid bits; later layer-1+ flip aggregation does not rewrite these leaf bits.",
	}

	InvestigationLib.write_json_report(REPORT_PATH, report)
	print("Bad x-column provenance report written to: %s" % REPORT_PATH)
	print("Bad x-column provenance raster target solid count: %d" % raster_target_solid_count)
	print("Bad x-column provenance propagated target solid count: %d" % propagated_target_solid_count)
	print("Bad x-column provenance final target solid count: %d" % final_target_solid_count)
	print("Bad x-column provenance probable origin stage: %s" % probable_origin_stage)
	if not minimal_candidate.is_empty():
		print("Bad x-column provenance minimal candidate triangle set: %s" % var_to_str(minimal_candidate))

	InvestigationLib.teardown_demo(context)
	await process_frame
	quit()


func _build_target_mask_by_offset(bad_link_details: Array[Dictionary]) -> Dictionary:
	var target_mask_by_offset: Dictionary = {}
	for detail in bad_link_details:
		if detail.has("error"):
			continue
		var offset: int = detail["offset"]
		var subgrid: int = detail["subgrid"]
		target_mask_by_offset[offset] = int(target_mask_by_offset.get(offset, 0)) | (1 << subgrid)
	return target_mask_by_offset


func _build_chain_offsets(svo: SVO, target_offsets: Array) -> Array[int]:
	if target_offsets.is_empty():
		return []

	var min_target: int = target_offsets[0]
	var max_target: int = target_offsets[target_offsets.size() - 1]
	var head_offset: int = min_target
	while true:
		var xn_svolink: int = svo.xn[0][head_offset]
		if xn_svolink == SvoLink64.singleton.null_link():
			break
		if SvoLink64.singleton.get_layer(xn_svolink) != 0:
			break
		head_offset = SvoLink64.singleton.get_offset(xn_svolink)

	var chain_offsets: Array[int] = [head_offset]
	var current_offset: int = head_offset
	while current_offset < max_target:
		var xp_svolink: int = svo.xp[0][current_offset]
		if xp_svolink == SvoLink64.singleton.null_link():
			break
		if SvoLink64.singleton.get_layer(xp_svolink) != 0:
			break
		current_offset = SvoLink64.singleton.get_offset(xp_svolink)
		chain_offsets.push_back(current_offset)
	return chain_offsets


func _build_watch_mask_by_offset(
	target_chain_offsets: Array[int],
	target_mask_by_offset: Dictionary
) -> Dictionary:
	var watch_mask_by_offset: Dictionary = {}
	for offset in target_chain_offsets:
		watch_mask_by_offset[offset] = Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp
	for offset in target_mask_by_offset.keys():
		watch_mask_by_offset[offset] = int(watch_mask_by_offset.get(offset, 0)) | int(target_mask_by_offset[offset])
	return watch_mask_by_offset


func _snapshot_masks(subgrid: PackedInt64Array, watch_mask_by_offset: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	for offset in watch_mask_by_offset.keys():
		snapshot[offset] = subgrid[offset] & int(watch_mask_by_offset[offset])
	return snapshot


func _capture_mask_delta_event(
	triangle_index: int,
	before_masks: Dictionary,
	subgrid: PackedInt64Array,
	watch_mask_by_offset: Dictionary,
	provenance: Dictionary
) -> Dictionary:
	var delta_by_offset: Array[Dictionary] = []
	for offset in watch_mask_by_offset.keys():
		var mask: int = int(watch_mask_by_offset[offset])
		var before_value: int = int(before_masks.get(offset, 0))
		var after_value: int = subgrid[offset] & mask
		var delta: int = before_value ^ after_value
		if delta == 0:
			continue
		var toggled_subgrids := _extract_set_bits(delta)
		for subgrid_index in toggled_subgrids:
			_toggle_triangle_in_provenance(provenance, int(offset), subgrid_index, triangle_index)
		delta_by_offset.push_back({
			"offset": int(offset),
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


func _propagate_chain_with_provenance(
	svo: SVO,
	subgrid: PackedInt64Array,
	target_chain_offsets: Array[int],
	watch_mask_by_offset: Dictionary,
	provenance: Dictionary
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if target_chain_offsets.is_empty():
		return events

	var watch_offsets: Dictionary = {}
	for offset in target_chain_offsets:
		watch_offsets[offset] = true

	for chain_index in range(target_chain_offsets.size() - 1):
		var current_offset: int = target_chain_offsets[chain_index]
		var neighbor_offset: int = target_chain_offsets[chain_index + 1]
		var flip_buffer: int = 0
		var event_sources: Array[Dictionary] = []
		var neighbor_watch_mask: int = int(watch_mask_by_offset.get(neighbor_offset, 0))

		for source_subgrid in Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"]:
			var source_bitmask: int = 1 << source_subgrid
			if subgrid[current_offset] & source_bitmask == 0:
				continue
			var propagated_mask: int = Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index[source_subgrid]
			flip_buffer |= propagated_mask

			var watched_overlap: int = propagated_mask & neighbor_watch_mask
			if watched_overlap == 0:
				continue

			var target_subgrids := _extract_set_bits(watched_overlap)
			var source_provenance := _get_sorted_provenance_triangles(
				provenance,
				current_offset,
				source_subgrid
			)
			for target_subgrid in target_subgrids:
				_xor_provenance_sets(
					provenance,
					neighbor_offset,
					target_subgrid,
					current_offset,
					source_subgrid
				)

			event_sources.push_back({
				"source_offset": current_offset,
				"source_subgrid": source_subgrid,
				"source_subgrid_coords": InvestigationLib.vec3i_to_array(Morton3.decode_vec3i(source_subgrid)),
				"target_offset": neighbor_offset,
				"propagated_mask": propagated_mask,
				"target_subgrids": target_subgrids,
				"source_provenance_triangles": source_provenance,
			})

		if flip_buffer == 0:
			continue

		var before_value: int = subgrid[neighbor_offset] & neighbor_watch_mask
		subgrid[neighbor_offset] = subgrid[neighbor_offset] ^ flip_buffer
		var after_value: int = subgrid[neighbor_offset] & neighbor_watch_mask
		var delta_mask: int = before_value ^ after_value
		if delta_mask == 0:
			continue

		events.push_back({
			"source_offset": current_offset,
			"target_offset": neighbor_offset,
			"before_masked": before_value,
			"after_masked": after_value,
			"delta_mask": delta_mask,
			"toggled_subgrids": _extract_set_bits(delta_mask),
			"source_details": event_sources,
		})
	return events


func _build_target_bit_report(
	bad_link_details: Array[Dictionary],
	subgrid: PackedInt64Array,
	target_mask_by_offset: Dictionary,
	provenance: Dictionary
) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for detail in bad_link_details:
		if detail.has("error"):
			report.push_back(detail)
			continue

		var offset: int = detail["offset"]
		var bit_mask: int = 1 << int(detail["subgrid"])
		var is_solid: bool = (subgrid[offset] & bit_mask) != 0
		var item := detail.duplicate(true)
		item["is_solid"] = is_solid
		item["offset_target_mask"] = int(target_mask_by_offset.get(offset, 0))
		item["provenance_triangles"] = _get_sorted_provenance_triangles(
			provenance,
			offset,
			int(detail["subgrid"])
		)
		report.push_back(item)
	return report


func _build_parent_aggregation_report(
	svo: SVO,
	subgrid: PackedInt64Array,
	target_offsets: Array
) -> Array[Dictionary]:
	var seen_parent_offsets: Dictionary = {}
	var report: Array[Dictionary] = []
	for target_offset_variant in target_offsets:
		var target_offset: int = int(target_offset_variant)
		var parent_svolink: int = svo.parent[0][target_offset]
		if parent_svolink == SvoLink64.singleton.null_link():
			continue
		var parent_offset: int = SvoLink64.singleton.get_offset(parent_svolink)
		if seen_parent_offsets.has(parent_offset):
			continue
		seen_parent_offsets[parent_offset] = true

		var first_child_svolink: int = svo.first_child[1][parent_offset]
		if first_child_svolink == SvoLink64.singleton.null_link():
			continue
		var first_child_offset: int = SvoLink64.singleton.get_offset(first_child_svolink)
		var xp_children: Array[Dictionary] = []
		for child_offset_delta in [1, 3, 5, 7]:
			var child_offset: int = first_child_offset + child_offset_delta
			var child_subgrid: int = subgrid[child_offset]
			xp_children.push_back({
				"child_offset": child_offset,
				"xp_face_full": (child_subgrid & Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp) == Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp,
			})

		report.push_back({
			"parent_layer": 1,
			"parent_offset": parent_offset,
			"first_child_offset": first_child_offset,
			"is_end_of_x_linked_node_string": SvoVoxelizer._is_end_of_x_linked_node_string(1, parent_offset, svo.first_child, svo.xp),
			"flip_flag_from_children": SvoVoxelizer._has_full_xp_face_in_all_children(
				first_child_offset,
				subgrid,
				Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp
			),
			"xp_children": xp_children,
		})
	return report


func _toggle_triangle_in_provenance(
	provenance: Dictionary,
	offset: int,
	subgrid_index: int,
	triangle_index: int
) -> void:
	var key: String = _provenance_key(offset, subgrid_index)
	var triangle_set: Dictionary = provenance.get(key, {})
	if triangle_set.has(triangle_index):
		triangle_set.erase(triangle_index)
	else:
		triangle_set[triangle_index] = true
	provenance[key] = triangle_set


func _xor_provenance_sets(
	provenance: Dictionary,
	target_offset: int,
	target_subgrid: int,
	source_offset: int,
	source_subgrid: int
) -> void:
	var source_key: String = _provenance_key(source_offset, source_subgrid)
	if not provenance.has(source_key):
		return
	var source_set: Dictionary = provenance[source_key]
	for triangle_index_variant in source_set.keys():
		_toggle_triangle_in_provenance(
			provenance,
			target_offset,
			target_subgrid,
			int(triangle_index_variant)
		)


func _get_sorted_provenance_triangles(
	provenance: Dictionary,
	offset: int,
	subgrid_index: int
) -> Array[int]:
	var key: String = _provenance_key(offset, subgrid_index)
	if not provenance.has(key):
		return []
	var result: Array[int] = []
	for triangle_index_variant in provenance[key].keys():
		result.push_back(int(triangle_index_variant))
	result.sort()
	return result


func _count_solid_target_bits(target_report: Array[Dictionary]) -> int:
	var solid_count: int = 0
	for item in target_report:
		if bool(item.get("is_solid", false)):
			solid_count += 1
	return solid_count


func _collect_union_of_target_provenance(target_report: Array[Dictionary]) -> Array[int]:
	var triangle_set: Dictionary = {}
	for item in target_report:
		for triangle_index_variant in item.get("provenance_triangles", []):
			triangle_set[int(triangle_index_variant)] = true
	var result: Array[int] = []
	for triangle_index_variant in triangle_set.keys():
		result.push_back(int(triangle_index_variant))
	result.sort()
	return result


func _extract_set_bits(mask: int) -> Array[int]:
	var bits: Array[int] = []
	for bit_index in range(64):
		if mask & (1 << bit_index):
			bits.push_back(bit_index)
	return bits


func _stringify_int_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[str(key)] = source[key]
	return result


func _provenance_key(offset: int, subgrid_index: int) -> String:
	return "%d:%d" % [offset, subgrid_index]


func _triangle_report(triangles: PackedVector3Array, triangle_index: int) -> Dictionary:
	var start: int = triangle_index * 3
	return {
		"triangle_index": triangle_index,
		"v0": InvestigationLib.vec3_to_array(triangles[start]),
		"v1": InvestigationLib.vec3_to_array(triangles[start + 1]),
		"v2": InvestigationLib.vec3_to_array(triangles[start + 2]),
	}
