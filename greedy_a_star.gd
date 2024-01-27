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
		#print("Unsearched size: %d" % unsearched.size())
		var best_node = unsearched.pop()
		var bn_neighbors := svo.neighbors_of(best_node[SvoLink])
		for neighbor in bn_neighbors:
			if charted.has(neighbor):
				continue
			
			var neighbor_cost = charted[best_node[SvoLink]] \
					+ _compute_cost(best_node[SvoLink], neighbor, svo)
			charted[neighbor] = neighbor_cost
			if neighbor == to:
				break
			unsearched.push([neighbor_cost\
				+ _estimate_cost(neighbor, to, svo)\
				, neighbor])
	
	if not charted.has(to):
		return []
	
	var path: PackedInt64Array = [to]
	
	while path[path.size()-1] != from:
		print("path size: %d" % path.size())
		var back_node := path[path.size()-1]
		var neighbors := svo.neighbors_of(back_node)
		var pathlength = path.size()
		for n in neighbors:
			if charted[n] + _compute_cost(n, back_node, svo) == charted[back_node]:
				path.append(n)
				break
		if path.size() == pathlength:
			print("b: %s" % Morton.int_to_bin(back_node))
			print("Charted backnode: %f" % charted[back_node])
			for n in neighbors:
				print("n: %s" % Morton.int_to_bin(n))
				if SVOLink.layer(n) == 0:
					(get_parent() as FlyingNavigation3D).draw_svolink_box(n, Color.AQUAMARINE)
					print("L%d M%v O%v" %\
						 [SVOLink.layer(n), 
						Morton3.decode_vec3(svo.node_from_link(n).morton), 
						Morton3.decode_vec3(SVOLink.offset(n))])
				print("%f + %f != %f" % [charted[n], _compute_cost(n, back_node, svo), charted[back_node]])
			
			#print("Neighbors: \n%s" % str(Array(neighbors).map(func(svolink): 
				#return "L%d M%v O%v" %\
				 #[SVOLink.layer(svolink), 
				#Morton3.decode_vec3(svo.node_from_link(svolink).morton), 
				#Morton3.decode_vec3(SVOLink.offset(svolink))])))
				
			#print("Neighbors pos after convert SVO: %s" % str(Array(neighbors).map(func(svolink):
					#return get_parent().get_global_position_of(svolink))))
			break
	path.reverse()
	return path


## @from, @to: SVOLink
## Calculate the cost between two connected voxels 
## Direction is from @from to @to
func _compute_cost(from: int, to: int, svo: SVO) -> float:
	#var layer_f = SVOLink.layer(svolink_from)
	#var layer_t = SVOLink.layer(svolink_to)
	
	#var grid_f = SVOLink.subgrid(svolink_from)
	#var grid_t = SVOLink.subgrid(svolink_to)
	
	#return 0
	return unit_cost * (1 - SVOLink.layer(to) * size_compensation_factor)


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
	return _node_center(svolink1, svo).distance_to(_node_center(svolink2, svo))


## Calculate the center of the voxel
## where 1 unit distance corresponds to side length of 1 subgrid voxel
func _node_center(svolink: int, svo: SVO) -> Vector3:
	var node = svo.node_from_link(svolink)
	var layer = SVOLink.layer(svolink)
	var corner_pos = Morton3.decode_vec3(node.morton)\
			* (2 ** (layer+2))
	
	# In case layer 0 node has some solid voxels, the center
	# is the center of the subgrid voxel, not of the node
	if layer == 0 and node.first_child != 0:
		return corner_pos + Morton3.decode_vec3(SVOLink.subgrid(svolink))\
				+ Vector3(1,1,1)*0.5
			
	return corner_pos + Vector3(1,1,1) * (2 ** (layer+1))


func _manhattan(svolink1: int, svolink2: int, svo: SVO):
	pass
	

func _on_property_list_changed():
	update_configuration_warnings()
	
func _get_configuration_warnings():
	if get_parent() == null or not get_parent() is FlyingNavigation3D:
		return ["Must be a child of FlyingNavigation3D"]
	return []
