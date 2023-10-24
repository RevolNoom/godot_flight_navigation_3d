class_name SparseVoxelOctree

## TODO: Build whole tree

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
	

func node(layer: int, idx: int) -> SVONode:
	return _nodes[layer][idx]

# TODO:
func is_solid(morton_code: int) -> bool:
	return false
func from_file(filename: String):
	pass
func to_file(filename: String):
	pass

## Allocate memory for each layer in bulk
func _construct_bottom_up(act1nodes: PackedInt64Array):
	act1nodes.sort()
	
	## Allocating memory for subgrids
	var err = _leaves.resize(act1nodes.size() * 8)
	assert(err == OK, "Could't allocate %d nodes for SVO subgrids. Error code: %d" \
				% [act1nodes.size() * 8, err])
	
	## Init layer 0
	err = _nodes[0].resize(act1nodes.size() * 8)
	_nodes[0] = _nodes[0].map(func(value): return SVONode.new())
	assert(err == OK, "Could't allocate %d nodes for SVO layer %d. Error code: %d" \
				% [act1nodes.size() * 8, 0, err])
	
	var active_nodes = act1nodes
	
	# Init layer 1 upward
	for layer in range(1, _nodes.size()):
		## Fill children's morton code 
		for i in range(0, active_nodes.size()):
			for child in range(8):
				_nodes[layer-1][i+child].morton\
					= (active_nodes[i] << 3) + (child & 0b111) if \
						layer < _nodes.size() else NULL_LINK
		
						
		var parent_idx = active_nodes.duplicate()
		parent_idx[0] = 0
		
		# Handle root node case
		if layer == _nodes.size()-1:
			_nodes[layer] = [SVONode.new()]
		else:
			for i in range(1, parent_idx.size()):
				if (active_nodes[i-1] >> 3) != (active_nodes[i] >> 3):
					parent_idx[i] = parent_idx[i-1] + 1
			
			## Allocate memory for current layer
			var current_layer_size = (parent_idx[parent_idx.size()-1] + 1) * 8
			err = _nodes[layer].resize(current_layer_size)
			assert(err == OK, "Could't allocate %d nodes for SVO layer %d. Error code: %d" \
						% [current_layer_size, 0, err])
			_nodes[layer] = _nodes[layer].map(func(x): return SVONode.new())

		# Fill parent/children index
		for i in range(0, active_nodes.size()):
			var node_idx = (8*parent_idx[i] + active_nodes[i] & 0b111)
			# Fill child idx for current layer
			_nodes[layer][node_idx].first_child\
					= _to_link(layer-1, 8*i)
			
			# Fill parent idx for children
			var link_to_parent = _to_link(layer, i)
			print("To link: %d %d %d" % [layer, i, link_to_parent])
			for child in range(8):
				print("Layer %d node %d parentlink %d" % [layer, 8*i+child, link_to_parent])
				_nodes[layer-1][8*i + child].parent = link_to_parent
		
		## Prepare for the next layer construction
		active_nodes = _get_parent_mortons(active_nodes)
	
	_test_for_orphan(self)


## WARN: This func relies on @active_nodes being sorted and contains only uniques
func _get_parent_mortons(active_nodes: PackedInt64Array) -> PackedInt64Array:
	#print("Child mortons: %s" % str(active_nodes))
	var result: PackedInt64Array = []
	result.resize(active_nodes.size())
	result.resize(0)
	for morton in active_nodes:
		var parent_code = (morton>>3)
		if result.size() == 0 or result[result.size()-1] != parent_code:
			result.push_back(parent_code)
	
	#print("parent mortons: %s" % str(result))
	return result


