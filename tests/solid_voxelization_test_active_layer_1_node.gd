extends Node3D

@onready var flight_nav: FlightNavigation3D = $FlightNavigation3D

func _ready():
	var result = await test()
	pass
	

func test():
	var voxel_size_quarter = 1
	var voxel_size_half = 2*voxel_size_quarter
	var voxel_size = 2*voxel_size_half
	var node_size_0 = 4*voxel_size
	var node_size_1 = 2*node_size_0
	var node_size_2 = 2*node_size_1
	var node_size_3 = 2*node_size_2
	
	var triangle: PackedVector3Array = [
		Vector3(node_size_2-voxel_size_quarter, 0, 0), 
		Vector3(node_size_2-voxel_size_quarter, 0, node_size_1-2*voxel_size_quarter),
		Vector3(node_size_2-voxel_size_quarter, node_size_1-2*voxel_size_quarter, 0) 
	]
	
	var triangle_shifted: PackedVector3Array = triangle.duplicate()
	for i in range(triangle_shifted.size()):
		triangle_shifted[i].x += voxel_size_half
	
	var tbt = TriangleBoxTest.new(
		triangle_shifted,
		Vector3.ONE * node_size_1, 
		TriangleBoxTest.Separability.SEPARATING_26,
		voxel_size)
		
	# Schwarz's modification: 
	# Enlarge the triangle’s bounding box in −x direction by one SG voxel
	tbt.aabb.position.x -= voxel_size
	tbt.aabb.size.x += voxel_size
	
	var vox_range: Array[Vector3i] = flight_nav._voxels_overlapped_by_aabb(
		node_size_1,
		tbt.aabb, 
		Vector3.ONE * node_size_3)
	
	var overlap_result = []
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				var node_coordinate = Vector3(x, y, z)
				if tbt.overlap_voxel(node_coordinate * node_size_1):
					overlap_result.push_back(node_coordinate)
	
	var result = {}
	result["TriangleBoxTest Node 1"] = \
		overlap_result[0] == Vector3(1, 0, 0) and\
		overlap_result[1] == Vector3(2, 0, 0)
	
	var svo = await flight_nav.build_navigation_data()
	flight_nav.sparse_voxel_octree = svo
	result["build_navigation_data Active layer 1 node count == 2"] = svo.morton[1].size() == 16
	return result
	
