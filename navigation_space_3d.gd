# Voxelize StaticBodies in the specified area
# "monitoring" and "monitorable" must be kept on to detect StaticBody3D

# TODO: Unify the use of "layer", "depth".
# Some places mean SVO depth + 2 subgrid layers
# Other places mean only SVO depth


# WARNING: Do NOT call voxelize() or voxelize_async() in _ready(). 
# Call it only after all the shapes have been registered by the physic engine
# e.g. 0.05s after _ready()
@tool
extends Area3D
class_name NavigationSpace3D

## Emitted when voxelize() or voxelize_async() finishes
signal finished()

# TODO: Specialize Triangle-box overlap test for these cases:
# - One-voxel thick bounding box
# - Dominant normal axis (3 possible voxels/column)

# TODO: Support more type of shapes
# Sphere
# Capsule
# Cylinder

## TODO: Bake geometry & save to files
#@export_file() var bakedFile: String = ""

## Higher depth rasterizes collision shapes in more details,
## but also consumes more memory. Each layer adds roughly 8 
## times more memory consumption. Only supports 
## upto TreeAttribute.MAX_DEPTH layers. I reckon your computer
## can't handle more than that.
@export_range(TreeAttribute.MIN_DEPTH, TreeAttribute.MAX_DEPTH)\
		var max_depth: int = TreeAttribute.MIN_DEPTH:
				set(value):
						max_depth = clampi(value, 
									TreeAttribute.MIN_DEPTH, 
									TreeAttribute.MAX_DEPTH)
						_update_information()
						notify_property_list_changed()


## Disable editor warnings when max_depth is too big
@export var disable_depth_warning := false:
	set(value):
		disable_depth_warning = value
		notify_property_list_changed()
		

## This value is READ-ONLY. Modifying it has no effect on the tree construction.
@export var leaf_cube_size := 0.0:
	get:
		return _leaf_cube_size


func _ready():
	$Extent/DebugVisual.mesh.size = $Extent.shape.size
	_recalculate_cached_data()
	_update_information()
	

## Expensive, should call only once
## when all CollisionShapes are registered
## WARNING: Do Not call it on _ready()!
## This function blocks the main thread
func voxelize():
	_voxelize()
	emit_signal("finished")

## Like voxelize(), but doesn't block the main thread
var _background_voxelize_thread: Thread
func voxelize_async():
	_background_voxelize_thread = Thread.new()
	_background_voxelize_thread.start(_voxelize_async, Thread.PRIORITY_LOW)


## @from, @to: Global Positions
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return $Astar.find_path(
		to_local(from) - _extent_origin, 
		to_local(to) - _extent_origin, 
		_svo, self)

#func find_path_async(from: Vector3, to: Vector3, ...) -> PackedVector3Array:
#	return []

#################################

func _voxelize():
	var act1node_triangles = _determine_act1nodes()
	var svo = SVO.new(max_depth, act1node_triangles.keys())
	_voxelize_tree(svo, act1node_triangles)
	_svo = svo

func _voxelize_async():
	_voxelize()
	call_deferred("emit_signal", "finished")

############################

func _on_body_shape_entered(
	_body_rid: RID,
	body: PhysicsBody3D,
	body_shape_index: int,
	_local_shape_index: int):
		#print("enter: " + str(body))
		if not body is StaticBody3D:
			return
		
		var col_shape: CollisionShape3D = body.shape_owner_get_owner(
			shape_find_owner(body_shape_index))
		
		_entered_shapes.append(col_shape)

func _get_box_faces(col_shape: CollisionShape3D) -> PackedVector3Array:
	var box = BoxMesh.new()
	box.size = col_shape.shape.size
	var arr_mesh = ArrayMesh.new()
	var ma = box.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	
	return _convert_to_local_transform_in_place(col_shape, arr_mesh.get_faces())


func _get_polygon_faces(col_shape: CollisionShape3D) -> PackedVector3Array:
	var polymesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] =\
		(col_shape.shape as ConvexPolygonShape3D).points
	polymesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	return _convert_to_local_transform_in_place(col_shape, polymesh.get_faces())


