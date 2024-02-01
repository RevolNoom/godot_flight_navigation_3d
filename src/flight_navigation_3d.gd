## Voxelize [CollisionObject3D] that enters this area
##
## [b]Warning:[/b] [param monitoring] and [param monitorable] must be kept on 
## to detect [StaticBody3D] and [Area3D]
@tool
extends Area3D
class_name FlightNavigation3D

## Emitted when voxelize() or voxelize_async() finishes
signal finished()

# TODO: Specialize Triangle-box overlap test for these cases:
# - One-voxel thick bounding box
# - Dominant normal axis (3 possible voxels/column)

# TODO: Support more type of shapes
# ConvexPolygonShape3D
# HeightMap3D
# SeparationRay3D
# WorldBoundaryShape3D

## TODO: Bake geometry & save to files
#@export_file() var bakedFile: String = ""

## Set the max depth of rasterization process.[br]
##
## Higher depth rasterizes collision shapes in more details,
## but also consumes more memory.[br]
##
## Each layer adds roughly 8 times more memory consumption.[br]
##
## [b]WARNING:[/b] Try to use a tree as shallow as possible to avoid crashing the game.
@export_range(2, 16)\
		var max_depth: int = 2:
				set(value):
						max_depth = clampi(value, 2, 16)
						leaf_cube_size = 0
						notify_property_list_changed()


## Node with pathfinding algorithm used for [method find_path]
@export_node_path("FlightPathfinder") var pathfinder


## [b]NOTE:[/b] This value is readonly.
## Modifying it has no effect on the construction of the tree.[br]
##
## An indication of how small the finest voxel is going to be.[br]
## [b]TODO:[/b] Create a small MeshInstance box in the corner of the voxelize
## area for illustration
@export var leaf_cube_size : float = 0.0:
	get: 
		return _node_size(-2)


func _ready():
	$Extent/DebugVisual.mesh.size = $Extent.shape.size
	_recalculate_cached_data()
	

## Expensive, should call only once when all CollisionShapes are registered[br]
## [br]
## [b]WARNING:[/b] Do Not call on _ready(), because physic engine have not processed this node yet.
## Try [method call_deferred] or set a [Timer] to wait for physics first.[br]
## [br]
## [b]NOTE:[/b] This function is computationally expensive,
## which could freeze the game for a while.
func voxelize():
	_voxelize()
	finished.emit()


var _background_voxelize_thread: Thread
## Like [method voxelize], but doesn't block the main thread.
## emit [signal finished] on complete
func voxelize_async():
	_background_voxelize_thread = Thread.new()
	_background_voxelize_thread.start(_voxelize_async, Thread.PRIORITY_LOW)

## Return a path that connects [param from] and [param to][br]
## [param from], [param to] are in global coordinate.[br]
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var svolink_path: Array = (get_node(pathfinder) as FlightPathfinder).find_path(get_svolink_of(from), get_svolink_of(to), _svo)
	return svolink_path.map(func (link) -> Vector3:
		return get_global_position_of(link))


#func find_path_async(from: Vector3, to: Vector3, ...) -> PackedVector3Array:
#	return []

#################################

func _voxelize():
	var act1node_triangles = _determine_act1nodes()
	var svo = SVO.new(max_depth, act1node_triangles.keys())
	_voxelize_tree(svo, act1node_triangles)
	_svo = svo

func _voxelize_async():
	_voxelize()
	call_deferred("emit_signal", "finished")

############################

func _get_box_faces(collision_shape: CollisionShape3D) -> PackedVector3Array:
	var box = BoxMesh.new()
	box.size = collision_shape.shape.size
	var arr_mesh = ArrayMesh.new()
	var ma = box.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	
	return _convert_to_local_transform_in_place(collision_shape, arr_mesh.get_faces())


# TODO: Maybe there should be a way to dynamically increase triangle counts for sphere?
func _get_sphere_faces(collision_shape: CollisionShape3D) -> PackedVector3Array:
	var sphere = SphereMesh.new()
	var shape = collision_shape.shape as SphereShape3D
	sphere.height = shape.radius*2
	sphere.radius = shape.radius
	var arr_mesh = ArrayMesh.new()
	var ma = sphere.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	return _convert_to_local_transform_in_place(collision_shape, arr_mesh.get_faces())
	
	
