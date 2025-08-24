extends RefCounted
class_name FlightNavigation3DParameter

## Determine how detailed the space will be voxelized.
## [br]
## Increase this value will exponentially increase memory usage and voxelization time.
@export_range(2, 15, 1) var depth: int = 7

## Remove triangles with area close to zero before voxelization (recommended).
## [br]
## FlightNavigation3D uses CSG nodes internally, and the result meshes contain 
## lots of triangles with 2 vertices in the same position.
@export var remove_thin_triangles: bool = true

## Enable multi-threading while building navigation data. [br]
## Set to false for easier debugging in single-threading
@export var multi_threading: bool = true

## Thread priority when used in [member multi_threading]
@export var thread_priority: Thread.Priority = Thread.PRIORITY_LOW

## Surface voxelization "thickness". [br]
## Default to conservative voxelization (all voxels touched by the surface).
@export var surface_separability:\
	TriangleBoxTest.Separability = TriangleBoxTest.Separability.SEPARATING_26

## [DEBUG] Whether CSG nodes created for each Voxelization targets 
## are deleted after voxelization.
## [br]
## Used to visualize and debug CSG nodes creation.
@export var delete_csg: bool = true
