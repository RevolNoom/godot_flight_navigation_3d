## Validate each node to see whether all neighbor/parent/children links are assigned correctly
extends Node3D
class_name Fn3dTestCase

@onready var flight_navigation: FlightNavigation3D = $FlightNavigation3D

func _ready():
	if flight_navigation.sparse_voxel_octree == null:
		print("No SVO configured")
	var svo: SVO = await flight_navigation.build_navigation()
	if flight_navigation.sparse_voxel_octree.deep_compare(svo):
		print("true")
	else:
		print("false")
	get_tree().quit()
