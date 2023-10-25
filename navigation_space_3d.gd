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
							_calculate_node0_size()
						notify_property_list_changed()

## This value serves as indication to how small a leaf
## cube is gonna be. Changing it doesn't affect anything
@export var leaf_cube_size: float = 0:
	get:
		return _leaf_cube_size 


func _ready():
	_calculate_node0_size()
	

# Expensive operation, should call only once
# when all CollisionShapes are registered
func voxelise():
	var act1nodes = _determine_act1nodes()
	_svo = SparseVoxelOctree.new(max_depth, act1nodes)
	_voxelise_leaf_layer()
	_fill_solid()


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
		Transform3D = global_transform.inverse() \
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

func _determine_act1nodes() -> PackedInt64Array:
	var act1nodes: Dictionary = {}
	for col_shape in _entered_shapes:
		if col_shape.shape is BoxShape3D:
			act1nodes.merge(_voxelise_polygon_layer1(_get_box_faces(col_shape)))
	return act1nodes.keys()


## @polygon is assumed to have length divisible by 3
## Every 3 elements make up a triangle
func _voxelise_polygon_layer1(polygon_faces: PackedVector3Array) -> Dictionary:
	var result = {}
	for i in range(0, polygon_faces.size()/3):
		result.merge(_voxelise_triangle_layer1(polygon_faces.slice(i*3, (i+1)*3)))
	return result


## Return a dictionary with keys are Morton codes of active nodes
func _voxelise_triangle_layer1(triangle: PackedVector3Array) -> Dictionary:
	var result = {}
	var vox_origin = _extent_origin / _node1_size
	var tbt = TriangleBoxTest.new(triangle, Vector3(1,1,1) * _node1_size)
	var vox_range: Array[Vector3i] = _voxels_overlapped_by_aabb(_node1_size, tbt.aabb)
		
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				if tbt.overlap_voxel(Vector3(x, y, z) * _node0_size):
					result[Morton3.encode64(
						x - vox_origin.x, 
						y - vox_origin.y,
						z - vox_origin.z)] = true
	return result


## Voxelize directly into the subgrids of the tree
func _voxelise_triangle_subgrid(triangle: PackedVector3Array):
	var tbt = TriangleBoxTest.new(triangle, Vector3(1,1,1) * _leaf_cube_size)
	var vox_range: Array[Vector3i] = _voxels_overlapped_by_aabb(_leaf_cube_size, tbt.aabb)
	
	
	# TODO: Probably the problem is here. Don't subtract it before overlap testing
	var vox_origin = _extent_origin / _leaf_cube_size
	vox_range[0] -= Vector3i(vox_origin)
	vox_range[1] -= Vector3i(vox_origin)
	## vox_range is morton code into subgrid 
	## As such, we can derive subgrid's layer-0 bounding box through it
	## Each vox_range[0] component must be floor()ed, and vox_range[1] ceil()ed
	## because we want to expand layer-0 BB to contain all voxels of subgrid's BB
	## But integer division already helps vox_range[0] with that, so we only
	## need to ceil()
	vox_range[0] = vox_range[0] / 4 
	vox_range[1] = Vector3i(
			ceil(vox_range[1].x/4.0), 
			ceil(vox_range[1].y/4.0),
			ceil(vox_range[1].z/4.0))
	
	## Get the node0 at the "position" corner of the BB as the start point
	## for the overlap-test loops 
	var node0start:= _svo.node(0, Morton3.encode64(
			vox_range[0].x, vox_range[0].y, vox_range[0].z))
	
	## Loop through each node0 in the BB
	for x in range(vox_range[0].x, vox_range[1].x):
		var n0y = node0start.duplicate()
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				pass
	


func _noob_tri_vox_overlap_test(
		vox_range: Array[Vector3i], 
		triangle: PackedVector3Array):
	pass


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
	
	var vox_bound = - _extent_origin / size 
	
	# Clamp to fit inside Navigation Space
	b = b.clamp(-vox_bound, vox_bound)
	e = e.clamp(-vox_bound, vox_bound)
	
	return [b.floor(), e.ceil()]


func _voxelise_leaf_layer():
	for col_shape in _entered_shapes:
		if col_shape.shape is BoxShape3D:
			_voxelise_polygon_subgrid(_get_box_faces(col_shape))
	
func _voxelise_polygon_subgrid(polygon_faces: PackedVector3Array):
	for i in range(0, polygon_faces.size()/3):
		_voxelise_triangle_subgrid(polygon_faces.slice(i, (i+1)*3))
	
func _fill_solid():
	pass


############## CONFIG WARNINGS ##############

func _get_configuration_warnings():
	var warnings: PackedStringArray = []
	if not $Extent.shape is BoxShape3D:
		warnings.push_back("Extent must be BoxShape3D.")
	if max_depth >= TreeAttribute.DANGEROUS_MAX_DEPTH:
		warnings.push_back("Can your machine really handle a voxel tree this deep and big?")
	return warnings


func _on_property_list_changed():
	update_configuration_warnings()

##############


var _entered_shapes: Array[CollisionShape3D] = []

var _node1_size: float = 1
var _node0_size: float = 1
var _leaf_cube_size: float = 1

func _calculate_node0_size():
	var size = $Extent.shape.size
	var max_extent = maxf(maxf(size.x, size.y), size.z)
	_leaf_cube_size = max_extent / 2**(max_depth - 1)
	_node0_size = _leaf_cube_size * 4
	_node1_size = _node1_size * 2


enum TreeAttribute{
	LEAF_LAYERS = 2,
	MIN_DEPTH = 4,
	DANGEROUS_MAX_DEPTH = 11,
	MAX_DEPTH = 14,
}

var _svo: SparseVoxelOctree

@onready var _extent_origin: Vector3 = - $Extent.shape.size/2
func _on_extent_property_list_changed():
	_extent_origin = - $Extent.shape.size/2
