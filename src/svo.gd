## The Sparse Voxel Octree
##
## Sparse Voxel Octree contains solid/free state of space in a tightly-packed, 
## tightly-coupled manner. Thus, adding/removing nodes cannot be done iteratively.
## You must create a new one to reflect that update.
class_name SVO

## Return the depth of the tree, excluding the subgrid levels.
var depth: int:
	get:
		return _nodes.size()

## [param layers]: Depth of the tree[br]
## [param act1nodes]: List of unique morton codes of active nodes in layer 1. 
func _init(layers: int, act1nodes: PackedInt64Array):
	# Handle case when there's nothing in space
	if act1nodes.size() == 0:
		printerr("SVO construction: No active nodes found. Did you forget to put some objects in space, or turn on NavSpace/Object physic flags?")
		_nodes = [[SVONode.new()]]
		_nodes[0][0].morton = 0
		_nodes[0][0].subgrid = SVONode.EMPTY_SUBGRID
		return
		
	for i in range(layers):
		_nodes.push_back([])

	_construct_bottom_up(act1nodes)
	_fill_neighbor_top_down()


## Return the node at [param offset] in SVO's [param layer],
## or null if either [param layer] or [param offset] doesn't exist
func node_from_offset(layer: int, offset: int) -> SVONode:
	if _nodes.size() <= layer or _nodes[layer].size() < offset:
		return null
	return _nodes[layer][offset]
	
	
## Return the node identified as [param svolink]
## or null if [param svolink] isn't valid 
## (either [param svolink]'s layer or [param offset doesn't exist)
func node_from_link(svolink: int) -> SVONode:
	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	return node_from_offset(layer, offset)


## Return the node with [param morton] code in SVO's [param layer].[br]
## Return [member null] if there's no such [param layer] or node with [param morton] code
func node_from_morton(layer: int, morton: int) -> SVONode:
	var svolink = link_from_morton(layer, morton)
	return null if svolink == SVOLink.NULL else node_from_link(svolink)


## Find node with [param morton] code in SVO's [param layer].[br]
## Return [SVOLink] to the node if it exists, [member SVOLink.NULL] otherwise.
func link_from_morton(layer: int, morton: int) -> int:
	if _nodes.size() <= layer:
		return SVOLink.NULL
	var m_node = SVONode.new()
	m_node.morton = morton
	var offset = _nodes[layer].bsearch_custom(m_node, 
			func(node1: SVONode, node2: SVONode):
				return node1.morton < node2.morton)
	if offset >= _nodes[layer].size() or _nodes[layer][offset].morton != morton:
		return SVOLink.NULL
	return SVOLink.from(layer, offset)


## Return neighbor nodes' links of node with [param svolink
## [param svolink: The node whose neighbors need to be found
## [param return: Array of neighbors' SVOLinks
func neighbors_of(svolink: int) -> PackedInt64Array:
	var node = node_from_link(svolink)
	var layer = SVOLink.layer(svolink)
	
	var neighbors: PackedInt64Array = []
	
	# Get neighbors of subgrid voxel
	# TODO: Refactor to a separate method
	if is_subgrid_voxel(svolink):
		var subgrid = SVOLink.subgrid(svolink)
		var m = Morton3.decode_vec3i(subgrid)
		
		# [Face: Neighbor in which direction,
		# subgrid: Subgrid value of the voxel neighbor we're looking for]
		for neighbor in [
			[Face.X_NEG, Morton3.dec_x(subgrid)],
			[Face.X_POS, Morton3.inc_x(subgrid)],
			[Face.Y_NEG, Morton3.dec_y(subgrid)],
			[Face.Y_POS, Morton3.inc_y(subgrid)],
			[Face.Z_NEG, Morton3.dec_z(subgrid)],
			[Face.Z_POS, Morton3.inc_z(subgrid)],
			]:
			# Add neighboring leaf voxels in same parent
			if Morton3.ge(neighbor[1], 0) and Morton3.le(neighbor[1], 63):
				neighbors.push_back(SVOLink.set_subgrid(neighbor[1], svolink))
			else:
				var nb_link := node.neighbor(neighbor[0])
						
				# Neighbor does not exist
				if nb_link == SVOLink.NULL:
					continue
					
				if not is_subgrid_voxel(nb_link):
					neighbors.push_back(nb_link)
					continue
				
				# Get that subgrid voxel on neighbor node0
				var neighbor_voxel_index = neighbor[1] & 0x3F
				neighbors.push_back(SVOLink.set_subgrid(neighbor_voxel_index, nb_link))
	# Get neighbor of a node
	else:
		# Get voxels on face that is opposite to direction
		# e.g. If neighbor is in positive direction, 
		# then get voxels on negative face of that neighbor
		for nb in [[Face.X_NEG, node.xp], 
					[Face.X_POS, node.xn], 
					[Face.Y_NEG, node.yp], 
					[Face.Y_POS, node.yn], 
					[Face.Z_NEG, node.zp],
					[Face.Z_POS, node.zn]]:
			if nb[1] == SVOLink.NULL:
				continue
			
			# If neighbor is a bigger node
			# then it already makes up the whole surface we are looking at
			# neighbor cannot be a smaller node, because the construction of SVO
			# sets up links between same level nodes
			# Thus, one method call works on both cases
			var neighbor_layer = SVOLink.layer(nb[1])
			var surf_vox = _smallest_voxels_on_surface(nb[0], nb[1])
			neighbors.append_array(surf_vox)
			
	return neighbors


