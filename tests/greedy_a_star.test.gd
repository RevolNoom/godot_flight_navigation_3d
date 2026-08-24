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
