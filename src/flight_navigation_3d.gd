## Voxelize all FlightNavigationTarget inside this area
@tool
@warning_ignore_start("integer_division")
extends CSGBox3D
class_name FlightNavigation3D

## [param time_elapsed]: milliseconds since last log
signal build_log(message: String, time_string: String, time_elapsed: int)

	
## There could be mayn FlightNavigation3D in one scene, 
## and you might decide that some targets will voxelize
## in one FlightNavigation3D but not the others.
##
## If FlightNavigation3D's mask overlaps with at least
## one bit of VoxelizationTarget mask, its shapes will 
## be considered for Voxelization.
@export_flags_3d_navigation var voxelization_mask: int

@export var sparse_voxel_octree: SVO

## Node with pathfinding algorithm used for [method find_path]
@export_node_path("FlightPathfinder") var pathfinder

## Return a path that connects [param from] and [param to].[br]
## [param from], [param to] are in global coordinate.[br]
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var from_svolink = get_svolink_of(from)
	var to_svolink = get_svolink_of(to)
	var svolink_path: Array = (get_node(pathfinder) as FlightPathfinder).find_path(
		from_svolink, to_svolink, sparse_voxel_octree)
	var vec3_path = PackedVector3Array()
	vec3_path.resize(svolink_path.size())
	for i in range(svolink_path.size()):
		vec3_path[i] = get_global_position_of(svolink_path[i])
	return vec3_path

