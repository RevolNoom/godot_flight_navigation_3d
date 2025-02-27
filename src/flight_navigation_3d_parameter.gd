extends RefCounted
class_name FlightNavigation3DParameter

## Determine how detailed the space will be voxelized.[br]
## Increase this value will exponentially increase memory usage and voxelization time.[br]
@export_range(3, 15, 1) var depth: int = 7

## Remove triangles with area close to zero before voxelization (recommended).[br]
## FlightNavigation3D uses CSG nodes internally, and the result meshes contain 
## lots of thin triangles which usually have 2 vertices in the same position.
@export var cull_slivers: bool = true

## Perform tasks in parallel to speed up the process.[br]
## (Usually set false for debugging purposes)
@export var multithreading: bool = true
