## Sparse Voxel Octree is a data structure used to contain solid state of 
## volumes in 3D space.
##
## Sparse Voxel Octree contains solid/free state of space. It has the following features:[br]
## [br]
## - Tightly packed: Each layer contains only nodes that has some solid volume, and
## they are serialized in increasing Morton order.[br]
##
## - Tightly-coupled: Each node contains [SVOLink] to other neighbor nodes in tree
## for fast traversal between nodes.[br]
## 
## Because of that, it's best to use SVO as an immutable data type 
## (i.e. keep all attributes unchanged after construction).[br]
extends Resource
class_name SVO

## The depth of the tree, excluding the subgrid levels.[br]
##
## Higher depth rasterizes collision shapes in more details,
## but also consumes more memory. Each layer adds upto 
## 8 times more memory consumption.[br]
##
## [b]NOTE:[/b] This value is read-only. Used for editor convenience.[br]
@export var depth: int = 2:
	get:
		return layers.size()

## The i-th element is an array of all nodes on the i-th layer of the tree. [br]
## [member layers][depth-1][0] is the tree root. [br]
## [member layers][0] is array of all bottom-most nodes.[br]
##
## [b]WARNING:[/b] If you don't know what you are doing, don't edit this.[br] 
## [b]NOTE:[/b] It's safe to modify [member SVONode.subgrid] (voxel solid state).
## But since [SVO] is intended to be generated from meshes, it's generally not
## a good idea to modify its content directly.[br] 
## [b]NOTE:[/b] UI for this property is not updated right away after voxelization.
## You must click on it to see updated values
@export var layers: Array[PackedInt64Array] = []

func _init():
	_construct_tree(1, [])


## Return the node with [param morton] code in SVO's [param layer].[br]
## Return [member null] if there's no such [param layer] or node with [param morton] code
func it_from_morton(layer: int, morton: int) -> SVOIteratorRandom:
	if layer >= layers.size():
		return null
	var it = SVOIteratorRandom._new(self, SVOLink.from(layer, 0, 0))
	# Binary search to find the node with specified morton
	var begin: int = 0
	var end: int = get_layer_size(layer)
	while begin != end:
		@warning_ignore("integer_division")
		var middle = (begin+end)/2
		it.go(layer, middle)
		if it.morton < morton:
			begin = middle + 1
		else:
			end = middle
	it.go(layer, begin)
	if it.morton != morton:
		return null
	return it
	
## [param depth]: Depth of the tree.[br]
##
## [param act1nodes]: List of unique morton codes of active nodes in layer 1.
## If left empty, a tree with only root node will be returned[br]
##
## [param subgrid_states]: List of [member SVONode.subgrid] that contains subgrid
## voxel solid state per layer-0 node. Must have length exactly 8-time longer than 
## [param act1nodes]. If left empty, all subgrids are initialized empty.[br]
static func create_new(tree_depth: int = 2, act1nodes: PackedInt64Array = [], subgrid_states: PackedInt64Array = []) -> SVO:
	var svo = SVO.new()
	svo._construct_tree(tree_depth, act1nodes)
	if subgrid_states.size() == svo.layers[0].size():
		svo.set_solid_states(subgrid_states)
	return svo


## See [method create_new].[br]
func _construct_tree(tree_depth: int, act1nodes: PackedInt64Array):
	if act1nodes.size() == 0:
		return
	layers.resize(tree_depth)
	_construct_bottom_up(act1nodes)
	_fill_neighbor_top_down()
	_initialize_layer0()


## Return [constant @GlobalScope.OK] if all subgrids are set,
## else [constant @GlobalScope.FAILED] if they are not.[br]
## Subgrids are not set when they don't have same size as layers[0]
func set_solid_states(subgrid_states: PackedInt64Array) -> Error:
	if subgrid_states.is_empty() or subgrid_states.size() != layers[0].size():
		return FAILED
	var it = SVOIteratorRandom._new(self, SVOLink.NULL)
	for i in range(subgrid_states.size()):
		it.go(0, i).rubik = subgrid_states[i]
	return OK


func _initialize_layer0() -> void:
	var it = SVOIteratorSequential.h_begin(self, SVOLink.from(0, 0, 0))
	while not it.end():
		it.rubik = Subgrid.EMPTY
		it.next()


