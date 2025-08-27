## Sparse Voxel Octree 
## [br][br]
## Represents the solid/free states of volumes in 3D space.
##
## Sparse Voxel Octree has the following properties:
## [br][br]
## - Tightly packed: Each layer contains only nodes that has some solid volume, and
## they are serialized in increasing Morton order.
## [br][br]
## - Tightly-coupled: Each node contains [SVOLink] to other neighbor nodes in tree
## for fast traversal between nodes.
## [br][br]
## [b]CONCEPTS[/b]
## [br][br]
## An SVO of depth 9 means 9 layers of SVONode. 
## [br]
## The SVO can be thought of as a rubik with 2^9 cubes on each dimension (512x512x512). 
## [br]
## Since each SVONode in the deepest layer (leaf node) is made of 64 (4x4x4) voxels,
## the [i]Resolution[/i] is 2048x2048x2048 (2^11). [br] 
## [br]
## [br][br]
## [b]LIMITATIONS[/b]
## [br][br]
## - After construction, SVO are best used to read only. 
## Due to its tightly-packed nature, there's no way to trivially update a voxel 
## solid/free state. You must always reconstruct it, using FlightNavigation3D.
## [br]
## - Current implementation only do a surface voxelization. 
## It means SVO only knows whether a position is On The Surface of an object.
## SVO doesn't know whether a position is inside an object.

extends Resource
class_name SVO

## [b]NOTE:[/b] This value is read-only. Used for editor convenience.
## [br]
## The number of SVONode layers of the tree (doesn't count subgrid voxel layers). 
## [br]
## Higher depth rasterizes collision shapes in more details,
## but also consumes more memory. Each layer adds upto 
## 8 times more memory consumption.
## (But thought analysis says it is only about 4 times).[br]
@export var depth: int:
	get:
		return morton.size()

## [class Morton3] coordinates
@export var morton: Array[PackedInt64Array] = []

## [class SVOLink] to the parent SVONode in the upper layer.
@export var parent: Array[PackedInt64Array] = []

## [class SVOLink] to the first of the 8 children SVONode in the lower layer.
@export var first_child: Array[PackedInt64Array] = []

## Subgrid voxels of the deepest SVONode layer.
@export var subgrid: PackedInt64Array = []

## [class SVOLink] of X-Positive neighbor
@export var xp: Array[PackedInt64Array] = []

## [class SVOLink] of Y-Positive neighbor
@export var yp: Array[PackedInt64Array] = []

## [class SVOLink] of Z-Positive neighbor
@export var zp: Array[PackedInt64Array] = []

## [class SVOLink] of X-Negative neighbor
@export var xn: Array[PackedInt64Array] = []

## [class SVOLink] of Y-Negative neighbor
@export var yn: Array[PackedInt64Array] = []

## [class SVOLink] of Z-Negative neighbor
@export var zn: Array[PackedInt64Array] = []

## True if this [SVO] supports inside/outside state query.
@export var support_inside: bool:
	get:
		return inside.size()

## Determine whether a node is inside or outside an object. [br]
## [b]NOTE:[/b] Although it is possible to pack each inside state as a bit 
## (8 inside states in 1 byte),
## it was thought that the trade off between memory saved 
## and code coherence was not worth it. 
## As such, this array is indexed similarly to other arrays ([member xn], [member yn], [member zn]...).
## @experimental: TODO
@export var inside: Array[PackedByteArray] = []

## True if this [SVO] supports solid percentage coverage per node.
@export var support_coverage: bool:
	get:
		return coverage.size()
		
## Coverage factor (the percentage of the voxel covered by the object).
## Is a number between 0 and 1.
## @experimental: TODO
@export var coverage: Array[PackedFloat64Array] = []

func _init():
	pass


## Return the node with [param target_morton] in SVO's [param layer].
## [br]
## If no node with such [param target_morton] exists, return [SVOLink.NULL].
func svolink_from_morton(layer: int, target_morton: int) -> int:
	var morton_layer = morton[layer]
	var offset = Algorithm.binary_search(morton_layer, target_morton)
	if offset == -1:
		return SVOLink.NULL
	return SVOLink.from(layer, offset)


