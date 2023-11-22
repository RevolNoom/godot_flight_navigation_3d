extends Node3D

func _ready():
	#PriorityQueue._automated_test()
	pass

func _on_timer_timeout():
	$NavigationSpace3D.voxelize_async()
	#$NavigationSpace3D.voxelize()
	pass

func _on_navigation_space_3d_finished():
	#pass
	#$MeshInstance3D.visible = true
	$NavigationSpace3D.draw_debug_boxes()
	print("Finding path")
	var path = $NavigationSpace3D.find_path(Vector3(-1, -1, -1), Vector3(-1, 1, -1))
	print("Path: %s" % str(path))

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