# TODO: Maybe there should be a way to dynamically increase triangle counts for cylinder?
func _get_cylinder_faces(collision_shape: CollisionShape3D) -> PackedVector3Array:
	var cylinder = CylinderMesh.new()
	var shape = collision_shape.shape as CylinderShape3D
	cylinder.height = shape.height
	cylinder.top_radius = shape.radius
	cylinder.bottom_radius = shape.radius
	var arr_mesh = ArrayMesh.new()
	var ma = cylinder.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	return _convert_to_local_transform_in_place(collision_shape, arr_mesh.get_faces())
	

# TODO: Maybe there should be a way to dynamically increase triangle counts for capsule?
func _get_capsule_faces(collision_shape: CollisionShape3D) -> PackedVector3Array:
	var capsule = CapsuleMesh.new()
	var shape = collision_shape.shape as CapsuleShape3D
	capsule.height = shape.height
	capsule.radius = shape.radius
	var arr_mesh = ArrayMesh.new()
	var ma = capsule.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	return _convert_to_local_transform_in_place(collision_shape, arr_mesh.get_faces())


## [b]TODO:[/b] There's no class or method of Godot that I know of that can create
## an ArrayMesh from a ConvexPolygonShape3D
func _get_polygon_faces(_collision_shape: CollisionShape3D) -> PackedVector3Array:
	return []
	#return _convert_to_local_transform_in_place(collision_shape, polymesh.get_faces())


# Convert [param out_triangles] (in-place) from collision_shape's transform 
# to [FlightNavigation3D]'s transform.[br]
# Return reference to [param out_triangles]
func _convert_to_local_transform_in_place(
	collision_shape: CollisionShape3D, 
	out_triangles: PackedVector3Array) -> PackedVector3Array:
		var mesh_to_navspace: \
		Transform3D = _origin_global_transform_inv \
					* collision_shape.global_transform
	
		for i in range(0, out_triangles.size()):
			out_triangles[i] = mesh_to_navspace * out_triangles[i]
		return out_triangles


# Return dictionary associating Morton codes of active nodes with triangles overlapping them
func _determine_act1nodes() -> Dictionary:
	var act1node_triangles: Dictionary = {}
	var node1_size = _node_size(1)
	for collision_shape in _overlapping_shapes:
		var faces = []
		if collision_shape.shape is BoxShape3D:
			faces = _get_box_faces(collision_shape) 
		elif collision_shape.shape is ConvexPolygonShape3D:
			printerr("[FlightNavigation3D]: ConvexPolygonShape3D is not yet supported for voxelization")
			#faces = _get_polygon_faces(collision_shape)
		elif collision_shape.shape is ConcavePolygonShape3D:
			faces = _convert_to_local_transform_in_place(collision_shape, 
						collision_shape.shape.get_faces())
		elif collision_shape.shape is SphereShape3D:
			faces = _get_sphere_faces(collision_shape)
		elif collision_shape.shape is CapsuleShape3D:
			faces = _get_capsule_faces(collision_shape)
		elif collision_shape.shape is CylinderShape3D:
			faces = _get_cylinder_faces(collision_shape)
		
		_merge_triangle_overlap_node_dicts(act1node_triangles, 
			_voxelize_polygon(node1_size, faces))
			
	return act1node_triangles

# Return dictionary of key - value: Active node morton code - Overlapping triangles.[br]
# Overlapping triangles are serialized. Every 3 elements make up a triangle.[br]
# [param polygon] is assumed to have length divisible by 3. Every 3 elements make up a triangle.[br]
# [b]NOTE:[/b] This method allocates one thread per triangle
func _voxelize_polygon(vox_size: float, polygon_faces: PackedVector3Array) -> Dictionary:
	var result = {}
	var threads: Array[Thread] = []
	# Using roundf() to avoid integer division warning
	threads.resize(polygon_faces.size() / 3)
	threads.resize(0)
	for i in range(0, polygon_faces.size(), 3):
		threads.push_back(Thread.new())
		threads.back().start(
			_voxelize_triangle.bind(vox_size, polygon_faces.slice(i, i+3)), 
			Thread.PRIORITY_LOW)
			
	for thread in threads:
		_merge_triangle_overlap_node_dicts(result, thread.wait_to_finish())
	return result


