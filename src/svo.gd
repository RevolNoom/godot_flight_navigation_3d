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
##
## Side note: This class is @tool to enable working in editor without crashing.
@tool
extends Resource
class_name SVO

const SvoLink64 = preload("res://src/svo_link64.gd")

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

## [Morton3] coordinates
@export var morton: Array[PackedInt64Array] = []

## [SVOLink] to the parent SVONode in the upper layer.
@export var parent: Array[PackedInt64Array] = []

## [SVOLink] to the first of the 8 children SVONode in the lower layer.
@export var first_child: Array[PackedInt64Array] = []

## Subgrid voxels of the deepest SVONode layer.
@export var subgrid: PackedInt64Array = []

## [SVOLink] of X-Positive neighbor
@export var xp: Array[PackedInt64Array] = []

## [SVOLink] of Y-Positive neighbor
@export var yp: Array[PackedInt64Array] = []

## [SVOLink] of Z-Positive neighbor
@export var zp: Array[PackedInt64Array] = []

## [SVOLink] of X-Negative neighbor
@export var xn: Array[PackedInt64Array] = []

## [SVOLink] of Y-Negative neighbor
@export var yn: Array[PackedInt64Array] = []

## [SVOLink] of Z-Negative neighbor
@export var zn: Array[PackedInt64Array] = []

## True if this [SVO] supports inside/outside state query.
@export var support_inside: bool:
	get:
		return inside.size()

## Use [member is_solid()] to determine whether a node is inside or outside an object. [br]
## [b]NOTE:[/b] Although it is possible to pack each inside state as a bit 
## (8 inside states in 1 byte),
## it was thought that the trade off between memory saved 
## and code coherence was not worth it. 
## As such, this array is indexed similarly to other arrays ([member xn], [member yn], [member zn]...).
@export var inside: Array[PackedByteArray] = []

## [b][DEBUG][/b] Flip flags used for solid voxelization,
## in Hierarchical inside/outside propagation step.[br]
## It should be removed after [member FlightNavigation3D.build_navigation_data]
## by enabling [member FlightNavigation3D.debug_delete_flip_flag].
@export var flip: Array[PackedByteArray] = []

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


## Return true iff all exported variables have identical content to [param other].
## This performs a deep structural comparison of all arrays.
func deep_compare(other: SVO) -> bool:
	if other == null:
		return false
	# depth is derived from morton.size(), but check anyway for clarity
	if depth != other.depth:
		return false
	if not _equal_array_of_arrays(morton, other.morton):
		return false
	if not _equal_array_of_arrays(parent, other.parent):
		return false
	if not _equal_array_of_arrays(first_child, other.first_child):
		return false
	if not _equal_array(subgrid, other.subgrid):
		return false
	if not _equal_array_of_arrays(xp, other.xp):
		return false
	if not _equal_array_of_arrays(yp, other.yp):
		return false
	if not _equal_array_of_arrays(zp, other.zp):
		return false
	if not _equal_array_of_arrays(xn, other.xn):
		return false
	if not _equal_array_of_arrays(yn, other.yn):
		return false
	if not _equal_array_of_arrays(zn, other.zn):
		return false
	if not _equal_array_of_arrays(inside, other.inside):
		return false
	if not _equal_array_of_arrays(flip, other.flip):
		return false
	if not _equal_array_of_arrays(coverage, other.coverage):
		return false
	return true


static func _equal_array(a, b) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true


