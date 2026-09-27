## Voxelize all FlightNavigationTarget inside this area
@tool
@warning_ignore_start("integer_division")
extends CSGBox3D
class_name FlightNavigation3D

@export var sparse_voxel_octree: SVO

## Pathfinding algorithm used for [method find_path]
@export var pathfinder: AFlightPathFinder


## Return a path that connects [param from] and [param to].[br]
## [param from], [param to] are in global coordinate.[br]
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if sparse_voxel_octree == null:
		printerr("FlightNavigation3D.find_path(): sparse_voxel_octree is null.")
		return []
	if pathfinder == null:
		printerr("FlightNavigation3D.find_path(): pathfinder is null.")
		return []

	var from_svolink: int = get_svolink_of(from)
	var to_svolink: int = get_svolink_of(to)
	if from_svolink == SvoLink64.singleton.null_link() \
		or to_svolink == SvoLink64.singleton.null_link():
		return []
	if sparse_voxel_octree.is_solid(from_svolink) \
		or sparse_voxel_octree.is_solid(to_svolink):
		return []

	var svolink_path: PackedInt64Array = pathfinder.find_path(
		from_svolink,
		to_svolink,
		sparse_voxel_octree
	)
	var vec3_path: PackedVector3Array = []
	vec3_path.resize(svolink_path.size())
	for i in range(svolink_path.size()):
		vec3_path[i] = get_global_position_of(svolink_path[i])
	return vec3_path


#region Build navigation

## Construct an SVO that can be assigned to [member sparse_voxel_octree] later.[br]
## [b]NOTE:[/b] Many build processes can be run at a time.
func build_navigation():
	var list_child_voxelizers: Array[ASvoVoxelizer] = _get_child_voxelizers()
	if list_child_voxelizers.size() != 1:
		printerr(
			"build_navigation() requires exactly 1 child ASvoVoxelizer. Found: %d" %
			list_child_voxelizers.size()
		)
		return

	sparse_voxel_octree = await list_child_voxelizers[0].voxelize(self)


## Draw all child [ASvoVisualizer] using [member sparse_voxel_octree].
func draw():
	if sparse_voxel_octree == null:
		printerr(str(get_path()) + ".sparse_voxel_octree is null")
		return

	var list_child_visualizers: Array[Node] = _get_child_visualizers()
	if list_child_visualizers.is_empty():
		printerr("No child ASvoVisualizer found under " + str(get_path()))
		return

	for visualizer in list_child_visualizers:
		await visualizer.draw(self)


#endregion

#region Utility function


## Return global position of center of the node or subgrid voxel identified as [param svolink].[br]
## [member sparse_voxel_octree] must not be null.[br]
func get_global_position_of(svolink: int) -> Vector3:
	if sparse_voxel_octree == null:
		printerr("FlightNavigation3D.get_global_position_of(): sparse_voxel_octree is null.")
		return Vector3.ZERO
	if svolink == SvoLink64.singleton.null_link():
		return Vector3.ZERO

	var voxel_size: Vector3 = calculate_node_size(size, -2, sparse_voxel_octree.depth)
	var layer: int = SvoLink64.singleton.get_layer(svolink)
	if layer < 0 or layer >= sparse_voxel_octree.depth:
		printerr("FlightNavigation3D.get_global_position_of(): layer out of bounds.")
		return Vector3.ZERO
	var offset: int = SvoLink64.singleton.get_offset(svolink)
	if offset < 0 or offset >= sparse_voxel_octree.morton[layer].size():
		printerr("FlightNavigation3D.get_global_position_of(): offset out of bounds.")
		return Vector3.ZERO

	var morton_code: int = sparse_voxel_octree.morton[layer][offset]
	if layer == 0:
		var voxel_morton: int = (morton_code << 6) | \
			SvoLink64.singleton.get_subgrid(svolink)
		return global_transform * (
			(Morton3.decode_vec3(voxel_morton) + Vector3(0.5, 0.5, 0.5)) *
			voxel_size +
			morton_origin_offset()
		)

	return global_transform * (
		(Morton3.decode_vec3(morton_code) + Vector3(0.5, 0.5, 0.5)) *
		calculate_node_size(size, layer, sparse_voxel_octree.depth) +
		morton_origin_offset()
	)


## Return [SVOLink] of the smallest node/voxel at [param gposition].
## [br]
## [b]NOTE:[/b] Positions exactly on a face might be mislocated
## to different node/voxel due to floating-point inaccuracy.
## [br]
## [param gposition]: Global position that needs conversion to [SVOLink].
func get_svolink_of(gposition: Vector3) -> int:
	if sparse_voxel_octree == null:
		printerr("FlightNavigation3D.get_svolink_of(): sparse_voxel_octree is null.")
		return SvoLink64.singleton.null_link()
	if sparse_voxel_octree.depth <= 0:
		printerr("FlightNavigation3D.get_svolink_of(): sparse_voxel_octree.depth must be > 0.")
		return SvoLink64.singleton.null_link()

	var local_pos: Vector3 = to_local(gposition) - morton_origin_offset()
	var aabb: AABB = AABB(Vector3.ZERO, size)

	# Points outside Navigation Space
	if not aabb.has_point(local_pos):
		return SvoLink64.singleton.null_link()

	return _descend_to_layer_zero(local_pos, aabb)