# Return dictionary of key - value: Active node morton code - Array of 3 Vector3 (vertices of [param triangle])[br]
func _voxelize_triangle(vox_size: float, triangle: PackedVector3Array) -> Dictionary:
	var result = {}
	var tbt = TriangleBoxTest.new(triangle, Vector3(1,1,1) * vox_size)
	var vox_range: Array[Vector3i] = _voxels_overlapped_by_aabb(vox_size, tbt.aabb, _extent_size)
		
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				if tbt.overlap_voxel(Vector3(x, y, z) * vox_size):
					var vox_morton = Morton3.encode64(x, y, z)
					if result.has(vox_morton):
						result[vox_morton].append_array(triangle)
					else:
						result[vox_morton] = triangle
	return result

# Merge information of triangles overlapping a node from [param append] to [param base].[br]
#
# Both [param base] and [param append] are dictionaries of Key - Value: 
# Morton code - Array of vertices, every 3 elements make a triangle.[br]
#
# [b]NOTE:[/b] Duplicated triangles are not removed from [param base].
func _merge_triangle_overlap_node_dicts(base: Dictionary, append: Dictionary) -> void:
	for key in append.keys():
		if base.has(key):
			base[key].append_array(append[key])
		else:
			base[key] = append[key].duplicate()


# Return two Vector3i as bounding box for a range of voxels that's intersection
# between FlyingNavigation3D and [param t_aabb].[br]
# 
# The first vector (begin) contains the start voxel index (inclusive), 
# the second vector (end) is the end index (exclusive). [br]
#
# (end - begin) is non-negative. [br]
# 
# The voxel range is inside FlyingNavigation3D area.[br]
#
# The result includes also voxels merely touched by t_aabb.[br]
# [param size] is the side length of a voxel.[br]
# [param t_aabb] is the triangle's AABB.[br]
# [param vox_bound] clamps the result between 0 and [param vox_bound]/[param size] (exclusive)
func _voxels_overlapped_by_aabb(size: float, t_aabb: AABB, vox_bound: Vector3) -> Array[Vector3i]:
	# Begin & End
	var b = t_aabb.position/size
	var e = t_aabb.end/size
	var vb = vox_bound/size
	
	# Include voxels merely touched by t_aabb
	b.x = b.x - (1 if b.x == round(b.x) else 0)
	b.y = b.y - (1 if b.y == round(b.y) else 0)
	b.z = b.z - (1 if b.z == round(b.z) else 0)
	
	e.x = e.x + (1 if e.x == round(e.x) else 0)
	e.y = e.y + (1 if e.y == round(e.y) else 0)
	e.z = e.z + (1 if e.z == round(e.z) else 0)
	
	# Clamp to fit inside Navigation Space
	b = b.clamp(Vector3(), vb).floor()
	e = e.clamp(Vector3(), vb).ceil()
	
	return [b, e]


# Allocate each layer-1 node with 1 thread.[br]
# For each thread, sequentially test triangle overlapping with each of 8 layer-0 child node.[br]
# For each layer-0 child node overlapped by triangle, launch a thread to voxelize subgrid.[br]
func _voxelize_tree(svo: SVO, act1node_triangles: Dictionary):
	var a1t_keys = act1node_triangles.keys()
	var threads: Array[Thread] = []
	threads.resize(a1t_keys.size())
	threads.resize(0)
	
	for key in a1t_keys:
		threads.push_back(Thread.new())
		threads.back().start(
			_voxelize_tree_node0.bind(svo, key, act1node_triangles[key]),
			Thread.PRIORITY_LOW)
	
	for t in threads:
		t.wait_to_finish()