## Construct an SVO that can be assigned to [member sparse_voxel_octree] later.[br]
## [b]NOTE:[/b] This function is asynchronous, and span over many frames.
## Please "await" it for the result. 
func build_navigation_data(parameters: FlightNavigation3DParameter) -> SVO:
	_time_elapsed_since_last_log = Time.get_ticks_msec()
	
	#region Prepare triangles
	
	#region Get all voxelization_target
	_write_build_log("Begin get all voxelization_target")
	# Array[VoxelizationTarget]
	var target_array = get_tree().get_nodes_in_group("voxelization_target") 
	var result: Array = []
	result.resize(target_array.size())
	result.resize(0)
	for target in target_array:
		if target.voxelization_mask & voxelization_mask != 0:
			result.push_back(target)
	_write_build_log("Done get all voxelization_target: %d" % target_array.size())
	#endregion
	
	#region Build mesh
	_write_build_log("Begin build_mesh")
	var union_voxelization_target_shapes = CSGCombiner3D.new()
	union_voxelization_target_shapes.operation = CSGShape3D.OPERATION_INTERSECTION
	# The combiner must be added as child first, so that its children could have
	# their global transforms modified.
	#
	# call_deferred() is used to work in multithreading
	add_child.call_deferred(union_voxelization_target_shapes)
	await get_tree().process_frame # Wait for call_deferred
	
	for target in target_array:
		var csg_shapes = target.get_csg()
		for shape in csg_shapes:
			union_voxelization_target_shapes.add_child(shape)
			shape.global_transform = target.global_transform
			shape.operation = CSGShape3D.OPERATION_UNION
			
	# Since CSG nodes do not update immediately, calling bake_static_mesh() 
	# right away does not return the actual result.
	# So we must wait until next frame.
	await get_tree().process_frame
	var mesh = bake_static_mesh()
	if parameters.delete_csg:
		remove_child(union_voxelization_target_shapes)
		union_voxelization_target_shapes.free()
	
	var triangles = mesh.get_faces()
	_write_build_log("Done build_mesh")
	#endregion
	
	if parameters.cull_slivers:
		_write_build_log("Before cull_slivers: %d triangles" % [triangles.size()/3])
		triangles = MeshTool.cull_slivers(triangles)
		_write_build_log("Done cull_slivers: %d triangles left" % [triangles.size()/3])
	#_write_build_log("Creating array mesh from faces")
	#$MeshInstance3D.mesh = MeshTool.create_array_mesh_from_faces(triangles)
	
	# Add half a cube offset to each vertex, 
	# because morton code index starts from the corner of the cube
	_write_build_log("Offsetting vertices to local coordinate")
	var half_flight_navigation_cube_offset = size/2
	for i in range(0, triangles.size()):
		triangles[i] += half_flight_navigation_cube_offset
	#MeshTool.set_vertices_in_clockwise_order(triangles)
	#MeshTool.print_faces(triangles)
	#endregion
	
	#region Voxelize
	_write_build_log("Begin voxelizing")
	#region Determine active layer 1 nodes
	# Return dictionary of key - value: Active node morton code - Overlapping triangles.[br]
	# Overlapping triangles are serialized. Every 3 elements make up a triangle.[br]
	# [param polygon] is assumed to have length divisible by 3. Every 3 elements make up a triangle.[br]
	# [b]NOTE:[/b] This method allocates one thread per triangle
	
	_write_build_log("Determining active layer 1 nodes")
	
	# Mapping between active layer 1 node, and the triangles overlap it
	
	var act1node_triangles: Dictionary[int, PackedVector3Array] = {}
	var node1_size = _node_size(1, parameters.depth)
	if parameters.multi_threading:
		var threads: Array[Thread] = []
		threads.resize(triangles.size() / 3)
		threads.resize(0)
		_write_build_log("Spawning %d threads" % (triangles.size()/3))
		for i in range(0, triangles.size(), 3):
			threads.push_back(Thread.new())
			var err = threads.back().start(
				voxelize_triangle.bind(node1_size, triangles.slice(i, i+3)), 
				parameters.thread_priority)
			if err != OK:
				_write_build_log("Can't start thread %d. Code: %d" % [i/3, err])
				pass
				
		for t in threads:
			while true:
				if not t.is_alive():
					var triangles_overlap_node_dictionary = t.wait_to_finish()
					_merge_triangle_overlap_node_dicts(act1node_triangles, triangles_overlap_node_dictionary)
					break
				else:
					await get_tree().process_frame
	else:
		for i in range(0, triangles.size(), 3):
			_merge_triangle_overlap_node_dicts(act1node_triangles, 
				voxelize_triangle(node1_size, triangles.slice(i, i+3)))
	_write_build_log("Done determining active layer 1 nodes: %d nodes" % act1node_triangles.keys().size())
	#endregion
	
	var list_active_layer_1_node_morton_code = act1node_triangles.keys()
	
	#region Construct SVO
	_write_build_log("Constructing SVO")
	var svo = SVO.new()
	var tree_depth = parameters.depth
	if list_active_layer_1_node_morton_code.size() == 0:
		return null
		
	svo.morton.resize(tree_depth)
	svo.parent.resize(tree_depth)
	svo.first_child.resize(tree_depth)
	#svo.subgrid.resize later, when we figured out how mayn leaf SVONode are there.
	svo.xp.resize(tree_depth)
	svo.yp.resize(tree_depth)
	svo.zp.resize(tree_depth)
	svo.xn.resize(tree_depth)
	svo.yn.resize(tree_depth)
	svo.zn.resize(tree_depth)
	
	#region Construct from bottom up
	list_active_layer_1_node_morton_code.sort()
	
	#region Initialize layer 0
	var layer_0_size = list_active_layer_1_node_morton_code.size() * 8
	
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
	
	var current_active_layer_nodes = list_active_layer_1_node_morton_code
	
	# An array to hold the parent index on above layer of the current layer in building.
	# It is kept outside the for-loop to reduce memory re-allocation.
	var parent_idx = current_active_layer_nodes.duplicate()
	
	# Init layer 1 upward
	for layer in range(1, tree_depth):
		# Fill children's morton code 
		for i in range(current_active_layer_nodes.size()):
			for child in range(8):
				svo.morton[layer-1][i*8+child] = (current_active_layer_nodes[i] << 3) | child
				
		parent_idx[0] = 0
		
		# ROOT NODE CASE
		if layer == tree_depth-1:
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
	#SVO._comprehensive_test(self)
	#endregion
	
	#region Fill neighbor links from top down
	# Fill neighbor link from the second-to-top layer, 
	# because the top layer has no neighbors.
	
	if parameters.multi_threading:
		var threads: Array[Thread] = []
		# Negative X neighbor
		threads.push_back(Thread.new())
		var err = threads.back().start(
			func ():
				for layer in range(tree_depth - 2, -1, -1):
					for offset in range(svo.morton[layer].size()):
						var current_node_morton = svo.morton[layer][offset]
						var parent_svolink = svo.parent[layer][offset]
						var parent_layer = SVOLink.layer(parent_svolink)
						var parent_offset = SVOLink.offset(parent_svolink)
						var parent_first_child_offset = offset & ~0b111 # Alternatively: SVOLink.offset(svo.first_child[layer][offset])
						
						var xn = Morton3.dec_x(current_node_morton)
						
						if _mortons_different_parent(xn, current_node_morton):
							svo.xn[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
								parent_layer, parent_offset, svo.xn, xn)
						else:
							svo.xn[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (xn & 0b111))
						,
				parameters.thread_priority)
		if err != OK:
			printerr("Error creating thread for xn neighbor filling")
			
		# Positive X neighbor
		threads.push_back(Thread.new())
		err = threads.back().start(
			func ():
				for layer in range(tree_depth - 2, -1, -1):
					for offset in range(svo.morton[layer].size()):
						var current_node_morton = svo.morton[layer][offset]
						var parent_svolink = svo.parent[layer][offset]
						var parent_layer = SVOLink.layer(parent_svolink)
						var parent_offset = SVOLink.offset(parent_svolink)
						var parent_first_child_offset = offset & ~0b111 # Alternatively: SVOLink.offset(svo.first_child[layer][offset])
						
						var xp = Morton3.inc_x(current_node_morton)
						
						if _mortons_different_parent(xp, current_node_morton):
							svo.xp[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
								parent_layer, parent_offset, svo.xp, xp)
						else:
							svo.xp[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (xp & 0b111))
						,
				parameters.thread_priority)
		if err != OK:
			printerr("Error creating thread for xp neighbor filling")

		# Negative Y Neighbor
		threads.push_back(Thread.new())
		err = threads.back().start(
			func ():
				for layer in range(tree_depth - 2, -1, -1):
					for offset in range(svo.morton[layer].size()):
						var current_node_morton = svo.morton[layer][offset]
						var parent_svolink = svo.parent[layer][offset]
						var parent_layer = SVOLink.layer(parent_svolink)
						var parent_offset = SVOLink.offset(parent_svolink)
						var parent_first_child_offset = offset & ~0b111 # Alternatively: SVOLink.offset(svo.first_child[layer][offset])
						
						var yn = Morton3.dec_y(current_node_morton)
						
						if _mortons_different_parent(yn, current_node_morton):
							svo.yn[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
								parent_layer, parent_offset, svo.yn, yn)
						else:
							svo.yn[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (yn & 0b111))
						,
				parameters.thread_priority)
		if err != OK:
			printerr("Error creating thread for yn neighbor filling")
			
		# Positive Y Neighbor
		threads.push_back(Thread.new())
		err = threads.back().start(
			func ():
				for layer in range(tree_depth - 2, -1, -1):
					for offset in range(svo.morton[layer].size()):
						var current_node_morton = svo.morton[layer][offset]
						var parent_svolink = svo.parent[layer][offset]
						var parent_layer = SVOLink.layer(parent_svolink)
						var parent_offset = SVOLink.offset(parent_svolink)
						var parent_first_child_offset = offset & ~0b111 # Alternatively: SVOLink.offset(svo.first_child[layer][offset])
						
						var yp = Morton3.inc_y(current_node_morton)
						
						if _mortons_different_parent(yp, current_node_morton):
							svo.yp[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
								parent_layer, parent_offset, svo.yp, yp)
						else:
							svo.yp[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (yp & 0b111))
						,
				parameters.thread_priority)
		if err != OK:
			printerr("Error creating thread for yp neighbor filling")
			
		# Positive Z Neighbor
		threads.push_back(Thread.new())
		err = threads.back().start(
			func ():
				for layer in range(tree_depth - 2, -1, -1):
					for offset in range(svo.morton[layer].size()):
						var current_node_morton = svo.morton[layer][offset]
						var parent_svolink = svo.parent[layer][offset]
						var parent_layer = SVOLink.layer(parent_svolink)
						var parent_offset = SVOLink.offset(parent_svolink)
						var parent_first_child_offset = offset & ~0b111 # Alternatively: SVOLink.offset(svo.first_child[layer][offset])
						
						var zp = Morton3.inc_z(current_node_morton)
						
						if _mortons_different_parent(zp, current_node_morton):
							svo.zp[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
								parent_layer, parent_offset, svo.zp, zp)
						else:
							svo.zp[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (zp & 0b111))
						,
				parameters.thread_priority)
		if err != OK:
			printerr("Error creating thread for zp neighbor filling")
		
		# Negative Z Neighbor
		threads.push_back(Thread.new())
		err = threads.back().start(
			func ():
				for layer in range(tree_depth - 2, -1, -1):
					for offset in range(svo.morton[layer].size()):
						var current_node_morton = svo.morton[layer][offset]
						var parent_svolink = svo.parent[layer][offset]
						var parent_layer = SVOLink.layer(parent_svolink)
						var parent_offset = SVOLink.offset(parent_svolink)
						var parent_first_child_offset = offset & ~0b111 # Alternatively: SVOLink.offset(svo.first_child[layer][offset])
						
						var zn = Morton3.dec_z(current_node_morton)
						
						if _mortons_different_parent(zn, current_node_morton):
							svo.zn[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
								parent_layer, parent_offset, svo.zn, zn)
						else:
							svo.zn[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (zn & 0b111))
						,
				parameters.thread_priority)
		if err != OK:
			printerr("Error creating thread for zn neighbor filling")
		for t in threads:
			while true:
				if not t.is_alive():
					t.wait_to_finish()
					break
				else:
					# Unblock the main thread, so that the editor won't freeze
					await get_tree().process_frame
	else:
		for layer in range(tree_depth - 2, -1, -1):
			for offset in range(svo.morton[layer].size()):
				var current_node_morton = svo.morton[layer][offset]
				var xn = Morton3.dec_x(current_node_morton)
				var yn = Morton3.dec_y(current_node_morton)
				var zn = Morton3.dec_z(current_node_morton)
				var xp = Morton3.inc_x(current_node_morton)
				var yp = Morton3.inc_y(current_node_morton)
				var zp = Morton3.inc_z(current_node_morton)
				
				var parent_svolink = svo.parent[layer][offset]
				var parent_layer = SVOLink.layer(parent_svolink)
				var parent_offset = SVOLink.offset(parent_svolink)
				var parent_first_child_offset = offset & ~0b111 # Alternatively: SVOLink.offset(svo.first_child[layer][offset])
				
				# Negative X neighbor
				if _mortons_different_parent(xn, current_node_morton):
					svo.xn[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
						parent_layer, parent_offset, svo.xn, xn)
				else:
					svo.xn[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (xn & 0b111))
				
				# Negative Y neighbor
				if _mortons_different_parent(yn, current_node_morton):
					svo.yn[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
						parent_layer, parent_offset, svo.yn, yn)
				else:
					svo.yn[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (yn & 0b111))
				
				# Negative Z neighbor
				if _mortons_different_parent(zn, current_node_morton):
					svo.zn[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
						parent_layer, parent_offset, svo.zn, zn)
				else:
					svo.zn[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (zn & 0b111))
					
				# Positive X neighbor
				if _mortons_different_parent(xp, current_node_morton):
					svo.xp[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
						parent_layer, parent_offset, svo.xp, xp)
				else:
					svo.xp[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (xp & 0b111))
					
				# Positive Y neighbor
				if _mortons_different_parent(yp, current_node_morton):
					svo.yp[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
						parent_layer, parent_offset, svo.yp, yp)
				else:
					svo.yp[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (yp & 0b111))
					
				# Positive Z neighbor
				if _mortons_different_parent(zp, current_node_morton):
					svo.zp[layer][offset] = _ask_parent_for_neighbor_svolink(svo, 
						parent_layer, parent_offset, svo.zp, zp)
				else:
					svo.zp[layer][offset] = SVOLink.from(layer, parent_first_child_offset | (zp & 0b111))
	#endregion
	
	_write_build_log("Done constructing SVO")
	#endregion
	
	#region Voxelize tree
	# Allocate each layer-1 node with 1 thread.[br]
	# For each thread, sequentially test triangle overlapping with each of 8 layer-0 child node.[br]
	# For each layer-0 child node overlapped by triangle, launch a thread to voxelize subgrid.[br]

	if not act1node_triangles.is_empty():
		_write_build_log("Begin voxelizing tree")
		var act1node_triangles_keys: Array[int] = act1node_triangles.keys()
		_write_build_log("Spawning %d threads" % act1node_triangles_keys.size())
		if parameters.multi_threading:
			var threads: Array[Thread] = []
			threads.resize(act1node_triangles_keys.size())
			threads.resize(0)
			for key in act1node_triangles_keys:
				threads.push_back(Thread.new())
				threads.back().start(
					_voxelize_tree_node0.bind(svo, key, act1node_triangles[key]),
					parameters.thread_priority)
			for t in threads:
				while true:
					if not t.is_alive():
						t.wait_to_finish()
						break
					else:
						await get_tree().process_frame
		else:
			for key in act1node_triangles_keys:
				_voxelize_tree_node0(svo, key, act1node_triangles[key])
		_write_build_log("Done voxelizing tree")
	#endregion
	_write_build_log("Done voxelizing")
	#endregion
	return svo

