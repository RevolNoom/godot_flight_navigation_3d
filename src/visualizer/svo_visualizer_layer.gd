## Draw selected SVO layers as MultiMesh instances.
@tool
@warning_ignore_start("integer_division")
extends ASvoVisualizer
class_name SvoVisualizerLayer


## Whether to use multithreading when rendering layer instances.[br]
@export var multithreading_enabled: bool = true
## Thread priority used for asynchronous operations.[br]
@export var multithreading_priority: Thread.Priority = \
	Thread.PRIORITY_LOW

## Enabled status for each SVO layer index.[br]
@export var layer_enabled_by_index: Dictionary[int, bool] = {
	0: true, 1: true, 2: true, 3: true,
	4: true, 5: true, 6: true, 7: true,
	8: true, 9: true, 10: true, 11: true,
	12: true, 13: true, 14: true, 15: true,
}

func _ready() -> void:
	for layer_index in range(16):
		var instance: MultiMeshInstance3D = _get_layer_instance(layer_index)
		if instance == null:
			push_warning("SvoVisualizerLayer: missing child node Layer_%d" % layer_index)
			continue
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TransformFormat.TRANSFORM_3D
		var boxmesh: BoxMesh = BoxMesh.new()
		boxmesh.material = StandardMaterial3D.new()
		multimesh.mesh = boxmesh
		instance.multimesh = multimesh


## [param fn3d]: Target FlightNavigation3D node to visualize[br]
## Return: void.[br]
func draw(fn3d: FlightNavigation3D) -> void:
	if fn3d == null:
		printerr("SvoVisualizerLayer.draw(): fn3d is null.")
		return
	var concrete_svo: SVO = fn3d.sparse_voxel_octree
	if concrete_svo == null:
		printerr("SvoVisualizerLayer.draw(): fn3d.sparse_voxel_octree is null.")
		return

	_clear_debug_draw_svonode()
	if not concrete_svo.support_inside:
		return

	var async_context: Signal = get_tree().process_frame
	var origin_offset: Vector3 = fn3d.morton_origin_offset()

	for layer_index in range(16):
		await _draw_layer(
			fn3d,
			concrete_svo,
			async_context,
			origin_offset,
			layer_index
		)


## Draws a single SVO layer as MultiMesh instances.[br]
## [param fn3d]: Target FlightNavigation3D node to visualize[br]
## [param concrete_svo]: SVO containing node data[br]
## [param async_context]: Signal for asynchronous frame processing[br]
## [param origin_offset]: Morton origin offset[br]
## [param layer_index]: SVO layer index[br]
## Return: void.[br]
func _draw_layer(
	fn3d: FlightNavigation3D,
	concrete_svo: SVO,
	async_context: Signal,
	origin_offset: Vector3,
	layer_index: int
) -> void:
	var instance: MultiMeshInstance3D = _get_layer_instance(layer_index)
	if instance == null:
		return

	if not get_draw_layer(layer_index):
		_clear_layer_instance(instance)
		return
	if layer_index >= concrete_svo.depth:
		_clear_layer_instance(instance)
		return

	var draw_flag: PackedByteArray = _build_draw_flag(concrete_svo, layer_index)

	var count_result: Dictionary = await Parallel.count_by_batch(
		async_context,
		multithreading_priority,
		draw_flag,
		1
	)
	var list_solid_count_by_batch: PackedInt64Array = \
		count_result.list_count_by_batch
	var batch_size: int = count_result.batch_size
	var total_instance_count: int = \
		Fn3dUtility.sum_number_array(list_solid_count_by_batch)
	var list_start_write_index: PackedInt64Array = \
		Parallel.make_start_write_index_array_from_count_array(
			list_solid_count_by_batch
		)

	var node_size: Vector3 = _configure_layer_multimesh(
		instance,
		fn3d.size,
		layer_index,
		concrete_svo.depth,
		total_instance_count
	)
	if node_size == Vector3.ZERO:
		return

	await _render_layer_instances(
		async_context,
		draw_flag,
		concrete_svo.morton[layer_index],
		instance.multimesh,
		node_size,
		origin_offset,
		list_start_write_index,
		batch_size
	)


## Builds a draw flag byte array marking solid nodes for the given layer.[br]
## [param concrete_svo]: SVO containing node data[br]
## [param layer_index]: SVO layer index[br]
## Return: PackedByteArray where 1 indicates solid and 0 indicates non-solid.[br]
static func _build_draw_flag(
	concrete_svo: SVO,
	layer_index: int
) -> PackedByteArray:
	var draw_flag: PackedByteArray = []
	draw_flag.resize(concrete_svo.inside[layer_index].size())
	draw_flag.fill(0)
	for offset in range(draw_flag.size()):
		draw_flag[offset] = int(
			concrete_svo.is_solid(SvoLink64.singleton.create(layer_index, offset))
		)
	return draw_flag


