extends Node3D

func _ready():
	#FlyingNavigation3D.automated_test()
	#PriorityQueue._automated_test()
	pass

func _on_timer_timeout():
	$NavigationSpace3D.voxelize_async()
	#$NavigationSpace3D.voxelize()
	pass

func _on_navigation_space_3d_finished():
	print("Done")
	var link = $NavigationSpace3D.get_svolink_of(Vector3(2,2,2))
	print("Result link: %s" % Morton.int_to_bin(link))
	print("SVOLink pos: %v" % $NavigationSpace3D.get_global_position_of(link))
	#pass
	#$MeshInstance3D.visible = true
	#$NavigationSpace3D.draw_debug_boxes()
	#print("Finding path")
	#var path = $NavigationSpace3D.find_path(Vector3(-1, -1, -1), Vector3(-1, 1, -1))
	#var black = Color.BLACK
	#black.a = 100
	#ns.draw_svolink_box(SVOLink.from_navspace(ns, Vector3(-1, -1, -1)), black )
	#var brown = Color.BROWN
	#brown.a = 100
	#ns.draw_svolink_box(SVOLink.from_navspace(ns, Vector3(-1, 1, -1)), brown)
	#print("Path: %s" % str(path))

######## TEST #############

func _automated_test():
	_test_debug_draw()
	pass


func _test_debug_draw():
	var Ns: PackedScene = preload("res://navigation_space_3d.tscn")
	var ns = Ns.instantiate()
	var max_depth = 5
	ns.max_depth = max_depth
	ns._svo = SVO._get_debug_svo(max_depth)
	add_child(ns)
	ns.draw_debug_boxes()