var _time_elapsed_since_last_log = 0
func _write_build_log(message: String):
	var ticks = Time.get_ticks_msec()
	# call_deferred to synchronize between multiple threads
	build_log.emit(message, Time.get_time_string_from_system(), ticks - _time_elapsed_since_last_log)
	_time_elapsed_since_last_log = ticks

## Return true if svo nodes with codes m1 and m2 have the same parent
static func _mortons_different_parent(
	m1: int, # Morton3 
	m2: int # Morton3 
	) -> int: 
	# Same parent means 2nd-61th bits are the same.
	# Thus, m1 ^ m2 should have them == 0
	return (m1^m2) & 0x7FFF_FFFF_FFFF_FFF8


## [param parent_layer]: Layer index of parent node.
## [br]
## [param parent_offset]: Offset index of parent node.
## [br]
## [param face]: The direction to ask parent node for neighbor.
## [br]
## [param neighbor_morton]: Morton code of the neighbor whose SVOLink needed to find.
func _ask_parent_for_neighbor_svolink(
		svo: SVO,
		parent_layer: int, 
		parent_offset: int, 
		neighbor_face: Array[PackedInt64Array], # SVO.xn/yn/zn/xp/yp/zp
		neighbor_morton: int) -> int:	
	var parent_neighbor_svolink = neighbor_face[parent_layer][parent_offset]
	
	if parent_neighbor_svolink == SVOLink.NULL:
		return SVOLink.NULL
		
	var parent_neighbor_layer = SVOLink.layer(parent_neighbor_svolink)
	
	# If parent's neighbor is on upper layer,
	# then that upper layer node is our neighbor.
	if parent_layer != parent_neighbor_layer:
		return parent_neighbor_svolink
	
	var parent_neighbor_offset = SVOLink.offset(parent_neighbor_svolink)
	
	# If parent's neighbor has no child,
	# Then parent's neighbor is our neighbor.
	# Note: Layer 0 node always has no children. They contain only voxels.
	if parent_neighbor_layer == 0 or\
		svo.first_child[parent_neighbor_layer][parent_neighbor_offset] == SVOLink.NULL:
		return parent_neighbor_svolink
	
	var parent_neighbor_first_child_svolink = svo.first_child[parent_neighbor_layer][parent_neighbor_offset]
	return SVOLink.from(parent_layer - 1, 
		(SVOLink.offset(parent_neighbor_first_child_svolink) & ~0b111)\
		| (neighbor_morton & 0b111))


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
			
