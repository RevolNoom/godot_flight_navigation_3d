@tool
extends SceneTree


const InvestigationLib = preload("res://tests/investigation/voxelization_investigation_lib.gd")
const REPORT_PATH: String = "user://investigation/demo_bad_svolink_flip_probe.json"


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
	var svo := flight_navigation.sparse_voxel_octree
	var voxel_size: Vector3 = FlightNavigation3D.calculate_node_size(
		flight_navigation.size,
		-2,
		voxelizer.layer_count
	)

	var bad_link_details := InvestigationLib.inspect_svolinks(
		svo,
		voxel_size,
		InvestigationLib.BAD_SVOLINKS
	)
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

	var yz_cells: Dictionary = {}
	for detail in bad_link_details:
		if detail.has("error"):
			continue
		var voxel_coords: Array = detail["voxel_coords"]
		var yz_key := "%d,%d" % [voxel_coords[1], voxel_coords[2]]
		yz_cells[yz_key] = Vector2i(voxel_coords[1], voxel_coords[2])

	var relevant_triangles: Array[Dictionary] = []
	var precision_diff_count: int = 0
	for triangle_index in range(prepared_triangles.size() / 3):
		var triangle_report := _analyze_triangle(
			prepared_triangles,
			triangle_index,
			voxel_size,
			flight_navigation.size,
			svo,
			bad_link_details,
			yz_cells
		)
		if not triangle_report["relevant"]:
			continue
		if triangle_report["precision_diff"]:
			precision_diff_count += 1
		relevant_triangles.push_back(triangle_report)

	var report := {
		"scene_path": InvestigationLib.DEMO_SCENE_PATH,
		"reported_bad_svolinks": InvestigationLib.BAD_SVOLINKS,
		"bad_svolink_details": bad_link_details,
		"voxel_size": InvestigationLib.vec3_to_array(voxel_size),
		"prepared_triangle_count": prepared_triangles.size() / 3,
		"relevant_triangle_count": relevant_triangles.size(),
		"precision_diff_triangle_count": precision_diff_count,
		"relevant_triangles": relevant_triangles,
	}

	InvestigationLib.write_json_report(REPORT_PATH, report)
	print("Bad SVOLink flip probe written to: %s" % REPORT_PATH)
	print("Bad SVOLink flip probe prepared triangle count: %d" % (prepared_triangles.size() / 3))
	print("Bad SVOLink flip probe relevant triangle count: %d" % relevant_triangles.size())
	print("Bad SVOLink flip probe precision diff triangle count: %d" % precision_diff_count)

	InvestigationLib.teardown_demo(context)
	await process_frame
	quit()


