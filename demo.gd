extends Node3D

@onready var flight_nav = $FlightNavigation3D

func _ready() -> void:
	#TriangleBoxTest_ReferenceCode._automated_test()
	#TriangleBoxTest._automated_test()
	var svo = await flight_nav.build_navigation_data()
	flight_nav.sparse_voxel_octree = svo
	flight_nav.draw()
	print("Done")
	#_find_path_test()

######## TEST #############

func _find_path_test():
	#print($FlightNavigation3D.svo.layers[4])
	var path = $FlightNavigation3D.find_path($Start.global_position, $End.global_position)
	var svolink_path = Array(path).map(func(pos): return $FlightNavigation3D.get_svolink_of(pos))
	print("Path:")
	for svolink in svolink_path:
		print("(", SVOLink.layer(svolink), ", ", SVOLink.offset(svolink), ", ", SVOLink.subgrid(svolink), ")")
		
	for svolink in svolink_path:
		$FlightNavigation3D.draw_svolink_box(svolink)
	#print(svolink_path.map(func(svolink): return SVOLink.get_format_string(svolink, $FlightNavigation3D.svo)))
