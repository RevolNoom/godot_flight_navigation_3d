## Concrete SVO voxelizer implementation.
## Contains voxelization pipeline extracted from FlightNavigation3D.
@tool
@warning_ignore_start("integer_division")
extends ASvoVoxelizer
class_name SvoVoxelizer

## Voxelizes the geometry associated with [param fn3d] into an [SVO].[br]
## [param fn3d]: [FlightNavigation3D] node defining bounds and target shapes.[br]
## Return: Constructed [SVO], or `null` on failure.[br]
func voxelize(fn3d: FlightNavigation3D) -> SVO:
	if fn3d == null:
		printerr("SvoVoxelizer.voxelize(): fn3d is null.")
		return null

	var cfg: Dictionary = _capture_voxelizer_config()
	var async_context: Signal = fn3d.get_tree().process_frame
	var list_voxelization_target: Array[VoxelizationTarget] = \
		SvoMeshPreprocessor.collect_voxelization_targets(fn3d)
	var flight_navigation_size: Vector3 = fn3d.size

	var voxel_size: Vector3 = FlightNavigation3D.calculate_node_size(
		flight_navigation_size,
		-2,
		cfg.layer_count
	)
	var origin_offset: Vector3 = -flight_navigation_size / 2

	var factory_triangle_box_test: AFactoryTriangleBoxOverlapCheck = \
		_create_triangle_box_test_factory(cfg.support_float64)

	var triangles: PackedVector3Array = await _prepare_triangles(
		fn3d,
		async_context,
		list_voxelization_target,
		cfg.voxelization_mask,
		cfg.debug_delete_csg,
		cfg.remove_thin_triangles,
		cfg.multi_threading_enabled,
		cfg.multi_threading_priority,
		origin_offset
	)

	var active_layer_1_result: Dictionary = \
		await _determine_active_layer_1_nodes(
			async_context,
			triangles,
			factory_triangle_box_test,
			voxel_size,
			cfg.surface_voxelization_float_error_margin,
			flight_navigation_size,
			cfg.multi_threading_enabled,
			cfg.multi_threading_priority
		)
	if active_layer_1_result.is_empty():
		printerr("Nothing to voxelize")
		return null
	if not active_layer_1_result.has("list_pair_node1_overlap_triangle_index") \
		or not active_layer_1_result.has("unique_morton_count") \
		or not active_layer_1_result.has("list_node_1_morton_grouped"):
		printerr("SvoVoxelizer._voxelize_from_fn3d_logic(): malformed active layer result.")
		return null

	var list_pair_node1_overlap_triangle_index: Array[Vector4i] = \
		active_layer_1_result[
			"list_pair_node1_overlap_triangle_index"
		]
	var unique_morton_count: int = \
		active_layer_1_result["unique_morton_count"]
	var list_node_1_morton_grouped: PackedInt64Array = \
		active_layer_1_result["list_node_1_morton_grouped"]

	var svo: SVO = await _construct_svo(
		async_context,
		list_node_1_morton_grouped,
		cfg.layer_count,
		cfg.multi_threading_enabled,
		cfg.multi_threading_priority
	)
	if svo == null:
		printerr("No layer 1 node found")
		return null

	if cfg.solid_voxelization_enabled:
		await _run_solid_voxelization(
			async_context,
			svo,
			triangles,
			voxel_size,
			flight_navigation_size,
			cfg.support_float64,
			cfg.solid_voxelization_top_left_edge_epsilon,
			cfg.debug_delete_flip_flag,
			cfg.multi_threading_enabled,
			cfg.multi_threading_priority,
			cfg.layer_count
		)

	if cfg.surface_voxelization_enabled:
		await _run_surface_voxelization(
			async_context,
			svo,
			triangles,
			list_pair_node1_overlap_triangle_index,
			unique_morton_count,
			list_node_1_morton_grouped,
			voxel_size,
			cfg.surface_voxelization_separability,
			cfg.surface_voxelization_float_error_margin,
			flight_navigation_size,
			factory_triangle_box_test,
			cfg.multi_threading_enabled,
			cfg.multi_threading_priority
		)

	if cfg.solid_voxelization_calculate_coverage_factor:
		await _calculate_coverage_factor(
			async_context,
			svo,
			cfg.multi_threading_enabled,
			cfg.multi_threading_priority
		)

	return svo


## Captures configuration properties into a [Dictionary] to make [method voxelize] reentrant.[br]
## Return: [Dictionary] of configuration properties.[br]
func _capture_voxelizer_config() -> Dictionary:
	return {
		"multi_threading_enabled": multi_threading_enabled,
		"multi_threading_priority": multi_threading_priority,
		"voxelization_mask": voxelization_mask,
		"remove_thin_triangles": remove_thin_triangles,
		"layer_count": layer_count,
		"support_float64": support_float64,
		"solid_voxelization_enabled": solid_voxelization_enabled,
		"solid_voxelization_calculate_coverage_factor": (
			solid_voxelization_calculate_coverage_factor
		),
		"solid_voxelization_top_left_edge_epsilon": (
			solid_voxelization_top_left_edge_epsilon
		),
		"surface_voxelization_enabled": surface_voxelization_enabled,
		"surface_voxelization_separability": (
			surface_voxelization_separability
		),
		"surface_voxelization_float_error_margin": (
			surface_voxelization_float_error_margin
		),
		"debug_delete_csg": debug_delete_csg,
		"debug_delete_flip_flag": debug_delete_flip_flag,
	}


static func _create_triangle_box_test_factory(support_float64: bool) -> AFactoryTriangleBoxOverlapCheck:
	if support_float64:
		return FactoryTriangleBoxOverlapCheckF64.new()
	return FactoryTriangleBoxOverlapCheckF32.new()


func _prepare_triangles(
	fn3d: FlightNavigation3D,
	async_context: Signal,
	list_voxelization_target: Array[VoxelizationTarget],
	voxelization_mask: int,
	debug_delete_csg: bool,
	remove_thin_triangles: bool,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority,
	origin_offset: Vector3) -> PackedVector3Array:
	var preprocessor := SvoMeshPreprocessor.new()
	preprocessor.progress.connect(func(step, svo, completed, total): progress.emit(step, svo, completed, total))
	return await preprocessor.prepare_triangles(
		fn3d,
		async_context,
		list_voxelization_target,
		voxelization_mask,
		debug_delete_csg,
		remove_thin_triangles,
		multi_threading_enabled,
		multi_threading_priority,
		origin_offset
	)


