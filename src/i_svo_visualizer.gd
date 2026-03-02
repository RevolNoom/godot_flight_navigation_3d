## Interface-like base for SVO visualizers.
## Concrete implementations should render an [SVO] for debugging/inspection.
@tool
extends Node3D
class_name ISvoVisualizer


func draw(_fn3d: FlightNavigation3D):
	printerr("ISvoVisualizer.draw() is abstract.")
	return null
