## Voxelize all FlightNavigationTarget inside this area
@tool
@warning_ignore_start("integer_division")
extends CSGBox3D
class_name FlightNavigation3D

const SvoLink64 = preload("res://src/svo_link64.gd")

@export var sparse_voxel_octree: SVO

## Pathfinding algorithm used for [method find_path]
@export var pathfinder: FlightPathfinder



## Return a path that connects [param from] and [param to].[br]
## [param from], [param to] are in global coordinate.[br]
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var from_svolink: int = get_svolink_of(from)
	var to_svolink: int = get_svolink_of(to)
	var svolink_path: Array = pathfinder.find_path(
		from_svolink, to_svolink, sparse_voxel_octree)
	var vec3_path = PackedVector3Array()
	vec3_path.resize(svolink_path.size())
	for i in range(svolink_path.size()):
		vec3_path[i] = get_global_position_of(svolink_path[i])
	return vec3_path

#region Build navigation

## Construct an SVO that can be assigned to [member sparse_voxel_octree] later.[br]
## [b]NOTE:[/b] Many build processes can be run at a time.
func build_navigation():
	var list_child_voxelizers: Array[ISvoVoxelizer] = []
	for child in get_children():
		if child is ISvoVoxelizer:
			list_child_voxelizers.push_back(child)
	if list_child_voxelizers.size() != 1:
		printerr(
			"build_navigation() requires exactly 1 child ISvoVoxelizer. Found: %d" %
			list_child_voxelizers.size()
		)
		return

	var voxelized_svo = await list_child_voxelizers[0].voxelize(self)
	sparse_voxel_octree = voxelized_svo


#region Utility function

## Return true when two morton codes belong to different parents.
## Kept here for compatibility with existing tests.
static func _mortons_different_parent(
	morton_a: int,
	morton_b: int) -> bool:
	return (morton_a >> 3) != (morton_b >> 3)


## Return global position of center of the node or subgrid voxel identified as [param svolink].[br]
## [member sparse_voxel_octree] must not be null.[br]
func get_global_position_of(svolink: int) -> Vector3:
	var voxel_size = calculate_node_size(size, -2, sparse_voxel_octree.depth)
	var layer = SvoLink64.singleton.get_layer(svolink)
	var offset = SvoLink64.singleton.get_offset(svolink)
	
	var morton_code = sparse_voxel_octree.morton[layer][offset]
	if layer == 0:
		var voxel_morton = (morton_code << 6) | SvoLink64.singleton.get_subgrid(svolink)#sparse_voxel_octree.subgrid[offset]
		var half_a_voxel = Vector3(0.5, 0.5, 0.5)
		return global_transform * (
			(Morton3.decode_vec3(voxel_morton) + half_a_voxel) 
			* voxel_size + morton_origin_offset())
	
	var half_a_node = Vector3(0.5, 0.5, 0.5)
	var result = global_transform\
			* (
				(Morton3.decode_vec3(morton_code) + half_a_node)
			 	* calculate_node_size(size, layer, sparse_voxel_octree.depth) 
				+ morton_origin_offset()
			)
	return result


## Return [SVOLink] of the smallest node/voxel at [param gposition].
## [br]
## [b]NOTE:[/b] Positions exactly on a face might be mislocated
## to different node/voxel due to floating-point inaccuracy.
## [br]
## [param gposition]: Global position that needs conversion to [SVOLink].
func get_svolink_of(gposition: Vector3) -> int:
	var local_pos = to_local(gposition) - morton_origin_offset()
	var extent: Vector3 = size
	var aabb := AABB(Vector3.ZERO, extent)
	
	# Points outside Navigation Space
	if not aabb.has_point(local_pos):
		return SvoLink64.singleton.null_link()
	
	var link_layer := sparse_voxel_octree.depth - 1
	var link_offset:= 0
	
	# Descend the tree layer by layer
	while link_layer > 0:
		var first_child = sparse_voxel_octree.first_child[link_layer][link_offset]
		if first_child == SvoLink64.singleton.null_link():
			return SvoLink64.singleton.create(link_layer, link_offset)

		link_offset = SvoLink64.singleton.get_offset(first_child)
		link_layer -= 1
		
		var aabb_center := aabb.position + aabb.size/2
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
			
		aabb = AABB(new_pos, aabb.size/2)
	
	# Return the subgrid voxel that encloses @position
	var subgridv = (local_pos - aabb.position) * 4 / aabb.size
	return SvoLink64.singleton.create(0, link_offset, Morton3.encode64v(subgridv))
	
#endregion

#region Helper functions