# Return dictionary of key - value: Active node morton code - Array of 3 Vector3 (vertices of [param triangle])[br]
func voxelize_triangle(
	vox_size: float, 
	triangle: PackedVector3Array) -> Dictionary[int, PackedVector3Array]:
	var result: Dictionary[int, PackedVector3Array] = {}
	var tbt = TriangleBoxTest.new(triangle, Vector3.ONE * vox_size)
		
	#_write_build_log("Voxelize triangle started.")
	var vox_range: Array[Vector3i] = _voxels_overlapped_by_aabb(vox_size, tbt.aabb, size)
		
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				if tbt.overlap_voxel(Vector3(x, y, z) * vox_size):
					var vox_morton: int = Morton3.encode64(x, y, z)
					if result.has(vox_morton):
						result[vox_morton].append_array(triangle)
					else:
						result[vox_morton] = triangle
					
	#_write_build_log("Voxelize triangle Done. Result: %s" % result.keys().size())
	return result

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
func _voxels_overlapped_by_aabb(
	voxel_size_length: float, 
	triangle_aabb: AABB, 
	voxel_bound: Vector3) -> Array[Vector3i]:
	# Begin & End
	var b: Vector3 = triangle_aabb.position/voxel_size_length
	var e: Vector3 = triangle_aabb.end/voxel_size_length
	# Clamps the result between 0 and vb (exclusive)
	var vb = voxel_bound/voxel_size_length
	
	# Include voxels merely touched by t_aabb
	b.x = b.x - (1.0 if b.x == floorf(b.x) else 0.0)
	b.y = b.y - (1.0 if b.y == floorf(b.y) else 0.0)
	b.z = b.z - (1.0 if b.z == floorf(b.z) else 0.0)
	e.x = e.x + (1.0 if e.x == roundf(e.x) else 0.0)
	e.y = e.y + (1.0 if e.y == roundf(e.y) else 0.0)
	e.z = e.z + (1.0 if e.z == roundf(e.z) else 0.0)
	
	#b.x = b.x - (1.0 if is_equal_approx(b.x, floorf(b.x)) else 0.0)
	#b.y = b.y - (1.0 if is_equal_approx(b.y, floorf(b.y)) else 0.0)
	#b.z = b.z - (1.0 if is_equal_approx(b.z, floorf(b.z)) else 0.0)
	#e.x = e.x + (1.0 if is_equal_approx(e.x, ceilf(e.x)) else 0.0)
	#e.y = e.y + (1.0 if is_equal_approx(e.y, ceilf(e.y)) else 0.0)
	#e.z = e.z + (1.0 if is_equal_approx(e.z, ceilf(e.z)) else 0.0)
	
	# Clamp to fit inside Navigation Space
	var bi: Vector3i = Vector3i(b.clamp(Vector3(), vb).floor())
	var ei: Vector3i = Vector3i(e.clamp(Vector3(), vb).ceil())
	
	return [bi, ei]


