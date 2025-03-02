## Identifier to an [SVO.SVONode] in [SVO]
##
## An SVOLink is an int64. This class provides methods to manipulate an int64
## as SVOLink to save memory (as Godot by design extends classes from Object, which
## consumes more memory). SVOLink has the following layout:[br]
## [br]
## [method layer] - 4 most significant bits: Which layer this node is in[br]
## [method offset] - 54 middle bits: Which index in the layer array this node is [br]
## [method subgrid] - 6 least significant bits: Morton code of the subgrid voxel of the layer-0 node that this link points to.[br]
class_name SVOLink

## Null SVOLink that doesn't point to any node/voxel
const NULL: int = ~0
const SUBGRID_MASK: int = 0x3F
const OFFSET_MASK: int = 0xFFFF_FFFF_FFFF_C0
const LAYER_MASK: int = ~(SUBGRID_MASK | OFFSET_MASK)


## Create a new SVOLink[br]
##
## [b]Warning:[/b] This function will truncate parameters' values if they fall
## out of permitted field range.
static func from(svo_layer: int, array_offset: int, subgrid_idx: int = 0) -> int:
	return (svo_layer << 60)\
			| ((array_offset << 6) & OFFSET_MASK)\
			| (subgrid_idx & SUBGRID_MASK)


## Return the layer this node is in
static func layer(link: int) -> int:
	return link >> 60


## Return the index in the [SVO]'s layer array this node is
static func offset(link: int) -> int:
	return (link << 4) >> 10


## Return the morton code of the subgrid voxel
static func subgrid(link: int) -> int:
	return link & SUBGRID_MASK


## Return a copy of [SVOLink] with the layer value of [param link] set as [param new_layer][br]
##
## [b]Warning:[/b] This function will truncate [param link] bits >= 2^4 
static func set_layer(new_layer: int, link: int) -> int:
	return (link & ~LAYER_MASK) | (new_layer << 60)

## Return a copy of [SVOLink] with the offset value of [param link] set as [param new_offset][br]
##
## [b]Warning:[/b] This function will truncate [param new_offset] bits >= 2^54 
static func set_offset(new_offset: int, link: int) -> int:
	return (link & ~OFFSET_MASK) | ((new_offset << 6) & OFFSET_MASK)


## Return a copy of [SVOLink] with the subgrid value of [param link] set as [param new_subgrid][br]
##
## [b]Warning:[/b] This function will truncate [param new_subgrid] bits >= 2^6
static func set_subgrid(new_subgrid: int, link: int) -> int:
	return (link & ~SUBGRID_MASK) | (new_subgrid & SUBGRID_MASK)


## Return true if [param link1] have same [method layer] field as [param link2] values
static func same_layer(link1: int, link2: int) -> bool: 
	return not not_same_layer(link1, link2)


## Return true if [param link1] have different [method layer] field as [param link2] values
static func not_same_layer(link1: int, link2: int) -> bool: 
	return (link1^link2) & LAYER_MASK


## This is a debug function. Don't mind it.[br]
## Format: Layer MortonCode Subgrid
static func get_format_string(svolink: int) -> String:
	#return "%d %s %s" % [
		#SVOLink.layer(svolink),
			#Morton3.decode_vec3i(svo.node_from_link(svolink).morton), 
			#Morton3.decode_vec3i(SVOLink.subgrid(svolink))]
	# This version appends the value of the link at the end
	# This function is used for debug anyway, so I modify it to my needs 
	return "Svolink %d\n Layer %d\n offset %s\n subgrid %d\n subgrid vec3 %s\n" % [
		svolink,
		SVOLink.layer(svolink),
		SVOLink.offset(svolink),
		SVOLink.subgrid(svolink),
		Morton3.decode_vec3i(SVOLink.subgrid(svolink))]
	
## This is a debug function. Don't mind it.[br]
static func get_binary_string(svolink: int) -> String:
	var result = ""
	for i in range(63, -1, -1):
		if svolink & (1<<i):
			result += "1"
		else:
			result += "0"
	result = result.insert(58, "|")
	result = result.insert(4, "|")
	return result
