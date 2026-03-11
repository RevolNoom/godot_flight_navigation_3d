@tool
extends SceneTree


const InvestigationLib = preload("res://tests/investigation/voxelization_investigation_lib.gd")
const REPORT_PATH: String = "user://investigation/bad_x_column_candidate_subset_repro.json"
const CANDIDATE_TRIANGLE_INDICES: Array[int] = [431, 440, 441]
const EXPECTED_BAD_SVOLINKS: Array[int] = [5390, 5391, 5446, 5447, 5454, 5455]


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
	var voxel_size: Vector3 = FlightNavigation3D.calculate_node_size(
		flight_navigation.size,
		-2,
		voxelizer.layer_count
	)
	var prepare_origin_offset: Vector3 = -flight_navigation.size / 2.0
	var prepared_triangles: PackedVector3Array = await voxelizer._prepare_triangles(
		flight_navigation,
		process_frame,
		InvestigationLib.duplicate_target_array(targets),
		voxelizer.voxelization_mask,
		voxelizer.debug_delete_csg,
		voxelizer.remove_thin_triangles,
		voxelizer.multi_threading_enabled,
		voxelizer.multi_threading_priority,
		prepare_origin_offset
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
		printerr("reproduce_bad_x_column_candidate_triangles: failed to determine active layer-1 nodes.")
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
		printerr("reproduce_bad_x_column_candidate_triangles: failed to construct base SVO.")
		InvestigationLib.teardown_demo(context)
		await process_frame
		quit(1)
		return

	var clean_subgrid: PackedInt64Array = base_svo.subgrid.duplicate()
	var bad_link_details := InvestigationLib.inspect_svolinks(
		flight_navigation.sparse_voxel_octree,
		voxel_size,
		InvestigationLib.BAD_SVOLINKS
	)
	var target_mask_by_offset := _build_target_mask_by_offset(bad_link_details)
	var target_offsets := target_mask_by_offset.keys()
	target_offsets.sort()
	var target_chain_offsets := _build_chain_offsets(base_svo, target_offsets)
	var watch_mask_by_offset := _build_watch_mask_by_offset(target_chain_offsets, target_mask_by_offset)

	var candidate_reports: Array[Dictionary] = []
	for triangle_index in CANDIDATE_TRIANGLE_INDICES:
		candidate_reports.push_back(
			_build_candidate_source_report(
				prepared_triangles,
				raw_triangles,
				target_reports,
				triangle_index,
				-prepare_origin_offset
			)
		)

	var subset_reports: Array[Dictionary] = []
	var direct_seed_minimal_subsets: Array[Array] = []
	var full_reproduction_minimal_subsets: Array[Array] = []
	for subset in _enumerate_non_empty_subsets(CANDIDATE_TRIANGLE_INDICES):
		var stage_subgrid: PackedInt64Array = clean_subgrid.duplicate()
		base_svo.subgrid = stage_subgrid
		for triangle_index in subset:
			if voxelizer.support_float64:
				SvoVoxelizer._parallel_yz_plane_rasterization_f64(
					triangle_index,
					base_svo,
					prepared_triangles,
					voxel_size,
					Fn3dLookupTable.x_column_flip_bitmask_by_subgrid_index,
					flight_navigation.size,
					voxelizer.solid_voxelization_top_left_edge_epsilon,
					voxelizer.solid_voxelization_float_error_margin
				)
			else:
				SvoVoxelizer._parallel_yz_plane_rasterization_f32(
					triangle_index,
					base_svo,
					prepared_triangles,
					voxel_size,
					Fn3dLookupTable.x_column_flip_bitmask_by_subgrid_index,
					flight_navigation.size,
					voxelizer.solid_voxelization_top_left_edge_epsilon,
					voxelizer.solid_voxelization_float_error_margin
				)

		var rasterization_target_report := _build_target_bit_report(
			bad_link_details,
			stage_subgrid,
			target_mask_by_offset
		)
		_propagate_chain_without_provenance(
			base_svo,
			stage_subgrid,
			target_chain_offsets
		)
		var propagated_target_report := _build_target_bit_report(
			bad_link_details,
			stage_subgrid,
			target_mask_by_offset
		)

		var direct_seed_reproduced: bool = _has_exact_solid_links(rasterization_target_report, [5390, 5391])
		var full_bad_column_reproduced: bool = _has_exact_solid_links(
			propagated_target_report,
			EXPECTED_BAD_SVOLINKS
		)
		if direct_seed_reproduced:
			direct_seed_minimal_subsets.push_back(subset)
		if full_bad_column_reproduced:
			full_reproduction_minimal_subsets.push_back(subset)

		subset_reports.push_back({
			"triangle_indices": subset,
			"subset_size": subset.size(),
			"direct_seed_reproduced": direct_seed_reproduced,
			"full_bad_column_reproduced": full_bad_column_reproduced,
			"rasterization_solid_svolinks": _collect_solid_svolinks(rasterization_target_report),
			"propagated_solid_svolinks": _collect_solid_svolinks(propagated_target_report),
		})

	var report := {
		"scene_path": InvestigationLib.DEMO_SCENE_PATH,
		"candidate_triangle_indices": CANDIDATE_TRIANGLE_INDICES,
		"candidate_triangle_reports": candidate_reports,
		"subset_reports": subset_reports,
		"direct_seed_minimal_subsets": _smallest_subsets(direct_seed_minimal_subsets),
		"full_bad_column_minimal_subsets": _smallest_subsets(full_reproduction_minimal_subsets),
	}

	InvestigationLib.write_json_report(REPORT_PATH, report)
	print("Bad x-column candidate subset report written to: %s" % REPORT_PATH)
	print("Bad x-column direct-seed minimal subsets: %s" % var_to_str(report["direct_seed_minimal_subsets"]))
	print("Bad x-column full reproduction minimal subsets: %s" % var_to_str(report["full_bad_column_minimal_subsets"]))

	InvestigationLib.teardown_demo(context)
	await process_frame
	quit()


func _build_candidate_source_report(
	prepared_triangles: PackedVector3Array,
	raw_triangles: PackedVector3Array,
	target_reports: Array[Dictionary],
	triangle_index: int,
	coordinate_offset: Vector3
) -> Dictionary:
	var start: int = triangle_index * 3
	var raw_match_index: int = _find_raw_triangle_match(
		raw_triangles,
		prepared_triangles[start],
		prepared_triangles[start + 1],
		prepared_triangles[start + 2],
		coordinate_offset
	)
	var source_info := _locate_target_for_raw_triangle(raw_match_index, target_reports)
	return {
		"triangle_index": triangle_index,
		"v0": InvestigationLib.vec3_to_array(prepared_triangles[start]),
		"v1": InvestigationLib.vec3_to_array(prepared_triangles[start + 1]),
		"v2": InvestigationLib.vec3_to_array(prepared_triangles[start + 2]),
		"raw_triangle_index": raw_match_index,
		"source_target_path": source_info.get("target_path", ""),
		"source_parent_path": source_info.get("parent_path", ""),
		"source_parent_type": source_info.get("parent_type", ""),
		"source_target_triangle_index": int(source_info.get("target_triangle_index", -1)),
	}


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


func _propagate_chain_without_provenance(
	svo: SVO,
	subgrid: PackedInt64Array,
	target_chain_offsets: Array[int]
) -> void:
	if target_chain_offsets.is_empty():
		return
	for chain_index in range(target_chain_offsets.size() - 1):
		var current_offset: int = target_chain_offsets[chain_index]
		var neighbor_offset: int = target_chain_offsets[chain_index + 1]
		var flip_buffer: int = 0
		for source_subgrid in Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"]:
			var source_bitmask: int = 1 << source_subgrid
			if subgrid[current_offset] & source_bitmask == 0:
				continue
			flip_buffer |= Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index[source_subgrid]
		if flip_buffer == 0:
			continue
		subgrid[neighbor_offset] = subgrid[neighbor_offset] ^ flip_buffer


func _build_target_bit_report(
	bad_link_details: Array[Dictionary],
	subgrid: PackedInt64Array,
	target_mask_by_offset: Dictionary
) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for detail in bad_link_details:
		if detail.has("error"):
			report.push_back(detail)
			continue
		var offset: int = detail["offset"]
		var bit_mask: int = 1 << int(detail["subgrid"])
		var item := detail.duplicate(true)
		item["is_solid"] = (subgrid[offset] & bit_mask) != 0
		item["offset_target_mask"] = int(target_mask_by_offset.get(offset, 0))
		report.push_back(item)
	return report


func _collect_solid_svolinks(target_report: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	for item in target_report:
		if bool(item.get("is_solid", false)):
			result.push_back(int(item["svolink"]))
	return result


func _has_exact_solid_links(target_report: Array[Dictionary], expected_svolinks: Array[int]) -> bool:
	var expected: Dictionary = {}
	for svolink in expected_svolinks:
		expected[svolink] = true
	var actual: Dictionary = {}
	for item in target_report:
		if bool(item.get("is_solid", false)):
			actual[int(item["svolink"])] = true
	return actual == expected


func _enumerate_non_empty_subsets(indices: Array[int]) -> Array[Array]:
	var subsets: Array[Array] = []
	for mask in range(1, 1 << indices.size()):
		var subset: Array[int] = []
		for bit_index in range(indices.size()):
			if mask & (1 << bit_index):
				subset.push_back(indices[bit_index])
		subsets.push_back(subset)
	return subsets


func _smallest_subsets(subsets: Array[Array]) -> Array[Array]:
	if subsets.is_empty():
		return []
	var minimum_size: int = subsets[0].size()
	for subset in subsets:
		minimum_size = mini(minimum_size, subset.size())
	var result: Array[Array] = []
	for subset in subsets:
		if subset.size() == minimum_size:
			result.push_back(subset)
	return result
