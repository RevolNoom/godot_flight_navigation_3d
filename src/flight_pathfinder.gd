## Interface for various path finding algorithms.
##
## 
extends Resource
class_name FlightPathfinder

func _init():
	printerr("FlightPathfinder is abstract. Instantiate a derived class instead.")

## Return a path of [SVOLink]s connecting [param from] and [param to] through [param svo].[br]
##
## If no path is found, an empty array is returned.[br]
##
## [b]NOTE:[/b] This method [b]MUST[/b] be overridden[br]
func find_path(from: int, to: int, svo: SVO) -> PackedInt64Array:
	return _find_path(from, to, svo)


## Calculate the cost to travel from [param start] to [param destination].[br]
## [param start], [param destination] are [SVOLink]s[br]
func compute_cost(start: int, destination: int, svo: SVO) -> float:
	return _compute_cost(start, destination, svo)


## Calculate the cost to travel from [param start] to [param destination]
## [param start], [param destination] are [SVOLink]s[br]
func estimate_cost(start: int, destination: int, svo: SVO) -> float:
	return _estimate_cost(start, destination, svo)


#### OVERRIDDEN-ABLE METHODS ####


## [b]OVERRIDE ME![/b][br]
func _find_path(_from: int, _to: int, _svo: SVO) -> PackedInt64Array:
	printerr("_find_path() not overridden in class ", get_class())
	return []


## [b]OVERRIDE ME![/b][br]
## Default to Euclidean distance.[br]
func _compute_cost(start: int, destination: int, svo: SVO) -> float:
	return FlightPathfinder.euclidean(svo.get_center(start), svo.get_center(destination))


## [b]OVERRIDE ME![/b][br]
func _estimate_cost(start: int, destination: int, svo: SVO) -> float:
	return FlightPathfinder.euclidean(svo.get_center(start), svo.get_center(destination))


#### UTILITY FUNCTIONS ####

## Return the size compensation factor for a node in [param node_layer].[br]
##
## Usually used in [method compute_cost] and [method estimate_cost],
## it introduces a factor that reduces the cost to move through big nodes.
## Thus, bigger nodes become more appealling to the finder.[br]
##
## [param svo_depth] is the depth of the [SVO][br]
##
## [b]NOTE:[/b] [param node_layer] is -2 if it's a subgrid voxel.[br]
##
## [b]NOTE:[/b] This is a helper function. Its use is optional.[br] 
func compute_size_compensation_factor(node_layer: int, svo_depth: int) -> float:
	return float(svo_depth - node_layer) / (svo_depth + 2.0)


## Return the Euclidean distance between [param pos1] and [param pos2][br]
static func euclidean(pos1: Vector3, pos2: Vector3) -> float:
	return pos1.distance_to(pos2)


## Return the Manhattan distance between [param pos1] and [param pos2][br]
static func manhattan(pos1: Vector3, pos2: Vector3) -> float:
	var manhattan_diff = (pos1-pos2).abs()#
	return manhattan_diff.x + manhattan_diff.y + manhattan_diff.z


## [b]TODO:[/b]
##
## Return array of 2 Vector3 that are centers of two faces with minimum distance
## between two nodes/voxels identified as [param svolink1] and [param svolink2] 
## in [param svo].[br]
##
## [param svolink1] and [param svolink2] are [SVOLink]s.[br]
static func get_closest_faces(svolink1: int, svolink2: int, svo: SVO) -> PackedVector3Array:
	printerr("get_closest_faces TODO")
	return []


## Return array of 2 Vector3 that are centers of two nodes/voxels 
## identified as [param svolink1] and [param svolink2] in [param svo].[br]
##
## [param svolink1] and [param svolink2] are [SVOLink]s[br]
static func get_centers(svolink1: int, svolink2: int, svo: SVO) -> PackedVector3Array:
	return [svo.get_center(svolink1), svo.get_center(svolink2)]