## Return array of neighbors' [SVOLink]s.[br]
## [param svolink]: The node whose neighbors need to be found.[br]
func neighbors_of(svolink: int) -> PackedInt64Array:
	var it = SVOIteratorRandom._new(self, svolink)
	var neighbors: PackedInt64Array = []
	
	# Get neighbors of subgrid voxel
	if it.is_subgrid_voxel():
		var subgrid = it.subgrid
		# [Face: Neighbor in which direction,
		# subgrid: Subgrid value of the voxel neighbor we're looking for]
		for neighbor in [
			[SVOIterator.DataField.NEIGHBOR_X_NEGATIVE, Morton3.dec_x(subgrid)],
			[SVOIterator.DataField.NEIGHBOR_X_POSITIVE, Morton3.inc_x(subgrid)],
			[SVOIterator.DataField.NEIGHBOR_Y_NEGATIVE, Morton3.dec_y(subgrid)],
			[SVOIterator.DataField.NEIGHBOR_Y_POSITIVE, Morton3.inc_y(subgrid)],
			[SVOIterator.DataField.NEIGHBOR_Z_NEGATIVE, Morton3.dec_z(subgrid)],
			[SVOIterator.DataField.NEIGHBOR_Z_POSITIVE, Morton3.inc_z(subgrid)],
			]:
			# Add neighboring leaf voxels in same parent
			if Morton3.ge(neighbor[1], 0) and Morton3.le(neighbor[1], 63):
				neighbors.push_back(SVOLink.set_subgrid(neighbor[1], svolink))
			else:
				# Neighbor does not exist
				if it.field(neighbor[0]) == SVOLink.NULL:
					continue
				var neighbor_it = SVOIteratorRandom._new(self, it.field(neighbor[0]))
					
				if not neighbor_it.is_subgrid_voxel():
					neighbors.push_back(neighbor_it.svolink)
					continue
				
				# Get that subgrid voxel on neighbor node0
				var neighbor_voxel_index = neighbor[1] & 0x3F
				neighbors.push_back(SVOLink.set_subgrid(neighbor_voxel_index, neighbor_it.svolink))
	# Get neighbor of a node
	else:
		# Get voxels on face that is opposite to direction
		# e.g. If neighbor is in positive direction, 
		# then get voxels on negative face of that neighbor
		for nb in [[SVOIterator.DataField.NEIGHBOR_X_NEGATIVE, it.xp], 
					[SVOIterator.DataField.NEIGHBOR_X_POSITIVE, it.xn], 
					[SVOIterator.DataField.NEIGHBOR_Y_NEGATIVE, it.yp], 
					[SVOIterator.DataField.NEIGHBOR_Y_POSITIVE, it.yn], 
					[SVOIterator.DataField.NEIGHBOR_Z_NEGATIVE, it.zp],
					[SVOIterator.DataField.NEIGHBOR_Z_POSITIVE, it.zn]]:
			if nb[1] == SVOLink.NULL:
				continue
			var smos = _smallest_voxels_on_surface(nb[0], nb[1])
			neighbors.append_array(smos)
			
	return neighbors


# NOTE: Currently, SVO is built without inside/outside information of a mesh,
# only solid/free space information of the surface of the mesh.
# As a consequence, nodes on layer != 0 are all free space,
# and only subgrid voxels can be solid
## Return true if [param svolink] refers to a solid voxel
func is_link_solid(svolink: int) -> bool:
	var it = SVOIteratorRandom._new(self, svolink)
	return it.layer == 0 and it.is_solid()


## Calculate the center of the voxel/node
## where 1 unit distance corresponds to side length of 1 subgrid voxel.
func get_center(svolink: int) -> Vector3:
	var it = SVOIteratorRandom._new(self, svolink)
	var node_size = 1 << (it.layer + 2)
	
	#var corner_pos = Morton3.decode_vec3(it.morton) * node_size
	
	# In case layer 0 node has some solid voxels, the center
	# is the center of the subgrid voxel, not of the node
	if it.is_subgrid_voxel():
		return Morton3.decode_vec3(it.morton) * node_size\
				+ Morton3.decode_vec3(it.subgrid)\
				+ Vector3(0.5, 0.5, 0.5) # half a voxel
			
	return (Morton3.decode_vec3(it.morton) + Vector3(0.5, 0.5, 0.5)) * node_size 