func _determine_active_layer_1_nodes(
	async_context: Signal,
	triangles: PackedVector3Array,
	factory_triangle_box_test: AFactoryTriangleBoxOverlapCheck,
	voxel_size: Vector3,
	surface_voxelization_float_error_margin: float,
	flight_navigation_size: Vector3,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority) -> Dictionary:
	progress.emit(
		ProgressStep.Enum.DETERMINE_ACTIVE_LAYER_1_NODES,
		null,
		0,
		triangles.size()/3)

	var list_triangle_overlap_node1_count: PackedInt64Array = []
	list_triangle_overlap_node1_count.resize(triangles.size()/3)
	list_triangle_overlap_node1_count.fill(0)
	if multi_threading_enabled:
		await Parallel.execute(
			async_context,
			triangles.size()/3,
			multi_threading_priority,
			_parallel_get_triangle_overlap_node1_count.bind(
				triangles,
				list_triangle_overlap_node1_count,
				factory_triangle_box_test,
				voxel_size,
				surface_voxelization_float_error_margin,
				flight_navigation_size
			))
	else:
		for i in range(triangles.size()/3):
			_parallel_get_triangle_overlap_node1_count(
				i,
				triangles,
				list_triangle_overlap_node1_count,
				factory_triangle_box_test,
				voxel_size,
				surface_voxelization_float_error_margin,
				flight_navigation_size
			)

	var list_triangle_overlap_node1_write_index: PackedInt64Array = \
		Parallel.make_start_write_index_array_from_count_array(
			list_triangle_overlap_node1_count)

	# Each element is a pair of int64 triangle index and int64 node 1 index.
	# Because each x, y, z, w component is int32, this is utilized to be a pair of int64
	# [0], [1] make up triangle_index
	# [2], [3] make up node_1_index
	# The reasons for using Vector4i are:
	# 1. Array supports sorting Vector4i with operator<
	# 2. Avoid creating a custom type that extends RefCounted.
	var list_pair_triangle_index_overlap_node1: Array[Vector4i] = []
	list_pair_triangle_index_overlap_node1.resize(
		Fn3dUtility.sum_number_array(list_triangle_overlap_node1_count))

	if list_pair_triangle_index_overlap_node1.size() == 0:
		return {}

	if multi_threading_enabled:
		await Parallel.execute(
			async_context,
			triangles.size()/3,
			multi_threading_priority,
			_parallel_get_triangle_overlap_list_node1.bind(
				triangles,
				factory_triangle_box_test,
				voxel_size,
				surface_voxelization_float_error_margin,
				flight_navigation_size,
				list_triangle_overlap_node1_write_index,
				list_pair_triangle_index_overlap_node1
			))
	else:
		for i in range(triangles.size()/3):
			_parallel_get_triangle_overlap_list_node1(
				i,
				triangles,
				factory_triangle_box_test,
				voxel_size,
				surface_voxelization_float_error_margin,
				flight_navigation_size,
				list_triangle_overlap_node1_write_index,
				list_pair_triangle_index_overlap_node1
			)

	var list_pair_node1_overlap_triangle_index: Array[Vector4i] = \
		_swap_triangle_node_pairs(list_pair_triangle_index_overlap_node1)

	# Group pairs by node_1 morton ascending, triangle index ascending
	# Note: This is a Group Operation, and is NOT a sort operation.
	# Because when breaking int64 into 2 int32,
	# low bits int32 sortings will be jumbled up based on sign bit
	list_pair_node1_overlap_triangle_index.sort()

	var unique_morton_count: int = _count_unique_morton_codes(
		list_pair_node1_overlap_triangle_index)
	var list_node_1_morton_grouped: PackedInt64Array = \
		_filter_unique_morton_codes(
			list_pair_node1_overlap_triangle_index,
			unique_morton_count)

	progress.emit(
		ProgressStep.Enum.DETERMINE_ACTIVE_LAYER_1_NODES,
		null,
		triangles.size()/3,
		triangles.size()/3)
	return {
		"list_pair_node1_overlap_triangle_index":
			list_pair_node1_overlap_triangle_index,
		"unique_morton_count": unique_morton_count,
		"list_node_1_morton_grouped": list_node_1_morton_grouped,
	}


static func _swap_triangle_node_pairs(list_pair_triangle_index_overlap_node1: Array[Vector4i]) -> Array[Vector4i]:
	var list_pair_node1_overlap_triangle_index: Array[Vector4i] = list_pair_triangle_index_overlap_node1.duplicate()
	for i in range(list_pair_node1_overlap_triangle_index.size()):
		var pair = list_pair_node1_overlap_triangle_index[i]
		var temp_high = pair[0]
		var temp_low = pair[1]
		pair[0] = pair[2]
		pair[1] = pair[3]
		pair[2] = temp_high
		pair[3] = temp_low
		list_pair_node1_overlap_triangle_index[i] = pair
	return list_pair_node1_overlap_triangle_index


func _construct_svo(
	async_context: Signal,
	list_node_1_morton_grouped: PackedInt64Array,
	depth: int,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority
) -> SVO:
	var tree_builder: SvoTreeBuilder = SvoTreeBuilder.new()
	tree_builder.progress.connect(
		func(step: ProgressStep.Enum, svo: SVO, work_completed: int, total_work: int):
			progress.emit(step, svo, work_completed, total_work)
	)
	return await tree_builder.construct_svo(
		async_context,
		list_node_1_morton_grouped,
		depth,
		multi_threading_enabled,
		multi_threading_priority
	)


func _init_svo_layers_and_layer_0(svo: SVO, depth: int, layer_0_size: int) -> void:
	SvoTreeBuilder.init_svo_layers_and_layer_0(svo, depth, layer_0_size)


static func _init_root_layer(svo: SVO, layer: int) -> void:
	SvoTreeBuilder.init_root_layer(svo, layer)


static func _allocate_svo_layer_arrays(
	svo: SVO,
	layer: int,
	current_layer_size: int
) -> void:
	SvoTreeBuilder.allocate_svo_layer_arrays(svo, layer, current_layer_size)


func _fill_neighbor_links(
	svo: SVO,
	async_context: Signal,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority
) -> void:
	var tree_builder: SvoTreeBuilder = SvoTreeBuilder.new()
	await tree_builder.fill_neighbor_links(
		svo,
		async_context,
		multi_threading_enabled,
		multi_threading_priority
	)



func _run_solid_voxelization(
	async_context: Signal,
	svo: SVO,
	triangles: PackedVector3Array,
	voxel_size: Vector3,
	flight_navigation_size: Vector3,
	support_float64: bool,
	solid_voxelization_top_left_edge_epsilon: float,
	debug_delete_flip_flag: bool,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority,
	depth: int) -> void:
	progress.emit(ProgressStep.Enum.SOLID_VOXELIZATION, svo, 0, 2)

	#region YZ plane rasterization, and projection on x column
	await _run_yz_plane_rasterization(
		svo,
		triangles,
		voxel_size,
		flight_navigation_size,
		support_float64,
		solid_voxelization_top_left_edge_epsilon,
		async_context,
		multi_threading_enabled,
		multi_threading_priority
	)
	#endregion

	progress.emit(ProgressStep.Enum.SOLID_VOXELIZATION, svo, 1, 2)
	#region Hierarchical inside/outside propagation
	progress.emit(
		ProgressStep.Enum.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION,
		svo,
		0,
		6)

	#region Prepare flip flags, inside flags, list head nodes
	var list_head_node_offset_of_layer: Array[PackedInt64Array] = \
		_prepare_flip_flags_and_head_nodes(svo)
	var flip_flag: Array[PackedByteArray] = svo.flip
	#endregion

	progress.emit(
		ProgressStep.Enum.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION,
		svo,
		1,
		6)
	#region Propagate bit flips in x+ direction
	await _propagate_bit_flips_xp(
		svo,
		list_head_node_offset_of_layer[0],
		async_context,
		multi_threading_enabled,
		multi_threading_priority
	)
	#endregion

	progress.emit(
		ProgressStep.Enum.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION,
		svo,
		2,
		6)
	#region Flip bottom up layer 1
	await _flip_bottom_up_layer_1(
		svo,
		flip_flag,
		list_head_node_offset_of_layer,
		async_context,
		multi_threading_enabled,
		multi_threading_priority
	)
	#endregion

	progress.emit(
		ProgressStep.Enum.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION,
		svo,
		3,
		6)
	#region Flip bottom up from layer 2
	await _flip_bottom_up_from_layer_2(
		svo,
		flip_flag,
		list_head_node_offset_of_layer,
		async_context,
		multi_threading_enabled,
		multi_threading_priority
	)
	#endregion

	progress.emit(
		ProgressStep.Enum.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION,
		svo,
		4,
		6)
	#region Propagate inside flags topdown for tree nodes
	_propagate_inside_flags_topdown(svo, depth)
	#endregion

	progress.emit(
		ProgressStep.Enum.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION,
		svo,
		5,
		6)
	#region Propagate inside flag to subgrid voxels
	_propagate_inside_flags_to_subgrid_voxels(svo)
	#endregion

	progress.emit(
		ProgressStep.Enum.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION,
		svo,
		6,
		6)
	#endregion

	progress.emit(ProgressStep.Enum.SOLID_VOXELIZATION, svo, 2, 2)
	if debug_delete_flip_flag:
		svo.flip.clear()


