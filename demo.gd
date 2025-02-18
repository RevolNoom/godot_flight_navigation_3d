extends Node3D

@onready var flight_nav = $FlightNavigation3D

func _ready() -> void:
	await get_tree().create_timer(1).timeout
	await deferred_build_nav()

func deferred_build_nav():
	var params = {
		"depth": 9,
	}
	await $FlightNavigation3D.build_navigation_data(params)
	$FlightNavigation3D.draw_debug_boxes()

######## TEST #############

func _automated_test():
	_test_debug_draw()
	pass

func _post_voxelization_svolink_globalpos_conversion_test():
	var test_positions = [Vector3(1, 1, 1), Vector3(0.9,0.9,0.9),Vector3(0.3,0.3,0.3),]
	for test_position in test_positions:
		var link = $FlightNavigation3D.get_svolink_of(test_position)
		$FlightNavigation3D.draw_svolink_box(link)

func _neighbor_draw_test():
	var test_positions = [Vector3(0.75, -0.25, 0.75)]#Vector3(0.5, 0.5, 1.5)]#Vector3(-1, -1, -1.2)]#, Vector3(0.9,0.9,0.9),Vector3(0.3,0.3,0.3),]
	for test_position in test_positions:
		var link = 2305843009213696640 # $FlightNavigation3D.get_svolink_of(test_position)
		$FlightNavigation3D.draw_svolink_box(link, Color.GREEN)
		for n in $FlightNavigation3D.svo.neighbors_of(link):
			$FlightNavigation3D.draw_svolink_box(n, Color.BLUE, Color.PINK)


#func _get_svolink_test():
	#var test_positions = [Vector3(-1.4375, -0.4375, -0.9375), 
						#Vector3(-1.4375, -0.3125, -0.9375),
						#Vector3(-1.4375, -0.3125, -0.8125),
						#Vector3(-1.4375, -0.1875, -0.8125),
						#Vector3(-1.4375, -0.0625, -0.8125)]
	#for test_position in test_positions:
		#var link = $FlightNavigation3D.get_svolink_of(test_position)


func _find_path_test():
	var path = $FlightNavigation3D.find_path($Start.global_position, $End.global_position)
	var svolink_path = Array(path).map(func(pos): return $FlightNavigation3D.get_svolink_of(pos))
	print("Path: %s" % [str(svolink_path)])
	for svolink in svolink_path:
		$FlightNavigation3D.draw_svolink_box(svolink)
	#print(svolink_path.map(func(svolink): return SVOLink.get_format_string(svolink, $FlightNavigation3D.svo)))
	

func _test_debug_draw():
	var Ns: PackedScene = preload("res://src/flight_navigation_3d.tscn")
	var ns = Ns.instantiate()
	var max_depth = 5
	ns.max_depth = max_depth
	ns.svo = SVO.get_debug_svo(max_depth)
	add_child(ns)
	ns.draw_debug_boxes()