# NOTE: Currently, SVO is built without inside/outside information of a mesh,
# only solid/free space information of the surface of the mesh.
# As a consequence, nodes on layer != 0 are all free space,
# and only subgrid voxels can be solid
## Return true if [param svolink] refers to a solid voxel
func is_link_solid(svolink: int) -> bool:
	return SVOLink.layer(svolink) == 0\
			and node_from_link(svolink).is_solid(SVOLink.subgrid(svolink))


## Return true if [param svolink] refers to a subgrid voxel.[br]
## An svolink points to a subgrid voxel when it points to layer 0 and that node
## has at least one solid voxel.
func is_subgrid_voxel(svolink: int) -> bool:
	return SVOLink.layer(svolink) == 0\
			and node_from_link(svolink).subgrid != SVONode.EMPTY_SUBGRID


## Calculate the center of the voxel/node
## where 1 unit distance corresponds to side length of 1 subgrid voxel.
func get_center(svolink: int) -> Vector3:
	var node = node_from_link(svolink)
	var layer = SVOLink.layer(svolink)
	var node_size = 1 << (layer + 2)
	var corner_pos = Morton3.decode_vec3(node.morton) * node_size
	
	# In case layer 0 node has some solid voxels, the center
	# is the center of the subgrid voxel, not of the node
	if is_subgrid_voxel(svolink):
		return corner_pos\
				+ Morton3.decode_vec3(SVOLink.subgrid(svolink))\
				+ Vector3(1,1,1)*0.5 # half a voxel
			
	return corner_pos + Vector3(1,1,1) * 0.5 * node_size 



## TODO:
func from_file(_filename: String):
	pass
	
## TODO:
func to_file(_filename: String):
	pass

# Allocate memory for each layer in bulk[br]
# [param act1nodes]: Layer 1 nodes' Morton codes
func _construct_bottom_up(act1nodes: PackedInt64Array) -> void:
	act1nodes.sort()
	
	## Init layer 0
	_nodes[0].resize(act1nodes.size() * 8)
	_nodes[0] = _nodes[0].map(func(_v): return SVONode.new())
	## Set all subgrid voxels as free space
	for node in _nodes[0]:
		node.subgrid = SVONode.EMPTY_SUBGRID
	
	var active_nodes = act1nodes
	
	# Init layer 1 upward
	for layer in range(1, _nodes.size()):
		## Fill children's morton code 
		for i in range(0, active_nodes.size()):
			for child in range(8):
				_nodes[layer-1][i*8+child].morton\
					= (active_nodes[i] << 3) | child
		
						
		var parent_idx = active_nodes.duplicate()
		parent_idx[0] = 0
		
		# ROOT NODE CASE
		if layer == _nodes.size()-1:
			_nodes[layer] = [SVONode.new()]
			_nodes[layer][0].morton = 0
		else:
			for i in range(1, parent_idx.size()):
				parent_idx[i] = parent_idx[i-1]\
					+ int(not _mortons_same_parent(active_nodes[i-1], active_nodes[i]))
		
			
			## Allocate memory for current layer
			var current_layer_size = (parent_idx[parent_idx.size()-1] + 1) * 8
			_nodes[layer].resize(current_layer_size)
			_nodes[layer] = _nodes[layer].map(func(_v): return SVONode.new())

		# Fill parent/children index
		for i in range(0, active_nodes.size()):
			var j = 8*parent_idx[i] + (active_nodes[i] & 0b111)
			# Fill child idx for current layer
			_nodes[layer][j].first_child\
					= SVOLink.from(layer-1, 8*i)
			
			# Fill parent idx for children
			var link_to_parent = SVOLink.from(layer, j)
			for child in range(8):
				_nodes[layer-1][8*i + child].parent = link_to_parent
		
		## Prepare for the next layer construction
		active_nodes = _get_parent_mortons(active_nodes)
	
	#SVO._comprehensive_test(self)

