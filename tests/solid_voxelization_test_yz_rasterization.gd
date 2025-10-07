extends Node3D

@onready var flight_nav: FlightNavigation3D = $FlightNavigation3D

signal _test_result(passed: bool)

func _ready():
	flight_nav.progress.connect(_on_flight_nav_progress)
	test()

func _exit_tree():
	flight_nav.progress.disconnect(_on_flight_nav_progress)
	
func test():
	var svo = await flight_nav.build_navigation()
	flight_nav.sparse_voxel_octree = svo
	flight_nav.draw()
	pass
	
func _on_flight_nav_progress(
	step: FlightNavigation3D.ProgressStep, 
	svo: SVO, 
	work_completed: int, 
	total_work: int):
		if work_completed != total_work:
			return
		#if step == FlightNavigation3D.ProgressStep.YZ_PLANE_RASTERIZATION:
			#flight_nav.sparse_voxel_octree = svo
			#flight_nav.draw()