func _analyze_triangle(
	triangles: PackedVector3Array,
	triangle_index: int,
	voxel_size: Vector3,
	flight_navigation_size: Vector3,
	svo: SVO,
	bad_link_details: Array[Dictionary],
	yz_cells: Dictionary
) -> Dictionary:
	var start: int = triangle_index * 3
	var v0: Vector3 = triangles[start]
	var v1: Vector3 = triangles[start + 1]
	var v2: Vector3 = triangles[start + 2]

	var yz_samples: Dictionary = {}
	var precision_diff: bool = false
	for yz_key in yz_cells.keys():
		var yz := yz_cells[yz_key] as Vector2i
		var sample_f32 := _sample_triangle_yz_projection_f32(
			v0,
			v1,
			v2,
			voxel_size,
			flight_navigation_size,
			yz.y,
			yz.x
		)
		var sample_f64 := _sample_triangle_yz_projection_f64(
			v0,
			v1,
			v2,
			voxel_size,
			flight_navigation_size,
			yz.y,
			yz.x
		)
		if sample_f32["hit"] != sample_f64["hit"]:
			precision_diff = true
		elif sample_f32["hit"] and sample_f64["hit"] and sample_f32["projected_x"] != sample_f64["projected_x"]:
			precision_diff = true
		yz_samples[yz_key] = {
			"voxel_y": yz.x,
			"voxel_z": yz.y,
			"f32": sample_f32,
			"f64": sample_f64,
		}

	var contributions: Array[Dictionary] = []
	var relevant: bool = precision_diff
	for detail in bad_link_details:
		if detail.has("error"):
			continue
		var voxel_coords: Array = detail["voxel_coords"]
		var yz_key := "%d,%d" % [voxel_coords[1], voxel_coords[2]]
		var yz_sample: Dictionary = yz_samples[yz_key]
		var f32: Dictionary = yz_sample["f32"]
		var f64: Dictionary = yz_sample["f64"]

		var f32_reaches_link: bool = f32["hit"] and f32["projected_x"] <= voxel_coords[0]
		var f64_reaches_link: bool = f64["hit"] and f64["projected_x"] <= voxel_coords[0]
		if f32_reaches_link or f64_reaches_link:
			relevant = true

		var f32_start_link: int = SvoLink64.singleton.null_link()
		if f32["hit"]:
			f32_start_link = svo.get_svolink_from_voxel_morton(
				Morton3.encode64(f32["projected_x"], voxel_coords[1], voxel_coords[2])
			)
		var f64_start_link: int = SvoLink64.singleton.null_link()
		if f64["hit"]:
			f64_start_link = svo.get_svolink_from_voxel_morton(
				Morton3.encode64(f64["projected_x"], voxel_coords[1], voxel_coords[2])
			)

		contributions.push_back({
			"svolink": detail["svolink"],
			"voxel_coords": voxel_coords,
			"f32_hit": f32["hit"],
			"f64_hit": f64["hit"],
			"f32_projected_x": f32["projected_x"],
			"f64_projected_x": f64["projected_x"],
			"f32_reaches_link": f32_reaches_link,
			"f64_reaches_link": f64_reaches_link,
			"f32_start_svolink": f32_start_link,
			"f64_start_svolink": f64_start_link,
		})

	return {
		"relevant": relevant,
		"precision_diff": precision_diff,
		"triangle_index": triangle_index,
		"v0": InvestigationLib.vec3_to_array(v0),
		"v1": InvestigationLib.vec3_to_array(v1),
		"v2": InvestigationLib.vec3_to_array(v2),
		"yz_samples": yz_samples,
		"contributions": contributions,
	}