## Configures MultiMesh and BoxMesh material for a layer, returning the node size.[br]
## [param instance]: MultiMeshInstance3D for the layer[br]
## [param fn3d_size]: Bounds size of FlightNavigation3D[br]
## [param layer_index]: SVO layer index[br]
## [param svo_depth]: Depth of the SVO[br]
## [param total_instance_count]: Total number of solid instances to display[br]
## Return: node size Vector3, or Vector3.ZERO if multimesh or boxmesh is null.[br]
static func _configure_layer_multimesh(
	instance: MultiMeshInstance3D,
	fn3d_size: Vector3,
	layer_index: int,
	svo_depth: int,
	total_instance_count: int
) -> Vector3:
	var multimesh: MultiMesh = instance.multimesh
	if multimesh == null:
		return Vector3.ZERO
	var node_size: Vector3 = FlightNavigation3D.calculate_node_size(
		fn3d_size,
		layer_index,
		svo_depth
	)
	var boxmesh: BoxMesh = multimesh.mesh as BoxMesh
	if boxmesh == null:
		return Vector3.ZERO
	boxmesh.size = node_size * 0.95
	var material: StandardMaterial3D = \
		boxmesh.material as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		boxmesh.material = material
	material.albedo_color = Color(
		1.0 * (layer_index + 1) / svo_depth,
		randf(),
		1.0 - (layer_index + 1) / svo_depth
	)
	multimesh.instance_count = total_instance_count
	return node_size


## Renders layer instances into the MultiMesh using multithreading or synchronous fallback.[br]
## [param async_context]: Signal for asynchronous frame processing[br]
## [param draw_flag]: PackedByteArray indicating which nodes to render[br]
## [param morton_layer]: PackedInt64Array of Morton codes for the layer[br]
## [param multimesh]: MultiMesh to populate transforms into[br]
## [param node_size]: Size of each voxel node[br]
## [param origin_offset]: Morton origin offset[br]
## [param list_start_write_index]: PackedInt64Array of batch start write indices[br]
## [param batch_size]: Batch size for parallel/batched execution[br]
## Return: void.[br]
func _render_layer_instances(
	async_context: Signal,
	draw_flag: PackedByteArray,
	morton_layer: PackedInt64Array,
	multimesh: MultiMesh,
	node_size: Vector3,
	origin_offset: Vector3,
	list_start_write_index: PackedInt64Array,
	batch_size: int
) -> void:
	if multithreading_enabled:
		await Parallel.execute_batched(
			async_context,
			draw_flag.size(),
			multithreading_priority,
			batch_size,
			_parallel_batched_write_node_transforms.bind(
				draw_flag,
				morton_layer,
				multimesh,
				node_size,
				origin_offset,
				list_start_write_index
			)
		)
	else:
		for batch_index in range(list_start_write_index.size()):
			var batch_start: int = batch_index * batch_size
			var batch_end: int = mini(
				(batch_index + 1) * batch_size,
				draw_flag.size()
			)
			_parallel_batched_write_node_transforms(
				batch_index,
				batch_start,
				batch_end,
				draw_flag,
				morton_layer,
				multimesh,
				node_size,
				origin_offset,
				list_start_write_index
			)

func set_draw_layer(layer_index: int, enabled: bool) -> void:
	layer_enabled_by_index[layer_index] = enabled


func get_draw_layer(layer_index: int) -> bool:
	return layer_enabled_by_index.get(layer_index, false)


func _clear_debug_draw_svonode() -> void:
	for layer_index in range(16):
		var instance: MultiMeshInstance3D = _get_layer_instance(layer_index)
		if instance == null:
			continue
		_clear_layer_instance(instance)


func _get_layer_instance(layer_index: int) -> MultiMeshInstance3D:
	return get_node_or_null(
		"Layer_%d" % layer_index
	) as MultiMeshInstance3D


func _clear_layer_instance(instance: MultiMeshInstance3D) -> void:
	if instance.multimesh != null:
		instance.multimesh.instance_count = 0


## Batched parallel callback to write instance transforms for solid nodes.[br]
## [param batch_index]: Current batch index[br]
## [param batch_start]: Start offset for this batch[br]
## [param batch_end]: End offset for this batch[br]
## [param draw_flag]: PackedByteArray indicating solid nodes[br]
## [param morton_layer]: Morton codes for this layer[br]
## [param multimesh]: Target MultiMesh to write transforms to[br]
## [param node_size]: Size of each node[br]
## [param origin_offset]: Morton origin offset[br]
## [param list_start_write_index]: Starting write index array[br]
## Return: void.[br]
static func _parallel_batched_write_node_transforms(
	batch_index: int,
	batch_start: int,
	batch_end: int,
	draw_flag: PackedByteArray,
	morton_layer: PackedInt64Array,
	multimesh: MultiMesh,
	node_size: Vector3,
	origin_offset: Vector3,
	list_start_write_index: PackedInt64Array
) -> void:
	var solid_node_count: int = 0
	var start_write_index: int = list_start_write_index[batch_index]
	for offset in range(batch_start, batch_end):
		if not draw_flag[offset]:
			continue
		var node_position: Vector3 = node_size * (
			Morton3.decode_vec3(morton_layer[offset]) +
			Vector3(0.5, 0.5, 0.5)
		) + origin_offset
		var write_index: int = start_write_index + solid_node_count
		multimesh.set_instance_transform(
			write_index,
			Transform3D(Basis(), node_position)
		)
		solid_node_count += 1
