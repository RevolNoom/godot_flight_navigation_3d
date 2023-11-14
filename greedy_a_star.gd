@tool
extends Node
class_name GreedyAStar

@export_enum("Face Centers", "Cube Centers") var endpoints = "Face Centers":
	set(value):
		endpoints = value
		if endpoints == "Face Centers":
			_endpoints = _face_centers
		else:
			_endpoints = _node_centers

@export_enum("Euclidean", "Manhattan") var distance = "Euclidean":
	set(value):
		distance = value
		if distance == "Euclidean":
			_distance = _euclidean
		else:
			_distance = _manhattan

## Bias weight. The higher it is, the more A* is biased toward estimation,
## prefer exploring nodes it thinks are closer to the goal
@export var w: float = 1

## The bigger the node, the less it costs to move through it
@export var size_compensation_factor: float = 0.05

## no matter how big the node is, travelling
## through it has the same cost
@export var unit_cost: float = 1


## @svo: A SVO contains collision information
## @extent: The length of one side of the navigation space (assumed as cube)
## @return: The path connecting @from and @to through the navigation space
func find_path(from: Vector3, to: Vector3, svo: SVO, extent: float) -> PackedVector3Array:
	#_convert_to_svolink()
	# A* algo
	return []


func _greedy_a_star(from: int, to: int, svo: SVO):
	# The Priority Queue of best nodes to search
	var uncharted:= PriorityQueue.new()
	
	# Dictionary of nodes already searched
	# Key - Value: SVOLink - real cost
	var charted: Dictionary
	pass
 
func _neighbors_of(node_link) -> PackedInt64Array:
	return []

func _get_total_cost(svolink_from: int, svolink_to: int) -> float:
	var layer_f = SVOLink.layer(svolink_from)
	var layer_t = SVOLink.layer(svolink_to)
	
	var grid_f = SVOLink.subgrid(svolink_from)
	var grid_t = SVOLink.subgrid(svolink_to)
	
	return 0
	# return (_compute_cost() + w * _estimate_cost())\
	# * (1 - layer_t * size_compensation_factor)

func _estimate_cost(svolink1: int, svolink2: int) -> float:
	return distance


## Return SVOLink of the smallest node in the svo tree that contains this position
func _convert_to_svolink(svo_depth: int, extent_size: float, position: Vector3) -> int:
	return 0


func _compute_cost() -> float:
	return 0

func _node_centers():
	pass
	
func _face_centers():
	pass

func _euclidean():
	pass
	
func _manhattan():
	pass
	
var _distance
var _endpoints

func _on_property_list_changed():
	update_configuration_warnings()
	
func _get_configuration_warnings():
	if get_parent() == null or not get_parent() is NavigationSpace3D:
		return ["Must be a child of NavigationSpace3D"]
	return []
