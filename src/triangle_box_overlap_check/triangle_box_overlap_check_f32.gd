## Fast triangle-box test as described by Michael Schwarz and Hans-Peter Seidel.
##
## This triangle-box test uses float32. 
## Since Vector in Godot also uses float32, it helps the test runs faster 
## and consumes less memory
extends ATriangleBoxOverlapCheck
class_name TriangleBoxOverlapCheckF32

var epsilon: float

var v0: Vector3 = Vector3.ZERO
var v1: Vector3 = Vector3.ZERO
var v2: Vector3 = Vector3.ZERO

## Triangle normal
var n: Vector3 = Vector3.ZERO

## Plane equation: ax + by + cz = d
##
## n.dot(v0) = d
##
## Used for calculation of projection of one Vector3 on the plane.
var n_dot_v0: float = 0

## Edges normal projections on xy.
var n_xy_e0: Vector2 = Vector2.ZERO
var n_xy_e1: Vector2 = Vector2.ZERO
var n_xy_e2: Vector2 = Vector2.ZERO

## Edges normal projections on yz.
var n_yz_e0: Vector2 = Vector2.ZERO
var n_yz_e1: Vector2 = Vector2.ZERO
var n_yz_e2: Vector2 = Vector2.ZERO

## Edges normal projections on zx.
var n_zx_e0: Vector2 = Vector2.ZERO
var n_zx_e1: Vector2 = Vector2.ZERO
var n_zx_e2: Vector2 = Vector2.ZERO

## Edges projected distances(?) on xy.
var d_xy_e0: float = 0
var d_xy_e1: float = 0
var d_xy_e2: float = 0

## Edges projected distances(?) on yz.
var d_yz_e0: float = 0
var d_yz_e1: float = 0
var d_yz_e2: float = 0

## Edges projected distances(?) on zx.
var d_zx_e0: float = 0
var d_zx_e1: float = 0
var d_zx_e2: float = 0

## Critical point factor.
## Determine whether triangle plane separates two critical points.
var d1: float = 0

## (Opposite) Critical point factor
## Determine whether triangle plane separates two critical points.
var d2: float = 0

## Initialize a new triangle-box test.[br]
## [br]
## [param v]: Positions of 3 triangle vertices.[br]
## [param dp]: Box size.
func _init(
	v0_f32: Vector3, 
	v1_f32: Vector3, 
	v2_f32: Vector3, 
	dp_f32: Vector3, 
	separability: Separability.Enum,
	epsilon_value: float) -> void:
	epsilon = epsilon_value
		
	v0 = v0_f32
	v1 = v1_f32
	v2 = v2_f32
	
	# Edge equations
	var e0: Vector3 = v1 - v0
	var e1: Vector3 = v2 - v1
	var e2: Vector3 = v0 - v2
	
	# Triangle normal
	# NOTE: This order of vector is important. Copied from cuda_voxelizer
	n = e0.cross(e1)

	n_dot_v0 = n.dot(v0)
	
	# Normalization creates too much inaccuracy, and thus omitted
	#Dvector.normalize(n, n)
	
	_init_normal_projections(e0, e1, e2)
	
	# Distance factors
	match separability:
		Separability.Enum.SEPARATING_6:
			_init_separating_6(dp_f32)
		Separability.Enum.SEPARATING_26:
			_init_separating_26(dp_f32)
	
	# Initialization complete.


## Calculate normal projections of triangle edges on coordinate planes.[br]
## [param e0]: Edge vector from v0 to v1.[br]
## [param e1]: Edge vector from v1 to v2.[br]
## [param e2]: Edge vector from v2 to v0.[br]
func _init_normal_projections(e0: Vector3, e1: Vector3, e2: Vector3) -> void:
	# n.z >= 0
	if n.z >= 0:
		n_xy_e0 = Vector2(-e0.y, e0.x)
		n_xy_e1 = Vector2(-e1.y, e1.x)
		n_xy_e2 = Vector2(-e2.y, e2.x)
	else:
		n_xy_e0 = Vector2(e0.y, -e0.x)
		n_xy_e1 = Vector2(e1.y, -e1.x)
		n_xy_e2 = Vector2(e2.y, -e2.x)
	
	# n.x >= 0
	if n.x >= 0:
		n_yz_e0 = Vector2(-e0.z, e0.y)
		n_yz_e1 = Vector2(-e1.z, e1.y)
		n_yz_e2 = Vector2(-e2.z, e2.y)
	else:
		n_yz_e0 = Vector2(e0.z, -e0.y)
		n_yz_e1 = Vector2(e1.z, -e1.y)
		n_yz_e2 = Vector2(e2.z, -e2.y)
	
	# n.y >= 0
	if n.y >= 0:
		n_zx_e0 = Vector2(-e0.x, e0.z)
		n_zx_e1 = Vector2(-e1.x, e1.z)
		n_zx_e2 = Vector2(-e2.x, e2.z)
	else:
		n_zx_e0 = Vector2(e0.x, -e0.z)
		n_zx_e1 = Vector2(e1.x, -e1.z)
		n_zx_e2 = Vector2(e2.x, -e2.z)


