## Voxelize all FlightNavigationTarget inside this area
##
## TODO: Remove redundant .fill() in initialization
@tool
@warning_ignore_start("integer_division")
extends CSGBox3D
class_name FlightNavigation3D

signal progress(step: ProgressStep, svo: SVO, work_completed: int, total_work: int)

## Enum used in tandem with [member progress] signal,
## for logging, testing, debugging purpose.
enum ProgressStep {
	GET_ALL_VOXELIZATION_TARGET,
	BUILD_MESH,
	REMOVE_THIN_TRIANGLES,
	OFFSET_VERTICES_TO_LOCAL_COORDINATE,
	DETERMINE_ACTIVE_LAYER_1_NODES,
	CONSTRUCT_SVO,
	SOLID_VOXELIZATION,
	HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION,
	YZ_PLANE_RASTERIZATION,
	PREPARE_FLAGS_AND_HEAD_NODES,
	XP_BIT_FLIP_PROPAGATION,
	PREPARE_FLIP_FLAG_LAYER_1,
	FLIP_BOTTOM_UP_LAYER_1,
	PROPAGATE_FLIP_INFORMATION_LAYER_1,
	PREPARE_FLIP_FLAG_FROM_LAYER_2,
	FLIP_BOTTOM_UP_FROM_LAYER_2,
	PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2,
	PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES,
	PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS,
	SURFACE_VOXELIZATION,
	CALCULATE_COVERAGE_FACTOR,
	
	## If used for [draw_on_step_completion], nothing will be drawn.
	MAX_STEP,
}

@export var sparse_voxel_octree: SVO

## Pathfinding algorithm used for [method find_path]
@export var pathfinder: FlightPathfinder


#region Voxelization parameters
@export_group("Voxelization parameters")
@export_subgroup("Multi-threading", "")
## Enable multi-threading while building navigation data. [br]
## Set to false for easier debugging in single-threading.
@export var multi_threading: bool = true

## Thread priority when used in [member multi_threading]
@export var thread_priority: Thread.Priority = Thread.PRIORITY_LOW
@export_subgroup("", "")

@export_subgroup("Voxelization targets handling", "")
## Many [FlightNavigation3D] could coexist in one scene, 
## and you might decide that some objects will voxelize
## in one [FlightNavigation3D] but not the others.
##
## Voxelize [VoxelizationTarget]s
## whose mask overlaps with [FlightNavigation3D]
@export_flags_3d_navigation var voxelization_mask: int = 1

## Remove triangles with area close to zero before voxelization (recommended).
## [br]
## FlightNavigation3D uses CSG nodes internally, and the result meshes contain 
## lots of triangles with 2 vertices in the same position.
@export var remove_thin_triangles: bool = true
@export_subgroup("", "")

@export_subgroup("SVO properties", "")

## Determine how detailed the space will be voxelized.
## [br]
## Increase this value will exponentially increase memory usage and voxelization time.
@export_range(2, 15, 1) var depth: int = 7:
	set(value):
		depth = value
		var res = 2**(value+1)
		resolution = "%d x %d x %d" % [res, res, res]


## (Readonly) The amount of subgrid voxels on each dimension.
## The higher the resolution, the better the space can capture fine details.
@export var resolution: String = "256 x 256 x 256":
	set(value):
		var res = 2**(depth+1)
		resolution = "%d x %d x %d" % [res, res, res]

## The [Resource] format to save, when voxelized via editor addon.[br]
## [b].res[/b] is recommended to save space.
@export_enum(".tres", ".res") var resource_format: String = ".res"

@export_subgroup("Solid voxelization", "")
## Construct inside/outside states of the space,
## useful for [FlightPathfinder] algorithms.
## [br]
## [b]NOTE:[/b] If you want to voxelize objects to display, not for navigation,
## then you may omit solid voxelization and go for SEPARATING_26 surface voxelization.
@export var perform_solid_voxelization: bool = true:
	set(value):
		perform_solid_voxelization = value
		update_configuration_warnings()

## Calculate the percentage of solid volume for each SVO node.[br]
## Useful for heuristic navigation algorithms.
@export var calculate_coverage_factor: bool = true
@export_subgroup("", "")

@export_subgroup("Surface voxelization", "")
## Capture fine details like thin sheets, tree leaves,...
## [br]
## [b]NOTE:[/b] If you care only about navigation, you may not need this.
@export var perform_surface_voxelization: bool = true:
	set(value):
		perform_surface_voxelization = value
		update_configuration_warnings()

## Surface voxelization "thickness". [br]
## Default to [enum TriangleBoxTest.Separability.SEPARATING_26] (all voxels touched by the surface).
@export var surface_separability:\
	TriangleBoxTest.Separability = TriangleBoxTest.Separability.SEPARATING_26
@export_subgroup("", "")

@export_subgroup("Debug", "debug_")

## Whether CSG nodes created for each Voxelization targets 
## are deleted after voxelization.
## [br]
## Used to visualize and debug CSG nodes creation.
@export var debug_delete_csg: bool = true

## Delete flip flags after solid voxelization to save memory.[br]
## Used for testing purpose
@export var debug_delete_flip_flag: bool = true

@export_subgroup("")

@export_subgroup("", "")
@export_group("", "")
#endregion


## Return a path that connects [param from] and [param to].[br]
## [param from], [param to] are in global coordinate.[br]
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var from_svolink: int = get_svolink_of(from)
	var to_svolink: int = get_svolink_of(to)
	var svolink_path: Array = pathfinder.find_path(
		from_svolink, to_svolink, sparse_voxel_octree)
	var vec3_path = PackedVector3Array()
	vec3_path.resize(svolink_path.size())
	for i in range(svolink_path.size()):
		vec3_path[i] = get_global_position_of(svolink_path[i])
	return vec3_path

#region Build navigation
## The "smallest" floating point number.
## Usually used for float comparisons.
const epsilon: float = 0.0000001

