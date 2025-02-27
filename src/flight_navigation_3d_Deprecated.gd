## Voxelize all FlightNavigationTarget inside this area
##
## [b]Warning:[/b] [param monitoring] and [param monitorable] must be kept on 
## to detect [StaticBody3D] and [Area3D]
@tool
extends MeshInstance3D
class_name FlightNavigation3D_Deprecated

# Emitted when voxelize() or voxelize_async() finishes
#signal finished()

# TODO: Specialize Triangle-box overlap test for these cases:
# - One-voxel thick bounding box
# - Dominant normal axis (3 possible voxels/column)

## There could be many FlightNavigation3D in one scene, 
## and you might decide that this FlightNavigation3D 
## will voxelize some targets but not the others.
##
## If FlightNavigation3D's mask overlaps with at least
## one bit of VoxelizationTarget mask, its shapes will 
## be considered for Voxelization.
@export_flags_3d_navigation var voxelization_mask

## The SVO used for obstacle information for [member pathfinder].[br]
## Generated by [method voxelize_async], [method voxelize], or loaded from an .svo file[br]
## To generate the solid states, first create a new [SVO] resource, set [member SVO.depth],
## and then call [method voxelize_async] or [method voxelize].[br]
@export var svo: SVO:
	set(new_svo):
		if svo != null:
			svo.changed.disconnect(_on_svo_changed)
		svo = new_svo
		if new_svo != null:
			new_svo.changed.connect(_on_svo_changed)
			_on_svo_changed()
		update_configuration_warnings()


func _on_svo_changed():
	if svo != null:
		_leaf_cube_size = _node_size(-2, svo.depth)


## Node with pathfinding algorithm used for [method find_path]
@export_node_path("FlightPathfinder") var pathfinder

@export_group("Read-only Informations")
## An indication of how small the finest voxel is going to be.[br]
## [b]TODO:[/b] Create a small MeshInstance box in the corner of the voxelize
## area for illustration
@export var leaf_cube_size : float:
	get: 
		return 0.0 if svo == null else _node_size(-2, svo.depth)
		#return _leaf_cube_size
var _leaf_cube_size: float = 0.0

func _ready():
	$Extent/DebugVisual.mesh.size = $Extent.shape.size
	_recalculate_cached_data()
	update_configuration_warnings()
	
## Voxelize and return a reference to [SVO] after assigning it to [member svo]
##
## Expensive, should call only once when all CollisionShapes are registered[br]
## [br]
## [b]WARNING: DO NOT[/b] call on _ready(), because physic engine have not
## processed this node to gather overlapping collision objects yet.
## Try set a [Timer] of 0.1s to wait for physics.[br]
## [br]
## [b]NOTE:[/b] Using [method call_deferred] on _ready() doesn't
## guarantee it to have had physic run. I strongly recommend setting [Timer].[br]
## [br]
## [b]NOTE:[/b] This function is computationally expensive,
## which could freeze the game for a while.[br]
func voxelize(depth: int) -> SVO:
	svo = _voxelize(depth)
	return svo


## Like [method voxelize], but doesn't block the main thread.[br]
## [param on_complete_callback] is a [Callable] of signature: [code]func(svo: SVO) -> void[/code].
## It is called after voxelization is completed.[br]
## Return the thread. This thread needs to be saved until completion.[br]
func voxelize_async(depth: int, on_complete_callback: Callable) -> Thread:
	var voxelize_thread = Thread.new()
	voxelize_thread.start(
			_voxelize_async.bind(depth, on_complete_callback), 
			Thread.PRIORITY_LOW)
	return voxelize_thread


## Return a path that connects [param from] and [param to].[br]
## [param from], [param to] are in global coordinate.[br]
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var svolink_path: Array = (get_node(pathfinder) as FlightPathfinder).find_path(get_svolink_of(from), get_svolink_of(to), svo)
	return svolink_path.map(func (link) -> Vector3:
		return get_global_position_of(link))


#func find_path_async(from: Vector3, to: Vector3, ...) -> PackedVector3Array:
#	return []

#################################

func _voxelize(depth: int) -> SVO:
	var act1node_triangles = _determine_act1nodes(depth)
	var act1nodes = act1node_triangles.keys()
	var new_svo = SVO.create_new(depth, act1nodes)
	if not act1node_triangles.is_empty():
		_voxelize_tree(new_svo, act1node_triangles)
	return new_svo


func _voxelize_async(depth: int, on_complete_call_back: Callable):
	svo = _voxelize(depth)
	on_complete_call_back.call_deferred(svo)


############################

