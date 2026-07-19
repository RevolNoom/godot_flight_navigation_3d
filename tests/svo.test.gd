extends GutTest


const FLOAT_TOLERANCE: float = 0.000001


func test_get_svolink_from_node_morton_returns_link_and_null_for_missing_nodes() -> void:
	var svo := _create_two_adjacent_leaf_nodes_svo()
	var existing_morton: int = Morton3.encode64v(Vector3i(1, 0, 0))

	assert_eq(svo.get_svolink_from_node_morton(0, existing_morton), SvoLink64.singleton.create(0, 1))
	assert_eq(svo.get_svolink_from_node_morton(0, Morton3.encode64v(Vector3i(2, 0, 0))), SvoLink64.singleton.null_link())


func test_get_svolink_from_voxel_morton_returns_parent_offset_and_requested_subgrid() -> void:
	var svo := _create_two_adjacent_leaf_nodes_svo()
	var morton_value: int = Morton3.encode64v(Vector3i(5, 2, 1))

	assert_eq(
		svo.get_svolink_from_voxel_morton(morton_value),
		SvoLink64.singleton.create(0, 1, Morton3.encode64v(Vector3i(1, 2, 1)))
	)


func test_get_center_and_get_node_center_use_correct_resolution_for_voxels_and_nodes() -> void:
	var svo := _create_branch_svo_with_root_children()
	var voxel_link: int = SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(3, 2, 1)))
	var root_link: int = SvoLink64.singleton.create(1, 0)

	_assert_vector3_almost_eq(svo.get_center(voxel_link), Vector3(3.5, 2.5, 1.5), "Voxel center should include subgrid offset")
	_assert_vector3_almost_eq(svo.get_node_center(root_link), Vector3(4.0, 4.0, 4.0), "Node center should use node dimensions")


func test_get_voxels_and_nodes_on_face_for_leaf_returns_face_voxels() -> void:
	var svo := _create_single_leaf_svo_with_distinct_face_arrays()
	var node_link: int = SvoLink64.singleton.create(0, 0)
	var face_voxels: PackedInt64Array = svo.get_voxels_and_nodes_on_face_xp(node_link)
	var expected_face_voxels: PackedInt64Array = []
	for subgrid_index in Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"]:
		expected_face_voxels.push_back(SvoLink64.singleton.create(0, 0, subgrid_index))

	assert_eq(face_voxels, expected_face_voxels)


func test_get_voxels_and_nodes_on_face_returns_node_when_branch_has_no_children() -> void:
	var svo := _create_childless_root_svo()
	var root_link: int = SvoLink64.singleton.create(1, 0)

	assert_eq(svo.get_voxels_and_nodes_on_face_xp(root_link), PackedInt64Array([root_link]))


func test_get_voxels_and_nodes_on_face_recurses_into_children_on_requested_face() -> void:
	var svo := _create_branch_svo_with_root_children(true)
	var root_link: int = SvoLink64.singleton.create(1, 0)
	var result: PackedInt64Array = svo.get_voxels_and_nodes_on_face_xp(root_link)
	var expected_offsets := PackedInt64Array([1, 3, 5, 7])

	assert_eq(result.size(), 64)
	for voxel_link in result:
		assert_has(expected_offsets, SvoLink64.singleton.get_offset(voxel_link))
		assert_eq(
			Morton3.decode_vec3i(SvoLink64.singleton.get_subgrid(voxel_link)).x,
			3,
			"Each returned voxel should lie on the +X face of its child node"
		)


func test_get_neighbors_of_leaf_voxel_returns_adjacent_voxels_within_same_parent() -> void:
	var svo := _create_single_leaf_svo()
	var center_link: int = SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(1, 1, 1)))
	var expected := PackedInt64Array([
		SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(0, 1, 1))),
		SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(2, 1, 1))),
		SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(1, 0, 1))),
		SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(1, 2, 1))),
		SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(1, 1, 0))),
		SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(1, 1, 2))),
	])

	assert_eq(svo.get_neighbors_of(center_link), expected)


func test_get_neighbors_of_leaf_voxel_crosses_to_neighbor_node_at_subgrid_boundary() -> void:
	var svo := _create_two_adjacent_leaf_nodes_svo()
	var boundary_link: int = SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(3, 1, 1)))
	var neighbors: PackedInt64Array = svo.get_neighbors_of(boundary_link)
	var expected_neighbor: int = SvoLink64.singleton.create(0, 1, Morton3.encode64v(Vector3i(0, 1, 1)))

	assert_has(neighbors, expected_neighbor, "Boundary voxel should connect into the adjacent node")
	assert_eq(neighbors.size(), 6)


