class_name SVO

# TODO: The neighbor filling algorithm could be sped up by allocating 1 thread
# per neighbor direction (-x, +x, -y,...) 

## @layers: Depth of the tree
## Construction of this tree omits root node
## @act1nodes: List of morton codes of active nodes in layer 1. 
##		Must contains only unique elements
## 		Layer 1 counted bottom-up, 0-based, excluding subgrids (leaves layer)
func _init(layers: int, act1nodes: PackedInt64Array):
	# Handle case when there's nothing in space
	if act1nodes.size() == 0:
		printerr("SVO construction: No active nodes found. Did you forget to put some objects in space, or turn on NavSpace/Object physic flags?")
		_nodes = [[SVONode.new()]]
		_nodes[0][0].morton = 0
		_nodes[0][0].first_child = SVOLink.NULL
		return
		
	# Minus 2 grid layers. But should I refactor it into a const?
	for i in range(layers-2):
		_nodes.push_back([])

	_construct_bottom_up(act1nodes)
	_fill_neighbor_top_down()


func node_from_offset(layer: int, offset: int) -> SVONode:
	return _nodes[layer][offset]
	
	
func node_from_link(link: int) -> SVONode:
	var debug = Morton3.int_to_bin(link)
	return _nodes[SVOLink.layer(link)][SVOLink.offset(link)]


## Return neighbor nodes' links of node with @svolink
## TODO: Return neighbors in SVONode attributes
## and all smallest nodes (vox) if we're going from big vox to small vox

func node_from_morton(layer: int, morton: int) -> SVONode:
	return _nodes[layer][index_from_morton(layer, morton)]


func index_from_morton(layer: int, morton: int) -> int:
	var m_node = SVONode.new()
	m_node.morton = morton
	return _nodes[layer].bsearch_custom(m_node, 
			func(node1: SVONode, node2: SVONode):
				return node1.morton < node2.morton)


func neighbors_of(svolink: int) -> PackedInt64Array:
	var node = node_from_link(svolink)
	var layer = SVOLink.layer(svolink)
	
	var neighbors: PackedInt64Array = []
	if layer == 0 and node.first_child != 0:
		var subgrid = SVOLink.subgrid(svolink)
		var m = Morton3.decode_vec3i(subgrid)
		
		# [Face: Neighbor in which direction,
		# subgrid: Subgrid value of the voxel neighbor we're looking for]
		# TODO: Check subgrid on surface
		for neighbor in [
			[Face.X_NEG, Morton3.dec_x(subgrid)],
			[Face.X_POS, Morton3.inc_x(subgrid)],
			[Face.Y_NEG, Morton3.dec_y(subgrid)],
			[Face.Y_POS, Morton3.inc_y(subgrid)],
			[Face.Z_NEG, Morton3.dec_z(subgrid)],
			[Face.Z_POS, Morton3.inc_z(subgrid)],
			]:
			if Morton3.ge(neighbor[1], 0) and Morton3.lt(neighbor[1], 64):
				neighbors.push_back(SVOLink.set_subgrid(neighbor[1], svolink))
			else:
				var nb_link := node.neighbor(neighbor[0])
						
				# Neighbor does not exist
				if nb_link == SVOLink.NULL:
					continue
					
				# Free-space nodes (higher layer). Return whole
				if SVOLink.layer(nb_link) > 0:
					neighbors.push_back(nb_link)
					continue
					
				var nb_node = node_from_link(nb_link)
				# Free-space node0. Return whole
				if nb_node.first_child == 0:
					neighbors.push_back(nb_link)
					continue
				
				# Get that subgrid voxel on neighbor node0
				neighbors.push_back(SVOLink.set_subgrid(nb_node.first_child, subgrid & 0x3F))
	else:
		# Get voxels on face opposite to direction
		# e.g. If neighbor is in positive direction, 
		# then get voxels on negative face
		for nb in [[Face.X_NEG, node.xp], 
					[Face.X_POS, node.xn], 
					[Face.Y_NEG, node.yp], 
					[Face.Y_POS, node.yn], 
					[Face.Z_NEG, node.zp],
					[Face.Z_POS, node.zn]]:
			if nb[1] != SVOLink.NULL:
				neighbors.append_array(_smallest_voxels_on_surface(nb[0], nb[1]))
	
	return neighbors


