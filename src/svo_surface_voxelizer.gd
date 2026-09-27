## Performs surface voxelization by testing triangle intersections against SVO subgrids.
@tool
extends RefCounted
class_name SvoSurfaceVoxelizer

signal progress(
	step: ProgressStep.Enum,
	svo: SVO,
	work_completed: int,
	total_work: int
)


## Runs surface voxelization by testing triangle intersections against subgrids in parallel or sequentially.[br]
## [param async_context]: Context signal for asynchronous execution.[br]
## [param svo]: Target [SVO] whose subgrid will be populated.[br]
## [param triangles]: Input triangle vertex buffer.[br]
## [param list_pair_node1_overlap_triangle_index]: Pairs of node 1 and overlapping triangle indexes.[br]
## [param unique_morton_count]: Number of unique Morton codes.[br]
## [param list_node_1_morton_grouped]: Layer 1 grouped Morton codes.[br]
## [param voxel_size]: Dimensions of a single voxel.[br]
## [param surface_voxelization_separability]: Separability level.[br]
## [param surface_voxelization_float_error_margin]: Numerical margin for triangle-box overlap test.[br]
## [param flight_navigation_size]: Extents of the navigation region.[br]
## [param factory_triangle_box_test]: Factory providing overlap test instances.[br]
## [param multi_threading_enabled]: Whether to run on multiple worker threads.[br]
## [param multi_threading_priority]: Thread priority for worker tasks.[br]
func run_surface_voxelization(
	async_context: Signal,
	svo: SVO,
	triangles: PackedVector3Array,
	list_pair_node1_overlap_triangle_index: Array[Vector4i],
	unique_morton_count: int,
	list_node_1_morton_grouped: PackedInt64Array,
	voxel_size: Vector3,
	surface_voxelization_separability: Separability.Enum,
	surface_voxelization_float_error_margin: float,
	flight_navigation_size: Vector3,
	factory_triangle_box_test: AFactoryTriangleBoxOverlapCheck,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority
) -> void:
	progress.emit(
		ProgressStep.Enum.SURFACE_VOXELIZATION,
		svo,
		0,
		list_node_1_morton_grouped.size()
	)

	var list_node_1_overlap_triangle_count: PackedInt64Array = \
		get_node_1_overlap_triangle_count_array(
			list_pair_node1_overlap_triangle_index,
			unique_morton_count
		)
	var list_node_1_overlap_triangle_write_index: PackedInt64Array = \
		Parallel.make_start_write_index_array_from_count_array(
			list_node_1_overlap_triangle_count
		)

	var list_node_1_overlap_triangle_index: PackedInt64Array = []
	list_node_1_overlap_triangle_index.resize(
		list_pair_node1_overlap_triangle_index.size()
	)
	for i: int in range(list_pair_node1_overlap_triangle_index.size()):
		var current_pair: Vector4i = list_pair_node1_overlap_triangle_index[i]
		var triangle_index: int = current_pair[2] << 32 | current_pair[3]
		list_node_1_overlap_triangle_index[i] = triangle_index

	if multi_threading_enabled:
		await Parallel.execute(
			async_context,
			list_node_1_morton_grouped.size(),
			multi_threading_priority,
			parallel_voxelize_subgrid.bind(
				list_node_1_morton_grouped,
				list_node_1_overlap_triangle_index,
				list_node_1_overlap_triangle_write_index,
				triangles,
				svo,
				voxel_size,
				surface_voxelization_separability,
				flight_navigation_size,
				surface_voxelization_float_error_margin,
				factory_triangle_box_test
			)
		)
	else:
		for i: int in range(list_node_1_morton_grouped.size()):
			parallel_voxelize_subgrid(
				i,
				list_node_1_morton_grouped,
				list_node_1_overlap_triangle_index,
				list_node_1_overlap_triangle_write_index,
				triangles,
				svo,
				voxel_size,
				surface_voxelization_separability,
				flight_navigation_size,
				surface_voxelization_float_error_margin,
				factory_triangle_box_test
			)

	progress.emit(
		ProgressStep.Enum.SURFACE_VOXELIZATION,
		svo,
		list_node_1_morton_grouped.size(),
		list_node_1_morton_grouped.size()
	)