## Return array of neighbors' [SVOLink]s.
## [br]
## [param svolink]: The node whose neighbors need to be found.
func neighbors_of(svolink: int) -> PackedInt64Array:
	var neighbors: PackedInt64Array = []
	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	#var linkstr = SVOLink.get_format_string(svolink)
	# Get neighbors of subgrid voxel
	if layer == 0:
		var current_svolink_subgrid = SVOLink.subgrid(svolink)
		
		var promising_neighbors = [
			# neighbor_expected_subgrid, neighbor_direction, neighbor_actual_subgrid (in case neighbor is of different parent)
			[Morton3.dec_x(current_svolink_subgrid), xn, Morton3.set_x(current_svolink_subgrid, 3)],
			[Morton3.inc_x(current_svolink_subgrid), xp, Morton3.set_x(current_svolink_subgrid, 0)],
			[Morton3.dec_y(current_svolink_subgrid), yn, Morton3.set_y(current_svolink_subgrid, 3)],
			[Morton3.inc_y(current_svolink_subgrid), yp, Morton3.set_y(current_svolink_subgrid, 0)],
			[Morton3.dec_z(current_svolink_subgrid), zn, Morton3.set_z(current_svolink_subgrid, 3)],
			[Morton3.inc_z(current_svolink_subgrid), zp, Morton3.set_z(current_svolink_subgrid, 0)]
		]
		for neighbor_info in promising_neighbors:
			var neighbor_expected_subgrid = neighbor_info[0]
			
			var neighbor_is_a_leaf_voxel_of_same_parent = \
				Morton3.ge(neighbor_expected_subgrid, 0)\
				and Morton3.le(neighbor_expected_subgrid, 63)
				
			if neighbor_is_a_leaf_voxel_of_same_parent:
				neighbors.push_back(SVOLink.set_subgrid(neighbor_expected_subgrid, svolink))
				continue
				
			var neighbor_direction = neighbor_info[1]
			var neighbor_svolink = neighbor_direction[layer][offset]
			# There is no neighbor on this side
			if neighbor_svolink == SVOLink.NULL:
				continue
			
			var neighbor_layer = SVOLink.layer(neighbor_svolink)
			var neighbor_is_not_subgrid_voxel = neighbor_layer > 0
			if neighbor_is_not_subgrid_voxel:
				neighbors.push_back(neighbor_svolink)
				continue
			
			var neighbor_actual_subgrid = neighbor_info[2]
			neighbors.push_back(SVOLink.set_subgrid(neighbor_actual_subgrid, neighbor_svolink))
	# Get neighbors of a node
	else:
		# Get voxels on face that is opposite to direction
		# e.g. If neighbor is in positive direction, 
		# then get voxels on negative face of that neighbor
		for neighbor in [[xp, xn], [xn, xp], [yp, yn], [yn, yp], [zp, zn], [zn, zp]]:
			var neighbor_svolink = neighbor[0][layer][offset]
			if neighbor_svolink == SVOLink.NULL:
				continue
			var neighbor_face = neighbor[1]
			var smos = _get_voxels_on_face(neighbor_face, neighbor_svolink)
			neighbors.append_array(smos)
			
	return neighbors


## Return true if [param svolink] refers to a solid voxel
func is_solid(svolink: int) -> bool:
	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	var subgrid_index = SVOLink.subgrid(svolink)
	return layer == 0 and subgrid[offset] & (1 << subgrid_index)


## Calculate the center of the voxel/node
## where 1 unit distance corresponds to side length of 1 subgrid voxel.
func get_center(svolink: int) -> Vector3:
	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	var node_size = 1 << (layer + 2)
	var node_corner_position = Morton3.decode_vec3(morton[layer][offset])
	
	# For layer 0, the center is the center of the subgrid voxel
	if layer == 0:
		var voxel_corner_position = Morton3.decode_vec3(subgrid[offset])
		var half_a_voxel = Vector3(0.5, 0.5, 0.5)
		return node_corner_position * node_size + voxel_corner_position + half_a_voxel
	
	var half_a_node = Vector3(0.5, 0.5, 0.5)
	return (node_corner_position + half_a_node) * node_size 