## [param svo]: [SVO] being constructed.[br]
## [param triangles]: Triangles to rasterize.[br]
## [param voxel_size]: Size of leaf voxel in world coordinates.[br]
## [param flight_navigation_size]: Bounding size of the navigation area.[br]
## [param support_float64]: Whether to use 64-bit float precision.[br]
## [param solid_voxelization_top_left_edge_epsilon]: Epsilon offset for top-left edge rule.[br]
## [param async_context]: Context signal for asynchronous processing.[br]
## [param multi_threading_enabled]: Whether multi-threading is enabled.[br]
## [param multi_threading_priority]: Thread priority for parallel execution.[br]
func _run_yz_plane_rasterization(
	svo: SVO,
	triangles: PackedVector3Array,
	voxel_size: Vector3,
	flight_navigation_size: Vector3,
	support_float64: bool,
	solid_voxelization_top_left_edge_epsilon: float,
	async_context: Signal,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority) -> void:
	progress.emit(ProgressStep.Enum.YZ_PLANE_RASTERIZATION, svo, 0, triangles.size() / 3)

	var x_column_flip_bitmask_by_subgrid_index: PackedInt64Array = \
		Fn3dLookupTable.x_column_flip_bitmask_by_subgrid_index

	var parallel_yz_plane_rasterization: Callable
	if support_float64:
		parallel_yz_plane_rasterization = _parallel_yz_plane_rasterization_f64
	else:
		parallel_yz_plane_rasterization = _parallel_yz_plane_rasterization_f32

	if multi_threading_enabled:
		await Parallel.execute(
			async_context,
			triangles.size() / 3,
			multi_threading_priority,
			parallel_yz_plane_rasterization.bind(
				svo,
				triangles,
				voxel_size,
				x_column_flip_bitmask_by_subgrid_index,
				flight_navigation_size,
				solid_voxelization_top_left_edge_epsilon
			))
	else:
		for i: int in range(triangles.size() / 3):
			parallel_yz_plane_rasterization.call(
				i,
				svo,
				triangles,
				voxel_size,
				x_column_flip_bitmask_by_subgrid_index,
				flight_navigation_size,
				solid_voxelization_top_left_edge_epsilon
			)

	progress.emit(
		ProgressStep.Enum.YZ_PLANE_RASTERIZATION,
		svo,
		triangles.size() / 3,
		triangles.size() / 3)


## [param svo]: [SVO] to prepare flip and inside flags for.[br]
## Return: Array of head node offsets for each layer in X direction.[br]
func _prepare_flip_flags_and_head_nodes(
	svo: SVO) -> Array[PackedInt64Array]:
	progress.emit(ProgressStep.Enum.PREPARE_FLAGS_AND_HEAD_NODES, svo, 0, 3)
	# Flip flags of layer 0 are not used, so they are not initialized.
	# Only inside flags are initialized.
	var flip_flag: Array[PackedByteArray] = []
	flip_flag.resize(svo.morton.size())
	for i: int in range(1, svo.morton.size()):
		flip_flag[i].resize(svo.morton[i].size())
		flip_flag[i].fill(0)
	svo.flip = flip_flag

	progress.emit(ProgressStep.Enum.PREPARE_FLAGS_AND_HEAD_NODES, svo, 1, 3)
	svo.inside.resize(svo.morton.size())
	for i: int in range(0, svo.morton.size()):
		svo.inside[i].resize(svo.morton[i].size())
		svo.inside[i].fill(0)

	progress.emit(ProgressStep.Enum.PREPARE_FLAGS_AND_HEAD_NODES, svo, 2, 3)
	var list_head_node_offset_of_layer: Array[PackedInt64Array] = []
	list_head_node_offset_of_layer.resize(svo.morton.size())
	for layer: int in range(0, svo.morton.size()):
		list_head_node_offset_of_layer[layer] = \
			svo.get_offsets_of_head_nodes_in_x_direction_of_layer(layer)

	progress.emit(ProgressStep.Enum.PREPARE_FLAGS_AND_HEAD_NODES, svo, 3, 3)
	return list_head_node_offset_of_layer


## [param svo]: [SVO] whose subgrid bit flips will be propagated.[br]
## [param list_head_node_offset_of_layer_0]: Head node offsets in layer 0.[br]
## [param async_context]: Context signal for asynchronous processing.[br]
## [param multi_threading_enabled]: Whether multi-threading is enabled.[br]
## [param multi_threading_priority]: Thread priority for parallel execution.[br]
func _propagate_bit_flips_xp(
	svo: SVO,
	list_head_node_offset_of_layer_0: PackedInt64Array,
	async_context: Signal,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority) -> void:
	var neighbor_node_x_column_bits_by_subgrid_index: Dictionary[int, int] = \
		Fn3dLookupTable.neighbor_node_x_column_bits_by_subgrid_index
	var subgrid_voxel_indexes_on_face_xp: PackedInt32Array = \
		Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"]
	var svo_subgrid: PackedInt64Array = svo.subgrid
	var svo_xp: Array[PackedInt64Array] = svo.xp

	progress.emit(
		ProgressStep.Enum.XP_BIT_FLIP_PROPAGATION,
		svo,
		0,
		list_head_node_offset_of_layer_0.size())

	if multi_threading_enabled:
		await Parallel.execute(
			async_context,
			list_head_node_offset_of_layer_0.size(),
			multi_threading_priority,
			_parallel_propagate_bit_flip.bind(
				list_head_node_offset_of_layer_0,
				subgrid_voxel_indexes_on_face_xp,
				svo_xp,
				svo_subgrid,
				neighbor_node_x_column_bits_by_subgrid_index))
	else:
		for i: int in range(list_head_node_offset_of_layer_0.size()):
			_parallel_propagate_bit_flip(
				i,
				list_head_node_offset_of_layer_0,
				subgrid_voxel_indexes_on_face_xp,
				svo_xp,
				svo_subgrid,
				neighbor_node_x_column_bits_by_subgrid_index)

	progress.emit(
		ProgressStep.Enum.XP_BIT_FLIP_PROPAGATION,
		svo,
		list_head_node_offset_of_layer_0.size(),
		list_head_node_offset_of_layer_0.size())