## Convert [param out_triangles] (in-place) from collision_shape's transform 
## to [FlightNavigation3D]'s transform.[br]
## Return reference to [param out_triangles].
func _convert_to_local_transform_in_place(
	collision_shape: CollisionShape3D, 
	out_triangles: PackedVector3Array) -> PackedVector3Array:
		var mesh_to_navspace: \
		Transform3D = _origin_global_transform_inv \
					* collision_shape.global_transform
	
		for i in range(0, out_triangles.size()):
			out_triangles[i] = mesh_to_navspace * out_triangles[i]
		return out_triangles


func _get_overlapping_shapes() -> Array[Shape3D]:
	var targets = get_tree()\
	.get_nodes_in_group("VoxelizationTarget")\
	.filter(func (target: VoxelizationTarget): return target.voxelization_mask & voxelization_mask)\
	.map(func (target: VoxelizationTarget): return target.get_shapes())
	return []
	

## Return dictionary associating Morton codes of active nodes with triangles overlapping them
func _determine_act1nodes(depth: int) -> Dictionary:
	var act1node_triangles: Dictionary = {}
	var node1_size = _node_size(1, depth)
	var overlapping_shapes = _get_overlapping_shapes()
	for collision_shape in overlapping_shapes:
		var faces = MeshTool.get_faces(collision_shape.shape)
		faces = _convert_to_local_transform_in_place(collision_shape, faces)
		_merge_triangle_overlap_node_dicts(act1node_triangles, 
			_voxelize_polygon(node1_size, faces))
	return act1node_triangles


# Return dictionary of key - value: Active node morton code - Overlapping triangles.[br]
# Overlapping triangles are serialized. Every 3 elements make up a triangle.[br]
# [param polygon] is assumed to have length divisible by 3. Every 3 elements make up a triangle.[br]
# [b]NOTE:[/b] This method allocates one thread per triangle
func _voxelize_polygon(vox_size: float, polygon_faces: PackedVector3Array) -> Dictionary:
	var result = {}
	var threads: Array[Thread] = []
	@warning_ignore("integer_division")
	threads.resize(polygon_faces.size() / 3)
	threads.resize(0)
	for i in range(0, polygon_faces.size(), 3):
		threads.push_back(Thread.new())
		threads.back().start(
			_voxelize_triangle.bind(vox_size, polygon_faces.slice(i, i+3)), 
			Thread.PRIORITY_LOW)
			
	for thread in threads:
		_merge_triangle_overlap_node_dicts(result, thread.wait_to_finish())
	return result


# Return dictionary of key - value: Active node morton code - Array of 3 Vector3 (vertices of [param triangle])[br]
func _voxelize_triangle(vox_size: float, triangle: PackedVector3Array) -> Dictionary:
	var result = {}
	var tbt = TriangleBoxTest.new(triangle, Vector3(1,1,1) * vox_size)
	var vox_range: Array[Vector3i] = _voxels_overlapped_by_aabb(vox_size, tbt.aabb, _extent_size)
		
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				if tbt.overlap_voxel(Vector3(x, y, z) * vox_size):
					var vox_morton = Morton3.encode64(x, y, z)
					if result.has(vox_morton):
						result[vox_morton].append_array(triangle)
					else:
						result[vox_morton] = triangle
	return result

# Merge information of triangles overlapping a node from [param append] to [param base].[br]
#
# Both [param base] and [param append] are dictionaries of Key - Value: 
# Morton code - Array of vertices, every 3 elements make a triangle.[br]
#
# [b]NOTE:[/b] Duplicated triangles are not removed from [param base].
func _merge_triangle_overlap_node_dicts(base: Dictionary, append: Dictionary) -> void:
	for key in append.keys():
		if base.has(key):
			base[key].append_array(append[key])
		else:
			base[key] = append[key].duplicate()


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
# [param size] is the side length of a voxel.[br]
# [param t_aabb] is the triangle's AABB.[br]
# [param vox_bound] clamps the result between 0 and [param vox_bound]/[param size] (exclusive)
func _voxels_overlapped_by_aabb(size: float, t_aabb: AABB, vox_bound: Vector3) -> Array[Vector3i]:
	# Begin & End
	var b = t_aabb.position/size
	var e = t_aabb.end/size
	var vb = vox_bound/size
	
	# Include voxels merely touched by t_aabb
	b.x = b.x - (1 if b.x == round(b.x) else 0)
	b.y = b.y - (1 if b.y == round(b.y) else 0)
	b.z = b.z - (1 if b.z == round(b.z) else 0)
	
	e.x = e.x + (1 if e.x == round(e.x) else 0)
	e.y = e.y + (1 if e.y == round(e.y) else 0)
	e.z = e.z + (1 if e.z == round(e.z) else 0)
	
	# Clamp to fit inside Navigation Space
	b = b.clamp(Vector3(), vb).floor()
	e = e.clamp(Vector3(), vb).ceil()
	
	return [b, e]


