@tool
extends EditorPlugin


## The "Voxelize" button that shows on 3D editor menu
var voxelize_button 

## Reference to the [FlightNavigation3D] that's currently active.[br]
## Is null if the active scene isn't [FlightNavigation3D] 
var flight_navigation_3d_scene: FlightNavigation3D

# Initialization of the plugin goes here.
func _enter_tree():
	# Add voxelize button to 3d-editor screen
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	voxelize_button = preload("res://addons/flight_navigation_3d/voxelize_button.tscn").instantiate()

# Show the Voxelize button only if the editor is focusing on a [FlightNavigation3D]
func _on_selection_changed():
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	
	if flight_navigation_3d_scene != null\
	and (selected_nodes.size() != 1\
	or not selected_nodes.front() is FlightNavigation3D\
	or flight_navigation_3d_scene != selected_nodes.front()):
		#print("Remove")
		flight_navigation_3d_scene = null
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, voxelize_button)
	
	if selected_nodes.size() == 1\
	and selected_nodes.front() is FlightNavigation3D\
	and flight_navigation_3d_scene == null:
		flight_navigation_3d_scene = selected_nodes.front()
		voxelize_button.flight_navigation_3d_scene = flight_navigation_3d_scene
		#print("Add")
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, voxelize_button)

func _exit_tree():
	# Clean-up of the plugin goes here.
	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	
	# Erase the control from the memory.
	if flight_navigation_3d_scene != null:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, voxelize_button)
	voxelize_button.free()