## [param svo]: [SVO] whose layer 1 flip flags will be determined and propagated.[br]
## [param flip_flag]: Array of flip flags per layer.[br]
## [param list_head_node_offset_of_layer]: Head node offsets per layer.[br]
## [param async_context]: Context signal for asynchronous processing.[br]
## [param multi_threading_enabled]: Whether multi-threading is enabled.[br]
## [param multi_threading_priority]: Thread priority for parallel execution.[br]
func _flip_bottom_up_layer_1(
	svo: SVO,
	flip_flag: Array[PackedByteArray],
	list_head_node_offset_of_layer: Array[PackedInt64Array],
	async_context: Signal,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority) -> void:
	progress.emit(ProgressStep.Enum.FLIP_BOTTOM_UP_LAYER_1, svo, 0, 2)
	#region Prepare layer 1 flip flag
	progress.emit(
		ProgressStep.Enum.PREPARE_FLIP_FLAG_LAYER_1,
		svo,
		0,
		flip_flag[1].size())
	# Set flip flag for layer-1 nodes with children
	# at the end of a x-linked node string
	var svo_first_child: Array[PackedInt64Array] = svo.first_child
	var svo_xp: Array[PackedInt64Array] = svo.xp
	var svo_subgrid: PackedInt64Array = svo.subgrid
	var bitmask_of_subgrid_voxels_on_face_xp: int = \
		Fn3dLookupTable.bitmask_of_subgrid_voxels_on_face_xp
	var svo_inside: Array[PackedByteArray] = svo.inside

	for i: int in range(0, flip_flag[1].size()):
		var first_child_svolink: int = svo_first_child[1][i]
		if first_child_svolink == SvoLink64.singleton.null_link():
			continue

		if not _is_end_of_x_linked_node_string(1, i, svo_first_child, svo_xp):
			continue

		var first_child_offset: int = SvoLink64.singleton.get_offset(first_child_svolink)
		# Schwarz:
		# "Note that after that, at the end of such node strings, where no
		# more level-0 nodes abut, all four level-0 nodes with the same level-1
		# parent have all their SG voxels with local x index 3 in agreement."
		#
		# Explanation:
		# All four level-0 nodes (at the end of x-linked string)
		# with the same level-1 parent have all their SG voxels
		# with local x index 3 either all free or all solid.
		#
		# To prove this by contrast, let's assume that they are not in agreement.
		# It means that the surface of the object are snuggly bounded in
		# those 4 level-0 nodes.
		# And since we have modified the surface voxelization
		# to ensure that the final voxelization boundary consists solely
		# of level-0 nodes, the level-0 nodes will have level-0 x+ neighbors.
		# Because they have level-0 neighbors, they are not at the end of x-linked string.
		#
		# This argument proves that it is correct to only set flip flag based on 1 child.
		# It also applies to upper layers.

		#var child_on_xp_offset = first_child_offset + 1
		#var child_subgrid = svo_subgrid[child_on_xp_offset]
		#flip_flag[1][i] = int(bitmask_of_subgrid_voxels_on_face_xp ==
				#(child_subgrid & bitmask_of_subgrid_voxels_on_face_xp))

		# 23/10/2025: Floating point errors cause some voxels to not be rasterized
		# As such, some nodes are incorrectly flipped.
		# So I have to go back to checking every nodes
		flip_flag[1][i] = _has_full_xp_face_in_all_children(
			first_child_offset,
			svo_subgrid,
			bitmask_of_subgrid_voxels_on_face_xp)

	progress.emit(
		ProgressStep.Enum.PREPARE_FLIP_FLAG_LAYER_1,
		svo,
		flip_flag[1].size(),
		flip_flag[1].size())
	#endregion

	progress.emit(ProgressStep.Enum.FLIP_BOTTOM_UP_LAYER_1, svo, 1, 2)
	#region Propagate layer 1 flip information
	progress.emit(
		ProgressStep.Enum.PROPAGATE_FLIP_INFORMATION_LAYER_1,
		svo,
		0,
		list_head_node_offset_of_layer[1].size())

	if multi_threading_enabled:
		await Parallel.execute(
			async_context,
			list_head_node_offset_of_layer[1].size(),
			multi_threading_priority,
			_parallel_propagate_flip_and_inside.bind(
				1,
				list_head_node_offset_of_layer,
				svo_xp,
				flip_flag,
				svo_inside))
	else:
		for head_node_index: int in range(list_head_node_offset_of_layer[1].size()):
			_parallel_propagate_flip_and_inside(
				head_node_index,
				1,
				list_head_node_offset_of_layer,
				svo_xp,
				flip_flag,
				svo_inside)

	progress.emit(
		ProgressStep.Enum.PROPAGATE_FLIP_INFORMATION_LAYER_1,
		svo,
		list_head_node_offset_of_layer[1].size(),
		list_head_node_offset_of_layer[1].size())
	#endregion

	progress.emit(ProgressStep.Enum.FLIP_BOTTOM_UP_LAYER_1, svo, 2, 2)


## [param svo]: [SVO] whose flip flags from layer 2 upward will be determined and propagated.[br]
## [param flip_flag]: Array of flip flags per layer.[br]
## [param list_head_node_offset_of_layer]: Head node offsets per layer.[br]
## [param async_context]: Context signal for asynchronous processing.[br]
## [param multi_threading_enabled]: Whether multi-threading is enabled.[br]
## [param multi_threading_priority]: Thread priority for parallel execution.[br]
func _flip_bottom_up_from_layer_2(
	svo: SVO,
	flip_flag: Array[PackedByteArray],
	list_head_node_offset_of_layer: Array[PackedInt64Array],
	async_context: Signal,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority) -> void:
	progress.emit(
		ProgressStep.Enum.FLIP_BOTTOM_UP_FROM_LAYER_2,
		svo,
		0,
		flip_flag.size())

	var svo_first_child: Array[PackedInt64Array] = svo.first_child
	var svo_xp: Array[PackedInt64Array] = svo.xp
	var svo_inside: Array[PackedByteArray] = svo.inside

	# Set flip flag for layer-1 nodes with children
	# at the end of a z-linked node string
	# TODO: Parallelize operation in each layer, in all layers
	for layer: int in range(2, flip_flag.size()):
		#region Prepare flip flag
		var flip_flag_layer: PackedByteArray = flip_flag[layer]
		var flip_flag_child_layer: PackedByteArray = flip_flag[layer - 1]
		progress.emit(
			ProgressStep.Enum.PREPARE_FLIP_FLAG_FROM_LAYER_2,
			svo,
			0,
			flip_flag_layer.size())
		for i: int in range(0, flip_flag_layer.size()):
			var first_child_svolink: int = svo_first_child[layer][i]
			if first_child_svolink == SvoLink64.singleton.null_link():
				continue

			if not _is_end_of_x_linked_node_string(
					layer, i, svo_first_child, svo_xp):
				continue

			var first_child_offset: int = SvoLink64.singleton.get_offset(first_child_svolink)
			#var child_on_xp_offset = first_child_offset + 1
			#flip_flag_layer[i] = flip_flag_child_layer[child_on_xp_offset]

			flip_flag_layer[i] = _all_xp_children_are_flipped(
				first_child_offset,
				flip_flag_child_layer)

		progress.emit(
			ProgressStep.Enum.PREPARE_FLIP_FLAG_FROM_LAYER_2,
			svo,
			flip_flag_layer.size(),
			flip_flag_layer.size())
		#endregion

		#region Propagate flip information
		progress.emit(
			ProgressStep.Enum.PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2,
			svo,
			0,
			list_head_node_offset_of_layer[layer].size())
		if multi_threading_enabled:
			await Parallel.execute(
				async_context,
				list_head_node_offset_of_layer[layer].size(),
				multi_threading_priority,
				_parallel_propagate_flip_and_inside.bind(
					layer,
					list_head_node_offset_of_layer,
					svo_xp,
					flip_flag,
					svo_inside))
		else:
			for head_node_index: int in range(
					list_head_node_offset_of_layer[layer].size()):
				_parallel_propagate_flip_and_inside(
					head_node_index,
					layer,
					list_head_node_offset_of_layer,
					svo_xp,
					flip_flag,
					svo_inside)

		progress.emit(
			ProgressStep.Enum.PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2,
			svo,
			list_head_node_offset_of_layer[layer].size(),
			list_head_node_offset_of_layer[layer].size())
		#endregion

		progress.emit(
			ProgressStep.Enum.FLIP_BOTTOM_UP_FROM_LAYER_2,
			svo,
			layer,
			flip_flag.size())

	progress.emit(
		ProgressStep.Enum.FLIP_BOTTOM_UP_FROM_LAYER_2,
		svo,
		flip_flag.size(),
		flip_flag.size())


## [param svo]: [SVO] whose tree nodes' inside flags will be propagated top-down.[br]
## [param depth]: Total tree depth (number of layers).[br]
func _propagate_inside_flags_topdown(svo: SVO, depth: int) -> void:
	progress.emit(
		ProgressStep.Enum.PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES,
		svo,
		0,
		depth - 1)
	var svo_inside: Array[PackedByteArray] = svo.inside
	var svo_first_child: Array[PackedInt64Array] = svo.first_child

	for layer: int in range(depth - 1, 0, -1):
		var svo_inside_layer: PackedByteArray = svo_inside[layer]
		var svo_inside_layer_child: PackedByteArray = svo_inside[layer - 1]
		var svo_first_child_layer: PackedInt64Array = svo_first_child[layer]
		for offset: int in range(svo_inside_layer.size()):
			if svo_inside_layer[offset]:
				var first_child_svolink: int = svo_first_child_layer[offset]
				if first_child_svolink == SvoLink64.singleton.null_link():
					continue
				var first_child_offset: int = SvoLink64.singleton.get_offset(first_child_svolink)
				for child: int in range(first_child_offset, first_child_offset + 8):
					svo_inside_layer_child[child] = \
						svo_inside_layer_child[child] ^ 1

	progress.emit(
		ProgressStep.Enum.PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES,
		svo,
		depth - 1,
		depth - 1)


## [param svo]: [SVO] whose leaf subgrid voxels will have inside flags applied.[br]
func _propagate_inside_flags_to_subgrid_voxels(svo: SVO) -> void:
	var svo_inside_layer_0: PackedByteArray = svo.inside[0]
	var svo_subgrid: PackedInt64Array = svo.subgrid
	progress.emit(
		ProgressStep.Enum.PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS,
		svo,
		0,
		svo_inside_layer_0.size())
	for offset: int in range(svo_inside_layer_0.size()):
		if svo_inside_layer_0[offset]:
			svo_subgrid[offset] = ~svo_subgrid[offset]
	progress.emit(
		ProgressStep.Enum.PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS,
		svo,
		svo_inside_layer_0.size(),
		svo_inside_layer_0.size())


