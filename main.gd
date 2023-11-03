extends Node3D

func _on_timer_timeout():
	$NavigationSpace3D.voxelize_async()

func _on_navigation_space_3d_finished():
	#$MeshInstance3D.visible = true
	$NavigationSpace3D._draw_debug_boxes()

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
	ns._draw_debug_boxes()


