## Draw selected SVO links as individual debug boxes.
@tool
extends ISvoVisualizer
class_name SvoVisualizerLink

## [svolink:int] -> [label_text:String]
@export var svo_nodes: Dictionary = {}
## [svolink:int] -> [label_text:String]
@export var voxels: Dictionary = {}
@export var node_color: Color = Color.RED
@export var leaf_color: Color = Color.GREEN

@onready var svo_nodes_root: Node3D = \
	get_node("SvoNodes") as Node3D
@onready var voxels_instance: MultiMeshInstance3D = \
	get_node("Voxels") as MultiMeshInstance3D


func draw(
	fn3d: FlightNavigation3D
):
	if fn3d == null:
		printerr("SvoVisualizerLink.draw(): fn3d is null.")
		return
	var concrete_svo: SVO = fn3d.sparse_voxel_octree
	if concrete_svo == null:
		printerr("SvoVisualizerLink.draw(): fn3d.sparse_voxel_octree is null.")
		return

	_clear_svo_node_boxes()
	_clear_voxel_instances()
	var voxel_transforms: Array[Transform3D] = []
	for key in svo_nodes.keys():
		var svolink: int = int(key)
		var label_text: String = str(svo_nodes[key])
		_draw_svo_node_box(fn3d, concrete_svo, svolink, node_color, label_text)

	for key in voxels.keys():
		var svolink: int = int(key)
		var voxel_position: Vector3 = fn3d.get_global_position_of(svolink)
		voxel_transforms.push_back(Transform3D(Basis(), voxel_position))

	_draw_voxel_instances(fn3d, concrete_svo, voxel_transforms)


func add_node(svolink: int, label_text: String = ""):
	svo_nodes[svolink] = label_text


func add_voxel(svolink: int, label_text: String = ""):
	voxels[svolink] = label_text


func remove_node(svolink: int):
	svo_nodes.erase(svolink)


func remove_voxel(svolink: int):
	voxels.erase(svolink)


func _draw_svo_node_box(
	fn3d: FlightNavigation3D,
	svo: SVO,
	svolink: int,
	in_node_color: Color,
	text: String) -> MeshInstance3D:
	var cube := MeshInstance3D.new()
	var cube_mesh := BoxMesh.new()
	cube.mesh = cube_mesh
	var label := Label3D.new()
	label.name = "Label3D"
	cube.add_child(label)

	cube_mesh.material = StandardMaterial3D.new()
	cube_mesh.material.transparency = \
		BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
	label.text = text

	var layer: int = SvoLink64.singleton.get_layer(svolink)
	cube_mesh.size = FlightNavigation3D.calculate_node_size(
		fn3d.size,
		layer,
		svo.depth
	)
	cube_mesh.material.albedo_color = in_node_color
	label.pixel_size = cube_mesh.size.x / 400
	cube_mesh.material.albedo_color.a = 0.2
	svo_nodes_root.add_child(cube)
	cube.global_position = fn3d.get_global_position_of(svolink)
	return cube


func _draw_voxel_instances(
	fn3d: FlightNavigation3D,
	svo: SVO,
	voxel_transforms: Array[Transform3D]
):
	if voxels_instance.multimesh == null:
		printerr("SvoVisualizerLink.draw(): Voxels node must have a MultiMesh.")
		return

	var multimesh: MultiMesh = voxels_instance.multimesh
	multimesh.transform_format = MultiMesh.TransformFormat.TRANSFORM_3D
	if multimesh.mesh == null:
		printerr("SvoVisualizerLink.draw(): Voxels.multimesh.mesh must be assigned.")
		return
	var voxel_mesh := multimesh.mesh as BoxMesh
	if voxel_mesh == null:
		printerr("SvoVisualizerLink.draw(): Voxels.multimesh.mesh must be BoxMesh.")
		return

	var voxel_size: Vector3 = FlightNavigation3D.calculate_node_size(
		fn3d.size,
		-2,
		svo.depth
	)
	voxel_mesh.size = voxel_size
	if voxel_mesh.material == null:
		voxel_mesh.material = StandardMaterial3D.new()
	voxel_mesh.material.transparency = \
		BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
	voxel_mesh.material.albedo_color = leaf_color
	voxel_mesh.material.albedo_color.a = 0.2

	multimesh.instance_count = voxel_transforms.size()
	for instance_index in range(voxel_transforms.size()):
		multimesh.set_instance_transform(
			instance_index,
			voxel_transforms[instance_index]
		)

func _clear_svo_node_boxes():
	for child in svo_nodes_root.get_children():
		svo_nodes_root.remove_child(child)
		child.queue_free()


func _clear_voxel_instances():
	if voxels_instance.multimesh != null:
		voxels_instance.multimesh.instance_count = 0
