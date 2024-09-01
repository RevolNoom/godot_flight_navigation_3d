## A node in Sparse Voxel Octree.[br]
##
## An SVONode contains information about position in space, neighbors,
## parent, children, and subgrid voxels solid state, with some helper methods.[br]
extends Object
class_name SVONode

enum Subgrid{
	## No voxel is solid
	EMPTY = 0,
	## All voxels are solid
	SOLID = ~0,
}

## The faces of an SVONode
enum Face
{
	## Face on negative-x direction
	X_NEG, #x-1
	## Face on positive-x direction
	X_POS, #x+1
	## Face on negative-y direction
	Y_NEG, #y-1
	## Face on positive-y direction
	Y_POS, #y+1
	## Face on negative-z direction
	Z_NEG, #z-1
	## Face on positive-z direction
	Z_POS, #z+1
}

## Morton3 index of this node. Defines where it is in space[br]
var morton: int

## SVOLink of parent node.[br]
var parent: int 

## For layer-0 node, [member SVONode.first_child] [b]IS[b] [member SVONode.subgrid].[br]
##
## For layer i > 0, [member SVO.layers][i-1][[member SVONode.first_child]] is [SVOLink] to its first child in [class SVO],
## [member SVO.layers][layer-1][[member SVONode.first_child]+1] is 2nd... upto +7 (8th child).[br]
var first_child: int 

## [b]NOTE: FOR LAYER-0 NODES ONLY[/b][br]
## Alias for [member first_child], each bit corresponds to solid state of a voxel.[br]
var subgrid: int:
	get:
		return first_child
	set(value):
		first_child = value

var xn: int ## SVOLink to neighbor on negative x direction.[br]
var xp: int ## SVOLink to neighbor on positive y direction.[br]
var yn: int ## SVOLink to neighbor on negative z direction.[br]
var yp: int ## SVOLink to neighbor on positive x direction.[br]
var zn: int ## SVOLink to neighbor on negative y direction.[br]
var zp: int ## SVOLink to neighbor on positive z direction.[br]

func _init():
	morton = SVOLink.NULL
	parent = SVOLink.NULL
	first_child = SVOLink.NULL
	xn = SVOLink.NULL
	xp = SVOLink.NULL
	yn = SVOLink.NULL
	yp = SVOLink.NULL
	zn = SVOLink.NULL
	zp = SVOLink.NULL

## Return an SVOLink to the neighbor on this node's [param face].[br]
func neighbor(face: Face) -> int:
	match face:
		Face.X_NEG:
			return xn
		Face.X_POS:
			return xp
		Face.Y_NEG:
			return yn
		Face.Y_POS:
			return yp
		Face.Z_NEG:
			return zn
		_: #Face.Z_POS:
			return zp

## [b]NOTE:[/b] For layer-0 nodes only.[br]
##
## Return true if subgrid voxel at [param subgrid_index] is solid.[br]
##
## [param subgrid_index]: bit position 0-63 (inclusive), corresponds to [method SVOLink.subgrid]
func is_solid(subgrid_index: int) -> bool:
	return subgrid & (1 << subgrid_index)

## [b]NOTE:[/b] NOT for layer-0 nodes.[br]
## Return true if this node has no children.[br]
func has_no_child() -> bool:
	return first_child == SVOLink.NULL
