## Voxelize all FlightNavigationTarget inside this area
@tool
extends CSGBox3D
class_name FlightNavigation3D

# Signals to log progress on editor popup
signal progress_get_all_flight_navigation_targets_start()
signal progress_get_all_flight_navigation_targets_end(number_of_targets: int)

signal progress_build_mesh_start()
signal progress_build_mesh_end(mesh: ArrayMesh)

#signal progress__end(number_of: int)

## There could be many FlightNavigation3D in one scene, 
## and you might decide that some targets will voxelize
## in one FlightNavigation3D but not the others.
##
## If FlightNavigation3D's mask overlaps with at least
## one bit of VoxelizationTarget mask, its shapes will 
## be considered for Voxelization.
@export_flags_3d_navigation var voxelization_mask: int

@export var svo: SVO_V3

## parameters:[br]
## - int depth: number of layers this SVO has (not counting leaf layers)
func build_navigation_data(parameters: Dictionary):
	var triangles = await prepare_triangles()
	svo = voxelize(triangles, parameters)
	print("Done build navigation data: ", svo)
	

#region Prepare Triagles

## Return an array of 3*number_of_triangle Vector3.
## Each 3 consecutive vectors make up a triangle, in clockwise order
func prepare_triangles() -> PackedVector3Array:
	var target_array = get_all_flight_navigation_targets()
	var triangles = await build_mesh(target_array)
	#triangles = MeshTool.normalize_faces(triangles)
	
	$MeshInstance3D.mesh = MeshTool.create_array_mesh_from_faces(triangles)
	
	# Add half a cube offset to each vertex, 
	# because morton code index starts from the corner of the cube
	var half_flight_navigation_cube_offset = size/2
	for i in range(0, triangles.size()):
		triangles[i] += half_flight_navigation_cube_offset
	#MeshTool.set_vertices_in_clockwise_order(triangles)
	#MeshTool.print_faces(triangles)
	return triangles
	
	
func get_all_flight_navigation_targets() -> Array[VoxelizationTarget]:
	progress_get_all_flight_navigation_targets_start.emit()
	var target_array = get_tree().get_nodes_in_group("voxelization_target") 
	var result: Array[VoxelizationTarget] = []
	result.resize(target_array.size())
	result.resize(0)
	for target in target_array:
		#print("Target: %s. Class: %s" % [target.get_path(), target.get_class()])
		if target.voxelization_mask & voxelization_mask != 0:
			result.push_back(target as VoxelizationTarget)
	progress_get_all_flight_navigation_targets_end.emit(target_array.size())
	return result


func build_mesh(target_array: Array[VoxelizationTarget]) -> PackedVector3Array:
	var union_voxelization_target_shapes = CSGCombiner3D.new()
	union_voxelization_target_shapes.operation = CSGShape3D.OPERATION_INTERSECTION
	# The combiner must be added as child first, so that its children could have
	# their global transforms modified
	add_child(union_voxelization_target_shapes)
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
	var faces = mesh.get_faces()
	#var mesh = bake_collision_shape().get_faces()
	remove_child(union_voxelization_target_shapes)
	union_voxelization_target_shapes.free()
	return faces

#endregion

#region Voxelize Triangles
func voxelize(triangles: PackedVector3Array, parameters: Dictionary) -> SVO_V3:
	var act1node_triangles = determine_act1nodes(triangles, parameters)
	var act1nodes = act1node_triangles.keys()
	var new_svo = SVO_V3.create_new(parameters.depth, act1nodes)
	if not act1node_triangles.is_empty():
		_voxelize_tree(new_svo, act1node_triangles)
	return new_svo
	
# Return dictionary of key - value: Active node morton code - Overlapping triangles.[br]
# Overlapping triangles are serialized. Every 3 elements make up a triangle.[br]
# [param polygon] is assumed to have length divisible by 3. Every 3 elements make up a triangle.[br]
# [b]NOTE:[/b] This method allocates one thread per triangle
func determine_act1nodes(
	triangles: PackedVector3Array,
	parameters: Dictionary) -> Dictionary[int, PackedVector3Array]:
	# Mapping between active layer 1 node, and the triangles overlap it
	var act1node_triangles: Dictionary[int, PackedVector3Array] = {}
	var node1_size = _node_size(1, parameters.depth)
	
	var threads: Array[Thread] = []
	@warning_ignore("integer_division")
	threads.resize(triangles.size() / 3)
	threads.resize(0)
	for i in range(0, triangles.size(), 3):
		threads.push_back(Thread.new())
		threads.back().start(
			voxelize_triangle.bind(node1_size, triangles.slice(i, i+3)), 
			Thread.PRIORITY_LOW)
			
	for thread in threads:
		_merge_triangle_overlap_node_dicts(act1node_triangles, thread.wait_to_finish())
	
	# Debug (without threading):
	#for i in range(0, triangles.size(), 3):
		#_merge_triangle_overlap_node_dicts(act1node_triangles, 
			#voxelize_triangle(node1_size, triangles.slice(i, i+3)))
		 
	return act1node_triangles
	
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
	
	#if triangle[0].x == triangle[1].x and triangle[1].x == triangle[2].x:
		#pass # Debug breakpoint
		
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
	return result

