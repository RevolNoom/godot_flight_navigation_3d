extends Node3D

func _ready():
	print_aabb.call_deferred()
	
func print_aabb():
	print($Node3D/CSGBox3D.get_aabb())
