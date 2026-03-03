## Draw selected SVO layers as MultiMesh instances.
@tool
@warning_ignore_start("integer_division")
extends ISvoVisualizer
class_name SvoVisualizerLayer


@export var multithreading_enabled: bool = true
@export var multithreading_priority: Thread.Priority = \
	Thread.PRIORITY_LOW

@export var layer_enabled_by_index: Dictionary = {0: true, 1: true, 2: true, 3: true, 4: true, 5: true, 6: true, 7: true, 8: true, 9: true, 10: true, 11: true, 12: true, 13: true, 14: true, 15: true}

func _ready():
	for layer_index in range(16):
		var instance: MultiMeshInstance3D = _get_layer_instance(layer_index)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TransformFormat.TRANSFORM_3D
		var boxmesh := BoxMesh.new()
		boxmesh.material = StandardMaterial3D.new()
		multimesh.mesh = boxmesh
		instance.multimesh = multimesh

func draw(fn3d: FlightNavigation3D):
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
		var instance: MultiMeshInstance3D = _get_layer_instance(layer_index)

		if not get_draw_layer(layer_index):
			_clear_layer_instance(instance)
			continue
		if layer_index >= concrete_svo.depth:
			_clear_layer_instance(instance)
			continue

		var draw_flag: PackedByteArray = PackedByteArray()
		draw_flag.resize(concrete_svo.inside[layer_index].size())
		draw_flag.fill(0)
		for offset in range(draw_flag.size()):
			draw_flag[offset] = int(
				concrete_svo.is_solid(SvoLink64.singleton.create(layer_index, offset))
			)

		var count_result = await Parallel.count_by_batch(
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

		var multimesh: MultiMesh = instance.multimesh
		var node_size: Vector3 = FlightNavigation3D.calculate_node_size(
			fn3d.size,
			layer_index,
			concrete_svo.depth
		)
		var boxmesh: BoxMesh = multimesh.mesh as BoxMesh
		boxmesh.size = node_size * 0.95
		var material: StandardMaterial3D = \
			boxmesh.material as StandardMaterial3D
		material.albedo_color = Color(
			1.0 * (layer_index + 1) / concrete_svo.depth,
			randf(),
			1.0 - (layer_index + 1) / concrete_svo.depth
		)
		multimesh.instance_count = total_instance_count
		if multithreading_enabled:
			await Parallel.execute_batched(
				async_context,
				draw_flag.size(),
				multithreading_priority,
				batch_size,
				_parallel_batched_write_node_transforms.bind(
					draw_flag,
					concrete_svo.morton[layer_index],
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
					concrete_svo.morton[layer_index],
					multimesh,
					node_size,
					origin_offset,
					list_start_write_index
				)

func set_draw_layer(layer_index: int, enabled: bool):
	layer_enabled_by_index[layer_index] = enabled


func get_draw_layer(layer_index: int) -> bool:
	return layer_enabled_by_index[layer_index]


func _clear_debug_draw_svonode():
	for layer_index in range(16):
		var instance: MultiMeshInstance3D = _get_layer_instance(layer_index)
		_clear_layer_instance(instance)


func _get_layer_instance(layer_index: int) -> MultiMeshInstance3D:
	return get_node(
		"Layer_%d" % layer_index
	) as MultiMeshInstance3D


func _clear_layer_instance(instance: MultiMeshInstance3D):
	instance.multimesh.instance_count = 0


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
):
	var solid_node_count := 0
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
