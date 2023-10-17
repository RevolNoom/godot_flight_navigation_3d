# Voxelize StaticBodies in the specified area 
@tool
extends Area3D
class_name NavigationSpace3D

# TODO:
# Process the shapes based on their types
# Prioritize Box shape voxelization first

## TODO: Bake geometry & save to files
@export_file() var bakedFile: String = ""

## Deeper tree rasterizes collision shapes in more details,
## but also consumes more memory. Each layer added means
## about roughly 8 times more memory consumption.
## Only supports upto 15 layers. 
## I reckon your computer can't handle more than that
@export_range(5, 15) var max_depth: int = 7:
	set(value):
		max_depth = clampi(value, 5, 15)
		notify_property_list_changed()

## Omits a few top layers when building the octree
## 1 omits the root node.
## 2 omits the root node and first layer,
## and so on... 
## Note: The tree must have at least 4 active layers
@export_range(1, 11) var omitted_top_layers: int = 2:
	set(value):
		omitted_top_layers = clampi(value, 1, 11)
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
	_construct_octree(act_node1)
	_voxelise()
	_fill_solid()



############################3

func _on_body_shape_entered(
	body_rid: RID,
	body: PhysicsBody3D,
	body_shape_index: int,
	local_shape_index: int):
		if not body is StaticBody3D:
			return
		
		var shape: Shape3D = body.shape_owner_get_owner(
			shape_find_owner(body_shape_index)).shape
		
		_entered_shapes.append(shape)


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
	return []

func _construct_octree(active_level1_nodes: PackedInt64Array):
	pass
	
func _voxelise():
	pass

func _fill_solid():
	pass

############## CONFIG WARNINGS ##############

func _get_configuration_warnings():
	var warnings: PackedStringArray = []
	if not $Extent.shape is BoxShape3D:
		warnings.push_back("Extent must be BoxShape3D.")
	if omitted_top_layers > max_depth - 4:
		warnings.push_back("shallowestLayer must be at least 2 layers less than maxDepth.")
	if max_depth >= DANGEROUS_MAX_DEPTH:
		warnings.push_back("Are you sure your machine can handle a voxel tree this deep and big?")
	return warnings


func _on_property_list_changed():
	update_configuration_warnings()

##############

var _entered_shapes: Array[CollisionShape3D] = []

## Each leaf is a 4x4x4 compound of voxels
## They make up 2 bottom-most layers of the tree
var _leaves: PackedInt64Array = []

## Since _leaves make up 2 bottom-most layers,
## _nodes[0] is the 3rd layer of the tree, 
## _nodes[1] is 4th,... and so on
## However, I'll refer to _nodes[0] as "layer 0"
## and _leaf as "leaves layer", for consistency with
## the research paper
var _nodes: Array = []

const DANGEROUS_MAX_DEPTH = 11
