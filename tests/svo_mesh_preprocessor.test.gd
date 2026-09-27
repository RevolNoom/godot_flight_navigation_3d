extends GutTest

class_name SvoMeshPreprocessorTest


func test_is_non_zero_area_triangle_rejects_degenerate_triangles() -> void:
	var degenerate_identical := PackedVector3Array([
		Vector3(1, 1, 1),
		Vector3(1, 1, 1),
		Vector3(2, 2, 2)
	])
	assert_false(SvoMeshPreprocessor._parallel_is_non_zero_area_triangle(0, degenerate_identical))

	var valid_triangle := PackedVector3Array([
		Vector3(0, 0, 0),
		Vector3(1, 0, 0),
		Vector3(0, 1, 0)
	])
	assert_true(SvoMeshPreprocessor._parallel_is_non_zero_area_triangle(0, valid_triangle))


func test_filter_voxelization_targets_filters_by_mask() -> void:
	var target1 := VoxelizationTarget.new()
	target1.voxelization_mask = 1
	var target2 := VoxelizationTarget.new()
	target2.voxelization_mask = 2
	var targets: Array[VoxelizationTarget] = [target1, target2]

	var preprocessor := SvoMeshPreprocessor.new()
	preprocessor.filter_voxelization_targets(targets, 1)

	assert_eq(targets.size(), 1)
	assert_eq(targets[0], target1)
	target1.free()
	target2.free()


func test_filter_thin_triangles_removes_zero_area_faces() -> void:
	var mixed_triangles := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), # Valid
		Vector3(0, 0, 0), Vector3(0, 0, 0), Vector3(1, 1, 1), # Degenerate
		Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), # Valid
	])
	var preprocessor := SvoMeshPreprocessor.new()
	var cleaned := await preprocessor.filter_thin_triangles(
		mixed_triangles,
		get_tree().process_frame,
		false,
		Thread.PRIORITY_LOW
	)

	assert_eq(cleaned.size(), 6)
	assert_eq(cleaned[0], Vector3(0, 0, 0))
	assert_eq(cleaned[1], Vector3(1, 0, 0))
	assert_eq(cleaned[2], Vector3(0, 1, 0))
	assert_eq(cleaned[3], Vector3(0, 0, 1))
	assert_eq(cleaned[4], Vector3(1, 0, 1))
	assert_eq(cleaned[5], Vector3(0, 1, 1))
