# Voxelize StaticBodies in the specified area
# "monitoring" and "monitorable" must be kept on to detect StaticBody3D
@tool
extends Area3D
class_name NavigationSpace3D

# TODO: Save the collision shapes' mesh in a variable to avoid 
# generating mesh twice, once in _determine_act1nodes, once in _voxelise_leaf_layer

# TODO: Specialize Triangle-box overlap test for these cases:
## - One-voxel thick bounding box
## - Dominant normal axis (3 possible voxels/column)

# TODO: Support more type of shapes, currently only BoxShape is supported

# TODO: When determine act1nodes, also store info about triangles overlapping them

# TODO: Bake geometry & save to files
@export_file() var bakedFile: String = ""

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
						if get_child_count() > 0:
							_recalculate_leaf_size()
						notify_property_list_changed()

## This value serves as indication to how small a leaf
## cube is gonna be. Changing it doesn't affect anything
@export var leaf_cube_size: float = 0
func _recalculate_leaf_size():
	leaf_cube_size = _node_size(-2)


func _ready():
	_recalculate_area_origin()
	

# Expensive operation, should call only once
# when all CollisionShapes are registered
func voxelise():
	var act1node_triangles = _determine_act1nodes()
	_svo = SparseVoxelOctree.new(max_depth, act1node_triangles.keys())
	#_voxelise_tree_node1(act1node_triangles)
	#_fill_solid()
	_draw_debug_boxes()


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
		#print("Something got in: %s" % str(body))
		voxelise()
		

func _get_box_faces(col_shape: CollisionShape3D) -> PackedVector3Array:
	var box = BoxMesh.new()
	box.size = col_shape.shape.size
	var arr_mesh = ArrayMesh.new()
	var ma = box.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	
	# Convert triangles to local NavigationSpaceTransform
	var mesh_to_navspace: \
		Transform3D = $Origin.global_transform.inverse() \
					* col_shape.global_transform
	
	var triangles = arr_mesh.get_faces()
	for i in range(0, triangles.size()):
		triangles[i] = mesh_to_navspace * triangles[i]
	
	return triangles


func _on_body_shape_exited(
	body_rid: RID,
	body: PhysicsBody3D,
	body_shape_index: int,
	local_shape_index: int):
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
		if col_shape.shape is BoxShape3D:
			_merge_triangle_overlap_node_dicts(act1node_triangles, 
				_voxelise_polygon(node1_size, _get_box_faces(col_shape)))
	return act1node_triangles


## Return dictionary associating: 
## Morton code of active nodes ~~~ Triangles overlapping it
## @polygon is assumed to have length divisible by 3
## Every 3 elements make up a triangle
func _voxelise_polygon(vox_size: float, polygon_faces: PackedVector3Array) -> Dictionary:
	var result = {}
	for i in range(0, polygon_faces.size()/3):
		_merge_triangle_overlap_node_dicts(result, 
			_voxelise_triangle(vox_size, polygon_faces.slice(i*3, (i+1)*3)))
	return result

## Return a dictionary 
## Key: Morton of active nodes 
## Values: Triangles overlapping it, 
##	serialized into a PackedVector3Array. Every 3 makes a triangle
func _voxelise_triangle(vox_size: float, triangle: PackedVector3Array) -> Dictionary:
	var result = {}
	var tbt = TriangleBoxTest.new(triangle, Vector3(1,1,1) * vox_size)
	var vox_range: Array[Vector3i] = _voxels_overlapped_by_aabb(vox_size, tbt.aabb)
		
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
## @return: [begin, end) (end is exclusive)
##	(end - begin) is non-negative
##	begin and end are inside Navigation Space  
##	Includes also voxels meerly touched by t_aabb
func _voxels_overlapped_by_aabb(size: float, t_aabb: AABB) -> Array[Vector3i]:
	# Begin & End
	var b = t_aabb.position/size
	var e = t_aabb.end/size
	
	#print("b: %s" % str(b))
	#print("e: %s" % str(e))
	
	# Include voxels meerly touched by t_aabb
	b.x = b.x - (1 if b.x == round(b.x) else 0)
	b.y = b.y - (1 if b.y == round(b.y) else 0)
	b.z = b.z - (1 if b.z == round(b.z) else 0)
	
	e.x = e.x + (1 if e.x == round(e.x) else 0)
	e.y = e.y + (1 if e.y == round(e.y) else 0)
	e.z = e.z + (1 if e.z == round(e.z) else 0)
	
	# Because by configuration, all Extent sides are equal
	var vox_bound = $Extent.shape.size
	
	# Clamp to fit inside Navigation Space
	b = b.clamp(Vector3(), vox_bound)
	e = e.clamp(Vector3(), vox_bound)
	
	return [b.floor(), e.ceil()]


