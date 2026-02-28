# Flight navigation 3D Architecture
This is the goal for the project architecture:

IFlightNavigation3D
|_ [Resource] ISvo
|_ [Node] ISvoVoxelizer
|_ [MultiMeshInstance3D] ISvoVisualizer
|_ [Node3D] ISvoPathFinder
|_ [Node][TODO][Need brainstorming] ISvoPathSmoother

[Marker3D] [TODO] Fn3dPathMarker

## Design principles
Apply dependency injection to make the system more flexible.

### IFlightNavigation3D
Work as a Facade for the whole system, provide a simple interface for the users to use the features.
Map svo coordinate to world coordinate and vice versa.

#### Functions:
- get_svo() -> ISvo: Get the ISvo resource for the navigation system.
- set_svo(svo: ISvo): Get or set the ISvo resource for the navigation system.

- draw(): Draw all SvoVisualizer in the scene by calling their draw() function.
- find_path(start: Vector3, end: Vector3) -> PackedVector3Array: Look for SvoPathFinderNode in the scene and call their find_path(start: Vector3, end: Vector3, svo: ISvo) function. The result then goes through SvoPathSmoother if there is any SvoPathSmootherInstance in the scene, and finally return the path as an array of Vector3 positions in world coordinate.
- voxelize(): Look for SvoVoxelizer in the scene and call their voxelize().

#### Extended by
##### FlightNavigation3D

### ISvo
#### Functions:
##### Supported query
- support_query_solid() -> bool: Return true if the SVO was solid voxelized.
- support_query_coverage() -> bool: Return true if the SVO supports coverage queries.
##### Getter/Setter 
- get_layer_count() -> int: Get the number of layers of the SVO tree.
- set_layer_count(layer_count: int): Set the number of layers of the SVO tree.
- get_node_count_in_layer(layer: int) -> int: Get the number of nodes in the given layer.
- set_node_count_in_layer(layer: int, node_count: int): Set the number of nodes in the given layer.
- get_morton(layer: int, index: int) -> int: Get the Morton3 coordinate of the SVO node at the given layer and index.
- set_morton(layer: int, index: int, morton3_value: int): Set the Morton3 coordinate of the SVO node at the given layer and index.
- get_parent(layer: int, index: int) -> int: Get the SvoLink to the parent SVO node in the upper layer for the SVO node at the given layer and index.
- set_parent(layer: int, index: int, parent_svolink: int): Set the SvoLink to the parent SVO node in the upper layer for the SVO node at the given layer and index.
- get_first_child(layer: int, index: int) -> int: Get the SvoLink to the first of the 8 children SVO nodes in the lower layer for the SVO node at the given layer and index.
- set_first_child(layer: int, index: int, first_child_svolink: int): Set the SvoLink to the first of the 8 children SVO nodes in the lower layer for the SVO node at the given layer and index.
- get_subgrid(index: int) -> int: Get the subgrid voxel value.
- set_subgrid(index: int, subgrid_bitmask: int): Set the subgrid voxel value.
- get_xp/yp/zp/xn/yn/zn_neighbor(layer: int, index: int) -> int: Get the SvoLink of the X-Positive/Y-Positive/Z-Positive/X-Negative/Y-Negative/Z-Negative neighbor for the SVO node at the given layer and index.
- set_xp/yp/zp/xn/yn/zn_neighbor(layer: int, index: int, xp_svolink: int): Set the SvoLink of the X-Positive/Y-Positive/Z-Positive/X-Negative/Y-Negative/Z-Negative neighbor for the SVO node at the given layer and index.
- get_flag_inside(layer: int, index: int) -> bool: Get the "inside" flag of the SVO node at the given layer and index.
- set_flag_inside(layer: int, index: int, inside: bool): Set the "inside" flag of the SVO node at the given layer and index.
- get_flag_flip(layer: int, index: int) -> bool: Get the "flip" flag of the SVO node at the given layer and index.
- set_flag_flip(layer: int, index: int, flip: bool): Set the "flip" flag of the SVO node at the given layer and index.
- get_coverage(layer: int, index: int) -> float: Get the coverage value of the SVO node at the given layer and index. The coverage value should be between 0 and 1, where 0 means completely empty and 1 means completely solid. Return NaN if the SVO does not support coverage queries.
- set_coverage(layer: int, index: int, coverage: float): Set the coverage value of the SVO node at the given layer and index. The coverage value should be between 0 and 1, where 0 means completely empty and 1 means completely solid.
##### Query
- get_node_center(svolink: int) -> Vector3: Return the position from the root node (0, 0, 0) of the SVO node in voxel unit.
- get_voxel_center(svolink: int) -> Vector3: Return the position from the root node (0, 0, 0) of the voxel in voxel unit, starting from the root node at (0, 0, 0).
- get_voxels_and_nodes_on_face_xp/yp/zp/xn/yn/zn(svolink: int) -> Array: Return an array of SvoLink of voxels and nodes that make up the X-Positive/Y-Positive/Z-Positive/X-Negative/Y-Negative/Z-Negative face of the input SVO node.
- get_svolink_from_node_morton(layer: int, morton3: int) -> int: Get the SvoLink of the SVO node at the given layer and Morton3 coordinate.
- get_svolink_from_voxel_morton(morton3: int) -> int: Get the SvoLink of the voxel at the Morton3 coordinate.
- get_neighbors_of(svolink: int) -> Array: Return an array of SvoLink of the neighboring voxels/nodes on 6 faces of the input SVO node.
- is_solid(layer: int, index: int) -> bool: Return true if the SVO node at the given layer and index is solid.
- get_offsets_of_head_nodes_in_x_direction_of_layer(layer: int) -> PackedInt64Array
- get_solid_bit_counts_by_subgrid() -> PackedInt32Array: Return an array of count of solid voxels in each subgrid. The count should be between 0 and 64, where 0 means completely empty and 64 means completely solid. Return an empty array if the SVO does not support this query.
- parallel_get_solid_bit_counts_by_subgrid(async_context: Signal, thread_priority: Thread.Priority) -> PackedInt32Array: Return an array of count of solid voxels in each subgrid. The count should be between 0 and 64, where 0 means completely empty and 64 means completely solid. Return an empty array if the SVO does not support this query. This function run the query in parallel and return the result asynchronously through the async_context signal.