## Return array of all [param active_nodes]' parents' morton codes.[br]
## [param active_nodes]: Sorted Array that contains only uniques of some nodes' morton codes.
func _get_parent_mortons(active_nodes: PackedInt64Array) -> PackedInt64Array:
	#print("Child mortons: %s" % str(active_nodes))
	if active_nodes.size() == 0:
		return []
		
	var result: PackedInt64Array = [active_nodes[0] >> 3]
	result.resize(active_nodes.size())
	result.resize(1)
	for morton in active_nodes:
		var parent_code = morton>>3
		if result[result.size()-1] != parent_code:
			result.push_back(parent_code)
	#print("parent mortons: %s" % str(result))
	return result


# Fill neighbor informations, so that lower layers can rely on 
# their parents to figure out their neighbors
# TODO: I think the neighbor filling algorithm could be sped up by allocating 1 thread
# per neighbor direction (-x, +x, -y,...) 
func _fill_neighbor_top_down() -> void:
	## Setup root node links
	_nodes[_nodes.size()-1][0].first_child = SVOLink.from(_nodes.size()-2, 0)
	
	for layer in range(_nodes.size()-2, -1, -1):
		var this_layer = _nodes[layer]
		for i in range(this_layer.size()):
			var this_node = this_layer[i]
			
			for face in [Face.X_NEG, Face.X_POS,
								Face.Y_NEG, Face.Y_POS,
								Face.Z_NEG, Face.Z_POS]:
				var neighbor: int = 0
				match face:
					Face.X_NEG:
						neighbor = Morton3.dec_x(this_node.morton)
					Face.X_POS:
						neighbor = Morton3.inc_x(this_node.morton)
					Face.Y_NEG: 
						neighbor = Morton3.dec_y(this_node.morton)
					Face.Y_POS:
						neighbor = Morton3.inc_y(this_node.morton)
					Face.Z_NEG: 
						neighbor = Morton3.dec_z(this_node.morton)
					Face.Z_POS:
						neighbor = Morton3.inc_z(this_node.morton)
			
				if _mortons_same_parent(neighbor, this_node.morton):
					var nb_link = SVOLink.from(layer, (i & ~0b111) | (neighbor & 0b111))
					match face:
						Face.X_NEG:
							this_node.xn = nb_link
						Face.X_POS:
							this_node.xp = nb_link
						Face.Y_NEG: 
							this_node.yn = nb_link
						Face.Y_POS:
							this_node.yp = nb_link
						Face.Z_NEG: 
							this_node.zn = nb_link
						Face.Z_POS:
							this_node.zp = nb_link
				else:
					var actual_neighbor = _ask_parent_for_neighbor(this_node.parent, face, neighbor)
					match face:
						Face.X_NEG:
							this_node.xn = actual_neighbor
						Face.X_POS:
							this_node.xp = actual_neighbor
						Face.Y_NEG: 
							this_node.yn = actual_neighbor
						Face.Y_POS:
							this_node.yp = actual_neighbor
						Face.Z_NEG: 
							this_node.zn = actual_neighbor
						Face.Z_POS:
							this_node.zp = actual_neighbor
			
## Return the neighbor of parent's on [param face] or parent's neighbor's subgrid voxel
## with index [param child_neighbor].[br]
##
## [param parent_link]: [SVOLink] to parent node.[br]
## [param face]: The direction to ask parent node for neighbor.[br]
## [param child_neighbor]: The subgrid index of the parent's neighbor's subgrid voxel, if there's any.[br]
func _ask_parent_for_neighbor(
		parent_link: int, 
		face: Face,
		child_neighbor: int) -> int:
	var parent = node_from_link(parent_link)
	var parent_layer = SVOLink.layer(parent_link)
	var parent_nbor: int = parent.neighbor(face)
	
	if parent_nbor == SVOLink.NULL:
		return SVOLink.NULL
	
	# Parent's neighbor is on higher layer
	if parent_layer != SVOLink.layer(parent_nbor):
		return parent_nbor
	
	var neighbor = node_from_offset(parent_layer, SVOLink.offset(parent_nbor))
	
	if neighbor.has_no_child():
		return parent_nbor
	
	return SVOLink.from(parent_layer-1, 
		(SVOLink.offset(neighbor.first_child) & ~0b111)\
		| (child_neighbor & 0b111))


