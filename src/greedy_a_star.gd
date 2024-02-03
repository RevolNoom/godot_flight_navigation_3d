@tool
extends FlightPathfinder
class_name GreedyAStar

## [b]TODO:[/b] Support Face Centers in the future.[br]
## A Callable that determines which endpoints are used to calculate distance
## between two voxels/nodes 
@export_enum("Face Centers", "Voxel Centers") var endpoints = "Voxel Centers":
	set(value):
		endpoints = value
		if endpoints == "Face Centers":
			_get_endpoints = FlightPathfinder.get_closest_faces
		else:
			_get_endpoints = FlightPathfinder.get_centers

# Signature: func(svolink1, svolink2, svo) -> [Vector3, Vector3].
var _get_endpoints: Callable = FlightPathfinder.get_centers


## Function used to estimate cost between a voxel and destination
## And used to calculate adjacent voxels cost, if [member use_unit_cost] is disabled
@export_enum("Euclidean", "Manhattan") var distance_function = "Euclidean":
	set(value):
		distance_function = value
		if distance_function == "Euclidean":
			_get_distance = FlightPathfinder.euclidean
		else:
			_get_distance = FlightPathfinder.manhattan

# Signature: func(Vector3, Vector3) -> float
var _get_distance: Callable = FlightPathfinder.euclidean


## Bias weight. The higher it is, the more A* is biased toward estimation,
## prefers exploring nodes it thinks are closer to the goal
## BUG: Setting w=2 makes the game freeze
@export var w: float = 1.0

## The bigger the node, the less it costs to move through it.[br]
## The factor is a function: (Node layer, SVO Depth) -> float(0, 1][br]
## Minimum value is reached when a link points to the root node.[br]
## Maximum value 1 is reached when a link points to a subgrid voxel.[br]
@export var use_size_compensation_factor: bool = true

## If true, the cost between two voxels is [member unit_cost] no matter their sizes.
## Otherwise, use [member distance_function] to calculate.
## TODO: Actually make it works
@export var use_unit_cost: bool = true

## Unit cost used when [member use_unit_cost] is true.
@export var unit_cost: float = 1.0

func _ready():
	endpoints = endpoints
	distance_function = distance_function

func _find_path(start: int, destination: int, svo: SVO) -> PackedInt64Array:
	# The Priority Queue of nodes to search
	# Element: [TotalCostEstimated, SVOLink]
	# Sorted by TCE. TCE = f(x) = g(x) + h(x).
	# pop() returns element with smallest TCE
	const TotalCostEstimated = 0
	const SvoLink = 1
	var frontier:= PriorityQueue.new([],
		func (u1, u2) -> bool:
			return u1[TotalCostEstimated] > u2[TotalCostEstimated])
	frontier.push([INF, start])
	
	# travel_cost[node] returns the current cost to travel
	# from starting point to node
	# Key - Value: SVOLink - Real Cost
	var travel_cost: Dictionary = {start: 0}
	
	# breadcrumb[i] = j means j is the closest route found 
	# from @start to @destination to i
	var breadcrumb: Dictionary = {start: SVOLink.NULL}
	
	
	#var test:= PriorityQueue.new(
	#[[21.4326663970947, 114], [21.9248672485352, 128], [22.7359443664551, 100], [22.070911026001, 102], [23.2495037078857, 70], [22.7359443664551, 82], [23.2936111450195, 96], [23.2936111450195, 80], [23.8808933258057, 66], [22.6454082489014, 98], [22.6454082489014, 84], [22.0242858886719, 112], [22.070911026001, 86], [23.8808933258057, 68], [21.9248672485352, 256], [21.4326663970947, 116], [24.4956069946289, 64]]
		#
		#,
		#func (u1, u2) -> bool:
			#return u1[TotalCostEstimated] > u2[TotalCostEstimated])
	#
	#while not test.is_empty():
		#print(test.pop()[0])
	#return []
	while frontier.size() > 0:
		# Get the next most promising node that we haven't visited to examine
		var best_node = frontier.pop()
		var best_node_link = best_node[SvoLink]
		
		#print("%s" % str(frontier.to_array()))
		#print()
		#if best_node_link in [3331, 3363]:
			#print("best: %d, f: %f" % [best_node_link, best_node[TotalCostEstimated]])
		#print("best: %d, f: %f" % [best_node_link, best_node[TotalCostEstimated]])
		#OS.delay_msec(5)
		
		#get_parent().draw_svolink_box(best_node_link, Color.GREEN, Color.GREEN, "")
		if best_node_link == destination:
			break
		
		#print(best_node[TotalCostEstimated])
		var bn_neighbors := svo.neighbors_of(best_node_link)
		
		for neighbor in bn_neighbors:
			# Ignore obstacles
			if svo.is_link_solid(neighbor):
				travel_cost[neighbor] = INF
				continue
			
			var neighbor_cost_of_current_visit = travel_cost[best_node_link] \
					+ compute_cost(best_node_link, neighbor, svo)
			
			if neighbor_cost_of_current_visit < travel_cost.get(neighbor, INF):
				travel_cost[neighbor] = neighbor_cost_of_current_visit
				breadcrumb[neighbor] = best_node_link
				#get_parent().draw_svolink_box(neighbor, Color.GRAY, Color.GRAY, "")
				frontier.push([neighbor_cost_of_current_visit\
					+ estimate_cost(neighbor, destination, svo)\
					, neighbor])
			#print()
	
	if not travel_cost.has(destination):
		return []
	
	#for debug_link in [3335]:
		#print("%d cost: %f" %[debug_link, travel_cost[debug_link]])
		#get_parent().draw_svolink_box(debug_link, Color.PEACH_PUFF, Color.PEACH_PUFF, str(travel_cost[debug_link]))
		#for neighbor in svo.neighbors_of(debug_link):
			##print("Neighbor %d cost: %f" %[neighbor, travel_cost[neighbor]])
			#var est = estimate_cost(neighbor, destination, svo)
			#get_parent().draw_svolink_box(neighbor, Color.ORANGE_RED, Color.ORANGE_RED, 
				#SVOLink.get_format_string(neighbor, svo) + "\n" + str(travel_cost[neighbor]) + "\n" + str(est))
		
		
	var path: PackedInt64Array = [destination]
	while path[-1] != start:
		path.push_back(breadcrumb[path[-1]])
	path.reverse()
	
	#for debug_link in travel_cost.keys():
		#get_parent().draw_svolink_box(debug_link, Color.RED, Color.BLUE, str(travel_cost[debug_link]))
		
	return path


func _compute_cost(start: int, destination: int, svo: SVO) -> float:
	var cost := 0.0
	if use_unit_cost:
		cost = unit_cost
	else:
		cost = _get_distance.callv(_get_endpoints.call(start, destination, svo))
	
	if use_size_compensation_factor:
		return cost * compute_size_compensation_factor(SVOLink.layer(destination), svo.depth)
	return cost


func _estimate_cost(start: int, destination: int, svo: SVO) -> float:
	return w * _get_distance.callv(_get_endpoints.call(start, destination, svo))# \
			#* compute_size_compensation_factor(SVOLink.layer(start), svo.depth)