static func get_node_1_overlap_triangle_count_array(
	list_pair_node1_overlap_triangle_index: Array[Vector4i],
	unique_morton_count: int
) -> PackedInt64Array:
	var list_node_1_overlap_triangle_count: PackedInt64Array = []
	list_node_1_overlap_triangle_count.resize(unique_morton_count)
	list_node_1_overlap_triangle_count.fill(0)
	list_node_1_overlap_triangle_count[0] = 1
	var current_morton_index: int = 0
	for i: int in range(1, list_pair_node1_overlap_triangle_index.size()):
		var current_pair: Vector4i = list_pair_node1_overlap_triangle_index[i]
		var last_pair: Vector4i = list_pair_node1_overlap_triangle_index[i - 1]
		var current_morton: int = current_pair[0] << 32 | current_pair[1]
		var last_morton: int = last_pair[0] << 32 | last_pair[1]
		if current_morton != last_morton:
			current_morton_index += 1
		list_node_1_overlap_triangle_count[current_morton_index] += 1
	return list_node_1_overlap_triangle_count


static func calculate_triangle_aabb(v0: Vector3, v1: Vector3, v2: Vector3) -> AABB:
	var aabb: AABB = AABB(v0, Vector3())
	aabb = aabb.expand(v1)
	aabb = aabb.expand(v2)
	aabb = aabb.abs()
	return aabb


static func voxels_overlapped_by_aabb(
	voxel_size: Vector3, 
	triangle_aabb: AABB, 
	flight_navigation_size: Vector3
) -> Array[Vector3i]:
	var inverted_voxel_size: Vector3 = Vector3.ONE / voxel_size
	
	var b: Vector3 = triangle_aabb.position * inverted_voxel_size
	var e: Vector3 = triangle_aabb.end * inverted_voxel_size
	var vb: Vector3 = flight_navigation_size * inverted_voxel_size
	
	b = (b - Vector3.ONE).ceil()
	e = (e + Vector3.ONE).floor()
	
	var bi: Vector3i = Vector3i(b.clamp(Vector3(), vb).floor())
	var ei: Vector3i = Vector3i(e.clamp(Vector3(), vb).ceil())
	
	return [bi, ei]


static func voxelize_subgrid_z_dominant(
	triangle_voxel_test: ATriangleBoxOverlapCheck,
	vox_range: Array[Vector3i],
	voxel_size: Vector3,
	node0_position: Vector3,
	node0_solid_state: int
) -> int:
	for x: int in range(vox_range[0].x, vox_range[1].x):
		for y: int in range(vox_range[0].y, vox_range[1].y):
			var column_pos: Vector3 = node0_position + Vector3(x, y, 0) * voxel_size
			var projection_overlaps: bool = triangle_voxel_test.projection_xy_overlaps(column_pos)
			if not projection_overlaps:
				continue
			
			var c: Vector3 = column_pos + Vector3(
				0.0 if triangle_voxel_test.n[0] <= 0 else voxel_size.x,
				0.0 if triangle_voxel_test.n[1] <= 0 else voxel_size.y,
				0.0
			)
			var c_opposite: Vector3 = column_pos + Vector3(
				voxel_size.x if triangle_voxel_test.n[0] <= 0 else 0.0,
				voxel_size.y if triangle_voxel_test.n[1] <= 0 else 0.0,
				0.0
			)
			
			var z_at_c: float = triangle_voxel_test.z_projection_on_plane(c.x, c.y)
			var z_at_c_opposite: float = triangle_voxel_test.z_projection_on_plane(c_opposite.x, c_opposite.y)
			
			var z_min: int = maxi(vox_range[0].z, floori((minf(z_at_c, z_at_c_opposite) - node0_position.z) / voxel_size.z))
			var z_max: int = mini(vox_range[1].z, ceili((maxf(z_at_c, z_at_c_opposite) - node0_position.z) / voxel_size.z) + 1)
			
			for z: int in range(z_min, z_max):
				var voxel_pos: Vector3 = node0_position + Vector3(x, y, z) * voxel_size
				var subgrid_index: int = Morton3.encode64(x, y, z)
				
				var havent_been_overlapped_before: bool = (node0_solid_state & (1 << subgrid_index)) == 0
				var overlaps_voxel: bool = triangle_voxel_test.plane_overlaps(voxel_pos) and \
					triangle_voxel_test.projection_yz_overlaps(voxel_pos) and \
					triangle_voxel_test.projection_zx_overlaps(voxel_pos)
				if havent_been_overlapped_before and overlaps_voxel:
					node0_solid_state |= (1 << subgrid_index)
	
	return node0_solid_state


