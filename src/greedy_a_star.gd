@tool
extends AFlightPathFinder
class_name GreedyAStar

## A Callable that determines which endpoints are used to calculate distance
## between two voxels/nodes.[br]
##
## Only Voxel Centers is currently supported. This property stays exported so
## older resources that serialized Face Centers can safely fall back.
@export_enum("Voxel Centers") var endpoints: String = "Voxel Centers":
	set(value):
		_endpoint_mode = _parse_endpoint_mode(value)
		endpoints = _stringify_endpoint_mode(_endpoint_mode)
		_get_endpoints = _resolve_endpoint_callable(_endpoint_mode)

# Signature: func(svolink1, svolink2, svo) -> [Vector3, Vector3].
var _get_endpoints: Callable = AFlightPathFinder.get_centers
var _endpoint_mode: EndpointMode.Enum = EndpointMode.Enum.VOXEL_CENTERS


## Function used to estimate cost between a voxel and destination
## And used to calculate adjacent voxels cost, if [member use_unit_cost] is disabled
@export_enum("Euclidean", "Manhattan") var distance_function: String = "Euclidean":
	set(value):
		_distance_mode = _parse_distance_mode(value)
		distance_function = _stringify_distance_mode(_distance_mode)
		_get_distance = _resolve_distance_callable(_distance_mode)

# Signature: func(Vector3, Vector3) -> float
var _get_distance: Callable = AFlightPathFinder.euclidean
var _distance_mode: DistanceMode.Enum = DistanceMode.Enum.EUCLIDEAN


## Bias weight. The higher it is, the more A* is biased toward estimation
## and prefers exploring nodes it thinks are closer to the goal.
@export var w: float = 1.0

## The bigger the node, the less it costs to move through it.[br]
## The factor is a function: (Node layer, SVO Depth) -> float(0, 1][br]
## Minimum value is reached when a link points to the root node.[br]
## Maximum value 1 is reached when a link points to a subgrid voxel.[br]
@export var use_size_compensation_factor: bool = true

## If true, the cost between two voxels is [member unit_cost] no matter their sizes.
## Otherwise, use [member distance_function] to calculate.
@export var use_unit_cost: bool = true

## Unit cost used when [member use_unit_cost] is true.
@export var unit_cost: float = 1.0

func _init() -> void:
	endpoints = endpoints
	distance_function = distance_function

func _find_path(start: int, destination: int, svo: SVO) -> PackedInt64Array:
	if start == SvoLink64.singleton.null_link() \
		or destination == SvoLink64.singleton.null_link():
		return []

	# The Priority Queue of nodes to search, ordered by lowest estimated total cost
	var frontier: PriorityQueue = PriorityQueue.new([], 
		func (a: SearchNode, b: SearchNode) -> bool:
			return a.estimated_total_cost > b.estimated_total_cost)
	frontier.push(SearchNode.new(INF, start))
	
	# travel_cost[node] returns the current cost to travel
	# from starting point to node
	# Key - Value: SVOLink - Real Cost
	var travel_cost: Dictionary = {start: 0}
	
	# breadcrumb[i] = j means j is the closest route found 
	# from @start to @destination to i
	var breadcrumb: Dictionary = {start: SvoLink64.singleton.null_link()}
	var context := SearchContext.new(
		destination,
		svo,
		travel_cost,
		breadcrumb,
		frontier
	)
	
	while frontier.size() > 0:
		# Get the next most promising node that we haven't visited to examine
		var best_node: SearchNode = frontier.pop()
		var best_node_link: int = best_node.svolink
		
		if best_node_link == destination:
			break
		
		var bn_neighbors: PackedInt64Array = svo.get_neighbors_of(best_node_link)
		
		for neighbor in bn_neighbors:
			_relax_neighbor(
				best_node_link,
				neighbor,
				context
			)
	
	if not travel_cost.has(destination):
		return []
	
	return _reconstruct_path(breadcrumb, start, destination)


## A candidate node in the A* search frontier with its estimated total cost.
class SearchNode:
	var estimated_total_cost: float
	var svolink: int

	func _init(p_estimated_total_cost: float, p_svolink: int) -> void:
		estimated_total_cost = p_estimated_total_cost
		svolink = p_svolink