func _run_surface_voxelization(
	async_context: Signal,
	svo: SVO,
	triangles: PackedVector3Array,
	list_pair_node1_overlap_triangle_index: Array[Vector4i],
	unique_morton_count: int,
	list_node_1_morton_grouped: PackedInt64Array,
	voxel_size: Vector3,
	surface_voxelization_separability: Separability.Enum,
	surface_voxelization_float_error_margin: float,
	flight_navigation_size: Vector3,
	factory_triangle_box_test: AFactoryTriangleBoxOverlapCheck,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority
) -> void:
	var surface_voxelizer: SvoSurfaceVoxelizer = SvoSurfaceVoxelizer.new()
	surface_voxelizer.progress.connect(
		func(step: ProgressStep.Enum, svo_arg: SVO, completed: int, total: int):
			progress.emit(step, svo_arg, completed, total)
	)
	await surface_voxelizer.run_surface_voxelization(
		async_context,
		svo,
		triangles,
		list_pair_node1_overlap_triangle_index,
		unique_morton_count,
		list_node_1_morton_grouped,
		voxel_size,
		surface_voxelization_separability,
		surface_voxelization_float_error_margin,
		flight_navigation_size,
		factory_triangle_box_test,
		multi_threading_enabled,
		multi_threading_priority
	)



func _calculate_coverage_factor(
	async_context: Signal,
	svo: SVO,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority) -> void:
	progress.emit(ProgressStep.Enum.CALCULATE_COVERAGE_FACTOR, svo, 0, 2)
	var new_svo_coverage: Array[PackedFloat64Array] = []
	new_svo_coverage.resize(svo.morton.size())
	for layer in range(svo.morton.size()):
		new_svo_coverage[layer].resize(svo.morton[layer].size())
		new_svo_coverage[layer].fill(0.0)

	#region Calculate layer 0 coverage
	var list_solid_bit_count_by_subgrid: PackedInt64Array = []
	if multi_threading_enabled:
		list_solid_bit_count_by_subgrid = \
		await svo.parallel_get_list_solid_bit_count_by_subgrid(
			async_context,
			multi_threading_priority)
	else:
		list_solid_bit_count_by_subgrid = \
			svo.get_list_solid_bit_count_by_subgrid()

	for i in range(list_solid_bit_count_by_subgrid.size()):
		new_svo_coverage[0][i] = list_solid_bit_count_by_subgrid[i] / 64.0
	progress.emit(ProgressStep.Enum.CALCULATE_COVERAGE_FACTOR, svo, 1, 2)
	#endregion

	#region Calculate coverage for layer 1 and up
	for layer in range(1, new_svo_coverage.size()):
		for i in range(new_svo_coverage[layer].size()):
			var first_child_svolink = svo.first_child[layer][i]
			if first_child_svolink == SvoLink64.singleton.null_link() and svo.support_inside:
				if svo.inside[layer][i]:
					new_svo_coverage[layer][i] = 1.0
				else:
					new_svo_coverage[layer][i] = 0.0
				continue
			var total_coverage: float = 0
			var first_child_offset = SvoLink64.singleton.get_offset(first_child_svolink)
			var child_layer = layer-1
			for child_offset in range(
					first_child_offset,
					first_child_offset + 8):
				total_coverage += new_svo_coverage[child_layer][child_offset]
			new_svo_coverage[layer][i] = total_coverage / 8
	svo.coverage = new_svo_coverage
	#endregion

	progress.emit(ProgressStep.Enum.CALCULATE_COVERAGE_FACTOR, svo, 2, 2)


static func _is_end_of_x_linked_node_string(
	layer: int,
	node_offset: int,
	svo_first_child: Array[PackedInt64Array],
	svo_xp: Array[PackedInt64Array]) -> bool:
	var xp_svolink = svo_xp[layer][node_offset]
	if xp_svolink == SvoLink64.singleton.null_link():
		return true

	var xp_layer = SvoLink64.singleton.get_layer(xp_svolink)
	var xp_offset = SvoLink64.singleton.get_offset(xp_svolink)
	var xp_first_child = svo_first_child[layer][xp_offset]
	return not (xp_layer == layer and xp_first_child != SvoLink64.singleton.null_link())


static func _has_full_xp_face_in_all_children(
	first_child_offset: int,
	svo_subgrid: PackedInt64Array,
	xp_face_bitmask: int) -> int:
	var flip: int = 1
	for xp_offset in [1, 3, 5, 7]:
		var child_subgrid = svo_subgrid[first_child_offset + xp_offset]
		flip = flip & int(xp_face_bitmask == (child_subgrid & xp_face_bitmask))
	return flip


static func _all_xp_children_are_flipped(
	first_child_offset: int,
	flip_flag_child_layer: PackedByteArray) -> int:
	var flip: int = 1
	for xp_offset in [1, 3, 5, 7]:
		flip = flip & flip_flag_child_layer[first_child_offset + xp_offset]
	return flip


static func _filter_unique_morton_codes(
	list_pair_node1_overlap_triangle_index: Array[Vector4i], 
	unique_morton_count: int) -> PackedInt64Array:
	var first_element: Vector4i = list_pair_node1_overlap_triangle_index[0]
	var first_element_morton: int = first_element[0] << 32 | first_element[1]
	var list_node_1_morton_grouped: PackedInt64Array = [first_element_morton]
	list_node_1_morton_grouped.resize(unique_morton_count)
	list_node_1_morton_grouped.resize(1)
	for i in range(list_pair_node1_overlap_triangle_index.size()):
		var current_morton: int = list_pair_node1_overlap_triangle_index[i][0] << 32 | list_pair_node1_overlap_triangle_index[i][1]
		if current_morton != list_node_1_morton_grouped[list_node_1_morton_grouped.size()-1]:
			list_node_1_morton_grouped.push_back(current_morton)
	return list_node_1_morton_grouped


static func _count_unique_morton_codes(list_pair_node1_overlap_triangle_index: Array[Vector4i]) -> int:
	var unique_morton_count: int = 1
	for i in range(1, list_pair_node1_overlap_triangle_index.size()):
		var current_morton: int = list_pair_node1_overlap_triangle_index[i][0] << 32 | list_pair_node1_overlap_triangle_index[i][1]
		var last_morton: int = list_pair_node1_overlap_triangle_index[i-1][0] << 32 | list_pair_node1_overlap_triangle_index[i-1][1]
		if current_morton != last_morton:
			unique_morton_count += 1
	return unique_morton_count


static func _get_node_1_overlap_triangle_count_array(
	list_pair_node1_overlap_triangle_index: Array[Vector4i],
	unique_morton_count: int
) -> PackedInt64Array:
	return SvoSurfaceVoxelizer.get_node_1_overlap_triangle_count_array(
		list_pair_node1_overlap_triangle_index,
		unique_morton_count
	)




#region Multithreading functions

