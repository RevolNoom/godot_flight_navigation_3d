extends Object
class_name MeshTool


static func convert_to_mesh(shape: Shape3D) -> Mesh:
	var faces = get_faces(shape)
	var array_mesh = ArrayMesh.new()
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh


## Return an array of vertices, each 3 vertices represent a triangle face
## of the [param shape] in clockwise order.[br]
## [b]NOTE:[/b] Not all shapes are supported, in which case it returns empty Array.
static func get_faces(shape: Shape3D) -> PackedVector3Array:
	if shape is BoxShape3D:
		return MeshTool.get_boxmesh_faces(shape)
	elif shape is ConvexPolygonShape3D:
		return MeshTool.get_convex_polygon_faces(shape)
	elif shape is ConcavePolygonShape3D:
		return shape.get_faces()
	elif shape is SphereShape3D:
		return MeshTool.get_sphereshape_faces(shape)
	elif shape is CapsuleShape3D:
		return MeshTool.get_capsuleshape_faces(shape)
	elif shape is CylinderShape3D:
		return MeshTool.get_cylindershape_faces(shape)
	return []


static func get_boxmesh_faces(shape: BoxShape3D) -> PackedVector3Array:
	var box = BoxMesh.new()
	box.size = shape.size
	var arr_mesh = ArrayMesh.new()
	var ma = box.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	return arr_mesh.get_faces()


# TODO: Maybe there should be a way to dynamically increase triangle counts for sphere?
static func get_sphereshape_faces(shape: SphereShape3D) -> PackedVector3Array:
	var sphere = SphereMesh.new()
	sphere.height = shape.radius*2
	sphere.radius = shape.radius
	var arr_mesh = ArrayMesh.new()
	var ma = sphere.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	return arr_mesh.get_faces()
	

# TODO: Maybe there should be a way to dynamically increase triangle counts for capsule?
static func get_capsuleshape_faces(shape: CapsuleShape3D) -> PackedVector3Array:
	var capsule = CapsuleMesh.new()
	capsule.height = shape.height
	capsule.radius = shape.radius
	var arr_mesh = ArrayMesh.new()
	var ma = capsule.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	return arr_mesh.get_faces()


	
# TODO: Maybe there should be a way to dynamically increase triangle counts for cylinder?
static func get_cylindershape_faces(shape: CylinderShape3D) -> PackedVector3Array:
	var cylinder = CylinderMesh.new()
	cylinder.height = shape.height
	cylinder.top_radius = shape.radius
	cylinder.bottom_radius = shape.radius
	var arr_mesh = ArrayMesh.new()
	var ma = cylinder.get_mesh_arrays()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ma)
	return arr_mesh.get_faces()
	

## Generate triangle faces using incremental algorithm. O(N^2)
static func get_convex_polygon_faces(shape: ConvexPolygonShape3D) -> PackedVector3Array:
	var vertices = shape.points
	var initial_vertices = MeshTool._get_random_tetrahedron(vertices)
	if initial_vertices.size() == 0:
		return []
		
	var faces = [
		initial_vertices[0], initial_vertices[1], initial_vertices[2], 
		initial_vertices[0], initial_vertices[1], initial_vertices[3], 
		initial_vertices[0], initial_vertices[2], initial_vertices[3], 
		initial_vertices[1], initial_vertices[2], initial_vertices[3], 
	]
	MeshTool.set_vertices_in_clockwise_order(faces)
	
	for i in range(vertices.size()):
		var vertex_i = vertices[i]
		var faces_can_see_vertex_i = MeshTool._faces_can_see_vertex(faces, vertex_i)
		# No face can see this point.
		# It means this point is already inside the hull
		if faces_can_see_vertex_i.size() == 0:
			continue
			
		# Find the perimeter of the cross-section
		var perimeter = MeshTool._perimeter_of_faces(faces_can_see_vertex_i)
	
		# Add new faces
		var new_faces: PackedVector3Array = []
		@warning_ignore("integer_division")
		for j in range(perimeter.size()/2):
			var v1 = perimeter[j*2]
			var v2 = perimeter[j*2+1]
			new_faces.append_array([v1, v2, vertex_i])
		MeshTool.set_vertices_in_clockwise_order(new_faces)
		faces = MeshTool.subtract_faces(faces, faces_can_see_vertex_i) + new_faces
	# TODO: There's some faces generated somewhere that's not in clockwise order
	# I don't have time to debug it right now, so this have to do
	MeshTool.set_vertices_in_clockwise_order(faces)
	return faces


