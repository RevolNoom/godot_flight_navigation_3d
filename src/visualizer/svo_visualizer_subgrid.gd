## Draw only subgrid voxels of an [SVO].
@tool
@warning_ignore_start("integer_division")
extends ASvoVisualizer
class_name SvoVisualizerSubgrid

## Whether to use multithreading when processing subgrid voxels.[br]
@export var multi_threading_enabled: bool = true
## Thread priority used for asynchronous operations.[br]
@export var multi_threading_priority: Thread.Priority = Thread.PRIORITY_LOW

## MultiMeshInstance3D displaying subgrid voxels.[br]
@onready var voxels: MultiMeshInstance3D = \
	get_node("Voxels") as MultiMeshInstance3D


func _ready() -> void:
	if voxels == null:
		push_warning("SvoVisualizerSubgrid: missing child node Voxels")
		return
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TransformFormat.TRANSFORM_3D
	voxels.multimesh = multimesh
	var boxmesh: BoxMesh = BoxMesh.new()
	boxmesh.material = StandardMaterial3D.new()
	voxels.multimesh.mesh = boxmesh


## [param fn3d]: Target FlightNavigation3D node to visualize[br]
## Return: void.[br]
func draw(fn3d: FlightNavigation3D) -> void:
	if not _validate_draw_target(fn3d):
		return
	var concrete_svo: SVO = fn3d.sparse_voxel_octree
	var voxel_mesh: BoxMesh = voxels.multimesh.mesh as BoxMesh

	var async_context: Signal = get_tree().process_frame
	var list_solid_bit_count_by_subgrid: PackedInt64Array = \
		await _get_solid_bit_counts(concrete_svo, async_context)

	var total_solid_bit_count: int = \
		Fn3dUtility.sum_number_array(list_solid_bit_count_by_subgrid)
	var list_start_write_index: PackedInt64Array = \
		Parallel.make_start_write_index_array_from_count_array(
			list_solid_bit_count_by_subgrid
		)

	var list_voxel_transform: Array[Transform3D] = []
	list_voxel_transform.resize(total_solid_bit_count)

	var voxel_size: Vector3 = FlightNavigation3D.calculate_node_size(
		fn3d.size,
		-2,
		concrete_svo.depth
	)
	var origin_offset: Vector3 = fn3d.morton_origin_offset()

	await _populate_voxel_transforms(
		async_context,
		concrete_svo,
		voxel_size,
		origin_offset,
		list_start_write_index,
		list_voxel_transform
	)

	voxels.multimesh.instance_count = total_solid_bit_count
	voxel_mesh.size = voxel_size * 0.95

	await _apply_transforms_to_multimesh(
		async_context,
		total_solid_bit_count,
		list_voxel_transform
	)


## Validates that fn3d, its SVO, and the voxels MultiMesh are valid for drawing.[br]
## [param fn3d]: FlightNavigation3D target node[br]
## Return: true if all requirements are met, false otherwise.[br]
func _validate_draw_target(fn3d: FlightNavigation3D) -> bool:
	if fn3d == null:
		printerr("SvoVisualizerSubgrid.draw(): fn3d is null.")
		return false
	var concrete_svo: SVO = fn3d.sparse_voxel_octree
	if concrete_svo == null:
		printerr("SvoVisualizerSubgrid.draw(): fn3d.sparse_voxel_octree is null.")
		return false
	if voxels == null:
		printerr("SvoVisualizerSubgrid.draw(): missing child node Voxels.")
		return false
	if voxels.multimesh == null:
		printerr("SvoVisualizerSubgrid.draw(): Voxels node must have a MultiMesh.")
		return false
	if voxels.multimesh.mesh == null:
		printerr("SvoVisualizerSubgrid.draw(): Voxels.multimesh.mesh must be assigned.")
		return false
	var voxel_mesh: BoxMesh = voxels.multimesh.mesh as BoxMesh
	if voxel_mesh == null:
		printerr("SvoVisualizerSubgrid.draw(): Voxels.multimesh.mesh must be BoxMesh.")
		return false
	return true


## Retrieves solid bit counts per subgrid using multithreading or synchronous fallback.[br]
## [param concrete_svo]: SVO instance to read subgrid counts from[br]
## [param async_context]: Signal to yield on during asynchronous processing[br]
## Return: packed array containing the number of solid bits per subgrid.[br]
func _get_solid_bit_counts(
	concrete_svo: SVO,
	async_context: Signal
) -> PackedInt64Array:
	if multi_threading_enabled:
		return await concrete_svo.parallel_get_list_solid_bit_count_by_subgrid(
			async_context,
			multi_threading_priority
		)
	return concrete_svo.get_list_solid_bit_count_by_subgrid()


## Populates subgrid voxel transforms using multithreading or synchronous fallback.[br]
## [param async_context]: Signal to yield on during asynchronous processing[br]
## [param concrete_svo]: SVO instance containing subgrid and morton data[br]
## [param voxel_size]: Size of each individual voxel[br]
## [param origin_offset]: Morton origin offset[br]
## [param list_start_write_index]: Starting write indices for subgrids[br]
## [param list_voxel_transform]: Destination array for voxel transforms[br]
## Return: void.[br]
func _populate_voxel_transforms(
	async_context: Signal,
	concrete_svo: SVO,
	voxel_size: Vector3,
	origin_offset: Vector3,
	list_start_write_index: PackedInt64Array,
	list_voxel_transform: Array[Transform3D]
) -> void:
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


## Writes instance transforms to MultiMesh using multithreading or synchronous fallback.[br]
## [param async_context]: Signal to yield on during asynchronous processing[br]
## [param total_solid_bit_count]: Total number of solid instances to write[br]
## [param list_voxel_transform]: Source array of Transform3D[br]
## Return: void.[br]
func _apply_transforms_to_multimesh(
	async_context: Signal,
	total_solid_bit_count: int,
	list_voxel_transform: Array[Transform3D]
) -> void:
	if multi_threading_enabled:
		await Parallel.execute_batched(
			async_context,
			total_solid_bit_count,
			multi_threading_priority,
			100000,
			_parallel_batched_write_multimesh_instance_transforms.bind(
				voxels.multimesh,
				list_voxel_transform
			)
		)
	else:
		_parallel_batched_write_multimesh_instance_transforms(
			0,
			0,
			total_solid_bit_count,
			voxels.multimesh,
			list_voxel_transform
		)


## Batched parallel callback to write voxel transforms from subgrid bitmasks.[br]
## [param _batch_index]: Unused batch index[br]
## [param batch_start]: Start index for this batch[br]
## [param batch_end]: End index for this batch[br]
## [param svo_subgrid]: SVO subgrid bitmasks[br]
## [param svo_morton_layer0]: Morton codes for layer 0[br]
## [param voxel_size]: Calculated voxel size[br]
## [param origin_offset]: Morton origin offset[br]
## [param list_start_write_index]: Starting write indices for subgrids[br]
## [param list_voxel_transform]: Destination transform array[br]
## Return: void.[br]
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
) -> void:
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


## Batched parallel callback to write instance transforms to MultiMesh.[br]
## [param _batch_index]: Unused batch index[br]
## [param batch_start]: Start index for this batch[br]
## [param batch_end]: End index for this batch[br]
## [param multimesh]: Target MultiMesh[br]
## [param list_transform]: Source array of Transform3D[br]
## Return: void.[br]
static func _parallel_batched_write_multimesh_instance_transforms(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	multimesh: MultiMesh,
	list_transform: Array[Transform3D]
) -> void:
	for index in range(batch_start, batch_end):
		multimesh.set_instance_transform(index, list_transform[index])
