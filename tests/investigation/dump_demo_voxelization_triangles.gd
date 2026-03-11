@tool
extends SceneTree


const InvestigationLib = preload("res://tests/investigation/voxelization_investigation_lib.gd")
const REPORT_PATH: String = "user://investigation/demo_voxelization_triangle_dump.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var context := await InvestigationLib.setup_demo(self)
	if context.is_empty():
		quit(1)
		return

	var flight_navigation := context["flight_navigation"] as FlightNavigation3D
	var voxelizer := context["voxelizer"] as SvoVoxelizer
	var targets := context["targets"] as Array[VoxelizationTarget]

	var raw_triangles := await InvestigationLib.build_raw_triangles(flight_navigation, targets)
	var prepared_triangles: PackedVector3Array = await voxelizer._prepare_triangles(
		flight_navigation,
		process_frame,
		InvestigationLib.duplicate_target_array(targets),
		voxelizer.voxelization_mask,
		voxelizer.debug_delete_csg,
		voxelizer.remove_thin_triangles,
		voxelizer.multi_threading_enabled,
		voxelizer.multi_threading_priority,
		-flight_navigation.size / 2.0
	)
	var voxel_size: Vector3 = FlightNavigation3D.calculate_node_size(
		flight_navigation.size,
		-2,
		voxelizer.layer_count
	)

	var report := {
		"scene_path": InvestigationLib.DEMO_SCENE_PATH,
		"flight_navigation_size": InvestigationLib.vec3_to_array(flight_navigation.size),
		"voxel_size": InvestigationLib.vec3_to_array(voxel_size),
		"layer_count": voxelizer.layer_count,
		"target_count": targets.size(),
		"target_reports": await InvestigationLib.build_target_triangle_reports(flight_navigation, targets),
		"reported_bad_svolinks": InvestigationLib.BAD_SVOLINKS,
		"bad_svolink_details": InvestigationLib.inspect_svolinks(
			flight_navigation.sparse_voxel_octree,
			voxel_size,
			InvestigationLib.BAD_SVOLINKS
		),
		"combined_raw_triangle_count": raw_triangles.size() / 3,
		"combined_prepared_triangle_count": prepared_triangles.size() / 3,
		"combined_raw_triangles": InvestigationLib.triangles_to_report(raw_triangles),
	}

	InvestigationLib.write_json_report(REPORT_PATH, report)
	print("Voxelization triangle dump written to: %s" % REPORT_PATH)
	print("Voxelization triangle dump target count: %d" % targets.size())
	print("Voxelization triangle dump raw triangle count: %d" % (raw_triangles.size() / 3))
	print("Voxelization triangle dump prepared triangle count: %d" % (prepared_triangles.size() / 3))

	InvestigationLib.teardown_demo(context)
	await process_frame
	quit()
