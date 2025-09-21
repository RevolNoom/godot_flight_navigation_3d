extends Node3D

@onready var flight_nav: FlightNavigation3D = $FlightNavigation3D

func _ready():
	flight_nav.progress.connect(_on_flight_nav_progress)
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
		
		match step:
			FlightNavigation3D.ProgressStep.YZ_PLANE_RASTERIZATION:
				pass
			FlightNavigation3D.ProgressStep.XP_BIT_FLIP_PROPAGATION:
				pass
			FlightNavigation3D.ProgressStep.PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2:
				pass
			FlightNavigation3D.ProgressStep.PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES:
				pass
			FlightNavigation3D.ProgressStep.PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS:
				pass
			_:
				return
		flight_nav.sparse_voxel_octree = svo
		flight_nav.draw()
		pass