## Return the corner position where morton index starts counting
func morton_origin_offset() -> Vector3:
	return -size/2
	
## Return the size (in local meter) of a node at [param layer]
static func calculate_node_size(
	flight_navigation_size: Vector3, 
	layer: int, 
	svo_depth: int) -> Vector3:
	return flight_navigation_size * (2.0 ** (layer - svo_depth + 1))


func _initialize_debug_draw_multimesh():
	var debug_draw_svonode = $DebugDraw/SVONode
	var debug_draw_voxel = $DebugDraw/Voxel
	for multimesh_instance in debug_draw_svonode.get_children():
		debug_draw_svonode.remove_child(multimesh_instance)
		multimesh_instance.queue_free()
	
	if sparse_voxel_octree == null:
		return
		
	var voxel_size: Vector3 = calculate_node_size(size, -2, sparse_voxel_octree.depth)
		
	for layer in range(sparse_voxel_octree.depth):
		var boxmesh = BoxMesh.new()
		boxmesh.size = calculate_node_size(size, layer, sparse_voxel_octree.depth)\
			* 0.95
		boxmesh.material = StandardMaterial3D.new()
		boxmesh.material.albedo_color = Color(
			1*(layer+1)/sparse_voxel_octree.depth,
			randf(),
			1-(layer+1)/sparse_voxel_octree.depth)
			
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TransformFormat.TRANSFORM_3D
		multimesh.mesh = boxmesh
		
		var multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.multimesh = multimesh
		
		debug_draw_svonode.add_child(multimesh_instance)
	
	debug_draw_voxel.multimesh.instance_count = 0
	debug_draw_voxel.multimesh.transform_format = MultiMesh.TransformFormat.TRANSFORM_3D
	
	debug_draw_voxel.multimesh.mesh.size = voxel_size\
			* 0.95
	#debug_draw_voxel.multimesh.mesh.material = StandardMaterial3D.new()
	#debug_draw_voxel.multimesh.mesh.material.albedo_color = Color(1, 1, 1, 0.1)
	

## Draw a box represents the space occupied by an [SVONode] identified as [param svolink].[br]
## 
## Return a reference to the box. [br] 
##
## Gives [param text] a custom value to insert a label in the center of the box.
## null for default value of [method SvoLink64.get_format_string].[br]
##
## [b]NOTE:[/b]: [member sparse_voxel_octree] must not be null.[br]
func draw_svolink_box(svolink: int, 
		node_color: Color = Color.RED, 
		leaf_color: Color = Color.GREEN,
		text = null) -> MeshInstance3D:
	var voxel_size: Vector3 = calculate_node_size(size, -2, sparse_voxel_octree.depth)
	
	var cube = MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	var label = Label3D.new()
	cube.add_child(label)
	
	cube.mesh.material = StandardMaterial3D.new()
	cube.mesh.material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
	label.text = text if text != null else SvoLink64.singleton.get_format_string(svolink)
			
	var layer = SvoLink64.singleton.get_layer(svolink)
	var offset = SvoLink64.singleton.get_offset(svolink)
	
	# Draw voxel
	if layer == 0 and not(sparse_voxel_octree.support_inside
		and sparse_voxel_octree.inside[layer][offset]):
		cube.mesh.size = voxel_size
		cube.mesh.material.albedo_color = leaf_color
		label.pixel_size = voxel_size.x / 400
	# Draw node
	else:
		cube.mesh.size = calculate_node_size(size, layer, sparse_voxel_octree.depth)
		cube.mesh.material.albedo_color = node_color
		label.pixel_size = calculate_node_size(size, layer, sparse_voxel_octree.depth).x / 400
	cube.mesh.material.albedo_color.a = 0.2
	
	$SVOLinkCubes.add_child(cube)
	cube.global_position = get_global_position_of(svolink) #+ Vector3(1, 0, 0)
	return cube