## Descend the octree to layer zero to locate the enclosing node or leaf.[br]
## [param local_pos]: Position relative to morton origin[br]
## [param aabb]: Bounding box of the current octree volume[br]
## Return: SVOLink of the enclosing leaf node or subgrid voxel[br]
func _descend_to_layer_zero(local_pos: Vector3, aabb: AABB) -> int:
	var link_layer: int = sparse_voxel_octree.depth - 1
	var link_offset: int = 0

	# Descend the tree layer by layer
	while link_layer > 0:
		if link_offset < 0 or link_offset >= sparse_voxel_octree.first_child[link_layer].size():
			return SvoLink64.singleton.null_link()
		var first_child: int = sparse_voxel_octree.first_child[link_layer][link_offset]
		if first_child == SvoLink64.singleton.null_link():
			return SvoLink64.singleton.create(link_layer, link_offset)

		link_offset = SvoLink64.singleton.get_offset(first_child)
		link_layer -= 1

		var child_octant: ChildOctantResult = _select_child_octant(local_pos, aabb, link_offset)
		link_offset = child_octant.offset
		aabb = AABB(child_octant.position, aabb.size / 2.0)

	if link_offset < 0 or link_offset >= sparse_voxel_octree.morton[0].size():
		return SvoLink64.singleton.null_link()

	var subgrid_morton: int = _calculate_subgrid_voxel_morton(local_pos, aabb)
	return SvoLink64.singleton.create(0, link_offset, subgrid_morton)


## Encapsulates the updated sub-AABB origin position and child link offset.
class ChildOctantResult:
	var position: Vector3
	var offset: int

	func _init(p_position: Vector3, p_offset: int) -> void:
		position = p_position
		offset = p_offset


## Select child octant containing [param local_pos], returning updated position and offset.[br]
## [param local_pos]: Position relative to morton origin[br]
## [param aabb]: Bounding box of the current octree node[br]
## [param link_offset]: First child link offset[br]
## Return: [ChildOctantResult] containing updated position and offset[br]
func _select_child_octant(local_pos: Vector3, aabb: AABB, link_offset: int) -> ChildOctantResult:
	var aabb_center: Vector3 = aabb.position + aabb.size / 2.0
	var new_pos: Vector3 = aabb.position
	var updated_offset: int = link_offset

	if local_pos.x >= aabb_center.x:
		updated_offset |= 0b001
		new_pos.x = aabb_center.x

	if local_pos.y >= aabb_center.y:
		updated_offset |= 0b010
		new_pos.y = aabb_center.y

	if local_pos.z >= aabb_center.z:
		updated_offset |= 0b100
		new_pos.z = aabb_center.z

	return ChildOctantResult.new(new_pos, updated_offset)


## Calculate the morton index of a subgrid voxel within a layer 0 node.[br]
## [param local_pos]: Position relative to morton origin[br]
## [param aabb]: Bounding box of the layer 0 node[br]
## Return: Morton code of the subgrid voxel[br]
func _calculate_subgrid_voxel_morton(local_pos: Vector3, aabb: AABB) -> int:
	var subgridv: Vector3 = (local_pos - aabb.position) * 4.0 / aabb.size
	return Morton3.encode64(
		clampi(floori(subgridv.x), 0, 3),
		clampi(floori(subgridv.y), 0, 3),
		clampi(floori(subgridv.z), 0, 3)
	)


#endregion

#region Helper functions

func _get_child_voxelizers() -> Array[ASvoVoxelizer]:
	var list_child_voxelizers: Array[ASvoVoxelizer] = []
	for child in get_children():
		if child is ASvoVoxelizer:
			list_child_voxelizers.push_back(child)
	return list_child_voxelizers


func _get_child_visualizers() -> Array[Node]:
	var list_child_visualizers: Array[Node] = []
	for child in get_children():
		if child is ASvoVisualizer:
			list_child_visualizers.push_back(child)
	return list_child_visualizers


## Return the corner position where morton index starts counting
func morton_origin_offset() -> Vector3:
	return -size / 2


## Return the size (in local meter) of a node at [param layer].
## Note: This function is made static to be used safely in asynchronous context.
static func calculate_node_size(
	flight_navigation_size: Vector3,
	layer: int,
	svo_depth: int) -> Vector3:
	return flight_navigation_size * (2.0 ** (layer - svo_depth + 1))


#endregion

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not is_root_shape():
		warnings.append("Must be a root CSG shape to calculate mesh correctly")
	if sparse_voxel_octree == null:
		warnings.push_back(
			"No valid SVO resource found. Try voxelize it in editor or call build_navigation() from script."
		)

	var child_voxelizers: Array[ASvoVoxelizer] = _get_child_voxelizers()
	if child_voxelizers.size() > 1:
		warnings.push_back(
			"More than one child ASvoVoxelizer found. build_navigation() will not work due to ambiguity. If this is intended, you must manually call ASvoVoxelizer.voxelize() of one of the child and reassign the result."
		)

	var child_visualizers: Array[Node] = _get_child_visualizers()
	if child_visualizers.is_empty():
		warnings.push_back("No child ASvoVisualizer found. draw() will do nothing.")
	elif child_visualizers.size() > 1:
		warnings.push_back(
			"More than one child ASvoVisualizer found. draw() will call all visualizers."
		)

	return warnings
