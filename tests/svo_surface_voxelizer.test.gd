extends GutTest

class_name SvoSurfaceVoxelizerTest


func test_calculate_triangle_aabb() -> void:
	var v0 := Vector3(1, 2, 3)
	var v1 := Vector3(4, 0, -1)
	var v2 := Vector3(-2, 5, 2)

	var aabb: AABB = SvoSurfaceVoxelizer.calculate_triangle_aabb(v0, v1, v2)

	assert_eq(aabb.position, Vector3(-2, 0, -1))
	assert_eq(aabb.end, Vector3(4, 5, 3))


func test_voxels_overlapped_by_aabb() -> void:
	var voxel_size := Vector3(1.0, 1.0, 1.0)
	var aabb := AABB(Vector3(0.5, 0.5, 0.5), Vector3(1.0, 1.0, 1.0))
	var grid_size := Vector3(10.0, 10.0, 10.0)

	var voxel_range: Array[Vector3i] = SvoSurfaceVoxelizer.voxels_overlapped_by_aabb(
		voxel_size,
		aabb,
		grid_size
	)

	assert_eq(voxel_range.size(), 2)
	assert_true(voxel_range[0].x <= voxel_range[1].x)
	assert_true(voxel_range[0].y <= voxel_range[1].y)
	assert_true(voxel_range[0].z <= voxel_range[1].z)


func test_get_node_1_overlap_triangle_count_array() -> void:
	# Pairs of Vector4i with morton encoded in [0],[1]
	# Morton code 10 appearing twice, Morton code 20 appearing once
	var pairs: Array[Vector4i] = [
		Vector4i(0, 10, 0, 1),
		Vector4i(0, 10, 0, 2),
		Vector4i(0, 20, 0, 3)
	]
	var unique_morton_count := 2

	var counts: PackedInt64Array = SvoSurfaceVoxelizer.get_node_1_overlap_triangle_count_array(
		pairs,
		unique_morton_count
	)

	assert_eq(counts.size(), 2)
	assert_eq(counts[0], 2)
	assert_eq(counts[1], 1)