func get_layer_size(layer_idx: int):
	@warning_ignore("integer_division")
	return layers[layer_idx].size()/SVOIterator.DataField.MAX_FIELD

func resize_layer(layer_idx: int, size: int):
	layers[layer_idx].resize(size * SVOIterator.DataField.MAX_FIELD)
	layers[layer_idx].fill(SVOLink.NULL)
	
# Allocate memory for each layer in bulk.[br]
# [param act1nodes]: Layer 1 nodes' Morton codes[br]
func _construct_bottom_up(act1nodes: PackedInt64Array) -> void:
	act1nodes.sort()
	
	# Init layer 0
	resize_layer(0, act1nodes.size() * 8)
	
	var activelayers = act1nodes
	
	## An array to hold the parent index on above layer of the current layer in building.
	var parent_idx = activelayers.duplicate()
	
	# Init layer 1 upward
	var it = SVOIteratorRandom._new(self, SVOLink.NULL)
	
	for layer in range(1, layers.size()):
		## Fill children's morton code 
		for i in range(0, activelayers.size()):
			for child in range(8):
				it.go(layer-1, i*8+child).morton = (activelayers[i] << 3) | child
				
		parent_idx[0] = 0
		
		# ROOT NODE CASE
		if layer == layers.size()-1:
			resize_layer(layer, 1)
			it.go(layer, 0).morton = 0
		else:
			for i in range(1, activelayers.size()):
				parent_idx[i] = parent_idx[i-1]\
					+ int(not _mortons_same_parent(activelayers[i-1], activelayers[i]))
		
			## Allocate memory for current layer
			var current_layer_size = (parent_idx[parent_idx.size()-1] + 1) * 8
			resize_layer(layer, current_layer_size)

		# Fill parent/children index
		for i in range(0, activelayers.size()):
			var j = 8*parent_idx[i] + (activelayers[i] & 0b111)
			# Fill child idx for current layer
			it.go(layer, j).first_child\
					= SVOLink.from(layer-1, 8*i)
			
			# Fill parent idx for children
			var link_to_parent = SVOLink.from(layer, j)
			for child in range(8):
				it.go(layer-1, 8*i + child).parent = link_to_parent
		
		## Prepare for the next layer construction
		activelayers = _get_parent_mortons(activelayers)
	#SVO._comprehensive_test(self)

## Return array of all [param activelayers]' parents' morton codes.[br]
## [param activelayers]: Sorted Array that contains only uniques of some nodes' morton codes.
func _get_parent_mortons(activelayers: PackedInt64Array) -> PackedInt64Array:
	#print("Child mortons: %s" % str(activelayers))
	if activelayers.size() == 0:
		return []
		
	var result: PackedInt64Array = [activelayers[0] >> 3]
	result.resize(activelayers.size())
	result.resize(1)
	for morton in activelayers:
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
	var v_it = SVOIteratorSequential.v_begin(self)
	v_it.first_child = SVOLink.from(layers.size()-2, 0)
	v_it.next()
	while not v_it.end():
		var h_it = SVOIteratorSequential.h_begin(self, v_it.svolink)
		while not h_it.end():
			for face in SVOIterator.Neighbors:
				var neighbor: int = 0
				match face:
					SVOIterator.DataField.NEIGHBOR_X_NEGATIVE:
						neighbor = Morton3.dec_x(h_it.morton)
					SVOIterator.DataField.NEIGHBOR_X_POSITIVE:
						neighbor = Morton3.inc_x(h_it.morton)
					SVOIterator.DataField.NEIGHBOR_Y_NEGATIVE:
						neighbor = Morton3.dec_y(h_it.morton)
					SVOIterator.DataField.NEIGHBOR_Y_POSITIVE:
						neighbor = Morton3.inc_y(h_it.morton)
					SVOIterator.DataField.NEIGHBOR_Z_NEGATIVE:
						neighbor = Morton3.dec_z(h_it.morton)
					SVOIterator.DataField.NEIGHBOR_Z_POSITIVE:
						neighbor = Morton3.inc_z(h_it.morton)
			
				if _mortons_same_parent(neighbor, h_it.morton):
					h_it.set_field(
						face, 
						SVOLink.from(
							h_it.layer, 
							(h_it.offset & ~0b111) | (neighbor & 0b111)))
				else:
					h_it.set_field(
						face, 
						_ask_parent_for_neighbor(h_it.parent, face, neighbor))
			h_it.next()
		v_it.next()
			
