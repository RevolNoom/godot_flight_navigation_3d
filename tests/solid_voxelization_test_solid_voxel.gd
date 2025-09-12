extends Node3D

@onready var flight_nav: FlightNavigation3D = $FlightNavigation3D

func _ready():
	flight_nav.progress.connect(_on_flight_nav_progress)
	
	flight_nav.depth = 3
	flight_nav.multi_threading = false
	var svo = await flight_nav.build_navigation_data()
	flight_nav.sparse_voxel_octree = svo
	flight_nav.draw()
	
func _on_flight_nav_progress(
	step: FlightNavigation3D.ProgressStep, 
	svo: SVO,
	work_completed: int, 
	total_work: int):
		match step:
			FlightNavigation3D.ProgressStep.XY_PLANE_RASTERIZATION:
				if work_completed == total_work:
					var subgrid = flight_nav.sparse_voxel_octree.subgrid
					flight_nav.sparse_voxel_octree = svo
					flight_nav.draw()
					
					
