## Mark an object to be voxelized by [FlightNavigation3D]
@tool
extends Node3D
class_name VoxelizationTarget

## There could be many [FlightNavigation3D] in one scene, 
## and you might decide that some targets will voxelize
## in one [FlightNavigation3D] but not the others.
##
## If [FlightNavigation3D]'s mask overlaps with at least
## one bit of [VoxelizationTarget] mask, its shapes will 
## be considered for voxelization.
@export_flags_3d_navigation var voxelization_mask: int

## Used for [CSGShape3D] generation of:[br]
## - [SphereShape3D]/[SphereMesh] [br]
## - [CylinderShape3D]/[CylinderMesh] [br]
@export var radial_segments: int = 16

## Used for [CSGShape3D] generation of:[br]
## - [SphereShape3D]/[SphereMesh] [br]
@export var rings: int = 8


## Return all shapes that would be Voxelized.
func get_csg() -> Array[CSGShape3D]:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return []
	var list_csg: Array[CSGShape3D] = []
	if parent_node is CollisionObject3D:
		list_csg = _get_csg_collision_object_3d(parent_node)
	elif parent_node is CollisionShape3D:
		list_csg = _get_csg_collision_shape_3d(parent_node)
	elif parent_node is MeshInstance3D:
		list_csg = _get_csg_mesh_instance_3d(parent_node)
	elif parent_node is MultiMeshInstance3D: # TODO
		list_csg = _get_csg_multimesh_instance_3d(parent_node)
	elif parent_node is CSGShape3D:
		list_csg = [parent_node] # TODO: Do we need to duplicate() this parent and its children?
	# NOTE: The engine defers calculating CSG operations until they are visible.
	# As such, all csg must be visible.
	#for csg in list_csg:
		#csg.visible = false
	return list_csg


## Return CSG shapes from all CollisionShape3D children
func _get_csg_collision_object_3d(collision_object: CollisionObject3D) -> Array[CSGShape3D]:
	var result: Array[CSGShape3D] = []
	for child in collision_object.get_children():
		var collision_shape := child as CollisionShape3D
		if collision_shape == null:
			continue
		result.append_array(_get_csg_collision_shape_3d(collision_shape))
	return result


## Return a CSG shape that best describes this collision shape.
## The Combiner takes global transform of its parent.
## The real shape takes local transform relative to its parent
func _get_csg_collision_shape_3d(collision_shape: CollisionShape3D) -> Array[CSGShape3D]:
	var csg: CSGShape3D = null
	var shape: Shape3D = collision_shape.shape
	if shape == null:
		return []
	if shape is BoxShape3D:
		var box_shape := shape as BoxShape3D
		csg = CSGBox3D.new()
		csg.size = box_shape.size
	elif shape is ConvexPolygonShape3D:
		var convex_shape := shape as ConvexPolygonShape3D
		csg = CSGMesh3D.new()
		csg.mesh = MeshTool.create_array_mesh_from_faces(convex_shape.get_debug_mesh().get_faces())
	elif shape is ConcavePolygonShape3D:
		var concave_shape := shape as ConcavePolygonShape3D
		csg = CSGMesh3D.new()
		csg.mesh = MeshTool.create_array_mesh_from_faces(concave_shape.get_faces())
	elif shape is SphereShape3D:
		var sphere_shape := shape as SphereShape3D
		csg = CSGSphere3D.new()
		csg.radial_segments = radial_segments
		csg.radius = sphere_shape.radius
		csg.rings = rings
		csg.smooth_faces = false
	elif shape is CapsuleShape3D:
		var capsule_shape := shape as CapsuleShape3D
		csg = CSGCombiner3D.new()
		
		var cylinder = CSGCylinder3D.new()
		cylinder.radius = capsule_shape.radius
		# A capsule height is the total height of the shape.
		# Formula: Capsule height = 2 * shape.radius + Cylinder height.
		# Constraint: Capsule height >= 2 * shape.radius.
		# If the constraint is violated:
		# either the radius will be shortened,
		# or the height will be lengthened,
		# whichever happens is based on which attribute the user edit on the editors.
		# Rest assured that CapsuleShape3D has validated this constraint for us.
		cylinder.height = max(0.0, capsule_shape.height - 2.0 * capsule_shape.radius)
		cylinder.sides = radial_segments
		cylinder.smooth_faces = false
		
		var sphere_begin = CSGSphere3D.new()
		sphere_begin.radius = capsule_shape.radius
		sphere_begin.radial_segments = radial_segments
		sphere_begin.rings = rings
		sphere_begin.smooth_faces = false
		sphere_begin.position.y = -cylinder.height/2
		
		var sphere_end = CSGSphere3D.new()
		sphere_end.radius = capsule_shape.radius
		sphere_end.radial_segments = radial_segments
		sphere_end.rings = rings
		sphere_end.smooth_faces = false
		sphere_end.position.y = +cylinder.height/2
		
		csg.add_child(cylinder)
		csg.add_child(sphere_begin)
		csg.add_child(sphere_end)
		
	elif shape is CylinderShape3D:
		var cylinder_shape := shape as CylinderShape3D
		csg = CSGCylinder3D.new()
		csg.height = cylinder_shape.height
		csg.radius = cylinder_shape.radius
		csg.sides = radial_segments
		csg.smooth_faces = false

	if csg == null:
		return []
	csg.global_transform = collision_shape.global_transform
	return [csg]
	

func _get_csg_mesh_instance_3d(mesh_instance: MeshInstance3D) -> Array[CSGShape3D]:
	if mesh_instance.mesh == null:
		return []
	var csg_array = _get_csg_from_mesh(mesh_instance.mesh)
	for csg in csg_array:
		csg.global_transform = mesh_instance.global_transform
	return csg_array