## Return the neighbor of parent's on [param face] or parent's neighbor's subgrid voxel
## with index [param child_neighbor].[br]
##
## [param parent_link]: [SVOLink] to parent node.[br]
## [param face]: The direction to ask parent node for neighbor.[br]
## [param child_neighbor]: The subgrid index of the parent's neighbor's subgrid voxel, if any.[br]
func _ask_parent_for_neighbor(
		parent_link: int, 
		face: SVOIterator.DataField,
		child_neighbor: int) -> int:
	if parent_link == SVOLink.NULL:
		return SVOLink.NULL
	var parent = SVOIteratorRandom._new(self, parent_link)
	var parent_nbor_svolink = parent.field(face)
	if parent_nbor_svolink == SVOLink.NULL:
		return SVOLink.NULL
	
	# Parent's neighbor is on higher layer
	if SVOLink.layer(parent_link) != SVOLink.layer(parent_nbor_svolink):
		return parent_nbor_svolink
		
	var neighbor = SVOIteratorRandom._new(self, 
		SVOLink.from(parent.layer, SVOLink.offset(parent_nbor_svolink)))
	
	if neighbor.has_no_child():
		return parent_nbor_svolink
	
	return SVOLink.from(parent.layer-1, 
		(SVOLink.offset(neighbor.first_child) & ~0b111)\
		| (child_neighbor & 0b111))


# Return all subgrid voxels which has morton code coordinate
# equals to some of [param v]'s x, y, z components.[br]
#
# [param v]'s component is -1 if you want to disable checking that component.
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
	[], [], [], # Padding 0, 1, 2 until NEIGHBOR_X_NEGATIVE
	_get_subgrid_voxels_where_component_equals(Vector3i(0, -1, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(3, -1, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, 0, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, 3, -1)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, -1, 0)),
	_get_subgrid_voxels_where_component_equals(Vector3i(-1, -1, 3)),
]


# Return all highest-resolution voxels that make up the face of node 
# identified as [param svolink][br]
#
# [param svolink]: link to a node (not a subgrid voxel!)
func _smallest_voxels_on_surface(face: SVOIterator.DataField, svolink: int) -> PackedInt64Array:
	if svolink == SVOLink.NULL:
		return []
		
	var it = SVOIteratorRandom._new(self, svolink)
	
	if it.layer == 0:
		# This node is all free space. No need to travel its subgrid
		if it.rubik == SVONode.Subgrid.EMPTY:
			return [svolink]
			
		# Return all subgrid voxels on the specified face
		return (_face_subgrid[face] as Array).map(
			func(voxel_idx) -> int:
				return SVOLink.set_subgrid(voxel_idx, svolink))
	
	# If this node doesn't have any child
	# Then it makes up the face itself
	if it.has_no_child():
		return [svolink]

	# This vector holds index of 4 children on [param face]
	var children_on_face: PackedInt64Array = [it.first_child, it.first_child, it.first_child, it.first_child]
	var children_indexes: Vector4i
	match face:
		SVOIterator.DataField.NEIGHBOR_X_NEGATIVE:
			children_indexes = Vector4i(0,2,4,6)
		SVOIterator.DataField.NEIGHBOR_X_POSITIVE:
			children_indexes = Vector4i(1,3,5,7)
		SVOIterator.DataField.NEIGHBOR_Y_NEGATIVE:
			children_indexes = Vector4i(0,1,4,5)
		SVOIterator.DataField.NEIGHBOR_Y_POSITIVE:
			children_indexes = Vector4i(2,3,6,7)
		SVOIterator.DataField.NEIGHBOR_Z_NEGATIVE:
			children_indexes = Vector4i(0,1,2,3)
		_: #SVOIterator.DataField.NEIGHBOR_Y_POSITIVE:
			children_indexes = Vector4i(4,5,6,7)
	
	# Ignore "subgrid" in SVOLink 
	children_indexes.x <<= 6
	children_indexes.y <<= 6
	children_indexes.z <<= 6
	children_indexes.w <<= 6
	
	return (_smallest_voxels_on_surface(face, children_on_face[0] + children_indexes.x)\
		+  _smallest_voxels_on_surface(face, children_on_face[1] + children_indexes.y))\
		+  (_smallest_voxels_on_surface(face, children_on_face[2] + children_indexes.z)\
		+  _smallest_voxels_on_surface(face, children_on_face[3] + children_indexes.w))