@warning_ignore("shadowed_variable")
static func _parallel_get_triangle_overlap_list_node1(
	triangle_idx: int,
	list_triangle: PackedVector3Array,
	factory_triangle_box_test: AFactoryTriangleBoxOverlapCheck,
	voxel_size: Vector3,
	surface_voxelization_float_error_margin: float,
	flight_navigation_size: Vector3,
	list_triangle_overlap_node1_write_index: PackedInt64Array,
	list_pair_triangle_index_overlap_node1: Array[Vector4i],
	) -> void:
	
	var node_1_size: Vector3 = voxel_size * 8
		
	var start_idx = triangle_idx*3
	var v0 = list_triangle[start_idx]
	var v1 = list_triangle[start_idx + 1]
	var v2 = list_triangle[start_idx + 2]
	
	# Modifications (as described by Schwarz) to ensure that 
	# the final voxelization boundary consists solely of level-0 nodes.
	# 
	# Without these modifications, consider this case:
	# 1. Triangle is perpendicular to x-axis (lie completely on yz-plane)
	# 2. Triangle intersects with "children (of layer 0) with x index = 1" of layer-1 nodes.
	# 3. Triangle has x-coordinate (subgrid voxel unit) of 3.5 to 3.999 relative to that layer-0 node.
	# 4. Triangle intersects with layer 0 node that is the end of x-linked string.
	# When these criteria are met, the triangle does not flip any bit during 
	# YZ rasterization step, thus their existence is not taken into account.
	# Therefore, inside-outside propagation will incorrectly flip free space into
	# solid space and vice versa.
	var half_voxel_size_x: float = voxel_size.x/2
	v0.x += half_voxel_size_x
	v1.x += half_voxel_size_x
	v2.x += half_voxel_size_x

	var triangle_node1_test = factory_triangle_box_test.create(
		v0, 
		v1, 
		v2, 
		node_1_size, 
		Separability.Enum.SEPARATING_26,
		surface_voxelization_float_error_margin)
	var aabb: AABB = SvoSurfaceVoxelizer.calculate_triangle_aabb(v0, v1, v2)
	var voxel_range: Array[Vector3i] = SvoSurfaceVoxelizer.voxels_overlapped_by_aabb(node_1_size, aabb, flight_navigation_size)

	var write_index = list_triangle_overlap_node1_write_index[triangle_idx]
	var node_1_position: Vector3 = Vector3()
	for x in range(voxel_range[0].x, voxel_range[1].x):
		node_1_position.x = x * node_1_size.x
		for y in range(voxel_range[0].y, voxel_range[1].y):
			node_1_position.y = y * node_1_size.y
			for z in range(voxel_range[0].z, voxel_range[1].z):
				node_1_position.z = z * node_1_size.z
				if triangle_node1_test.overlap_voxel(node_1_position):
					var triangle_index_high: int = (triangle_idx >> 32) & 0xFFFF_FFFF
					var triangle_index_low: int = triangle_idx & 0xFFFF_FFFF

					var node_1_morton = Morton3.encode64(x, y, z)
					var node_1_morton_high: int = (node_1_morton >> 32) & 0xFFFF_FFFF
					var node_1_morton_low: int = node_1_morton & 0xFFFF_FFFF
					
					var pair_triangle_index_overlap_node1: Vector4i = Vector4i()
					pair_triangle_index_overlap_node1[0] = triangle_index_high
					pair_triangle_index_overlap_node1[1] = triangle_index_low
					pair_triangle_index_overlap_node1[2] = node_1_morton_high
					pair_triangle_index_overlap_node1[3] = node_1_morton_low
					list_pair_triangle_index_overlap_node1[write_index] = pair_triangle_index_overlap_node1
					write_index += 1



@warning_ignore("shadowed_variable")
static func _parallel_get_triangle_overlap_node1_count(
	triangle_idx: int,
	list_triangle: PackedVector3Array,
	list_triangle_overlap_node1_count: PackedInt64Array,
	factory_triangle_box_test: AFactoryTriangleBoxOverlapCheck,
	voxel_size: Vector3,
	surface_voxelization_float_error_margin: float,
	flight_navigation_size: Vector3) -> void:
	var node_1_size: Vector3 = voxel_size * 8
		
	var start_idx = triangle_idx*3
	var v0 = list_triangle[start_idx]
	var v1 = list_triangle[start_idx + 1]
	var v2 = list_triangle[start_idx + 2]

	# Modifications (as described by Schwarz) to ensure that 
	# the final voxelization boundary consists solely of level-0 nodes.
	# 
	# Without these modifications, consider this case:
	# 1. Triangle is perpendicular to x-axis (lie completely on yz-plane)
	# 2. Triangle intersects with "children (of layer 0) with x index = 1" of layer-1 nodes.
	# 3. Triangle has x-coordinate (subgrid voxel unit) of 3.5 to 3.999 relative to that layer-0 node.
	# 4. Triangle intersects with layer 0 node that is the end of x-linked string.
	# When these criteria are met, the triangle does not flip any bit during 
	# YZ rasterization step, thus their existence is not taken into account.
	# Therefore, inside-outside propagation will incorrectly flip free space into
	# solid space and vice versa.
	var half_voxel_size_x: float = voxel_size.x/2
	v0.x += half_voxel_size_x
	v1.x += half_voxel_size_x
	v2.x += half_voxel_size_x
	
	var triangle_node1_test = factory_triangle_box_test.create(
		v0, 
		v1, 
		v2, 
		node_1_size, 
		Separability.Enum.SEPARATING_26,
		surface_voxelization_float_error_margin)
	var aabb: AABB = SvoSurfaceVoxelizer.calculate_triangle_aabb(v0, v1, v2)
	var voxel_range: Array[Vector3i] = SvoSurfaceVoxelizer.voxels_overlapped_by_aabb(node_1_size, aabb, flight_navigation_size)
	var node_1_position: Vector3 = Vector3()
	for x in range(voxel_range[0].x, voxel_range[1].x):
		node_1_position.x = x * node_1_size.x
		for y in range(voxel_range[0].y, voxel_range[1].y):
			node_1_position.y = y * node_1_size.y
			for z in range(voxel_range[0].z, voxel_range[1].z):
				node_1_position.z = z * node_1_size.z
				if triangle_node1_test.overlap_voxel(node_1_position):
					list_triangle_overlap_node1_count[triangle_idx] += 1