## Construct an SVO that can be assigned to [member sparse_voxel_octree] later.[br]
## [b]NOTE:[/b] Only one build process can be run at a time for each FlightNavigation3D.
func build_navigation() -> SVO:
	#region Copy variables to make build_navigation() reentrant 
	var new_depth = depth
	var new_thread_priority = thread_priority
	var new_voxelization_mask = voxelization_mask
	var flight_navigation_size = size
	#endregion
	
	#region Commonly used variables
	var async_context = get_tree().process_frame
	var voxel_size: Vector3 = _node_size(flight_navigation_size, -2, new_depth)
	
	var offset_by_half_voxel_size_x = Vector3(voxel_size.x/2, 0, 0)
	var origin_offset = _origin_offset()
	#endregion
	
	#region Prepare triangles
	
	#region Get all voxelization_target
	progress.emit(ProgressStep.GET_ALL_VOXELIZATION_TARGET, null, 0, 1)
	# Array[VoxelizationTarget]
	var all_target_array = get_tree().get_nodes_in_group("voxelization_target")
	var target_array: Array = []
	target_array.resize(all_target_array.size())
	target_array.resize(0)
	for target in all_target_array:
		if target.voxelization_mask & new_voxelization_mask != 0:
			target_array.push_back(target)
	progress.emit(ProgressStep.GET_ALL_VOXELIZATION_TARGET, null, 1, 1)
	#endregion
	
	#region Build mesh
	progress.emit(ProgressStep.BUILD_MESH, null, 0, 1)
	var union_voxelization_target_shapes = CSGCombiner3D.new()
	union_voxelization_target_shapes.operation = CSGShape3D.OPERATION_INTERSECTION
	# The combiner must be added as child first, so that its children could have
	# their global transforms modified.
	#
	# call_deferred() is used to work in multithreading
	add_child.call_deferred(union_voxelization_target_shapes)
	await async_context # Wait for call_deferred to complete
	
	for target in target_array:
		var csg_shapes = target.get_csg()
		for shape in csg_shapes:
			union_voxelization_target_shapes.add_child(shape)
			shape.global_transform = target.global_transform
			shape.operation = CSGShape3D.OPERATION_UNION
			
	# Since CSG nodes do not update immediately, calling bake_static_mesh() 
	# right away does not return the actual result.
	# So we must wait until next frame.
	await async_context
	var mesh = bake_static_mesh()
	if debug_delete_csg:
		remove_child(union_voxelization_target_shapes)
		union_voxelization_target_shapes.free()
	
	var triangles: PackedVector3Array = mesh.get_faces()
	progress.emit(ProgressStep.BUILD_MESH, null, 1, 1)
	#endregion
	
	# Clean up generated faces from CSG shapes by doing these things:[br]
	# - Remove all faces with 2 or more vertices identical to each other [br]
	# - Remove all faces with 3 vertices lie on the same line[br]
	# - [NOT YET SUPPORTED] Remove identical faces (same set of 3 points)[br]
	if remove_thin_triangles:
		progress.emit(ProgressStep.REMOVE_THIN_TRIANGLES, null, 0, 1)
		
		var fat_triangle_count: int = 0
		var cleaned_triangles: PackedVector3Array
		if multi_threading:
			var count_result = await Parallel.count_if_by_batch(
				async_context, 
				triangles.size()/3, 
				new_thread_priority,
				10000,
				_parallel_is_non_zero_area_triangle.bind(triangles)
			)
			var batch_size = count_result.batch_size
			var list_count_if_by_batch = count_result.list_count_if_by_batch
			fat_triangle_count = Fn3dUtility.sum_array_number(list_count_if_by_batch)
			cleaned_triangles.resize(fat_triangle_count*3)
			
			var list_start_write_index: PackedInt64Array = \
				Parallel.make_start_write_index_array_from_count_array(
					list_count_if_by_batch)
			
			await Parallel.execute_batched(
				async_context, 
				triangles.size()/3,
				new_thread_priority,
				batch_size,
				_parallel_batched_write_clean_triangles.bind(
					triangles,
					cleaned_triangles,
					list_start_write_index
				))
		else:
			for i in range(triangles.size()/3):
				if _parallel_is_non_zero_area_triangle(i, triangles):
					fat_triangle_count += 1
			cleaned_triangles.resize(fat_triangle_count*3)
			cleaned_triangles.resize(0)
			for i in range(triangles.size()/3):
				if _parallel_is_non_zero_area_triangle(i, triangles):
					var start_index = i*3
					cleaned_triangles.push_back(triangles[start_index])
					cleaned_triangles.push_back(triangles[start_index+1])
					cleaned_triangles.push_back(triangles[start_index+2])
		
		triangles = cleaned_triangles
		progress.emit(ProgressStep.REMOVE_THIN_TRIANGLES, null, 1, 1)
	#$MeshInstance3D.mesh = MeshTool.create_array_mesh_from_faces(triangles)
	
	# Add half a cube offset to each vertex, 
	# because morton code index starts from the corner of the cube
	progress.emit(ProgressStep.OFFSET_VERTICES_TO_LOCAL_COORDINATE, null, 0, triangles.size())
	if multi_threading:
		await Parallel.execute_batched(
			async_context, 
			triangles.size(),
			new_thread_priority,
			1000000,
			_parallel_batched_offset_triangle.bind(
				triangles,
				-origin_offset,
			))
	else:
		for i in range(0, triangles.size()):
			_parallel_batched_offset_triangle(
				i, i, i+1,
				triangles,
				-origin_offset
			)
	progress.emit(ProgressStep.OFFSET_VERTICES_TO_LOCAL_COORDINATE, null, triangles.size(), triangles.size())
	#endregion
	
	#region Determine active layer 1 nodes
	# Return dictionary of key - value: Active node morton code - Overlapping triangles.[br]
	# Overlapping triangles are serialized. Every 3 elements make up a triangle.[br]
	# [param polygon] is assumed to have length divisible by 3. Every 3 elements make up a triangle.[br]
	# [b]NOTE:[/b] This method allocates one thread per triangle
	
	# TODO: Count node 1 and then pre-allocate data.
	
	progress.emit(ProgressStep.DETERMINE_ACTIVE_LAYER_1_NODES, null, 0, triangles.size()/3)
	# Mapping between active layer 1 node, and the triangles overlap it
	var act1node_triangles: Dictionary[int, PackedVector3Array] = {}
	
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
	
	#region Shift triangles in x+ by half a level-0 sub-grid voxel
	var triangles_shifted: PackedVector3Array = triangles.duplicate()
	
	if multi_threading:
		await Parallel.execute_batched(
			async_context, 
			triangles_shifted.size(),
			new_thread_priority,
			100000,
			_parallel_batched_offset_triangle.bind(
				triangles_shifted,
				offset_by_half_voxel_size_x,
			))
	else:
		for i in range(0, triangles_shifted.size()):
			triangles_shifted[i] += offset_by_half_voxel_size_x
	#endregion
	
	# TODO: Make this PackedInt64Array
	var list_active_layer_1_morton: Array = []
	
	if multi_threading:
		var threads: Array[Thread] = []
		threads.resize(triangles_shifted.size() / 3)
		threads.resize(0)
		for i in range(0, triangles_shifted.size(), 3):
			threads.push_back(Thread.new())
			# TODO: Change slice() into indexing into triangle array
			var err = threads.back().start(
				voxelize_triangle_node_1.bind(
					voxel_size, 
					triangles_shifted.slice(i, i+3)), 
					new_thread_priority)
			if err != OK:
				pass
		
		for i in range(threads.size()):
			var t = threads[i]
			progress.emit(ProgressStep.DETERMINE_ACTIVE_LAYER_1_NODES, null, i, triangles_shifted.size()/3)
			while true:
				if not t.is_alive():
					var triangles_overlap_node_dictionary = t.wait_to_finish()
					_merge_triangle_overlap_node_dicts(act1node_triangles, triangles_overlap_node_dictionary)
					break
				else:
					await async_context
	else:
		for i in range(0, triangles_shifted.size(), 3):
			# TODO: Change slice() into indexing into triangle array
			var triangle_overlap_node_dictionary = voxelize_triangle_node_1(
				voxel_size, triangles_shifted.slice(i, i+3))
			_merge_triangle_overlap_node_dicts(act1node_triangles, triangle_overlap_node_dictionary)
	progress.emit(ProgressStep.DETERMINE_ACTIVE_LAYER_1_NODES, null, triangles.size()/3, triangles.size()/3)
	#endregion
	
	list_active_layer_1_morton = act1node_triangles.keys()
	
	#region Construct SVO
	var svo = SVO.new()
	
	progress.emit(ProgressStep.CONSTRUCT_SVO, svo, 0, 2)
	
	if list_active_layer_1_morton.size() == 0:
		printerr("No layer 1 node found")
		return null
		
	svo.morton.resize(new_depth)
	svo.parent.resize(new_depth)
	svo.first_child.resize(new_depth)
	#svo.subgrid.resize later, when we figured out how many leaf SVONode are there.
	svo.xp.resize(new_depth)
	svo.yp.resize(new_depth)
	svo.zp.resize(new_depth)
	svo.xn.resize(new_depth)
	svo.yn.resize(new_depth)
	svo.zn.resize(new_depth)
	
	#region Construct from bottom up
	list_active_layer_1_morton.sort()
	
	#region Initialize layer 0
	var layer_0_size = list_active_layer_1_morton.size() * 8
	
	svo.morton[0].resize(layer_0_size)
	svo.parent[0].resize(layer_0_size)
	svo.first_child[0].resize(0) # The leaf layer has no children, only voxels
	svo.subgrid.resize(layer_0_size)
	svo.xp[0].resize(layer_0_size)
	svo.yp[0].resize(layer_0_size)
	svo.zp[0].resize(layer_0_size)
	svo.xn[0].resize(layer_0_size)
	svo.yn[0].resize(layer_0_size)
	svo.zn[0].resize(layer_0_size)
	
	svo.morton[0].fill(SVOLink.NULL)
	svo.parent[0].fill(SVOLink.NULL)
	#svo.first_child[0]
	#svo.subgrid
	svo.xp[0].fill(SVOLink.NULL)
	svo.yp[0].fill(SVOLink.NULL)
	svo.zp[0].fill(SVOLink.NULL)
	svo.xn[0].fill(SVOLink.NULL)
	svo.yn[0].fill(SVOLink.NULL)
	svo.zn[0].fill(SVOLink.NULL)
	#endregion
	
	var current_active_layer_nodes = list_active_layer_1_morton
	
	# An array to hold the parent index on above layer of the current layer in building.
	# It is kept outside the for-loop to reduce memory re-allocation.
	var parent_idx = current_active_layer_nodes.duplicate()
	
	# Init layer 1 upward
	for layer in range(1, new_depth):
		# Fill children's morton code 
		for i in range(current_active_layer_nodes.size()):
			for child in range(8):
				svo.morton[layer-1][i*8+child] = (current_active_layer_nodes[i] << 3) | child
				
		parent_idx[0] = 0
		
		# ROOT NODE CASE
		if layer == new_depth-1:
			#region Initialize root layer
			svo.morton[layer].resize(1)
			svo.parent[layer].resize(1)
			svo.first_child[layer].resize(1)
			#svo.subgrid
			svo.xp[layer].resize(1)
			svo.yp[layer].resize(1)
			svo.zp[layer].resize(1)
			svo.xn[layer].resize(1)
			svo.yn[layer].resize(1)
			svo.zn[layer].resize(1)
			
			svo.morton[layer][0] = 0
			svo.parent[layer][0] = SVOLink.NULL
			svo.first_child[layer][0] = SVOLink.from(layer-1, 0)
			#svo.subgrid
			svo.xp[layer][0] = SVOLink.NULL
			svo.yp[layer][0] = SVOLink.NULL
			svo.zp[layer][0] = SVOLink.NULL
			svo.xn[layer][0] = SVOLink.NULL
			svo.yn[layer][0] = SVOLink.NULL
			svo.zn[layer][0] = SVOLink.NULL
			
			#endregion
		else:
			for i in range(1, current_active_layer_nodes.size()):
				parent_idx[i] = parent_idx[i-1]
				if _mortons_different_parent(
						current_active_layer_nodes[i-1], 
						current_active_layer_nodes[i]):
					parent_idx[i] += 1
		
			## Allocate memory for current layer
			var current_layer_size = (parent_idx[parent_idx.size()-1] + 1) * 8
			
			svo.morton[layer].resize(current_layer_size)
			svo.parent[layer].resize(current_layer_size)
			svo.first_child[layer].resize(current_layer_size)
			#svo.subgrid
			svo.xp[layer].resize(current_layer_size)
			svo.yp[layer].resize(current_layer_size)
			svo.zp[layer].resize(current_layer_size)
			svo.xn[layer].resize(current_layer_size)
			svo.yn[layer].resize(current_layer_size)
			svo.zn[layer].resize(current_layer_size)

			svo.morton[layer].fill(~0) # ~0 is 111111111...1111. An invalid initial value.
			svo.parent[layer].fill(SVOLink.NULL)
			svo.first_child[layer].fill(SVOLink.NULL)
			#svo.subgrid
			svo.xp[layer].fill(SVOLink.NULL)
			svo.yp[layer].fill(SVOLink.NULL)
			svo.zp[layer].fill(SVOLink.NULL)
			svo.xn[layer].fill(SVOLink.NULL)
			svo.yn[layer].fill(SVOLink.NULL)
			svo.zn[layer].fill(SVOLink.NULL)
			
		#region Fill parent/children index
		for active_node_idx in range(current_active_layer_nodes.size()):
			# In between active nodes are inactive nodes.
			# Inactive nodes are the ones without any triangle overlapped.
			# So, active_node_offset is the actual offset of the current active node
			# inside the SVO.
			var active_node_offset = 8*parent_idx[active_node_idx] + (current_active_layer_nodes[active_node_idx] & 0b111)
			svo.first_child[layer][active_node_offset] = SVOLink.from(layer-1, 8*active_node_idx)
			var link_to_parent = SVOLink.from(layer, active_node_offset)
			for child in range(8):
				svo.parent[layer-1][8*active_node_idx + child] = link_to_parent
		#endregion
		
		#region Get parent morton codes to prepare for the next layer construction
		var new_active_layer_nodes: PackedInt64Array = []
		if current_active_layer_nodes.size() > 0:
			new_active_layer_nodes.resize(current_active_layer_nodes.size()) # Pre-allocate memory
			new_active_layer_nodes.resize(0)
			new_active_layer_nodes.push_back(current_active_layer_nodes[0] >> 3)
			
			for morton in current_active_layer_nodes:
				var parent_code = morton>>3
				if new_active_layer_nodes[new_active_layer_nodes.size()-1] != parent_code:
					new_active_layer_nodes.push_back(parent_code)
		#endregion

		current_active_layer_nodes = new_active_layer_nodes
	#endregion
	
	progress.emit(ProgressStep.CONSTRUCT_SVO, svo, 1, 2)
	#region Fill neighbor links from top down
	# Array[Array[PackedInt64Array]]
	var list_neighbor_direction: Array = [
		svo.xn , svo.yn , svo.zn ,
		svo.xp , svo.yp , svo.zp]
	var list_next_neighbor_calculator: Array[Callable] = [
		Morton3.dec_x, Morton3.dec_y, Morton3.dec_z, 
		Morton3.inc_x, Morton3.inc_y, Morton3.inc_z]
	if multi_threading:
		await Parallel.execute(
			async_context, 
			list_neighbor_direction.size(),
			new_thread_priority,
			_parallel_fill_neighbor_in_direction.bind(
				svo, 
				list_neighbor_direction, 
				list_next_neighbor_calculator))
	else:
		for i in range(list_neighbor_direction.size()):
			_parallel_fill_neighbor_in_direction(
				i,
				svo, 
				list_neighbor_direction, 
				list_next_neighbor_calculator)
	#endregion
	
	progress.emit(ProgressStep.CONSTRUCT_SVO, svo, 2, 2)
	#endregion
	
	#region Solid voxelization
	if perform_solid_voxelization:
		progress.emit(ProgressStep.SOLID_VOXELIZATION, svo, 0, 2)
		
		#region YZ plane rasterization, and projection on x column
		progress.emit(ProgressStep.YZ_PLANE_RASTERIZATION, svo, 0, triangles.size()/3)
		if multi_threading:
			await Parallel.execute(
				async_context, 
				triangles.size()/3,
				new_thread_priority,
				_parallel_yz_plane_rasterization.bind(
					svo, 
					triangles, 
					voxel_size,
					_x_column_flip_bitmask_by_subgrid_index,
					flight_navigation_size))
		else:
			for i in range(triangles.size()/3):
				_parallel_yz_plane_rasterization(i, svo, triangles, voxel_size,
				_x_column_flip_bitmask_by_subgrid_index,
				flight_navigation_size)
		
		progress.emit(ProgressStep.YZ_PLANE_RASTERIZATION, svo, triangles.size()/3, triangles.size()/3)
		#endregion
		
		progress.emit(ProgressStep.SOLID_VOXELIZATION, svo, 1, 2)
		#region Hierarchical inside/outside propagation
		
		progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 0, 6)
		
		#region Prepare flip flags, inside flags, list head nodes
		progress.emit(ProgressStep.PREPARE_FLAGS_AND_HEAD_NODES, svo, 0, 3)
		# Flip flags of layer 0 are not used, so they are not initialized. 
		# Only inside flags are initialized.
		var flip_flag: Array[PackedByteArray] = []
		flip_flag.resize(svo.morton.size())
		for i in range(1, svo.morton.size()):
			flip_flag[i].resize(svo.morton[i].size())
			flip_flag[i].fill(0)
		svo.flip = flip_flag
		
		progress.emit(ProgressStep.PREPARE_FLAGS_AND_HEAD_NODES, svo, 1, 3)
			
		svo.inside.resize(svo.morton.size())
		for i in range(0, svo.morton.size()):
			svo.inside[i].resize(svo.morton[i].size())
			svo.inside[i].fill(0)
		
		progress.emit(ProgressStep.PREPARE_FLAGS_AND_HEAD_NODES, svo, 2, 3)
			
		var list_head_node_offset_of_layer: Array[PackedInt64Array] = []
		list_head_node_offset_of_layer.resize(svo.morton.size())
		for layer in range(0, svo.morton.size()):
			list_head_node_offset_of_layer[layer] = svo._get_list_offset_of_head_node_in_x_direction_of_layer(layer)
		
		progress.emit(ProgressStep.PREPARE_FLAGS_AND_HEAD_NODES, svo, 3, 3)
			
		#endregion
		
		progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 1, 6)
		#region Propagate bit flips in x+ direction
		
		var list_head_node_offset_of_layer_0: PackedInt64Array = list_head_node_offset_of_layer[0]
		var subgrid_voxel_indexes_on_face_xp: PackedInt32Array = subgrid_voxel_indexes_on_face["xp"]
		var svo_subgrid = svo.subgrid
		var svo_xp = svo.xp
		
		progress.emit(ProgressStep.XP_BIT_FLIP_PROPAGATION, 
			svo, 0, list_head_node_offset_of_layer_0.size())
		
		if multi_threading:
			await Parallel.execute(
				async_context, 
				list_head_node_offset_of_layer_0.size(),
				new_thread_priority,
				_parallel_propagate_bit_flip.bind(
						list_head_node_offset_of_layer_0,
						subgrid_voxel_indexes_on_face_xp,
						svo_xp,
						svo_subgrid))
		else:
			for i in range(list_head_node_offset_of_layer_0.size()):
				_parallel_propagate_bit_flip(
					i,
					list_head_node_offset_of_layer_0,
					subgrid_voxel_indexes_on_face_xp,
					svo_xp,
					svo_subgrid)
						
		progress.emit(ProgressStep.XP_BIT_FLIP_PROPAGATION, svo, 
			list_head_node_offset_of_layer_0.size(), list_head_node_offset_of_layer_0.size())
				
		#endregion
		
		progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 2, 6)
		#region Flip bottom up layer 1
		progress.emit(ProgressStep.FLIP_BOTTOM_UP_LAYER_1, svo, 0, 2)
		#region Prepare layer 1 flip flag
		progress.emit(ProgressStep.PREPARE_FLIP_FLAG_LAYER_1, svo, 0, flip_flag[1].size())
		# Set flip flag for layer-1 nodes with children 
		# at the end of a x-linked node string
		var svo_first_child = svo.first_child
		var svo_inside = svo.inside
		for i in range(0, flip_flag[1].size()):
			var first_child_svolink = svo_first_child[1][i]
			if first_child_svolink == SVOLink.NULL:
				continue
				
			var not_is_end_of_x_linked_node_string = true
			
			var xp_svolink = svo_xp[1][i]
			if xp_svolink == SVOLink.NULL:
				not_is_end_of_x_linked_node_string = false
			else:
				var xp_layer = SVOLink.layer(xp_svolink)
				var xp_offset = SVOLink.offset(xp_svolink)
				var xp_first_child = svo_first_child[1][xp_offset]
				not_is_end_of_x_linked_node_string = \
					xp_layer == 1 and xp_first_child != SVOLink.NULL
				
			if not_is_end_of_x_linked_node_string:
				continue
			
			var first_child_offset = SVOLink.offset(first_child_svolink)
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
			
			var child_on_xp_offset = first_child_offset + 1
			var child_subgrid = svo_subgrid[child_on_xp_offset]
			flip_flag[1][i] = int(bitmask_of_subgrid_voxels_on_face_xp == 
					(child_subgrid & bitmask_of_subgrid_voxels_on_face_xp))
			
		progress.emit(ProgressStep.PREPARE_FLIP_FLAG_LAYER_1, svo, flip_flag[1].size(), flip_flag[1].size())
		#endregion
		
		progress.emit(ProgressStep.FLIP_BOTTOM_UP_LAYER_1, svo, 1, 2)
		#region Propagate layer 1 flip information
		
		progress.emit(ProgressStep.PROPAGATE_FLIP_INFORMATION_LAYER_1, svo, 0, 
			list_head_node_offset_of_layer[1].size())
			
		if multi_threading:
			await Parallel.execute(
				async_context, 
				list_head_node_offset_of_layer[1].size(),
				new_thread_priority,
				_parallel_propagate_flip_and_inside.bind(
					1, 
					list_head_node_offset_of_layer,
					svo_xp, 
					flip_flag, 
					svo_inside))
		else:
			for head_node_index in range(list_head_node_offset_of_layer[1].size()):
				_parallel_propagate_flip_and_inside(
					head_node_index, 
					1, 
					list_head_node_offset_of_layer,
					svo_xp, 
					flip_flag, 
					svo_inside)
		
		progress.emit(ProgressStep.PROPAGATE_FLIP_INFORMATION_LAYER_1, svo, 
			list_head_node_offset_of_layer[1].size(), 
			list_head_node_offset_of_layer[1].size())
		#endregion
		
		progress.emit(ProgressStep.FLIP_BOTTOM_UP_LAYER_1, svo, 2, 2)
		#endregion
		
		progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 3, 6)
		#region Flip bottom up from layer 2
		progress.emit(ProgressStep.FLIP_BOTTOM_UP_FROM_LAYER_2, svo, 0, flip_flag.size())
		
		# Set flip flag for layer-1 nodes with children 
		# at the end of a z-linked node string
		# TODO: Parallelize operation in each layer, in all layers
		for layer in range(2, flip_flag.size()):
			#region Prepare flip flag
			var flip_flag_layer = flip_flag[layer]
			var flip_flag_child_layer = flip_flag[layer-1]
			progress.emit(ProgressStep.PREPARE_FLIP_FLAG_FROM_LAYER_2, svo, 0, flip_flag_layer.size())
			for i in range(0, flip_flag_layer.size()):
				var first_child_svolink = svo_first_child[layer][i]
				if first_child_svolink == SVOLink.NULL:
					continue
				var not_is_end_of_x_linked_node_string = true
				
				var xp_svolink = svo_xp[layer][i]
				if xp_svolink == SVOLink.NULL:
					not_is_end_of_x_linked_node_string = false
				else:
					var xp_layer = SVOLink.layer(xp_svolink)
					var xp_offset = SVOLink.offset(xp_svolink)
					var xp_first_child = svo_first_child[layer][xp_offset]
					not_is_end_of_x_linked_node_string = \
						xp_layer == layer and xp_first_child != SVOLink.NULL
					
				if not_is_end_of_x_linked_node_string:
					continue
				
				var first_child_offset = SVOLink.offset(first_child_svolink)
				var child_on_xp_offset = first_child_offset + 1
				flip_flag_layer[i] = flip_flag_child_layer[child_on_xp_offset]
			progress.emit(ProgressStep.PREPARE_FLIP_FLAG_FROM_LAYER_2, 
				svo, flip_flag_layer.size(), flip_flag_layer.size())
			#endregion
		
			#region Propagate flip information
			progress.emit(ProgressStep.PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2, 
				svo, 0, list_head_node_offset_of_layer[layer].size())
			if multi_threading:
				await Parallel.execute(
					async_context, 
					list_head_node_offset_of_layer[layer].size(),
					new_thread_priority,
					_parallel_propagate_flip_and_inside.bind(
						layer, 
						list_head_node_offset_of_layer,
						svo_xp, 
						flip_flag, 
						svo_inside))
			else:
				for head_node_index in range(list_head_node_offset_of_layer[layer].size()):
					_parallel_propagate_flip_and_inside(
						head_node_index,
						layer, 
						list_head_node_offset_of_layer,
						svo_xp, 
						flip_flag, 
						svo_inside)
				
			progress.emit(ProgressStep.PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2, 
				svo, list_head_node_offset_of_layer[layer].size(), 
				list_head_node_offset_of_layer[layer].size())
			#endregion
		
			progress.emit(ProgressStep.FLIP_BOTTOM_UP_FROM_LAYER_2,
				svo, layer, flip_flag.size())
			
		progress.emit(ProgressStep.FLIP_BOTTOM_UP_FROM_LAYER_2, svo, 
			flip_flag.size(), flip_flag.size())
		#endregion
		
		progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 4, 6)
		#region Propagate inside flags topdown for tree nodes
		
		progress.emit(ProgressStep.PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES, svo, 
			0, new_depth-1)
		for layer in range(new_depth-1, 0, -1):
			var svo_inside_layer = svo_inside[layer]
			var svo_inside_layer_child = svo_inside[layer-1]
			var svo_first_child_layer = svo.first_child[layer]
			for offset in range(svo_inside_layer.size()):
				if svo_inside_layer[offset]:
					var first_child_svolink = svo_first_child_layer[offset]
					if first_child_svolink == SVOLink.NULL:
						continue
					var first_child_offset = SVOLink.offset(first_child_svolink)
					for child in range(first_child_offset, first_child_offset + 8):
						svo_inside_layer_child[child] = svo_inside_layer_child[child] ^ 1
							
		progress.emit(ProgressStep.PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES, svo, 
			new_depth-1, new_depth-1)
		#endregion
		
		progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 5, 6)
		#region Propagate inside flag to subgrid voxels
		var svo_inside_layer_0 = svo_inside[0]
		progress.emit(ProgressStep.PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS, svo, 
			0, svo_inside_layer_0.size())
		for offset in range(svo_inside_layer_0.size()):
			if svo_inside_layer_0[offset]:
				svo_subgrid[offset] = ~svo_subgrid[offset]
		progress.emit(ProgressStep.PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS, svo, 
			svo_inside_layer_0.size(), svo_inside_layer_0.size())
		#endregion
		
		progress.emit(ProgressStep.HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION, svo, 6, 6)
		#endregion
		
		progress.emit(ProgressStep.SOLID_VOXELIZATION, svo, 2, 2)
		
		if debug_delete_flip_flag:
			svo.flip.clear()
		
	#endregion
	#region Surface voxelization
	if perform_surface_voxelization:
		progress.emit(ProgressStep.SURFACE_VOXELIZATION, svo, 
			0, act1node_triangles.keys().size())
		# Allocate each layer-1 node with 1 thread.[br]
		# For each thread, sequentially test triangle overlapping with each of 8 layer-0 child node.[br]
		# For each layer-0 child node overlapped by triangle, launch a thread to voxelize subgrid.[br]
		if not act1node_triangles.is_empty():
			var act1node_triangles_keys: Array[int] = act1node_triangles.keys()
			# Reshift triangles back to their place.
			# TODO: Flatten dictionary into array
			for key in act1node_triangles_keys:
				for i in range(act1node_triangles[key].size()):
					act1node_triangles[key][i] -= offset_by_half_voxel_size_x
			if multi_threading:
				await Parallel.execute(
					async_context, 
					act1node_triangles_keys.size(),
					new_thread_priority,
					_parallel_voxelize_tree_node0.bind(
						act1node_triangles_keys,
						act1node_triangles,
						svo,
						voxel_size))
			else:
				for i in range(act1node_triangles_keys.size()):
					_parallel_voxelize_tree_node0(
						i,
						act1node_triangles_keys,
						act1node_triangles,
						svo,
						voxel_size)
					
		progress.emit(ProgressStep.SURFACE_VOXELIZATION, svo, 
			 act1node_triangles.keys().size(), act1node_triangles.keys().size())
	#endregion
	
	if calculate_coverage_factor:
		progress.emit(ProgressStep.CALCULATE_COVERAGE_FACTOR, svo, 0, 2)
		var new_svo_coverage: Array[PackedFloat64Array] = []
		new_svo_coverage.resize(svo.morton.size())
		for layer in range(svo.morton.size()):
			new_svo_coverage[layer].resize(svo.morton[layer].size())
			new_svo_coverage[layer].fill(0.0)
		#region Calculate layer 0 coverage
		var list_solid_bit_count_by_subgrid: PackedInt64Array = \
			await svo.get_list_solid_bit_count_by_subgrid(
				async_context, 
				new_thread_priority)
		for i in range(list_solid_bit_count_by_subgrid.size()):
			new_svo_coverage[0][i] = list_solid_bit_count_by_subgrid[i] / 64.0
			
		progress.emit(ProgressStep.CALCULATE_COVERAGE_FACTOR, svo, 1, 2)
		#endregion
		#region Calculate coverage for layer 1 and up
		for layer in range(1, new_svo_coverage.size()):
			for i in range(new_svo_coverage[layer].size()):
				var first_child_svolink = svo.first_child[layer][i]
				if first_child_svolink == SVOLink.NULL:
					if svo.inside[layer][i]:
						new_svo_coverage[layer][i] = 1.0
					else:
						new_svo_coverage[layer][i] = 0.0
					continue
				var total_coverage: float = 0
				var first_child_offset = SVOLink.offset(first_child_svolink)
				var child_layer = layer-1
				for child_offset in range(first_child_offset, first_child_offset+8):
					total_coverage += new_svo_coverage[child_layer][child_offset]
				new_svo_coverage[layer][i] = total_coverage / 8
		svo.coverage = new_svo_coverage
		#endregion 
		
		progress.emit(ProgressStep.CALCULATE_COVERAGE_FACTOR, svo, 2, 2)
		
	return svo