func _voxelize_tree_node0(svo: SVO, node1_morton: int, triangles: PackedVector3Array):
	var node0size = _node_size(0)
	var node1size = _node_size(1) 
	
	var node1pos = Morton3.decode_vec3(node1_morton) * node1size
	var node0s: Array[SVO.SVONode] = []
	node0s.resize(8)
	var node0pos: PackedVector3Array = []
	node0pos.resize(8)
	for m in range(8):
		node0s[m] = svo.node_from_morton(0, (node1_morton << 3) | m)
		node0pos[m] = node1pos + Morton3.decode_vec3(m) * node0size
		
	for i in range(0, triangles.size(), 3):
		var triangle = triangles.slice(i, i+3)
		var triangle_node0_test = TriangleBoxTest.new(triangle, Vector3(1,1,1) * _node_size(0))
		var triangle_voxel_test = TriangleBoxTest.new(triangle, Vector3(1,1,1) * leaf_cube_size)
		for m in range(8):
			if triangle_node0_test.overlap_voxel(node0pos[m]):
					_voxelize_tree_leaves(triangle_voxel_test, node0s[m], node0pos[m])
		# Note: I think one thread per subgrid is overkill
		# I have a feeling that creating too many threads might cause
		# adverse effect than boosting performance
		#var threads: Array[Thread] = []
		#var triangle = triangles.slice(i, i+3)
		#
		## Node layer 0 - Triangle Test
		#var tbt0 = TriangleBoxTest.new(triangle, Vector3(1,1,1) * _node_size(0))
		#
		## Leaf voxel - Triangle Test
		#var tbtl = TriangleBoxTest.new(triangle, Vector3(1,1,1) * leaf_cube_size)
		#
		#for m in range(8):
			#if tbt0.overlap_voxel(node0pos[m]):
				#threads.push_back(Thread.new())
				#threads.back().start(
					#_voxelize_tree_leaves.bind(tbtl, node0s[m], node0pos[m]),
					#Thread.PRIORITY_LOW)
						#
		#for thread in threads:
			#thread.wait_to_finish()


func _voxelize_tree_leaves(tbtl: TriangleBoxTest, node0: SVO.SVONode, node0pos: Vector3):
	var node0_solid_state: int = node0.first_child
	
	var node0size = Vector3.ONE * _node_size(0)
	var node0aabb = AABB(node0pos, node0size)
	var intersection = tbtl.aabb.intersection(node0aabb)
	intersection.position -= node0pos
	var vox_range = _voxels_overlapped_by_aabb(leaf_cube_size, intersection, node0size)
	
	for x in range(vox_range[0].x, vox_range[1].x):
		for y in range(vox_range[0].y, vox_range[1].y):
			for z in range(vox_range[0].z, vox_range[1].z):
				var morton = Morton3.encode64(x,y,z)
				var vox_offset = Vector3(x,y,z) * leaf_cube_size
				var leaf_pos = node0pos+vox_offset
				if (node0_solid_state & (1 << morton) == 0)\
					and tbtl.overlap_voxel(leaf_pos):
						node0_solid_state |= 1<<morton
	node0.first_child = node0_solid_state


# Return global position of center of the node or subgrid voxel identified as [param svolink]
func get_global_position_of(svolink: int) -> Vector3:
	var layer = SVOLink.layer(svolink)
	var node = _svo.node_from_link(svolink)
	if _svo.is_subgrid_voxel(svolink):
		var voxel_morton = (node.morton << 6) | SVOLink.subgrid(svolink)
		return (Morton3.decode_vec3(voxel_morton) + Vector3.ONE*0.5) * leaf_cube_size\
				+ _extent_origin
		
	return (Morton3.decode_vec3(node.morton) + Vector3.ONE*0.5) * _node_size(layer)\
			+ _extent_origin


