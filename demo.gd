extends Node3D

@onready var flight_nav = $FlightNavigation3D

func _ready() -> void:
	#TriangleBoxOverlapCheck_ReferenceCode._automated_test()
	#ITriangleBoxOverlapCheck._automated_test()
	await flight_nav.build_navigation()
	#flight_nav.draw()
	print("Done")
	_find_path_test()

######## TEST #############

func _find_path_test():
	#print($FlightNavigation3D.svo.layers[4])
	var path = flight_nav.find_path($Start.global_position, $End.global_position)
	var svolink_path: Array[int] = []
	svolink_path.resize(path.size())
	for i in range(path.size()):
		svolink_path[i] = flight_nav.get_svolink_of(path[i])
	print("Path:")
	var visualizer_link := flight_nav.get_node("SvoVisualizerLink") as SvoVisualizerLink
	visualizer_link.svo_nodes.clear()
	for svolink in svolink_path:
		if SvoLink64.singleton.get_layer(svolink) > 0:
			visualizer_link.add_node(svolink, SvoLink64.singleton.get_format_string(svolink))
		else:
			visualizer_link.add_voxel(svolink, SvoLink64.singleton.get_format_string(svolink))
			
	flight_nav.draw()