## Return non-zero if svo nodes with codes m1 and m2 have different parents
static func _mortons_different_parent(
	m1: int, # Morton3 
	m2: int # Morton3 
	) -> int: 
	# Same parent means 2nd-61th bits are the same.
	# Thus, m1 ^ m2 should have them == 0
	return (m1^m2) & 0x7FFF_FFFF_FFFF_FFF8

#region Multithreading functions

static func _parallel_is_non_zero_area_triangle(
	triangle_idx: int,
	list_triangle: PackedVector3Array) -> bool:
	var start_idx = triangle_idx*3
	var v0 = list_triangle[start_idx]
	var v1 = list_triangle[start_idx + 1]
	var v2 = list_triangle[start_idx + 2]
	if v0.is_equal_approx(v1) or v1.is_equal_approx(v2) or v2.is_equal_approx(v0):
		return false
	return true


static func _parallel_batched_write_clean_triangles(
	batch_index: int,
	batch_start: int,
	batch_end: int,
	triangles: PackedVector3Array,
	cleaned_triangles: PackedVector3Array,
	list_start_write_index: PackedInt64Array):
	var fat_triangle_this_batch = 0
	for i in range(batch_start, batch_end):
		if _parallel_is_non_zero_area_triangle(i, triangles):
			var write_address = 3 *\
				(list_start_write_index[batch_index] + fat_triangle_this_batch)
			var triangle_address = 3 * i
			cleaned_triangles[write_address] = triangles[triangle_address]
			cleaned_triangles[write_address+1] = triangles[triangle_address+1]
			cleaned_triangles[write_address+2] = triangles[triangle_address+2]
			fat_triangle_this_batch += 1


