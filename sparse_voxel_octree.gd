class_name SparseVoxelOctree

const NULL_NODE = 0

## @omitted_top_layers: Stop the construction of the tree after building this layer
## = 0: Complete tree with root node
## = 1: Tree without root node
## = 2: Tree without root node & layer 1
## @layers: Depth of the tree
## @act1nodes: List of morton codes of active nodes in layer 1. 
##		Must contains only unique elements
## 		Layer 1 counted bottom-up, 0-based, excluding subgrids (leaves layer)
func _init(layers: int, omitted_top_layers: int, act1nodes: PackedInt64Array):
	var err = _nodes.resize(layers - omitted_top_layers)
	assert(err == OK, "Could't resize SVO to %d layers. Error code: %d"\
			% [layers, err])

	_construct_bottom_up(act1nodes)
	## Too much text
	#print("_nodes: %s" % str(_nodes))
	_refine_top_down()
	

## @layer: the layer of the node, counted bottom-up
## @idx: offset into layer-array of the node
func node(layer: int, node_idx: int, field: NodeLayout) -> int:
	return _nodes[layer][node_idx * NodeLayout.NODE_SIZE + field]

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
	var err = _leaves.resize(NodeLayout.NODE_SIZE * act1nodes.size() * 8)
	assert(err == OK, "Could't allocate %d nodes for SVO subgrids. Error code: %d" \
				% [act1nodes.size() * 8, err])
	
	var active_nodes = act1nodes
	
	## Init layer 0
	err = _nodes[0].resize(NodeLayout.NODE_SIZE * act1nodes.size() * 8)
	assert(err == OK, "Could't allocate %d nodes for SVO layer %d. Error code: %d" \
				% [active_nodes.size() * 8, 0, err])
	
	# Init layer 1 upward
	for layer in range(1, _nodes.size()):
		
		## Fill children's morton code 
		for i in range(0, active_nodes.size()):
			for child in range(8):
				_nodes[layer-1][(i+child)*NodeLayout.NODE_SIZE + NodeLayout.MORTON_CODE]\
						= (active_nodes[i] << 3) + (child & 0b111)\
						if layer < _nodes.size()\
						else NULL_NODE
		
		if layer >= _nodes.size():
			return
					
		var parent_idx = active_nodes.duplicate()
		parent_idx[0] = 0
		for i in range(1, parent_idx.size()):
			if (active_nodes[i-1] >> 3) != (active_nodes[i] >> 3):
				parent_idx[i] = parent_idx[i-1] + 1
		
		## Allocate memory for current layer
		var current_layer_size = (parent_idx[parent_idx.size()-1] + 1) * 8
		err = _nodes[layer].resize(
			NodeLayout.NODE_SIZE * current_layer_size)
		assert(err == OK, "Could't allocate %d nodes for SVO layer %d. Error code: %d" \
					% [current_layer_size, 0, err])

		for i in range(0, active_nodes.size()):
			var node_idx = (8*parent_idx[i] + active_nodes[i] & 0b111)
			# Fill child idx for current layer
			_nodes[layer][node_idx \
						* NodeLayout.NODE_SIZE\
						+ NodeLayout.FIRST_CHILD_IDX]\
						= _to_link(layer-1,
							8*i*NodeLayout.NODE_SIZE,
							0)
			# TODO:
			# Fill parent idx for children
		
		
		## Prepare for the next layer construction
		active_nodes = _get_parent_mortons(active_nodes)


## WARN: This func relies on @active_nodes being sorted and contains only uniques
func _get_parent_mortons(active_nodes: PackedInt64Array) -> PackedInt64Array:
	var result: PackedInt64Array = []
	result.resize(active_nodes.size())
	result.resize(0)
	for morton in active_nodes:
		var parent_code = (morton>>3)
		if result.size() == 0 or result[result.size()-1] != parent_code:
			result.push_back(parent_code)
	return result


## Fill in neighbor and parent links for each node
func _refine_top_down():
	for layer in range(_nodes.size()-1, -1, -1):
		for i in range(0, _nodes[layer].size() / NodeLayout.NODE_SIZE):
			if layer == _nodes.size()-1:	# Top layer parent = null
				_nodes[layer][i*NodeLayout.NODE_SIZE + NodeLayout.PARENT_IDX] = NULL_NODE
			else:
				pass

## Each leaf is a 4x4x4 compound of voxels
## They make up 2 bottom-most layers of the tree
var _leaves: PackedInt64Array = []

## Since _leaves make up 2 bottom-most layers,
## _nodes[0] is the 3rd layer of the tree, 
## _nodes[1] is 4th,... and so on
## However, I'll refer to _nodes[0] as "layer 0"
## and _leaf as "leaves layer", for consistency with
## the research paper
var _nodes: Array[PackedInt64Array] = []




enum NodeLayout
{
	MORTON_CODE = 0,
	
	# Offset into parent-layer array
	PARENT_IDX,
	
	# Offset into child-layer array
	# The first child is, by design,
	# followed by 7 other children
	FIRST_CHILD_IDX,
	
	# Links to neighbors
	# Could be parent's neighbor
	X_NEG, #x-1
	X_POS, #x+1
	Y_NEG, #y-1
	Y_POS, #y+1
	Z_NEG, #z-1
	Z_POS, #z+1
	
	NODE_SIZE, # = 9
}

func __set_sibling_links():
	var layer = 0
	var active_nodes = []
	
	for i in range(0, _nodes[layer].size()/NodeLayout.NODE_SIZE):
		var parent_code = active_nodes[i] << 3
		
		_nodes[layer][i*NodeLayout.NODE_SIZE + NodeLayout.MORTON_CODE]\
				= parent_code + i % 8
		
		## Set x neighbor
		if i & 0b001: 
			_nodes[layer][i*NodeLayout.NODE_SIZE + NodeLayout.X_NEG]\
				= parent_code | (i & 0b110)	# x = 0
		else:
			_nodes[layer][i*NodeLayout.NODE_SIZE + NodeLayout.X_POS]\
				= parent_code | 0b001	# x = 1
				
		## Set y neighbor
		if i & 0b010: 
			_nodes[layer][i*NodeLayout.NODE_SIZE + NodeLayout.Y_NEG]\
				= parent_code | (i & 0b101)	# y = 0
		else:
			_nodes[layer][i*NodeLayout.NODE_SIZE + NodeLayout.Y_POS]\
				= parent_code | 0b010	# y = 1
				
		## Set z neighbor
		if i & 0b100: 
			_nodes[layer][i*NodeLayout.NODE_SIZE + NodeLayout.Z_NEG]\
				= parent_code | (i & 0b011)	# z = 0
		else:
			_nodes[layer][i*NodeLayout.NODE_SIZE + NodeLayout.Z_POS]\
				= parent_code | 0b100	# z = 1

## 4 leftmost bits
static func _layer_of(link: int) -> int:
	return link >> 60

## 6 rightmost bits
static func _subgrid(link: int) -> int:
	return link & 0x3F

## The rest
static func _offset(link: int) -> int:
	return (link >> 6) & 0x3_FFFF_FFFF_FFFF

## WARNING: Not checking valid value for performance 
static func _to_link(layer: int, offset: int, subgrid: int) -> int:
	return (layer << 60) | (offset << 6) | subgrid 
