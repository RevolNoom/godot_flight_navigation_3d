extends GutTest


class ProjectionStub:
	extends ATriangleBoxOverlapCheck

	var plane_result: bool = true
	var xy_result: bool = true
	var yz_result: bool = true
	var zx_result: bool = true

	func _init(plane_value: bool, xy_value: bool, yz_value: bool, zx_value: bool) -> void:
		plane_result = plane_value
		xy_result = xy_value
		yz_result = yz_value
		zx_result = zx_value

	func plane_overlaps(_minimum_corner: Vector3) -> bool:
		return plane_result

	func projection_xy_overlaps(_minimum_corner: Vector3) -> bool:
		return xy_result

	func projection_yz_overlaps(_minimum_corner: Vector3) -> bool:
		return yz_result

	func projection_zx_overlaps(_minimum_corner: Vector3) -> bool:
		return zx_result


const EPSILON: float = 0.000001


func test_interface_overlap_voxel_requires_every_projection_to_pass() -> void:
	assert_true(ProjectionStub.new(true, true, true, true).overlap_voxel(Vector3.ZERO))
	assert_false(ProjectionStub.new(false, true, true, true).overlap_voxel(Vector3.ZERO))
	assert_false(ProjectionStub.new(true, false, true, true).overlap_voxel(Vector3.ZERO))
	assert_false(ProjectionStub.new(true, true, false, true).overlap_voxel(Vector3.ZERO))
	assert_false(ProjectionStub.new(true, true, true, false).overlap_voxel(Vector3.ZERO))


func test_direct_overlap_implementations_agree_on_overlapping_and_separated_voxels() -> void:
	for separability in [
		Separability.Enum.SEPARATING_6,
		Separability.Enum.SEPARATING_26,
	]:
		var checkers: Array[ATriangleBoxOverlapCheck] = [
			TriangleBoxOverlapCheckF32.new(
				Vector3(1, 0, 0),
				Vector3(0, 1, 0),
				Vector3(0, 0, 1),
				Vector3.ONE,
				separability,
				EPSILON
			),
			TriangleBoxOverlapCheckF64.new(
				Vector3(1, 0, 0),
				Vector3(0, 1, 0),
				Vector3(0, 0, 1),
				Vector3.ONE,
				separability,
				EPSILON
			),
		]

		for checker in checkers:
			assert_true(checker.overlap_voxel(Vector3.ZERO), "Unit cube at the origin should intersect the triangle")
			assert_false(checker.overlap_voxel(Vector3(2, 2, 2)), "Far-away cube should be rejected")


func test_plane_projection_helpers_return_points_on_shared_plane_for_both_precisions() -> void:
	var checkers: Array[ATriangleBoxOverlapCheck] = [
		TriangleBoxOverlapCheckF32.new(
			Vector3(1, 0, 0),
			Vector3(0, 1, 0),
			Vector3(0, 0, 1),
			Vector3.ONE,
			Separability.Enum.SEPARATING_26,
			EPSILON
		),
		TriangleBoxOverlapCheckF64.new(
			Vector3(1, 0, 0),
			Vector3(0, 1, 0),
			Vector3(0, 0, 1),
			Vector3.ONE,
			Separability.Enum.SEPARATING_26,
			EPSILON
		),
	]

	for checker in checkers:
		assert_almost_eq(checker.x_projection_on_plane(0.25, 0.25), 0.5, EPSILON)
		assert_almost_eq(checker.y_projection_on_plane(0.25, 0.25), 0.5, EPSILON)
		assert_almost_eq(checker.z_projection_on_plane(0.25, 0.25), 0.5, EPSILON)


func test_factories_create_expected_checker_types_with_observable_equivalent_behavior() -> void:
	var factory_f32 := FactoryTriangleBoxOverlapCheckF32.new()
	var factory_f64 := FactoryTriangleBoxOverlapCheckF64.new()
	var checker_f32 := factory_f32.create(
		Vector3(1, 0, 0),
		Vector3(0, 1, 0),
		Vector3(0, 0, 1),
		Vector3.ONE,
		Separability.Enum.SEPARATING_26,
		EPSILON
	)
	var checker_f64 := factory_f64.create(
		Vector3(1, 0, 0),
		Vector3(0, 1, 0),
		Vector3(0, 0, 1),
		Vector3.ONE,
		Separability.Enum.SEPARATING_26,
		EPSILON
	)

	assert_true(checker_f32 is TriangleBoxOverlapCheckF32)
	assert_true(checker_f64 is TriangleBoxOverlapCheckF64)
	assert_true(checker_f32.overlap_voxel(Vector3.ZERO))
	assert_true(checker_f64.overlap_voxel(Vector3.ZERO))
	assert_false(checker_f32.overlap_voxel(Vector3(2, 2, 2)))
	assert_false(checker_f64.overlap_voxel(Vector3(2, 2, 2)))