static func _parallel_batched_offset_triangle(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	list_triangle: PackedVector3Array,
	offset: Vector3) -> void:
		for vertex_idx in range(batch_start, batch_end):
			list_triangle[vertex_idx] += offset


static func _parallel_fill_neighbor_in_direction(
	index: int,
	svo: SVO, 
	list_neighbor_direction: Array, # Array[Array[PackedInt64Array]] svo.xn/yn/zn/xp/yp/zp
	list_next_neighbor_calculator: Array[Callable] # Morton3.dec_x/inc_x/dec_y/inc_y/dec_z/inc_z
	) -> void:
	var neighbor_direction = list_neighbor_direction[index]
	var next_neighbor_calculator = list_next_neighbor_calculator[index]
	for layer in range(svo.depth - 2, -1, -1):
		for offset in range(svo.morton[layer].size()):
			var current_node_morton = svo.morton[layer][offset]
			var parent_svolink = svo.parent[layer][offset]
			var parent_layer = SVOLink.layer(parent_svolink)
			var parent_offset = SVOLink.offset(parent_svolink)
			var parent_first_child_offset = offset & ~0b111 # Alternatively: SVOLink.offset(svo.first_child[layer][offset])
			
			var neighbor_morton = next_neighbor_calculator.call(current_node_morton)
			
			if _mortons_different_parent(neighbor_morton, current_node_morton):
				#region Ask parent for neighbor SVOLink
				var parent_neighbor_svolink = neighbor_direction[parent_layer][parent_offset]
				
				if parent_neighbor_svolink == SVOLink.NULL:
					neighbor_direction[layer][offset] = SVOLink.NULL
					continue
					
				var parent_neighbor_layer = SVOLink.layer(parent_neighbor_svolink)
				
				# If parent's neighbor is on upper layer,
				# then that upper layer node is our neighbor.
				if parent_layer != parent_neighbor_layer:
					neighbor_direction[layer][offset] = parent_neighbor_svolink
					continue
				
				var parent_neighbor_offset = SVOLink.offset(parent_neighbor_svolink)
				
				# If parent's neighbor has no child,
				# Then parent's neighbor is our neighbor.
				# Note: Layer 0 node always has no children. They contain only voxels.
				if parent_neighbor_layer == 0 or\
					svo.first_child[parent_neighbor_layer][parent_neighbor_offset] == SVOLink.NULL:
					neighbor_direction[layer][offset] = parent_neighbor_svolink
					continue
				
				var parent_neighbor_first_child_svolink = svo.first_child[parent_neighbor_layer][parent_neighbor_offset]
	
				neighbor_direction[layer][offset] = SVOLink.from(parent_layer - 1, 
					(SVOLink.offset(parent_neighbor_first_child_svolink) & ~0b111)\
					| (neighbor_morton & 0b111))
				continue
				#endregion
			else:
				neighbor_direction[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (neighbor_morton & 0b111))


