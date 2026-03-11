extends GutTest


const EDGE_EPSILON: float = 0.00001


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
		EDGE_EPSILON,
		EDGE_EPSILON
	)
	SvoVoxelizer._parallel_yz_plane_rasterization_f64(
		0,
		svo_f64,
		triangles,
		Vector3.ONE,
		flip_masks,
		Vector3(4.0, 4.0, 4.0),
		EDGE_EPSILON,
		EDGE_EPSILON
	)

	var expected_subgrid_bit: int = 1 << Morton3.encode64(1, 0, 0)
	assert_eq(svo_f32.subgrid[0], expected_subgrid_bit)
	assert_eq(svo_f64.subgrid[0], expected_subgrid_bit)
	assert_eq(svo_f32.subgrid, svo_f64.subgrid)


func _create_single_leaf_svo() -> SVO:
	var svo := SVO.new()
	svo.set_layer_count(1)
	svo.set_node_count_in_layer(0, 1)
	svo.set_morton(0, 0, 0)
	svo.subgrid.resize(1)
	svo.set_subgrid(0, 0)
	return svo
