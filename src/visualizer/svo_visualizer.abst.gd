## Interface-like base for SVO visualizers.
## Concrete implementations should render an [SVO] for debugging/inspection.
@tool
extends Node3D
class_name ASvoVisualizer


func draw(_fn3d: FlightNavigation3D) -> void:
	assert(false, "Not implemented")