func _voxelize_tree_node0(svo: SVO, node1_morton: int, triangles: PackedVector3Array):
	var voxel_size = _node_size(-2, svo.depth)
	var node0_size = _node_size(0, svo.depth)
	var node1_size = _node_size(1, svo.depth)
	var node0_size_vec3 = Vector3(node0_size, node0_size, node0_size)
	var node1_position = Morton3.decode_vec3(node1_morton) * node1_size
	
	for i in range(0, triangles.size(), 3):
		var triangle = triangles.slice(i, i+3)
		#if triangle[0].z == triangle[1].z and triangle[1].z == triangle[2].z: # Look for corner voxel
			#pass
		var triangle_node0_test = TriangleBoxTest.new(triangle, Vector3(1,1,1) * node0_size)
		var triangle_voxel_test = TriangleBoxTest.new(triangle, Vector3(1,1,1) * voxel_size)
		
		for m in range(8): # Test overlap on all 8 nodes layer 0 within node layer 1
			var node0_svolink = svo.svolink_from_morton(0, (node1_morton << 3) | m)
			var offset = SVOLink.offset(node0_svolink)
			var node0_position = node1_position + Morton3.decode_vec3(m) * node0_size
			if triangle_node0_test.overlap_voxel(node0_position):
				#region Voxelize tree leaves
				var node0_solid_state: int = svo.subgrid[offset]
				
				var node0_aabb = AABB(node0_position, node0_size_vec3)
				var intersection = triangle_voxel_test.aabb.intersection(node0_aabb)
				intersection.position -= node0_position
				
				var vox_range = _voxels_overlapped_by_aabb(voxel_size, intersection, node0_size_vec3)
				
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
				svo.subgrid[offset] = node0_solid_state
				#endregion