@warning_ignore("shadowed_variable")
static func _parallel_yz_plane_rasterization_f64(
	triangle_index: int,
	svo: SVO,
	triangles: PackedVector3Array, 
	voxel_size: Vector3,
	x_column_flip_bitmask_by_subgrid_index: PackedInt64Array,
	flight_navigation_size: Vector3,
	solid_voxelization_top_left_edge_epsilon: float
	):
	var triangle_start_idx: int = triangle_index * 3
	
	var voxel_size_yz: PackedFloat64Array = [voxel_size[1], voxel_size[2]]
	
	var v0: PackedFloat64Array = Dvector.create_v3(triangles[triangle_start_idx+0])
	var v1: PackedFloat64Array = Dvector.create_v3(triangles[triangle_start_idx+1])
	var v2: PackedFloat64Array = Dvector.create_v3(triangles[triangle_start_idx+2])

	var e0xyz: PackedFloat64Array = [0.0, 0.0, 0.0]
	var e1xyz: PackedFloat64Array = [0.0, 0.0, 0.0]
	var e2xyz: PackedFloat64Array = [0.0, 0.0, 0.0]
	Dvector.sub(e0xyz, v1, v0)
	Dvector.sub(e1xyz, v2, v1)
	Dvector.sub(e2xyz, v0, v2)
	
	var v0yz: PackedFloat64Array = [v0[1], v0[2]]
	var v1yz: PackedFloat64Array = [v1[1], v1[2]]
	var v2yz: PackedFloat64Array = [v2[1], v2[2]]

	#region Ensure consistent counter-clockwise order of vertices
	var not_is_ccw = e2xyz[1] * e0xyz[2] - e0xyz[1] * e2xyz[2] < 0
	if not_is_ccw:
		# Swap v1yz and v2yz
		var v_temp = v1yz
		v1yz = v2yz
		v2yz = v_temp
		
		# Recalculate edge equations. Turn v1yz into v2yz and vice versa.
		Dvector.sub(e0xyz, v2, v0)
		Dvector.sub(e1xyz, v1, v2)
		Dvector.sub(e2xyz, v0, v1)
	#endregion

	
	var n: PackedFloat64Array = [0.0, 0.0, 0.0]
	Dvector.cross(n, e0xyz, e1xyz)

	# Ignore projected triangles that are too thin.
	if is_zero_approx(n[0]):
	#if absf(n[0]) < epsilon:
		return

	var n_yz_e0: PackedFloat64Array = [-e0xyz[2], e0xyz[1]]
	var n_yz_e1: PackedFloat64Array = [-e1xyz[2], e1xyz[1]]
	var n_yz_e2: PackedFloat64Array = [-e2xyz[2], e2xyz[1]]

	if n[0] < 0:
		n_yz_e0 = [e0xyz[2], -e0xyz[1]]
		n_yz_e1 = [e1xyz[2], -e1xyz[1]]
		n_yz_e2 = [e2xyz[2], -e2xyz[1]]
		
	var d_yz_e0: float = -Dvector.dot(n_yz_e0, v0yz)
	var d_yz_e1: float = -Dvector.dot(n_yz_e1, v1yz)
	var d_yz_e2: float = -Dvector.dot(n_yz_e2, v2yz)

	var is_left_edge_e0: bool = n_yz_e0[0] > 0
	var is_left_edge_e1: bool = n_yz_e1[0] > 0
	var is_left_edge_e2: bool = n_yz_e2[0] > 0

	var is_top_edge_e0: bool = n_yz_e0[0] == 0.0 and n_yz_e0[1] < 0
	var is_top_edge_e1: bool = n_yz_e1[0] == 0.0 and n_yz_e1[1] < 0
	var is_top_edge_e2: bool = n_yz_e2[0] == 0.0 and n_yz_e2[1] < 0

	var f_yz_e0: float = 0
	var f_yz_e1: float = 0
	var f_yz_e2: float = 0

	if is_left_edge_e0 or is_top_edge_e0:
		f_yz_e0 = solid_voxelization_top_left_edge_epsilon
	if is_left_edge_e1 or is_top_edge_e1:
		f_yz_e1 = solid_voxelization_top_left_edge_epsilon
	if is_left_edge_e2 or is_top_edge_e2:
		f_yz_e2 = solid_voxelization_top_left_edge_epsilon

	# Bounding box in voxel coordinate
	#
	# Use floori(x + 0.) instead of roundi(x) to make sure that 
	# 0.5 cases are handled consistently
	#
	# Voxel coordinates are offseted by 0.5 
	# because we are considering voxel centers
	var rect2i: Rect2i = Rect2i()
	rect2i.position = Vector2i(
		ceili(min(v0yz[0], v1yz[0], v2yz[0]) / voxel_size_yz[0] - 0.5), 
		ceili(min(v0yz[1], v1yz[1], v2yz[1]) / voxel_size_yz[1] - 0.5)
		)
	rect2i.end = Vector2i(
		floori(max(v0yz[0], v1yz[0], v2yz[0]) / voxel_size_yz[0] + 0.5), 
		floori(max(v0yz[1], v1yz[1], v2yz[1]) / voxel_size_yz[1] + 0.5))

	if not rect2i.has_area():
		return

	var voxel_center_yz: PackedFloat64Array = [0.0, 0.0]
	for voxel_y in range(rect2i.position[0], rect2i.end[0]):
		voxel_center_yz[0] = (voxel_y+0.5) * voxel_size_yz[0]
		for voxel_z in range(rect2i.position[1], rect2i.end[1]):
			voxel_center_yz[1] = (voxel_z+0.5) * voxel_size_yz[1]
			
			#var t0 = Dvector.dot(n_yz_e0, voxel_center_yz) + d_yz_e0 + f_yz_e0
			#var t1 = Dvector.dot(n_yz_e1, voxel_center_yz) + d_yz_e1 + f_yz_e1
			#var t2 = Dvector.dot(n_yz_e2, voxel_center_yz) + d_yz_e2 + f_yz_e2
			var edge_value_e0: float = Dvector.dot(n_yz_e0, voxel_center_yz) + d_yz_e0 + f_yz_e0
			var edge_value_e1: float = Dvector.dot(n_yz_e1, voxel_center_yz) + d_yz_e1 + f_yz_e1
			var edge_value_e2: float = Dvector.dot(n_yz_e2, voxel_center_yz) + d_yz_e2 + f_yz_e2
			
			var triangle_overlap_voxel_center =\
				edge_value_e0 > 0.0\
				and edge_value_e1 > 0.0\
				and edge_value_e2 > 0.0
					
			var rect2: Rect2 = Rect2()
			rect2.position = Vector2(voxel_y * voxel_size_yz[0], voxel_z * voxel_size_yz[1])
			rect2.size = Vector2(voxel_size_yz[0], voxel_size_yz[1])
			if rect2.has_point(Vector2(1.476336, 1.004249)):
				pass
			if rect2.has_point(Vector2(1.475474, 1.006704)):
				pass
				
			if not triangle_overlap_voxel_center:
				continue
			
			# n = (a, b, c)
			# Plane equation: ax + by + cz + d = 0
			# x = -(by + cz + d)/a
			# Also, shift the voxel position by size[0]/2 (half the navigation cube),
			# because the navigation cube originates from the center, 
			# not from the corner of the cube (as we expect it to be)
			var plane_equation_d = - Dvector.dot(n, v0)
			#var projected_x = -(n[1] * voxel_center_yz[0] + n[2] * voxel_center_yz[1] + plane_equation_d)/n[0]
			
			var voxel_x: int = floori(0.5 - 
				(n[1] * voxel_center_yz[0] + n[2] * voxel_center_yz[1] + plane_equation_d)/
				(n[0] * voxel_size[0]))

			# clamp to valid x range
			var grid_x: int = int(flight_navigation_size[0] / voxel_size[0])
			voxel_x = clamp(voxel_x, 0, grid_x - 1)
			
			var voxel_morton: int = Morton3.encode64(voxel_x, voxel_y, voxel_z)
			var voxel_svolink: int  = svo.get_svolink_from_voxel_morton(voxel_morton)

			# Could be null, because triangles on the face of navigation space
			# might be projected to an outside voxel.
			if voxel_svolink == SvoLink64.singleton.null_link():
				continue
			var offset = SvoLink64.singleton.get_offset(voxel_svolink)
			var subgrid = SvoLink64.singleton.get_subgrid(voxel_svolink)
			
			var flip_mask: int = x_column_flip_bitmask_by_subgrid_index[subgrid]
			#var subgrid_vec3 = Morton3.decode_vec3i(subgrid)
			#var flip_mask_str = Morton.int_to_bin(flip_mask)
			svo.subgrid[offset] = svo.subgrid[offset] ^ flip_mask