#### Extended by
##### SvoColumnBased
Split the SVO data into multiple columns of arrays, where each column store a specific type of data (e.g. morton, parent, first_child, neighbor, flag_inside, flag_flip, coverage) for all nodes in the SVO tree.
##### SvoStructBased
[TODO]

### ISvoVoxelizer
#### Enums
Enum used for [member progress] signal.
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
#### Signals
- progress(step: ProgressStep, svo: SVO, work_completed: int, total_work: int): Emitted when the voxelization process makes progress. The step parameter indicates the current step of the process, svo is the SVO being built, work_completed is the amount of work completed in the current step, and total_work is the total amount of work to be done in the current step. This signal can be used to update a progress bar or perform other UI updates to inform the user about the progress of the voxelization process.
#### Functions:
##### Getter/Setter
- get_is_multithreading_enabled() -> bool: Return true if the voxelizer is set to use multithreading for the voxelization process.
- set_is_multithreading_enabled(enabled: bool): Set whether the voxelizer should use multithreading for the voxelization process. Enabling multithreading can improve performance on large scenes.
- get_multithreading_priority() -> Thread.Priority: Get the thread priority to be used for the voxelization process when multithreading is enabled.
- set_multithreading_priority(priority: Thread.Priority): Set the thread priority to be used for the voxelization process when multithreading is enabled.
- get_voxelization_mask() -> int: Get the voxelization mask that determines which objects in the scene should be voxelized. The mask is a bitmask where each bit corresponds to a layer in the Godot engine. Objects on layers that have their corresponding bit set in the mask will be included in the voxelization process.
- set_voxelization_mask(mask: int): Set the voxelization mask that determines which objects in the scene should be voxelized. The mask is a bitmask where each bit corresponds to a layer in the Godot engine. Objects on layers that have their corresponding bit set in the mask will be included in the voxelization process.
- get_remove_thin_triangles() -> bool: Return true if the voxelizer is set to remove thin triangles during the mesh building step of the voxelization process.
- set_remove_thin_triangles(remove: bool): Set whether the voxelizer should remove thin triangles during the mesh building step of the voxelization process.
- get_layer_count() -> int: Get the number of layers to be used in the SVO.
- set_layer_count(layer_count: int): Set the number of layers to be used in the SVO.
- get_resolution() -> int: The amount of subgrid voxels on each dimension of the SVO.
- get_resource_format() -> String: Get the resource format to be used for the SVO.
- set_resource_format(format: String): Set the resource format to be used for the SVO.
- get_support_float64() -> bool: Return true if the voxelizer supports using float64 for the calculation.
- set_support_float64(support: bool): Set whether the voxelizer supports using float64 for the calculation.
- get_solid_voxelization_enabled() -> bool: Return true if the voxelizer is set to perform solid voxelization.
- set_solid_voxelization_enabled(enable: bool): Set whether the voxelizer should perform solid voxelization.
- get_solid_voxelization_coverage_enabled() -> int: Return true if the voxelizer is set to calculate the percentage of solid volume for each SVO node. Useful for heuristic navigation algorithms.
- set_solid_voxelization_coverage_enabled(enabled: int): Set whether the voxelizer should calculate the percentage of solid volume for each SVO node.
- get_solid_voxelization_top_left_edge_epsilon() -> float: Get the floating point value used as tie-breaker for top/left edge rasterization.
- set_solid_voxelization_top_left_edge_epsilon(epsilon: float): Set the floating point value used as tie-breaker for top/left edge rasterization.
- get_surface_voxelization_enabled() -> bool: Return true if the voxelizer is set to perform surface voxelization.
- set_surface_voxelization_enabled(enable: bool): Set whether the voxelizer should perform surface voxelization.
- get_surface_voxelization_separability() -> TriangleBoxOverlapCheck.Separability: Get the separability setting to be used for surface voxelization.
- set_surface_voxelization_separability(separability: TriangleBoxOverlapCheck.Separability): Set the separability setting to be used for surface voxelization.
- get_debug_delete_csg() -> bool: Return true if the voxelizer is set to delete CSG nodes (created for each Voxelization targets) after voxelization.
##### Features
- voxelize(fn3d: IFlightNavigation3D) -> ISvo: Build and fill a SVO that represents the navigable space in the scene.
#### Extended by
##### SvoVoxelizer