## Fill neighbor informations, so that lower layers can rely on 
## their parents to figure out their neighbors
func _fill_neighbor_top_down():
	## Setup root node links
	_nodes[_nodes.size()-1][0].first_child = _to_link(_nodes.size()-2, 0)
	
	for layer in range(_nodes.size()-2, -1, -1):
		var this_layer = _nodes[layer]
		for i in range(this_layer.size()):
			var m = this_layer[i].morton
			var parent_i = _offset(this_layer[i].parent)
			
			##### X #####
			
			if m & 0b001:	# x = 1
				this_layer[i].xn = _to_link(layer, i ^ 0b001)
				
				var xp_nei = _ask_parent_for_neighbor(layer+1, parent_i, Neighbor.X_POS)
				this_layer[i].xp = _to_link(layer,
						(xp_nei + ((i & 0b111) ^ 0b001)))\
							if xp_nei != NULL_LINK else NULL_LINK
			else:	# x = 0
				var xn_nei = _ask_parent_for_neighbor(layer+1, parent_i, Neighbor.X_NEG)
				this_layer[i].xn = _to_link(layer,
							(xn_nei + ((i & 0b111) ^ 0b001)))\
								if xn_nei != NULL_LINK else NULL_LINK
				this_layer[i].xp = _to_link(layer, i ^ 0b001)
			
			##### Y #####
			
			if m & 0b010:	# y = 1
				this_layer[i].yn = _to_link(layer, i ^ 0b010)
				var yp_nei = _ask_parent_for_neighbor(layer+1, parent_i, Neighbor.Y_POS)
				this_layer[i].yp = _to_link(layer,
						(yp_nei + ((i & 0b111) ^ 0b010)))\
							if yp_nei != NULL_LINK else NULL_LINK
			else:	# y = 0
				var yn_nei = _ask_parent_for_neighbor(layer+1, parent_i, Neighbor.Y_NEG)
				this_layer[i].yn = _to_link(layer,
						(yn_nei + ((i & 0b111) ^ 0b010)))\
							if yn_nei != NULL_LINK else NULL_LINK
				this_layer[i].yp = _to_link(layer, i ^ 0b010)

			##### Z #####
			
			if m & 0b100:	# z = 1
				this_layer[i].zn = _to_link(layer, i ^ 0b100)
				
				var zp_nei = _ask_parent_for_neighbor(layer+1, parent_i, Neighbor.Z_POS)
				this_layer[i].zp = _to_link(layer,
						(zp_nei + ((i & 0b111) ^ 0b100)))\
							if zp_nei != NULL_LINK else NULL_LINK
			else:	# z = 0
				var zn_nei = _ask_parent_for_neighbor(layer+1, parent_i, Neighbor.Z_NEG)
				this_layer[i].zn = _to_link(layer,
						(zn_nei + ((i & 0b111) ^ 0b100))\
							if zn_nei != NULL_LINK else NULL_LINK)
							
				this_layer[i].zp = _to_link(layer, i ^ 0b100)
	#print("Breakpoint")


# Ask parent for their x_pos neighbor, get parent's neighbor's first_child
# If first_child is null link, then child's neighbor is parent's neighbor
# Else, same-size neighbor exists, return their first child index
func _ask_parent_for_neighbor(
		parent_layer: int, 
		parent_idx: int, 
		direction: Neighbor):
	var parent = _nodes[parent_layer][parent_idx] as SVONode
	var parent_nbor
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
			
	if parent_nbor == NULL_LINK:
		return NULL_LINK
	var nbor_first_child = _nodes[parent_layer][_offset(parent_nbor)].first_child
	
	if nbor_first_child == NULL_LINK:
		return parent_nbor
	
	return _offset(nbor_first_child)
	


## Each leaf is a 4x4x4 compound of voxels
## They make up 2 bottom-most layers of the tree
var _leaves: PackedInt64Array = []

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
	var first_child: int
	var xn: int
	var xp: int
	var yn: int
	var yp: int
	var zn: int
	var zp: int
	
	func _init():
		morton = NULL_LINK
		parent = NULL_LINK
		first_child = NULL_LINK
		xn = NULL_LINK
		xp = NULL_LINK
		yn = NULL_LINK
		yp = NULL_LINK
		zn = NULL_LINK
		zp = NULL_LINK

# All 1s
const NULL_LINK = ~0

## 4 leftmost bits
static func _layer_of(link: int) -> int:
	return link >> 60

## 6 rightmost bits
static func _subgrid(link: int) -> int:
	return link & 0x3F

## The rest
static func _offset(link: int) -> int:
	#print("\nlink: %d\noffset: %d\n" % [link, (link << 4) >> 10])
	return (link << 4) >> 10

## WARNING: Not checking valid value for performance 
static func _to_link(layer: int, offset: int, subgrid: int = 0) -> int:
	return (layer << 60) | (offset << 6) | subgrid 


static func _test_for_orphan(svo: SparseVoxelOctree):
	for i in range(svo._nodes.size()):
		for j in range(svo._nodes[i].size()):
			if svo._nodes[i][j].parent == NULL_LINK:
				printerr("NULL parent: Layer %d Node %d" % [i, j])