#endregion

#region Utility function

## Return global position of center of the node or subgrid voxel identified as [param svolink].[br]
## [member sparse_voxel_octree] must not be null.[br]
func get_global_position_of(svolink: int) -> Vector3:
	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	
	var morton_code = sparse_voxel_octree.morton[layer][offset]
	if layer == 0:
		var voxel_morton = (morton_code << 6) | SVOLink.subgrid(svolink)#sparse_voxel_octree.subgrid[offset]
		var half_a_voxel = Vector3(0.5, 0.5, 0.5)
		return global_transform * (
			(Morton3.decode_vec3(voxel_morton) + half_a_voxel) 
			* _leaf_cube_size() + _corner())
				
	var half_a_node = Vector3(0.5, 0.5, 0.5)
	var result = global_transform\
			* ((Morton3.decode_vec3(morton_code) + half_a_node)
			 * _node_size(layer, sparse_voxel_octree.depth) + _corner())
	return result


## Return [SVOLink] of the smallest node/voxel at [param gposition].
## [br]
## [param gposition]: Global position that needs conversion to [SVOLink].
func get_svolink_of(gposition: Vector3) -> int:
	var local_pos = to_local(gposition) - _corner()
	var extent = size.x
	var aabb := AABB(Vector3.ZERO, Vector3.ONE*extent)
	
	# Points outside Navigation Space
	## TODO: Return the closest node
	if not aabb.has_point(local_pos):
		#print("Position: %v -> null" % position)
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
func _corner() -> Vector3:
	return -size/2
	