static func _parallel_batched_initialize_active_layer_1_triangle_box_test(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	triangles: PackedVector3Array,
	list_triangle_box_test: Array[TriangleBoxTest],
	modified_node_1_size: Vector3,
	voxel_size: Vector3,
) -> void:
	for triangle_index in range(batch_start, batch_end):
		var start_index = triangle_index*3
		var triangle_box_test = TriangleBoxTest.new(
			triangles[start_index], 
			triangles[start_index+1], 
			triangles[start_index+2], 
			modified_node_1_size,
			TriangleBoxTest.Separability.SEPARATING_26)
			
		# Schwarz's modification: 
		# Enlarge the triangle’s bounding box in −x direction by one SG voxel
		triangle_box_test.aabb.position.x -= voxel_size.x
		triangle_box_test.aabb.size.x += voxel_size.x
		
		list_triangle_box_test[triangle_index] = triangle_box_test
			

static func _parallel_batched_count_active_layer_1_node_by_triangle(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	list_triangle_box_test: Array[TriangleBoxTest],
	list_active_layer_1_node_overlap_count_by_triangle: PackedInt64Array,
	node_1_size: Vector3,
	flight_navigation_size: Vector3,
) -> void:
	for test_index in range(batch_start, batch_end):
		var triangle_box_test = list_triangle_box_test[test_index]
		var voxel_range: Array[Vector3i] = _voxels_overlapped_by_aabb(
			node_1_size, 
			triangle_box_test.aabb, 
			flight_navigation_size)
		
		var minimum_corner: Vector3 = Vector3()
		for x in range(voxel_range[0].x, voxel_range[1].x):
			minimum_corner.x = node_1_size.x * x
			for y in range(voxel_range[0].y, voxel_range[1].y):
				minimum_corner.y = node_1_size.y * y
				for z in range(voxel_range[0].z, voxel_range[1].z):
					minimum_corner.z = node_1_size.z * z
					list_active_layer_1_node_overlap_count_by_triangle[test_index] +=\
						int(triangle_box_test.overlap_voxel(minimum_corner))


static func _parallel_batched_write_active_layer_1_node_by_triangle(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	list_triangle_box_test: Array[TriangleBoxTest],
	list_morton_layer_1_overlapped_by_triangle_start_index: PackedInt64Array,
	list_morton_layer_1_overlapped_by_triangle: PackedInt64Array,
	node_1_size: Vector3,
	flight_navigation_size: Vector3
):
	for test_index in range(batch_start, batch_end):
		var triangle_box_test = list_triangle_box_test[test_index]
		
		var voxel_range: Array[Vector3i] = _voxels_overlapped_by_aabb(
			node_1_size, 
			triangle_box_test.aabb, 
			flight_navigation_size)
		
		var minimum_corner: Vector3 = Vector3()
		var start_write_index = list_morton_layer_1_overlapped_by_triangle_start_index[test_index]
		var overlapped_node_1_count: int = 0
		for x in range(voxel_range[0].x, voxel_range[1].x):
			minimum_corner.x = node_1_size.x * x
			for y in range(voxel_range[0].y, voxel_range[1].y):
				minimum_corner.y = node_1_size.y * y
				for z in range(voxel_range[0].z, voxel_range[1].z):
					minimum_corner.z = node_1_size.z * z
					if triangle_box_test.overlap_voxel(minimum_corner):
						var write_index = start_write_index + overlapped_node_1_count
						var node_1_morton: int = Morton3.encode64(x, y, z)
						list_morton_layer_1_overlapped_by_triangle[write_index] = node_1_morton
						overlapped_node_1_count += 1
		
		
## Return dictionary of key - value: Active node morton code - Array of 3 Vector3 (vertices of [param triangle])[br]
func voxelize_triangle_node_1(
	voxel_size: Vector3,
	triangle: PackedVector3Array) -> Dictionary[int, PackedVector3Array]:
	var node_1_size: Vector3 = voxel_size * 8
	var result: Dictionary[int, PackedVector3Array] = {}
	var triangle_box_test = TriangleBoxTest.new(
		triangle[0], 
		triangle[1], 
		triangle[2], 
		node_1_size, 
		TriangleBoxTest.Separability.SEPARATING_26,
	)
		
	#var aabb_before = triangle_box_test.aabb
	
	# Schwarz's modification: 
	# Enlarge the triangle’s bounding box in −x direction by one SG voxel
	triangle_box_test.aabb.position.x -= voxel_size.x
	triangle_box_test.aabb.size.x += voxel_size.x
	
	#var aabb_after = triangle_box_test.aabb
	var vox_range: Array[Vector3i] = _voxels_overlapped_by_aabb(node_1_size, triangle_box_test.aabb, size)
	
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				if triangle_box_test.overlap_voxel(Vector3(x, y, z) * node_1_size):
					var vox_morton: int = Morton3.encode64(x, y, z)
					if result.has(vox_morton):
						result[vox_morton].append_array(triangle)
					else:
						result[vox_morton] = triangle.duplicate()
					
	return result
	
	
## Return dictionary of key - value: Active node morton code - Array of 3 Vector3 (vertices of [param triangle])[br]
static func _parallel_voxelize_triangle_node_1(
	triangle_index: int,
	voxel_size: Vector3,
	triangle_shifted: PackedVector3Array,
	flight_navigation_size: Vector3,
	) -> Dictionary[int, PackedVector3Array]:
	var node_1_size: Vector3 = voxel_size * 8
	
	var result: Dictionary[int, PackedVector3Array] = {}
	var triangle_start_index: int = triangle_index * 3
	var triangle_box_test = TriangleBoxTest.new(
		triangle_shifted[triangle_start_index], 
		triangle_shifted[triangle_start_index+1], 
		triangle_shifted[triangle_start_index+2], 
		node_1_size, 
		TriangleBoxTest.Separability.SEPARATING_26,
		)
		
	#var aabb_before = triangle_box_test.aabb
	
	# Schwarz's modification: 
	# Enlarge the triangle’s bounding box in −x direction by one SG voxel
	triangle_box_test.aabb.position.x -= voxel_size.x
	triangle_box_test.aabb.size.x += voxel_size.x
	
	#var aabb_after = triangle_box_test.aabb
	
	var vox_range: Array[Vector3i] = _voxels_overlapped_by_aabb(
		node_1_size, triangle_box_test.aabb, flight_navigation_size)
	
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				if triangle_box_test.overlap_voxel(Vector3(x, y, z) * node_1_size):
					var vox_morton: int = Morton3.encode64(x, y, z)
					if result.has(vox_morton):
						result[vox_morton].append_array(triangle_shifted
							.slice(triangle_start_index, triangle_start_index + 3))
					else:
						result[vox_morton] = triangle_shifted.slice(
							triangle_start_index, triangle_start_index + 3)
					
	return result


func _parallel_count_active_node_1_by_triangle(
	triangle_index: int,
	triangle: PackedVector3Array,
	voxel_size: Vector3) -> Dictionary[int, PackedVector3Array]:
	var node_1_size: Vector3 = voxel_size * 8
	
	var result: Dictionary[int, PackedVector3Array] = {}
	var triangle_start_index = triangle_index*3
	var triangle_box_test = TriangleBoxTest.new(
		triangle[triangle_start_index], 
		triangle[triangle_start_index+1], 
		triangle[triangle_start_index+2], 
		node_1_size, 
		TriangleBoxTest.Separability.SEPARATING_26,
		)
		
	#var aabb_before = triangle_box_test.aabb
	
	# Schwarz's modification: 
	# Enlarge the triangle’s bounding box in −x direction by one SG voxel
	triangle_box_test.aabb.position.x -= voxel_size.x
	triangle_box_test.aabb.size.x += voxel_size.x
	
	#var aabb_after = triangle_box_test.aabb
	
	var vox_range: Array[Vector3i] = _voxels_overlapped_by_aabb(
		node_1_size, triangle_box_test.aabb, size)
	
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				if triangle_box_test.overlap_voxel(Vector3(x, y, z) * node_1_size):
					var vox_morton: int = Morton3.encode64(x, y, z)
					if result.has(vox_morton):
						result[vox_morton].append_array(triangle)
					else:
						result[vox_morton] = triangle
					
	return result