## Convert @out_triangles (in-place) from col_shape's transform 
## to NavigationSpace transform
## Return reference to @out_triangles
func _convert_to_local_transform_in_place(
	col_shape: CollisionShape3D, 
	out_triangles: PackedVector3Array) -> PackedVector3Array:
		var mesh_to_navspace: \
		Transform3D = _origin_global_transform_inv \
					* col_shape.global_transform
	
		for i in range(0, out_triangles.size()):
			out_triangles[i] = mesh_to_navspace * out_triangles[i]
		return out_triangles
		

func _on_body_shape_exited(
	_body_rid: RID,
	body: PhysicsBody3D,
	body_shape_index: int,
	_local_shape_index: int):
		if not body is StaticBody3D:
			_entered_shapes.erase(body.shape_owner_get_owner(
			shape_find_owner(body_shape_index)).shape)


############## PRIVATE METHODS ###############

## Return dictionary associating: 
## Morton code of active nodes ~~~ Triangles overlapping it
func _determine_act1nodes() -> Dictionary:
	var act1node_triangles: Dictionary = {}
	var node1_size = _node_size(1)
	for col_shape in _entered_shapes:
		var faces = []
		if col_shape.shape is BoxShape3D:
			faces = _get_box_faces(col_shape) 
		elif col_shape.shape is ConvexPolygonShape3D:
			faces = _get_polygon_faces(col_shape) 
		elif col_shape.shape is ConcavePolygonShape3D:
			faces = _convert_to_local_transform_in_place(col_shape, 
						col_shape.shape.get_faces())
		
		_merge_triangle_overlap_node_dicts(act1node_triangles, 
			_voxelize_polygon(node1_size, faces))
			
	return act1node_triangles


## Return dictionary associating: 
## Morton code of active nodes ~~~ Triangles overlapping it
## @polygon is assumed to have length divisible by 3
## Every 3 elements make up a triangle
## Allocate one thread per triangle
func _voxelize_polygon(vox_size: float, polygon_faces: PackedVector3Array) -> Dictionary:
	var result = {}
	var threads: Array[Thread] = []
	# Using roundf() to avoid integer division warning
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

## Return a dictionary 
## Key: Morton of active nodes 
## Values: Triangles overlapping it, 
##	serialized into a PackedVector3Array. Every 3 makes a triangle
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


## @size: The length in side of a voxel
## @t_aabb: Triangle's AABB
## @vox_bound: Clamp the result between 0 and vox_bound/size (exclusive)
## @return: [begin, end) (end is exclusive)
##	(end - begin) is non-negative
##	begin and end are inside Navigation Space  
##	Includes also voxels meerly touched by t_aabb
func _voxels_overlapped_by_aabb(size: float, t_aabb: AABB, vox_bound: Vector3) -> Array[Vector3i]:
	# Begin & End
	var b = t_aabb.position/size
	var e = t_aabb.end/size
	var vb = vox_bound/size
	
	# Include voxels meerly touched by t_aabb
	b.x = b.x - (1 if b.x == round(b.x) else 0)
	b.y = b.y - (1 if b.y == round(b.y) else 0)
	b.z = b.z - (1 if b.z == round(b.z) else 0)
	
	e.x = e.x + (1 if e.x == round(e.x) else 0)
	e.y = e.y + (1 if e.y == round(e.y) else 0)
	e.z = e.z + (1 if e.z == round(e.z) else 0)
	
	# Clamp to fit inside Navigation Space
	b = b.clamp(Vector3(), vb)
	e = e.clamp(Vector3(), vb)
	
	return [b.floor(), e.ceil()]


