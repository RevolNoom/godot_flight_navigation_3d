extends Node3D

## Demo scene for SVOLinkProbe
## 
## This scene demonstrates how to use SVOLinkProbe to inspect voxels at runtime.
## - Move mouse to position the probe sphere
## - Click to print SVOLink info to console
## - Click and hold to show 3D label with SVOLink info

@onready var flight_nav: FlightNavigation3D = $FlightNavigation3D
@onready var probe: SVOLinkProbe = $Camera3D/SvoLinkProbe


func _ready() -> void:
	print("=== SVOLinkProbe Demo ===")
	print("Building navigation data...")
	
	# Build navigation data
	await flight_nav.build_navigation()
	
	# Assign FlightNavigation3D reference to probe
	probe.flight_navigation = flight_nav
	
	# Optional: Draw the voxelization for visualization
	flight_nav.draw()
