@tool
extends Control

@onready var progress_dialog = $ProgressDialog/ScrollContainer/Log
@onready var voxelization_information = $VoxelizationInformation
@onready var depth_choice = $VoxelizationInformation/MarginContainer/VBoxContainer/Depth/DepthChoice
@onready var format_choice = $VoxelizationInformation/MarginContainer/VBoxContainer/Format/FormatChoice

var depth_id = 7
var format_id = 0

var flight_navigation_3d_scene: FlightNavigation3D = null:
	set(value):
		flight_navigation_3d_scene = value
		if flight_navigation_3d_scene != null:
			flight_navigation_3d_scene.build_log.connect(_on_log_received)
			
var th := Thread.new()

func _ready():
	(depth_choice.get_popup() as PopupMenu).id_pressed.connect(_on_depth_choice_id_pressed)
	(format_choice.get_popup() as PopupMenu).id_pressed.connect(_on_format_choice_id_pressed)
	
	_on_depth_choice_id_pressed(depth_id)
	_on_format_choice_id_pressed(format_id)


func get_format() -> String:
	match format_id:
		0:
			return ".res"
		1:
			return ".tres"
	return ""

func _on_depth_choice_id_pressed(id) -> void:
	depth_id = id
	var item_idx = depth_choice.get_popup().get_item_index(id)
	depth_choice.text = depth_choice.get_popup().get_item_text(item_idx)
	var resolution = 2**(int(id)+2)
	$VoxelizationInformation/MarginContainer/VBoxContainer/Depth/HBoxContainer/ComputedResolution.text = "%dx%dx%d" % [resolution, resolution, resolution]
	
func _on_format_choice_id_pressed(id) -> void:
	format_id = id
	var item_idx = format_choice.get_popup().get_item_index(id)
	format_choice.text = format_choice.get_popup().get_item_text(item_idx)

func _on_pressed() -> void:
	voxelization_information.show()
	for index in range(depth_choice.get_popup().item_count):
		if depth_choice.text == depth_choice.get_popup().get_item_text(index):
			depth_id = depth_choice.get_popup().get_item_id(index)
	
func _on_confirm_voxelize_pressed() -> void:
	voxelization_information.hide()
	$ProgressDialog.show()
	progress_dialog.text = ""
	var parameters = FlightNavigation3DParameter.new()
	parameters.depth = int(depth_id)
	parameters.self_validate = true
	
	var svo = await flight_navigation_3d_scene.build_navigation_data(parameters)
	var existing_svo = flight_navigation_3d_scene.sparse_voxel_octree
	var resource_path = ""
	if existing_svo == null:
		resource_path = "%s%s" % [flight_navigation_3d_scene.name, format_choice.text]
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

func _on_voxelization_information_close_requested() -> void:
	voxelization_information.hide()

func _on_log_received(log: String, time_string: String, time_elapsed: int):
	progress_dialog.text += "[%s][%dms] %s\n" % [time_string, time_elapsed, log]

func _on_progress_dialog_close_requested() -> void:
	$ProgressDialog.hide()

func _exit_tree() -> void:
	if flight_navigation_3d_scene != null:
		flight_navigation_3d_scene.build_log.disconnect(_on_log_received)
