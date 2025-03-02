## An iterator to help traverse and modify an SVO.
extends RefCounted
class_name SVOIterator

## Morton3 index of this node.[br]
## The most significant (leftmost) bit tells whether this node is solid.[br]
## The remaining 63 bits defines voxel position.[br]
var morton: int:
	get():
		return field(DataField.MORTON)
	set(value):
		set_field(DataField.MORTON, value)
		
## SVOLink to Parent node.[br]
var parent: int:
	get():
		return field(DataField.PARENT)
	set(value):
		set_field(DataField.PARENT, value)

var first_child: int:
	get():
		return field(DataField.FIRST_CHILD)
	set(value):
		set_field(DataField.FIRST_CHILD, value)

## Each bit corresponds to solid state of a leaf voxel.[br]
## [b]WARNING: FOR LAYER-0 NODES ONLY.[/b]
## Reading this value from a non-layer-0 node will return first_child instead.[br]
var rubik: int:
	get:
		return field(DataField.RUBIK)
	set(value):
		set_field(DataField.RUBIK, value)

## Neighbor on negative x direction.
var xn: int:
	get():
		return field(DataField.NEIGHBOR_X_NEGATIVE)
	set(value):
		set_field(DataField.NEIGHBOR_X_NEGATIVE, value)
		
## Neighbor on positive x direction.
var xp: int:
	get():
		return field(DataField.NEIGHBOR_X_POSITIVE)
	set(value):
		set_field(DataField.NEIGHBOR_X_POSITIVE, value)
		
## Neighbor on negative y direction.
var yn: int:
	get():
		return field(DataField.NEIGHBOR_Y_NEGATIVE)
	set(value):
		set_field(DataField.NEIGHBOR_Y_NEGATIVE, value)
		
## Neighbor on positive y direction.
var yp: int:
	get():
		return field(DataField.NEIGHBOR_Y_POSITIVE)
	set(value):
		set_field(DataField.NEIGHBOR_Y_POSITIVE, value)
		
## Neighbor on negative z direction.
var zn: int:
	get():
		return field(DataField.NEIGHBOR_Z_NEGATIVE)
	set(value):
		set_field(DataField.NEIGHBOR_Z_NEGATIVE, value)
		
## Neighbor on positive z direction.
var zp: int:
	get():
		return field(DataField.NEIGHBOR_Z_POSITIVE)
	set(value):
		set_field(DataField.NEIGHBOR_Z_POSITIVE, value)

var layer: int:
	get():
		return SVOLink.layer(svolink)

var offset: int:
	get():
		return SVOLink.offset(svolink)

var subgrid: int:
	get():
		return SVOLink.subgrid(svolink)
		
## The SVOLink that identify this node/voxel.[br]
var svolink: int
## For layer-0 node, [member SVONode.first_child] [b]IS[b] [member SVONode.subgrid].[br]
##
## For layer i > 0, [member SVO.layers][i-1][[member SVONode.first_child]] is [SVOLink] to its first child in [class SVO],
## [member SVO.layers][layer-1][[member SVONode.first_child]+1] is 2nd... upto +7 (8th child).[br]
## TODO: Handle leaf and node casses
func get_child(index: int) -> int:
	var child = field(DataField.FIRST_CHILD)
	if layer == 0 or child == SVOLink.NULL:
		return SVOLink.NULL
	return child + index

func get_children() -> PackedInt64Array:
	if layer == 0 or first_child == SVOLink.NULL:
		return []
	return [
		first_child + 0,
		first_child + 1,
		first_child + 2,
		first_child + 3,
		first_child + 4,
		first_child + 5,
		first_child + 6,
		first_child + 7,
	]

## [b]NOTE:[/b] NOT for layer-0 nodes.[br]
## Return true if this node is one of the following:[br]
## - A leaf voxel.[br]
## - An empty node layer 0.[br]
## - A node in layer 1+ that has no children.[br]
func has_no_child() -> bool:
	return field(DataField.FIRST_CHILD) == SVOLink.NULL

# Return true if this iterator points to a SVO node that 
# has the same parent as that of [param it].[br]
# Technically, same parent means all morton bits except the solid
# and 3 least significant bits are equal.[br]
func same_parent(it: SVOIteratorRandom) -> bool:
	return (morton ^ it.morton) & 0x7FFF_FFFF_FFFF_FFFC == 0
	 
## Private. Reference to SVO internal data structure.[br]
## You should not read or edit SVO through this reference.[br]
var _svo_data: Array

## Offset of data fields from the pointer
enum DataField
{
	MORTON = 0,
	PARENT = 1,
	FIRST_CHILD = 2,
	RUBIK = FIRST_CHILD,
	NEIGHBOR_X_NEGATIVE = 3,
	NEIGHBOR_X_POSITIVE = 4,
	NEIGHBOR_Y_NEGATIVE = 5,
	NEIGHBOR_Y_POSITIVE = 6,
	NEIGHBOR_Z_NEGATIVE = 7,
	NEIGHBOR_Z_POSITIVE = 8,
	MAX_FIELD, # All iterator fields
}

static var Neighbors: Array[DataField] = [
	DataField.NEIGHBOR_X_NEGATIVE,
	DataField.NEIGHBOR_X_POSITIVE,
	DataField.NEIGHBOR_Y_NEGATIVE,
	DataField.NEIGHBOR_Y_POSITIVE,
	DataField.NEIGHBOR_Z_NEGATIVE,
	DataField.NEIGHBOR_Z_POSITIVE,
]

enum Subgrid{
	## No voxel is solid
	EMPTY = 0,
	## All voxels are solid
	SOLID = ~0,
}

## Return an SVOLink to the neighbor on this node's [param face].[br]
func field(df: DataField) -> int:
	return _svo_data[layer][offset*DataField.MAX_FIELD + df]
	
func set_field(df: DataField, value: int) -> void:
	_svo_data[layer][offset*DataField.MAX_FIELD + df] = value

## Return true if this voxel is solid.[br]
func is_solid() -> bool:
	return rubik & (1 << subgrid) # || (morton & 1 << 63)

## Return true if [param svolink] refers to a subgrid voxel.[br]
## An svolink points to a subgrid voxel when it points to layer 0 and that node
## has at least one solid voxel.
func is_subgrid_voxel() -> bool:
	return layer == 0 and rubik != SVONode.Subgrid.EMPTY

func get_debug_dict() -> Dictionary:
	return {
		"svolink": SVOLink.get_format_string(svolink),
		"morton": Morton.int_to_bin(morton),
		"parent": SVOLink.get_format_string(parent),
		"first_child": SVOLink.get_format_string(first_child),
		"rubik": SVOLink.get_format_string(rubik),
		"xn": SVOLink.get_format_string(xn),
		"xp": SVOLink.get_format_string(xp),
		"yn": SVOLink.get_format_string(yn),
		"yp": SVOLink.get_format_string(yp),
		"zn": SVOLink.get_format_string(zn),
		"zp": SVOLink.get_format_string(zp),
	}
