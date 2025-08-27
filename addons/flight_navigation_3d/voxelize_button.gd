@tool
extends Control

@onready var progress_dialog = $ProgressDialog/ScrollContainer/Log

var flight_navigation_3d_scene: FlightNavigation3D = null:
	set(value):
		flight_navigation_3d_scene = value
		if flight_navigation_3d_scene != null:
			flight_navigation_3d_scene.build_log.connect(_on_log_received)
			
var th := Thread.new()

func _on_pressed() -> void:
	$ProgressDialog.show()
	progress_dialog.text = ""
	
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

func _on_log_received(log: String, time_string: String, time_elapsed: int):
	progress_dialog.text += "[%s][%dms] %s\n" % [time_string, time_elapsed, log]

func _on_progress_dialog_close_requested() -> void:
	$ProgressDialog.hide()

func _exit_tree() -> void:
	if flight_navigation_3d_scene != null:
		flight_navigation_3d_scene.build_log.disconnect(_on_log_received)
