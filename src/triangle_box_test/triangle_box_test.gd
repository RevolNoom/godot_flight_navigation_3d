## Fast triangle-box test as described by Michael Schwarz and Hans-Peter Seidel.
## Used for surface voxelization.
extends RefCounted
class_name TriangleBoxTest

## Determines how "thick" the surface voxelization is.
enum Separability {
	## Thin voxelization.[br]
	## [b]WARNING: [/b]Due to floating-point inaccuracy, 
	## a water-tight object might have a non-water-tight voxel representation.[br]
	## Thus, it is recommended to also perform a solid voxelization.
	SEPARATING_6,
	
	## Conservative voxelization.[br]
	## The surface contains all voxels it cuts through, even merely touched.
	SEPARATING_26,
}

## Initialize a new triangle-box test.[br]
## [br]
## [param v]: Positions of 3 triangle vertices.[br]
## [param dp]: Box size.
func _init(
	_v0_f32: Vector3, 
	_v1_f32: Vector3, 
	_v2_f32: Vector3, 
	_dp_f32: Vector3, 
	_separability: Separability,
	_epsilon_value: float):
		pass


## Return true if triangle overlaps voxel at [param minimum_corner] position.[br]
## [br]
## [b]Note:[/b] This test doesn't check whether triangle's bounding box overlaps voxel, 
## which is a prerequisite. Do that test first to get potential overlapping voxels
## and then feed them here.
func overlap_voxel(minimum_corner: Vector3) -> bool:
	return plane_overlaps(minimum_corner) and \
	projection_xy_overlaps(minimum_corner) and \
	projection_yz_overlaps(minimum_corner) and \
	projection_zx_overlaps(minimum_corner)


## Return true if triangle's plane
## overlaps voxel at [param minimum_corner] position.[br]
func plane_overlaps(_minimum_corner: Vector3) -> bool:
	return false
	

## Return true if projections on xy of triangle
## overlaps projections on xy of voxel at [param minimum_corner] position.[br]
func projection_xy_overlaps(_minimum_corner: Vector3) -> bool:
	return false
	

## Return true if projections on yz of triangle
## overlaps projections on yz of voxel at [param minimum_corner] position.[br]
func projection_yz_overlaps(_minimum_corner: Vector3) -> bool:
	return false


## Return true if projections on zx of triangle
## overlaps projections on zx of voxel at [param minimum_corner] position.[br]
func projection_zx_overlaps(_minimum_corner: Vector3) -> bool:
	return false


func x_projection_on_plane(_y: float, _z: float) -> float:
	return NAN


func y_projection_on_plane(_x: float, _z: float) -> float:
	return NAN
	

func z_projection_on_plane(_x: float, _y: float) -> float:
	return NAN