static func voxelize_subgrid_y_dominant(
	triangle_voxel_test: ATriangleBoxOverlapCheck,
	vox_range: Array[Vector3i],
	voxel_size: Vector3,
	node0_position: Vector3,
	node0_solid_state: int
) -> int:
	for x: int in range(vox_range[0].x, vox_range[1].x):
		for z: int in range(vox_range[0].z, vox_range[1].z):
			var column_pos: Vector3 = node0_position + Vector3(x, 0, z) * voxel_size
			if not triangle_voxel_test.projection_zx_overlaps(column_pos):
				continue
			
			var y_min: int = vox_range[0].y
			var y_max: int = vox_range[1].y
			
			var c: Vector3 = column_pos + Vector3(
				0.0 if triangle_voxel_test.n[0] <= 0 else voxel_size.x,
				0.0,
				0.0 if triangle_voxel_test.n[2] <= 0 else voxel_size.z
			)
			var c_opposite: Vector3 = column_pos + Vector3(
				voxel_size.x if triangle_voxel_test.n[0] <= 0 else 0.0,
				0.0,
				voxel_size.z if triangle_voxel_test.n[2] <= 0 else 0.0
			)
			
			var y_at_c: float = triangle_voxel_test.y_projection_on_plane(c.x, c.z)
			var y_at_c_opposite: float = triangle_voxel_test.y_projection_on_plane(c_opposite.x, c_opposite.z)
			y_min = maxi(y_min, floori((minf(y_at_c, y_at_c_opposite) - node0_position.y) / voxel_size.y))
			y_max = mini(y_max, ceili((maxf(y_at_c, y_at_c_opposite) - node0_position.y) / voxel_size.y) + 1)
			
			for y: int in range(y_min, y_max):
				var voxel_pos: Vector3 = node0_position + Vector3(x, y, z) * voxel_size
				var subgrid_index: int = Morton3.encode64(x, y, z)
				
				var havent_been_overlapped_before: bool = (node0_solid_state & (1 << subgrid_index)) == 0
				var overlaps_voxel: bool = triangle_voxel_test.plane_overlaps(voxel_pos) and \
					triangle_voxel_test.projection_xy_overlaps(voxel_pos) and \
					triangle_voxel_test.projection_yz_overlaps(voxel_pos)
				if havent_been_overlapped_before and overlaps_voxel:
					node0_solid_state |= (1 << subgrid_index)
	
	return node0_solid_state


