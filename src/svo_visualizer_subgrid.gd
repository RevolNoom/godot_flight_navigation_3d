## Draw only subgrid voxels of an [SVO].
@tool
@warning_ignore_start("integer_division")
extends ISvoVisualizer
class_name SvoVisualizerSubgrid

const multi_threading_enabled: bool = true
const multi_threading_priority: Thread.Priority = Thread.PRIORITY_LOW

@onready var debug_draw_voxel: MultiMeshInstance3D = \
	get_node("Voxel") as MultiMeshInstance3D


func draw(fn3d: FlightNavigation3D):
	if fn3d == null:
		printerr("SvoVisualizerSubgrid.draw(): fn3d is null.")
		return
	var concrete_svo: SVO = fn3d.sparse_voxel_octree
	if concrete_svo == null:
		printerr("SvoVisualizerSubgrid.draw(): fn3d.sparse_voxel_octree is null.")
		return

	await _draw_solid_voxels(fn3d, concrete_svo)


func _draw_solid_voxels(fn3d: FlightNavigation3D, concrete_svo: SVO):
	var async_context: Signal = fn3d.get_tree().process_frame
	var list_solid_bit_count_by_subgrid: PackedInt64Array = []
	if multi_threading_enabled:
		list_solid_bit_count_by_subgrid = \
			await concrete_svo.parallel_get_list_solid_bit_count_by_subgrid(
				async_context,
				multi_threading_priority
			)
	else:
		list_solid_bit_count_by_subgrid = \
			concrete_svo.get_list_solid_bit_count_by_subgrid()

	var total_solid_bit_count: int = \
		Fn3dUtility.sum_number_array(list_solid_bit_count_by_subgrid)
	var list_start_write_index: PackedInt64Array = \
		Parallel.make_start_write_index_array_from_count_array(
			list_solid_bit_count_by_subgrid
		)

	var list_voxel_transform: Array[Transform3D] = []
	list_voxel_transform.resize(total_solid_bit_count)

	var voxel_size = FlightNavigation3D.calculate_node_size(
		fn3d.size,
		-2,
		concrete_svo.depth
	)
	var origin_offset: Vector3 = fn3d.morton_origin_offset()

	if multi_threading_enabled:
		await Parallel.execute_batched(
			async_context,
			concrete_svo.subgrid.size(),
			multi_threading_priority,
			100000,
			_parallel_batched_write_subgrid_voxel_transforms.bind(
				concrete_svo.subgrid,
				concrete_svo.morton[0],
				voxel_size,
				origin_offset,
				list_start_write_index,
				list_voxel_transform
			)
		)
	else:
		_parallel_batched_write_subgrid_voxel_transforms(
			0,
			0,
			concrete_svo.subgrid.size(),
			concrete_svo.subgrid,
			concrete_svo.morton[0],
			voxel_size,
			origin_offset,
			list_start_write_index,
			list_voxel_transform
		)

	if debug_draw_voxel.multimesh == null:
		printerr(
			"SvoVisualizerSubgrid.draw(): " +
			"Voxel must have a MultiMesh assigned in scene."
		)
		return
	debug_draw_voxel.multimesh.instance_count = total_solid_bit_count
	debug_draw_voxel.multimesh.transform_format = \
		MultiMesh.TransformFormat.TRANSFORM_3D

	if debug_draw_voxel.multimesh.mesh == null:
		printerr(
			"SvoVisualizerSubgrid.draw(): " +
			"Voxel.multimesh.mesh must be assigned in scene."
		)
		return
	debug_draw_voxel.multimesh.mesh.size = voxel_size * 0.95

	if multi_threading_enabled:
		await Parallel.execute_batched(
			async_context,
			total_solid_bit_count,
			multi_threading_priority,
			100000,
			_parallel_batched_write_multimesh_instance_transforms.bind(
				debug_draw_voxel.multimesh,
				list_voxel_transform
			)
		)
	else:
		_parallel_batched_write_multimesh_instance_transforms(
			0,
			0,
			total_solid_bit_count,
			debug_draw_voxel.multimesh,
			list_voxel_transform
		)


static func _parallel_batched_write_subgrid_voxel_transforms(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	svo_subgrid: PackedInt64Array,
	svo_morton_layer0: PackedInt64Array,
	voxel_size: Vector3,
	origin_offset: Vector3,
	list_start_write_index: PackedInt64Array,
	list_voxel_transform: Array[Transform3D]
):
	var node_0_size: Vector3 = voxel_size * 4
	for layer0_offset in range(batch_start, batch_end):
		if svo_subgrid[layer0_offset] == 0:
			continue
		var start_write_index: int = list_start_write_index[layer0_offset]
		var node_position: Vector3 = origin_offset + \
			node_0_size * Morton3.decode_vec3(svo_morton_layer0[layer0_offset])
		var solid_voxel_count: int = 0
		for voxel_index in range(64):
			if svo_subgrid[layer0_offset] & (1 << voxel_index):
				var voxel_position_offset: Vector3 = voxel_size * (
					Morton3.decode_vec3(voxel_index) + Vector3(0.5, 0.5, 0.5)
				)
				var voxel_final_position: Vector3 = \
					node_position + voxel_position_offset
				var write_index: int = start_write_index + solid_voxel_count
				list_voxel_transform[write_index] = \
					Transform3D(Basis(), voxel_final_position)
				solid_voxel_count += 1


static func _parallel_batched_write_multimesh_instance_transforms(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	multimesh: MultiMesh,
	list_transform: Array[Transform3D]
):
	for index in range(batch_start, batch_end):
		multimesh.set_instance_transform(index, list_transform[index])