# Allocate each layer-1 node with 1 thread.[br]
# For each thread, sequentially test triangle overlapping with each of 8 layer-0 child node.[br]
# For each layer-0 child node overlapped by triangle, launch a thread to voxelize subgrid.[br]
func _voxelize_tree(svo_input: SVO, act1node_triangles: Dictionary):
	var a1t_keys = act1node_triangles.keys()
	var threads: Array[Thread] = []
	threads.resize(a1t_keys.size())
	threads.resize(0)
	
	for key in a1t_keys:
		threads.push_back(Thread.new())
		threads.back().start(
			_voxelize_tree_node0.bind(svo_input, key, act1node_triangles[key]),
			Thread.PRIORITY_LOW)
	
	for t in threads:
		t.wait_to_finish()


func _voxelize_tree_node0(svo_input: SVO, node1_morton: int, triangles: PackedVector3Array):
	var node0size = _node_size(0, svo_input.depth)
	var node1size = _node_size(1, svo_input.depth) 
	
	var node1pos = Morton3.decode_vec3(node1_morton) * node1size
	var node0s: Array[SVONode] = []
	node0s.resize(8)
	var node0pos: PackedVector3Array = []
	node0pos.resize(8)
	for m in range(8):
		node0s[m] = svo_input.node_from_morton(0, (node1_morton << 3) | m)
		node0pos[m] = node1pos + Morton3.decode_vec3(m) * node0size
		
	# This is leaf_cube_size, but overridden for svo_input
	var voxel_size = _node_size(-2, svo_input.depth)
	for i in range(0, triangles.size(), 3):
		var triangle = triangles.slice(i, i+3)
		var triangle_node0_test = TriangleBoxTest.new(triangle, Vector3(1,1,1) * node0size)
		var triangle_voxel_test = TriangleBoxTest.new(triangle, Vector3(1,1,1) * voxel_size)
		for m in range(8):
			if triangle_node0_test.overlap_voxel(node0pos[m]):
					_voxelize_tree_leaves(triangle_voxel_test, svo_input, node0s[m], node0pos[m])


func _voxelize_tree_leaves(tbtl: TriangleBoxTest, svo_input: SVO, node0: SVONode, node0pos: Vector3):
	var node0_solid_state: int = node0.subgrid
	
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
	node0.subgrid = node0_solid_state


## Return global position of center of the node or subgrid voxel identified as [param svolink].[br]
## [member svo] must not be null.[br]
func get_global_position_of(svolink: int) -> Vector3:
	var layer = SVOLink.layer(svolink)
	var node = svo.node_from_link(svolink)
	if svo.is_subgrid_voxel(svolink):
		var voxel_morton = (node.morton << 6) | SVOLink.subgrid(svolink)
		return global_transform*((Morton3.decode_vec3(voxel_morton) + Vector3.ONE*0.5) * leaf_cube_size\
				+ _extent_origin)
	var result = global_transform\
			* ((Morton3.decode_vec3(node.morton) + Vector3.ONE*0.5) * _node_size(layer, svo.depth)\
				+ _extent_origin)
	return result


#TODO: @return_closest_node: determine what to return if navspace doesn't encloses @gposition
# if false, return SVOLink.NULL
# if true, return the closest node 
## Return [SVOLink] of the smallest node/voxel at [param gposition].[br]
## [param gposition]: Global position that needs conversion to [SVOLink].[br]
func get_svolink_of(gposition: Vector3, _return_closest_node: bool = false) -> int:
	var local_pos = to_local(gposition) - _extent_origin
	var extent = _extent_size.x
	var aabb := AABB(Vector3.ZERO, Vector3.ONE*extent)
	
	# Points outside Navigation Space
	## TODO: Return the closest node
	if not aabb.has_point(local_pos):
		#print("Position: %v -> null" % position)
		return SVOLink.NULL
	
	var link_layer := svo.depth - 1
	var link_offset:= 0
	
	# Descend the tree layer by layer
	while link_layer > 0:
		var this_node_link = SVOLink.from(link_layer, link_offset, 0)
		var this_node = svo.node_from_link(this_node_link)
		if this_node.first_child == SVOLink.NULL:
			return this_node_link

		link_offset = SVOLink.offset(this_node.first_child)
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
	if svo.node_from_offset(0, link_offset).subgrid == SVONode.Subgrid.EMPTY:
		return SVOLink.from(0, link_offset, 0)
	
	# else, return the subgrid voxel that encloses @position
	var subgridv = (local_pos - aabb.position) * 4 / aabb.size
	return SVOLink.from(0, link_offset, Morton3.encode64v(subgridv))

############## DEBUGS #######################

