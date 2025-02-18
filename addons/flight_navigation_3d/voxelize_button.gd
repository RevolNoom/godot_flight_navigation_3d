@tool
extends Control

@onready var progress_dialog = $ProgressDialog
@onready var voxelization_information = $VoxelizationInformation
@onready var depth_choice = $VoxelizationInformation/MarginContainer/VBoxContainer/Depth/DepthChoice
@onready var format_choice = $VoxelizationInformation/MarginContainer/VBoxContainer/Format/FormatChoice

var depth_id = 5
var format_id = 0

var flight_navigation_3d_scene: FlightNavigation3D = null

func _ready():
	(depth_choice.get_popup() as PopupMenu).id_pressed.connect(_on_depth_choice_id_pressed)
	(format_choice.get_popup() as PopupMenu).id_pressed.connect(_on_format_choice_id_pressed)
	
	depth_choice.text = depth_choice.get_popup().get_item_text(depth_id)
	format_choice.text = format_choice.get_popup().get_item_text(format_id)
	
	if flight_navigation_3d_scene != null:
		flight_navigation_3d_scene.progress_get_all_flight_navigation_targets_start.connect(
			_on_log_received.bind("Start getting all flight navigation targets"))

		flight_navigation_3d_scene.progress_get_all_flight_navigation_targets_end.connect(
			func (number_of_targets: int):
				_on_log_received("Got %d targets" % number_of_targets))

func get_format() -> String:
	match format_id:
		0:
			return ".res"
		1:
			return ".tres"
	return ""

func _on_depth_choice_id_pressed(id) -> void:
	depth_id = id
	depth_choice.text = depth_choice.get_popup().get_item_text(depth_id)
	
func _on_format_choice_id_pressed(id) -> void:
	format_id = id
	format_choice.text = format_choice.get_popup().get_item_text(format_id)

func _on_pressed() -> void:
	voxelization_information.show()
	
func _on_confirm_voxelize_pressed() -> void:
	voxelization_information.hide()
	progress_dialog.show()
	var parameters = {
		"depth": int(depth_choice.text)
	}
	flight_navigation_3d_scene.build_navigation_data(parameters)

func _on_voxelization_information_close_requested() -> void:
	voxelization_information.hide()

func _on_log_received(log: String):
	$ProgressDialog/Log.text += log + "\n"

func _on_progress_dialog_close_requested() -> void:
	$ProgressDialog.hide()