## Return the depth, excluding the subgrid levels
var depth: int:
	get:
		return _nodes.size()

# TODO:
func from_file(_filename: String):
	pass
func to_file(_filename: String):
	pass

## Allocate memory for each layer in bulk
func _construct_bottom_up(act1nodes: PackedInt64Array):
	act1nodes.sort()
	
	## Init layer 0
	_nodes[0].resize(act1nodes.size() * 8)
	_nodes[0] = _nodes[0].map(func(_v): return SVONode.new())
	## Set all subgrid voxels as free space
	for node in _nodes[0]:
		node.first_child = 0
	
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
					+ int(SVO._mortons_diff_parent(active_nodes[i-1], active_nodes[i]))
		
			
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


## WARN: This func relies on @active_nodes being sorted and contains only uniques
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

#TODO: Is there any way to remove the enum test reeks?
## Fill neighbor informations, so that lower layers can rely on 
## their parents to figure out their neighbors
func _fill_neighbor_top_down():
	## Setup root node links
	_nodes[_nodes.size()-1][0].first_child = SVOLink.from(_nodes.size()-2, 0)
	
	for layer in range(_nodes.size()-2, -1, -1):
		var this_layer = _nodes[layer]
		for i in range(this_layer.size()):
			var this_node = this_layer[i]
			var parent_i = SVOLink.offset(this_node.parent)
			var p_layer = layer+1
			
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
			
				if not SVO._mortons_diff_parent(neighbor, this_node.morton):
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
					var actual_neighbor = _ask_parent_for_neighbor(p_layer, 
											parent_i, face, neighbor)
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
			

# Ask parent for parent's neighbor
# If parent's neighbor is on same layer with parent:
# + then get parent's neighbor's first_child
# If first_child is null link, then child's neighbor is parent's neighbor
# Else, same-size neighbor exists, return their first child index
# Else, if parent's... (I forgot to comment the last part. Now I forgot)
func _ask_parent_for_neighbor(
		parent_layer: int, 
		parent_idx: int, 
		face: Face,
		child_neighbor: int):
	var parent = _nodes[parent_layer][parent_idx] as SVONode
	var parent_nbor: int = parent.neighbor(face)
	
	if parent_nbor == SVOLink.NULL:
		return SVOLink.NULL
	
	# Parent's neighbor is one in higher layer
	if parent_layer != SVOLink.layer(parent_nbor):
		return parent_nbor
	
	var offset = SVOLink.offset(parent_nbor)
	var nbor_first_child = _nodes[parent_layer][offset].first_child
	
	if nbor_first_child == SVOLink.NULL:
		return parent_nbor
	
	return SVOLink.from(parent_layer-1, 
		(SVOLink.offset(nbor_first_child) & ~0b111)\
		| (child_neighbor & 0b111))


## Return all subgrid voxels which has morton code coordinate
## equals to some of @v 's x, y, z components
## @v 's component is -1 if you want to disable checking that component
static func _get_subgrid_voxels_where_component_equals(v: Vector3i) -> PackedInt64Array:
	var result: PackedInt64Array = []
	for i in range(64):
		var mv = Morton3.decode_vec3i(i)
		if v.x != -1 and mv.x != v.x:
			continue
		if v.y != -1 and mv.y != v.y:
			continue
		if v.z != -1 and mv.z != v.z:
			continue
		result.push_back(i)
	# Debug print
	# print("v: %v, result: %s" % [v, 
	#		str((result as Array).map(
	#			func(value): 
	#				return Morton.int_to_bin(value).substr(58)))])
	return result

static var face_subgrid: Array[PackedInt64Array] = [
	_get_subgrid_voxels_where_component_equals(Vector3i(0, -1, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(3, -1, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, 0, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, 3, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, -1, 0)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, -1, 3)),
]