func test_get_offsets_of_head_nodes_in_x_direction_treats_missing_and_coarser_neighbors_as_heads() -> void:
	var svo := _create_head_offset_fixture()

	assert_eq(svo.get_offsets_of_head_nodes_in_x_direction_of_layer(0), PackedInt64Array([0, 2]))


func test_get_solid_bit_counts_by_subgrid_counts_bits_for_each_layer_zero_node() -> void:
	var svo := _create_two_adjacent_leaf_nodes_svo()
	svo.set_subgrid(0, 0b10101)
	svo.set_subgrid(1, 0b110000)

	assert_eq(svo.get_list_solid_bit_count_by_subgrid(), PackedInt64Array([3, 2]))
	assert_eq(svo.get_solid_bit_counts_by_subgrid(), PackedInt32Array([3, 2]))


func test_is_solid_supports_voxel_queries_node_queries_and_branch_nodes() -> void:
	var leaf_svo := _create_single_leaf_svo([Vector3i(2, 1, 0)])
	var solid_voxel: int = SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(2, 1, 0)))
	var empty_voxel: int = SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(0, 0, 0)))

	assert_true(leaf_svo.is_solid(solid_voxel))
	assert_false(leaf_svo.is_solid(empty_voxel))
	_set_inside_value(leaf_svo, 0, 0, 1)
	assert_true(leaf_svo.is_solid(0, 0))

	var branch_svo := _create_childless_root_svo()
	_set_inside_value(branch_svo, 1, 0, 1)
	assert_true(branch_svo.is_solid(SvoLink64.singleton.create(1, 0)))
	branch_svo.set_first_child(1, 0, SvoLink64.singleton.create(0, 0))
	assert_false(branch_svo.is_solid(SvoLink64.singleton.create(1, 0)))


func test_deep_compare_requires_identical_structure_and_content() -> void:
	var original := _create_two_adjacent_leaf_nodes_svo([Vector3i(0, 0, 0)], [Vector3i(3, 3, 3)])
	var identical := _create_two_adjacent_leaf_nodes_svo([Vector3i(0, 0, 0)], [Vector3i(3, 3, 3)])
	var modified := _create_two_adjacent_leaf_nodes_svo([Vector3i(0, 0, 0)], [Vector3i(0, 0, 0)])

	assert_true(original.deep_compare(identical))
	assert_false(original.deep_compare(modified))
	assert_false(original.deep_compare(null))


func _create_single_leaf_svo(solid_subgrids: Array[Vector3i] = []) -> SVO:
	var svo := SVO.new()
	svo.set_layer_count(1)
	svo.set_node_count_in_layer(0, 1)
	svo.set_morton(0, 0, 0)
	svo.subgrid.resize(1)
	svo.set_subgrid(0, _bitmask_from_subgrids(solid_subgrids))
	_fill_link_arrays_with_null(svo)
	return svo


func _create_single_leaf_svo_with_distinct_face_arrays() -> SVO:
	var svo := _create_single_leaf_svo()
	_seed_distinct_face_array_values(svo)
	return svo


func _create_two_adjacent_leaf_nodes_svo(
	solid_subgrids_left: Array[Vector3i] = [],
	solid_subgrids_right: Array[Vector3i] = []
) -> SVO:
	var svo := SVO.new()
	svo.set_layer_count(1)
	svo.set_node_count_in_layer(0, 2)
	svo.set_morton(0, 0, 0)
	svo.set_morton(0, 1, Morton3.encode64v(Vector3i(1, 0, 0)))
	svo.subgrid.resize(2)
	svo.set_subgrid(0, _bitmask_from_subgrids(solid_subgrids_left))
	svo.set_subgrid(1, _bitmask_from_subgrids(solid_subgrids_right))
	_fill_link_arrays_with_null(svo)
	svo.set_xp_neighbor(0, 0, SvoLink64.singleton.create(0, 1))
	svo.set_xn_neighbor(0, 1, SvoLink64.singleton.create(0, 0))
	return svo


func _create_childless_root_svo() -> SVO:
	var svo := SVO.new()
	svo.set_layer_count(2)
	svo.set_node_count_in_layer(0, 0)
	svo.set_node_count_in_layer(1, 1)
	svo.subgrid.resize(0)
	svo.set_morton(1, 0, 0)
	_fill_link_arrays_with_null(svo)
	return svo