## Return the size (in local meter) of a node at 'depth' level, 
## in an SVO with 'layer'
func _node_size(layer: int, depth: int) -> float:
	return size.x * (2.0 ** (-depth + 1 + layer))
	
func _leaf_cube_size() -> float:
	return _node_size(-2, sparse_voxel_octree.depth)
	

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
	var cube = MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	var label = Label3D.new()
	cube.add_child(label)

	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	
	cube.mesh.material = StandardMaterial3D.new()
	cube.mesh.material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
	label.text = text if text != null else SVOLink.get_format_string(svolink)
			
	if layer == 0:
		cube.mesh.size = Vector3.ONE * _leaf_cube_size()
		cube.mesh.material.albedo_color = leaf_color
		label.pixel_size = _leaf_cube_size() / 400
	else:
		cube.mesh.size = Vector3.ONE * _node_size(layer, sparse_voxel_octree.depth)
		cube.mesh.material.albedo_color = node_color
		label.pixel_size = _node_size(layer, sparse_voxel_octree.depth) / 400
	cube.mesh.material.albedo_color.a = 0.2
	
	#if svolink == 90368:
		#breakpoint
		
	$SVOLinkCubes.add_child(cube)
	cube.global_position = get_global_position_of(svolink) #+ Vector3(1, 0, 0)
	return cube
	
## Draw all subgrid voxels in the svo.[br]
func draw_debug_boxes():
	var node0_size = _node_size(0, sparse_voxel_octree.depth)
	
	var threads: Array[Thread] = []
	threads.resize(sparse_voxel_octree.subgrid.size())
	threads.resize(0)
	var cube_pos : Array[PackedVector3Array] = []
	cube_pos.resize(sparse_voxel_octree.subgrid.size())
	var iterator_array = []
	iterator_array.resize(cube_pos.size())
		
	for i in range(sparse_voxel_octree.subgrid.size()):
		var svolink = SVOLink.from(0, i, 0)
		threads.push_back(Thread.new())
		threads.back().start(
			_collect_cubes.bind(
				sparse_voxel_octree,
				svolink,
				cube_pos, i, node0_size),
			Thread.PRIORITY_LOW)
	for thread in threads:
		thread.wait_to_finish()
	
	var all_pos: PackedVector3Array = []
	for pv3a in cube_pos:
		all_pos.append_array(pv3a)
		
	$DebugCubes.multimesh.mesh.size = _leaf_cube_size() * Vector3.ONE
	
	$DebugCubes.multimesh.instance_count = all_pos.size()
		
	for i in range(all_pos.size()):
		$DebugCubes.multimesh.set_instance_transform(i, 
			Transform3D(Basis(), all_pos[i]))

func _collect_cubes(
	svo: SVO, 
	svolink: int, 
	cube_pos: Array[PackedVector3Array],
	i: int,
	node0_size: float):
	cube_pos[i] = PackedVector3Array([])
	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	var node_position = node0_size * Morton3.decode_vec3(svo.morton[layer][offset]) - size/2
	for vox in range(64):
		if svo.subgrid[offset] & (1<<vox):
			var voxel_position_offset = _leaf_cube_size() * (Morton3.decode_vec3(vox) + Vector3(0.5,0.5,0.5))
			var pos = node_position + voxel_position_offset
			cube_pos[i].push_back(pos)
#endregion
	
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if !is_root_shape():
		warnings.append("Must be a root csg shape to calculate mesh correctly")
	if sparse_voxel_octree == null:# or svo.get_layer_size(0) == 0:
		warnings.push_back("No valid SVO resource found. Try voxelize it in editor or call build_navigation_data from script.")
		
	return warnings