## Return all highest-resolution voxels that make up the face of node [param svolink][br]
func _get_voxels_on_face(
	face: Array[PackedInt64Array], # SVO.nx/ny/nz/px/py/pz
	svolink: int) -> PackedInt64Array:
	if svolink == SVOLink.NULL:
		return []
	
	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	
	if layer == 0:
		var subgrid_voxels: PackedInt32Array
		if face == xn:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face["xn"]
		elif face == xp:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face["xp"]
		elif face == yn:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face["yn"]
		elif face == yp:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face["yp"]
		elif face == zn:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face["zn"]
		elif face == zp:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face["zp"]
		var subgrid_voxel_on_face: PackedInt64Array = []
		subgrid_voxel_on_face.resize(subgrid_voxels.size())
		for i in range(subgrid_voxels.size()):
			subgrid_voxel_on_face[i] = SVOLink.set_subgrid(subgrid_voxels[i], svolink) 
		return subgrid_voxel_on_face
	
	var first_child_svolink = first_child[layer][offset]
	# If this node doesn't have any child
	# Then it makes up the face itself
	if first_child_svolink == SVOLink.NULL:
		return [svolink]

	# This vector holds index of 4 children on [param face]
	var children_on_face: PackedInt64Array = \
		[first_child_svolink, first_child_svolink, first_child_svolink, first_child_svolink]
	var children_indexes: PackedInt64Array
	if face == xn:
		children_indexes = Fn3dLookupTable.children_node_by_face["xn"]
	elif face == xp:
		children_indexes = Fn3dLookupTable.children_node_by_face["xp"]
	elif face == yn:
		children_indexes = Fn3dLookupTable.children_node_by_face["yn"]
	elif face == yp:
		children_indexes = Fn3dLookupTable.children_node_by_face["yp"]
	elif face == zn:
		children_indexes = Fn3dLookupTable.children_node_by_face["zn"]
	elif face == zp:
		children_indexes = Fn3dLookupTable.children_node_by_face["zp"]
	
	var voxels_on_face: PackedInt64Array = []
	for i in range(4):
		var children_voxels_on_face = _get_voxels_on_face(face, children_on_face[i] + children_indexes[i])
		voxels_on_face.append_array(children_voxels_on_face)
	
	return voxels_on_face


## Head nodes are nodes without -z neighbors
func _get_list_offset_of_head_node_of_layer(layer: int) -> PackedInt64Array:
	var list_size = 0
	var zn_layer = zn[layer]
	for i in range(0, zn_layer.size(), 2):
		if zn_layer[i] == SVOLink.NULL:
			list_size += 1
			
	var list_head_node_offset: PackedInt64Array = []
	list_head_node_offset.resize(list_size)
	
	# Identify head nodes
	var list_head_node_offset_index = 0
	for i in range(0, zn_layer.size(), 2):
		if zn_layer[i] == SVOLink.NULL:
			list_head_node_offset[list_head_node_offset_index] = i
			list_head_node_offset_index += 1
	return list_head_node_offset

#static func _comprehensive_test(svo: SVO) -> void:
	#print("Testing SVO Validity")
	#_test_for_orphan(svo)
	#_test_for_null_morton(svo)
	#print("SVO Validity Test completed")
#
#
#static func _test_for_null_morton(svo: SVO):
	#print("Testing SVO for null morton")
	#var unnamed = 0
	#var v_it = SVOIteratorSequential.v_begin(svo)
	#while not v_it.end():
		#var h_it = SVOIteratorSequential.h_begin(svo, v_it.svolink)
		#if h_it.morton == SVOLink.NULL:
			#unnamed += 1
			#printerr("NULL morton: Layer %d Node %d" % [h_it.layer, h_it.offset])
	#var err_str = "Completed with %d null mortons%s found" \
					#% [unnamed, "s" if unnamed > 1 else ""]
	#if unnamed:
		#printerr(err_str)
	#else:
		#print(err_str)
		
		
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
	
