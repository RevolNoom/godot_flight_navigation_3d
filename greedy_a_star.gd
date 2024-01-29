@tool
extends Node
class_name GreedyAStar

## TODO: Support Face Centers in the future
#@export_enum("Face Centers", "Voxel Centers") var endpoints = "Voxel Centers":
#	set(value):
#		endpoints = "Voxel Centers"
#		endpoints = value
#		if endpoints == "Face Centers":
#			_endpoints = _face_centers
#		else:
#			_endpoints = _node_centers
#var _endpoints: Callable

## Function used to estimate cost between a voxel and destination
## And used to calculate adjacent voxels cost, if @use_unit_cost is disabled
## TODO: Support Manhattan in the future
@export_enum("Euclidean", "Manhattan") var distance = "Euclidean":
	set(value):
		distance = value
		if distance == "Euclidean":
			_distance = _euclidean
		else:
			_distance = _manhattan
var _distance: Callable = _euclidean

## Bias weight. The higher it is, the more A* is biased toward estimation,
## prefer exploring nodes it thinks are closer to the goal
@export var w: float = 1

## The bigger the node, the less it costs to move through it
@export var size_compensation_factor: float = 0.05

## If true, the cost between two voxels is unit_cost no matter their sizes
## Otherwise, use distance function to calculate
## TODO: Actually make it works
@export var use_unit_cost: bool = true

## No matter how big the node is, travelling
## through it has the same cost
@export var unit_cost: float = 1


## @svo: A SVO contains collision information
## @from: SVOLink
## @to: SVOLink
## @return: The path connecting @from and @to through the navigation space, as SVOLinks
func find_path(from: int, to: int, svo: SVO) -> PackedInt64Array:
	return _greedy_a_star(from, to, svo)


## @from, @to: SVOLink
## Return an array of SVOLinks represents a 
## connected path between @from and @to
## Return empty array if path not found
func _greedy_a_star(from: int, to: int, svo: SVO) -> PackedInt64Array:
	# The Priority Queue of nodes to search
	# Element: [TotalCostEstimated, SVOLink]
	# Sorted by TCE. TCE = f(x) = g(x) + h(x).
	# pop() returns element with smallest TCE
	const TotalCostEstimated = 0
	const SvoLink = 1
	var frontier:= PriorityQueue.new(
		func (u1, u2) -> bool:
			return u1[TotalCostEstimated] > u2[TotalCostEstimated])
	frontier.push([INF, from])
	
	# travel_cost[node] returns the current cost to travel
	# from starting point to node
	# Key - Value: SVOLink - Real Cost
	var travel_cost: Dictionary = {from: 0}
	
	# Nodes already visited and cannot be visited anymore
	# Key: SVOLink. Value doesn't matter, but recommended to be null for less memory usage?
	var visited: Dictionary = {}
	
	while frontier.size() > 0:
		#print("frontier size: %d" % frontier.size())
		# Get the next most promising node that we haven't visited to examine
		var best_node
		while frontier.size() > 0:
			best_node = frontier.pop()
			if not visited.has(best_node[SvoLink]):
				break
				
		# In case we have exhausted all frontier nodes but no unvisited node is found
		# That means there's no path to destination
		if visited.has(best_node[SvoLink]):
			break
		
		# Mark node as visited
		visited[best_node[SvoLink]] = null
		
		var bn_neighbors := svo.neighbors_of(best_node[SvoLink])
		
		for neighbor in bn_neighbors:
			
			## DEBUG:
			#if neighbor == 1509:
				#print("best_node: %d" % best_node[SvoLink])
				#print("Neighbor: %d" % neighbor)
				#(get_parent() as FlyingNavigation3D).draw_svolink_box(neighbor, Color.RED, Color.BLUE)
				#(get_parent() as FlyingNavigation3D).draw_svolink_box(best_node[SvoLink], Color.RED, Color.BLUE)
				#return []
				
			# Ignore obstacles
			if svo.is_link_solid(neighbor):
				travel_cost[neighbor] = INF
				visited[neighbor] = null
				continue
			
			var neighbor_cost_of_current_visit = travel_cost[best_node[SvoLink]] \
					+ _compute_cost(best_node[SvoLink], neighbor, svo)
			
			if neighbor_cost_of_current_visit < travel_cost.get(neighbor, INF):
				travel_cost[neighbor] = neighbor_cost_of_current_visit
				if not visited.has(neighbor):
					frontier.push([neighbor_cost_of_current_visit\
						+ _estimate_cost(neighbor, to, svo)\
						, neighbor])
			if neighbor == to:
				visited[neighbor] = null
				print("Reached")
				break
		# The destination has been reached. Return the path now
		if visited.has(to):
			break
			
	#for travel_cost_link in travel_cost.keys():
		## TODO: Print out problematic links and find out which node got that link as neighbors
		#(get_parent() as FlyingNavigation3D).draw_svolink_box(travel_cost_link, Color.RED, Color.BLUE) #, str(travel_cost[travel_cost_link]))
	
	if not visited.has(to):
		return []
	
	var path: PackedInt64Array = [to]
	while path[path.size()-1] != from:
		print("path size: %d" % path.size())
		var back_node := path[path.size()-1]
		var neighbors := svo.neighbors_of(back_node)
		var pathlength = path.size()
		for n in neighbors:
			if n == 1008:
				print("1008 spotted")
				print("1008 solid? %s" % svo.is_link_solid(n))
				print("Expression: %f + %f = %f ? %f" % \
					[travel_cost.get(n, INF),
					_compute_cost(n, back_node, svo), 
					travel_cost.get(n, INF) + _compute_cost(n, back_node, svo), 
					travel_cost[back_node]])
			if travel_cost.get(n, INF) + _compute_cost(n, back_node, svo) == travel_cost[back_node]:
				path.append(n)
				break
	path.reverse()
	return path


## @from, @to: SVOLink
## Calculate the cost between two connected voxels 
## Direction is from @from to @to
# TODO: Is this size compensation factor working as expected?
func _compute_cost(from: int, to: int, svo: SVO) -> float:
	if svo.is_subgrid_voxel(to):
		return unit_cost
	return unit_cost * (1 - (SVOLink.layer(to) + 2) * size_compensation_factor)


## Calculate the cost to travel from @svolink to @destination
func _estimate_cost(svolink: int, destination: int, svo: SVO) -> float:
	return w * _distance.call(svolink, destination, svo)

## @extent: The length of one side of the navigation space (assumed to be cube)
## Return SVOLink of the smallest node in @svo that contains @position
func _convert_to_svolink(position: Vector3, extent: float, svo: SVO) -> int:
	return 0


#func _node_centers():
#	pass
	
#func _face_centers():
#	pass


func _euclidean(svolink1: int, svolink2: int, svo: SVO) -> float:
	## TODO: Maybe distance_squared_to is a better choice?
	return svo.get_center(svolink1).distance_to(svo.get_center(svolink2))


func _manhattan(svolink1: int, svolink2: int, svo: SVO):
	pass
	

func _on_property_list_changed():
	update_configuration_warnings()
	
func _get_configuration_warnings():
	if get_parent() == null or not get_parent() is FlyingNavigation3D:
		return ["Must be a child of FlyingNavigation3D"]
	return []