## Draw all solid voxels, solid nodes there are
func draw():
	_initialize_debug_draw_multimesh()
	await draw_solid_voxels()
	
	if not sparse_voxel_octree.support_inside:
		return
		
	var multi_threading_enabled = true
	var multi_threading_priority = Thread.PRIORITY_LOW
	var child_voxelizer_count = 0
	for child in get_children():
		if child is ISvoVoxelizer:
			child_voxelizer_count += 1
			if child_voxelizer_count == 1:
				multi_threading_enabled = \
					child.get_is_multithreading_enabled()
				multi_threading_priority = \
					child.get_multithreading_priority()
	if child_voxelizer_count != 1:
		multi_threading_enabled = true
		multi_threading_priority = Thread.PRIORITY_LOW

	var async_context: Signal = get_tree().process_frame
	
	var draw_flag_by_layer: Array[PackedByteArray] = []
	draw_flag_by_layer.resize(sparse_voxel_octree.depth)
	for layer in range(draw_flag_by_layer.size()):
		draw_flag_by_layer[layer] = PackedByteArray()
		draw_flag_by_layer[layer].resize(sparse_voxel_octree.inside[layer].size())
		draw_flag_by_layer[layer].fill(0)
		
	for layer in range(1, draw_flag_by_layer.size()):
		for offset in range(draw_flag_by_layer[layer].size()):
			draw_flag_by_layer[layer][offset] = int(
				sparse_voxel_octree.is_solid(SvoLink64.singleton.create(layer, offset)))
	
	
	var debug_draw_node = $DebugDraw/SVONode
	var origin_offset = morton_origin_offset()
	
	# TODO: Parallel.wait_all()
	for layer in range(1, sparse_voxel_octree.depth):
		var node_size: Vector3 = calculate_node_size(size, layer, sparse_voxel_octree.depth)
		var multimesh: MultiMesh = debug_draw_node.get_child(layer).multimesh
		
		var count_result = await Parallel.count_by_batch(
				async_context,
				multi_threading_priority,
				draw_flag_by_layer[layer],
				1
			)
		
		var list_solid_node_count_by_batch: PackedInt64Array = count_result.list_count_by_batch
		var batch_size: int = count_result.batch_size
		
		var total_instance_count: int = Fn3dUtility.sum_number_array(list_solid_node_count_by_batch)
		
		var list_start_write_index: PackedInt64Array = \
			Parallel.make_start_write_index_array_from_count_array(
				list_solid_node_count_by_batch)
		
		# Allocate memory
		multimesh.instance_count = total_instance_count
		
		if multi_threading_enabled:
			await Parallel.execute_batched(
					async_context,
					draw_flag_by_layer[layer].size(),
					multi_threading_priority,
					batch_size,
					_parallel_batched_write_node_transforms.bind(
						layer,
						draw_flag_by_layer,
						sparse_voxel_octree,
						multimesh,
						node_size,
						origin_offset,
						list_start_write_index,
					))
		else:
			for i in range(draw_flag_by_layer[layer].size()):
				var batch_index = i/batch_size
				_parallel_batched_write_node_transforms(
					batch_index, i*batch_size, 
					mini((i+1)*batch_size, draw_flag_by_layer[layer].size()),
					layer,
					draw_flag_by_layer,
					sparse_voxel_octree,
					multimesh,
					node_size,
					origin_offset,
					list_start_write_index,
				)


func draw_solid_voxels():
	if sparse_voxel_octree == null:
		printerr(str(get_path()) + ".sparse_voxel_octree is null")
		return
		
	var multi_threading_enabled = true
	var multi_threading_priority = Thread.PRIORITY_LOW
	var child_voxelizer_count = 0
	for child in get_children():
		if child is ISvoVoxelizer:
			child_voxelizer_count += 1
			if child_voxelizer_count == 1:
				multi_threading_enabled = \
					child.get_is_multithreading_enabled()
				multi_threading_priority = \
					child.get_multithreading_priority()
	if child_voxelizer_count != 1:
		multi_threading_enabled = true
		multi_threading_priority = Thread.PRIORITY_LOW

	var async_context: Signal = get_tree().process_frame
	
	var list_solid_bit_count_by_subgrid: PackedInt64Array = []
	if multi_threading_enabled:
		list_solid_bit_count_by_subgrid = \
			await sparse_voxel_octree.parallel_get_list_solid_bit_count_by_subgrid(
				async_context, multi_threading_priority)
	else:
		list_solid_bit_count_by_subgrid = \
			sparse_voxel_octree.get_list_solid_bit_count_by_subgrid()
			
	var total_solid_bit_count: int = Fn3dUtility.sum_number_array(list_solid_bit_count_by_subgrid)
	
	var list_start_write_index: PackedInt64Array = \
			Parallel.make_start_write_index_array_from_count_array(
				list_solid_bit_count_by_subgrid)
	
	var list_voxel_transform: Array[Transform3D] = []
	list_voxel_transform.resize(total_solid_bit_count)
	
	var voxel_size = calculate_node_size(size, -2, sparse_voxel_octree.depth)
	
	if multi_threading_enabled:
		await Parallel.execute_batched(
			async_context, 
			sparse_voxel_octree.subgrid.size(),
			multi_threading_priority,
			100000,
			_parallel_batched_write_subgrid_voxel_transforms.bind(
				sparse_voxel_octree.subgrid,
				sparse_voxel_octree.morton[0],
				voxel_size,
				-size/2,
				list_start_write_index,
				list_voxel_transform))
	else:
		_parallel_batched_write_subgrid_voxel_transforms(
			0,
			0,
			sparse_voxel_octree.subgrid.size(),
			sparse_voxel_octree.subgrid,
			sparse_voxel_octree.morton[0],
			voxel_size,
			-size/2,
			list_start_write_index,
			list_voxel_transform)
	var debug_draw_voxel = $DebugDraw/Voxel
	debug_draw_voxel.multimesh.instance_count = total_solid_bit_count
	
	if multi_threading_enabled:
		await Parallel.execute_batched(
			async_context, 
			total_solid_bit_count,
			multi_threading_priority,
			100000,
			_parallel_batched_write_multimesh_instance_transforms.bind(
				debug_draw_voxel.multimesh,
				list_voxel_transform))
	else:
		_parallel_batched_write_multimesh_instance_transforms(
			0,
			0,
			total_solid_bit_count,
			debug_draw_voxel.multimesh,
			list_voxel_transform)


