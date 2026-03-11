@tool
extends RefCounted
class_name VoxelizationInvestigationLib


const DEMO_SCENE_PATH: String = "res://demo.tscn"
const DEFAULT_REPORT_DIR: String = "user://investigation"
const BAD_SVOLINKS: Array[int] = [5390, 5391, 5446, 5447, 5454, 5455]


static func setup_demo(scene_tree: SceneTree) -> Dictionary:
	var packed_scene := load(DEMO_SCENE_PATH) as PackedScene
	if packed_scene == null:
		printerr("VoxelizationInvestigationLib.setup_demo(): Failed to load demo scene.")
		return {}

	var scene_root := packed_scene.instantiate()
	scene_tree.root.add_child(scene_root)
	await scene_tree.process_frame

	var flight_navigation := scene_root.get_node_or_null("FlightNavigation3D") as FlightNavigation3D
	if flight_navigation == null:
		printerr("VoxelizationInvestigationLib.setup_demo(): Missing FlightNavigation3D node.")
		scene_root.queue_free()
		return {}

	var voxelizer := flight_navigation.get_node_or_null("SvoVoxelizer") as SvoVoxelizer
	if voxelizer == null:
		printerr("VoxelizationInvestigationLib.setup_demo(): Missing SvoVoxelizer node.")
		scene_root.queue_free()
		return {}

	var targets := collect_voxelization_targets(scene_tree, voxelizer.voxelization_mask)
	return {
		"scene_root": scene_root,
		"flight_navigation": flight_navigation,
		"voxelizer": voxelizer,
		"targets": targets,
	}


static func teardown_demo(context: Dictionary) -> void:
	var scene_root := context.get("scene_root") as Node
	if scene_root != null:
		scene_root.queue_free()


static func collect_voxelization_targets(
	scene_tree: SceneTree,
	voxelization_mask: int
) -> Array[VoxelizationTarget]:
	var result: Array[VoxelizationTarget] = []
	for node in scene_tree.get_nodes_in_group("voxelization_target"):
		var target := node as VoxelizationTarget
		if target == null:
			continue
		if target.voxelization_mask & voxelization_mask == 0:
			continue
		result.push_back(target)
	return result


static func build_raw_triangles(
	flight_navigation: FlightNavigation3D,
	targets: Array[VoxelizationTarget]
) -> PackedVector3Array:
	var voxelization_target_shapes := flight_navigation.get_node_or_null("VoxelizationTargetShapes") as Node
	if voxelization_target_shapes == null:
		printerr("VoxelizationInvestigationLib.build_raw_triangles(): Missing VoxelizationTargetShapes node.")
		return PackedVector3Array()

	_clear_voxelization_target_shapes(voxelization_target_shapes)
	for target in targets:
		for shape in target.get_csg():
			voxelization_target_shapes.add_child(shape)
			shape.global_transform = target.global_transform
			shape.operation = CSGShape3D.OPERATION_UNION

	await flight_navigation.get_tree().process_frame
	var baked_mesh: Mesh = flight_navigation.bake_static_mesh()
	if baked_mesh == null:
		return PackedVector3Array()
	return baked_mesh.get_faces()


static func build_target_triangle_reports(
	flight_navigation: FlightNavigation3D,
	targets: Array[VoxelizationTarget]
) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	var voxelization_target_shapes := flight_navigation.get_node_or_null("VoxelizationTargetShapes") as Node
	if voxelization_target_shapes == null:
		printerr("VoxelizationInvestigationLib.build_target_triangle_reports(): Missing VoxelizationTargetShapes node.")
		return reports

	for target in targets:
		_clear_voxelization_target_shapes(voxelization_target_shapes)
		var csg_shapes := target.get_csg()
		for shape in csg_shapes:
			voxelization_target_shapes.add_child(shape)
			shape.global_transform = target.global_transform
			shape.operation = CSGShape3D.OPERATION_UNION

		await flight_navigation.get_tree().process_frame
		var baked_mesh: Mesh = flight_navigation.bake_static_mesh()
		var faces := PackedVector3Array()
		if baked_mesh != null:
			faces = baked_mesh.get_faces()

		var shape_types: Array[String] = []
		for shape in csg_shapes:
			shape_types.push_back(shape.get_class())

		reports.push_back({
			"target_path": str(target.get_path()),
			"parent_path": str(target.get_parent().get_path()) if target.get_parent() != null else "",
			"parent_type": target.get_parent().get_class() if target.get_parent() != null else "",
			"csg_shape_types": shape_types,
			"csg_shape_count": csg_shapes.size(),
			"triangle_count": faces.size() / 3,
		})

	_clear_voxelization_target_shapes(voxelization_target_shapes)
	return reports


