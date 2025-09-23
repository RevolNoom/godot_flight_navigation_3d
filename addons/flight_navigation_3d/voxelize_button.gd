@tool
extends Control

@onready var progress_dialog = $ProgressDialog/ScrollContainer/Log

var flight_navigation_3d_scene: FlightNavigation3D = null:
	set(value):
		if flight_navigation_3d_scene != null:
			flight_navigation_3d_scene.progress.disconnect(_on_progress)
		flight_navigation_3d_scene = value
		if flight_navigation_3d_scene != null:
			flight_navigation_3d_scene.progress.connect(_on_progress)
			

func _exit_tree() -> void:
	if flight_navigation_3d_scene != null:
		flight_navigation_3d_scene.progress.disconnect(_on_progress)
		

var step_start_time: Array[Dictionary] = []
var step_end_time: Array[Dictionary] = []
var step_work_completed: PackedInt64Array = []
var step_total_work: PackedInt64Array = []
var step_message: PackedStringArray = _generate_step_message()

func _generate_step_message() -> PackedStringArray:
	var result: PackedStringArray = []
	result.resize(FlightNavigation3D.ProgressStep.MAX_STEP)
	result[FlightNavigation3D.ProgressStep.GET_ALL_VOXELIZATION_TARGET] = "GET_ALL_VOXELIZATION_TARGET"
	result[FlightNavigation3D.ProgressStep.BUILD_MESH] = "BUILD_MESH"
	result[FlightNavigation3D.ProgressStep.REMOVE_THIN_TRIANGLES] = "REMOVE_THIN_TRIANGLES"
	result[FlightNavigation3D.ProgressStep.OFFSET_VERTICES_TO_LOCAL_COORDINATE] = "OFFSET_VERTICES_TO_LOCAL_COORDINATE"
	result[FlightNavigation3D.ProgressStep.DETERMINE_ACTIVE_LAYER_1_NODES] = "DETERMINE_ACTIVE_LAYER_1_NODES"
	result[FlightNavigation3D.ProgressStep.CONSTRUCT_SVO] = "CONSTRUCT_SVO"
	result[FlightNavigation3D.ProgressStep.SOLID_VOXELIZATION] = "SOLID_VOXELIZATION"
	result[FlightNavigation3D.ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION] = "HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION"
	result[FlightNavigation3D.ProgressStep.YZ_PLANE_RASTERIZATION] = "YZ_PLANE_RASTERIZATION"
	result[FlightNavigation3D.ProgressStep.PREPARE_FLAGS_AND_HEAD_NODES] = "PREPARE_FLAGS_AND_HEAD_NODES"
	result[FlightNavigation3D.ProgressStep.XP_BIT_FLIP_PROPAGATION] = "XP_BIT_FLIP_PROPAGATION"
	result[FlightNavigation3D.ProgressStep.PREPARE_FLIP_FLAG_LAYER_1] = "PREPARE_FLIP_FLAG_LAYER_1"
	result[FlightNavigation3D.ProgressStep.FLIP_BOTTOM_UP_LAYER_1] = "FLIP_BOTTOM_UP_LAYER_1"
	result[FlightNavigation3D.ProgressStep.PROPAGATE_FLIP_INFORMATION_LAYER_1] = "PROPAGATE_FLIP_INFORMATION_LAYER_1"
	result[FlightNavigation3D.ProgressStep.PREPARE_FLIP_FLAG_FROM_LAYER_2] = "PREPARE_FLIP_FLAG_FROM_LAYER_2"
	result[FlightNavigation3D.ProgressStep.FLIP_BOTTOM_UP_FROM_LAYER_2] = "FLIP_BOTTOM_UP_FROM_LAYER_2"
	result[FlightNavigation3D.ProgressStep.PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2] = "PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2"
	result[FlightNavigation3D.ProgressStep.PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES] = "PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES"
	result[FlightNavigation3D.ProgressStep.PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS] = "PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS"
	result[FlightNavigation3D.ProgressStep.SURFACE_VOXELIZATION] = "SURFACE_VOXELIZATION"
	result[FlightNavigation3D.ProgressStep.CALCULATE_COVERAGE_FACTOR] = "CALCULATE_COVERAGE_FACTOR"
	return result
	

func _on_pressed() -> void:
	$ProgressDialog.show()
	step_start_time.resize(0)
	step_end_time.resize(0)
	step_work_completed.resize(0)
	step_total_work.resize(0)
	
	step_start_time.resize(FlightNavigation3D.ProgressStep.MAX_STEP)
	step_end_time.resize(FlightNavigation3D.ProgressStep.MAX_STEP)
	step_work_completed.resize(FlightNavigation3D.ProgressStep.MAX_STEP)
	step_total_work.resize(FlightNavigation3D.ProgressStep.MAX_STEP)
	
	step_work_completed.fill(-1)
	step_total_work.fill(-1)
	
	_update_dialog_text()
	
	var svo = await flight_navigation_3d_scene.build_navigation_data()
	var existing_svo = flight_navigation_3d_scene.sparse_voxel_octree
	var resource_path = ""
	if existing_svo == null:
		resource_path = "%s%s" % [flight_navigation_3d_scene.name, flight_navigation_3d_scene.resource_format]
		svo.resource_path = resource_path
		ResourceSaver.save(svo, resource_path,
			ResourceSaver.FLAG_RELATIVE_PATHS
			#ResourceSaver.FLAG_COMPRESS |
			)
	else:
		resource_path = existing_svo.resource_path
		svo.take_over_path(resource_path)
		ResourceSaver.save(svo, resource_path, ResourceSaver.FLAG_NONE)
		
	flight_navigation_3d_scene.sparse_voxel_octree = svo
	progress_dialog.text += "Done building navigation data.\nResource saved to %s." % resource_path


func _on_progress(
	step: FlightNavigation3D.ProgressStep, 
	svo: SVO, 
	work_completed: int, 
	total_work: int):
	if work_completed == 0:
		step_start_time[step] = Time.get_datetime_dict_from_system()

	if work_completed == total_work:
		step_end_time[step] = Time.get_datetime_dict_from_system()
	
	step_work_completed[step] = work_completed
	step_total_work[step] = total_work
	_update_dialog_text()

func _update_dialog_text():
	var message = ""
	for step in range(FlightNavigation3D.ProgressStep.MAX_STEP):
		var start_time = ""
		if step_start_time[step].is_empty():
			start_time = "[--:--:--]"
		else:
			start_time = "[%s:%s:%s]" % [
				str(step_start_time[step]["hour"]).lpad(2, "0"),
				str(step_start_time[step]["minute"]).lpad(2, "0"),
				str(step_start_time[step]["second"]).lpad(2, "0")]
				
		var end_time = ""
		if step_end_time[step].is_empty():
			end_time = "[--:--:--]"
		else:
			end_time = "[%s:%s:%s]" % [
				str(step_end_time[step]["hour"]).lpad(2, "0"),
				str(step_end_time[step]["minute"]).lpad(2, "0"),
				str(step_end_time[step]["second"]).lpad(2, "0")]
		message += "%s %s %s [%d/%d]\n" % [
			start_time, 
			end_time, 
			step_message[step],
			step_work_completed[step],
			step_total_work[step],
		]
	progress_dialog.text = message

func _on_progress_dialog_close_requested() -> void:
	$ProgressDialog.hide()