static func _equal_array_of_arrays(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if not _equal_array(a[i], b[i]):
			return false
	return true


## Return the SVONode with [param target_morton] in SVO's [param layer].
## [br]
## If no node with such [param target_morton] exists, return [method SvoLink64.null_link].
func svolink_from_morton(layer: int, target_morton: int) -> int:
	var morton_layer = morton[layer]
	var offset = morton_layer.bsearch(target_morton)
	if offset >= morton_layer.size() or morton_layer[offset] != target_morton:
		return SvoLink64.singleton.null_link()
	return SvoLink64.singleton.create(layer, offset)


## Return the SVOLink corresponding to a subgrid voxel.
## [br]
## If no voxel with such [param target_morton] exists in [member subgrid],
## return [method SvoLink64.null_link].
func svolink_from_voxel_morton(voxel_morton: int) -> int:
	var layer0_morton_idx = voxel_morton >> 6
	var subgrid_idx = voxel_morton & 0b11_1111
	var morton_layer = morton[0]
	var offset = morton_layer.bsearch(layer0_morton_idx)
	if offset >= morton_layer.size() or morton_layer[offset] != layer0_morton_idx:
		return SvoLink64.singleton.null_link()
	return SvoLink64.singleton.create(0, offset, subgrid_idx)

## Return array of neighbors' [SVOLink]s.
## [br]
## [param svolink]: The node whose neighbors need to be found.
func neighbors_of(svolink: int) -> PackedInt64Array:
	var neighbors: PackedInt64Array = []
	var layer = SvoLink64.singleton.get_layer(svolink)
	var offset = SvoLink64.singleton.get_offset(svolink)
	#var linkstr = SvoLink64.singleton.get_format_string(svolink)
	# Get neighbors of subgrid voxel
	if layer == 0:
		var current_svolink_subgrid = SvoLink64.singleton.get_subgrid(svolink)
		
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
				neighbors.push_back(SvoLink64.singleton.set_subgrid(svolink, neighbor_expected_subgrid))
				continue
				
			var neighbor_direction = neighbor_info[1]
			var neighbor_svolink = neighbor_direction[layer][offset]
			# There is no neighbor on this side
			if neighbor_svolink == SvoLink64.singleton.null_link():
				continue
			
			var neighbor_layer = SvoLink64.singleton.get_layer(neighbor_svolink)
			var neighbor_is_not_subgrid_voxel = neighbor_layer > 0
			if neighbor_is_not_subgrid_voxel:
				neighbors.push_back(neighbor_svolink)
				continue
			
			var neighbor_actual_subgrid = neighbor_info[2]
			neighbors.push_back(SvoLink64.singleton.set_subgrid(neighbor_svolink, neighbor_actual_subgrid))
	# Get neighbors of a node
	else:
		# Get voxels on face that is opposite to direction
		# e.g. If neighbor is in positive direction, 
		# then get voxels on negative face of that neighbor
		for neighbor in [[xp, xn], [xn, xp], [yp, yn], [yn, yp], [zp, zn], [zn, zp]]:
			var neighbor_svolink = neighbor[0][layer][offset]
			if neighbor_svolink == SvoLink64.singleton.null_link():
				continue
			var neighbor_face = neighbor[1]
			var smos = _get_voxels_on_face(neighbor_face, neighbor_svolink)
			neighbors.append_array(smos)
			
	return neighbors


## Return true if [param svolink] refers to a solid voxel or a solid node.
func is_solid(svolink: int) -> bool:
	var layer = SvoLink64.singleton.get_layer(svolink)
	var offset = SvoLink64.singleton.get_offset(svolink)
	if layer == 0:
		var subgrid_index = SvoLink64.singleton.get_subgrid(svolink)
		return subgrid[offset] & (1 << subgrid_index)
	return inside[layer][offset] and first_child[layer][offset] == SvoLink64.singleton.null_link()


## Calculate the center of the voxel/node
## where 1 unit distance corresponds to side length of 1 subgrid voxel.
func get_center(svolink: int) -> Vector3:
	var layer = SvoLink64.singleton.get_layer(svolink)
	var offset = SvoLink64.singleton.get_offset(svolink)
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
	if svolink == SvoLink64.singleton.null_link():
		return []
	
	var layer = SvoLink64.singleton.get_layer(svolink)
	var offset = SvoLink64.singleton.get_offset(svolink)
	
	if layer == 0:
		var subgrid_voxels: PackedInt32Array
		if face == xn:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xn"]
		elif face == xp:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"xp"]
		elif face == yn:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"yn"]
		elif face == yp:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"yp"]
		elif face == zn:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"zn"]
		elif face == zp:
			subgrid_voxels = Fn3dLookupTable.subgrid_voxel_indexes_on_face[&"zp"]
		var subgrid_voxel_on_face: PackedInt64Array = []
		subgrid_voxel_on_face.resize(subgrid_voxels.size())
		for i in range(subgrid_voxels.size()):
			subgrid_voxel_on_face[i] = SvoLink64.singleton.set_subgrid(svolink, subgrid_voxels[i]) 
		return subgrid_voxel_on_face
	
	var first_child_svolink = first_child[layer][offset]
	# If this node doesn't have any child
	# Then it makes up the face itself
	if first_child_svolink == SvoLink64.singleton.null_link():
		return [svolink]

	# This vector holds index of 4 children on [param face]
	var children_on_face: PackedInt64Array = \
		[first_child_svolink, first_child_svolink, first_child_svolink, first_child_svolink]
	var children_indexes: PackedInt64Array
	if face == xn:
		children_indexes = Fn3dLookupTable.children_node_by_face[&"xn"]
	elif face == xp:
		children_indexes = Fn3dLookupTable.children_node_by_face[&"xp"]
	elif face == yn:
		children_indexes = Fn3dLookupTable.children_node_by_face[&"yn"]
	elif face == yp:
		children_indexes = Fn3dLookupTable.children_node_by_face[&"yp"]
	elif face == zn:
		children_indexes = Fn3dLookupTable.children_node_by_face[&"zn"]
	elif face == zp:
		children_indexes = Fn3dLookupTable.children_node_by_face[&"zp"]
	
	var voxels_on_face: PackedInt64Array = []
	for i in range(4):
		var children_voxels_on_face = _get_voxels_on_face(face, children_on_face[i] + children_indexes[i])
		voxels_on_face.append_array(children_voxels_on_face)
	
	return voxels_on_face