func _sample_triangle_yz_projection_f32(
	v0: Vector3,
	v1: Vector3,
	v2: Vector3,
	voxel_size: Vector3,
	flight_navigation_size: Vector3,
	voxel_z: int,
	voxel_y: int
) -> Dictionary:
	var voxel_size_yz: Vector2 = Vector2(voxel_size.y, voxel_size.z)
	var e0xyz: Vector3 = v1 - v0
	var e1xyz: Vector3 = v2 - v1
	var e2xyz: Vector3 = v0 - v2

	var v0yz: Vector2 = Vector2(v0.y, v0.z)
	var v1yz: Vector2 = Vector2(v1.y, v1.z)
	var v2yz: Vector2 = Vector2(v2.y, v2.z)

	var not_is_ccw: bool = e2xyz.y * e0xyz.z - e0xyz.y * e2xyz.z < 0.0
	if not_is_ccw:
		var temp := v1yz
		v1yz = v2yz
		v2yz = temp
		e0xyz = v2 - v0
		e1xyz = v1 - v2
		e2xyz = v0 - v1

	var n: Vector3 = e0xyz.cross(e1xyz)
	if is_zero_approx(n.x):
		return {"hit": false, "projected_x": -1}

	var n_yz_e0: Vector2 = Vector2(-e0xyz.z, e0xyz.y)
	var n_yz_e1: Vector2 = Vector2(-e1xyz.z, e1xyz.y)
	var n_yz_e2: Vector2 = Vector2(-e2xyz.z, e2xyz.y)
	if n.x < 0.0:
		n_yz_e0 = Vector2(e0xyz.z, -e0xyz.y)
		n_yz_e1 = Vector2(e1xyz.z, -e1xyz.y)
		n_yz_e2 = Vector2(e2xyz.z, -e2xyz.y)

	var d_yz_e0: float = -n_yz_e0.dot(v0yz)
	var d_yz_e1: float = -n_yz_e1.dot(v1yz)
	var d_yz_e2: float = -n_yz_e2.dot(v2yz)

	var f_yz_e0: float = 0.0
	var f_yz_e1: float = 0.0
	var f_yz_e2: float = 0.0
	var epsilon: float = voxelizer_float_epsilon()
	if n_yz_e0.x > 0.0 or (absf(n_yz_e0.x) < epsilon and n_yz_e0.y < 0.0):
		f_yz_e0 = voxelizer_top_left_epsilon()
	if n_yz_e1.x > 0.0 or (absf(n_yz_e1.x) < epsilon and n_yz_e1.y < 0.0):
		f_yz_e1 = voxelizer_top_left_epsilon()
	if n_yz_e2.x > 0.0 or (absf(n_yz_e2.x) < epsilon and n_yz_e2.y < 0.0):
		f_yz_e2 = voxelizer_top_left_epsilon()

	var rect2i := Rect2i()
	rect2i.position = Vector2i(
		ceili(minf(minf(v0yz.x, v1yz.x), v2yz.x) / voxel_size_yz.x - 0.5),
		ceili(minf(minf(v0yz.y, v1yz.y), v2yz.y) / voxel_size_yz.y - 0.5)
	)
	rect2i.end = Vector2i(
		floori(maxf(maxf(v0yz.x, v1yz.x), v2yz.x) / voxel_size_yz.x + 0.5),
		floori(maxf(maxf(v0yz.y, v1yz.y), v2yz.y) / voxel_size_yz.y + 0.5)
	)
	if not rect2i.has_area():
		return {"hit": false, "projected_x": -1}
	if voxel_y < rect2i.position.x or voxel_y >= rect2i.end.x:
		return {"hit": false, "projected_x": -1}
	if voxel_z < rect2i.position.y or voxel_z >= rect2i.end.y:
		return {"hit": false, "projected_x": -1}

	var voxel_center_yz := Vector2(
		(voxel_y + 0.5) * voxel_size_yz.x,
		(voxel_z + 0.5) * voxel_size_yz.y
	)
	var overlaps_center := (
		n_yz_e0.dot(voxel_center_yz) + d_yz_e0 + f_yz_e0 + epsilon > 0.0
		and n_yz_e1.dot(voxel_center_yz) + d_yz_e1 + f_yz_e1 + epsilon > 0.0
		and n_yz_e2.dot(voxel_center_yz) + d_yz_e2 + f_yz_e2 + epsilon > 0.0
	)
	if not overlaps_center:
		return {"hit": false, "projected_x": -1}

	var plane_equation_d: float = -n.dot(v0)
	var projected_x: int = floori(
		0.5 - (n.y * voxel_center_yz.x + n.z * voxel_center_yz.y + plane_equation_d) / (n.x * voxel_size.x)
	)
	var grid_x: int = int(flight_navigation_size.x / voxel_size.x)
	projected_x = clampi(projected_x, 0, grid_x - 1)
	return {"hit": true, "projected_x": projected_x}


