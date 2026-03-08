extends Node3D

## Demo scene for SVOLinkProbe
## 
## This scene demonstrates how to use SVOLinkProbe to inspect voxels at runtime.
## - Move mouse to position the probe sphere
## - Click to print SVOLink info to console
## - Click and hold to show 3D label with SVOLink info

## Disabled by default so this demo scene is inert during automated test runs.
@export var auto_build_navigation_on_ready: bool = false
@export var auto_draw_navigation_after_build: bool = false
@export var verbose_logging: bool = false

@onready var flight_nav: FlightNavigation3D = $FlightNavigation3D
@onready var probe: SVOLinkProbe = $Camera3D/SvoLinkProbe


func _ready() -> void:
	if flight_nav and probe:
		probe.flight_navigation = flight_nav

	if OS.has_feature("headless") or not auto_build_navigation_on_ready:
		return

	if not flight_nav or not probe:
		push_warning("SVOLinkProbe demo is missing required scene nodes.")
		return

	if verbose_logging:
		print("=== SVOLinkProbe Demo ===")
		print("Building navigation data...")
	
	# Build navigation data
	await flight_nav.build_navigation()
	if not is_instance_valid(flight_nav) or not is_instance_valid(probe):
		return
	
	# Assign FlightNavigation3D reference to probe
	probe.flight_navigation = flight_nav
	
	# Optional: Draw the voxelization for visualization
	if auto_draw_navigation_after_build:
		flight_nav.draw()
