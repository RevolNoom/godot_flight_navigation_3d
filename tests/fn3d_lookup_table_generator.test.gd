extends GutTest

class_name Fn3dLookupTableGeneratorTest


const FACE_COMPONENT_BY_NAME: Dictionary = {
	&"xn": Vector3i(0, -1, -1),
	&"xp": Vector3i(3, -1, -1),
	&"yn": Vector3i(-1, 0, -1),
	&"yp": Vector3i(-1, 3, -1),
	&"zn": Vector3i(-1, -1, 0),
	&"zp": Vector3i(-1, -1, 3),
}


func test_generate_lut_bit_1_count_by_u8() -> void:
	var expected: PackedInt32Array = Fn3dLookupTable.bit_1_count_by_u8
	var result: PackedInt32Array = \
		Fn3dLookupTableGenerator.generate_lut_bit_1_count_by_u8()
	assert_eq(result, expected)


func test_generate_lut_bit_1_count_by_u8_invariants() -> void:
	var result: PackedInt32Array = Fn3dLookupTableGenerator.generate_lut_bit_1_count_by_u8()

	assert_eq(result.size(), 256)
	for value in range(result.size()):
		assert_gte(result[value], 0, "Bit count should never be negative")
		assert_lte(result[value], 8, "Bit count should stay within u8 width")
		assert_eq(result[value], Fn3dUtility.count_bit_1(value), "Unexpected count for %d" % value)


func test_generate_lut_subgrid_voxel_indexes_on_face() -> void:
	var expected: Dictionary[StringName, PackedInt32Array] = \
		Fn3dLookupTable.subgrid_voxel_indexes_on_face
	var result: Dictionary[StringName, PackedInt32Array] = \
		Fn3dLookupTableGenerator.generate_lut_subgrid_voxel_indexes_on_face()
	assert_eq(result, expected)


func test_generate_lut_subgrid_voxel_indexes_on_face_match_requested_constraints() -> void:
	var result: Dictionary[StringName, PackedInt32Array] = \
		Fn3dLookupTableGenerator.generate_lut_subgrid_voxel_indexes_on_face()

	for face_name in FACE_COMPONENT_BY_NAME.keys():
		var indexes: PackedInt32Array = result[face_name]
		var component_constraint: Vector3i = FACE_COMPONENT_BY_NAME[face_name]
		var seen_indexes: Dictionary = {}

		assert_eq(indexes.size(), 16, "%s should contain one 4x4 face worth of voxels" % face_name)
		for voxel_index in indexes:
			assert_gte(voxel_index, 0, "%s index should be non-negative" % face_name)
			assert_lte(voxel_index, 63, "%s index should fit within a subgrid" % face_name)
			assert_false(seen_indexes.has(voxel_index), "%s should not contain duplicate indexes" % face_name)
			seen_indexes[voxel_index] = true

			var decoded_position: Vector3i = Morton3.decode_vec3i(voxel_index)
			if component_constraint.x >= 0:
				assert_eq(decoded_position.x, component_constraint.x, "%s should constrain x" % face_name)
			if component_constraint.y >= 0:
				assert_eq(decoded_position.y, component_constraint.y, "%s should constrain y" % face_name)
			if component_constraint.z >= 0:
				assert_eq(decoded_position.z, component_constraint.z, "%s should constrain z" % face_name)


func test_generate_lut_children_node_by_face() -> void:
	var expected: Dictionary[StringName, PackedInt64Array] = \
		Fn3dLookupTable.children_node_by_face
	var result: Dictionary[StringName, PackedInt64Array] = \
		Fn3dLookupTableGenerator.generate_lut_children_node_by_face()
	assert_eq(result, expected)


func test_generate_lut_children_node_by_face_stays_within_child_offset_field() -> void:
	var result: Dictionary[StringName, PackedInt64Array] = \
		Fn3dLookupTableGenerator.generate_lut_children_node_by_face()
	var subgrid_mask: int = SvoLink64.singleton.get_subgrid_mask()

	for face_name in result.keys():
		var child_links: PackedInt64Array = result[face_name]
		var seen_offsets: Dictionary = {}

		assert_eq(child_links.size(), 4, "%s should reference exactly 4 children" % face_name)
		for child_link in child_links:
			assert_eq(child_link & subgrid_mask, 0, "%s should only use the packed offset field" % face_name)
			var child_offset: int = child_link >> 6
			assert_gte(child_offset, 0, "%s child offset should be non-negative" % face_name)
			assert_lte(child_offset, 7, "%s child offset should fit in an octant" % face_name)
			assert_false(seen_offsets.has(child_offset), "%s should not repeat child offsets" % face_name)
			seen_offsets[child_offset] = true


