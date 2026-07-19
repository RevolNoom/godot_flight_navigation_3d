extends GutTest


const EDGE_EPSILON: float = 0.00001
const InvestigationLib = preload("res://tests/investigation/voxelization_investigation_lib.gd")


func test_parallel_yz_plane_rasterization_f32_matches_f64_for_boundary_triangle() -> void:
	var triangles := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 1.0, 0.0),
		Vector3(1.0, 0.5, 0.5),
	])
	var flip_masks := PackedInt64Array()
	flip_masks.resize(64)
	for subgrid_index in range(64):
		flip_masks[subgrid_index] = 1 << subgrid_index

	var svo_f32 := _create_single_leaf_svo()
	var svo_f64 := _create_single_leaf_svo()

	SvoVoxelizer._parallel_yz_plane_rasterization_f32(
		0,
		svo_f32,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON
	)
	SvoVoxelizer._parallel_yz_plane_rasterization_f64(
		0,
		svo_f64,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON
	)

	assert_eq(svo_f32.subgrid[0], 0)
	assert_eq(svo_f64.subgrid[0], 0)
	assert_eq(svo_f32.subgrid, svo_f64.subgrid)


func test_parallel_yz_plane_rasterization_applies_top_left_tie_break_once_for_shared_diagonal() -> void:
	var triangles := PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 1.0, 0.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(2.0, 1.0, 1.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(1.0, 1.0, 0.0),
	])
	var expected_subgrid_bit: int = 1 << Morton3.encode64(1, 0, 0)

	var f32_single_bits := _rasterize_triangle_pair_bits_f32(triangles)
	assert_eq(f32_single_bits[0] | f32_single_bits[1], expected_subgrid_bit)
	assert_eq(f32_single_bits[2], expected_subgrid_bit)

	var f64_single_bits := _rasterize_triangle_pair_bits_f64(triangles)
	assert_eq(f64_single_bits[0] | f64_single_bits[1], expected_subgrid_bit)
	assert_eq(f64_single_bits[2], expected_subgrid_bit)


func test_parallel_propagate_bit_flip_propagates_across_same_layer_leaf_neighbors() -> void:
	var source_subgrid_index: int = Morton3.encode64(3, 2, 1)
	var expected_mask: int = Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index[source_subgrid_index]
	var svo := _create_leaf_chain_svo(SvoLink64.singleton.null_link())
	svo.subgrid[0] = 1 << source_subgrid_index

	SvoVoxelizer._parallel_propagate_bit_flip(
		0,
		PackedInt64Array([0]),
		Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"],
		svo.xp,
		svo.subgrid,
		Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index
	)

	assert_eq(svo.subgrid[1], expected_mask)


func test_parallel_propagate_bit_flip_skips_leaf_tail_adjacent_to_coarser_x_neighbor() -> void:
	var source_subgrid_index: int = Morton3.encode64(3, 2, 1)
	var coarse_xp_neighbor: int = SvoLink64.singleton.create(1, 0)
	var svo := _create_leaf_chain_svo(coarse_xp_neighbor)
	svo.subgrid[0] = 1 << source_subgrid_index

	SvoVoxelizer._parallel_propagate_bit_flip(
		0,
		PackedInt64Array([0]),
		Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"],
		svo.xp,
		svo.subgrid,
		Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index
	)

	assert_eq(svo.subgrid[1], 0)


func test_demo_reported_solid_propagation_links_remain_free_after_rebuild() -> void:
	var context := await InvestigationLib.setup_demo(get_tree())
	assert_false(context.is_empty(), "Demo scene should load for reported propagation regression coverage")
	if context.is_empty():
		return

	var flight_navigation := context["flight_navigation"] as FlightNavigation3D
	await flight_navigation.build_navigation()

	var rebuilt_svo := flight_navigation.sparse_voxel_octree
	assert_not_null(rebuilt_svo)
	if rebuilt_svo == null:
		InvestigationLib.teardown_demo(context)
		await get_tree().process_frame
		return

	for reported_svolink in _get_reported_bad_solid_links():
		assert_false(
			rebuilt_svo.is_solid(reported_svolink),
			"Reported propagation regression should remain free: %s" %
			SvoLink64.singleton.get_format_string(reported_svolink)
		)

	InvestigationLib.teardown_demo(context)
	await get_tree().process_frame


