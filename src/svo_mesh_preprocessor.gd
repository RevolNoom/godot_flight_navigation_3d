## Preprocessor for collecting, converting CSG geometry, filtering, and offsetting triangles.
@tool
extends RefCounted
class_name SvoMeshPreprocessor

signal progress(
	step: ProgressStep.Enum,
	svo: SVO,
	work_completed: int,
	total_work: int
)


## Collects all [VoxelizationTarget] nodes from the scene tree.[br]
## [param fn3d]: [FlightNavigation3D] node providing scene tree access.[br]
## Return: Array of [VoxelizationTarget] nodes found in the scene tree.[br]
static func collect_voxelization_targets(
	fn3d: FlightNavigation3D
) -> Array[VoxelizationTarget]:
	var list_voxelization_target: Array[VoxelizationTarget] = []
	for node: Node in fn3d.get_tree().get_nodes_in_group("voxelization_target"):
		var voxelization_target: VoxelizationTarget = node as VoxelizationTarget
		if voxelization_target != null:
			list_voxelization_target.push_back(voxelization_target)
	return list_voxelization_target


## [param list_targets]: List of [VoxelizationTarget] to filter in place.[br]
## [param mask]: Bitmask used to match target's voxelization_mask.[br]
func filter_voxelization_targets(
	list_targets: Array[VoxelizationTarget],
	mask: int
) -> void:
	progress.emit(ProgressStep.Enum.GET_ALL_VOXELIZATION_TARGET, null, 0, 1)
	Fn3dUtility.filter_in_place(
		list_targets,
		func (target: VoxelizationTarget, _index: int) -> bool:
			return target.voxelization_mask & mask != 0
	)
	progress.emit(ProgressStep.Enum.GET_ALL_VOXELIZATION_TARGET, null, 1, 1)


## [param fn3d]: [FlightNavigation3D] node owning voxelization target shapes.[br]
## [param targets]: Array of [VoxelizationTarget] to build CSG from.[br]
## [param async_context]: Context signal to await a frame for CSG baking.[br]
## [param debug_delete_csg]: Whether to remove and free CSG shapes after baking.[br]
## Return: [PackedVector3Array] of mesh faces.[br]
func build_mesh_from_csg(
	fn3d: FlightNavigation3D,
	targets: Array[VoxelizationTarget],
	async_context: Signal,
	debug_delete_csg: bool
) -> PackedVector3Array:
	progress.emit(ProgressStep.Enum.BUILD_MESH, null, 0, 1)
	var voxelization_target_shapes: Node = fn3d.get_node_or_null("VoxelizationTargetShapes")
	if voxelization_target_shapes == null:
		printerr("SvoMeshPreprocessor.build_mesh_from_csg(): missing child node 'VoxelizationTargetShapes'.")
		progress.emit(ProgressStep.Enum.BUILD_MESH, null, 1, 1)
		return []

	for child_shapes: Node in voxelization_target_shapes.get_children():
		voxelization_target_shapes.remove_child(child_shapes)
		child_shapes.free()

	for target: VoxelizationTarget in targets:
		var csg_shapes: Array[CSGShape3D] = target.get_csg()
		for shape: CSGShape3D in csg_shapes:
			voxelization_target_shapes.add_child(shape)
			shape.global_transform = target.global_transform
			shape.operation = CSGShape3D.OPERATION_UNION

	# Since CSG nodes do not update immediately, wait until next frame.
	await async_context
	var mesh: Mesh = fn3d.bake_static_mesh()
	if mesh == null:
		progress.emit(ProgressStep.Enum.BUILD_MESH, null, 1, 1)
		return []
	if debug_delete_csg:
		for child_shapes: Node in voxelization_target_shapes.get_children():
			voxelization_target_shapes.remove_child(child_shapes)
			child_shapes.free()

	var triangles: PackedVector3Array = mesh.get_faces()
	progress.emit(ProgressStep.Enum.BUILD_MESH, null, 1, 1)
	return triangles


