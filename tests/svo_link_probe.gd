## SVOLinkProbe - Runtime voxel/node inspection tool
##
## Add as a child of Camera3D to enable interactive SVOLink querying.
## Move mouse to project a probe sphere into the world, click to query SVOLink.
@tool
extends Node3D
class_name SVOLinkProbe


## Distance from camera to project the probe sphere
@export var probe_distance: float = 0.2:
	set(value):
		probe_distance = value
		_update_probe_position()

## Reference to the FlightNavigation3D to query
@export var flight_navigation: FlightNavigation3D:
	set(value):
		flight_navigation = value
		update_configuration_warnings()

## Size of the probe sphere indicator
@export var sphere_radius: float = 0.1

## Color of the probe sphere
@export var sphere_color: Color = Color.YELLOW

## Font size for the 3D label
@export var label_font_size: int = 32

## Whether to show the probe sphere
@export var show_probe: bool = true:
	set(value):
		show_probe = value
		if _sphere_mesh:
			_sphere_mesh.visible = value

# Internal nodes
var _camera: Camera3D
var _sphere_mesh: MeshInstance3D
var _box_mesh: MeshInstance3D
var _label_3d: Label3D
var _current_svolink: int = SvoLink64.singleton.null_link()
var _mouse_position: Vector2 = Vector2.ZERO
var _is_mouse_pressed: bool = false

func _ready():
	
	# Create sphere mesh for probe visualization
	_sphere_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = sphere_radius
	sphere.height = sphere_radius * 2
	_sphere_mesh.mesh = sphere
	
	var material = StandardMaterial3D.new()
	material.albedo_color = sphere_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.7
	_sphere_mesh.material_override = material
	_sphere_mesh.visible = show_probe
	add_child(_sphere_mesh)
	
	# Create box mesh for voxel visualization
	_box_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3.ONE
	_box_mesh.mesh = box
	
	var box_material = StandardMaterial3D.new()
	box_material.albedo_color = Color(0.0, 1.0, 1.0, 0.3)  # Cyan with transparency
	box_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box_mesh.material_override = box_material
	_box_mesh.visible = false
	add_child(_box_mesh)
	
	# Create 3D label for displaying SVOLink
	_label_3d = Label3D.new()
	_label_3d.text = ""
	_label_3d.font_size = label_font_size
	_label_3d.modulate = Color.WHITE
	_label_3d.outline_modulate = Color.BLACK
	_label_3d.outline_size = 4
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_3d.visible = false
	_label_3d.pixel_size = 0.001
	add_child(_label_3d)

	# Get parent camera
	_camera = get_parent() as Camera3D
	if not _camera:
		push_error("SVOLinkProbe must be a child of Camera3D")
		return


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if not get_parent() is Camera3D:
		warnings.push_back("SVOLinkProbe must be a child of Camera3D")
	
	if not flight_navigation:
		warnings.push_back("FlightNavigation3D reference is not set")
	
	return warnings


func _input(event):
	if not _camera or not flight_navigation:
		return
	
	# Track mouse motion
	if event is InputEventMouseMotion:
		_mouse_position = event.position
		_update_probe_position()
	
	# Handle mouse button press
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_mouse_pressed = true
				_on_mouse_click()
			else:
				_is_mouse_pressed = false
				_label_3d.visible = false


func _process(_delta):
	# Update current SVOLink at probe position
	if flight_navigation and flight_navigation.sparse_voxel_octree:
		_current_svolink = flight_navigation.get_svolink_of(_sphere_mesh.global_position)
	else:
		_current_svolink = SvoLink64.singleton.null_link()
	
	# Update box visualization continuously (handles camera movement)
	_update_box_visualization()
	
	# Update label visibility and position based on mouse press state
	if _is_mouse_pressed and _current_svolink != SvoLink64.singleton.null_link():
		_label_3d.visible = true
		_label_3d.global_position = _sphere_mesh.global_position + Vector3(0, sphere_radius * 3, 0)
	#else:
		#_label_3d.visible = false


func _update_probe_position():
	if not _camera or not _sphere_mesh:
		return
	
	# Project mouse position into 3D world
	var from = _camera.project_ray_origin(_mouse_position)
	var direction = _camera.project_ray_normal(_mouse_position)
	var probe_position = from + direction * probe_distance
	
	_sphere_mesh.global_position = probe_position


func _on_mouse_click():
	if not flight_navigation or not flight_navigation.sparse_voxel_octree:
		print("SVOLinkProbe: FlightNavigation3D or SVO not available")
		return
	
	if _current_svolink == SvoLink64.singleton.null_link():
		print("SVOLinkProbe: No valid SVOLink at probe position")
		return
	
	# Print SVOLink information to console
	var layer = SvoLink64.singleton.get_layer(_current_svolink)
	var offset = SvoLink64.singleton.get_offset(_current_svolink)
	var subgrid = SvoLink64.singleton.get_subgrid(_current_svolink)
	var subgrid_vec3 = Morton3.decode_vec3i(subgrid)
	
	print("=== SVOLink Probe ===")
	print("SVOLink: ", _current_svolink)
	print("Layer: ", layer)
	print("Offset: ", offset)
	print("Subgrid: ", subgrid, " (", subgrid_vec3, ")")
	print("Position: ", _sphere_mesh.global_position)
	
	# Check if solid
	if flight_navigation.sparse_voxel_octree.support_inside:
		var is_solid = flight_navigation.sparse_voxel_octree.is_solid(_current_svolink)
		print("Is Solid: ", is_solid)
	
	print("====================")
	
	# Update label text
	_update_label_text()


func _update_label_text():
	if _current_svolink == SvoLink64.singleton.null_link():
		_label_3d.text = "NULL"
		return
	
	var layer = SvoLink64.singleton.get_layer(_current_svolink)
	var offset = SvoLink64.singleton.get_offset(_current_svolink)
	var subgrid = SvoLink64.singleton.get_subgrid(_current_svolink)
	
	var text = "SVOLink: %d\nL:%d O:%d S:%d" % [_current_svolink, layer, offset, subgrid]
	
	# Add solid state if available
	if flight_navigation and flight_navigation.sparse_voxel_octree and flight_navigation.sparse_voxel_octree.support_inside:
		var is_solid = flight_navigation.sparse_voxel_octree.is_solid(_current_svolink)
		text += "\nSolid: %s" % ("Yes" if is_solid else "No")
	
	_label_3d.text = text


func _update_box_visualization():
	if not _box_mesh:
		return
	
	if _current_svolink == SvoLink64.singleton.null_link() or not flight_navigation or not flight_navigation.sparse_voxel_octree:
		_box_mesh.visible = false
		return
	
	# Get the layer and calculate the voxel/node size
	var layer = SvoLink64.singleton.get_layer(_current_svolink)
	var svo = flight_navigation.sparse_voxel_octree
	var box_size: Vector3
	_label_3d.visible = true
	if layer == 0:
		box_size = FlightNavigation3D.calculate_node_size(flight_navigation.size, -2, svo.depth)
	else:
		box_size = FlightNavigation3D.calculate_node_size(flight_navigation.size, layer, svo.depth)
	_label_3d.text = str(box_size)
	
	# Get the center position of the voxel/node
	var center_position = flight_navigation.get_global_position_of(_current_svolink)
	
	# Update box mesh transform to match FlightNavigation transform basis.
	# Using only global_rotation drops scale and causes incorrect box sizes.
	_box_mesh.global_transform = Transform3D(
		flight_navigation.global_basis,
		center_position)
	_box_mesh.mesh.size = box_size
	_box_mesh.visible = true