## Return 4 points in [param vertices] that makes a tetrahedron with positive volume.
## Return empty array if no tetrahedron can be made.
## Worst case O(N^4).
static func _get_random_tetrahedron(vertices: PackedVector3Array) -> PackedVector3Array:
	if vertices.size() < 4:
		return []
	for i in range(vertices.size() - 3):
		var v0 = vertices[i]
		for j in range(i+1, vertices.size() - 2):
			var v1 = vertices[j]
			var e0 = v1-v0
			for k in range(j+1, vertices.size() - 1):
				var v2 = vertices[k]
				var e1 = v2-v0
				for l in range(k+1, vertices.size()):
					var v3 = vertices[l]
					var e2 = v3-v0
					if Basis(e0, e1, e2).determinant() > 0.0001:
						return [v0, v1, v2, v3]
	return []
	
	
## Return faces in [param faces] that can see [param point],
## each 3 vector3 make a face. 
## Faces must be in clockwise-order.
static func _faces_can_see_vertex(faces: PackedVector3Array, point: Vector3) -> PackedVector3Array:
	if faces.size() == 0:
		return []
	var result_faces: PackedVector3Array = []
	var center_of_mass = MeshTool.calculate_center_of_mass(faces)
	@warning_ignore("integer_division")
	for i in range(faces.size()/3):
		var idx = i * 3
		var normal = MeshTool.get_surface_normal(faces[idx], faces[idx+1], faces[idx+2])
		# Center of mass and this point is on two sides of current face.
		# It means this face sees the point. Add it.
		var dot_product = normal.dot(point - faces[idx]) \
						* normal.dot(center_of_mass - faces[idx])
		if dot_product < 0:
			result_faces.append_array(faces.slice(idx, idx + 3))
	return result_faces


## Return outermost edges of [param faces] (edges that contributes to only 1 face).
## Every 2 vertices make an edge.
static func _perimeter_of_faces(faces: PackedVector3Array) -> PackedVector3Array:
	var edge_count := {}
	@warning_ignore("integer_division")
	for i in range(faces.size()/3):
		var start_idx = i*3
		var v0 = faces[start_idx]
		var v1 = faces[start_idx + 1]
		var v2 = faces[start_idx + 2]
		for edge in [
			MeshTool._make_edge(v0, v1),
			MeshTool._make_edge(v1, v2),
			MeshTool._make_edge(v2, v0)]:
				edge_count[edge] = edge_count.get(edge, 0) + 1
	var keys = edge_count.keys()
	var edges = keys.filter(func (edge):
			return edge_count[edge] == 1
			)
	var perim = edges.reduce(func (accum, edge):
		accum.append_array(edge)
		return accum)
	return perim
	

static func subtract_faces(
	face_list: PackedVector3Array, 
	subtract_face_list: PackedVector3Array) -> PackedVector3Array:
	var face_dict := {}
	@warning_ignore("integer_division")
	for i in range(face_list.size()/3):
		face_dict[face_list.slice(i*3, i*3+3)] = true
	@warning_ignore("integer_division")
	for i in range(subtract_face_list.size()/3):
		face_dict.erase(subtract_face_list.slice(i*3, i*3+3))
	if face_dict.keys().size() == 0:
		return []
	return face_dict.keys().reduce(func (accum, face):
			accum.append_array(face)
			return accum)



static func _make_edge(v1: Vector3, v2: Vector3) -> PackedVector3Array:
	if v1 < v2:
		return [v1, v2]
	return [v2, v1]


static var __clockwise_order_surface_normal_direction = \
	-1 if Vector3(1, 0, 0).cross(Vector3(0, 1, 0)) == Vector3(0, 0, 1) else 1
	
