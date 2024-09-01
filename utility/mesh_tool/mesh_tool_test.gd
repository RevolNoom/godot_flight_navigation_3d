extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var planet = $TruncatedIcosahedron
	#var planet = $Tetrahedron
	#var planet = $Hexahedron
	$MeshInstance3D.mesh = MeshTool.convert_to_mesh(planet.get_node("CollisionShape3D").shape)