#TODO: @return_closest_node: determine what to return if navspace doesn't encloses @gposition
# if false, return SVOLink.NULL
# if true, return the closest node 
## Return [SVOLink] of the smallest node/voxel at [param gposition].[br]
## [param gposition]: Global position that needs conversion to [SVOLink].[br]
func get_svolink_of(gposition: Vector3, return_closest_node: bool = false) -> int:
	var local_pos = to_local(gposition) - _extent_origin
	var extent = _extent_size.x
	var aabb := AABB(Vector3.ZERO, Vector3.ONE*extent)
	
	# Points outside Navigation Space
	## TODO: Return the closest node
	if not aabb.has_point(local_pos):
		#print("Position: %v -> null" % position)
		return SVOLink.NULL
	
	var link_layer := _svo._nodes.size()-1
	var link_offset:= 0
	
	# Descend the tree layer by layer
	while link_layer > 0:
		var this_node_link = SVOLink.from(link_layer, link_offset, 0)
		var this_node = _svo.node_from_link(this_node_link)
		if this_node.first_child == SVOLink.NULL:
			return this_node_link

		link_offset = SVOLink.offset(this_node.first_child)
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
	
	# If code reaches here, it means we have descended down to layer 0 already
	# If the layer 0 node is free space, return it
	if _svo.node_from_offset(0, link_offset).subgrid == SVO.SVONode.EMPTY_SUBGRID:
		return SVOLink.from(0, link_offset, 0)
	
	# else, return the subgrid voxel that encloses @position
	var subgridv = (local_pos - aabb.position) * 4 / aabb.size
	return SVOLink.from(0, link_offset, Morton3.encode64v(subgridv))

############## DEBUGS #######################

## Draw a box represents the space occupied by an [SVONode] identified as [param svolink].[br]
## 
## Return a reference to the box. [br] 
##
## Gives [param text] a custom value to insert a label in the center of the box.
## null for default value of [method SVOLink.get_format_string].[br]
func draw_svolink_box(svolink: int, 
		node_color: Color = Color.RED, 
		leaf_color: Color = Color.GREEN,
		text = null) -> MeshInstance3D:
	var cube = MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	var label = Label3D.new()
	cube.add_child(label)
	
	var layer = SVOLink.layer(svolink)
	var node = _svo.node_from_link(svolink)
	cube.mesh.material = StandardMaterial3D.new()
	cube.mesh.material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
	label.text = text if text != null else SVOLink.get_format_string(svolink, _svo)
			
	if layer == 0 and node.first_child != 0:
		cube.mesh.size = Vector3.ONE * leaf_cube_size
		cube.mesh.material.albedo_color = leaf_color
		label.pixel_size = leaf_cube_size / 400
	else:
		cube.mesh.size = Vector3.ONE * _node_size(layer)
		cube.mesh.material.albedo_color = node_color
		label.pixel_size = _node_size(layer) / 400
	cube.mesh.material.albedo_color.a = 0.2
	
	$Origin/SVOLinkCubes.add_child(cube)
	cube.global_position = get_global_position_of(svolink) #+ Vector3(1, 0, 0)
	return cube
	

## BUG: When SVO is passed empty act1nodes for construction, SVO consists
## of only 1 giant voxel
## This function incorrectly draws 1 subgrid voxel instead of the whole big space
func draw_debug_boxes():
	for cube in $Origin/DebugCubes.get_children():
		cube.queue_free()
	var node0_size = _node_size(0)
	
	var threads: Array[Thread] = []
	threads.resize(_svo._nodes[0].size())
	threads.resize(0)
	var cube_pos : Array[PackedVector3Array] = []
	cube_pos.resize(_svo._nodes[0].size())
	for i in range(_svo._nodes[0].size()):
		threads.push_back(Thread.new())
		threads.back().start(
			_collect_cubes.bind(_svo._nodes[0][i], cube_pos, i, node0_size),
			Thread.PRIORITY_LOW)
	for thread in threads:
		thread.wait_to_finish()
	
	var all_pos: PackedVector3Array = []
	for pv3a in cube_pos:
		all_pos.append_array(pv3a)
		
	$Origin/DebugCubes.multimesh.mesh.size = leaf_cube_size * Vector3(1,1,1)
	$Origin/DebugCubes.multimesh.instance_count = all_pos.size()
		
	for i in range(all_pos.size()):
		$Origin/DebugCubes.multimesh.set_instance_transform(i, 
			Transform3D(Basis(), all_pos[i]))