# Return two Vector3i as bounding box for a range of voxels that's intersection
# between FlyingNavigation3D and [param t_aabb].[br]
# 
# The first vector (begin) contains the start voxel index (inclusive), 
# the second vector (end) is the end index (exclusive). [br]
#
# (end - begin) is non-negative. [br]
# 
# The voxel range is inside FlyingNavigation3D area.[br]
#
# The result includes also voxels merely touched by t_aabb.[br]
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
	b.x = b.x - (1.0 if b.x == roundf(b.x) else 0.0)
	b.y = b.y - (1.0 if b.y == roundf(b.y) else 0.0)
	b.z = b.z - (1.0 if b.z == roundf(b.z) else 0.0)
	
	e.x = e.x + (1.0 if e.x == roundf(e.x) else 0.0)
	e.y = e.y + (1.0 if e.y == roundf(e.y) else 0.0)
	e.z = e.z + (1.0 if e.z == roundf(e.z) else 0.0)
	
	# Clamp to fit inside Navigation Space
	var bi: Vector3i = Vector3i(b.clamp(Vector3(), vb).floor())
	var ei: Vector3i = Vector3i(e.clamp(Vector3(), vb).ceil())
	
	return [bi, ei]

# Allocate each layer-1 node with 1 thread.[br]
# For each thread, sequentially test triangle overlapping with each of 8 layer-0 child node.[br]
# For each layer-0 child node overlapped by triangle, launch a thread to voxelize subgrid.[br]
func _voxelize_tree(svo_input: SVO_V3, act1node_triangles: Dictionary[int, PackedVector3Array]):
	var act1node_triangles_keys: Array[int] = act1node_triangles.keys()
	var threads: Array[Thread] = []
	threads.resize(act1node_triangles_keys.size())
	threads.resize(0)
	
	for key in act1node_triangles_keys:
		threads.push_back(Thread.new())
		threads.back().start(
			_voxelize_tree_node0.bind(svo_input, key, act1node_triangles[key]),
			Thread.PRIORITY_LOW)
	
	for t in threads:
		t.wait_to_finish()
		
	# Debug (No threading):
	#for key in act1node_triangles_keys:
		#_voxelize_tree_node0(svo_input, key, act1node_triangles[key])
		


func _voxelize_tree_node0(svo_input: SVO_V3, node1_morton: int, triangles: PackedVector3Array):
	var node0size = _node_size(0, svo_input.depth)
	var node1size = _node_size(1, svo_input.depth) 
	
	var node1position = Morton3.decode_vec3(node1_morton) * node1size
	var node0s: Array[SVOIteratorRandom] = []
	node0s.resize(8)
	var node0position: PackedVector3Array = []
	node0position.resize(8)
	for m in range(8):
		node0s[m] = svo_input.it_from_morton(0, (node1_morton << 3) | m)
		node0position[m] = node1position + Morton3.decode_vec3(m) * node0size
		
	# This is leaf_cube_size, but overridden for svo_input
	var voxel_size = _node_size(-2, svo_input.depth)
	for i in range(0, triangles.size(), 3):
		var triangle = triangles.slice(i, i+3)
		#if triangle[0].z == triangle[1].z and triangle[1].z == triangle[2].z: # Look for corner voxel
			#pass
		var triangle_node0_test = TriangleBoxTest.new(triangle, Vector3(1,1,1) * node0size)
		var triangle_voxel_test = TriangleBoxTest.new(triangle, Vector3(1,1,1) * voxel_size)
		
		for m in range(8): # Test overlap on all 8 nodes layer 0 within node layer 1
			#var pos = node0position[m]
			if triangle_node0_test.overlap_voxel(node0position[m]):
					_voxelize_tree_leaves(triangle_voxel_test, svo_input, node0s[m], node0position[m])