### ISvoVisualizer
- draw(svo: ISvo)
#### Extended by
##### SvoVisualizer
- draw(svo: ISvo): Draw the SVO in the scene. The visualization can be customized based on the data in the SVO (e.g. different color for solid and empty nodes, or visualize coverage with color gradient).
##### SvoVisualizerForVoxelizationProgress
Must be child of ISvoVoxelizer.
Connect to the [progress] signal of ISvoVoxelizer and visualize the SVO as it is being built.


### ISvoPathFinder
- find_path(start: Vector3, end: Vector3, svo: ISvo) -> Array[SVOLink]: Find a path from start to end position using the SVO.
#### Extended by
##### SvoPathFinderGreedyAStarInstance
### ISvoPathSmoother
Smooth the path found by ISvoPathFinder.
#### Functions:
- smooth_path(path: Array[SVOLink], svo: ISvo) -> Array[SVOLink]: Take the original path found by ISvoPathFinder and return a smoothed path. The smoothing algorithm can be based on the data in the SVO (e.g. try to find shortcuts by checking the occupancy of the SVO nodes along the path).
#### Extended by
##### SvoPathSmootherInstance
### Fn3dPathMarker
[TODO][Need brainstorming] Used to pre-compute shortest paths to speed up path finding process.
### ISvoLink
Provide support for SvoLink across multiple size.
#### Functions:
- null() -> int: Return the null SvoLink value.
- get_subgrid_mask() -> int: Return the bitmask to extract the subgrid index from the SvoLink value.
- get_offset_mask() -> int: Return the bitmask to extract the node offset.
- get_layer_mask() -> int: Return the bitmask to extract the layer index.
- create(layer: int, index: int, subgrid: int) -> int: Create a SvoLink value from the given layer index, node index and subgrid index.
##### Getter/Setter
- get_layer(svolink: int) -> int: Extract the layer index from the given SvoLink value.
- set_layer(svolink: int, layer: int) -> int: Set the layer index in the given SvoLink value and return the new SvoLink value.
- get_offset(svolink: int) -> int: Extract the node offset from the given SvoLink value.
- set_offset(svolink: int, offset: int) -> int: Set the node offset in the given SvoLink value and return the new SvoLink value.
- get_subgrid(svolink: int) -> int: Extract the subgrid index from the given SvoLink value.
- set_subgrid(svolink: int, subgrid: int) -> int: Set the subgrid index in the given SvoLink value and return the new SvoLink value.
#### Extended by
##### SvoLink32
Work with 32 bit integers. 4 layer bits, 22 offset bits, 6 subgrid bits
##### SvoLink64
Work with 64 bit integers. 4 layer bits, 54 offset bits, 6 subgrid bits
