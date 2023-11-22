class_name SVOLink

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
	return (link & ~0x3F) | new_subgrid

# @return true if they have different layer field values
static func in_diff_layers(link1: int, link2: int) -> bool: 
	return (link1^link2) & 0x0FFF_FFFF_FFFF_FFFF


### Convert Game World Position <-> SVO Logical Position

## @extent: The length of one side of the navigation space (assumed to be cube)
## @get_subgrid_center: If true and @svolink is in layer 0,
## return subgrid voxel center instead of node center.
## Note: used to distinguish layer 0 node with subgrid index = 0, 
## and 0-indexed subgrid voxel.
##
## @return: center of the node with @svolink in @svo
static func to_navspace(
		svo: SVO, 
		navspace: NavigationSpace3D, 
		svolink: int, 
		get_subgrid_center: bool = false) -> Vector3:
	var extent = navspace._extent_size
	var layer = SVOLink.layer(svolink)
	var node = svo.node_from_link(svolink)
	if layer == 0 and get_subgrid_center:
		var subgrid_voxel_size = extent / (2 << svo._nodes.size()) # equals 2^(nodes.size()+1)
		var voxel_morton = (node.morton << 6) | SVOLink.offset(svolink)
		return (Morton3.decode_vec3(voxel_morton) + Vector3.ONE*0.5) * subgrid_voxel_size
		
	var node_size = extent / (2 << (svo._nodes.size() - layer - 1))
	return (Morton3.decode_vec3(node.morton) + Vector3.ONE*0.5) * node_size
	
## @extent: The length of one side of the navigation space (assumed to be cube)
##
## @return: SVOLink of the smallest node in @svo that contains @position
## NULL if point doesn't lie inside the navspace 
static func from_navspace(
		svo: SVO, 
		navspace: NavigationSpace3D, 
		position: Vector3) -> int:
	var extent = navspace._extent_size.x
	var aabb := AABB(Vector3.ZERO, Vector3.ONE*extent)
	
	# Points outside Navigation Space
	if not aabb.has_point(position):
		print("Position: %v -> null" % position)
		return SVOLink.NULL
		
	var layer := svo._nodes.size()-1
	var offset:= 0
	
	# Descend the tree layer by layer
	while layer > 0:
		var this_node_link = SVOLink.from(layer, offset, 0)
		var this_node = svo.node_from_link(this_node_link)
		if this_node.first_child == SVOLink.NULL:
			navspace.draw_svolink_box(this_node_link)
			#print("Position: %v -> %s" % [position, Morton3.int_to_bin(this_node_link)])
			return this_node_link

		offset = this_node.first_child
		layer -= 1
		
		var aabb_center = aabb.position + aabb.size/2
		var new_pos := aabb.position
		if position.x >= aabb_center.x:
			offset |= 0b001
			new_pos.x = aabb_center.x
		if position.y >= aabb_center.y:
			offset |= 0b010
			new_pos.y = aabb_center.y
		if position.z >= aabb_center.z:
			offset |= 0b100
			new_pos.z = aabb_center.z
		aabb = AABB(new_pos, aabb.size/2)
	
	# If code reaches here, it means we have descended down to layer 0 already
	# Look for the subgrid voxel that encloses @position
	var subdivides = [aabb.size.x*0.25,
					aabb.size.x*0.5, 
					aabb.size.x*0.75]
	var subgridv = Vector3i.ZERO
	subgridv.x = subdivides.bsearch(position.x - aabb.position.x)
	subgridv.y = subdivides.bsearch(position.y - aabb.position.y)
	subgridv.z = subdivides.bsearch(position.z - aabb.position.z)
	#print("Position: %v -> %s" % [position, 
	#	Morton3.int_to_bin(SVOLink.from(layer, offset, Morton3.encode64v(subgridv)))])
		
	navspace.draw_svolink_box(SVOLink.from(layer, offset, Morton3.encode64v(subgridv)))
	return SVOLink.from(layer, offset, Morton3.encode64v(subgridv))