func _collect_cubes(
	node0: SVO.SVONode, 
	cube_pos: Array[PackedVector3Array],
	i: int,
	node0_size: float):
	cube_pos[i] = PackedVector3Array([])
	var node_pos = node0_size * Morton3.decode_vec3(node0.morton)
	for vox in range(64):
		if node0.first_child & (1<<vox):
			var offset = leaf_cube_size * (Morton3.decode_vec3(vox) + Vector3(0.5,0.5,0.5))
			var pos = node_pos + offset
			cube_pos[i].push_back(pos)


############## CONFIG WARNINGS ##############

func _get_configuration_warnings():
	var warnings: PackedStringArray = []
	if not $Extent.shape is BoxShape3D:
		warnings.push_back("Extent must be BoxShape3D.")
	var s = $Extent.shape.size
	if s.x != s.y or s.y != s.z:
		warnings.push_back("Extent's side lengths must be equal. Make Extent a cube.")
	
	if not monitorable:
		warnings.push_back("'monitorable' should be turned on, or else StaticBodies won't be detected.")
	
	if not monitoring:
		warnings.push_back("'monitoring' must be turned on to detect bodies and areas.")
		
	return warnings


func _on_property_list_changed():
	update_configuration_warnings()

##############

func _node_size(layer: int) -> float:
	return _extent_size.x * (2.0 ** (-max_depth + 1 + layer))

var _svo: SVO

# The most (x, y, z) negative corner of $Extent. It's cached here to be used in threads.
var _extent_origin := Vector3()

# $Extent.shape.size. It's cached here to be used in threads.
var _extent_size:= Vector3()

# $Origin.global_transform.inverse(). It's cached here to be used in threads.
var _origin_global_transform_inv: Transform3D

func _recalculate_cached_data():
	$Origin.position = - $Extent.shape.size/2
	_extent_origin = $Origin.position
	_extent_size = $Extent.shape.size
	_origin_global_transform_inv = $Origin.global_transform.inverse()
	
	
func _on_extent_property_list_changed():
	_recalculate_cached_data()


# Contains the collision shapes currently overlapping
# Multithreading forbids calling get_children(), so this is used instead
var _overlapping_shapes: Array[CollisionShape3D] = []

# On multithreading call, we can't access the scene tree through get_children()
# As such, the overlapping CollisionShape3Ds must be monitored at all times
func _on_body_shape_entered(_body_rid, body, body_shape_index, _local_shape_index):
	_on_shape_entered(body, body_shape_index)
	
	
# On multithreading call, we can't access the scene tree through get_children()
# As such, the overlapping CollisionShape3Ds must be monitored at all times
func _on_body_shape_exited(_body_rid, body, body_shape_index, _local_shape_index):
	_on_shape_exited(body, body_shape_index)


# On multithreading call, we can't access the scene tree through get_children()
# As such, the overlapping CollisionShape3Ds must be monitored at all times
func _on_area_shape_entered(_area_rid, area, area_shape_index, _local_shape_index):
	_on_shape_entered(area, area_shape_index)


# On multithreading call, we can't access the scene tree through get_children()
# As such, the overlapping CollisionShape3Ds must be monitored at all times
func _on_area_shape_exited(_area_rid, area, area_shape_index, _local_shape_index):
	_on_shape_exited(area, area_shape_index)


func _on_shape_entered(collision_object, collision_object_shape_index):
	var shape_owner = collision_object.shape_find_owner(collision_object_shape_index)
	var shape_node = collision_object.shape_owner_get_owner(shape_owner)
	_overlapping_shapes.append(shape_node)


func _on_shape_exited(collision_object, collision_object_shape_index):
	var shape_owner = collision_object.shape_find_owner(collision_object_shape_index)
	var shape_node = collision_object.shape_owner_get_owner(shape_owner)
	_overlapping_shapes.erase(shape_node)
