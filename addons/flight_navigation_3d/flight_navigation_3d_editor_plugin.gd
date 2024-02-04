@tool
extends EditorPlugin


## The "Voxelize" button that shows on 3D editor menu
var voxelize_button 

## Reference to the [FlightNavigation3D] that's currently active.[br]
## Is null if the active scene isn't [FlightNavigation3D] 
var flight_navigation_3d_scene: FlightNavigation3D

func _enter_tree():
	# Initialization of the plugin goes here.
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	voxelize_button = preload("res://addons/flight_navigation_3d/voxelize_button.tscn").instantiate() as Button
	voxelize_button.pressed.connect(_on_voxelize_pressed)


var voxelize_thread: Thread
func _on_voxelize_pressed():
	voxelize_thread = flight_navigation_3d_scene.voxelize_async()
	voxelize_button.show_please_wait()
	flight_navigation_3d_scene.finished.connect(_on_voxelization_completed)


func _on_voxelization_completed():
	if voxelize_button.please_wait_dialog:
		voxelize_button.please_wait_dialog.hide()
	flight_navigation_3d_scene.finished.disconnect(_on_voxelization_completed)
	voxelize_thread.wait_to_finish()
	voxelize_button.show_on_complete()


# Show the Voxelize button only if the editor is focusing on a [FlightNavigation3D]
func _on_selection_changed():
	if flight_navigation_3d_scene != null:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, voxelize_button)
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	if selected_nodes.size() == 1 and selected_nodes.front() is FlightNavigation3D:
		flight_navigation_3d_scene = selected_nodes.front()
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, voxelize_button)


func _exit_tree():
	# Clean-up of the plugin goes here.
	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	if flight_navigation_3d_scene != null:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, voxelize_button)
	
	# Erase the control from the memory.
	voxelize_button.free()
