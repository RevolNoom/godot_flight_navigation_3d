@tool
extends EditorPlugin


## The "Voxelize" button that shows on 3D editor menu
var voxelize_button 

## Reference to the [FlightNavigation3D] that's currently active.[br]
## Is null if the active scene isn't [FlightNavigation3D] 
var flight_navigation_3d_scene: FlightNavigation3D

var svo_data_loader: SVODataLoader = SVODataLoader.new()
var svo_data_saver: SVODataSaver = SVODataSaver.new()

# Initialization of the plugin goes here.
func _enter_tree():
	ResourceSaver.add_resource_format_saver(svo_data_saver)
	ResourceLoader.add_resource_format_loader(svo_data_loader)

	# Add voxelize button to 3d-editor screen
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	voxelize_button = preload("res://addons/flight_navigation_3d/voxelize_button.tscn").instantiate()
	voxelize_button.pressed.connect(_on_voxelize_pressed)
	voxelize_button.warning_confirmed.connect(_on_warning_dialog_confirmed)


var voxelize_thread: Thread
var physics_server_prior_state: bool = false
func _on_voxelize_pressed():
	voxelize_button.show_warning_dialog()

func _on_warning_dialog_confirmed():
	# Activate physic engine to let FlightNavigation3D catches some 
	# objects to voxelize
	PhysicsServer3D.set_active(true)
	get_tree().create_timer(0.2).timeout.connect(_on_voxelize_timer_timeout)


func _on_voxelize_timer_timeout():
	voxelize_button.show_please_wait()
	var depth = voxelize_button.depth_choice.text.to_int()
	var svo = flight_navigation_3d_scene.voxelize(depth)
	
	# Deactivate physic engine after we're done
	PhysicsServer3D.set_active(false)
	# TODO: I can't seem to get it right with the custom resource format saver/loader
	# So, save unnecessary informations (svonode's neighbors) for now
	svo.resource_path = "res://svo.res" 
	var save_error = ResourceSaver.save(svo)
	
	if save_error != OK:
		voxelize_button.show_save_svo_error("Can't save SVO resource. Error code: %d" % save_error)
	else:
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
	ResourceSaver.add_resource_format_saver(svo_data_saver)
	ResourceLoader.add_resource_format_loader(svo_data_loader)
	
	# Clean-up of the plugin goes here.
	voxelize_button.pressed.disconnect(_on_voxelize_pressed)
	voxelize_button.warning_confirmed.disconnect(_on_warning_dialog_confirmed)
	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	
	# Erase the control from the memory.
	if flight_navigation_3d_scene != null:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, voxelize_button)
	voxelize_button.free()