## Get normal of the surface made by 3 vertices 
## [param v1], [param v2], [param v3] (clockwise-ordered).
## The direction of the normal vector points away from the surface.
static func get_surface_normal(v1: Vector3, v2: Vector3, v3: Vector3) -> Vector3:
	return (v2-v1).cross(v3-v2) * __clockwise_order_surface_normal_direction


static func calculate_center_of_mass(vertices: PackedVector3Array):
	return Array(vertices).reduce(
		func (accum, vertex):
			return accum + vertex) / vertices.size()


## Find the center of mass of the hull, and rearranges each 3 vertices to
## face away from it. The array is modified in-place.
static func set_vertices_in_clockwise_order(faces: PackedVector3Array):
	if faces.size() == 0:
		return
	MeshTool.set_vertices_in_clockwise_order_with_calculate_center_of_mass(
		faces, MeshTool.calculate_center_of_mass(faces))


static func set_vertices_in_clockwise_order_with_calculate_center_of_mass(
		faces: PackedVector3Array,
		center_of_mass: Vector3):
	@warning_ignore("integer_division")
	for i in range(faces.size()/3):
		var start_idx = i*3
		if MeshTool.get_surface_normal(
				faces[start_idx],
				faces[start_idx+1],
				faces[start_idx+2])\
				.dot(center_of_mass - faces[start_idx]) > 0:
			var temp = faces[start_idx+1]
			faces[start_idx+1] = faces[start_idx+2]
			faces[start_idx+2] = temp


## [param] local_aabb: AABB of a VisualInstance3D, comes from get_aabb(). 
## Usually is in local coordinate of that Node.[br]
##
## [param] global_transform: global transform of that VisualInstance3D.[br]
static func convert_local_aabb_to_global(local_aabb: AABB, global_transform: Transform3D) -> AABB:
	var global_aabb = local_aabb
	global_aabb.position *= global_transform
	global_aabb.end *= global_transform
	return global_aabb

static func print_faces(faces: PackedVector3Array):
	var faces_str = ""
	for i in range(0, faces.size(), 3):
		faces_str += "\t%v, %v, %v,\n\n" % [faces[i], faces[i+1], faces[i+2]]
	print("[\n%s\n]" % faces_str)

## Clean up generated faces from CSG shapes by doing these things:[br]
## - Remove all faces with 2 or more vertices identical to each other [br]
## - Remove all faces with 3 vertices lie on the same line[br]
## - [NOT YET SUPPORTED] Remove identical faces (same set of 3 points)[br]
static func normalize_faces(faces: PackedVector3Array) -> PackedVector3Array:
	#print("Before remove: %d faces" % [faces.size()/3])
	var result: PackedVector3Array = []
	result.resize(faces.size())
	result.resize(0)
	for i in range(0, faces.size(), 3):
		var p0 = faces[i]
		var p1 = faces[i+1]
		var p2 = faces[i+2]
		var line_direction = p1-p0
		if line_direction == Vector3.ZERO\
			or p2 == p1\
			or p2 == p0:
			continue # 2 identical vertices
		var t = (p2-p0)/line_direction
		if t.x == t.y and t.y == t.z:
			continue # 3 vertices on a line
		result.append_array([p0, p1, p2])
	#print("After remove: %d faces" % [result.size()/3])
	return result

static func create_array_mesh_from_faces(faces: PackedVector3Array) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

## TODO: NOT YET TESTED
## TODO: Need to be in tree for get_debug_mesh to work after SceneTree.process_frame signal
#static func create_convex_mesh_from_points(points: PackedVector3Array) -> ArrayMesh:
	#var convex_polygon_3d = ConvexPolygonShape3D.new()
	#convex_polygon_3d.points = points
	#convex_polygon_3d.get_debug_mesh().get_faces()
	#var array_mesh = ArrayMesh.new()
	## Initialize the mesh
	#var arrays = []
	#arrays.resize(Mesh.ARRAY_MAX)
	#arrays[Mesh.ARRAY_VERTEX] = shape.get_debug_mesh().get_faces()
	#array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	#pass
