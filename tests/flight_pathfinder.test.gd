extends GutTest


class StubPathfinder:
	extends FlightPathfinder

	var received_from: int = SvoLink64.singleton.null_link()
	var received_to: int = SvoLink64.singleton.null_link()
	var received_svo: SVO = null
	var returned_path: PackedInt64Array = PackedInt64Array()

	func _init(path: PackedInt64Array = PackedInt64Array()) -> void:
		returned_path = path

	func _find_path(from: int, to: int, svo: SVO) -> PackedInt64Array:
		received_from = from
		received_to = to
		received_svo = svo
		return returned_path


const FLOAT_TOLERANCE: float = 0.000001


func test_find_path_dispatches_to_overridden_implementation() -> void:
	var expected_path := PackedInt64Array([
		SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(1, 1, 1))),
		SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(2, 1, 1))),
	])
	var pathfinder := StubPathfinder.new(expected_path)
	var svo := _create_single_leaf_svo()
	var start_link: int = expected_path[0]
	var goal_link: int = expected_path[1]

	var result: PackedInt64Array = pathfinder.find_path(start_link, goal_link, svo)

	assert_eq(result, expected_path)
	assert_eq(pathfinder.received_from, start_link)
	assert_eq(pathfinder.received_to, goal_link)
	assert_same(pathfinder.received_svo, svo)


func test_default_compute_and_estimate_cost_use_euclidean_distance_between_centers() -> void:
	var pathfinder := StubPathfinder.new()
	var svo := _create_single_leaf_svo()
	var start_link: int = SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(0, 0, 0)))
	var goal_link: int = SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(3, 3, 0)))
	var expected_cost: float = sqrt(18.0)

	assert_almost_eq(pathfinder.compute_cost(start_link, goal_link, svo), expected_cost, FLOAT_TOLERANCE)
	assert_almost_eq(pathfinder.estimate_cost(start_link, goal_link, svo), expected_cost, FLOAT_TOLERANCE)


func test_compute_size_compensation_factor_matches_formula_and_favors_larger_nodes() -> void:
	var pathfinder := StubPathfinder.new()
	var root_factor: float = pathfinder.compute_size_compensation_factor(3, 5)
	var leaf_factor: float = pathfinder.compute_size_compensation_factor(0, 5)

	assert_almost_eq(root_factor, 2.0 / 7.0, FLOAT_TOLERANCE)
	assert_almost_eq(leaf_factor, 5.0 / 7.0, FLOAT_TOLERANCE)
	assert_lt(root_factor, leaf_factor, "Higher-layer nodes should get a lower travel cost factor")


func test_distance_helpers_match_expected_metrics() -> void:
	var from := Vector3(1.0, 2.0, 3.0)
	var to := Vector3(4.0, -2.0, 5.0)

	assert_almost_eq(FlightPathfinder.euclidean(from, to), sqrt(29.0), FLOAT_TOLERANCE)
	assert_almost_eq(FlightPathfinder.manhattan(from, to), 9.0, FLOAT_TOLERANCE)


func test_get_centers_and_closest_faces_fallback_return_node_centers() -> void:
	var svo := _create_single_leaf_svo()
	var start_link: int = SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(0, 1, 2)))
	var goal_link: int = SvoLink64.singleton.create(0, 0, Morton3.encode64v(Vector3i(3, 2, 1)))
	var expected_centers := PackedVector3Array([
		svo.get_center(start_link),
		svo.get_center(goal_link),
	])

	assert_eq(FlightPathfinder.get_centers(start_link, goal_link, svo), expected_centers)
	assert_eq(FlightPathfinder.get_closest_faces(start_link, goal_link, svo), expected_centers)
	assert_engine_error("not implemented yet")


func _create_single_leaf_svo() -> SVO:
	var svo := SVO.new()
	svo.set_layer_count(1)
	svo.set_node_count_in_layer(0, 1)
	svo.set_morton(0, 0, 0)
	svo.subgrid.resize(1)
	svo.set_subgrid(0, 0)
	_fill_link_arrays_with_null(svo)
	return svo


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
