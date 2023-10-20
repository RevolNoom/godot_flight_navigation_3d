# Voxelize StaticBodies in the specified area
# "monitoring" and "monitorable" must be kept on to detect StaticBody3D
@tool
extends Area3D
class_name NavigationSpace3D


func _ready():
	pass

# TODO:
# Process the shapes based on their types
# Prioritize Box shape voxelization first

## TODO: Bake geometry & save to files
@export_file() var bakedFile: String = ""

## Higher depth rasterizes collision shapes in more details,
## but also consumes more memory. Each layer adds roughly 8 
## times more memory consumption. Only supports 
## upto TreeAttribute.MAX_DEPTH layers. I reckon your computer
## can't handle more than that.
@export_range(1 + TreeAttribute.MIN_ACTIVE_LAYER, TreeAttribute.MAX_DEPTH) var max_depth: int = 7:
	set(value):
		max_depth = clampi(value, 1 + TreeAttribute.MIN_ACTIVE_LAYER, TreeAttribute.MAX_DEPTH)
		calculate_every_layer_cube_size()
		notify_property_list_changed()

## Omits a few top layers when building the octree
## 1 omits the root node.
## 2 omits the root node and first layer,
## and so on... 
## Note: The tree must have at least 4 active layers
@export_range(1, TreeAttribute.MAX_DEPTH - TreeAttribute.MIN_ACTIVE_LAYER) var omitted_top_layers: int = 2:
	set(value):
		omitted_top_layers = clampi(value, 1, TreeAttribute.MAX_DEPTH - TreeAttribute.MIN_ACTIVE_LAYER)
		notify_property_list_changed()

## The tree will try to voxelise the deepest layer
## into cubes of size not greater than this
@export var maxLeafCubeSize: float = 0.01:
	set(value):
		maxLeafCubeSize = value
		var s = ($Extent.shape as BoxShape3D).size
		var longestSize = maxf(maxf(s.x, s.y), s.z)
		max_depth = ceili(log(longestSize/value)/log(2))
		
		notify_property_list_changed()



# TODO: This is assuming that objects are BoxShape3D
# Expensive operation
# Should call only once when all CollisionShapes are
# registered
func voxelise():
	var act_node1 = _determine_active_level1_nodes()
	_construct_layers(act_node1)
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
		
		voxelise()

func _get_box_triangles(col_shape: CollisionShape3D) -> PackedVector3Array:
	var box = BoxMesh.new()
	box.size = col_shape.shape.size
	var arr_mesh = ArrayMesh.new()
	var ma = box.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	
	# Convert triangles to local NavigationSpaceTransform
	var mesh_to_navspace: \
		Transform3D = global_transform \
					* col_shape.global_transform.inverse()
	
	var triangles = arr_mesh.get_faces()
	#print("Triangle before: " + str(triangles))
	for i in range(0, triangles.size()):
		triangles[i] = mesh_to_navspace * triangles[i]
	#print("Triangle after: " + str(triangles))
	
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

func _determine_active_level1_nodes() -> PackedInt64Array:
	var act1nodes: Dictionary = {}
	for col_shape in _entered_shapes:
		if col_shape.shape is BoxShape3D:
			act1nodes.merge(_surface_voxelise(1, _get_box_triangles(col_shape)))
	return act1nodes.keys()


## @triangles are assumed to have length divisible by 3
## Every 3 elements make up a triangle
func _surface_voxelise(layer: int, triangles: PackedVector3Array) -> Dictionary:
	var result = {}
	for i in range(0, triangles.size()/3):
		result.merge(_voxelise_triangle(layer, triangles.slice(i*3, (i+1)*3)))
	return result


func _voxelise_triangle(layer: int, triangle: PackedVector3Array) -> Dictionary:
	var tbt = TriangleBoxTest.new(triangle, _node_cube_size[layer])
	var vox_range = _voxels_overlapped_by_aabb(layer, tbt.aabb)
	# TODO: TEST TRIANGLE/VOXEL OVERLAP
	return {}


## TODO: 
func _voxelise_triangle_into_tree(layer: int, triangle: PackedVector3Array):
	pass



	
## Simply tests all voxels in range
## No specialization for these cases:
## - One-voxel thick bounding box
## - Dominant normal axis (3 possible voxels/column)
func _noob_tri_vox_overlap_test(
		vox_range: Array[Vector3i], 
		triangle: PackedVector3Array):
	pass


## @layer: The tree layer we're trying to get voxels from
## @t_aabb: Triangle's AABB
## @return: [begin, end]
##	(end - begin) is non-negative
##	begin and end are inside Navigation Space  
##	Includes also voxels meerly touched by t_aabb
func _voxels_overlapped_by_aabb(layer: int, t_aabb: AABB) -> Array[Vector3i]:
	# Begin & End
	var b = t_aabb.position/_node_cube_size[layer]
	var e = t_aabb.end/_node_cube_size[layer]
	
	# Include voxels meerly touched by t_aabb
	b.x = b.x - (1 if b.x == round(b.x) else 0)
	b.y = b.y - (1 if b.y == round(b.y) else 0)
	b.z = b.z - (1 if b.z == round(b.z) else 0)
	
	e.x = e.x + (1 if e.x == round(e.x) else 0)
	e.y = e.y + (1 if e.y == round(e.y) else 0)
	e.z = e.z + (1 if e.z == round(e.z) else 0)
	
	# Clamp to fit inside Navigation Space
	b = b.clamp(Vector3(), $Extent.shape.size)
	e = e.clamp(Vector3(), $Extent.shape.size)
	
	return [b.round(), e.round()]
	


func _construct_layers(active_level1_nodes: PackedInt64Array):
	pass
	
func _voxelise(layer: int, faces: PackedVector3Array):
	pass

func _voxelise_leaf_layer():
	pass
	
func _fill_solid():
	pass


############## CONFIG WARNINGS ##############

func _get_configuration_warnings():
	var warnings: PackedStringArray = []
	if not $Extent.shape is BoxShape3D:
		warnings.push_back("Extent must be BoxShape3D.")
	if omitted_top_layers > max_depth - TreeAttribute.MIN_ACTIVE_LAYER:
		warnings.push_back(
				"Too many top layers omitted. Must spare at least " + str(TreeAttribute.MIN_ACTIVE_LAYER) + " layers for the tree (max_depth - omitted_top_layers >= " + str(TreeAttribute.LEAF_LAYERS) + ").")
	if max_depth >= TreeAttribute.DANGEROUS_MAX_DEPTH:
		warnings.push_back("Are you sure your machine can handle a voxel tree this deep and big?")
	return warnings


func _on_property_list_changed():
	update_configuration_warnings()

##############

var _entered_shapes: Array[CollisionShape3D] = []

var _node_cube_size: PackedFloat32Array = []
var _leaf_cube_size: float = 1
func calculate_every_layer_cube_size():
	var node_layers: int = max_depth - TreeAttribute.LEAF_LAYERS - omitted_top_layers
	_node_cube_size.resize(node_layers)
	var s = $Extent.shape.size
	var max_extent = maxf(maxf(s.x, s.y), s.z)
	for i in range(0, node_layers):
		_node_cube_size[i] = max_extent / 2**(max_depth - i - TreeAttribute.LEAF_LAYERS - 1)
	_leaf_cube_size = _node_cube_size[0]/4

enum TreeAttribute{
	LEAF_LAYERS = 2,
	MIN_ACTIVE_LAYER = 3,
	DANGEROUS_MAX_DEPTH = 11,
	MAX_DEPTH = 18,
}