## Allocate each node1 with 1 thread
## For each thread, sequentially test overlap each triangle with
## each of 8 node0 child
## For each node0 child overlapped by triangle, launch a thread to 
## test overlap for subgrid
## Join all subgrid tests before starting with the next triangle
func _voxelize_tree(svo: SVO, act1node_triangles: Dictionary):
	var a1t_keys = act1node_triangles.keys()
	var threads: Array[Thread] = []
	threads.resize(a1t_keys.size())
	threads.resize(0)
	
	for key in a1t_keys:
		threads.push_back(Thread.new())
		threads.back().start(
			_voxelize_tree_node0.bind(svo, key, act1node_triangles[key]),
			Thread.PRIORITY_LOW)
	
	for t in threads:
		t.wait_to_finish()

## Sequentially test overlap each triangle with
## each of 8 node0 child
## For each node0 child overlapped by triangle, launch a thread to 
## test overlap for subgrid
## Join all subgrid tests before starting with the next triangle
func _voxelize_tree_node0(svo: SVO, node1_morton: int, triangles: PackedVector3Array):
	#print("Voxing 0:   %s" % Morton.int_to_bin(node1_morton))
	var node0size = _node_size(0)
	var node1size = _node_size(1) 
	
	var node1pos = Morton3.decode_vec3(node1_morton) * node1size
	var node0s: Array[SVO.SVONode] = []
	node0s.resize(8)
	var node0pos: PackedVector3Array = []
	node0pos.resize(8)
	for m in range(8):
		node0s[m] = svo.node_from_morton(0, (node1_morton << 3) | m)
		node0pos[m] = node1pos + Morton3.decode_vec3(m) * node0size
		
	for i in range(0, triangles.size(), 3):
		var threads: Array[Thread] = []
		var triangle = triangles.slice(i, i+3)
		
		# Node layer 0 - Triangle Test
		var tbt0 = TriangleBoxTest.new(triangle, Vector3(1,1,1) * _node_size(0))
		
		# Leaf voxel - Triangle Test
		var tbtl = TriangleBoxTest.new(triangle, Vector3(1,1,1) * _leaf_cube_size)
		#print("Leaf cube: %f" % _leaf_cube_size)
		
		for m in range(8):
			if tbt0.overlap_voxel(node0pos[m]):
				threads.push_back(Thread.new())
				threads.back().start(
					_voxelize_tree_leaves.bind(tbtl, node0s[m], node0pos[m]),
					Thread.PRIORITY_LOW)
						
		for thread in threads:
			thread.wait_to_finish()

# TODO: Optimize _node_size calls
# TODO: Pre-calculate morton offset of leaf nodes
func _voxelize_tree_leaves(tbtl: TriangleBoxTest, node0: SVO.SVONode, node0pos: Vector3):
	var node0_solid_state: int = node0.first_child
	
	var node0size = Vector3(1,1,1) * _node_size(0)
	var node0aabb = AABB(node0pos, node0size)
	var intersection = tbtl.aabb.intersection(node0aabb)
	intersection.position -= node0pos
	var vox_range = _voxels_overlapped_by_aabb(_leaf_cube_size, intersection, node0size)
	
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				var morton = Morton3.encode64(x,y,z)
				var vox_offset = Vector3(x,y,z) * _leaf_cube_size
				var leaf_pos = node0pos+vox_offset
				if (node0_solid_state & (1 << morton) == 0)\
					and tbtl.overlap_voxel(leaf_pos):
						node0_solid_state |= 1<<morton
	node0.first_child = node0_solid_state


############## DEBUGS #######################


## TODO: Add Color argument
func draw_svolink_box(svolink: int):
	var cube = MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	cube.mesh.size = Vector3.ONE * _node_size(SVOLink.layer(svolink))
	$Origin/SVOLinkCubes.add_child(cube)
	cube.position = SVOLink.to_navspace(_svo, self, svolink)


