@tool
extends Node
class_name GreedyAStar

## TODO: Currently only support Voxel Centers
@export_enum("Face Centers", "Voxel Centers") var endpoints = "Voxel Centers":
	set(value):
		endpoints = "Voxel Centers"
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

## If true, the cost between two voxels is unit_cost
## Otherwise, 
## TODO: Actually make it work
@export var use_unit_cost: bool = true

## No matter how big the node is, travelling
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
	# Element: [Total Cost Estimated, SVOLink]
	# Sorted by TCE. pop() returns element with smallest TCE
	const TotalCostEstimated = 0
	const SvoLink = 1
	var unsearched:= PriorityQueue.new(
		func (u1, u2) -> bool:
			return u1[TotalCostEstimated] > u2[TotalCostEstimated])
	
	# Dictionary of nodes already visited,
	# so that it's not visited more than once
	# Key - Value: SVOLink - Real Cost
	var charted: Dictionary = {}
	
	unsearched.push([INF, from])
	charted[from] = 0
	
	while unsearched.size() > 0:
		var best_node = unsearched.pop()
		var bn_neighbors := svo.neighbors_of(best_node[SvoLink])
		var neighbor_cost = charted[best_node[SvoLink]] + unit_cost
		for neighbor in bn_neighbors:
			if charted.has(neighbor):
				continue
			charted[neighbor] = neighbor_cost
			unsearched.push([neighbor_cost\
				+ _compute_cost(from, neighbor)\
				+ _estimate_cost(neighbor, to)\
				, neighbor])
			
	pass


## Calculate the cost between two connected voxels
func _compute_cost(svolink_from: int, svolink_to: int) -> float:
	var layer_f = SVOLink.layer(svolink_from)
	var layer_t = SVOLink.layer(svolink_to)
	
	var grid_f = SVOLink.subgrid(svolink_from)
	var grid_t = SVOLink.subgrid(svolink_to)
	
	return 0
	# return (_computSvoLinke_cost() + w * _estimate_cost())\
	# * (1 - layer_t * size_compensation_factor)

## Calculate the cost between a voxel and its destination
func _estimate_cost(svolink1: int, svolink2: int) -> float:
	return distance


## Return SVOLink of the smallest node in the svo tree that contains this position
func _convert_to_svolink(svo_depth: int, extent_size: float, position: Vector3) -> int:
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
