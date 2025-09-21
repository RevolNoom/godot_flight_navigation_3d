extends Node3D

@onready var flight_nav: FlightNavigation3D = $FlightNavigation3D
func test():
	var svo = await flight_nav.build_navigation_data()
	flight_nav.sparse_voxel_octree = svo
	