## Calculate separating edge distance projection on a 2D plane.[br]
## [param dp]: Box size projected on the 2D plane.[br]
## [param v]: Triangle vertex projected on the 2D plane.[br]
## [param n_edge]: Edge normal projection on the 2D plane.[br]
## Return: projected edge distance factor.[br]
func _calculate_separating_6_edge_distance(dp: Vector2, v: Vector2, n_edge: Vector2) -> float:
	var dp_n: float = 0.0
	var abs_n_x: float = absf(n_edge.x)
	var abs_n_y: float = absf(n_edge.y)
	if abs_n_x > abs_n_y:
		dp_n = dp.x * abs_n_x / 2.0
	else:
		dp_n = dp.y * abs_n_y / 2.0
	return n_edge.dot(dp / 2.0 - v) + dp_n


## Initialize distance factors and projected edge distances for 6-separating test.[br]
## [param dp]: Box size.[br]
func _init_separating_6(dp: Vector3) -> void:
	var dp_n: float = 0.0
	
	var an: Vector3 = n.abs()
	
	# Triangle normal is most dominant on x-axis
	if an.x > an.y and an.x > an.z:
		dp_n = dp.x * an.x
	# Triangle normal is most dominant on y-axis
	elif an.y > an.z and an.y > an.x:
		dp_n = dp.y * an.y
	# Triangle normal is most dominant on z-axis
	else:
		dp_n = dp.z * an.z
	
	# n.dot(1/2dp - v0)
	var ndpv: float = n.dot(dp / 2.0 - v0)
	d1 = ndpv + dp_n / 2.0
	d2 = ndpv - dp_n / 2.0
	
	var dp_xy: Vector2 = Vector2(dp.x, dp.y)
	var v0_xy: Vector2 = Vector2(v0.x, v0.y)
	var v1_xy: Vector2 = Vector2(v1.x, v1.y)
	var v2_xy: Vector2 = Vector2(v2.x, v2.y)
	d_xy_e0 = _calculate_separating_6_edge_distance(dp_xy, v0_xy, n_xy_e0)
	d_xy_e1 = _calculate_separating_6_edge_distance(dp_xy, v1_xy, n_xy_e1)
	d_xy_e2 = _calculate_separating_6_edge_distance(dp_xy, v2_xy, n_xy_e2)
	
	var dp_yz: Vector2 = Vector2(dp.y, dp.z)
	var v0_yz: Vector2 = Vector2(v0.y, v0.z)
	var v1_yz: Vector2 = Vector2(v1.y, v1.z)
	var v2_yz: Vector2 = Vector2(v2.y, v2.z)
	d_yz_e0 = _calculate_separating_6_edge_distance(dp_yz, v0_yz, n_yz_e0)
	d_yz_e1 = _calculate_separating_6_edge_distance(dp_yz, v1_yz, n_yz_e1)
	d_yz_e2 = _calculate_separating_6_edge_distance(dp_yz, v2_yz, n_yz_e2)
	
	var dp_zx: Vector2 = Vector2(dp.z, dp.x)
	var v0_zx: Vector2 = Vector2(v0.z, v0.x)
	var v1_zx: Vector2 = Vector2(v1.z, v1.x)
	var v2_zx: Vector2 = Vector2(v2.z, v2.x)
	d_zx_e0 = _calculate_separating_6_edge_distance(dp_zx, v0_zx, n_zx_e0)
	d_zx_e1 = _calculate_separating_6_edge_distance(dp_zx, v1_zx, n_zx_e1)
	d_zx_e2 = _calculate_separating_6_edge_distance(dp_zx, v2_zx, n_zx_e2)