func _parallel_voxelize_tree_node0(
	index: int,
	act1node_triangles_keys: Array,
	act1node_triangles: Dictionary[int, PackedVector3Array],
	svo: SVO,
	voxel_size: Vector3
	):
	var node_0_size: Vector3 = voxel_size * 4
	var node_1_size: Vector3 = voxel_size * 8
	var node1_morton = act1node_triangles_keys[index]
	var triangles = act1node_triangles[node1_morton]
	var node1_position = Morton3.decode_vec3(node1_morton) * node_1_size
	
	for i in range(0, triangles.size(), 3):
		var triangle = triangles.slice(i, i+3)
		
		var triangle_node0_test = TriangleBoxTest.new(triangle[0], triangle[1], triangle[2], Vector3(1,1,1) * node_0_size, surface_separability)
		var triangle_voxel_test = TriangleBoxTest.new(triangle[0], triangle[1], triangle[2], Vector3(1,1,1) * voxel_size, surface_separability)
		
		for m in range(8): # Test overlap on all 8 nodes layer 0 within node layer 1
			var node0_svolink = svo.svolink_from_morton(0, (node1_morton << 3) | m)
			var offset = SVOLink.offset(node0_svolink)
			var node0_position = node1_position + Morton3.decode_vec3(m) * node_0_size
			if triangle_node0_test.overlap_voxel(node0_position):
				#region Voxelize tree leaves
				var node0_solid_state: int = svo.subgrid[offset]
				
				var node0_aabb = AABB(node0_position, node_0_size)
				var intersection = triangle_voxel_test.aabb.intersection(node0_aabb)
				intersection.position -= node0_position
				
				var vox_range = _voxels_overlapped_by_aabb(voxel_size, intersection, node_0_size)
				
				for x in range(vox_range[0].x, vox_range[1].x):
					for y in range(vox_range[0].y, vox_range[1].y):
						for z in range(vox_range[0].z, vox_range[1].z):
							var morton = Morton3.encode64(x,y,z)
							var vox_offset = Vector3(x,y,z) * voxel_size
							var leaf_position = node0_position + vox_offset
							var havent_been_overlapped_before = node0_solid_state & (1 << morton) == 0
							if havent_been_overlapped_before\
									and triangle_voxel_test.overlap_voxel(leaf_position):
								node0_solid_state |= 1<<morton
				svo.subgrid[offset] = svo.subgrid[offset] | node0_solid_state
				#endregion
				
				
static func _parallel_yz_plane_rasterization(
	triangle_index: int,
	svo: SVO,
	triangles: PackedVector3Array, 
	voxel_size: Vector3,
	x_column_flip_bitmask_by_subgrid_index: PackedInt64Array,
	flight_navigation_size: Vector3):
	var inverted_voxel_size: Vector3 = Vector3.ONE / voxel_size
	var triangle_start_idx: int = triangle_index * 3
		
	var v0xyz: Vector3 = triangles[triangle_start_idx+0]
	var v1xyz: Vector3 = triangles[triangle_start_idx+1]
	var v2xyz: Vector3 = triangles[triangle_start_idx+2]

	var e0xyz: Vector3 = v1xyz - v0xyz
	var e1xyz: Vector3 = v2xyz - v1xyz
	var e2xyz: Vector3 = v0xyz - v2xyz
	
	var v0: Vector2 = Vector2(v0xyz.y, v0xyz.z)
	var v1: Vector2 = Vector2(v1xyz.y, v1xyz.z)
	var v2: Vector2 = Vector2(v2xyz.y, v2xyz.z)

	#region Ensure consistent counter-clockwise order of vertices
	var not_is_ccw = e2xyz.y * e0xyz.z - e0xyz.y * e2xyz.z < 0
	if not_is_ccw:
		# Swap v1 and v2
		var v_temp = v1
		v1 = v2
		v2 = v_temp
		
		# Recalculate edge equations. Turn v1 into v2 and vice versa.
		e0xyz = v2xyz - v0xyz
		e1xyz = v1xyz - v2xyz
		e2xyz = v0xyz - v1xyz
	#endregion

	var n: Vector3 = e0xyz.cross(e1xyz)

	# Ignore projected triangles that are too thin.
	if is_zero_approx(n.x):
		return

	var n_yz_e0: Vector2 = Vector2(-e0xyz.z, e0xyz.y)
	var n_yz_e1: Vector2 = Vector2(-e1xyz.z, e1xyz.y)
	var n_yz_e2: Vector2 = Vector2(-e2xyz.z, e2xyz.y)

	if n[0] < 0:
		n_yz_e0 = Vector2(e0xyz.z, -e0xyz.y)
		n_yz_e1 = Vector2(e1xyz.z, -e1xyz.y)
		n_yz_e2 = Vector2(e2xyz.z, -e2xyz.y)
		
	var d_yz_e0: float = -n_yz_e0.dot(v0)
	var d_yz_e1: float = -n_yz_e1.dot(v1)
	var d_yz_e2: float = -n_yz_e2.dot(v2)

	var is_left_edge_e0: bool = n_yz_e0[0] > 0
	var is_left_edge_e1: bool = n_yz_e1[0] > 0
	var is_left_edge_e2: bool = n_yz_e2[0] > 0

	var is_top_edge_e0: bool = n_yz_e0[0] == 0 and n_yz_e0[1] < 0
	var is_top_edge_e1: bool = n_yz_e1[0] == 0 and n_yz_e1[1] < 0
	var is_top_edge_e2: bool = n_yz_e2[0] == 0 and n_yz_e2[1] < 0

	var f_yz_e0: float = 0
	var f_yz_e1: float = 0
	var f_yz_e2: float = 0

	if is_left_edge_e0 or is_top_edge_e0:
		f_yz_e0 = epsilon
	if is_left_edge_e1 or is_top_edge_e1:
		f_yz_e1 = epsilon
	if is_left_edge_e2 or is_top_edge_e2:
		f_yz_e2 = epsilon

	# Bounding box in voxel coordinate
	#
	# Use floori(x + 0.) instead of roundi(x) to make sure that 
	# 0.5 cases are handled consistently
	#
	# Voxel coordinates are offseted by 0.5 
	# because we are considering voxel centers
	var rect2i: Rect2i = Rect2i()
	rect2i.position = Vector2i(
		floori(min(v0[0], v1[0], v2[0]) * inverted_voxel_size.y + 0.5), 
		floori(min(v0[1], v1[1], v2[1]) * inverted_voxel_size.z + 0.5)
		)
	rect2i.end = Vector2i(
		ceili(max(v0[0], v1[0], v2[0]) * inverted_voxel_size.y - 0.5), 
		ceili(max(v0[1], v1[1], v2[1]) * inverted_voxel_size.z - 0.5))

	if not rect2i.has_area():
		return

	var voxel_size_yz = Vector2(voxel_size.y, voxel_size.z)
	for voxel_y in range(rect2i.position[0], rect2i.end[0]):
		for voxel_z in range(rect2i.position[1], rect2i.end[1]):
			var p_yz: Vector2 = Vector2(voxel_y+0.5, voxel_z+0.5) * voxel_size_yz
			
			var triangle_overlap_voxel_center =\
				(n_yz_e0.dot(p_yz) + d_yz_e0 + f_yz_e0 > 0)\
				and (n_yz_e1.dot(p_yz) + d_yz_e1 + f_yz_e1 > 0)\
				and (n_yz_e2.dot(p_yz) + d_yz_e2 + f_yz_e2 > 0)
			
			if not triangle_overlap_voxel_center:
				continue
			
			# n = (a, b, c)
			# Plane equation: ax + by + cz + d = 0
			# x = -(by + cz + d)/a
			# Also, shift the voxel position by size.x/2 (half the navigation cube),
			# because the navigation cube originates from the center, 
			# not from the corner of the cube (as we expect it to be)
			var plane_equation_d = - n.dot(v0xyz)
			var projected_x = -(n.y * p_yz[0] + n.z * p_yz[1] + plane_equation_d)/n.x
			
			var voxel_x: int = floori(projected_x * inverted_voxel_size.x + 0.5)
			

			# clamp to valid x range
			var grid_x: int = int(flight_navigation_size.x / voxel_size.x)
			voxel_x = clamp(voxel_x, 0, grid_x - 1)
			
			var voxel_morton: int = Morton3.encode64(voxel_x, voxel_y, voxel_z)
			var voxel_svolink: int  = svo.svolink_from_voxel_morton(voxel_morton)

			# Could be null, because triangles on the face of navigation space
			# might be projected to an outside voxel.
			if voxel_svolink == SVOLink.NULL:
				continue
			var offset = SVOLink.offset(voxel_svolink)
			var subgrid = SVOLink.subgrid(voxel_svolink)
			
			var flip_mask: int = x_column_flip_bitmask_by_subgrid_index[subgrid]
			#var subgrid_vec3 = Morton3.decode_vec3i(subgrid)
			#var flip_mask_str = Morton.int_to_bin(flip_mask)
			svo.subgrid[offset] = svo.subgrid[offset] ^ flip_mask


func _parallel_propagate_bit_flip(
	head_node_index: int, 
	list_head_node_offset_of_layer_0: PackedInt64Array,
	subgrid_voxel_indexes_on_face_direction: PackedInt32Array,
	neighbor_direction_to_flip: Array[PackedInt64Array], # svo.xp
	svo_subgrid: PackedInt64Array, # svo.subgrid
):
	var current_node_offset = list_head_node_offset_of_layer_0[head_node_index]
	while true:
		var neighbor_svolink = neighbor_direction_to_flip[0][current_node_offset]
		if neighbor_svolink == SVOLink.NULL:
			break
		var neighbor_layer = SVOLink.layer(neighbor_svolink)
		if neighbor_layer != 0:
			break
		
		var flip_buffer: int = 0
		for subgrid_index in subgrid_voxel_indexes_on_face_direction:
			var last_bit_in_the_column_is_solid = \
				svo_subgrid[current_node_offset] & (1 << subgrid_index)
			if last_bit_in_the_column_is_solid:
				flip_buffer = flip_buffer | neighbor_node_x_column_bits_by_subgrid_index[subgrid_index]
		var neighbor_offset: int = SVOLink.offset(neighbor_svolink)
		svo_subgrid[neighbor_offset] = svo_subgrid[neighbor_offset] ^ flip_buffer
		
		# Increment condition
		current_node_offset = neighbor_offset
		
		