## Allocate each node1 with 1 thread
## For each thread, sequentially test overlap each triangle with
## each of 8 node0 child
## For each node0 child overlapped by triangle, launch a thread to 
## test overlap for subgrid
## Join all subgrid tests before starting with the next triangle
func _voxelise_tree_node1(act1node_triangles: Dictionary):
	var a1t_keys = act1node_triangles.keys()
	var threads: Array[Thread] = []
	threads.resize(a1t_keys.size())
	threads.resize(0)
	
	for key in a1t_keys:
		threads.push_back(Thread.new())
		threads.back().start(_voxelise_tree_node0.bind(key, act1node_triangles[key]))
		
	for t in threads:
		t.wait_to_finish()


## Sequentially test overlap each triangle with
## each of 8 node0 child
## For each node0 child overlapped by triangle, launch a thread to 
## test overlap for subgrid
## Join all subgrid tests before starting with the next triangle
func _voxelise_tree_node0(node1_morton: int, triangles: PackedVector3Array):
	for i in range(triangles.size()/3):
		var triangle = triangles.slice(i, (i+1)*3)
		
		var tbt = TriangleBoxTest.new(triangle, Vector3(1,1,1) * _node_size(0))
		var dm = Morton3.decode64(node1_morton)
		#var node1_start_pos = - _extent_origin Vector3(Morton3.x(dm), Morton3.y(dm), Morton3.z(dm)) 
	pass
	
	
#func _voxelise_polygon_subgrid(polygon_faces: PackedVector3Array):
#	for i in range(0, polygon_faces.size()/3):
#		_voxelise_triangle_subgrid(polygon_faces.slice(i, (i+1)*3))
	
	
func _fill_solid():
	pass


############## DEBUGS #######################

func _draw_debug_boxes():
	for cube in $Origin/DebugCubes.get_children():
		cube.queue_free()
	var _leaf_cube_size = _node_size(-2)
	$CubeTemplate.mesh.size = Vector3(1,1,1)*_leaf_cube_size*0.5
	var node0_size = _node_size(0)
	for node0 in _svo._nodes[0]:
			
		node0 = node0 as SparseVoxelOctree.SVONode
		
		#print("Node:\t%s\nSolid:\t%s" % 
		#	[Morton.int_to_bin(node0.morton, 64, false), 
		#	Morton.int_to_bin(node0.first_child, 64, false)])
			
		var d = Morton3.decode64(node0.morton)
		var node_pos = node0_size \
						* Vector3(Morton3.x(d),
								Morton3.y(d), 
								Morton3.z(d))
		for i in range(64):
			if node0.first_child & (1<<i):
				var di = Morton3.decode64(i) 
				var offset = _leaf_cube_size * Vector3(Morton3.x(di), Morton3.y(di), Morton3.z(di))
				var pos = node_pos + offset - Vector3(1,1,1)/2*_leaf_cube_size
				var cube = $CubeTemplate.duplicate()
				cube.visible = true
				$Origin/DebugCubes.add_child(cube)
				cube.position = pos
				

## Merge information of triangles overlapping a node, from @append to @base
## Both @base and @append are dictionarys with Keys: SVONode's Morton code,
## Values: PackedVector3Array of Vertices. Every 3 elements make a triangle
## Return: @base will contain all informations from append. Duplicates are 
## possible, if @append appears more than once 
func _merge_triangle_overlap_node_dicts(base: Dictionary, append: Dictionary):
	for key in append.keys():
		if base.has(key):
			base[key] = base[key] + append[key]
		else:
			base[key] = append[key]
	# Since @base is already a reference, no need to return anything here


############## CONFIG WARNINGS ##############

func _get_configuration_warnings():
	var warnings: PackedStringArray = []
	if not $Extent.shape is BoxShape3D:
		warnings.push_back("Extent must be BoxShape3D.")
	if max_depth >= TreeAttribute.DANGEROUS_MAX_DEPTH:
		warnings.push_back("Can your machine really handle a voxel tree this deep and big?")
	var s = $Extent.shape.size
	if s.x != s.y or s.y != s.z:
		warnings.push_back("Extent's side lengths must be equal. Make Extent a cube.")
	return warnings


func _on_property_list_changed():
	update_configuration_warnings()

##############


var _entered_shapes: Array[CollisionShape3D] = []

func _node_size(layer: int) -> float:
	return $Extent.shape.size.x / 2**(max_depth - layer - 3)
	


enum TreeAttribute{
	LEAF_LAYERS = 2,
	MIN_DEPTH = 4,
	DANGEROUS_MAX_DEPTH = 11,
	MAX_DEPTH = 14,
}

var _svo: SparseVoxelOctree

func _recalculate_area_origin():
	$Origin.position = - $Extent.shape.size/2
	
func _on_extent_property_list_changed():
	print("Extent changed")
	_recalculate_area_origin()
	_recalculate_leaf_size()