## @svolink: link to a node (not a subgrid voxel!)
## Return all highest-resolution voxels that make up the face of node @svolink
func _smallest_voxels_on_surface(face: Face, svolink: int) -> PackedInt64Array:
	if svolink == SVOLink.NULL:
		return []
	
	var layer = SVOLink.layer(svolink)
	var node = node_from_link(svolink)
	
	if layer == 0:
		# This node0 is all free space. No need to travel its subgrid
		if node.first_child == 0:
			return [svolink]
		# Return all subgrid voxels on the specified face
		return (face_subgrid[face] as Array).map(
			func(voxel_idx) -> int:
				return SVOLink.set_offset(voxel_idx, svolink))
	
	# If this node doesn't have any child
	# Then it makes up the face itself
	if node.first_child == SVOLink.NULL:
		return [svolink]

	# This vector holds index of 4 children on @face
	var children_on_face: Vector4i =\
			Vector4i(node.first_child,
					node.first_child,
					node.first_child,
					node.first_child)
	match face:
		Face.X_NEG:
			children_on_face += Vector4i(0,2,4,6)
		Face.X_POS:
			children_on_face += Vector4i(1,3,5,7)
		Face.Y_NEG:
			children_on_face += Vector4i(0,1,4,5)
		Face.Y_POS:
			children_on_face += Vector4i(2,3,6,7)
		Face.Z_NEG:
			children_on_face += Vector4i(0,1,2,3)
		_: #Face.Z_POS:
			children_on_face += Vector4i(4,5,6,7)
	return (_smallest_voxels_on_surface(face, children_on_face.x)\
		+  _smallest_voxels_on_surface(face, children_on_face.y))\
		+  (_smallest_voxels_on_surface(face, children_on_face.z)\
		+  _smallest_voxels_on_surface(face, children_on_face.w))


# @m1, @m2: Morton3 codes
# @return true if svo nodes with codes m1 and m2 don't have the same parent
static func _mortons_diff_parent(m1: int, m2: int) -> bool: 
	# Same parent means 61 most significant bits are the same
	# Thus, m1 ^ m2 should have 61 MSB == 0
	return (m1^m2) >> 3


## Each leaf is a 4x4x4 compound of voxels
## They make up 2 bottom-most layers of the tree
#var _leaves: PackedInt64Array = []

## Since _leaves make up 2 bottom-most layers,
## _nodes[0] is the 3rd layer of the tree, 
## _nodes[1] is 4th,... and so on
## However, I'll refer to _nodes[0] as "layer 0"
## and _leaf as "leaves layer", for consistency with
## the research paper
## Type: Array[Array[SVONode]]
var _nodes: Array = []


# Links to neighbors
# Could be parent's neighbor
enum Face
{
	X_NEG, #x-1
	X_POS, #x+1
	Y_NEG, #y-1
	Y_POS, #y+1
	Z_NEG, #z-1
	Z_POS, #z+1
}

class SVONode:
	## Morton index of this node. Also defines where it is in space
	var morton: int
	
	var parent: int #SVOLink
	
	# For layer 0, first_child IS the subgrid
	# For layer 1 and up, _nodes[layer-1][first_child] is its first child
	# _nodes[layer-1][first_child+1] is 2nd child... upto +7 (8th child)
	var first_child: int #SVOLink
	
	var xn: int #SVOLink, X-negative neighbor
	var xp: int #SVOLink, X-positive neighbor
	var yn: int #SVOLink
	var yp: int #SVOLink
	var zn: int #SVOLink
	var zp: int #SVOLink
	
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
		

static func _comprehensive_test(svo: SVO):
	print("Testing SVO Validity")
	_test_for_orphan(svo)
	_test_for_null_morton(svo)
	print("SVO Validity Test completed")


static func _test_for_orphan(svo: SVO):
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
		
		
## Create a svo with only voxels on the surfaces
static func _get_debug_svo(layer: int) -> SVO:
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
					node0.first_child |= 1<<i
	return svo
