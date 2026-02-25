extends GutTest

class_name Fn3dLookupTableGeneratorTest


func test_generate_lut_bit_1_count_by_u8():
	var expected: PackedInt32Array = Fn3dLookupTable.bit_1_count_by_u8
	var result: PackedInt32Array = \
		Fn3dLookupTableGenerator.generate_lut_bit_1_count_by_u8()
	assert_eq(result, expected)


func test_generate_lut_subgrid_voxel_indexes_on_face():
	var expected: Dictionary[StringName, PackedInt32Array] = \
		Fn3dLookupTable.subgrid_voxel_indexes_on_face
	var result: Dictionary[StringName, PackedInt32Array] = \
		Fn3dLookupTableGenerator.generate_lut_subgrid_voxel_indexes_on_face()
	assert_eq(result, expected)


func test_generate_lut_children_node_by_face():
	var expected: Dictionary[StringName, PackedInt64Array] = \
		Fn3dLookupTable.children_node_by_face
	var result: Dictionary[StringName, PackedInt64Array] = \
		Fn3dLookupTableGenerator.generate_lut_children_node_by_face()
	assert_eq(result, expected)


func test_generate_x_column_flip_bitmask_by_subgrid_index():
	var expected: PackedInt64Array = \
		Fn3dLookupTable.x_column_flip_bitmask_by_subgrid_index
	var result: PackedInt64Array = \
		Fn3dLookupTableGenerator.generate_x_column_flip_bitmask_by_subgrid_index()
	assert_eq(result, expected)


func test_bitmask_of_subgrid_voxels_on_face_xp():
	var expected: int = Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp
	var list_subgrid_index: PackedInt32Array = \
		Fn3dLookupTableGenerator._get_subgrid_voxel_indexes_where_component_equals(
			Vector3i(3, -1, -1))
	var result: int = Fn3dLookupTableGenerator.\
		_compress_subgrid_indexes_into_bitmask(
			list_subgrid_index)
	assert_eq(result, expected)


func test_generate_lut_neighbor_node_x_column_bits_by_subgrid_index():
	var expected: Dictionary[int, int] = \
		Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index
	var result: Dictionary[int, int] = \
		Fn3dLookupTableGenerator.\
			generate_lut_neighbor_node_x_column_bits_by_subgrid_index()
	assert_eq(result, expected)