func _voxelize_tree_leaves(tbtl: TriangleBoxTest, svo_input: SVO_V3, node0: SVOIteratorRandom, node0pos: Vector3):
	var node0_solid_state: int = node0.rubik
	
	var node0size = Vector3.ONE * _node_size(0, svo_input.depth)
	
	var node0aabb = AABB(node0pos, node0size)
	var intersection = tbtl.aabb.intersection(node0aabb)
	intersection.position -= node0pos
	
	# This is leaf_cube_size, but overridden for svo_input
	var voxel_size = _node_size(-2, svo_input.depth)
	
	var vox_range = _voxels_overlapped_by_aabb(voxel_size, intersection, node0size)
	
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				var morton = Morton3.encode64(x,y,z)
				var vox_offset = Vector3(x,y,z) * voxel_size
				var leaf_pos = node0pos+vox_offset
				if (node0_solid_state & (1 << morton) == 0)\
					and tbtl.overlap_voxel(leaf_pos):
						node0_solid_state |= 1<<morton
	node0.rubik = node0_solid_state

#endregion

#region Utility function

## Return global position of center of the node or subgrid voxel identified as [param svolink].[br]
## [member svo] must not be null.[br]
func get_global_position_of(svolink: int) -> Vector3:
	var layer = SVOLink.layer(svolink)
	var node = SVOIteratorRandom._new(svo, svolink)
	if svo.is_subgrid_voxel(svolink):
		var voxel_morton = (node.morton << 6) | SVOLink.subgrid(svolink)
		return global_transform*((Morton3.decode_vec3(voxel_morton) + Vector3.ONE*0.5) * _leaf_cube_size()\
				+ _corner())
	var result = global_transform\
			* ((Morton3.decode_vec3(node.morton) + Vector3.ONE*0.5) * _node_size(layer, svo.depth)\
				+ _corner())
	return result


#TODO: @return_closest_node: determine what to return if navspace doesn't encloses @gposition
# if false, return SVOLink.NULL
# if true, return the closest node 
## Return [SVOLink] of the smallest node/voxel at [param gposition].[br]
## [param gposition]: Global position that needs conversion to [SVOLink].[br]
func get_svolink_of(gposition: Vector3, _return_closest_node: bool = false) -> int:
	var local_pos = to_local(gposition) - _corner()
	var extent = size.x
	var aabb := AABB(Vector3.ZERO, Vector3.ONE*extent)
	
	# Points outside Navigation Space
	## TODO: Return the closest node
	if not aabb.has_point(local_pos):
		#print("Position: %v -> null" % position)
		return SVOLink.NULL
	
	var link_layer := svo.depth - 1
	var link_offset:= 0
	
	var it = SVOIteratorRandom._new(svo)
	# Descend the tree layer by layer
	while link_layer > 0:
		it.svolink = SVOLink.from(link_layer, link_offset, 0)
		if it.first_child == SVOLink.NULL:
			return it.svolink

		link_offset = SVOLink.offset(it.first_child)
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
	
	# If code reaches here, it means we have descended down to layer 0 already
	# If the layer 0 node is free space, return it
	if it.go(0, link_offset).subgrid == SVONode.Subgrid.EMPTY:
		return it.svolink
	
	# else, return the subgrid voxel that encloses @position
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
	return _node_size(-2, svo.depth)
	

## Draw all subgrid voxels in the svo.[br]
func draw_debug_boxes():
	var node0_size = _node_size(0, svo.depth)
	
	var threads: Array[Thread] = []
	threads.resize(svo.get_layer_size(0))
	threads.resize(0)
	var cube_pos : Array[PackedVector3Array] = []
	cube_pos.resize(svo.get_layer_size(0))
	var iterator_array = []
	iterator_array.resize(cube_pos.size())
	for i in range(iterator_array.size()):
		iterator_array[i] = SVOIteratorRandom._new(svo, SVOLink.from(0, i, 0))
		
	for i in range(svo.get_layer_size(0)):
		threads.push_back(Thread.new())
		threads.back().start(
			_collect_cubes.bind(
				iterator_array[i],
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
	node0: SVOIteratorRandom, 
	cube_pos: Array[PackedVector3Array],
	i: int,
	node0_size: float):
	cube_pos[i] = PackedVector3Array([])
	var node_pos = node0_size * Morton3.decode_vec3(node0.morton) - size/2
	for vox in range(64):
		if node0.first_child & (1<<vox):
			var offset = _leaf_cube_size() * (Morton3.decode_vec3(vox) + Vector3(0.5,0.5,0.5))
			var pos = node_pos + offset
			cube_pos[i].push_back(pos)
#endregion
	
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if !is_root_shape():
		warnings.append("Must be a root csg shape to calculate mesh correctly")
	if svo == null or svo.get_layer_size(0) == 0:
		warnings.push_back("No valid SVO resource found. Try voxelize it in editor or call build_navigation_data from script.")
		
	return warnings