func _create_branch_svo_with_root_children(seed_distinct_faces: bool = false) -> SVO:
	var svo := SVO.new()
	svo.set_layer_count(2)
	svo.set_node_count_in_layer(0, 8)
	svo.set_node_count_in_layer(1, 1)
	svo.subgrid.resize(8)
	for child_offset in range(8):
		svo.set_morton(0, child_offset, child_offset)
		svo.set_subgrid(child_offset, 0)
	svo.set_morton(1, 0, 0)
	_fill_link_arrays_with_null(svo)
	var root_link: int = SvoLink64.singleton.create(1, 0)
	for child_offset in range(8):
		svo.set_parent(0, child_offset, root_link)
	svo.set_first_child(1, 0, SvoLink64.singleton.create(0, 0))
	if seed_distinct_faces:
		_seed_distinct_face_array_values(svo)
	return svo


func _create_head_offset_fixture() -> SVO:
	var svo := SVO.new()
	svo.set_layer_count(2)
	svo.set_node_count_in_layer(0, 4)
	svo.set_node_count_in_layer(1, 1)
	svo.subgrid.resize(4)
	for offset in range(4):
		svo.set_morton(0, offset, offset)
		svo.set_subgrid(offset, 0)
	svo.set_morton(1, 0, 0)
	_fill_link_arrays_with_null(svo)
	svo.set_xn_neighbor(0, 2, SvoLink64.singleton.create(1, 0))
	return svo


func _bitmask_from_subgrids(positions: Array[Vector3i]) -> int:
	var bitmask: int = 0
	for position in positions:
		bitmask |= 1 << Morton3.encode64v(position)
	return bitmask


func _fill_link_arrays_with_null(svo: SVO) -> void:
	for layer in range(svo.depth):
		for offset in range(svo.get_node_count_in_layer(layer)):
			svo.set_parent(layer, offset, SvoLink64.singleton.null_link())
			svo.set_first_child(layer, offset, SvoLink64.singleton.null_link())
			svo.set_xp_neighbor(layer, offset, SvoLink64.singleton.null_link())
			svo.set_yp_neighbor(layer, offset, SvoLink64.singleton.null_link())
			svo.set_zp_neighbor(layer, offset, SvoLink64.singleton.null_link())
			svo.set_xn_neighbor(layer, offset, SvoLink64.singleton.null_link())
			svo.set_yn_neighbor(layer, offset, SvoLink64.singleton.null_link())
			svo.set_zn_neighbor(layer, offset, SvoLink64.singleton.null_link())


func _seed_distinct_face_array_values(svo: SVO) -> void:
	for layer in range(svo.depth):
		var xp_layer: PackedInt64Array = svo.xp[layer]
		var xn_layer: PackedInt64Array = svo.xn[layer]
		var yp_layer: PackedInt64Array = svo.yp[layer]
		var yn_layer: PackedInt64Array = svo.yn[layer]
		var zp_layer: PackedInt64Array = svo.zp[layer]
		var zn_layer: PackedInt64Array = svo.zn[layer]
		for offset in range(svo.get_node_count_in_layer(layer)):
			xp_layer[offset] = 1000 + layer * 100 + offset
			xn_layer[offset] = 2000 + layer * 100 + offset
			yp_layer[offset] = 3000 + layer * 100 + offset
			yn_layer[offset] = 4000 + layer * 100 + offset
			zp_layer[offset] = 5000 + layer * 100 + offset
			zn_layer[offset] = 6000 + layer * 100 + offset
		svo.xp[layer] = xp_layer
		svo.xn[layer] = xn_layer
		svo.yp[layer] = yp_layer
		svo.yn[layer] = yn_layer
		svo.zp[layer] = zp_layer
		svo.zn[layer] = zn_layer


func _set_inside_value(svo: SVO, layer: int, offset: int, value: int) -> void:
	var inside_layer: PackedByteArray = svo.inside[layer]
	inside_layer[offset] = value
	svo.inside[layer] = inside_layer


func _assert_vector3_almost_eq(actual: Vector3, expected: Vector3, message: String) -> void:
	assert_almost_eq(actual.x, expected.x, FLOAT_TOLERANCE, "%s (x)" % message)
	assert_almost_eq(actual.y, expected.y, FLOAT_TOLERANCE, "%s (y)" % message)
	assert_almost_eq(actual.z, expected.z, FLOAT_TOLERANCE, "%s (z)" % message)