static func inspect_svolinks(
	svo: SVO,
	voxel_size: Vector3,
	svolinks: Array[int]
) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for svolink in svolinks:
		var offset: int = SvoLink64.singleton.get_offset(svolink)
		var subgrid: int = SvoLink64.singleton.get_subgrid(svolink)
		if offset < 0 or offset >= svo.morton[0].size():
			report.push_back({
				"svolink": svolink,
				"error": "offset_out_of_bounds",
			})
			continue

		var node_morton: int = svo.morton[0][offset]
		var voxel_morton: int = (node_morton << 6) | subgrid
		var voxel_coords: Vector3i = Morton3.decode_vec3i(voxel_morton)
		var local_center := (Vector3(voxel_coords) + Vector3.ONE * 0.5) * voxel_size

		var item := {
			"svolink": svolink,
			"offset": offset,
			"subgrid": subgrid,
			"subgrid_coords": vec3i_to_array(Morton3.decode_vec3i(subgrid)),
			"node_morton": node_morton,
			"node_coords": vec3i_to_array(Morton3.decode_vec3i(node_morton)),
			"voxel_morton": voxel_morton,
			"voxel_coords": vec3i_to_array(voxel_coords),
			"local_center": vec3_to_array(local_center),
		}
		if svo.support_inside:
			item["is_solid"] = svo.is_solid(svolink)
		report.push_back(item)
	return report


static func triangles_to_report(triangles: PackedVector3Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for triangle_index in range(triangles.size() / 3):
		var start: int = triangle_index * 3
		var v0: Vector3 = triangles[start]
		var v1: Vector3 = triangles[start + 1]
		var v2: Vector3 = triangles[start + 2]
		var minimum_corner := Vector3(
			minf(minf(v0.x, v1.x), v2.x),
			minf(minf(v0.y, v1.y), v2.y),
			minf(minf(v0.z, v1.z), v2.z)
		)
		var maximum_corner := Vector3(
			maxf(maxf(v0.x, v1.x), v2.x),
			maxf(maxf(v0.y, v1.y), v2.y),
			maxf(maxf(v0.z, v1.z), v2.z)
		)
		result.push_back({
			"triangle_index": triangle_index,
			"v0": vec3_to_array(v0),
			"v1": vec3_to_array(v1),
			"v2": vec3_to_array(v2),
			"centroid": vec3_to_array((v0 + v1 + v2) / 3.0),
			"aabb_min": vec3_to_array(minimum_corner),
			"aabb_max": vec3_to_array(maximum_corner),
		})
	return result


static func vec3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func vec3i_to_array(value: Vector3i) -> Array[int]:
	return [value.x, value.y, value.z]


static func default_report_path(file_name: String) -> String:
	return DEFAULT_REPORT_DIR.path_join(file_name)


static func write_json_report(path: String, report: Dictionary) -> void:
	var directory_path := path.get_base_dir()
	if not directory_path.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("VoxelizationInvestigationLib.write_json_report(): Failed to open report path %s." % path)
		return
	file.store_string(JSON.stringify(report, "  "))


static func duplicate_target_array(targets: Array[VoxelizationTarget]) -> Array[VoxelizationTarget]:
	var duplicate_targets: Array[VoxelizationTarget] = []
	duplicate_targets.append_array(targets)
	return duplicate_targets


static func _clear_voxelization_target_shapes(voxelization_target_shapes: Node) -> void:
	for child in voxelization_target_shapes.get_children():
		voxelization_target_shapes.remove_child(child)
		child.free()