# Return true if svo nodes with codes m1 and m2 have the same parent
# [param m1], [param m2]: Morton3 codes of two nodes in same layer[br]
func _mortons_same_parent(m1: int, m2: int) -> bool: 
	# Same parent means 2nd-61th bits are the same.
	# Thus, m1 ^ m2 should have them == 0
	return (m1^m2) & 0x7FFF_FFFF_FFFF_FFF8 == 0


static func _comprehensive_test(svo: SVO) -> void:
	print("Testing SVO Validity")
	_test_for_orphan(svo)
	_test_for_null_morton(svo)
	print("SVO Validity Test completed")


static func _test_for_orphan(svo: SVO) -> void:
	print("Testing SVO for orphan")
	var orphan_found = 0
	var v_it = SVOIteratorSequential.v_begin(svo)
	while not v_it.end():
		var h_it = SVOIteratorSequential.h_begin(svo, v_it.svolink)
		if h_it.parent == SVOLink.NULL:
			orphan_found += 1
			printerr("NULL parent: Layer %d Node %d" % [h_it.layer, h_it.offset])
	var err_str = "Completed with %d orphan%s found" \
					% [orphan_found, "s" if orphan_found > 1 else ""]
	if orphan_found:
		printerr(err_str)
	else:
		print(err_str)


static func _test_for_null_morton(svo: SVO):
	print("Testing SVO for null morton")
	var unnamed = 0
	var v_it = SVOIteratorSequential.v_begin(svo)
	while not v_it.end():
		var h_it = SVOIteratorSequential.h_begin(svo, v_it.svolink)
		if h_it.morton == SVOLink.NULL:
			unnamed += 1
			printerr("NULL morton: Layer %d Node %d" % [h_it.layer, h_it.offset])
	var err_str = "Completed with %d null mortons%s found" \
					% [unnamed, "s" if unnamed > 1 else ""]
	if unnamed:
		printerr(err_str)
	else:
		print(err_str)
		
		
## Create a debug svo with only voxels on the surfaces
#static func get_debug_svo(layer: int) -> SVO:
	#var layer1_side_length = 2 ** (layer-4)
	#var act1nodes = []
	#for i in range(8**(layer-4)):
		#var node1 = Morton3.decode_vec3i(i)
		#if node1.x in [0, layer1_side_length - 1]\
		#or node1.y in [0, layer1_side_length - 1]\
		#or node1.z in [0, layer1_side_length - 1]:
			#act1nodes.append(i)
			#
	#var svo:= SVO.create_new(layer, act1nodes)
	#
	#var layer0_side_length = 2 ** (layer-3)
	#for node0 in svo.layers[0]:
		#node0 = node0 as SVONode
		#var n0pos := Morton3.decode_vec3i(node0.morton)
		#if n0pos.x in [0, layer0_side_length - 1]\
		#or n0pos.y in [0, layer0_side_length - 1]\
		#or n0pos.z in [0, layer0_side_length - 1]:
			#for i in range(64):
				## Voxel position (relative to its node0 origin)
				#var vpos := Morton3.decode_vec3i(i)
				#if (n0pos.x == 0 and vpos.x == 0)\
				#or (n0pos.y == 0 and vpos.y == 0)\
				#or (n0pos.z == 0 and vpos.z == 0)\
				#or (n0pos.x == layer0_side_length - 1 and vpos.x == 3)\
				#or (n0pos.y == layer0_side_length - 1 and vpos.y == 3)\
				#or (n0pos.z == layer0_side_length - 1 and vpos.z == 3):
					#node0.subgrid |= 1<<i
	#return svo

enum Subgrid{
	## No voxel is solid
	EMPTY = 0,
	## All voxels are solid
	SOLID = ~0,
}
