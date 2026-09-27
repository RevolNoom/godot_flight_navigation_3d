@tool
extends EditorPlugin

## The "Voxelize" button that shows on 3D editor menu
var voxelize_button 

## Reference to selected [ASvoVoxelizer] in the editor.
var selected_svo_voxelizer: ASvoVoxelizer

# Initialization of the plugin goes here.
func _enter_tree():
	# Add voxelize button to 3d-editor screen
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	voxelize_button = preload("res://addons/flight_navigation_3d/voxelize_button.tscn").instantiate()


func _exit_tree():
	# Clean-up of the plugin goes here.
	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	
	# Erase the control from the memory.
	if selected_svo_voxelizer != null:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, voxelize_button)
	voxelize_button.free()

# Show the Voxelize button only if the editor is focusing on a [ASvoVoxelizer]
func _on_selection_changed():
	var selected_nodes: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	
	var is_single_node_selected: bool = selected_nodes.size() == 1
	var is_node_asvo_voxelizer: bool = is_single_node_selected and selected_nodes.front() is ASvoVoxelizer
	var is_current_voxelizer_selected: bool = is_node_asvo_voxelizer and selected_nodes.front() == selected_svo_voxelizer
	
	if selected_svo_voxelizer != null and not is_current_voxelizer_selected:
		selected_svo_voxelizer = null
		voxelize_button.svo_voxelizer = null
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, voxelize_button)
	
	if is_node_asvo_voxelizer and selected_svo_voxelizer == null:
		selected_svo_voxelizer = selected_nodes.front()
		voxelize_button.svo_voxelizer = selected_svo_voxelizer
		add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, voxelize_button)
