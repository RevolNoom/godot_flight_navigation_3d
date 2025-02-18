## Mark an object to be voxelized by FlightNavigation3D
@tool
extends Node3D
class_name VoxelizationTarget

## There could be many FlightNavigation3D in one scene, 
## and you might decide that some targets will voxelize
## in one FlightNavigation3D but not the others.
##
## If FlightNavigation3D's mask overlaps with at least
## one bit of VoxelizationTarget mask, its shapes will 
## be considered for Voxelization.
@export_flags_3d_navigation var voxelization_mask: int

## Used for CSGShape3D generation of:[br]
## - SphereShape3D/Mesh [br]
## - CylinderShape3D/Mesh [br]
@export var radial_segments = 64

## Used for CSGShape3D generation of:[br]
## - SphereShape3D/Mesh [br]
@export var rings = 32

var _parent: 
	get():
		return get_parent()


## Return all shapes that would be Voxelized.
func get_csg() -> Array[CSGShape3D]:
	if _parent == null:
		return []
	if _parent is CollisionObject3D:
		return _get_csg_collision_object_3d(_parent)
	elif _parent is CollisionShape3D:
		return _get_csg_collision_shape_3d(_parent)
	elif _parent is MeshInstance3D:
		return _get_csg_mesh_instance_3d(_parent)
	elif _parent is MultiMeshInstance3D: # TODO
		return _get_csg_multimesh_instance_3d(_parent)
	elif _parent is CSGShape3D:
		return [_parent] # TODO: Do we need to duplicate() this parent and its children?
	return []


## Return CSG shapes from all CollisionShape3D children
func _get_csg_collision_object_3d(collision_object: CollisionObject3D) -> Array[CSGShape3D]:
	var collision_shapes = collision_object\
		.get_children()\
		.filter(func (child): return child is CollisionShape3D)
	var result: Array[CSGShape3D] = []
	for collision_shape in collision_shapes:
		result.append_array(_get_csg_collision_shape_3d(collision_shape))
	return result


## Return a CSG shape that best describes this collision shape
## TODO: Wrap a Combiner on all shapes.
## The Combiner takes global transform of its parent.
## The real shape takes local transform relative to its parent
func _get_csg_collision_shape_3d(collision_shape: CollisionShape3D) -> Array[CSGShape3D]:
	var csg: CSGShape3D = null
	var shape = collision_shape.shape
	if shape is BoxShape3D:
		csg = CSGBox3D.new()
		csg.size = shape.size
	elif shape is ConvexPolygonShape3D:
		csg = CSGMesh3D.new()
		csg.mesh = MeshTool.create_array_mesh_from_faces(shape.get_debug_mesh().get_faces())
	elif shape is ConcavePolygonShape3D:
		csg = CSGMesh3D.new()
		csg.mesh = MeshTool.create_array_mesh_from_faces(shape.get_faces())
	elif shape is SphereShape3D:
		csg = CSGSphere3D.new()
		csg.radial_segments = radial_segments
		csg.radius = shape.radius
		csg.rings = rings
		csg.smooth_faces = false
	elif shape is CapsuleShape3D: #TODO
		# With CapsuleShape3D, we need 3 CSG: 2 spheres on both ends, and a body
		csg = CSGCombiner3D.new()
	elif shape is CylinderShape3D:
		csg = CSGCylinder3D.new()
		csg.height = shape.height
		csg.radius = shape.radius
		csg.sides = radial_segments
		csg.smooth_faces = false
	csg.global_transform = collision_shape.global_transform
	return [csg]
	

func _get_csg_mesh_instance_3d(mesh_instance: MeshInstance3D) -> Array[CSGShape3D]:
	var csg_array = _get_csg_from_mesh(mesh_instance.mesh)
	for csg in csg_array:
		csg.global_transform = mesh_instance.global_transform
	return csg_array


# TODO:
func _get_csg_multimesh_instance_3d(multimesh: MultiMeshInstance3D) -> Array[CSGShape3D]:
	#var csg: CSGShape3D = _get_csg_from_mesh(multimesh.mesh)
	return []


func _get_csg_from_mesh(mesh: Mesh) -> Array[CSGShape3D]:
	var csg: CSGShape3D = null
	if mesh is BoxMesh:
		csg = CSGBox3D.new()
		csg.size = mesh.size
	elif mesh is SphereMesh:
		csg = CSGSphere3D.new()
		csg.radial_segments = radial_segments
		csg.radius = mesh.radius
		csg.rings = rings
		csg.smooth_faces = false
	elif mesh is CapsuleMesh: #TODO
		# With CapsuleShape3D, we need 3 CSG: 2 spheres on both ends, and a body
		csg = CSGCombiner3D.new()
	elif mesh is CylinderMesh:
		csg = CSGCylinder3D.new()
		csg.height = mesh.height
		csg.radius = mesh.radius
		csg.side = radial_segments
		csg.smooth_faces = false
	elif mesh is ArrayMesh:
		csg = CSGMesh3D.new()
		csg.mesh = mesh
	elif mesh is PlaneMesh: # TODO
		csg = CSGPolygon3D.new()
	elif mesh is PointMesh:
		return [] # Unsupported. I don't know what to do with it.
	elif mesh is PrismMesh: # TODO
		csg = CSGPolygon3D.new()
	elif mesh is RibbonTrailMesh: # TODO
		csg = CSGPolygon3D.new()
	elif mesh is TextMesh: # TODO
		csg = CSGPolygon3D.new()
	elif mesh is TorusMesh:
		csg = CSGTorus3D.new()
		csg.inner_radius = mesh.inner_radius
		csg.outer_radius = mesh.outer_radius
		csg.ring_sides = mesh.ring_segments
		csg.sides = mesh.rings
		csg.smooth_faces = false
	elif mesh is TubeTrailMesh: # TODO
		csg = CSGPolygon3D.new()
	return [csg]


func _get_configuration_warnings() -> PackedStringArray:
	var warnings = []
	if _parent == null \
		or (_parent is not CollisionObject3D \
		and _parent is not CollisionShape3D \
		and _parent is not MeshInstance3D \
		and _parent is not MultiMeshInstance3D \
		and _parent is not CSGShape3D):
		warnings.push_back("Parent node does not support voxelization.")
	if transform != Transform3D():
		warnings.push_back("Transform should be default.")
	return warnings
