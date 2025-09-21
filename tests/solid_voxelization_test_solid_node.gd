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
		if work_completed != total_work:
			return
			
		var draw_step = FlightNavigation3D.ProgressStep.PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS
		flight_nav.sparse_voxel_octree = svo
		if step == draw_step:
			flight_nav.draw()
			
		match step:
			FlightNavigation3D.ProgressStep.XY_PLANE_RASTERIZATION:
					#flight_nav.draw()
					pass
			FlightNavigation3D.ProgressStep.XP_BIT_FLIP_PROPAGATION:
					#flight_nav.sparse_voxel_octree = svo
					#flight_nav.draw()
					pass
			FlightNavigation3D.ProgressStep.PREPARE_FLIP_FLAG_LAYER_1:
					#flight_nav.draw()
					pass
			FlightNavigation3D.ProgressStep.FLIP_BOTTOM_UP_LAYER_1:
					#flight_nav.draw()
					pass
			FlightNavigation3D.ProgressStep.PROPAGATE_FLIP_INFORMATION_LAYER_1:
					#flight_nav.draw()
					pass
			FlightNavigation3D.ProgressStep.FLIP_BOTTOM_UP_FROM_LAYER_2:
					#flight_nav.draw()
					pass
			FlightNavigation3D.ProgressStep.PREPARE_FLIP_FLAG_FROM_LAYER_2:
					#flight_nav.draw()
					pass
			FlightNavigation3D.ProgressStep.PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2:
					#flight_nav.draw()
					pass
			FlightNavigation3D.ProgressStep.PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES:
					#flight_nav.draw()
					pass
			FlightNavigation3D.ProgressStep.PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS:
					#flight_nav.draw()
					pass
			FlightNavigation3D.ProgressStep.SURFACE_VOXELIZATION:
					#flight_nav.draw()
					pass
					
					