func _parallel_propagate_flip_and_inside(
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
		if neighbor_svolink == SVOLink.NULL:
			break
		var neighbor_layer = SVOLink.layer(neighbor_svolink)
		if neighbor_layer != layer:
			break
			
		var neighbor_offset = SVOLink.offset(neighbor_svolink)
		if flip_flag_layer[current_node_offset]:
			var neighbor_flip_flag = flip_flag_layer[neighbor_offset]
			var neighbor_inside_flag = svo_inside_layer[neighbor_offset]
			flip_flag_layer[neighbor_offset] = neighbor_flip_flag ^ 1
			svo_inside_layer[neighbor_offset] = neighbor_inside_flag ^ 1
		# Increment condition
		current_node_offset = neighbor_offset
#endregion



#region Voxelize Triangles
	
## Merge triangles overlapping a node from [param append] to [param base].[br]
##
## Both [param base] and [param append] are dictionaries of: [br] 
## Morton code - Array of vertices [br]
## every 3 elements in Array of vertices make a triangle.[br]
##
## [b]NOTE:[/b] Duplicated triangles are not removed from [param base].
func _merge_triangle_overlap_node_dicts(
	base: Dictionary[int, PackedVector3Array], 
	append: Dictionary[int, PackedVector3Array]) -> void:
	for key in append.keys():
		if base.has(key):
			base[key].append_array(append[key])
		else:
			base[key] = append[key].duplicate()


## Return two Vector3i as bounding box for a range of voxels that's intersection
## between FlyingNavigation3D and [param t_aabb].
## [br]
## The first vector (begin) contains the start voxel index (inclusive).
## [br]
## The second vector (end) is the end index (exclusive).
## [br]
## [b]NOTE:[/b]: (end - begin) is non-negative.
## [br]
## The voxel range is inside FlyingNavigation3D area.
## [br]
## The result includes also voxels merely touched by [param t_aabb].
static func _voxels_overlapped_by_aabb(
	voxel_size: Vector3, 
	triangle_aabb: AABB, 
	flight_navigation_size: Vector3) -> Array[Vector3i]:
	var inverted_voxel_size: Vector3 = Vector3.ONE / voxel_size
	
	# Begin & End
	var b: Vector3 = triangle_aabb.position*inverted_voxel_size
	var e: Vector3 = triangle_aabb.end*inverted_voxel_size
	# Clamps the result between 0 and vb (exclusive)
	var vb = flight_navigation_size*inverted_voxel_size
	
	# Include voxels merely touched by t_aabb
	b.x = b.x - (1.0 if b.x == floorf(b.x) else 0.0)
	b.y = b.y - (1.0 if b.y == floorf(b.y) else 0.0)
	b.z = b.z - (1.0 if b.z == floorf(b.z) else 0.0)
	e.x = e.x + (1.0 if e.x == roundf(e.x) else 0.0)
	e.y = e.y + (1.0 if e.y == roundf(e.y) else 0.0)
	e.z = e.z + (1.0 if e.z == roundf(e.z) else 0.0)
	
	# Clamp to fit inside Navigation Space
	var bi: Vector3i = Vector3i(b.clamp(Vector3(), vb).floor())
	var ei: Vector3i = Vector3i(e.clamp(Vector3(), vb).ceil())
	
	return [bi, ei]


#endregion
#endregion

#region Utility function
func _get_x_link_from_head_node(svo: SVO, layer: int, head_node_offset: int):
	var svolink = SVOLink.from(layer, head_node_offset)
	var result: PackedInt64Array = []
	
	while svolink != SVOLink.NULL:
		result.push_back(svolink)
		var next_layer = SVOLink.layer(svolink)
		var next_offset = SVOLink.offset(svolink)
		svolink = svo.xp[next_layer][next_offset]
	return result

## Return global position of center of the node or subgrid voxel identified as [param svolink].[br]
## [member sparse_voxel_octree] must not be null.[br]
func get_global_position_of(svolink: int) -> Vector3:
	var voxel_size = _node_size(size, -2, sparse_voxel_octree.depth)
	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	
	var morton_code = sparse_voxel_octree.morton[layer][offset]
	if layer == 0:
		var voxel_morton = (morton_code << 6) | SVOLink.subgrid(svolink)#sparse_voxel_octree.subgrid[offset]
		var half_a_voxel = Vector3(0.5, 0.5, 0.5)
		return global_transform * (
			(Morton3.decode_vec3(voxel_morton) + half_a_voxel) 
			* voxel_size + _origin_offset())
	
	var half_a_node = Vector3(0.5, 0.5, 0.5)
	var result = global_transform\
			* (
				(Morton3.decode_vec3(morton_code) + half_a_node)
			 	* _node_size(size, layer, sparse_voxel_octree.depth) 
				+ _origin_offset()
			)
	return result


## Return [SVOLink] of the smallest node/voxel at [param gposition].
## [br]
## [b]NOTE:[/b] Positions exactly on a face might be mislocated
## to different node/voxel due to floating-point inaccuracy.
## [br]
## [param gposition]: Global position that needs conversion to [SVOLink].
func get_svolink_of(gposition: Vector3) -> int:
	var local_pos = to_local(gposition) - _origin_offset()
	var extent: Vector3 = size
	var aabb := AABB(Vector3.ZERO, extent)
	
	# Points outside Navigation Space
	if not aabb.has_point(local_pos):
		return SVOLink.NULL
	
	var link_layer := sparse_voxel_octree.depth - 1
	var link_offset:= 0
	
	# Descend the tree layer by layer
	while link_layer > 0:
		var first_child = sparse_voxel_octree.first_child[link_layer][link_offset]
		if first_child == SVOLink.NULL:
			return SVOLink.from(link_layer, link_offset)

		link_offset = SVOLink.offset(first_child)
		link_layer -= 1
		
		var aabb_center := aabb.position + aabb.size/2
		var new_pos := aabb.position
		
		if local_pos.x >= aabb_center.x:
			link_offset |= 0b001
			new_pos.x = aabb_center.x
			
		if local_pos.y >= aabb_center.y:
			link_offset |= 0b010
			new_pos.y = aabb_center.y
			
		if local_pos.z >= aabb_center.z:
			link_offset |= 0b100
			new_pos.z = aabb_center.z
			
		aabb = AABB(new_pos, aabb.size/2)
	
	# Return the subgrid voxel that encloses @position
	var subgridv = (local_pos - aabb.position) * 4 / aabb.size
	return SVOLink.from(0, link_offset, Morton3.encode64v(subgridv))
	
#endregion

#region Helper functions

## Return the corner position where morton index starts counting
func _origin_offset() -> Vector3:
	return -size/2
	
## Return the size (in local meter) of a node at [param layer]
static func _node_size(
	flight_navigation_size: Vector3, 
	layer: int, 
	svo_depth: int) -> Vector3:
	return flight_navigation_size * (2.0 ** (layer - svo_depth + 1))

func _initialize_debug_draw_multimesh():
	var debug_draw_svonode = $DebugDraw/SVONode
	var debug_draw_voxel = $DebugDraw/Voxel
	for multimesh_instance in debug_draw_svonode.get_children():
		debug_draw_svonode.remove_child(multimesh_instance)
		multimesh_instance.queue_free()
	
	if sparse_voxel_octree == null:
		return
		
	var voxel_size: Vector3 = _node_size(size, -2, sparse_voxel_octree.depth)
		
	for layer in range(sparse_voxel_octree.depth):
		var boxmesh = BoxMesh.new()
		boxmesh.size = _node_size(size, layer, sparse_voxel_octree.depth)\
			* 0.95
		boxmesh.material = StandardMaterial3D.new()
		boxmesh.material.albedo_color = Color(
			1*(layer+1)/sparse_voxel_octree.depth,
			randf(),
			1-(layer+1)/sparse_voxel_octree.depth)
			
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TransformFormat.TRANSFORM_3D
		multimesh.mesh = boxmesh
		
		var multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.multimesh = multimesh
		
		debug_draw_svonode.add_child(multimesh_instance)
	
	debug_draw_voxel.multimesh.instance_count = 0
	debug_draw_voxel.multimesh.transform_format = MultiMesh.TransformFormat.TRANSFORM_3D
	
	debug_draw_voxel.multimesh.mesh.size = voxel_size\
			* 0.95
	#debug_draw_voxel.multimesh.mesh.material = StandardMaterial3D.new()
	#debug_draw_voxel.multimesh.mesh.material.albedo_color = Color(1, 1, 1, 0.1)
	

## Draw a box represents the space occupied by an [SVONode] identified as [param svolink].[br]
## 
## Return a reference to the box. [br] 
##
## Gives [param text] a custom value to insert a label in the center of the box.
## null for default value of [method SVOLink.get_format_string].[br]
##
## [b]NOTE:[/b]: [member sparse_voxel_octree] must not be null.[br]
func draw_svolink_box(svolink: int, 
		node_color: Color = Color.RED, 
		leaf_color: Color = Color.GREEN,
		text = null) -> MeshInstance3D:
	var voxel_size: Vector3 = _node_size(size, -2, sparse_voxel_octree.depth)
	
	var cube = MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	var label = Label3D.new()
	cube.add_child(label)
	
	cube.mesh.material = StandardMaterial3D.new()
	cube.mesh.material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
	label.text = text if text != null else SVOLink.get_format_string(svolink)
			
	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	
	# Draw voxel
	if layer == 0 and not(sparse_voxel_octree.support_inside
		and sparse_voxel_octree.inside[layer][offset]):
		cube.mesh.size = voxel_size
		cube.mesh.material.albedo_color = leaf_color
		label.pixel_size = voxel_size.x / 400
	# Draw node
	else:
		cube.mesh.size = _node_size(size, layer, sparse_voxel_octree.depth)
		cube.mesh.material.albedo_color = node_color
		label.pixel_size = _node_size(size, layer, sparse_voxel_octree.depth).x / 400
	cube.mesh.material.albedo_color.a = 0.2
	
	$SVOLinkCubes.add_child(cube)
	cube.global_position = get_global_position_of(svolink) #+ Vector3(1, 0, 0)
	return cube


## Draw all solid voxels, solid nodes there are
func draw():
	_initialize_debug_draw_multimesh()
	draw_solid_voxels()
	
	if not sparse_voxel_octree.support_inside:
		return
		
	var async_context: Signal = get_tree().process_frame
	var new_thread_priority = thread_priority
	
	var draw_flag_by_layer: Array[PackedByteArray] = []
	draw_flag_by_layer.resize(sparse_voxel_octree.depth)
	for layer in range(draw_flag_by_layer.size()):
		draw_flag_by_layer[layer] = PackedByteArray()
		draw_flag_by_layer[layer].resize(sparse_voxel_octree.inside[layer].size())
		draw_flag_by_layer[layer].fill(0)
		
	for layer in range(1, draw_flag_by_layer.size()):
		for offset in range(draw_flag_by_layer[layer].size()):
			draw_flag_by_layer[layer][offset] = int(
				sparse_voxel_octree.is_solid(SVOLink.from(layer, offset)))
	
	
	var debug_draw_node = $DebugDraw/SVONode
	var origin_offset = _origin_offset()
	
	# TODO: Parallel.wait_all()
	for layer in range(1, sparse_voxel_octree.depth):
		var node_size: Vector3 = _node_size(size, layer, sparse_voxel_octree.depth)
		var multimesh: MultiMesh = debug_draw_node.get_child(layer).multimesh
		
		var count_result = await Parallel.count_by_batch(
				async_context,
				new_thread_priority,
				draw_flag_by_layer[layer],
				1
			)
		
		var list_solid_node_count_by_batch: PackedInt64Array = count_result.list_count_by_batch
		var batch_size: int = count_result.batch_size
		
		var total_instance_count: int = Fn3dUtility.sum_array_number(list_solid_node_count_by_batch)
		
		var list_start_write_index: PackedInt64Array = \
			Parallel.make_start_write_index_array_from_count_array(
				list_solid_node_count_by_batch)
		
		# Allocate memory
		multimesh.instance_count = total_instance_count
		
		if multi_threading:
			await Parallel.execute_batched(
					async_context,
					draw_flag_by_layer[layer].size(),
					new_thread_priority,
					batch_size,
					_parallel_batched_write_node_transforms.bind(
						layer,
						draw_flag_by_layer,
						sparse_voxel_octree,
						multimesh,
						node_size,
						origin_offset,
						list_start_write_index,
					))
		else:
			for i in range(draw_flag_by_layer[layer].size()):
				var batch_index = i/batch_size
				_parallel_batched_write_node_transforms(
					batch_index, i*batch_size, 
					mini((i+1)*batch_size, draw_flag_by_layer[layer].size()),
					layer,
					draw_flag_by_layer,
					sparse_voxel_octree,
					multimesh,
					node_size,
					origin_offset,
					list_start_write_index,
				)


func draw_solid_voxels():
	if sparse_voxel_octree == null:
		printerr(str(get_path()) + ".sparse_voxel_octree is null")
		return
		
	var async_context: Signal = get_tree().process_frame
	var new_thread_priority = thread_priority
	
	var list_solid_bit_count_by_subgrid: PackedInt64Array = \
		await sparse_voxel_octree.get_list_solid_bit_count_by_subgrid(
			async_context, new_thread_priority)
			
	var total_solid_bit_count: int = Fn3dUtility.sum_array_number(list_solid_bit_count_by_subgrid)
	
	var list_start_write_index: PackedInt64Array = \
			Parallel.make_start_write_index_array_from_count_array(
				list_solid_bit_count_by_subgrid)
	
	var list_voxel_transform: Array[Transform3D] = []
	list_voxel_transform.resize(total_solid_bit_count)
	
	var voxel_size = _node_size(size, -2, sparse_voxel_octree.depth)
	
	await Parallel.execute_batched(
		async_context, 
		sparse_voxel_octree.subgrid.size(),
		new_thread_priority,
		100000,
		_parallel_batched_write_subgrid_voxel_transforms.bind(
			sparse_voxel_octree.subgrid,
			sparse_voxel_octree.morton[0],
			voxel_size,
			-size/2,
			list_start_write_index,
			list_voxel_transform))
		
	var debug_draw_voxel = $DebugDraw/Voxel
	debug_draw_voxel.multimesh.instance_count = total_solid_bit_count
	
	await Parallel.execute_batched(
		async_context, 
		total_solid_bit_count,
		new_thread_priority,
		100000,
		_parallel_batched_write_multimesh_instance_transforms.bind(
			debug_draw_voxel.multimesh,
			list_voxel_transform))


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
			if svo_subgrid[layer0_offset] & (1<<voxel_index):
				var voxel_position_offset: Vector3 = voxel_size * (Morton3.decode_vec3(voxel_index) + Vector3(0.5,0.5,0.5))
				var voxel_final_position: Vector3 = node_position + voxel_position_offset
				var write_index: int = start_write_index + solid_voxel_count
				list_voxel_transform[write_index] = Transform3D(Basis(), voxel_final_position)
				solid_voxel_count += 1


func _parallel_batched_write_node_transforms(
	batch_index: int,
	batch_start: int,
	batch_end: int,
	layer: int,
	draw_flag_by_layer: Array[PackedByteArray],
	svo: SVO,
	multimesh: MultiMesh,
	node_size: Vector3,
	origin_offset: Vector3,
	list_start_write_index: PackedInt64Array,
):
	var solid_node_count = 0
	var start_write_index = list_start_write_index[batch_index]
	for offset in range(batch_start, batch_end):
		if not draw_flag_by_layer[layer][offset]:
			continue
		var node_position = node_size\
			* (Morton3.decode_vec3(svo.morton[layer][offset]) 
				+ Vector3(0.5, 0.5, 0.5))\
			+ origin_offset
		var write_index = start_write_index + solid_node_count
		multimesh.set_instance_transform(write_index, 
			Transform3D(Basis(), node_position))
		solid_node_count += 1


func _parallel_batched_write_multimesh_instance_transforms(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	multimesh: MultiMesh,
	list_transform: Array[Transform3D]
):
	for index in range(batch_start, batch_end):
		multimesh.set_instance_transform(index, list_transform[index])
	
#endregion
#region Lookup Tables
# Lookup tables are not marked 'static'
# because static vars don't work when used in editor mode.

## Indexes of subgrid voxel that makes up a face of a layer-0 node
var subgrid_voxel_indexes_on_face: Dictionary[StringName, PackedInt32Array] =\
	SVO.generate_lut_subgrid_voxel_indexes_on_face()
	
## Used to quickly flip subgrid when rasterize triangles on xy plane.
var _x_column_flip_bitmask_by_subgrid_index: PackedInt64Array =\
	generate_x_column_flip_bitmask_by_subgrid_index()
	
var bitmask_of_subgrid_voxels_on_face_xp: int =\
	_compress_subgrid_indexes_into_bitmask(
		SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(3, -1, -1)))