## Head nodes are nodes without -x neighbors
func _get_list_offset_of_head_node_in_x_direction_of_layer(layer: int) -> PackedInt64Array:
	var list_size = 0
	var xn_layer = xn[layer]
	for i in range(0, xn_layer.size(), 2):
		var xn_layer_neighbor_svolink = xn_layer[i]
		if xn_layer_neighbor_svolink == SvoLink64.singleton.null_link():
			list_size += 1
			continue
		var xn_layer_neighbor_layer = SvoLink64.singleton.get_layer(xn_layer_neighbor_svolink)
		if xn_layer_neighbor_layer > layer:
			list_size += 1
			continue
			
	var list_head_node_offset: PackedInt64Array = []
	list_head_node_offset.resize(list_size)
	list_head_node_offset.resize(0)
	
	# Identify head nodes
	for i in range(0, xn_layer.size(), 2):
		var xn_layer_neighbor_svolink = xn_layer[i]
		if xn_layer_neighbor_svolink == SvoLink64.singleton.null_link():
			list_head_node_offset.push_back(i)
			continue
		var xn_layer_neighbor_layer = SvoLink64.singleton.get_layer(xn_layer_neighbor_svolink)
		if xn_layer_neighbor_layer > layer:
			list_head_node_offset.push_back(i)
			continue
	return list_head_node_offset
	

func parallel_get_list_solid_bit_count_by_subgrid(
	async_context: Signal, 
	thread_priority: Thread.Priority) -> PackedInt64Array:
	var list_solid_bit_count_by_subgrid: PackedInt64Array = \
		subgrid.duplicate()
	list_solid_bit_count_by_subgrid.fill(0)
	await Parallel.execute_batched(
		async_context, 
		list_solid_bit_count_by_subgrid.size(),
		thread_priority,
		100000,
		_parallel_batched_count_solid_bit_by_subgrid.bind(
			subgrid,
			list_solid_bit_count_by_subgrid
			))
	return list_solid_bit_count_by_subgrid


func get_list_solid_bit_count_by_subgrid() -> PackedInt64Array:
	var list_solid_bit_count_by_subgrid: PackedInt64Array = \
		subgrid.duplicate()
	list_solid_bit_count_by_subgrid.fill(0)
	_parallel_batched_count_solid_bit_by_subgrid(
		0,
		0,
		list_solid_bit_count_by_subgrid.size(),
		subgrid,
		list_solid_bit_count_by_subgrid
	)
	return list_solid_bit_count_by_subgrid


static func _parallel_batched_count_solid_bit_by_subgrid(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	svo_subgrid: PackedInt64Array,
	list_solid_bit_count_by_subgrid: PackedInt64Array):
		for layer0_offset in range(batch_start, batch_end):
			list_solid_bit_count_by_subgrid[layer0_offset] = \
				Fn3dUtility.count_bit_1(svo_subgrid[layer0_offset])
	