## Initialize distance factors and projected edge distances for 26-separating test.[br]
## [param dp]: Box size.[br]
func _init_separating_26(dp: Vector3) -> void:
	# Critical point
	var c: Vector3 = Vector3(
		0.0 if n.x <= 0 else dp.x,
		0.0 if n.y <= 0 else dp.y,
		0.0 if n.z <= 0 else dp.z)
	
	# Critical point 1: c
	# d1 = n.dot(c-v0)
	d1 = n.dot(c - v0)
	
	# Critical point 2: dp - c
	# d2 = n.dot((dp-c)-v0)
	d2 = n.dot(dp - c - v0)
	
	#region Edges Distances' Projections

	d_xy_e0 = maxf(0, dp.x*n_xy_e0.x)\
			+ maxf(0, dp.y*n_xy_e0.y)\
			- n_xy_e0.dot(Vector2(v0.x, v0.y))
			
	d_xy_e1 = maxf(0, dp.x*n_xy_e1.x)\
			+ maxf(0, dp.y*n_xy_e1.y)\
			- n_xy_e1.dot(Vector2(v1.x, v1.y))
			
	d_xy_e2 = maxf(0, dp.x*n_xy_e2.x)\
			+ maxf(0, dp.y*n_xy_e2.y)\
			- n_xy_e2.dot(Vector2(v2.x, v2.y))
	
	d_yz_e0 = maxf(0, dp.y*n_yz_e0.x)\
			+ maxf(0, dp.z*n_yz_e0.y)\
			- n_yz_e0.dot(Vector2(v0.y, v0.z))
			
	d_yz_e1 = maxf(0, dp.y*n_yz_e1.x)\
			+ maxf(0, dp.z*n_yz_e1.y)\
			- n_yz_e1.dot(Vector2(v1.y, v1.z))
			
	d_yz_e2 = maxf(0, dp.y*n_yz_e2.x)\
			+ maxf(0, dp.z*n_yz_e2.y)\
			- n_yz_e2.dot(Vector2(v2.y, v2.z))
			
	d_zx_e0 = maxf(0, dp.z*n_zx_e0.x)\
			+ maxf(0, dp.x*n_zx_e0.y)\
			- n_zx_e0.dot(Vector2(v0.z, v0.x))
			
	d_zx_e1 = maxf(0, dp.z*n_zx_e1.x)\
			+ maxf(0, dp.x*n_zx_e1.y)\
			- n_zx_e1.dot(Vector2(v1.z, v1.x))
			
	d_zx_e2 = maxf(0, dp.z*n_zx_e2.x)\
			+ maxf(0, dp.x*n_zx_e2.y)\
			- n_zx_e2.dot(Vector2(v2.z, v2.x))
	#endregion


## Return true if triangle's plane
## overlaps voxel at [param minimum_corner] position.[br]
func plane_overlaps(minimum_corner: Vector3) -> bool:
	var np: float = n.dot(minimum_corner)
	return (np + d1) * (np + d2) <= epsilon
	

func _test_edge_projections_overlap(
	n_e0: Vector2, d_e0: float,
	n_e1: Vector2, d_e1: float,
	n_e2: Vector2, d_e2: float,
	projected_corner: Vector2
) -> bool:
	var e0_overlaps: bool = n_e0.dot(projected_corner) + d_e0 + epsilon >= 0
	var e1_overlaps: bool = n_e1.dot(projected_corner) + d_e1 + epsilon >= 0
	var e2_overlaps: bool = n_e2.dot(projected_corner) + d_e2 + epsilon >= 0
	return e0_overlaps and e1_overlaps and e2_overlaps


## Return true if projections on xy of triangle
## overlaps projections on xy of voxel at [param minimum_corner] position.[br]
func projection_xy_overlaps(minimum_corner: Vector3) -> bool:
	return _test_edge_projections_overlap(
		n_xy_e0, d_xy_e0,
		n_xy_e1, d_xy_e1,
		n_xy_e2, d_xy_e2,
		Vector2(minimum_corner.x, minimum_corner.y)
	)


## Return true if projections on yz of triangle
## overlaps projections on yz of voxel at [param minimum_corner] position.[br]
func projection_yz_overlaps(minimum_corner: Vector3) -> bool:
	return _test_edge_projections_overlap(
		n_yz_e0, d_yz_e0,
		n_yz_e1, d_yz_e1,
		n_yz_e2, d_yz_e2,
		Vector2(minimum_corner.y, minimum_corner.z)
	)


## Return true if projections on zx of triangle
## overlaps projections on zx of voxel at [param minimum_corner] position.[br]
func projection_zx_overlaps(minimum_corner: Vector3) -> bool:
	return _test_edge_projections_overlap(
		n_zx_e0, d_zx_e0,
		n_zx_e1, d_zx_e1,
		n_zx_e2, d_zx_e2,
		Vector2(minimum_corner.z, minimum_corner.x)
	)


func x_projection_on_plane(y: float, z: float) -> float:
	if is_zero_approx(n.x):
		return v0.x
	return (n_dot_v0 - n.y*y - n.z*z) / n.x

func y_projection_on_plane(x: float, z: float) -> float:
	if is_zero_approx(n.y):
		return v0.y
	return (n_dot_v0 - n.x*x - n.z*z) / n.y

func z_projection_on_plane(x: float, y: float) -> float:
	if is_zero_approx(n.z):
		return v0.z
	return (n_dot_v0 - n.x*x - n.y*y) / n.z
