class SparseVoxelOctree:
	func _init(layer_count: int):
		var err = _nodes.resize(layer_count)
		assert(err != OK, "Could't resize SVO to " + str(layer_count) 
						+ " layers. Error code: " + str(err))
	
	## @layer: the layer of the node, counted bottom-up
	## @idx: offset into layer-array of the node
	func node_info(layer: int, node_idx: int, field: NodeLayout) -> int:
		return _nodes[layer][node_idx * NodeLayout.NODE_SIZE + field]
	
	## Create a new PackedInt64Array with enough memory
	## to store @node_count nodes in @layer. 
	func reserve(layer: int, node_count: int):
		var err = _nodes[layer].resize(node_count * NodeLayout.NODE_SIZE)
		assert(err != OK, "Could't allocate " + str(node_count) 
						+ " nodes for SVO layer " + str(layer) 
						+ ". Error code: " + str(err))
	
	# TODO:
	func is_solid(morton_code: int) -> bool:
		return false
	func from_file(filename: String):
		pass
	func to_file(filename: String):
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
		
		# Neighbors' Morton code
		# Could be parent's neighbor
		X_NEG, #x-1
		X_POS, #x+1
		Y_NEG, #y-1
		Y_POS, #y+1
		Z_NEG, #z-1
		Z_POS, #z+1
		
		NODE_SIZE,
	}
	
	
