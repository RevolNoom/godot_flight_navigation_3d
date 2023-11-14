class_name SVOPathNode
## This class packs the information of a node on a path travelling svo space
## into an int64: 4 layer bits - 54 morton-code positional bits - 6 subgrid bits

## WARNING: Not checking valid value for performance 
static func from(svo_layer: int, position: Vector3i, subgrid_idx: int = 0) -> int:
	return (svo_layer << 60) | (Morton3.encode64v(position) << 6) | subgrid_idx 

## 4 leftmost bits
static func layer(pathnode: int) -> int:
	return pathnode >> 60

## 6 rightmost bits
static func subgrid(pathnode: int) -> int:
	return pathnode & 0x3F

## The rest
static func offset(pathnode: int) -> int:
	return (pathnode << 4) >> 10

# @return true if they have different layer field values
static func in_diff_layers(pathnode1: int, pathnode2: int) -> bool: 
	return (pathnode1^pathnode2) & 0x0FFF_FFFF_FFFF_FFFF