func _ready():
	var list_child_voxelizers: Array[ISvoVoxelizer] = []
	for child in get_children():
		if child is ISvoVoxelizer:
			list_child_voxelizers.push_back(child)
	if list_child_voxelizers.size() != 1:
		return
	var voxelizer = list_child_voxelizers[0]


static func _parallel_batched_write_subgrid_voxel_transforms(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	svo_subgrid: PackedInt64Array,
	svo_morton_layer0: PackedInt64Array,
	voxel_size: Vector3,
	origin_offset: Vector3,
	list_start_write_index: PackedInt64Array,
	list_voxel_transform: Array[Transform3D]
):
	var node_0_size: Vector3 = voxel_size * 4
	for layer0_offset in range(batch_start, batch_end):
		if svo_subgrid[layer0_offset] == 0:
			continue
		var start_write_index: int = list_start_write_index[layer0_offset]
		var node_position: Vector3 = origin_offset + \
			node_0_size * Morton3.decode_vec3(svo_morton_layer0[layer0_offset])
		var solid_voxel_count: int = 0
		for voxel_index in range(64):
			if svo_subgrid[layer0_offset] & (1<<voxel_index):
				var voxel_position_offset: Vector3 = voxel_size * (Morton3.decode_vec3(voxel_index) + Vector3(0.5,0.5,0.5))
				var voxel_final_position: Vector3 = node_position + voxel_position_offset
				var write_index: int = start_write_index + solid_voxel_count
				list_voxel_transform[write_index] = Transform3D(Basis(), voxel_final_position)
				solid_voxel_count += 1


static func _parallel_batched_write_node_transforms(
	batch_index: int,
	batch_start: int,
	batch_end: int,
	layer: int,
	draw_flag_by_layer: Array[PackedByteArray],
	svo: SVO,
	multimesh: MultiMesh,
	node_size: Vector3,
	origin_offset: Vector3,
	list_start_write_index: PackedInt64Array,
):
	var solid_node_count = 0
	var start_write_index = list_start_write_index[batch_index]
	for offset in range(batch_start, batch_end):
		if not draw_flag_by_layer[layer][offset]:
			continue
		var node_position = node_size\
			* (Morton3.decode_vec3(svo.morton[layer][offset]) 
				+ Vector3(0.5, 0.5, 0.5))\
			+ origin_offset
		var write_index = start_write_index + solid_node_count
		multimesh.set_instance_transform(write_index, 
			Transform3D(Basis(), node_position))
		solid_node_count += 1


static func _parallel_batched_write_multimesh_instance_transforms(
	_batch_index: int,
	batch_start: int,
	batch_end: int,
	multimesh: MultiMesh,
	list_transform: Array[Transform3D]
):
	for index in range(batch_start, batch_end):
		multimesh.set_instance_transform(index, list_transform[index])
	
#endregion

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if !is_root_shape():
		warnings.append("Must be a root CSG shape to calculate mesh correctly")
	if sparse_voxel_octree == null:
		warnings.push_back("No valid SVO resource found. Try voxelize it in editor or call build_navigation() from script.")
	var child_voxelizer_count = 0
	for child in get_children():
		if child is ISvoVoxelizer:
			child_voxelizer_count += 1
	if child_voxelizer_count > 1:
		warnings.push_back("More than one child ISvoVoxelizer found. build_navigation() will not work due to ambiguity. If this is intended, you must manually call ISvoVoxelizer.voxelize() of one of the child and reassign the result.")
	return warnings