@warning_ignore("shadowed_variable")
static func _parallel_yz_plane_rasterization_f32(
	triangle_index: int,
	svo: SVO,
	triangles: PackedVector3Array, 
	voxel_size: Vector3,
	x_column_flip_bitmask_by_subgrid_index: PackedInt64Array,
	flight_navigation_size: Vector3,
	solid_voxelization_top_left_edge_epsilon: float):
	var triangle_start_idx: int = triangle_index * 3
	
	var voxel_size_yz: Vector2 = Vector2(voxel_size[1], voxel_size[2])
	
	var v0: Vector3 = triangles[triangle_start_idx+0]
	var v1: Vector3 = triangles[triangle_start_idx+1]
	var v2: Vector3 = triangles[triangle_start_idx+2]

	var e0xyz: Vector3 = v1 - v0
	var e1xyz: Vector3 = v2 - v1
	var e2xyz: Vector3 = v0 - v2
	
	var v0yz: Vector2 = Vector2(v0[1], v0[2])
	var v1yz: Vector2 = Vector2(v1[1], v1[2])
	var v2yz: Vector2 = Vector2(v2[1], v2[2])

	#region Ensure consistent counter-clockwise order of vertices
	var not_is_ccw = e2xyz[1] * e0xyz[2] - e0xyz[1] * e2xyz[2] < 0
	if not_is_ccw:
		# Swap v1yz and v2yz
		var v_temp = v1yz
		v1yz = v2yz
		v2yz = v_temp
		
		# Recalculate edge equations. Turn v1yz into v2yz and vice versa.
		e0xyz = v2 - v0
		e1xyz = v1 - v2
		e2xyz = v0 - v1
	#endregion

	var n: Vector3 = e0xyz.cross(e1xyz)

	# Ignore projected triangles that are too thin.
	if is_zero_approx(n[0]):
	#if absf(n[0]) < epsilon:
		return

	var n_yz_e0: Vector2 = Vector2(-e0xyz[2], e0xyz[1])
	var n_yz_e1: Vector2 = Vector2(-e1xyz[2], e1xyz[1])
	var n_yz_e2: Vector2 = Vector2(-e2xyz[2], e2xyz[1])

	if n[0] < 0:
		n_yz_e0 = Vector2(e0xyz[2], -e0xyz[1])
		n_yz_e1 = Vector2(e1xyz[2], -e1xyz[1])
		n_yz_e2 = Vector2(e2xyz[2], -e2xyz[1])
		
	var d_yz_e0: float = -n_yz_e0.dot(v0yz)
	var d_yz_e1: float = -n_yz_e1.dot(v1yz)
	var d_yz_e2: float = -n_yz_e2.dot(v2yz)

	var is_left_edge_e0: bool = n_yz_e0[0] > 0
	var is_left_edge_e1: bool = n_yz_e1[0] > 0
	var is_left_edge_e2: bool = n_yz_e2[0] > 0

	var is_top_edge_e0: bool = n_yz_e0[0] == 0.0 and n_yz_e0[1] < 0
	var is_top_edge_e1: bool = n_yz_e1[0] == 0.0 and n_yz_e1[1] < 0
	var is_top_edge_e2: bool = n_yz_e2[0] == 0.0 and n_yz_e2[1] < 0

	var f_yz_e0: float = 0
	var f_yz_e1: float = 0
	var f_yz_e2: float = 0

	if is_left_edge_e0 or is_top_edge_e0:
		f_yz_e0 = solid_voxelization_top_left_edge_epsilon
	if is_left_edge_e1 or is_top_edge_e1:
		f_yz_e1 = solid_voxelization_top_left_edge_epsilon
	if is_left_edge_e2 or is_top_edge_e2:
		f_yz_e2 = solid_voxelization_top_left_edge_epsilon

	# Bounding box in voxel coordinate
	#
	# Use floori(x + 0.) instead of roundi(x) to make sure that 
	# 0.5 cases are handled consistently
	#
	# Voxel coordinates are offseted by 0.5 
	# because we are considering voxel centers
	var rect2i: Rect2i = Rect2i()
	rect2i.position = Vector2i(
		ceili(min(v0yz[0], v1yz[0], v2yz[0]) / voxel_size_yz[0] - 0.5), 
		ceili(min(v0yz[1], v1yz[1], v2yz[1]) / voxel_size_yz[1] - 0.5)
		)
	rect2i.end = Vector2i(
		floori(max(v0yz[0], v1yz[0], v2yz[0]) / voxel_size_yz[0] + 0.5), 
		floori(max(v0yz[1], v1yz[1], v2yz[1]) / voxel_size_yz[1] + 0.5))

	if not rect2i.has_area():
		return

	var voxel_center_yz: Vector2 = Vector2.ZERO
	for voxel_y in range(rect2i.position[0], rect2i.end[0]):
		voxel_center_yz[0] = (voxel_y+0.5) * voxel_size_yz[0]
		for voxel_z in range(rect2i.position[1], rect2i.end[1]):
			voxel_center_yz[1] = (voxel_z+0.5) * voxel_size_yz[1]
			var edge_value_e0: float = n_yz_e0.dot(voxel_center_yz) + d_yz_e0 + f_yz_e0
			var edge_value_e1: float = n_yz_e1.dot(voxel_center_yz) + d_yz_e1 + f_yz_e1
			var edge_value_e2: float = n_yz_e2.dot(voxel_center_yz) + d_yz_e2 + f_yz_e2
			
			var triangle_overlap_voxel_center =\
				edge_value_e0 > 0.0\
				and edge_value_e1 > 0.0\
				and edge_value_e2 > 0.0
			
			if not triangle_overlap_voxel_center:
				continue
			
			# n = (a, b, c)
			# Plane equation: ax + by + cz + d = 0
			# x = -(by + cz + d)/a
			# Also, shift the voxel position by size[0]/2 (half the navigation cube),
			# because the navigation cube originates from the center, 
			# not from the corner of the cube (as we expect it to be)
			var plane_equation_d = - n.dot(v0)
			#var projected_x = -(n[1] * voxel_center_yz[0] + n[2] * voxel_center_yz[1] + plane_equation_d)/n[0]
			
			var voxel_x: int = floori(0.5 - 
				(n[1] * voxel_center_yz[0] + n[2] * voxel_center_yz[1] + plane_equation_d)/
				(n[0] * voxel_size[0]))

			# clamp to valid x range
			var grid_x: int = int(flight_navigation_size[0] / voxel_size[0])
			voxel_x = clamp(voxel_x, 0, grid_x - 1)
			
			var voxel_morton: int = Morton3.encode64(voxel_x, voxel_y, voxel_z)
			var voxel_svolink: int  = svo.get_svolink_from_voxel_morton(voxel_morton)

			# Could be null, because triangles on the face of navigation space
			# might be projected to an outside voxel.
			if voxel_svolink == SvoLink64.singleton.null_link():
				continue
			var offset = SvoLink64.singleton.get_offset(voxel_svolink)
			var subgrid = SvoLink64.singleton.get_subgrid(voxel_svolink)
			
			var flip_mask: int = x_column_flip_bitmask_by_subgrid_index[subgrid]
			#var subgrid_vec3 = Morton3.decode_vec3i(subgrid)
			#var flip_mask_str = Morton.int_to_bin(flip_mask)
			svo.subgrid[offset] = svo.subgrid[offset] ^ flip_mask



@warning_ignore("shadowed_variable")
static func _parallel_propagate_bit_flip(
	head_node_index: int, 
	list_head_node_offset_of_layer_0: PackedInt64Array,
	subgrid_voxel_indexes_on_face_direction: PackedInt32Array,
	neighbor_direction_to_flip: Array[PackedInt64Array], # svo.xp
	svo_subgrid: PackedInt64Array, # svo.subgrid
	neighbor_node_x_column_bits_by_subgrid_index: Dictionary[int, int]
):
	var current_node_offset = list_head_node_offset_of_layer_0[head_node_index]
	while true:
		var neighbor_svolink = neighbor_direction_to_flip[0][current_node_offset]
		if neighbor_svolink == SvoLink64.singleton.null_link():
			break
		var neighbor_layer = SvoLink64.singleton.get_layer(neighbor_svolink)
		# Stop bit propagation when reaching a coarser layer
		if neighbor_layer != 0:
			break

		var flip_buffer: int = 0
		for subgrid_index in subgrid_voxel_indexes_on_face_direction:
			var last_bit_in_the_column_is_solid = \
				svo_subgrid[current_node_offset] & (1 << subgrid_index)
			if last_bit_in_the_column_is_solid:
				flip_buffer = flip_buffer | neighbor_node_x_column_bits_by_subgrid_index[subgrid_index]
		var neighbor_offset: int = SvoLink64.singleton.get_offset(neighbor_svolink)
		svo_subgrid[neighbor_offset] = svo_subgrid[neighbor_offset] ^ flip_buffer
		
		# Increment condition
		current_node_offset = neighbor_offset
		
		
static func _parallel_propagate_flip_and_inside(
	head_node_offset: int,
	layer: int,
	list_head_node_offset_of_layer: Array[PackedInt64Array], 
	neighbor_direction: Array[PackedInt64Array], #SVO.xp
	flip_flag: Array[PackedByteArray],
	svo_inside: Array[PackedByteArray]):
	var neighbor_direction_layer = neighbor_direction[layer]
	var flip_flag_layer = flip_flag[layer]
	var svo_inside_layer = svo_inside[layer]
	var current_node_offset = list_head_node_offset_of_layer[layer][head_node_offset]
	while true:
		var neighbor_svolink = neighbor_direction_layer[current_node_offset]
		if neighbor_svolink == SvoLink64.singleton.null_link():
			break
		var neighbor_layer = SvoLink64.singleton.get_layer(neighbor_svolink)
		if neighbor_layer != layer:
			break
			
		var neighbor_offset = SvoLink64.singleton.get_offset(neighbor_svolink)
		if flip_flag_layer[current_node_offset]:
			var neighbor_flip_flag = flip_flag_layer[neighbor_offset]
			var neighbor_inside_flag = svo_inside_layer[neighbor_offset]
			flip_flag_layer[neighbor_offset] = neighbor_flip_flag ^ 1
			svo_inside_layer[neighbor_offset] = neighbor_inside_flag ^ 1
		# Increment condition
		current_node_offset = neighbor_offset
#endregion



#region Voxelize Triangles

#endregion
#endregion
