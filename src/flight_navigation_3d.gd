## Voxelize all FlightNavigationTarget inside this area
@tool
@warning_ignore_start("integer_division")
extends CSGBox3D
class_name FlightNavigation3D

@export var sparse_voxel_octree: SVO

## Pathfinding algorithm used for [method find_path]
@export var pathfinder: FlightPathfinder


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

	var voxelized_svo = await list_child_voxelizers[0].voxelize(self)
	sparse_voxel_octree = voxelized_svo


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

	var voxel_size = calculate_node_size(size, -2, sparse_voxel_octree.depth)
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
		var half_a_voxel: Vector3 = Vector3(0.5, 0.5, 0.5)
		return global_transform * (
			(Morton3.decode_vec3(voxel_morton) + half_a_voxel) *
			voxel_size +
			morton_origin_offset()
		)

	var half_a_node: Vector3 = Vector3(0.5, 0.5, 0.5)
	var result: Vector3 = global_transform * (
		(Morton3.decode_vec3(morton_code) + half_a_node) *
		calculate_node_size(size, layer, sparse_voxel_octree.depth) +
		morton_origin_offset()
	)
	return result


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
	var extent: Vector3 = size
	var aabb := AABB(Vector3.ZERO, extent)

	# Points outside Navigation Space
	if not aabb.has_point(local_pos):
		return SvoLink64.singleton.null_link()

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

		var aabb_center := aabb.position + aabb.size / 2
		var new_pos := aabb.position

		if local_pos.x >= aabb_center.x:
			link_offset |= 0b001
			new_pos.x = aabb_center.x

		if local_pos.y >= aabb_center.y:
			link_offset |= 0b010
			new_pos.y = aabb_center.y

		if local_pos.z >= aabb_center.z:
			link_offset |= 0b100
			new_pos.z = aabb_center.z

		aabb = AABB(new_pos, aabb.size / 2)

	if link_offset < 0 or link_offset >= sparse_voxel_octree.morton[0].size():
		return SvoLink64.singleton.null_link()

	# Return the subgrid voxel that encloses @position
	var subgridv: Vector3 = (local_pos - aabb.position) * 4.0 / aabb.size
	var subgrid_x: int = clampi(floori(subgridv.x), 0, 3)
	var subgrid_y: int = clampi(floori(subgridv.y), 0, 3)
	var subgrid_z: int = clampi(floori(subgridv.z), 0, 3)
	var subgrid_morton: int = Morton3.encode64(subgrid_x, subgrid_y, subgrid_z)
	return SvoLink64.singleton.create(0, link_offset, subgrid_morton)


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

	var child_voxelizer_count := 0
	for child in get_children():
		if child is ASvoVoxelizer:
			child_voxelizer_count += 1
	if child_voxelizer_count > 1:
		warnings.push_back(
			"More than one child ASvoVoxelizer found. build_navigation() will not work due to ambiguity. If this is intended, you must manually call ASvoVoxelizer.voxelize() of one of the child and reassign the result."
		)

	var child_visualizer_count := 0
	for child in get_children():
		if child is ASvoVisualizer:
			child_visualizer_count += 1
	if child_visualizer_count == 0:
		warnings.push_back("No child ASvoVisualizer found. draw() will do nothing.")
	if child_visualizer_count > 1:
		warnings.push_back(
			"More than one child ASvoVisualizer found. draw() will call all visualizers."
		)

	return warnings
