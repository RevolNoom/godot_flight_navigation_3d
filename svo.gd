class_name SVO

## @layers: Depth of the tree
## Construction of this tree omits root node
## @act1nodes: List of morton codes of active nodes in layer 1. 
##		Must contains only unique elements
## 		Layer 1 counted bottom-up, 0-based, excluding subgrids (leaves layer)
func _init(layers: int, act1nodes: PackedInt64Array):
	# Minus 2 grid layers. But should I refactor it into a const?
	for i in range(layers-2):
		_nodes.push_back([])

	_construct_bottom_up(act1nodes)
	_fill_neighbor_top_down()
	

func node_from_offset(layer: int, offset: int) -> SVONode:
	return _nodes[layer][offset]
	
	
func node_from_link(link: int) -> SVONode:
	return _nodes[SVOLink.layer(link)][SVOLink.offset(link)]

#func subgrid_i(idx) -> int:
#	return _leaves[idx]

func node_from_morton(layer: int, morton: int) -> SVONode:
	return _nodes[layer][index_from_morton(layer, morton)]

func index_from_morton(layer: int, morton: int) -> int:
	var m_node = SVONode.new()
	m_node.morton = morton
	return _nodes[layer].bsearch_custom(m_node, 
			func(node1: SVONode, node2: SVONode):
				return node1.morton < node2.morton)


# TODO:
func from_file(_filename: String):
	pass
func to_file(_filename: String):
	pass

## Allocate memory for each layer in bulk
func _construct_bottom_up(act1nodes: PackedInt64Array):
	act1nodes.sort()
	
	## Allocating memory for subgrids
	#var err = _leaves.resize(act1nodes.size() * 8)
	#assert(err == OK, "Could't allocate %d nodes for SVO subgrids. Error code: %d" \
	#			% [act1nodes.size() * 8, err])
	
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
					= (active_nodes[i] << 3) + (child & 0b111)
		
						
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
			
			for direction in [Neighbor.X_NEG, Neighbor.X_POS,
								Neighbor.Y_NEG, Neighbor.Y_POS,
								Neighbor.Z_NEG, Neighbor.Z_POS]:
				var neighbor: int = 0
				match direction:
					Neighbor.X_NEG:
						neighbor = Morton3.dec_x(this_node.morton)
					Neighbor.X_POS:
						neighbor = Morton3.inc_x(this_node.morton)
					Neighbor.Y_NEG: 
						neighbor = Morton3.dec_y(this_node.morton)
					Neighbor.Y_POS:
						neighbor = Morton3.inc_y(this_node.morton)
					Neighbor.Z_NEG: 
						neighbor = Morton3.dec_z(this_node.morton)
					Neighbor.Z_POS:
						neighbor = Morton3.inc_z(this_node.morton)
			
				if not SVO._mortons_diff_parent(neighbor, this_node.morton):
					var nb_link = SVOLink.from(layer, (i & ~0b111) | (neighbor & 0b111))
					match direction:
						Neighbor.X_NEG:
							this_node.xn = nb_link
						Neighbor.X_POS:
							this_node.xp = nb_link
						Neighbor.Y_NEG: 
							this_node.yn = nb_link
						Neighbor.Y_POS:
							this_node.yp = nb_link
						Neighbor.Z_NEG: 
							this_node.zn = nb_link
						Neighbor.Z_POS:
							this_node.zp = nb_link
				else:
					# TODO:
					var actual_neighbor = _ask_parent_for_neighbor(p_layer, 
											parent_i, direction, neighbor)
					match direction:
						Neighbor.X_NEG:
							this_node.xn = actual_neighbor
						Neighbor.X_POS:
							this_node.xp = actual_neighbor
						Neighbor.Y_NEG: 
							this_node.yn = actual_neighbor
						Neighbor.Y_POS:
							this_node.yp = actual_neighbor
						Neighbor.Z_NEG: 
							this_node.zn = actual_neighbor
						Neighbor.Z_POS:
							this_node.zp = actual_neighbor
			

# TODO: BUG: Didn't check for different layer neighbor
# Ask parent for parent's neighbor
# If parent's neighbor is on same layer with parent:
## then get parent's neighbor's first_child
## If first_child is null link, then child's neighbor is parent's neighbor
## Else, same-size neighbor exists, return their first child index
# Else, if parent's
func _ask_parent_for_neighbor(
		parent_layer: int, 
		parent_idx: int, 
		direction: Neighbor,
		child_neighbor: int):
	var parent = _nodes[parent_layer][parent_idx] as SVONode
	var parent_nbor: int = 0
	match direction:
		Neighbor.X_NEG:
			parent_nbor = parent.xn
		Neighbor.X_POS:
			parent_nbor = parent.xp
		Neighbor.Y_NEG:
			parent_nbor = parent.yn
		Neighbor.Y_POS:
			parent_nbor = parent.yp
		Neighbor.Z_NEG:
			parent_nbor = parent.zn
		Neighbor.Z_POS:
			parent_nbor = parent.zp
			
	if parent_nbor == SVOLink.NULL:
		return SVOLink.NULL
	
	# Parent's neighbor is one in higher layer
	if parent_layer != SVOLink.layer(parent_nbor):
		return parent_nbor
	
	var offset = SVOLink.offset(parent_nbor)
	print(Morton.int_to_bin(parent_nbor))
	var nbor_first_child = _nodes[parent_layer][offset].first_child
	
	if nbor_first_child == SVOLink.NULL:
		return parent_nbor
	
	return SVOLink.from(parent_layer-1, 
		(SVOLink.offset(nbor_first_child) & ~0b111)\
		| (child_neighbor & 0b111))


# @m1, @m2: Morton3 codes
# @return true if svo nodes with codes m1 and m2 don't have the same parent
static func _mortons_diff_parent(m1: int, m2: int) -> bool: 
	return (m1^m2) & 0b111


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
enum Neighbor
{
	X_NEG, #x-1
	X_POS, #x+1
	Y_NEG, #y-1
	Y_POS, #y+1
	Z_NEG, #z-1
	Z_POS, #z+1
}

class SVONode:
	var morton: int
	var parent: int
	
	# For layer 0, first_child IS the subgrid
	# For layer 1 and up, _nodes[layer-1][first_child] is its first child
	# _nodes[layer-1][first_child+1] is 2nd child... upto +7 (8th child)
	var first_child: int
	var xn: int
	var xp: int
	var yn: int
	var yp: int
	var zn: int
	var zp: int
	
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