func test_generate_x_column_flip_bitmask_by_subgrid_index() -> void:
	var expected: PackedInt64Array = \
		Fn3dLookupTable.x_column_flip_bitmask_by_subgrid_index
	var result: PackedInt64Array = \
		Fn3dLookupTableGenerator.generate_x_column_flip_bitmask_by_subgrid_index()
	assert_eq(result, expected)


func test_generate_x_column_flip_bitmask_by_subgrid_index_respects_remaining_x_column() -> void:
	var result: PackedInt64Array = Fn3dLookupTableGenerator.generate_x_column_flip_bitmask_by_subgrid_index()

	assert_eq(result.size(), 64)
	for subgrid_index in range(result.size()):
		var source_position: Vector3i = Morton3.decode_vec3i(subgrid_index)
		var indexes_in_column: PackedInt32Array = _expand_bitmask(result[subgrid_index])

		assert_eq(indexes_in_column.size(), 4 - source_position.x)
		assert_has(indexes_in_column, subgrid_index, "Bitmask should include its source voxel")
		for flipped_index in indexes_in_column:
			var flipped_position: Vector3i = Morton3.decode_vec3i(flipped_index)
			assert_eq(flipped_position.y, source_position.y, "Y should remain unchanged along an x-column")
			assert_eq(flipped_position.z, source_position.z, "Z should remain unchanged along an x-column")
			assert_gte(flipped_position.x, source_position.x, "X should only extend toward the positive direction")


func test_bitmask_of_subgrid_voxels_on_face_xp() -> void:
	var expected: int = Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp
	var list_subgrid_index: PackedInt32Array = \
		Fn3dLookupTableGenerator._get_subgrid_voxel_indexes_where_component_equals(
			Vector3i(3, -1, -1))
	var result: int = Fn3dLookupTableGenerator.\
			_compress_subgrid_indexes_into_bitmask(
				list_subgrid_index)
	assert_eq(result, expected)


func test_generate_lut_neighbor_node_x_column_bits_by_subgrid_index() -> void:
	var expected: Dictionary[int, int] = \
		Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index
	var result: Dictionary[int, int] = \
		Fn3dLookupTableGenerator.\
			generate_lut_neighbor_node_x_column_bits_by_subgrid_index()
	assert_eq(result, expected)


func test_generate_lut_neighbor_node_x_column_bits_by_subgrid_index_match_boundary_columns() -> void:
	var result: Dictionary[int, int] = \
		Fn3dLookupTableGenerator.generate_lut_neighbor_node_x_column_bits_by_subgrid_index()

	assert_eq(result.size(), 16)
	for key in result.keys():
		var boundary_position: Vector3i = Morton3.decode_vec3i(key)
		var boundary_indexes: PackedInt32Array = _expand_bitmask(result[key])
		var seen_x_values: Dictionary = {}

		assert_eq(boundary_position.x, 3, "Only +X boundary voxels should appear as keys")
		assert_eq(boundary_indexes.size(), 4, "Each boundary key should map to a full x-column")
		for boundary_index in boundary_indexes:
			var decoded_position: Vector3i = Morton3.decode_vec3i(boundary_index)
			assert_eq(decoded_position.y, boundary_position.y, "Neighbor column should preserve y")
			assert_eq(decoded_position.z, boundary_position.z, "Neighbor column should preserve z")
			assert_gte(decoded_position.x, 0, "Neighbor column x should stay inside the subgrid")
			assert_lte(decoded_position.x, 3, "Neighbor column x should stay inside the subgrid")
			seen_x_values[decoded_position.x] = true
		for expected_x in range(4):
			assert_true(seen_x_values.has(expected_x), "Neighbor column should cover every x coordinate")


func _expand_bitmask(bitmask: int) -> PackedInt32Array:
	var indexes: PackedInt32Array = []
	for index in range(64):
		if bitmask & (1 << index):
			indexes.push_back(index)
	return indexes
