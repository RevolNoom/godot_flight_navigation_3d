## Interface-like base for SVO voxelizers.
## Concrete implementations should build and return an [SVO].
@tool
extends Node
class_name ASvoVoxelizer


signal progress(
	step: ProgressStep.Enum,
	svo: SVO,
	work_completed: int,
	total_work: int
)


@export_subgroup("Multi-threading", "multi_threading_")
@export var multi_threading_enabled: bool = true
@export var multi_threading_priority: Thread.Priority = \
	Thread.PRIORITY_LOW
@export_subgroup("", "")

@export_subgroup("Preprocessing", "")
@export_flags_3d_navigation var voxelization_mask: int = 1
@export var remove_thin_triangles: bool = true
@export_subgroup("", "")

@export_subgroup("SVO construction", "")
@export_range(2, 15, 1) var layer_count: int = 7
@export_enum(".tres", ".res") var resource_format: String = ".res"
@export var support_float64: bool = false
@export_subgroup("", "")

@export_subgroup("Solid voxelization", "solid_voxelization_")
@export var solid_voxelization_enabled: bool = true
@export var solid_voxelization_calculate_coverage_factor: bool = true
@export_range(0, 0.1, 0.000_000_1) var \
	solid_voxelization_top_left_edge_epsilon: float = 0.000_01
@export_range(0, 0.1, 0.000_000_1) var \
	solid_voxelization_float_error_margin: float = 0.000_01
@export_subgroup("", "")

@export_subgroup("Surface voxelization", "surface_voxelization_")
@export var surface_voxelization_enabled: bool = true
@export var surface_voxelization_separability: \
	Separability.Enum = \
	Separability.Enum.SEPARATING_26
@export_range(0, 0.1, 0.000_000_1) var \
	surface_voxelization_float_error_margin: float = 0.000_1
@export_subgroup("", "")

@export_subgroup("Debug", "debug_")
@export var debug_delete_csg: bool = true
@export var debug_delete_flip_flag: bool = true
@export_subgroup("", "")


func get_is_multithreading_enabled() -> bool:
	return multi_threading_enabled


func set_is_multithreading_enabled(enabled: bool) -> void:
	multi_threading_enabled = enabled


func get_multithreading_priority() -> Thread.Priority:
	return multi_threading_priority


func set_multithreading_priority(priority: Thread.Priority) -> void:
	multi_threading_priority = priority


func get_voxelization_mask() -> int:
	return voxelization_mask


func set_voxelization_mask(mask: int) -> void:
	voxelization_mask = mask


func get_remove_thin_triangles() -> bool:
	return remove_thin_triangles


func set_remove_thin_triangles(remove: bool) -> void:
	remove_thin_triangles = remove


func get_layer_count() -> int:
	return layer_count


func set_layer_count(layer_count_value: int) -> void:
	layer_count = clampi(layer_count_value, 2, 15)


func get_resolution() -> int:
	return 2 ** (layer_count + 1)


func get_resource_format() -> String:
	return resource_format


func set_resource_format(format: String) -> void:
	resource_format = format


func get_support_float64() -> bool:
	return support_float64


func set_support_float64(support: bool) -> void:
	support_float64 = support


func get_solid_voxelization_enabled() -> bool:
	return solid_voxelization_enabled


func set_solid_voxelization_enabled(enable: bool) -> void:
	solid_voxelization_enabled = enable


func get_solid_voxelization_coverage_enabled() -> bool:
	return solid_voxelization_calculate_coverage_factor


func set_solid_voxelization_coverage_enabled(enabled: bool) -> void:
	solid_voxelization_calculate_coverage_factor = enabled


func get_solid_voxelization_top_left_edge_epsilon() -> float:
	return solid_voxelization_top_left_edge_epsilon


func set_solid_voxelization_top_left_edge_epsilon(epsilon: float) -> void:
	solid_voxelization_top_left_edge_epsilon = epsilon


func get_surface_voxelization_enabled() -> bool:
	return surface_voxelization_enabled


func set_surface_voxelization_enabled(enable: bool) -> void:
	surface_voxelization_enabled = enable


func get_surface_voxelization_separability() -> Separability.Enum:
	return surface_voxelization_separability


func set_surface_voxelization_separability(
	separability: Separability.Enum
) -> void:
	surface_voxelization_separability = separability


func get_debug_delete_csg() -> bool:
	return debug_delete_csg


func set_debug_delete_csg(enable: bool) -> void:
	debug_delete_csg = enable


func get_debug_delete_flip_flag() -> bool:
	return debug_delete_flip_flag


func set_debug_delete_flip_flag(enable: bool) -> void:
	debug_delete_flip_flag = enable


func voxelize(_fn3d: FlightNavigation3D) -> SVO:
	assert(false, "Not implemented")
	return null
