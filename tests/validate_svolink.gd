## Validate each node to see whether all neighbor/parent/children links are assigned correctly
extends Node3D

@onready var flight_nav: FlightNavigation3D = $FlightNavigation3D

func _ready():
	var result = await start()
	print(JSON.stringify(result.to_json()))

func start() -> FlightNavigation3DTestResult:
	var params = FlightNavigation3DParameter.new()
	params.depth = 3
	var svo = await flight_nav.build_navigation_data(params)
	flight_nav.sparse_voxel_octree = svo
	
	var test_result = FlightNavigation3DTestResult.new()
	
	var top_layer = params.depth-1
	var second_to_top_layer = params.depth-2
	var leaf_layer = 0
	#region SVOLink test
	# The second-to-top layer always has 8 children nodes, 
	# each points to the single parent node at top layer
	var second_to_top_layer_morton_sum = true
	var second_to_top_layer_parent_sum = true
	for i in range(8):
		second_to_top_layer_morton_sum = second_to_top_layer_morton_sum and svo.morton[second_to_top_layer][i] == i
		second_to_top_layer_parent_sum = second_to_top_layer_parent_sum and svo.parent[second_to_top_layer][i] == SVOLink.from(top_layer, 0)
	test_result.write_case("second_to_top_layer_morton_sum", second_to_top_layer_morton_sum)
	test_result.write_case("second_to_top_layer_parent_sum", second_to_top_layer_parent_sum)
	
	var second_to_top_layer_xn = {
		Morton3.encode64(0, 0, 0): svo.xn[second_to_top_layer][Morton3.encode64(0, 0, 0)] == SVOLink.NULL,
		Morton3.encode64(1, 0, 0): svo.xn[second_to_top_layer][Morton3.encode64(1, 0, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0, 0, 0)),
		Morton3.encode64(0, 1, 0): svo.xn[second_to_top_layer][Morton3.encode64(0, 1, 0)] == SVOLink.NULL,
		Morton3.encode64(1, 1, 0): svo.xn[second_to_top_layer][Morton3.encode64(1, 1, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0, 1, 0)),
		Morton3.encode64(0, 0, 1): svo.xn[second_to_top_layer][Morton3.encode64(0, 0, 1)] == SVOLink.NULL,
		Morton3.encode64(1, 0, 1): svo.xn[second_to_top_layer][Morton3.encode64(1, 0, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0, 0, 1)),
		Morton3.encode64(0, 1, 1): svo.xn[second_to_top_layer][Morton3.encode64(0, 1, 1)] == SVOLink.NULL,
		Morton3.encode64(1, 1, 1): svo.xn[second_to_top_layer][Morton3.encode64(1, 1, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0, 1, 1)),
	}
	var second_to_top_layer_xn_sum = sum_result_dictionary(second_to_top_layer_xn)
	test_result.write_case("second_to_top_layer_xn_sum", second_to_top_layer_xn_sum)
	
	var second_to_top_layer_yn = {
		Morton3.encode64(0, 0, 0): svo.yn[second_to_top_layer][Morton3.encode64(0, 0, 0)] == SVOLink.NULL,
		Morton3.encode64(1, 0, 0): svo.yn[second_to_top_layer][Morton3.encode64(1, 0, 0)] == SVOLink.NULL,
		Morton3.encode64(0, 1, 0): svo.yn[second_to_top_layer][Morton3.encode64(0, 1, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0, 0, 0)),
		Morton3.encode64(1, 1, 0): svo.yn[second_to_top_layer][Morton3.encode64(1, 1, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1, 0, 0)),
		Morton3.encode64(0, 0, 1): svo.yn[second_to_top_layer][Morton3.encode64(0, 0, 1)] == SVOLink.NULL,
		Morton3.encode64(1, 0, 1): svo.yn[second_to_top_layer][Morton3.encode64(1, 0, 1)] == SVOLink.NULL,
		Morton3.encode64(0, 1, 1): svo.yn[second_to_top_layer][Morton3.encode64(0, 1, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0, 0, 1)),
		Morton3.encode64(1, 1, 1): svo.yn[second_to_top_layer][Morton3.encode64(1, 1, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1, 0, 1)),
	}
	var second_to_top_layer_yn_sum = sum_result_dictionary(second_to_top_layer_yn)
	test_result.write_case("second_to_top_layer_yn_sum", second_to_top_layer_yn_sum)
	
	var second_to_top_layer_zn = {
		Morton3.encode64(0, 0, 0): svo.zn[second_to_top_layer][Morton3.encode64(0, 0, 0)] == SVOLink.NULL,
		Morton3.encode64(1, 0, 0): svo.zn[second_to_top_layer][Morton3.encode64(1, 0, 0)] == SVOLink.NULL,
		Morton3.encode64(0, 1, 0): svo.zn[second_to_top_layer][Morton3.encode64(0, 1, 0)] == SVOLink.NULL,
		Morton3.encode64(1, 1, 0): svo.zn[second_to_top_layer][Morton3.encode64(1, 1, 0)] == SVOLink.NULL,
		Morton3.encode64(0, 0, 1): svo.zn[second_to_top_layer][Morton3.encode64(0, 0, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0,0,0)),
		Morton3.encode64(1, 0, 1): svo.zn[second_to_top_layer][Morton3.encode64(1, 0, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1,0,0)),
		Morton3.encode64(0, 1, 1): svo.zn[second_to_top_layer][Morton3.encode64(0, 1, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0,1,0)),
		Morton3.encode64(1, 1, 1): svo.zn[second_to_top_layer][Morton3.encode64(1, 1, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1,1,0)),
	}
	var second_to_top_layer_zn_sum = sum_result_dictionary(second_to_top_layer_zn)
	test_result.write_case("second_to_top_layer_zn_sum", second_to_top_layer_zn_sum)
	
	var second_to_top_layer_xp = {
		Morton3.encode64(0, 0, 0): svo.xp[second_to_top_layer][Morton3.encode64(0, 0, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1, 0, 0)),
		Morton3.encode64(1, 0, 0): svo.xp[second_to_top_layer][Morton3.encode64(1, 0, 0)] == SVOLink.NULL,
		Morton3.encode64(0, 1, 0): svo.xp[second_to_top_layer][Morton3.encode64(0, 1, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1, 1, 0)),
		Morton3.encode64(1, 1, 0): svo.xp[second_to_top_layer][Morton3.encode64(1, 1, 0)] == SVOLink.NULL,
		Morton3.encode64(0, 0, 1): svo.xp[second_to_top_layer][Morton3.encode64(0, 0, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1, 0, 1)),
		Morton3.encode64(1, 0, 1): svo.xp[second_to_top_layer][Morton3.encode64(1, 0, 1)] == SVOLink.NULL,
		Morton3.encode64(0, 1, 1): svo.xp[second_to_top_layer][Morton3.encode64(0, 1, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1, 1, 1)),
		Morton3.encode64(1, 1, 1): svo.xp[second_to_top_layer][Morton3.encode64(1, 1, 1)] == SVOLink.NULL,
	}
	var second_to_top_layer_xp_sum = sum_result_dictionary(second_to_top_layer_xp)
	test_result.write_case("second_to_top_layer_xp_sum", second_to_top_layer_xp_sum)
	
	var second_to_top_layer_yp = {
		Morton3.encode64(0, 0, 0): svo.yp[second_to_top_layer][Morton3.encode64(0, 0, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0, 1, 0)),
		Morton3.encode64(1, 0, 0): svo.yp[second_to_top_layer][Morton3.encode64(1, 0, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1, 1, 0)),
		Morton3.encode64(0, 1, 0): svo.yp[second_to_top_layer][Morton3.encode64(0, 1, 0)] == SVOLink.NULL,
		Morton3.encode64(1, 1, 0): svo.yp[second_to_top_layer][Morton3.encode64(1, 1, 0)] == SVOLink.NULL,
		Morton3.encode64(0, 0, 1): svo.yp[second_to_top_layer][Morton3.encode64(0, 0, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0, 1, 1)),
		Morton3.encode64(1, 0, 1): svo.yp[second_to_top_layer][Morton3.encode64(1, 0, 1)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1, 1, 1)),
		Morton3.encode64(0, 1, 1): svo.yp[second_to_top_layer][Morton3.encode64(0, 1, 1)] == SVOLink.NULL,
		Morton3.encode64(1, 1, 1): svo.yp[second_to_top_layer][Morton3.encode64(1, 1, 1)] == SVOLink.NULL,
	}
	var second_to_top_layer_yp_sum = sum_result_dictionary(second_to_top_layer_yp)
	test_result.write_case("second_to_top_layer_yp_sum", second_to_top_layer_yp_sum)
	
	var second_to_top_layer_zp = {
		Morton3.encode64(0, 0, 0): svo.zp[second_to_top_layer][Morton3.encode64(0, 0, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0, 0, 1)),
		Morton3.encode64(1, 0, 0): svo.zp[second_to_top_layer][Morton3.encode64(1, 0, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1, 0, 1)),
		Morton3.encode64(0, 1, 0): svo.zp[second_to_top_layer][Morton3.encode64(0, 1, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(0, 1, 1)),
		Morton3.encode64(1, 1, 0): svo.zp[second_to_top_layer][Morton3.encode64(1, 1, 0)] == SVOLink.from(second_to_top_layer, Morton3.encode64(1, 1, 1)),
		Morton3.encode64(0, 0, 1): svo.zp[second_to_top_layer][Morton3.encode64(0, 0, 1)] == SVOLink.NULL,
		Morton3.encode64(1, 0, 1): svo.zp[second_to_top_layer][Morton3.encode64(1, 0, 1)] == SVOLink.NULL,
		Morton3.encode64(0, 1, 1): svo.zp[second_to_top_layer][Morton3.encode64(0, 1, 1)] == SVOLink.NULL,
		Morton3.encode64(1, 1, 1): svo.zp[second_to_top_layer][Morton3.encode64(1, 1, 1)] == SVOLink.NULL,
	}
	var second_to_top_layer_zp_sum = sum_result_dictionary(second_to_top_layer_zp)
	test_result.write_case("second_to_top_layer_zp_sum", second_to_top_layer_zp_sum)
	
	var second_to_top_layer_first_child = {
		Morton3.encode64(0, 0, 0): svo.first_child[second_to_top_layer][Morton3.encode64(0, 0, 0)] == SVOLink.from(leaf_layer,0),
		Morton3.encode64(1, 0, 0): svo.first_child[second_to_top_layer][Morton3.encode64(1, 0, 0)] == SVOLink.from(leaf_layer,8),
		Morton3.encode64(0, 1, 0): svo.first_child[second_to_top_layer][Morton3.encode64(0, 1, 0)] == SVOLink.from(leaf_layer,16),
		Morton3.encode64(1, 1, 0): svo.first_child[second_to_top_layer][Morton3.encode64(1, 1, 0)] == SVOLink.NULL,
		Morton3.encode64(0, 0, 1): svo.first_child[second_to_top_layer][Morton3.encode64(0, 0, 1)] == SVOLink.from(leaf_layer,24),
		Morton3.encode64(1, 0, 1): svo.first_child[second_to_top_layer][Morton3.encode64(1, 0, 1)] == SVOLink.NULL,
		Morton3.encode64(0, 1, 1): svo.first_child[second_to_top_layer][Morton3.encode64(0, 1, 1)] == SVOLink.NULL,
		Morton3.encode64(1, 1, 1): svo.first_child[second_to_top_layer][Morton3.encode64(1, 1, 1)] == SVOLink.NULL,
	}
	var second_to_top_layer_first_child_sum = sum_result_dictionary(second_to_top_layer_first_child)
	test_result.write_case("second_to_top_layer_first_child_sum", second_to_top_layer_first_child_sum)
	
	var leaf_layer_morton = {
		SVOLink.from(leaf_layer, 0): svo.morton[leaf_layer][0] == Morton3.encode64(0,0,0),
		SVOLink.from(leaf_layer, 1): svo.morton[leaf_layer][1] == Morton3.encode64(1,0,0),
		SVOLink.from(leaf_layer, 2): svo.morton[leaf_layer][2] == Morton3.encode64(0,1,0),
		SVOLink.from(leaf_layer, 3): svo.morton[leaf_layer][3] == Morton3.encode64(1,1,0),
		SVOLink.from(leaf_layer, 4): svo.morton[leaf_layer][4] == Morton3.encode64(0,0,1),
		SVOLink.from(leaf_layer, 5): svo.morton[leaf_layer][5] == Morton3.encode64(1,0,1),
		SVOLink.from(leaf_layer, 6): svo.morton[leaf_layer][6] == Morton3.encode64(0,1,1),
		SVOLink.from(leaf_layer, 7): svo.morton[leaf_layer][7] == Morton3.encode64(1,1,1),
		
		SVOLink.from(leaf_layer, 8): svo.morton[leaf_layer][8] == Morton3.encode64(2,0,0),
		SVOLink.from(leaf_layer, 9): svo.morton[leaf_layer][9] == Morton3.encode64(3,0,0),
		SVOLink.from(leaf_layer, 10): svo.morton[leaf_layer][10] == Morton3.encode64(2,1,0),
		SVOLink.from(leaf_layer, 11): svo.morton[leaf_layer][11] == Morton3.encode64(3,1,0),
		SVOLink.from(leaf_layer, 12): svo.morton[leaf_layer][12] == Morton3.encode64(2,0,1),
		SVOLink.from(leaf_layer, 13): svo.morton[leaf_layer][13] == Morton3.encode64(3,0,1),
		SVOLink.from(leaf_layer, 14): svo.morton[leaf_layer][14] == Morton3.encode64(2,1,1),
		SVOLink.from(leaf_layer, 15): svo.morton[leaf_layer][15] == Morton3.encode64(3,1,1),
		
		SVOLink.from(leaf_layer, 16): svo.morton[leaf_layer][16] == Morton3.encode64(0,2,0),
		SVOLink.from(leaf_layer, 17): svo.morton[leaf_layer][17] == Morton3.encode64(1,2,0),
		SVOLink.from(leaf_layer, 18): svo.morton[leaf_layer][18] == Morton3.encode64(0,3,0),
		SVOLink.from(leaf_layer, 19): svo.morton[leaf_layer][19] == Morton3.encode64(1,3,0),
		SVOLink.from(leaf_layer, 20): svo.morton[leaf_layer][20] == Morton3.encode64(0,2,1),
		SVOLink.from(leaf_layer, 21): svo.morton[leaf_layer][21] == Morton3.encode64(1,2,1),
		SVOLink.from(leaf_layer, 22): svo.morton[leaf_layer][22] == Morton3.encode64(0,3,1),
		SVOLink.from(leaf_layer, 23): svo.morton[leaf_layer][23] == Morton3.encode64(1,3,1),
		
		SVOLink.from(leaf_layer, 24): svo.morton[leaf_layer][24] == Morton3.encode64(0,0,2),
		SVOLink.from(leaf_layer, 25): svo.morton[leaf_layer][25] == Morton3.encode64(1,0,2),
		SVOLink.from(leaf_layer, 26): svo.morton[leaf_layer][26] == Morton3.encode64(0,1,2),
		SVOLink.from(leaf_layer, 27): svo.morton[leaf_layer][27] == Morton3.encode64(1,1,2),
		SVOLink.from(leaf_layer, 28): svo.morton[leaf_layer][28] == Morton3.encode64(0,0,3),
		SVOLink.from(leaf_layer, 29): svo.morton[leaf_layer][29] == Morton3.encode64(1,0,3),
		SVOLink.from(leaf_layer, 30): svo.morton[leaf_layer][30] == Morton3.encode64(0,1,3),
		SVOLink.from(leaf_layer, 31): svo.morton[leaf_layer][31] == Morton3.encode64(1,1,3),
	}
	var leaf_layer_morton_sum = sum_result_dictionary(leaf_layer_morton)
	test_result.write_case("leaf_layer_morton_sum", leaf_layer_morton_sum)
	
	var leaf_layer_parent = {
		SVOLink.from(leaf_layer, 0): svo.parent[leaf_layer][0] == SVOLink.from(second_to_top_layer, 0),
		SVOLink.from(leaf_layer, 1): svo.parent[leaf_layer][1] == SVOLink.from(second_to_top_layer, 0),
		SVOLink.from(leaf_layer, 2): svo.parent[leaf_layer][2] == SVOLink.from(second_to_top_layer, 0),
		SVOLink.from(leaf_layer, 3): svo.parent[leaf_layer][3] == SVOLink.from(second_to_top_layer, 0),
		SVOLink.from(leaf_layer, 4): svo.parent[leaf_layer][4] == SVOLink.from(second_to_top_layer, 0),
		SVOLink.from(leaf_layer, 5): svo.parent[leaf_layer][5] == SVOLink.from(second_to_top_layer, 0),
		SVOLink.from(leaf_layer, 6): svo.parent[leaf_layer][6] == SVOLink.from(second_to_top_layer, 0),
		SVOLink.from(leaf_layer, 7): svo.parent[leaf_layer][7] == SVOLink.from(second_to_top_layer, 0),
		
		SVOLink.from(leaf_layer, 8): svo.parent[leaf_layer][8] == SVOLink.from(second_to_top_layer, 1),
		SVOLink.from(leaf_layer, 9): svo.parent[leaf_layer][9] == SVOLink.from(second_to_top_layer, 1),
		SVOLink.from(leaf_layer, 10): svo.parent[leaf_layer][10] == SVOLink.from(second_to_top_layer, 1),
		SVOLink.from(leaf_layer, 11): svo.parent[leaf_layer][11] == SVOLink.from(second_to_top_layer, 1),
		SVOLink.from(leaf_layer, 12): svo.parent[leaf_layer][12] == SVOLink.from(second_to_top_layer, 1),
		SVOLink.from(leaf_layer, 13): svo.parent[leaf_layer][13] == SVOLink.from(second_to_top_layer, 1),
		SVOLink.from(leaf_layer, 14): svo.parent[leaf_layer][14] == SVOLink.from(second_to_top_layer, 1),
		SVOLink.from(leaf_layer, 15): svo.parent[leaf_layer][15] == SVOLink.from(second_to_top_layer, 1),
		
		SVOLink.from(leaf_layer, 16): svo.parent[leaf_layer][16] == SVOLink.from(second_to_top_layer, 2),
		SVOLink.from(leaf_layer, 17): svo.parent[leaf_layer][17] == SVOLink.from(second_to_top_layer, 2),
		SVOLink.from(leaf_layer, 18): svo.parent[leaf_layer][18] == SVOLink.from(second_to_top_layer, 2),
		SVOLink.from(leaf_layer, 19): svo.parent[leaf_layer][19] == SVOLink.from(second_to_top_layer, 2),
		SVOLink.from(leaf_layer, 20): svo.parent[leaf_layer][20] == SVOLink.from(second_to_top_layer, 2),
		SVOLink.from(leaf_layer, 21): svo.parent[leaf_layer][21] == SVOLink.from(second_to_top_layer, 2),
		SVOLink.from(leaf_layer, 22): svo.parent[leaf_layer][22] == SVOLink.from(second_to_top_layer, 2),
		SVOLink.from(leaf_layer, 23): svo.parent[leaf_layer][23] == SVOLink.from(second_to_top_layer, 2),
		
		SVOLink.from(leaf_layer, 24): svo.parent[leaf_layer][24] == SVOLink.from(second_to_top_layer, 4),
		SVOLink.from(leaf_layer, 25): svo.parent[leaf_layer][25] == SVOLink.from(second_to_top_layer, 4),
		SVOLink.from(leaf_layer, 26): svo.parent[leaf_layer][26] == SVOLink.from(second_to_top_layer, 4),
		SVOLink.from(leaf_layer, 27): svo.parent[leaf_layer][27] == SVOLink.from(second_to_top_layer, 4),
		SVOLink.from(leaf_layer, 28): svo.parent[leaf_layer][28] == SVOLink.from(second_to_top_layer, 4),
		SVOLink.from(leaf_layer, 29): svo.parent[leaf_layer][29] == SVOLink.from(second_to_top_layer, 4),
		SVOLink.from(leaf_layer, 30): svo.parent[leaf_layer][30] == SVOLink.from(second_to_top_layer, 4),
		SVOLink.from(leaf_layer, 31): svo.parent[leaf_layer][31] == SVOLink.from(second_to_top_layer, 4),
	}
	var leaf_layer_parent_sum = sum_result_dictionary(leaf_layer_parent)
	test_result.write_case("leaf_layer_parent_sum", leaf_layer_parent_sum)
	
	var leaf_layer_xn = {
		SVOLink.from(leaf_layer, 0): svo.xn[leaf_layer][0] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 1): svo.xn[leaf_layer][1] == SVOLink.from(leaf_layer, 0),
		SVOLink.from(leaf_layer, 2): svo.xn[leaf_layer][2] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 3): svo.xn[leaf_layer][3] == SVOLink.from(leaf_layer, 2),
		SVOLink.from(leaf_layer, 4): svo.xn[leaf_layer][4] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 5): svo.xn[leaf_layer][5] == SVOLink.from(leaf_layer, 4),
		SVOLink.from(leaf_layer, 6): svo.xn[leaf_layer][6] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 7): svo.xn[leaf_layer][7] == SVOLink.from(leaf_layer, 6),
		
		SVOLink.from(leaf_layer, 8): svo.xn[leaf_layer][8] == SVOLink.from(leaf_layer, 1),
		SVOLink.from(leaf_layer, 9): svo.xn[leaf_layer][9] == SVOLink.from(leaf_layer, 8),
		SVOLink.from(leaf_layer, 10): svo.xn[leaf_layer][10] == SVOLink.from(leaf_layer, 3),
		SVOLink.from(leaf_layer, 11): svo.xn[leaf_layer][11] == SVOLink.from(leaf_layer, 10),
		SVOLink.from(leaf_layer, 12): svo.xn[leaf_layer][12] == SVOLink.from(leaf_layer, 5),
		SVOLink.from(leaf_layer, 13): svo.xn[leaf_layer][13] == SVOLink.from(leaf_layer, 12),
		SVOLink.from(leaf_layer, 14): svo.xn[leaf_layer][14] == SVOLink.from(leaf_layer, 7),
		SVOLink.from(leaf_layer, 15): svo.xn[leaf_layer][15] == SVOLink.from(leaf_layer, 14),
		
		SVOLink.from(leaf_layer, 16): svo.xn[leaf_layer][16] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 17): svo.xn[leaf_layer][17] == SVOLink.from(leaf_layer, 16),
		SVOLink.from(leaf_layer, 18): svo.xn[leaf_layer][18] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 19): svo.xn[leaf_layer][19] == SVOLink.from(leaf_layer, 18),
		SVOLink.from(leaf_layer, 20): svo.xn[leaf_layer][20] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 21): svo.xn[leaf_layer][21] == SVOLink.from(leaf_layer, 20),
		SVOLink.from(leaf_layer, 22): svo.xn[leaf_layer][22] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 23): svo.xn[leaf_layer][23] == SVOLink.from(leaf_layer, 22),
		
		SVOLink.from(leaf_layer, 24): svo.xn[leaf_layer][24] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 25): svo.xn[leaf_layer][25] == SVOLink.from(leaf_layer, 24),
		SVOLink.from(leaf_layer, 26): svo.xn[leaf_layer][26] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 27): svo.xn[leaf_layer][27] == SVOLink.from(leaf_layer, 26),
		SVOLink.from(leaf_layer, 28): svo.xn[leaf_layer][28] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 29): svo.xn[leaf_layer][29] == SVOLink.from(leaf_layer, 28),
		SVOLink.from(leaf_layer, 30): svo.xn[leaf_layer][30] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 31): svo.xn[leaf_layer][31] == SVOLink.from(leaf_layer, 30),
	}
	var leaf_layer_xn_sum = sum_result_dictionary(leaf_layer_xn)
	test_result.write_case("leaf_layer_xn_sum", leaf_layer_xn_sum)
	
	var leaf_layer_yn = {
		SVOLink.from(leaf_layer, 0): svo.yn[leaf_layer][0] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 1): svo.yn[leaf_layer][1] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 2): svo.yn[leaf_layer][2] == SVOLink.from(leaf_layer, 0),
		SVOLink.from(leaf_layer, 3): svo.yn[leaf_layer][3] == SVOLink.from(leaf_layer, 1),
		SVOLink.from(leaf_layer, 4): svo.yn[leaf_layer][4] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 5): svo.yn[leaf_layer][5] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 6): svo.yn[leaf_layer][6] == SVOLink.from(leaf_layer, 4),
		SVOLink.from(leaf_layer, 7): svo.yn[leaf_layer][7] == SVOLink.from(leaf_layer, 5),
		
		SVOLink.from(leaf_layer, 8): svo.yn[leaf_layer][8] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 9): svo.yn[leaf_layer][9] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 10): svo.yn[leaf_layer][10] == SVOLink.from(leaf_layer, 8),
		SVOLink.from(leaf_layer, 11): svo.yn[leaf_layer][11] == SVOLink.from(leaf_layer, 9),
		SVOLink.from(leaf_layer, 12): svo.yn[leaf_layer][12] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 13): svo.yn[leaf_layer][13] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 14): svo.yn[leaf_layer][14] == SVOLink.from(leaf_layer, 12),
		SVOLink.from(leaf_layer, 15): svo.yn[leaf_layer][15] == SVOLink.from(leaf_layer, 13),
		
		SVOLink.from(leaf_layer, 16): svo.yn[leaf_layer][16] == SVOLink.from(leaf_layer, 2),
		SVOLink.from(leaf_layer, 17): svo.yn[leaf_layer][17] == SVOLink.from(leaf_layer, 3),
		SVOLink.from(leaf_layer, 18): svo.yn[leaf_layer][18] == SVOLink.from(leaf_layer, 16),
		SVOLink.from(leaf_layer, 19): svo.yn[leaf_layer][19] == SVOLink.from(leaf_layer, 17),
		SVOLink.from(leaf_layer, 20): svo.yn[leaf_layer][20] == SVOLink.from(leaf_layer, 6),
		SVOLink.from(leaf_layer, 21): svo.yn[leaf_layer][21] == SVOLink.from(leaf_layer, 7),
		SVOLink.from(leaf_layer, 22): svo.yn[leaf_layer][22] == SVOLink.from(leaf_layer, 20),
		SVOLink.from(leaf_layer, 23): svo.yn[leaf_layer][23] == SVOLink.from(leaf_layer, 21),
		
		SVOLink.from(leaf_layer, 24): svo.yn[leaf_layer][24] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 25): svo.yn[leaf_layer][25] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 26): svo.yn[leaf_layer][26] == SVOLink.from(leaf_layer, 24),
		SVOLink.from(leaf_layer, 27): svo.yn[leaf_layer][27] == SVOLink.from(leaf_layer, 25),
		SVOLink.from(leaf_layer, 28): svo.yn[leaf_layer][28] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 29): svo.yn[leaf_layer][29] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 30): svo.yn[leaf_layer][30] == SVOLink.from(leaf_layer, 28),
		SVOLink.from(leaf_layer, 31): svo.yn[leaf_layer][31] == SVOLink.from(leaf_layer, 29),
	}
	var leaf_layer_yn_sum = sum_result_dictionary(leaf_layer_yn)
	test_result.write_case("leaf_layer_yn_sum", leaf_layer_yn_sum)
	
	var leaf_layer_zn = {
		SVOLink.from(leaf_layer, 0): svo.zn[leaf_layer][0] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 1): svo.zn[leaf_layer][1] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 2): svo.zn[leaf_layer][2] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 3): svo.zn[leaf_layer][3] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 4): svo.zn[leaf_layer][4] == SVOLink.from(leaf_layer, 0),
		SVOLink.from(leaf_layer, 5): svo.zn[leaf_layer][5] == SVOLink.from(leaf_layer, 1),
		SVOLink.from(leaf_layer, 6): svo.zn[leaf_layer][6] == SVOLink.from(leaf_layer, 2),
		SVOLink.from(leaf_layer, 7): svo.zn[leaf_layer][7] == SVOLink.from(leaf_layer, 3),
		
		SVOLink.from(leaf_layer, 8): svo.zn[leaf_layer][8] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 9): svo.zn[leaf_layer][9] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 10): svo.zn[leaf_layer][10] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 11): svo.zn[leaf_layer][11] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 12): svo.zn[leaf_layer][12] == SVOLink.from(leaf_layer, 8),
		SVOLink.from(leaf_layer, 13): svo.zn[leaf_layer][13] == SVOLink.from(leaf_layer, 9),
		SVOLink.from(leaf_layer, 14): svo.zn[leaf_layer][14] == SVOLink.from(leaf_layer, 10),
		SVOLink.from(leaf_layer, 15): svo.zn[leaf_layer][15] == SVOLink.from(leaf_layer, 11),
		
		SVOLink.from(leaf_layer, 16): svo.zn[leaf_layer][16] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 17): svo.zn[leaf_layer][17] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 18): svo.zn[leaf_layer][18] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 19): svo.zn[leaf_layer][19] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 20): svo.zn[leaf_layer][20] == SVOLink.from(leaf_layer, 16),
		SVOLink.from(leaf_layer, 21): svo.zn[leaf_layer][21] == SVOLink.from(leaf_layer, 17),
		SVOLink.from(leaf_layer, 22): svo.zn[leaf_layer][22] == SVOLink.from(leaf_layer, 18),
		SVOLink.from(leaf_layer, 23): svo.zn[leaf_layer][23] == SVOLink.from(leaf_layer, 19),
		
		SVOLink.from(leaf_layer, 24): svo.zn[leaf_layer][24] == SVOLink.from(leaf_layer, 4),
		SVOLink.from(leaf_layer, 25): svo.zn[leaf_layer][25] == SVOLink.from(leaf_layer, 5),
		SVOLink.from(leaf_layer, 26): svo.zn[leaf_layer][26] == SVOLink.from(leaf_layer, 6),
		SVOLink.from(leaf_layer, 27): svo.zn[leaf_layer][27] == SVOLink.from(leaf_layer, 7),
		SVOLink.from(leaf_layer, 28): svo.zn[leaf_layer][28] == SVOLink.from(leaf_layer, 24),
		SVOLink.from(leaf_layer, 29): svo.zn[leaf_layer][29] == SVOLink.from(leaf_layer, 25),
		SVOLink.from(leaf_layer, 30): svo.zn[leaf_layer][30] == SVOLink.from(leaf_layer, 26),
		SVOLink.from(leaf_layer, 31): svo.zn[leaf_layer][31] == SVOLink.from(leaf_layer, 27),
	}
	var leaf_layer_zn_sum = sum_result_dictionary(leaf_layer_zn)
	test_result.write_case("leaf_layer_zn_sum", leaf_layer_zn_sum)
	
	var leaf_layer_xp = {
		SVOLink.from(leaf_layer, 0): svo.xp[leaf_layer][0] == SVOLink.from(leaf_layer, 1),
		SVOLink.from(leaf_layer, 1): svo.xp[leaf_layer][1] == SVOLink.from(leaf_layer, 8),
		SVOLink.from(leaf_layer, 2): svo.xp[leaf_layer][2] == SVOLink.from(leaf_layer, 3),
		SVOLink.from(leaf_layer, 3): svo.xp[leaf_layer][3] == SVOLink.from(leaf_layer, 10),
		SVOLink.from(leaf_layer, 4): svo.xp[leaf_layer][4] == SVOLink.from(leaf_layer, 5),
		SVOLink.from(leaf_layer, 5): svo.xp[leaf_layer][5] == SVOLink.from(leaf_layer, 12),
		SVOLink.from(leaf_layer, 6): svo.xp[leaf_layer][6] == SVOLink.from(leaf_layer, 7),
		SVOLink.from(leaf_layer, 7): svo.xp[leaf_layer][7] == SVOLink.from(leaf_layer, 14),
		
		SVOLink.from(leaf_layer, 8): svo.xp[leaf_layer][8] == SVOLink.from(leaf_layer, 9),
		SVOLink.from(leaf_layer, 9): svo.xp[leaf_layer][9] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 10): svo.xp[leaf_layer][10] == SVOLink.from(leaf_layer, 11),
		SVOLink.from(leaf_layer, 11): svo.xp[leaf_layer][11] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 12): svo.xp[leaf_layer][12] == SVOLink.from(leaf_layer, 13),
		SVOLink.from(leaf_layer, 13): svo.xp[leaf_layer][13] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 14): svo.xp[leaf_layer][14] == SVOLink.from(leaf_layer, 15),
		SVOLink.from(leaf_layer, 15): svo.xp[leaf_layer][15] == SVOLink.NULL,
		
		SVOLink.from(leaf_layer, 16): svo.xp[leaf_layer][16] == SVOLink.from(leaf_layer, 17),
		SVOLink.from(leaf_layer, 17): svo.xp[leaf_layer][17] == SVOLink.from(second_to_top_layer, 3),
		SVOLink.from(leaf_layer, 18): svo.xp[leaf_layer][18] == SVOLink.from(leaf_layer, 19),
		SVOLink.from(leaf_layer, 19): svo.xp[leaf_layer][19] == SVOLink.from(second_to_top_layer, 3),
		SVOLink.from(leaf_layer, 20): svo.xp[leaf_layer][20] == SVOLink.from(leaf_layer, 21),
		SVOLink.from(leaf_layer, 21): svo.xp[leaf_layer][21] == SVOLink.from(second_to_top_layer, 3),
		SVOLink.from(leaf_layer, 22): svo.xp[leaf_layer][22] == SVOLink.from(leaf_layer, 23),
		SVOLink.from(leaf_layer, 23): svo.xp[leaf_layer][23] == SVOLink.from(second_to_top_layer, 3),
		
		SVOLink.from(leaf_layer, 24): svo.xp[leaf_layer][24] == SVOLink.from(leaf_layer, 25),
		SVOLink.from(leaf_layer, 25): svo.xp[leaf_layer][25] == SVOLink.from(second_to_top_layer, 5),
		SVOLink.from(leaf_layer, 26): svo.xp[leaf_layer][26] == SVOLink.from(leaf_layer, 27),
		SVOLink.from(leaf_layer, 27): svo.xp[leaf_layer][27] == SVOLink.from(second_to_top_layer, 5),
		SVOLink.from(leaf_layer, 28): svo.xp[leaf_layer][28] == SVOLink.from(leaf_layer, 29),
		SVOLink.from(leaf_layer, 29): svo.xp[leaf_layer][29] == SVOLink.from(second_to_top_layer, 5),
		SVOLink.from(leaf_layer, 30): svo.xp[leaf_layer][30] == SVOLink.from(leaf_layer, 31),
		SVOLink.from(leaf_layer, 31): svo.xp[leaf_layer][31] == SVOLink.from(second_to_top_layer, 5),
	}
	var leaf_layer_xp_sum = sum_result_dictionary(leaf_layer_xp)
	test_result.write_case("leaf_layer_xp_sum", leaf_layer_xp_sum)
	
	var leaf_layer_yp = {
		SVOLink.from(leaf_layer, 0): svo.yp[leaf_layer][0] == SVOLink.from(leaf_layer, 2),
		SVOLink.from(leaf_layer, 1): svo.yp[leaf_layer][1] == SVOLink.from(leaf_layer, 3),
		SVOLink.from(leaf_layer, 2): svo.yp[leaf_layer][2] == SVOLink.from(leaf_layer, 16),
		SVOLink.from(leaf_layer, 3): svo.yp[leaf_layer][3] == SVOLink.from(leaf_layer, 17),
		SVOLink.from(leaf_layer, 4): svo.yp[leaf_layer][4] == SVOLink.from(leaf_layer, 6),
		SVOLink.from(leaf_layer, 5): svo.yp[leaf_layer][5] == SVOLink.from(leaf_layer, 7),
		SVOLink.from(leaf_layer, 6): svo.yp[leaf_layer][6] == SVOLink.from(leaf_layer, 20),
		SVOLink.from(leaf_layer, 7): svo.yp[leaf_layer][7] == SVOLink.from(leaf_layer, 21),
		
		SVOLink.from(leaf_layer, 8): svo.yp[leaf_layer][8] == SVOLink.from(leaf_layer, 10),
		SVOLink.from(leaf_layer, 9): svo.yp[leaf_layer][9] == SVOLink.from(leaf_layer, 11),
		SVOLink.from(leaf_layer, 10): svo.yp[leaf_layer][10] == SVOLink.from(second_to_top_layer, 3),
		SVOLink.from(leaf_layer, 11): svo.yp[leaf_layer][11] == SVOLink.from(second_to_top_layer, 3),
		SVOLink.from(leaf_layer, 12): svo.yp[leaf_layer][12] == SVOLink.from(leaf_layer, 14),
		SVOLink.from(leaf_layer, 13): svo.yp[leaf_layer][13] == SVOLink.from(leaf_layer, 15),
		SVOLink.from(leaf_layer, 14): svo.yp[leaf_layer][14] == SVOLink.from(second_to_top_layer, 3),
		SVOLink.from(leaf_layer, 15): svo.yp[leaf_layer][15] == SVOLink.from(second_to_top_layer, 3),
		
		SVOLink.from(leaf_layer, 16): svo.yp[leaf_layer][16] == SVOLink.from(leaf_layer, 18),
		SVOLink.from(leaf_layer, 17): svo.yp[leaf_layer][17] == SVOLink.from(leaf_layer, 19),
		SVOLink.from(leaf_layer, 18): svo.yp[leaf_layer][18] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 19): svo.yp[leaf_layer][19] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 20): svo.yp[leaf_layer][20] == SVOLink.from(leaf_layer, 22),
		SVOLink.from(leaf_layer, 21): svo.yp[leaf_layer][21] == SVOLink.from(leaf_layer, 23),
		SVOLink.from(leaf_layer, 22): svo.yp[leaf_layer][22] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 23): svo.yp[leaf_layer][23] == SVOLink.NULL,
		
		SVOLink.from(leaf_layer, 24): svo.yp[leaf_layer][24] == SVOLink.from(leaf_layer, 26),
		SVOLink.from(leaf_layer, 25): svo.yp[leaf_layer][25] == SVOLink.from(leaf_layer, 27),
		SVOLink.from(leaf_layer, 26): svo.yp[leaf_layer][26] == SVOLink.from(second_to_top_layer, 6),
		SVOLink.from(leaf_layer, 27): svo.yp[leaf_layer][27] == SVOLink.from(second_to_top_layer, 6),
		SVOLink.from(leaf_layer, 28): svo.yp[leaf_layer][28] == SVOLink.from(leaf_layer, 30),
		SVOLink.from(leaf_layer, 29): svo.yp[leaf_layer][29] == SVOLink.from(leaf_layer, 31),
		SVOLink.from(leaf_layer, 30): svo.yp[leaf_layer][30] == SVOLink.from(second_to_top_layer, 6),
		SVOLink.from(leaf_layer, 31): svo.yp[leaf_layer][31] == SVOLink.from(second_to_top_layer, 6),
	}
	var leaf_layer_yp_sum = sum_result_dictionary(leaf_layer_yp)
	test_result.write_case("leaf_layer_yp_sum", leaf_layer_yp_sum)
	
	var leaf_layer_zp = {
		SVOLink.from(leaf_layer, 0): svo.zp[leaf_layer][0] == SVOLink.from(leaf_layer, 4),
		SVOLink.from(leaf_layer, 1): svo.zp[leaf_layer][1] == SVOLink.from(leaf_layer, 5),
		SVOLink.from(leaf_layer, 2): svo.zp[leaf_layer][2] == SVOLink.from(leaf_layer, 6),
		SVOLink.from(leaf_layer, 3): svo.zp[leaf_layer][3] == SVOLink.from(leaf_layer, 7),
		SVOLink.from(leaf_layer, 4): svo.zp[leaf_layer][4] == SVOLink.from(leaf_layer, 24),
		SVOLink.from(leaf_layer, 5): svo.zp[leaf_layer][5] == SVOLink.from(leaf_layer, 25),
		SVOLink.from(leaf_layer, 6): svo.zp[leaf_layer][6] == SVOLink.from(leaf_layer, 26),
		SVOLink.from(leaf_layer, 7): svo.zp[leaf_layer][7] == SVOLink.from(leaf_layer, 27),
		
		SVOLink.from(leaf_layer, 8): svo.zp[leaf_layer][8] == SVOLink.from(leaf_layer, 12),
		SVOLink.from(leaf_layer, 9): svo.zp[leaf_layer][9] == SVOLink.from(leaf_layer, 13),
		SVOLink.from(leaf_layer, 10): svo.zp[leaf_layer][10] == SVOLink.from(leaf_layer, 14),
		SVOLink.from(leaf_layer, 11): svo.zp[leaf_layer][11] == SVOLink.from(leaf_layer, 15),
		SVOLink.from(leaf_layer, 12): svo.zp[leaf_layer][12] == SVOLink.from(second_to_top_layer, 5),
		SVOLink.from(leaf_layer, 13): svo.zp[leaf_layer][13] == SVOLink.from(second_to_top_layer, 5),
		SVOLink.from(leaf_layer, 14): svo.zp[leaf_layer][14] == SVOLink.from(second_to_top_layer, 5),
		SVOLink.from(leaf_layer, 15): svo.zp[leaf_layer][15] == SVOLink.from(second_to_top_layer, 5),
		
		SVOLink.from(leaf_layer, 16): svo.zp[leaf_layer][16] == SVOLink.from(leaf_layer, 20),
		SVOLink.from(leaf_layer, 17): svo.zp[leaf_layer][17] == SVOLink.from(leaf_layer, 21),
		SVOLink.from(leaf_layer, 18): svo.zp[leaf_layer][18] == SVOLink.from(leaf_layer, 22),
		SVOLink.from(leaf_layer, 19): svo.zp[leaf_layer][19] == SVOLink.from(leaf_layer, 23),
		SVOLink.from(leaf_layer, 20): svo.zp[leaf_layer][20] == SVOLink.from(second_to_top_layer, 6),
		SVOLink.from(leaf_layer, 21): svo.zp[leaf_layer][21] == SVOLink.from(second_to_top_layer, 6),
		SVOLink.from(leaf_layer, 22): svo.zp[leaf_layer][22] == SVOLink.from(second_to_top_layer, 6),
		SVOLink.from(leaf_layer, 23): svo.zp[leaf_layer][23] == SVOLink.from(second_to_top_layer, 6),
		
		SVOLink.from(leaf_layer, 24): svo.zp[leaf_layer][24] == SVOLink.from(leaf_layer, 28),
		SVOLink.from(leaf_layer, 25): svo.zp[leaf_layer][25] == SVOLink.from(leaf_layer, 29),
		SVOLink.from(leaf_layer, 26): svo.zp[leaf_layer][26] == SVOLink.from(leaf_layer, 30),
		SVOLink.from(leaf_layer, 27): svo.zp[leaf_layer][27] == SVOLink.from(leaf_layer, 31),
		SVOLink.from(leaf_layer, 28): svo.zp[leaf_layer][28] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 29): svo.zp[leaf_layer][29] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 30): svo.zp[leaf_layer][30] == SVOLink.NULL,
		SVOLink.from(leaf_layer, 31): svo.zp[leaf_layer][31] == SVOLink.NULL,
	}
	var leaf_layer_zp_sum = sum_result_dictionary(leaf_layer_zp)
	test_result.write_case("leaf_layer_zp_sum", leaf_layer_zp_sum)
	
	# TODO: Implement inside/outside SVO node state
	#for subgrid in svo.subgrid:
	#endregion
	
	#region Neighbor test
	var big_node_surrounded_by_big_node = [
		SVOLink.from(second_to_top_layer, 3),
		SVOLink.from(second_to_top_layer, 5),
		SVOLink.from(second_to_top_layer, 6),
	]
	var big_node_surrounded_by_big_node_neighbors = svo.neighbors_of(SVOLink.from(second_to_top_layer, 7))
	var big_node_surrounded_by_big_node_result = equal_set(
		big_node_surrounded_by_big_node, big_node_surrounded_by_big_node_neighbors)
	test_result.write_case("big_node_surrounded_by_big_node_result", big_node_surrounded_by_big_node_result)
	#endregion
	
	return test_result

func sum_result_dictionary(result: Dictionary) -> bool:
	var sum = true
	for key in result.keys():
		sum = sum and result[key]
	return sum

func equal_set(set1: Array, set2: Array) -> bool:
	if set1.size() != set2.size():
		return false
	for i in set1:
		if not set2.has(i):
			return false
	return true
