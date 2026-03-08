## Interface-like base for SVO visualizers.
## Concrete implementations should render an [SVO] for debugging/inspection.
@tool
extends Node3D
class_name ISvoVisualizer


func _abstract_fail(method_name: String) -> void:
	var message: String = "ISvoVisualizer.%s() is abstract. Override in subclass." % method_name
	push_error(message)
	assert(false, message)


func draw(_fn3d: FlightNavigation3D) -> void:
	_abstract_fail("draw")
