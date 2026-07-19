extends GutTest


const FACE_COMPONENT_BY_NAME: Dictionary = {
	&"xn": Vector3i(0, -1, -1),
	&"xp": Vector3i(3, -1, -1),
	&"yn": Vector3i(-1, 0, -1),
	&"yp": Vector3i(-1, 3, -1),
	&"zn": Vector3i(-1, -1, 0),
	&"zp": Vector3i(-1, -1, 3),
}


func test_lookup_dictionaries_are_read_only_after_static_initialization() -> void:
	assert_true(Fn3dLookupTable.subgrid_voxel_indexes_on_face.is_read_only())
	assert_true(Fn3dLookupTable.children_node_by_face.is_read_only())
	assert_true(Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index.is_read_only())


func test_bit_1_count_lookup_matches_popcount_for_representative_values() -> void:
	var lookup := Fn3dLookupTable.bit_1_count_by_u8
	var representative_values: PackedInt32Array = PackedInt32Array([0, 1, 3, 15, 16, 85, 170, 255])

	assert_eq(lookup.size(), 256)
	for value in representative_values:
		assert_eq(lookup[value], Fn3dUtility.count_bit_1(value), "Unexpected popcount for %d" % value)


func test_children_node_by_face_encodes_expected_octants() -> void:
	for face_name in FACE_COMPONENT_BY_NAME.keys():
		var component_constraint: Vector3i = FACE_COMPONENT_BY_NAME[face_name]
		var children: PackedInt64Array = Fn3dLookupTable.children_node_by_face[face_name]

		assert_eq(children.size(), 4, "%s should reference exactly four octants" % face_name)
		for child_link in children:
			var child_octant: Vector3i = Morton3.decode_vec3i(child_link >> 6)
			if component_constraint.x >= 0:
				assert_eq(child_octant.x, component_constraint.x / 3, "%s should constrain x octant" % face_name)
			if component_constraint.y >= 0:
				assert_eq(child_octant.y, component_constraint.y / 3, "%s should constrain y octant" % face_name)
			if component_constraint.z >= 0:
				assert_eq(child_octant.z, component_constraint.z / 3, "%s should constrain z octant" % face_name)


func test_xp_face_bitmask_expands_to_the_same_indexes_as_the_face_lookup() -> void:
	var expanded_indexes := _expand_bitmask(Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp)

	assert_eq(expanded_indexes, Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"])


func test_neighbor_node_x_column_lookup_covers_full_columns_for_each_boundary_voxel() -> void:
	var neighbor_lookup := Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index

	assert_eq(neighbor_lookup.size(), 16)
	for source_subgrid in neighbor_lookup.keys():
		var source_position: Vector3i = Morton3.decode_vec3i(source_subgrid)
		var column_indexes: PackedInt32Array = _expand_bitmask(neighbor_lookup[source_subgrid])

		assert_eq(source_position.x, 3, "Only +X boundary voxels should be represented")
		assert_eq(column_indexes.size(), 4)
		for column_index in column_indexes:
			var column_position: Vector3i = Morton3.decode_vec3i(column_index)
			assert_eq(column_position.y, source_position.y)
			assert_eq(column_position.z, source_position.z)


func _expand_bitmask(bitmask: int) -> PackedInt32Array:
	var indexes: PackedInt32Array = []
	for index in range(64):
		if bitmask & (1 << index):
			indexes.push_back(index)
	return indexes