class SearchContext:
	var destination: int
	var svo: SVO
	var travel_cost: Dictionary
	var breadcrumb: Dictionary
	var frontier: PriorityQueue

	func _init(
		p_destination: int,
		p_svo: SVO,
		p_travel_cost: Dictionary,
		p_breadcrumb: Dictionary,
		p_frontier: PriorityQueue
	) -> void:
		destination = p_destination
		svo = p_svo
		travel_cost = p_travel_cost
		breadcrumb = p_breadcrumb
		frontier = p_frontier


## [param best_node_link]: Current best node link being expanded[br]
## [param neighbor]: Neighbor node link to evaluate[br]
## [param context]: [SearchContext] holding search data structures[br]
## Return: void.[br]
func _relax_neighbor(
	best_node_link: int,
	neighbor: int,
	context: SearchContext
) -> void:
	# Ignore obstacles
	if context.svo.is_solid(neighbor):
		context.travel_cost[neighbor] = INF
		return
	
	var neighbor_cost_of_current_visit: float = context.travel_cost[best_node_link] \
			+ compute_cost(best_node_link, neighbor, context.svo)
	
	if neighbor_cost_of_current_visit < context.travel_cost.get(neighbor, INF):
		context.travel_cost[neighbor] = neighbor_cost_of_current_visit
		context.breadcrumb[neighbor] = best_node_link
		var total_estimated_cost: float = neighbor_cost_of_current_visit \
			+ estimate_cost(neighbor, context.destination, context.svo)
		context.frontier.push(SearchNode.new(total_estimated_cost, neighbor))


## [param breadcrumb]: Predecessor map tracking the search path[br]
## [param start]: Starting node link[br]
## [param destination]: Destination node link[br]
## Return: Path of node links from start to destination[br]
func _reconstruct_path(breadcrumb: Dictionary, start: int, destination: int) -> PackedInt64Array:
	var path: PackedInt64Array = [destination]
	while path[-1] != start:
		path.push_back(breadcrumb[path[-1]])
	path.reverse()
	return path


## [param start]: Starting node link[br]
## [param destination]: Destination node link[br]
## [param svo]: Sparse Voxel Octree structure[br]
## Return: Distance measured between the two nodes[br]
func _distance_between_nodes(start: int, destination: int, svo: SVO) -> float:
	return _get_distance.callv(_get_endpoints.call(start, destination, svo))


func _compute_cost(start: int, destination: int, svo: SVO) -> float:
	var cost: float = 0.0
	if use_unit_cost:
		cost = unit_cost
	else:
		cost = _distance_between_nodes(start, destination, svo)
	
	if use_size_compensation_factor:
		return cost * compute_size_compensation_factor(SvoLink64.singleton.get_layer(destination), svo.depth)
	return cost


func _estimate_cost(start: int, destination: int, svo: SVO) -> float:
	return w * _distance_between_nodes(start, destination, svo)


func _parse_endpoint_mode(value: String) -> EndpointMode.Enum:
	return EndpointMode.Enum.VOXEL_CENTERS


func _stringify_endpoint_mode(_mode: EndpointMode.Enum) -> String:
	return "Voxel Centers"


func _resolve_endpoint_callable(mode: EndpointMode.Enum) -> Callable:
	match mode:
		EndpointMode.Enum.VOXEL_CENTERS:
			return AFlightPathFinder.get_centers
		_:
			return AFlightPathFinder.get_centers


func _parse_distance_mode(value: String) -> DistanceMode.Enum:
	match value:
		"Manhattan":
			return DistanceMode.Enum.MANHATTAN
		_:
			return DistanceMode.Enum.EUCLIDEAN


func _stringify_distance_mode(mode: DistanceMode.Enum) -> String:
	match mode:
		DistanceMode.Enum.MANHATTAN:
			return "Manhattan"
		DistanceMode.Enum.EUCLIDEAN:
			return "Euclidean"
		_:
			return "Euclidean"


func _resolve_distance_callable(mode: DistanceMode.Enum) -> Callable:
	match mode:
		DistanceMode.Enum.MANHATTAN:
			return AFlightPathFinder.manhattan
		DistanceMode.Enum.EUCLIDEAN:
			return AFlightPathFinder.euclidean
		_:
			return AFlightPathFinder.euclidean
