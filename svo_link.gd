class_name SVOLink
## A SVOLink is an int64 with the following layout:
##
## Layer | Offset | Subgrid
## ====|======================================================|====== 
## 4   |						54							  |  6	 bits
## 
## Layer: Which layer this node is in SVO
## Offset: Which index in the layer array of SVO this node is 
## Subgrid: Morton code of the subgrid voxel of the layer-0 node that this link is pointing to. 

## Null SVOLink that doesn't point to any node/voxel
const NULL: int = ~0

## WARNING: Not checking valid values 
static func from(svo_layer: int, array_offset: int, subgrid_idx: int = 0) -> int:
	return (svo_layer << 60) | (array_offset << 6) | subgrid_idx 

## 4 leftmost bits
static func layer(link: int) -> int:
	return link >> 60

## The rest
static func offset(link: int) -> int:
	return (link << 4) >> 10

## 6 rightmost bits
static func subgrid(link: int) -> int:
	return link & 0x3F

## WARNING: Not checking for over 4-bit values
static func set_layer(new_layer: int, link: int) -> int:
	return (link & 0xFFF_FFFF_FFFF_FFFF) | (new_layer << 60)

## WARNING: Not checking for over 54-bit values
static func set_offset(new_offset: int, link: int) -> int:
	return (link & ~0x0FFF_FFFF_FFFF_FFC0) | (new_offset << 6)

## WARNING: Not checking for over 6-bit values
static func set_subgrid(new_subgrid: int, link: int) -> int:
	return (link & ~0b111111) | new_subgrid

## Return true if they have same "layer" field values
static func same_layer(link1: int, link2: int) -> bool: 
	return not ((link1^link2) >> 60)
	
## Return true if they have different "layer" field values
static func not_same_layer(link1: int, link2: int) -> bool: 
	return (link1^link2) >> 60
	
## Format: Layer MortonCode Subgrid
static func get_format_string(svolink: int, svo: SVO) -> String:
	#return "%d %s %s" % [
		#SVOLink.layer(svolink),
			#Morton3.decode_vec3i(svo.node_from_link(svolink).morton), 
			#Morton3.decode_vec3i(SVOLink.subgrid(svolink))]
	# This version appends the value of the link at the end
	# This function is used for debug anyway, so I modify it to my needs 
	return "%d %s %s\n%d" % [
		SVOLink.layer(svolink),
			Morton3.decode_vec3i(svo.node_from_link(svolink).morton), 
			Morton3.decode_vec3i(SVOLink.subgrid(svolink)), 
			svolink]
	