## Return all subgrid voxels which has morton code coordinate
## equals to some of [param v]'s x, y, z components.[br]
## [param v]'s component is -1 if you want to disable checking that component.
static func _get_subgrid_voxels_where_component_equals(v: Vector3i) -> PackedInt64Array:
	var result: PackedInt64Array = []
	for i in range(64):
		var mv = Morton3.decode_vec3i(i)
		if (v.x == -1 or mv.x == v.x) and\
			(v.y == -1 or mv.y == v.y) and\
			(v.z == -1 or mv.z == v.z):
			result.push_back(i)
	return result


# Indexes of subgrid voxel that makes up a face of a layer-0 node
# e.g. face_subgrid[Face.X_NEG] for all indexes of voxel on negative-x face
static var _face_subgrid: Array[PackedInt64Array] = [
	_get_subgrid_voxels_where_component_equals(Vector3i(0, -1, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(3, -1, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, 0, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, 3, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, -1, 0)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, -1, 3)),
]


## Return all highest-resolution voxels that make up the face of node identified as [param svolink]
## [param svolink]: link to a node (not a subgrid voxel!)
func _smallest_voxels_on_surface(face: Face, svolink: int) -> PackedInt64Array:
	if svolink == SVOLink.NULL:
		return []
		
	var layer = SVOLink.layer(svolink)
	var node = node_from_link(svolink)
	
	if layer == 0:
		# This node is all free space. No need to travel its subgrid
		if node.subgrid == SVONode.EMPTY_SUBGRID:
			return [svolink]
			
		# Return all subgrid voxels on the specified face
		return (_face_subgrid[face] as Array).map(
			func(voxel_idx) -> int:
				return SVOLink.set_subgrid(voxel_idx, svolink))
	
	# If this node doesn't have any child
	# Then it makes up the face itself
	if node.has_no_child():
		return [svolink]

	# This vector holds index of 4 children on [param face
	var children_on_face: Vector4i = Vector4i.ONE * node.first_child
	var children_indexes: Vector4i
	match face:
		Face.X_NEG:
			children_indexes = Vector4i(0,2,4,6)
		Face.X_POS:
			children_indexes = Vector4i(1,3,5,7)
		Face.Y_NEG:
			children_indexes = Vector4i(0,1,4,5)
		Face.Y_POS:
			children_indexes = Vector4i(2,3,6,7)
		Face.Z_NEG:
			children_indexes = Vector4i(0,1,2,3)
		_: #Face.Z_POS:
			children_indexes = Vector4i(4,5,6,7)
	
	# Multiply by 64 to shift all bits in indexes by 6 bits, 
	# to ignore "subgrid" in SVOLink 
	children_on_face += children_indexes * 64
	
	return (_smallest_voxels_on_surface(face, children_on_face.x)\
		+  _smallest_voxels_on_surface(face, children_on_face.y))\
		+  (_smallest_voxels_on_surface(face, children_on_face.z)\
		+  _smallest_voxels_on_surface(face, children_on_face.w))


# Return true if svo nodes with codes m1 and m2 have the same parent
# [param m1], [param m2]: Morton3 codes of two nodes in same layer[br]
func _mortons_same_parent(m1: int, m2: int) -> bool: 
	# Same parent means 61 most significant bits are the same
	# Thus, m1 ^ m2 should have 61 MSB == 0
	return (m1^m2) >> 3 == 0


# Type: Array[Array[SVONode]] [br]
# The i-th element is an array of all nodes on the i-th layer of the tree. [br]
# [member _nodes][depth-1] contains only one node (root) [br]
# [member _nodes][0] is array of all bottom-most nodes
var _nodes: Array = []


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