## Draw a box represents the space occupied by an [SVONode] identified as [param svolink].[br]
## 
## Return a reference to the box. [br] 
##
## Gives [param text] a custom value to insert a label in the center of the box.
## null for default value of [method SVOLink.get_format_string].[br]
##
## [b]NOTE:[/b]: [member svo] must not be null.[br]
func draw_svolink_box(svolink: int, 
		node_color: Color = Color.RED, 
		leaf_color: Color = Color.GREEN,
		text = null) -> MeshInstance3D:
	var cube = MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	var label = Label3D.new()
	cube.add_child(label)
	
	var layer = SVOLink.layer(svolink)
	var node = svo.node_from_link(svolink)
	cube.mesh.material = StandardMaterial3D.new()
	cube.mesh.material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
	#label.text = text if text != null else SVOLink.get_format_string(svolink, svo)
			
	if layer == 0 and node.first_child != 0:
		cube.mesh.size = Vector3.ONE * leaf_cube_size
		cube.mesh.material.albedo_color = leaf_color
		label.pixel_size = leaf_cube_size / 400
	else:
		cube.mesh.size = Vector3.ONE * _node_size(layer, svo.depth)
		cube.mesh.material.albedo_color = node_color
		label.pixel_size = _node_size(layer, svo.depth) / 400
	cube.mesh.material.albedo_color.a = 0.2
	
	$Origin/SVOLinkCubes.add_child(cube)
	cube.global_position = get_global_position_of(svolink) #+ Vector3(1, 0, 0)
	return cube
	

## Draw all subgrid voxels in the svo.[br]
func draw_debug_boxes():
	for cube in $Origin/DebugCubes.get_children():
		cube.queue_free()
	var node0_size = _node_size(0, svo.depth)
	
	var threads: Array[Thread] = []
	threads.resize(svo.layers[0].size())
	threads.resize(0)
	var cube_pos : Array[PackedVector3Array] = []
	cube_pos.resize(svo.layers[0].size())
	for i in range(svo.layers[0].size()):
		threads.push_back(Thread.new())
		threads.back().start(
			_collect_cubes.bind(svo.layers[0][i], cube_pos, i, node0_size),
			Thread.PRIORITY_LOW)
	for thread in threads:
		thread.wait_to_finish()
	
	var all_pos: PackedVector3Array = []
	for pv3a in cube_pos:
		all_pos.append_array(pv3a)
		
	$Origin/DebugCubes.multimesh.mesh.size = leaf_cube_size * Vector3.ONE
	
	$Origin/DebugCubes.multimesh.instance_count = all_pos.size()
		
	for i in range(all_pos.size()):
		$Origin/DebugCubes.multimesh.set_instance_transform(i, 
			Transform3D(Basis(), all_pos[i]))


func _collect_cubes(
	node0: SVONode, 
	cube_pos: Array[PackedVector3Array],
	i: int,
	node0_size: float):
	cube_pos[i] = PackedVector3Array([])
	var node_pos = node0_size * Morton3.decode_vec3(node0.morton)
	for vox in range(64):
		if node0.first_child & (1<<vox):
			var offset = leaf_cube_size * (Morton3.decode_vec3(vox) + Vector3(0.5,0.5,0.5))
			var pos = node_pos + offset
			cube_pos[i].push_back(pos)


############## CONFIG WARNINGS ##############

func _get_configuration_warnings():
	var warnings: PackedStringArray = []
	if not $Extent.shape is BoxShape3D:
		warnings.push_back("Extent must be BoxShape3D.")
	var s = $Extent.shape.size
	if s.x != s.y or s.y != s.z:
		warnings.push_back("Extent's side lengths must be equal. Make Extent a cube.")
	if svo == null:
		warnings.push_back("No svo resource found. Please create a new one.")
	elif svo.layers[0].size() == 0:
		warnings.push_back("SVO empty. Try voxelize it to obtain voxel solid state informations.")
		
	return warnings


func _on_property_list_changed():
	update_configuration_warnings()

##############

func _node_size(layer: int, depth: int) -> float:
	return _extent_size.x * (2.0 ** (-depth + 1 + layer))

## The smallest (x, y, z) corner of $Extent. It's cached here to be used in threads.
## It's local transform.
var _extent_origin := Vector3()

# $Extent.shape.size. It's cached here to be used in threads.
var _extent_size:= Vector3()

# $Origin.global_transform.inverse(). It's cached here to be used in threads.
var _origin_global_transform_inv: Transform3D

func _recalculate_cached_data():
	$Origin.position = - $Extent.shape.size/2
	_extent_origin = $Origin.position
	_extent_size = $Extent.shape.size
	_origin_global_transform_inv = $Origin.global_transform.inverse()
	_on_svo_changed()
	
	
func _on_extent_property_list_changed():
	_recalculate_cached_data()