func _rasterize_triangle_pair_bits_f32(triangles: PackedVector3Array) -> Array[int]:
	var first := _create_single_leaf_svo()
	var second := _create_single_leaf_svo()
	var pair := _create_single_leaf_svo()
	var flip_masks := _create_identity_flip_masks()

	SvoVoxelizer._parallel_yz_plane_rasterization_f32(
		0,
		first,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON
	)
	SvoVoxelizer._parallel_yz_plane_rasterization_f32(
		1,
		second,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON
	)
	SvoVoxelizer._parallel_yz_plane_rasterization_f32(
		0,
		pair,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON
	)
	SvoVoxelizer._parallel_yz_plane_rasterization_f32(
		1,
		pair,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON
	)

	return [first.subgrid[0], second.subgrid[0], pair.subgrid[0]]


func _rasterize_triangle_pair_bits_f64(triangles: PackedVector3Array) -> Array[int]:
	var first := _create_single_leaf_svo()
	var second := _create_single_leaf_svo()
	var pair := _create_single_leaf_svo()
	var flip_masks := _create_identity_flip_masks()

	SvoVoxelizer._parallel_yz_plane_rasterization_f64(
		0,
		first,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON
	)
	SvoVoxelizer._parallel_yz_plane_rasterization_f64(
		1,
		second,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON
	)
	SvoVoxelizer._parallel_yz_plane_rasterization_f64(
		0,
		pair,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON
	)
	SvoVoxelizer._parallel_yz_plane_rasterization_f64(
		1,
		pair,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON
	)

	return [first.subgrid[0], second.subgrid[0], pair.subgrid[0]]


func _create_identity_flip_masks() -> PackedInt64Array:
	var flip_masks := PackedInt64Array()
	flip_masks.resize(64)
	for subgrid_index in range(64):
		flip_masks[subgrid_index] = 1 << subgrid_index
	return flip_masks


func _create_single_leaf_svo() -> SVO:
	var svo := SVO.new()
	svo.set_layer_count(1)
	svo.set_node_count_in_layer(0, 1)
	svo.set_morton(0, 0, 0)
	svo.subgrid.resize(1)
	svo.set_subgrid(0, 0)
	return svo


func _create_leaf_chain_svo(tail_xp_neighbor: int) -> SVO:
	var svo := SVO.new()
	svo.set_layer_count(2)
	svo.set_node_count_in_layer(0, 2)
	svo.set_node_count_in_layer(1, 1)
	svo.subgrid.resize(2)
	svo.subgrid.fill(0)

	for layer_array in [svo.parent, svo.first_child, svo.xp, svo.yp, svo.zp, svo.xn, svo.yn, svo.zn]:
		for packed_array: PackedInt64Array in layer_array:
			packed_array.fill(SvoLink64.singleton.null_link())

	svo.xp[0][0] = SvoLink64.singleton.create(0, 1)
	svo.xn[0][1] = SvoLink64.singleton.create(0, 0)
	svo.xp[0][1] = tail_xp_neighbor

	return svo


func _get_reported_bad_solid_links() -> PackedInt64Array:
	return PackedInt64Array([
		SvoLink64.singleton.create(1, 1789),
		SvoLink64.singleton.create(1, 1785),
		SvoLink64.singleton.create(1, 1459),
		SvoLink64.singleton.create(0, 4811, 63),
		SvoLink64.singleton.create(0, 4841, 47),
		SvoLink64.singleton.create(0, 3811, 45),
	])
