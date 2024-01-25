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
	#_post_voxelization_svolink_globalpos_conversion_test()
	_find_path_test()
	pass

######## TEST #############

func _automated_test():
	_test_debug_draw()
	pass

func _post_voxelization_svolink_globalpos_conversion_test():
	var test_positions = [Vector3(1, 1, 1), Vector3(0.9,0.9,0.9),Vector3(0.3,0.3,0.3),]
	for test_position in test_positions:
		var link = $NavigationSpace3D.get_svolink_of(test_position)
		$NavigationSpace3D.draw_svolink_box(link)


func _find_path_test():
	print("Start find path")
	var from = Vector3(-2, -2, -2)
	var to = Vector3(2, 2, 2)
	var path = $NavigationSpace3D.find_path(from, to)
	$PathDebugDraw.multimesh.instance_count = path.size()
	for i in range(path.size()):
		$PathDebugDraw.multimesh.set_instance_transform(i, Transform3D(Basis(), path[i]))
	print("Done find path: %d points" % path.size())
	

func _test_debug_draw():
	var Ns: PackedScene = preload("res://navigation_space_3d.tscn")
	var ns = Ns.instantiate()
	var max_depth = 5
	ns.max_depth = max_depth
	ns._svo = SVO._get_debug_svo(max_depth)
	add_child(ns)
	ns.draw_debug_boxes()
