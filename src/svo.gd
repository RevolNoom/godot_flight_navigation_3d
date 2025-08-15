## Sparse Voxel Octree is a data structure used to contain solid state of 
## volumes in 3D space.
##
## Sparse Voxel Octree contains solid/free state of space. It has the following features:
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
## solid/free state. You must always reconstruct it, using FlightNavigation3D.[br]
## - Current implementation only do a surface voxelization. 
## It means SVO only knows whether a position is On The Surface of an object.
## SVO doesn't know whether a position is inside an object. [br]
## [br][br]
## [b]HISTORICAL: DATA STRUCTURE[/b]
## [br][br]
## SVO has had 2 reworks on data structures. 
## This section talks about the historical ways, 
## and explain the new way data is structured and accessed.
## [br][br]
## The first attempt was to extend RefCounted to create SVONode class.
## SVONode contains 10 int member variables (morton, parent, first_child,...).
## Each SVO layer is stored into an Array[SVONode]. 
## SVO stores all layers into another array (Array[Array[SVONode]]).
## [br]
## However, the (thought of) drawbacks were:
## [br]
## - Memory allocation: Billions of separate SVONode memory allocations 
## would terribly fragments physical memory. 
## Furthermore, RefCounted is not a primitive data type, which means an SVONode
## will consume more memory than 10 ints, more than it should. 
## (This drawback comes from thought analysis, not profiling)
## [br]
## - Data access: Each data access requires 3 pointer chases:
## tree -> layer -> SVONode. Although SVONodes are contiguous in Layer array, 
## their memory allocation might be scattered randomly in memory, 
## which might not play nice with physical cache. (Thought analysis)
## [br]
## - Serialization: SVONode is a custom type, 
## serialization into .tres files isn't support out of the box.
## [br][br]
## The second attempt was to expand SVONode into 10 ints. 
## Previously, if layer 5 is an array of 100 SVONodes, then now it becomes a
## PackedIntArray of length 100 * 10 = 1000. This solves 
## Memory Allocation (all ints are contiguously stored, no extra memory needed),
## Data access (only 2 pointer chases: tree -> layer), 
## and Serialization (PackedIntArray supports serialization by Godot).
## [br]
## The drawback, however, is that it makes code more difficult to debug, 
## and indexing is awkward without using iterator.
## [br][br]
## The newest attempt tackle the problem by spliting a tree of Array[Array[SVONode]]
## into many trees of Array[PackedIntArray], each tree specifically stores 1 attribute
## of SVONode.
## [br]
## For example, tree[2][3].xn accesses x-negative neighbor of the 3rd SVONode on layer 2,
## are now accessed using xn[2][3]. 
## [br]
## Most attributes (neighbors, morton, parent) have the same dimensions 
## (if morton[2][3] exists, then xn[2][3] exists). The different attributes are
## [member first_child] and [member subgrid].
## [br]
## SVONodes in the deepest layer has no SVONode children. They contain voxels instead. 
## As such, an empty array [] is assigned as placeholder for first_child[0],
## and subgrid[34] contains the subgrid voxel mask for tree[0][34].

extends Resource
class_name SVO

## The number of SVONode layers of the tree (doesn't count subgrid voxel layers). [br]
##
## Higher depth rasterizes collision shapes in more details,
## but also consumes more memory. Each layer adds upto 
## 8 times more memory consumption.
## (But thought analysis says it is only about 4 times).[br]
##
## [b]NOTE:[/b] This value is read-only. Used for editor convenience.[br]
@export var depth: int:
	get:
		return morton.size()

## [class Morton3] coordinate of this node in the octree.
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


## Return all subgrid voxels which has morton code coordinate
## equals to some of [param v]'s x, y, z components.
## [br]
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


## Indexes of subgrid voxel that makes up a face of a layer-0 node
## e.g. face_subgrid[Face.X_NEG] for all indexes of voxel on negative-x face
static var _face_subgrid: Dictionary[StringName, PackedInt64Array] = {
	"xn": _get_subgrid_voxels_where_component_equals(Vector3i(0, -1, -1)),
	"xp": _get_subgrid_voxels_where_component_equals(Vector3i(3, -1, -1)),
	"yn": _get_subgrid_voxels_where_component_equals(Vector3i(-1, 0, -1)),
	"yp": _get_subgrid_voxels_where_component_equals(Vector3i(-1, 3, -1)),
	"zn": _get_subgrid_voxels_where_component_equals(Vector3i(-1, -1, 0)),
	"zp": _get_subgrid_voxels_where_component_equals(Vector3i(-1, -1, 3)),
}


static func shift_to_svolink_index_field(list_index: PackedInt64Array) -> PackedInt64Array:
	var new_list: PackedInt64Array = []
	new_list.resize(list_index.size())
	for i in range(new_list.size()):
		new_list[i] = list_index[i] << 6
	return new_list


## Each face of a node has 4 children. Their indexes are listed here.
## Each index are shifted 6 bits to be added to SVOLink index field directly 
static var _children_node_by_face: Dictionary[StringName, PackedInt64Array] = {
	"xn": shift_to_svolink_index_field([0, 2, 4, 6]),
	"xp": shift_to_svolink_index_field([1, 3, 5, 7]),
	"yn": shift_to_svolink_index_field([0, 1, 4, 5]),
	"yp": shift_to_svolink_index_field([2, 3, 6, 7]),
	"zn": shift_to_svolink_index_field([0, 1, 2, 3]),
	"zp": shift_to_svolink_index_field([4, 5, 6, 7]),
}


## Return all highest-resolution voxels that make up the face of node [param svolink][br]
func _get_voxels_on_face(
	face: Array[PackedInt64Array], # SVO.nx/ny/nz/px/py/pz
	svolink: int) -> PackedInt64Array:
	if svolink == SVOLink.NULL:
		return []
	
	var layer = SVOLink.layer(svolink)
	var offset = SVOLink.offset(svolink)
	
	if layer == 0:
		var face_subgrid: PackedInt64Array
		if face == xn:
			face_subgrid = _face_subgrid["xn"]
		elif face == xp:
			face_subgrid = _face_subgrid["xp"]
		elif face == yn:
			face_subgrid = _face_subgrid["yn"]
		elif face == yp:
			face_subgrid = _face_subgrid["yp"]
		elif face == zn:
			face_subgrid = _face_subgrid["zn"]
		elif face == zp:
			face_subgrid = _face_subgrid["zp"]
		var subgrid_voxel_on_face: PackedInt64Array = []
		subgrid_voxel_on_face.resize(face_subgrid.size())
		for i in range(face_subgrid.size()):
			subgrid_voxel_on_face[i] = SVOLink.set_subgrid(face_subgrid[i], svolink) 
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
		children_indexes = _children_node_by_face["xn"]
	elif face == xp:
		children_indexes = _children_node_by_face["xp"]
	elif face == yn:
		children_indexes = _children_node_by_face["yn"]
	elif face == yp:
		children_indexes = _children_node_by_face["yp"]
	elif face == zn:
		children_indexes = _children_node_by_face["zn"]
	elif face == zp:
		children_indexes = _children_node_by_face["zp"]
	
	var voxels_on_face: PackedInt64Array = []
	for i in range(4):
		var children_voxels_on_face = _get_voxels_on_face(face, children_on_face[i] + children_indexes[i])
		voxels_on_face.append_array(children_voxels_on_face)
	
	return voxels_on_face


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
	