# TODO:
func _get_csg_multimesh_instance_3d(multimesh: MultiMeshInstance3D) -> Array[CSGShape3D]:
	#var csg: CSGShape3D = _get_csg_from_mesh(multimesh.mesh)
	return []


func _get_csg_from_mesh(mesh: Mesh) -> Array[CSGShape3D]:
	if mesh == null:
		return []
	var csg: CSGShape3D = null
	if mesh is BoxMesh:
		var box_mesh := mesh as BoxMesh
		csg = CSGBox3D.new()
		csg.size = box_mesh.size
	elif mesh is SphereMesh:
		var sphere_mesh := mesh as SphereMesh
		csg = CSGSphere3D.new()
		csg.radial_segments = radial_segments
		csg.radius = sphere_mesh.radius
		csg.rings = rings
		csg.smooth_faces = false
	elif mesh is CapsuleMesh:
		var capsule_mesh := mesh as CapsuleMesh
		csg = CSGCombiner3D.new()
		
		var cylinder = CSGCylinder3D.new()
		cylinder.radius = capsule_mesh.radius
		# A capsule height is the total height of the shape.
		# Formula: Capsule height = 2 * shape.radius + Cylinder height.
		# Constraint: Capsule height >= 2 * shape.radius.
		# If the constraint is violated:
		# either the radius will be shortened,
		# or the height will be lengthened,
		# whichever happens is based on which attribute the user edit on the editors.
		# Rest assured that CapsuleShape3D has validated this constraint for us.
		cylinder.height = max(0.0, capsule_mesh.height - 2.0 * capsule_mesh.radius)
		cylinder.sides = radial_segments
		cylinder.smooth_faces = false
		
		var sphere_begin = CSGSphere3D.new()
		sphere_begin.radius = capsule_mesh.radius
		sphere_begin.radial_segments = radial_segments
		sphere_begin.rings = rings
		sphere_begin.smooth_faces = false
		sphere_begin.position.y = -cylinder.height/2
		
		var sphere_end = CSGSphere3D.new()
		sphere_end.radius = capsule_mesh.radius
		sphere_end.radial_segments = radial_segments
		sphere_end.rings = rings
		sphere_end.smooth_faces = false
		sphere_end.position.y = +cylinder.height/2
		
		csg.add_child(cylinder)
		csg.add_child(sphere_begin)
		csg.add_child(sphere_end)
		
	elif mesh is CylinderMesh:
		var cylinder_mesh := mesh as CylinderMesh
		csg = CSGCylinder3D.new()
		csg.height = cylinder_mesh.height
		csg.radius = cylinder_mesh.radius
		csg.sides = radial_segments
		csg.smooth_faces = false
	elif mesh is ArrayMesh:
		csg = CSGMesh3D.new()
		csg.mesh = mesh
	## TODO: NOT YET SUPPORTED
	#elif mesh is PlaneMesh:
		#csg = CSGPolygon3D.new()
	# UNSUPPORTED
	#elif mesh is PointMesh:
		#return []
	## TODO: NOT YET SUPPORTED
	#elif mesh is PrismMesh:
		#csg = CSGPolygon3D.new()
	## TODO: NOT YET SUPPORTED
	#elif mesh is RibbonTrailMesh:
		#csg = CSGPolygon3D.new()
	## TODO: NOT YET SUPPORTED
	#elif mesh is TextMesh:
		#csg = CSGPolygon3D.new()
	elif mesh is TorusMesh:
		var torus_mesh := mesh as TorusMesh
		csg = CSGTorus3D.new()
		csg.inner_radius = torus_mesh.inner_radius
		csg.outer_radius = torus_mesh.outer_radius
		csg.ring_sides = torus_mesh.ring_segments
		csg.sides = torus_mesh.rings
		csg.smooth_faces = false
	## TODO: NOT YET SUPPORTED
	#elif mesh is TubeTrailMesh:
		#csg = CSGPolygon3D.new()
	if csg == null:
		return []
	return [csg]


static func _is_supported_parent_node(parent_node: Node) -> bool:
	return parent_node is CollisionObject3D \
		or parent_node is CollisionShape3D \
		or parent_node is MeshInstance3D \
		or parent_node is MultiMeshInstance3D \
		or parent_node is CSGShape3D


static func _is_supported_collision_shape(shape: Shape3D) -> bool:
	if shape == null:
		return false
	return shape is BoxShape3D \
		or shape is ConvexPolygonShape3D \
		or shape is ConcavePolygonShape3D \
		or shape is SphereShape3D \
		or shape is CapsuleShape3D \
		or shape is CylinderShape3D


static func _is_supported_mesh(mesh: Mesh) -> bool:
	if mesh == null:
		return false
	return mesh is BoxMesh \
		or mesh is SphereMesh \
		or mesh is CapsuleMesh \
		or mesh is CylinderMesh \
		or mesh is ArrayMesh \
		or mesh is TorusMesh


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var parent_node: Node = get_parent()
	if parent_node == null or not _is_supported_parent_node(parent_node):
		warnings.push_back("Parent node does not support voxelization.")
	elif parent_node is CollisionShape3D:
		var collision_shape := parent_node as CollisionShape3D
		if not _is_supported_collision_shape(collision_shape.shape):
			warnings.push_back("Collision shape is null or unsupported for voxelization.")
	elif parent_node is MeshInstance3D:
		var mesh_instance := parent_node as MeshInstance3D
		if not _is_supported_mesh(mesh_instance.mesh):
			warnings.push_back("Mesh is null or unsupported for voxelization.")
	if not transform.is_equal_approx(Transform3D.IDENTITY):
		warnings.push_back("Transform should be default.")
	return warnings