## Used for hierarchical inside/outside propagation.
var neighbor_node_x_column_bits_by_subgrid_index: Dictionary[int, int] = \
	generate_lut_neighbor_node_x_column_bits_by_subgrid_index()

#endregion
#region Generate Lookup Tables

static func generate_x_column_flip_bitmask_by_subgrid_index() -> PackedInt64Array:
	var list_bitmask: PackedInt64Array = []
	for i in range(64):
		var bitmask = _get_x_column_flip_bitmask_by_subgrid_index(i)
		list_bitmask.push_back(bitmask)
	#var list_bitmask_str = Array(list_bitmask).map(
		#func (bitmask): 
			#return Morton.int_to_bin(bitmask))
	return list_bitmask
	
static func _get_x_column_flip_bitmask_by_subgrid_index(subgrid_idx: int):
	var start_x = Morton3.decode_vec3i(subgrid_idx).x
	var list_flip_index: PackedInt32Array = []
	for next_x in range(start_x, 4):
		list_flip_index.push_back(Morton3.set_x(subgrid_idx, next_x))
	var bitmask = _compress_subgrid_indexes_into_bitmask(list_flip_index)
	return bitmask

## Used for hierarchical inside/outside propagation.
static func generate_lut_neighbor_node_x_column_bits_by_subgrid_index() -> Dictionary[int, int]:
	return {
		Morton3.encode64(3,0,0): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,0,0))),
		Morton3.encode64(3,1,0): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,1,0))),
		Morton3.encode64(3,2,0): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,2,0))),
		Morton3.encode64(3,3,0): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,3,0))),
		Morton3.encode64(3,0,1): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,0,1))),
		Morton3.encode64(3,1,1): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,1,1))),
		Morton3.encode64(3,2,1): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,2,1))),
		Morton3.encode64(3,3,1): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,3,1))),
		Morton3.encode64(3,0,2): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,0,2))),
		Morton3.encode64(3,1,2): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,1,2))),
		Morton3.encode64(3,2,2): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,2,2))),
		Morton3.encode64(3,3,2): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,3,2))),
		Morton3.encode64(3,0,3): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,0,3))),
		Morton3.encode64(3,1,3): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,1,3))),
		Morton3.encode64(3,2,3): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,2,3))),
		Morton3.encode64(3,3,3): _compress_subgrid_indexes_into_bitmask(SVO._get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,3,3))),
	}


static func _compress_subgrid_indexes_into_bitmask(list_index: PackedInt32Array) -> int:
	var bitmask: int = 0
	for idx in list_index:
		bitmask = bitmask | (1 << idx)
	return bitmask

#endregion

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if !is_root_shape():
		warnings.append("Must be a root CSG shape to calculate mesh correctly")
	if sparse_voxel_octree == null:# or svo.get_layer_size(0) == 0:
		warnings.push_back("No valid SVO resource found. Try voxelize it in editor or call build_navigation from script.")
	if voxelization_mask == 0:
		warnings.push_back("Empty voxelization_mask.")
	if perform_solid_voxelization == false and perform_surface_voxelization == false:
		warnings.push_back("Either perform_solid_voxelization or perform_surface_voxelization must be set.")
	if size.x != size.y or size.x != size.z:
		warnings.push_back("All sizes x/y/z must be equal.")
	return warnings