## A node in Sparse Voxel Octree.
##
## An SVONode contains information about position in space, neighbors,
## parent, children, and subgrid voxels solid state, with some helper methods
class SVONode:
	enum{
		## No voxel is solid
		EMPTY_SUBGRID = 0,
		## All voxels are solid
		SOLID_SUBGRID = ~0,
	}
	
	## Morton3 index of this node. Defines where it is in space
	var morton: int
	
	## SVOLink of parent node
	var parent: int 
	
	## For layer-0 node, [member SVONode.first_child] [b]IS[b] [member SVONode.subgrid][br]
	##
	## For layer i > 0, [member SVO._nodes][i-1][[member SVONode.first_child]] is [SVOLink] to its first child in [class SVO],
	## [member SVO._nodes][layer-1][[member SVONode.first_child]+1] is 2nd... upto +7 (8th child)
	var first_child: int 
	
	## [b]NOTE: FOR LAYER-0 NODES ONLY[/b][br]
	## Alias for [member first_child], each bit corresponds to solid state of a voxel
	var subgrid: int:
		get:
			return first_child
		set(value):
			first_child = value
	
	var xn: int ## SVOLink to neighbor on negative x direction
	var xp: int ## SVOLink to neighbor on positive y direction
	var yn: int ## SVOLink to neighbor on negative z direction
	var yp: int ## SVOLink to neighbor on positive x direction
	var zn: int ## SVOLink to neighbor on negative y direction
	var zp: int ## SVOLink to neighbor on positive z direction
	
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
	
	## Return an SVOLink to the neighbor on this node's [param face] 
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
	
	## [b]NOTE: For layer-0 nodes only[/b][br]
	## Return true if subgrid voxel at [param subgrid_index] is solid[br]
	## [param subgrid_index]: bit position 0-63 (inclusive), corresponds to [method SVOLink.subgrid]
	func is_solid(subgrid_index: int) -> bool:
		return subgrid & (1 << subgrid_index)
	
	## [b]NOTE: NOT for layer-0 nodes [/b][br]
	## Return true if this node has no children.
	func has_no_child() -> bool:
		return first_child == SVOLink.NULL
	

static func _comprehensive_test(svo: SVO) -> void:
	print("Testing SVO Validity")
	_test_for_orphan(svo)
	_test_for_null_morton(svo)
	print("SVO Validity Test completed")


static func _test_for_orphan(svo: SVO) -> void:
	print("Testing SVO for orphan")
	var orphan_found = 0
	for i in range(svo._nodes.size()-1):	# -1 to omit root node
		for j in range(svo._nodes[i].size()):
			if svo._nodes[i][j].parent == SVOLink.NULL:
				orphan_found += 1
				printerr("NULL parent: Layer %d Node %d" % [i, j])
	var err_str = "Completed with %d orphan%s found" \
					% [orphan_found, "s" if orphan_found > 1 else ""]
	if orphan_found:
		printerr(err_str)
	else:
		print(err_str)


static func _test_for_null_morton(svo: SVO):
	print("Testing SVO for null morton")
	var unnamed = 0
	for i in range(svo._nodes.size()):	# -1 to omit root node
		for j in range(svo._nodes[i].size()):
			if svo._nodes[i][j].morton == SVOLink.NULL:
				unnamed += 1
				printerr("NULL morton: Layer %d Node %d" % [i, j])
	var err_str = "Completed with %d null mortons%s found" \
					% [unnamed, "s" if unnamed > 1 else ""]
	if unnamed:
		printerr(err_str)
	else:
		print(err_str)
		
		
## Create a debug svo with only voxels on the surfaces
static func get_debug_svo(layer: int) -> SVO:
	var layer1_side_length = 2 ** (layer-4)
	var act1nodes = []
	for i in range(8**(layer-4)):
		var node1 = Morton3.decode_vec3i(i)
		if node1.x in [0, layer1_side_length - 1]\
		or node1.y in [0, layer1_side_length - 1]\
		or node1.z in [0, layer1_side_length - 1]:
			act1nodes.append(i)
			
	var svo:= SVO.new(layer, act1nodes)
	
	var layer0_side_length = 2 ** (layer-3)
	for node0 in svo._nodes[0]:
		node0 = node0 as SVO.SVONode
		var n0pos := Morton3.decode_vec3i(node0.morton)
		if n0pos.x in [0, layer0_side_length - 1]\
		or n0pos.y in [0, layer0_side_length - 1]\
		or n0pos.z in [0, layer0_side_length - 1]:
			for i in range(64):
				# Voxel position (relative to its node0 origin)
				var vpos := Morton3.decode_vec3i(i)
				if (n0pos.x == 0 and vpos.x == 0)\
				or (n0pos.y == 0 and vpos.y == 0)\
				or (n0pos.z == 0 and vpos.z == 0)\
				or (n0pos.x == layer0_side_length - 1 and vpos.x == 3)\
				or (n0pos.y == layer0_side_length - 1 and vpos.y == 3)\
				or (n0pos.z == layer0_side_length - 1 and vpos.z == 3):
					node0.subgrid |= 1<<i
	return svo