func draw_debug_boxes():
	for cube in $Origin/DebugCubes.get_children():
		cube.queue_free()
	var node0_size = _node_size(0)
	
	var threads: Array[Thread] = []
	threads.resize(_svo._nodes[0].size())
	threads.resize(0)
	var cube_pos : Array[PackedVector3Array] = []
	cube_pos.resize(_svo._nodes[0].size())
	for i in range(_svo._nodes[0].size()):
		threads.push_back(Thread.new())
		threads.back().start(
			_collect_cubes.bind(_svo._nodes[0][i], cube_pos, i, node0_size),
			Thread.PRIORITY_LOW)
	for thread in threads:
		thread.wait_to_finish()
	
	var all_pos: PackedVector3Array = []
	for pv3a in cube_pos:
		all_pos.append_array(pv3a)
		
	$Origin/DebugCubes.multimesh.mesh.size = _leaf_cube_size * Vector3(1,1,1)
	$Origin/DebugCubes.multimesh.instance_count = all_pos.size()
		
	for i in range(all_pos.size()):
		$Origin/DebugCubes.multimesh.set_instance_transform(i, 
			Transform3D(Basis(), all_pos[i]))


func _collect_cubes(
	node0: SVO.SVONode, 
	cube_pos: Array[PackedVector3Array],
	i: int,
	node0_size: float):
	cube_pos[i] = PackedVector3Array([])
	var node_pos = node0_size * Morton3.decode_vec3(node0.morton)
	for vox in range(64):
		if node0.first_child & (1<<vox):
			var offset = _leaf_cube_size * (Morton3.decode_vec3(vox) + Vector3(0.5,0.5,0.5))
			var pos = node_pos + offset
			cube_pos[i].push_back(pos)

## Merge information of triangles overlapping a node, from @append to @base
## Both @base and @append are dictionarys with Keys: SVONode's Morton code,
## Values: PackedVector3Array of Vertices. Every 3 elements make a triangle
## Return: @base will contain all informations from append. Duplicates are 
## possible, if @append appears more than once 
func _merge_triangle_overlap_node_dicts(base: Dictionary, append: Dictionary):
	for key in append.keys():
		if base.has(key):
			base[key].append_array(append[key])
		else:
			base[key] = append[key].duplicate()
	# Since @base is already a reference, no need to return anything here


############## CONFIG WARNINGS ##############

func _get_configuration_warnings():
	var warnings: PackedStringArray = []
	if not $Extent.shape is BoxShape3D:
		warnings.push_back("Extent must be BoxShape3D.")
	var s = $Extent.shape.size
	if s.x != s.y or s.y != s.z:
		warnings.push_back("Extent's side lengths must be equal. Make Extent a cube.")
	
	if disable_depth_warning:
		return warnings

	if max_depth >= TreeAttribute.DANGEROUS_DRAW_DEPTH:
		warnings.push_back("Calling draw_debug_boxes() might crash at this tree depth.")
	if max_depth >= TreeAttribute.DANGEROUS_MAX_DEPTH:
		warnings.push_back("Can your machine really handle a voxel tree this deep and big?")
	return warnings


func _on_property_list_changed():
	update_configuration_warnings()

##############


var _entered_shapes: Array[CollisionShape3D] = []

func _node_size(layer: int) -> float:
	return _leaf_cube_size * (2**(2 + layer))


enum TreeAttribute{
	LEAF_LAYERS = 2,
	MIN_DEPTH = 4,
	DANGEROUS_DRAW_DEPTH = 8,
	DANGEROUS_MAX_DEPTH = DANGEROUS_DRAW_DEPTH + 2,
	MAX_DEPTH = 14,
}

var _svo: SVO

var _leaf_cube_size: float = 1
var _extent_origin := Vector3()
var _extent_size:= Vector3()
var _origin_global_transform_inv: Transform3D

func _recalculate_cached_data():
	_leaf_cube_size = $Extent.shape.size.x / 2**(max_depth-1)
	$Origin.position = - $Extent.shape.size/2
	_extent_origin = $Origin.position
	_extent_size = $Extent.shape.size
	_origin_global_transform_inv = $Origin.global_transform.inverse()
	
func _on_extent_property_list_changed():
	_recalculate_cached_data()
	_update_information()

func _update_information():
	if get_child_count() > 0:
		_leaf_cube_size = $Extent.shape.size.x / 2**(max_depth-1)