## [param triangles]: Input triangles to clean.[br]
## [param async_context]: Context signal for asynchronous processing.[br]
## [param multi_threading_enabled]: Whether multi-threading is enabled.[br]
## [param multi_threading_priority]: Thread priority for parallel execution.[br]
## Return: Cleaned [PackedVector3Array] containing non-zero area triangles.[br]
func filter_thin_triangles(
	triangles: PackedVector3Array,
	async_context: Signal,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority
) -> PackedVector3Array:
	progress.emit(ProgressStep.Enum.REMOVE_THIN_TRIANGLES, null, 0, 1)

	var fat_triangle_count: int = 0
	var cleaned_triangles: PackedVector3Array = PackedVector3Array()
	if multi_threading_enabled:
		var count_result: Dictionary = await Parallel.count_if_by_batch(
			async_context,
			triangles.size() / 3,
			multi_threading_priority,
			10000,
			_parallel_is_non_zero_area_triangle.bind(triangles)
		)
		var batch_size: int = count_result.batch_size
		var list_count_if_by_batch: PackedInt64Array = count_result.list_count_if_by_batch
		fat_triangle_count = Fn3dUtility.sum_number_array(list_count_if_by_batch)
		cleaned_triangles.resize(fat_triangle_count * 3)

		var list_start_write_index: PackedInt64Array = \
			Parallel.make_start_write_index_array_from_count_array(list_count_if_by_batch)

		await Parallel.execute_batched(
			async_context,
			triangles.size() / 3,
			multi_threading_priority,
			batch_size,
			_parallel_batched_write_clean_triangles.bind(
				triangles,
				cleaned_triangles,
				list_start_write_index
			)
		)
	else:
		for i: int in range(triangles.size() / 3):
			if _parallel_is_non_zero_area_triangle(i, triangles):
				fat_triangle_count += 1
		cleaned_triangles.resize(fat_triangle_count * 3)
		cleaned_triangles.resize(0)
		for i: int in range(triangles.size() / 3):
			if _parallel_is_non_zero_area_triangle(i, triangles):
				var start_index: int = i * 3
				cleaned_triangles.push_back(triangles[start_index])
				cleaned_triangles.push_back(triangles[start_index + 1])
				cleaned_triangles.push_back(triangles[start_index + 2])

	progress.emit(ProgressStep.Enum.REMOVE_THIN_TRIANGLES, null, 1, 1)
	return cleaned_triangles


## [param triangles]: Vertex array to offset in place.[br]
## [param origin_offset]: Offset vector to apply to vertices.[br]
## [param async_context]: Context signal for asynchronous processing.[br]
## [param multi_threading_enabled]: Whether multi-threading is enabled.[br]
## [param multi_threading_priority]: Thread priority for parallel execution.[br]
func offset_triangles(
	triangles: PackedVector3Array,
	origin_offset: Vector3,
	async_context: Signal,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority
) -> void:
	progress.emit(
		ProgressStep.Enum.OFFSET_VERTICES_TO_LOCAL_COORDINATE,
		null,
		0,
		triangles.size()
	)
	if multi_threading_enabled:
		await Parallel.execute_batched(
			async_context,
			triangles.size(),
			multi_threading_priority,
			1000000,
			_parallel_batched_offset_triangle.bind(
				triangles,
				-origin_offset
			)
		)
	else:
		for i: int in range(0, triangles.size()):
			_parallel_batched_offset_triangle(
				i, i, i + 1,
				triangles,
				-origin_offset
			)
	progress.emit(
		ProgressStep.Enum.OFFSET_VERTICES_TO_LOCAL_COORDINATE,
		null,
		triangles.size(),
		triangles.size()
	)


func prepare_triangles(
	fn3d: FlightNavigation3D,
	async_context: Signal,
	list_voxelization_target: Array[VoxelizationTarget],
	voxelization_mask: int,
	debug_delete_csg: bool,
	remove_thin_triangles: bool,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority,
	origin_offset: Vector3
) -> PackedVector3Array:
	filter_voxelization_targets(list_voxelization_target, voxelization_mask)

	var triangles: PackedVector3Array = await build_mesh_from_csg(
		fn3d,
		list_voxelization_target,
		async_context,
		debug_delete_csg
	)
	if triangles.is_empty():
		return []

	if remove_thin_triangles:
		triangles = await filter_thin_triangles(
			triangles,
			async_context,
			multi_threading_enabled,
			multi_threading_priority
		)

	await offset_triangles(
		triangles,
		origin_offset,
		async_context,
		multi_threading_enabled,
		multi_threading_priority
	)

	return triangles


static func _parallel_is_non_zero_area_triangle(
	triangle_idx: int,
	list_triangle: PackedVector3Array
) -> bool:
	var start_idx: int = triangle_idx * 3
	var v0: Vector3 = list_triangle[start_idx]
	var v1: Vector3 = list_triangle[start_idx + 1]
	var v2: Vector3 = list_triangle[start_idx + 2]
	if v0.is_equal_approx(v1) or v1.is_equal_approx(v2) or v2.is_equal_approx(v0):
		return false
	return true


static func _parallel_batched_write_clean_triangles(
	batch_index: int,
	batch_start: int,
	batch_end: int,
	triangles: PackedVector3Array,
	cleaned_triangles: PackedVector3Array,
	list_start_write_index: PackedInt64Array
) -> void:
	var fat_triangle_this_batch: int = 0
	for i: int in range(batch_start, batch_end):
		if _parallel_is_non_zero_area_triangle(i, triangles):
			var write_address: int = 3 * (list_start_write_index[batch_index] + fat_triangle_this_batch)
			var triangle_address: int = 3 * i
			cleaned_triangles[write_address] = triangles[triangle_address]
			cleaned_triangles[write_address + 1] = triangles[triangle_address + 1]
			cleaned_triangles[write_address + 2] = triangles[triangle_address + 2]
			fat_triangle_this_batch += 1


static func _parallel_batched_offset_triangle(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	list_triangle: PackedVector3Array,
	offset: Vector3
) -> void:
	for vertex_idx: int in range(batch_start, batch_end):
		list_triangle[vertex_idx] += offset
