extends GutTest


func test_endpoints_rejects_face_centers_and_normalizes_to_voxel_centers() -> void:
	var pathfinder := GreedyAStar.new()

	pathfinder.endpoints = "Face Centers"

	assert_eq(pathfinder.endpoints, "Voxel Centers")


func test_distance_function_normalizes_invalid_values_and_keeps_supported_ones() -> void:
	var pathfinder := GreedyAStar.new()

	pathfinder.distance_function = "Manhattan"
	assert_eq(pathfinder.distance_function, "Manhattan")

	pathfinder.distance_function = "Not A Real Distance"
	assert_eq(pathfinder.distance_function, "Euclidean")


func test_find_path_returns_empty_when_start_or_destination_is_null_link() -> void:
	var pathfinder := GreedyAStar.new()
	var svo := SVO.new()
	var null_link: int = SvoLink64.singleton.null_link()
	var valid_link: int = SvoLink64.singleton.create(0, 0, 0)

	assert_eq(pathfinder.find_path(null_link, valid_link, svo), PackedInt64Array())
	assert_eq(pathfinder.find_path(valid_link, null_link, svo), PackedInt64Array())


func test_find_path_connects_adjacent_voxels() -> void:
	var pathfinder := GreedyAStar.new()
	var svo := SVO.new()
	svo.set_layer_count(1)
	svo.set_node_count_in_layer(0, 1)
	svo.set_morton(0, 0, 0)
	svo.subgrid.resize(1)
	svo.set_subgrid(0, 0)
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

	var start_link: int = SvoLink64.singleton.create(0, 0, Morton3.encode64(1, 1, 1))
	var goal_link: int = SvoLink64.singleton.create(0, 0, Morton3.encode64(2, 1, 1))
	var path: PackedInt64Array = pathfinder.find_path(start_link, goal_link, svo)

	assert_eq(path.size(), 2)
	assert_eq(path[0], start_link)
	assert_eq(path[1], goal_link)
