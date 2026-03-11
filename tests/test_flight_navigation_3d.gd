extends GutTest

class_name FlightNavigation3DTest


class RecordingPathfinder:
	extends FlightPathfinder

	var next_path: PackedInt64Array = []
	var last_from: int = SvoLink64.singleton.null_link()
	var last_to: int = SvoLink64.singleton.null_link()
	var last_svo: SVO = null

	func _init(path: PackedInt64Array = []) -> void:
		next_path = path

	func _find_path(from: int, to: int, svo: SVO) -> PackedInt64Array:
		last_from = from
		last_to = to
		last_svo = svo
		return next_path


class StubVoxelizer:
	extends ISvoVoxelizer

	var built_svo: SVO

	func _init(svo: SVO) -> void:
		built_svo = svo

	func voxelize(_fn3d: FlightNavigation3D) -> SVO:
		return built_svo


const TEST_NAVIGATION_SIZE: Vector3 = Vector3(4.0, 4.0, 4.0)
const FLOAT_TOLERANCE: float = 0.000001

var _navigation: FlightNavigation3D


func before_each() -> void:
	_navigation = FlightNavigation3D.new()
	_navigation.size = TEST_NAVIGATION_SIZE
	add_child(_navigation)


func after_each() -> void:
	if is_instance_valid(_navigation):
		_navigation.queue_free()
	_navigation = null


func test_build_navigation_assigns_result_from_single_voxelizer_child() -> void:
	var expected_svo: SVO = _create_single_leaf_svo()
	var voxelizer: StubVoxelizer = StubVoxelizer.new(expected_svo)
	_navigation.add_child(voxelizer)

	await _navigation.build_navigation()

	assert_same(_navigation.sparse_voxel_octree, expected_svo)


func test_find_path_returns_empty_when_sparse_voxel_octree_is_missing() -> void:
	_navigation.pathfinder = RecordingPathfinder.new()

	var result: PackedVector3Array = _navigation.find_path(Vector3.ZERO, Vector3.ONE)

	assert_true(result.is_empty())


func test_find_path_returns_empty_when_pathfinder_is_missing() -> void:
	_navigation.sparse_voxel_octree = _create_single_leaf_svo()

	var result: PackedVector3Array = _navigation.find_path(Vector3.ZERO, Vector3.ONE)

	assert_true(result.is_empty())


func test_find_path_smoke_converts_query_positions_and_result_links() -> void:
	var svo: SVO = _create_single_leaf_svo()
	var start_link: int = _create_leaf_link(Vector3i(0, 1, 2))
	var destination_link: int = _create_leaf_link(Vector3i(3, 2, 1))
	var pathfinder: RecordingPathfinder = RecordingPathfinder.new(
		PackedInt64Array([start_link, destination_link])
	)
	_navigation.sparse_voxel_octree = svo
	_navigation.pathfinder = pathfinder

	var from_position: Vector3 = _navigation.get_global_position_of(start_link)
	var to_position: Vector3 = _navigation.get_global_position_of(destination_link)
	var result: PackedVector3Array = _navigation.find_path(from_position, to_position)

	assert_eq(pathfinder.last_from, start_link)
	assert_eq(pathfinder.last_to, destination_link)
	assert_same(pathfinder.last_svo, svo)
	assert_eq(result.size(), 2)
	_assert_vector3_almost_eq(result[0], from_position, "Path start should match query center")
	_assert_vector3_almost_eq(result[1], to_position, "Path destination should match query center")


func test_find_path_returns_empty_when_start_voxel_is_solid() -> void:
	var blocked_subgrid := Vector3i(0, 1, 2)
	var destination_subgrid := Vector3i(3, 2, 1)
	var blocked_link: int = _create_leaf_link(blocked_subgrid)
	var destination_link: int = _create_leaf_link(destination_subgrid)
	var pathfinder: RecordingPathfinder = RecordingPathfinder.new([blocked_link, destination_link])
	_navigation.sparse_voxel_octree = _create_single_leaf_svo([blocked_subgrid])
	_navigation.pathfinder = pathfinder

	var result: PackedVector3Array = _navigation.find_path(
		_navigation.get_global_position_of(blocked_link),
		_navigation.get_global_position_of(destination_link)
	)

	assert_true(result.is_empty())
	assert_eq(pathfinder.last_from, SvoLink64.singleton.null_link())
	assert_eq(pathfinder.last_to, SvoLink64.singleton.null_link())


func test_find_path_returns_empty_when_goal_voxel_is_solid() -> void:
	var start_subgrid := Vector3i(0, 1, 2)
	var blocked_subgrid := Vector3i(3, 2, 1)
	var start_link: int = _create_leaf_link(start_subgrid)
	var blocked_link: int = _create_leaf_link(blocked_subgrid)
	var pathfinder: RecordingPathfinder = RecordingPathfinder.new([start_link, blocked_link])
	_navigation.sparse_voxel_octree = _create_single_leaf_svo([blocked_subgrid])
	_navigation.pathfinder = pathfinder

	var result: PackedVector3Array = _navigation.find_path(
		_navigation.get_global_position_of(start_link),
		_navigation.get_global_position_of(blocked_link)
	)

	assert_true(result.is_empty())
	assert_eq(pathfinder.last_from, SvoLink64.singleton.null_link())
	assert_eq(pathfinder.last_to, SvoLink64.singleton.null_link())


func test_layer_zero_centers_round_trip_through_global_conversion() -> void:
	_navigation.sparse_voxel_octree = _create_single_leaf_svo()
	var subgrid_positions: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(3, 0, 2),
		Vector3i(1, 3, 3),
		Vector3i(2, 2, 1),
	]

	for subgrid_position in subgrid_positions:
		var source_link: int = _create_leaf_link(subgrid_position)
		var center_position: Vector3 = _navigation.get_global_position_of(source_link)
		var round_trip_link: int = _navigation.get_svolink_of(center_position)
		var round_trip_position: Vector3 = _navigation.get_global_position_of(round_trip_link)

		assert_eq(
			round_trip_link,
			source_link,
			"Round-trip link mismatch for subgrid %s" % [subgrid_position]
		)
		_assert_vector3_almost_eq(
			round_trip_position,
			center_position,
			"Round-trip center mismatch for subgrid %s" % [subgrid_position]
		)


func _create_single_leaf_svo(solid_subgrids: Array[Vector3i] = []) -> SVO:
	var svo: SVO = SVO.new()
	svo.set_layer_count(1)
	svo.set_node_count_in_layer(0, 1)
	svo.set_morton(0, 0, 0)
	svo.set_first_child(0, 0, SvoLink64.singleton.null_link())
	svo.set_parent(0, 0, SvoLink64.singleton.null_link())
	svo.subgrid.resize(1)
	var solid_bitmask: int = 0
	for subgrid_position in solid_subgrids:
		solid_bitmask |= 1 << Morton3.encode64v(subgrid_position)
	svo.subgrid[0] = solid_bitmask
	return svo


func _create_leaf_link(subgrid_position: Vector3i) -> int:
	return SvoLink64.singleton.create(0, 0, Morton3.encode64v(subgrid_position))


func _assert_vector3_almost_eq(actual: Vector3, expected: Vector3, message: String) -> void:
	assert_almost_eq(actual.x, expected.x, FLOAT_TOLERANCE, "%s (x)" % message)
	assert_almost_eq(actual.y, expected.y, FLOAT_TOLERANCE, "%s (y)" % message)
	assert_almost_eq(actual.z, expected.z, FLOAT_TOLERANCE, "%s (z)" % message)
