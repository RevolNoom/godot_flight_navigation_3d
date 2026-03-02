## Draw selected SVO links as individual debug boxes.
@tool
extends ISvoVisualizer
class_name SvoVisualizerLink

const SvoLink64 = preload("res://src/svo_link64.gd")

## [svolink:int] -> [is_node:bool]
@export var svolink_is_node: Dictionary = {}
@export var node_color: Color = Color.RED
@export var leaf_color: Color = Color.GREEN

@onready var svo_nodes: Node3D = \
	get_node("SvoNodes") as Node3D
@onready var voxels: MultiMeshInstance3D = \
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
	if svo_nodes == null:
		printerr("SvoVisualizerLink.draw(): missing SvoNodes node.")
		return
	if voxels == null:
		printerr("SvoVisualizerLink.draw(): missing Voxels node.")
		return

	_clear_svo_node_boxes()
	_clear_voxel_instances()
	var voxel_transforms: Array[Transform3D] = []
	for key in svolink_is_node.keys():
		var svolink: int = int(key)
		var is_node: bool = bool(svolink_is_node[key])
		if is_node:
			_draw_svo_node_box(fn3d, concrete_svo, svolink, node_color)
		else:
			var voxel_position: Vector3 = _get_global_position_of(
				fn3d,
				concrete_svo,
				svolink,
				false
			)
			voxel_transforms.push_back(Transform3D(Basis(), voxel_position))

	_draw_voxel_instances(fn3d, concrete_svo, voxel_transforms)


func add(svolink: int, is_node: bool):
	svolink_is_node[svolink] = is_node


func remove(svolink: int):
	svolink_is_node.erase(svolink)


func _draw_svo_node_box(
	fn3d: FlightNavigation3D,
	svo: SVO,
	svolink: int,
	in_node_color: Color,
	text = null) -> MeshInstance3D:
	var cube := MeshInstance3D.new()
	var cube_mesh := BoxMesh.new()
	cube.mesh = cube_mesh
	var label := Label3D.new()
	label.name = "Label3D"
	cube.add_child(label)

	cube_mesh.material = StandardMaterial3D.new()
	cube_mesh.material.transparency = \
		BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
	label.text = text if text != null else SvoLink64.singleton.get_format_string(svolink)

	var layer: int = SvoLink64.singleton.get_layer(svolink)
	cube_mesh.size = FlightNavigation3D.calculate_node_size(
		fn3d.size,
		layer,
		svo.depth
	)
	cube_mesh.material.albedo_color = in_node_color
	label.pixel_size = cube_mesh.size.x / 400
	cube_mesh.material.albedo_color.a = 0.2
	svo_nodes.add_child(cube)
	cube.global_position = _get_global_position_of(
		fn3d,
		svo,
		svolink,
		true
	)
	return cube


func _draw_voxel_instances(
	fn3d: FlightNavigation3D,
	svo: SVO,
	voxel_transforms: Array[Transform3D]
):
	if voxels.multimesh == null:
		printerr("SvoVisualizerLink.draw(): Voxels node must have a MultiMesh.")
		return

	var multimesh: MultiMesh = voxels.multimesh
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


func _get_global_position_of(
	fn3d: FlightNavigation3D,
	svo: SVO,
	svolink: int,
	draw_as_node: bool) -> Vector3:
	var voxel_size = FlightNavigation3D.calculate_node_size(fn3d.size, -2, svo.depth)
	var layer: int = SvoLink64.singleton.get_layer(svolink)
	var offset: int = SvoLink64.singleton.get_offset(svolink)
	var morton_code: int = svo.morton[layer][offset]

	if layer == 0 and not draw_as_node:
		var voxel_morton = (morton_code << 6) | SvoLink64.singleton.get_subgrid(svolink)
		var half_a_voxel = Vector3(0.5, 0.5, 0.5)
		return fn3d.global_transform * (
			(Morton3.decode_vec3(voxel_morton) + half_a_voxel) *
			voxel_size +
			fn3d.morton_origin_offset()
		)

	var half_a_node = Vector3(0.5, 0.5, 0.5)
	return fn3d.global_transform * (
		(Morton3.decode_vec3(morton_code) + half_a_node) *
		FlightNavigation3D.calculate_node_size(fn3d.size, layer, svo.depth) +
		fn3d.morton_origin_offset()
	)


func _clear_svo_node_boxes():
	for child in svo_nodes.get_children():
		svo_nodes.remove_child(child)
		child.queue_free()


func _clear_voxel_instances():
	if voxels.multimesh != null:
		voxels.multimesh.instance_count = 0