func _sample_triangle_yz_projection_f64(
	v0_f32: Vector3,
	v1_f32: Vector3,
	v2_f32: Vector3,
	voxel_size: Vector3,
	flight_navigation_size: Vector3,
	voxel_z: int,
	voxel_y: int
) -> Dictionary:
	var voxel_size_yz: PackedFloat64Array = [voxel_size.y, voxel_size.z]
	var v0: PackedFloat64Array = Dvector.create_v3(v0_f32)
	var v1: PackedFloat64Array = Dvector.create_v3(v1_f32)
	var v2: PackedFloat64Array = Dvector.create_v3(v2_f32)

	var e0xyz: PackedFloat64Array = [0.0, 0.0, 0.0]
	var e1xyz: PackedFloat64Array = [0.0, 0.0, 0.0]
	var e2xyz: PackedFloat64Array = [0.0, 0.0, 0.0]
	Dvector.sub(e0xyz, v1, v0)
	Dvector.sub(e1xyz, v2, v1)
	Dvector.sub(e2xyz, v0, v2)

	var v0yz: PackedFloat64Array = [v0[1], v0[2]]
	var v1yz: PackedFloat64Array = [v1[1], v1[2]]
	var v2yz: PackedFloat64Array = [v2[1], v2[2]]

	var not_is_ccw: bool = e2xyz[1] * e0xyz[2] - e0xyz[1] * e2xyz[2] < 0.0
	if not_is_ccw:
		var temp := v1yz
		v1yz = v2yz
		v2yz = temp
		Dvector.sub(e0xyz, v2, v0)
		Dvector.sub(e1xyz, v1, v2)
		Dvector.sub(e2xyz, v0, v1)

	var n: PackedFloat64Array = [0.0, 0.0, 0.0]
	Dvector.cross(n, e0xyz, e1xyz)
	if is_zero_approx(n[0]):
		return {"hit": false, "projected_x": -1}

	var n_yz_e0: PackedFloat64Array = [-e0xyz[2], e0xyz[1]]
	var n_yz_e1: PackedFloat64Array = [-e1xyz[2], e1xyz[1]]
	var n_yz_e2: PackedFloat64Array = [-e2xyz[2], e2xyz[1]]
	if n[0] < 0.0:
		n_yz_e0 = [e0xyz[2], -e0xyz[1]]
		n_yz_e1 = [e1xyz[2], -e1xyz[1]]
		n_yz_e2 = [e2xyz[2], -e2xyz[1]]

	var d_yz_e0: float = -Dvector.dot(n_yz_e0, v0yz)
	var d_yz_e1: float = -Dvector.dot(n_yz_e1, v1yz)
	var d_yz_e2: float = -Dvector.dot(n_yz_e2, v2yz)

	var f_yz_e0: float = 0.0
	var f_yz_e1: float = 0.0
	var f_yz_e2: float = 0.0
	var epsilon: float = voxelizer_float_epsilon()
	if n_yz_e0[0] > 0.0 or (absf(n_yz_e0[0]) < epsilon and n_yz_e0[1] < 0.0):
		f_yz_e0 = voxelizer_top_left_epsilon()
	if n_yz_e1[0] > 0.0 or (absf(n_yz_e1[0]) < epsilon and n_yz_e1[1] < 0.0):
		f_yz_e1 = voxelizer_top_left_epsilon()
	if n_yz_e2[0] > 0.0 or (absf(n_yz_e2[0]) < epsilon and n_yz_e2[1] < 0.0):
		f_yz_e2 = voxelizer_top_left_epsilon()

	var rect2i := Rect2i()
	rect2i.position = Vector2i(
		ceili(minf(minf(v0yz[0], v1yz[0]), v2yz[0]) / voxel_size_yz[0] - 0.5),
		ceili(minf(minf(v0yz[1], v1yz[1]), v2yz[1]) / voxel_size_yz[1] - 0.5)
	)
	rect2i.end = Vector2i(
		floori(maxf(maxf(v0yz[0], v1yz[0]), v2yz[0]) / voxel_size_yz[0] + 0.5),
		floori(maxf(maxf(v0yz[1], v1yz[1]), v2yz[1]) / voxel_size_yz[1] + 0.5)
	)
	if not rect2i.has_area():
		return {"hit": false, "projected_x": -1}
	if voxel_y < rect2i.position.x or voxel_y >= rect2i.end.x:
		return {"hit": false, "projected_x": -1}
	if voxel_z < rect2i.position.y or voxel_z >= rect2i.end.y:
		return {"hit": false, "projected_x": -1}

	var voxel_center_yz: PackedFloat64Array = [
		(voxel_y + 0.5) * voxel_size_yz[0],
		(voxel_z + 0.5) * voxel_size_yz[1],
	]
	var overlaps_center := (
		Dvector.dot(n_yz_e0, voxel_center_yz) + d_yz_e0 + f_yz_e0 + epsilon > 0.0
		and Dvector.dot(n_yz_e1, voxel_center_yz) + d_yz_e1 + f_yz_e1 + epsilon > 0.0
		and Dvector.dot(n_yz_e2, voxel_center_yz) + d_yz_e2 + f_yz_e2 + epsilon > 0.0
	)
	if not overlaps_center:
		return {"hit": false, "projected_x": -1}

	var plane_equation_d: float = -Dvector.dot(n, v0)
	var projected_x: int = floori(
		0.5 - (n[1] * voxel_center_yz[0] + n[2] * voxel_center_yz[1] + plane_equation_d) / (n[0] * voxel_size.x)
	)
	var grid_x: int = int(flight_navigation_size.x / voxel_size.x)
	projected_x = clampi(projected_x, 0, grid_x - 1)
	return {"hit": true, "projected_x": projected_x}


func voxelizer_float_epsilon() -> float:
	return 0.00001


func voxelizer_top_left_epsilon() -> float:
	return 0.00001