static func voxelize_subgrid_x_dominant(
	triangle_voxel_test: ATriangleBoxOverlapCheck,
	vox_range: Array[Vector3i],
	voxel_size: Vector3,
	node0_position: Vector3,
	node0_solid_state: int
) -> int:
	for y: int in range(vox_range[0].y, vox_range[1].y):
		for z: int in range(vox_range[0].z, vox_range[1].z):
			var column_pos: Vector3 = node0_position + Vector3(0, y, z) * voxel_size
			if not triangle_voxel_test.projection_yz_overlaps(column_pos):
				continue
			
			var x_min: int = vox_range[0].x
			var x_max: int = vox_range[1].x
			
			var c: Vector3 = column_pos + Vector3(
				0.0,
				0.0 if triangle_voxel_test.n[1] <= 0 else voxel_size.y,
				0.0 if triangle_voxel_test.n[2] <= 0 else voxel_size.z
			)
			var c_opposite: Vector3 = column_pos + Vector3(
				0.0,
				voxel_size.y if triangle_voxel_test.n[1] <= 0 else 0.0,
				voxel_size.z if triangle_voxel_test.n[2] <= 0 else 0.0
			)
			
			var x_at_c: float = triangle_voxel_test.x_projection_on_plane(c.y, c.z)
			var x_at_c_opposite: float = triangle_voxel_test.x_projection_on_plane(c_opposite.y, c_opposite.z)
			x_min = maxi(x_min, floori((minf(x_at_c, x_at_c_opposite) - node0_position.x) / voxel_size.x))
			x_max = mini(x_max, ceili((maxf(x_at_c, x_at_c_opposite) - node0_position.x) / voxel_size.x) + 1)
			
			for x: int in range(x_min, x_max):
				var voxel_pos: Vector3 = node0_position + Vector3(x, y, z) * voxel_size
				var subgrid_index: int = Morton3.encode64(x, y, z)
				var havent_been_overlapped_before: bool = (node0_solid_state & (1 << subgrid_index)) == 0
				var overlaps_voxel: bool = triangle_voxel_test.plane_overlaps(voxel_pos) and \
					triangle_voxel_test.projection_xy_overlaps(voxel_pos) and \
					triangle_voxel_test.projection_zx_overlaps(voxel_pos)
				if havent_been_overlapped_before and overlaps_voxel:
					node0_solid_state |= (1 << subgrid_index)
	
	return node0_solid_state


@warning_ignore("shadowed_variable")
static func parallel_voxelize_subgrid(
	list_node_1_morton_index: int,
	list_node_1_morton_grouped: PackedInt64Array,
	list_node_1_overlap_triangle_index: PackedInt64Array,
	list_node_1_overlap_triangle_write_index: PackedInt64Array,
	triangles: PackedVector3Array,
	svo: SVO,
	voxel_size: Vector3,
	surface_voxelization_separability: Separability.Enum,
	flight_navigation_size: Vector3,
	surface_voxelization_float_error_margin: float,
	factory_triangle_box_test: AFactoryTriangleBoxOverlapCheck
) -> void:
	var node_0_size: Vector3 = voxel_size * 4
	var node_1_size: Vector3 = voxel_size * 8
	var node1_morton: int = list_node_1_morton_grouped[list_node_1_morton_index]
	var node1_position: Vector3 = Morton3.decode_vec3(node1_morton) * node_1_size

	var start_write_index: int = list_node_1_overlap_triangle_write_index[list_node_1_morton_index]
	var end_write_index: int = -1
	if list_node_1_morton_index + 1 < list_node_1_overlap_triangle_write_index.size():
		end_write_index = list_node_1_overlap_triangle_write_index[list_node_1_morton_index + 1]
	else:
		end_write_index = list_node_1_overlap_triangle_index.size()

	for i: int in range(start_write_index, end_write_index):
		var triangle_index: int = list_node_1_overlap_triangle_index[i]

		var v0: Vector3 = triangles[triangle_index * 3]
		var v1: Vector3 = triangles[triangle_index * 3 + 1]
		var v2: Vector3 = triangles[triangle_index * 3 + 2]

		var triangle_aabb: AABB = calculate_triangle_aabb(v0, v1, v2)
		var triangle_voxel_range: Array[Vector3i] = voxels_overlapped_by_aabb(voxel_size, triangle_aabb, flight_navigation_size)

		var triangle_voxel_range_thickness_x: int = triangle_voxel_range[1].x - triangle_voxel_range[0].x
		var triangle_voxel_range_thickness_y: int = triangle_voxel_range[1].y - triangle_voxel_range[0].y
		var triangle_voxel_range_thickness_z: int = triangle_voxel_range[1].z - triangle_voxel_range[0].z
		var thin_directions_count: int = (
			int(triangle_voxel_range_thickness_x == 1) +
			int(triangle_voxel_range_thickness_y == 1) +
			int(triangle_voxel_range_thickness_z == 1)
		)

		var triangle_node0_test: ATriangleBoxOverlapCheck = factory_triangle_box_test.create(
			v0, 
			v1, 
			v2, 
			node_0_size, 
			Separability.Enum.SEPARATING_26,
			surface_voxelization_float_error_margin
		)
		
		for child_index: int in range(8):
			var node0_position: Vector3 = node1_position + Morton3.decode_vec3(child_index) * node_0_size
			if not triangle_node0_test.overlap_voxel(node0_position):
				continue
		
			var node0_svolink: int = svo.get_svolink_from_node_morton(
				0,
				(node1_morton << 3) | child_index
			)

			var node0_offset: int = SvoLink64.singleton.get_offset(node0_svolink)
			var node0_aabb: AABB = AABB(node0_position, node_0_size)
			var intersection: AABB = triangle_aabb.intersection(node0_aabb)
			intersection.position -= node0_position
			
			var vox_range: Array[Vector3i] = voxels_overlapped_by_aabb(voxel_size, intersection, node_0_size)
			var node0_solid_state: int = svo.subgrid[node0_offset]
						
			if thin_directions_count >= 2:
				for x: int in range(vox_range[0].x, vox_range[1].x):
					for y: int in range(vox_range[0].y, vox_range[1].y):
						for z: int in range(vox_range[0].z, vox_range[1].z):
							var subgrid_index: int = Morton3.encode64(x, y, z)
							node0_solid_state = node0_solid_state | (1 << subgrid_index)
				svo.subgrid[node0_offset] = svo.subgrid[node0_offset] | node0_solid_state
				continue

			var triangle_voxel_test: ATriangleBoxOverlapCheck = factory_triangle_box_test.create(
				v0,
				v1,
				v2,
				voxel_size,
				surface_voxelization_separability,
				surface_voxelization_float_error_margin
			)
			
			if thin_directions_count == 1:
				var projection_test: Callable
				if triangle_voxel_range_thickness_x == 1:
					projection_test = triangle_voxel_test.projection_yz_overlaps 
				elif triangle_voxel_range_thickness_y == 1:
					projection_test = triangle_voxel_test.projection_zx_overlaps
				else:
					projection_test = triangle_voxel_test.projection_xy_overlaps

				for x: int in range(vox_range[0].x, vox_range[1].x):
					for y: int in range(vox_range[0].y, vox_range[1].y):
						for z: int in range(vox_range[0].z, vox_range[1].z):
							var voxel_pos: Vector3 = node0_position + Vector3(x, y, z) * voxel_size
							var subgrid_index: int = Morton3.encode64(x, y, z)
							var havent_been_overlapped_before: bool = (node0_solid_state & (1 << subgrid_index)) == 0
							if havent_been_overlapped_before and projection_test.call(voxel_pos):
								node0_solid_state = node0_solid_state | (1 << subgrid_index)
				svo.subgrid[node0_offset] = svo.subgrid[node0_offset] | node0_solid_state
				continue
			
			if thin_directions_count == 0:
				var abs_nx: float = absf(triangle_voxel_test.n[0])
				var abs_ny: float = absf(triangle_voxel_test.n[1])
				var abs_nz: float = absf(triangle_voxel_test.n[2])

				var dominant_axis_voxelizer: Callable
				if abs_nz >= abs_nx and abs_nz >= abs_ny:
					dominant_axis_voxelizer = voxelize_subgrid_z_dominant
				elif abs_ny >= abs_nx and abs_ny >= abs_nz:
					dominant_axis_voxelizer = voxelize_subgrid_y_dominant
				else:
					dominant_axis_voxelizer = voxelize_subgrid_x_dominant
				node0_solid_state = dominant_axis_voxelizer.call(
					triangle_voxel_test,
					vox_range,
					voxel_size, 
					node0_position,
					node0_solid_state
				)
			
				svo.subgrid[node0_offset] = svo.subgrid[node0_offset] | node0_solid_state
