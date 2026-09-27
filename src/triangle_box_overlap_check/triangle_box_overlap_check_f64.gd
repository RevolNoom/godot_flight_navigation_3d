## Fast triangle-box test as described by Michael Schwarz and Hans-Peter Seidel.
##
## Godot Vector uses float32. At 
extends ATriangleBoxOverlapCheck
class_name TriangleBoxOverlapCheckF64

var epsilon: float

var v0: PackedFloat64Array = [0, 0, 0]
var v1: PackedFloat64Array = [0, 0, 0]
var v2: PackedFloat64Array = [0, 0, 0]

## Triangle normal
var n: PackedFloat64Array = [0, 0, 0]

## If the plane equation is ax + by + cz = d
## then n.dot(v0) = d.
## Useful for calculation of projection of one Vector3 on the plane.
var n_dot_v0: float = 0

## Edges normal projections on xy.
var n_xy_e0: PackedFloat64Array = [0, 0]
var n_xy_e1: PackedFloat64Array = [0, 0]
var n_xy_e2: PackedFloat64Array = [0, 0]

## Edges normal projections on yz.
var n_yz_e0: PackedFloat64Array = [0, 0]
var n_yz_e1: PackedFloat64Array = [0, 0]
var n_yz_e2: PackedFloat64Array = [0, 0]

## Edges normal projections on zx.
var n_zx_e0: PackedFloat64Array = [0, 0]
var n_zx_e1: PackedFloat64Array = [0, 0]
var n_zx_e2: PackedFloat64Array = [0, 0]

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

## Vector to store temporary result
var temp_v2_0: PackedFloat64Array = [0, 0]
var temp_v2_1: PackedFloat64Array = [0, 0]
var temp_v3_0: PackedFloat64Array = [0, 0, 0]
var temp_v3_1: PackedFloat64Array = [0, 0, 0]


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
		
	v0 = Dvector.create_v3(v0_f32)
	v1 = Dvector.create_v3(v1_f32)
	v2 = Dvector.create_v3(v2_f32)
	
	var dp: PackedFloat64Array = Dvector.create_v3(dp_f32)
	
	# Edge equations
	var e0: PackedFloat64Array = [0, 0, 0]
	var e1: PackedFloat64Array = [0, 0, 0]
	var e2: PackedFloat64Array = [0, 0, 0]
	
	Dvector.sub(e0, v1, v0)
	Dvector.sub(e1, v2, v1)
	Dvector.sub(e2, v0, v2)
	
	# Triangle normal
	# NOTE: This order of vector is important. Copied from cuda_voxelizer
	Dvector.cross(n, e0, e1)

	n_dot_v0 = Dvector.dot(n, v0)
	
	# Normalization creates too much inaccuracy, and thus omitted
	#Dvector.normalize(n, n)
	
	_init_normal_projections(e0, e1, e2)
	
	# Distance factors
	match separability:
		Separability.Enum.SEPARATING_6:
			_init_separating_6(dp)
		Separability.Enum.SEPARATING_26:
			_init_separating_26(dp)
	
	# Initialization complete.


## Calculate normal projections of triangle edges on coordinate planes.[br]
## [param e0]: Edge vector from v0 to v1.[br]
## [param e1]: Edge vector from v1 to v2.[br]
## [param e2]: Edge vector from v2 to v0.[br]
func _init_normal_projections(
	e0: PackedFloat64Array, 
	e1: PackedFloat64Array, 
	e2: PackedFloat64Array
) -> void:
	# n.z >= 0
	if n[2] >= 0:
		n_xy_e0[0] = -e0[1]
		n_xy_e0[1] =  e0[0]
		n_xy_e1[0] = -e1[1]
		n_xy_e1[1] =  e1[0]
		n_xy_e2[0] = -e2[1]
		n_xy_e2[1] =  e2[0]
	else:
		n_xy_e0[0] =  e0[1]
		n_xy_e0[1] = -e0[0]
		n_xy_e1[0] =  e1[1]
		n_xy_e1[1] = -e1[0]
		n_xy_e2[0] =  e2[1]
		n_xy_e2[1] = -e2[0]
	
	# n.x >= 0
	if n[0] >= 0:
		n_yz_e0[0] = -e0[2]
		n_yz_e0[1] =  e0[1]
		n_yz_e1[0] = -e1[2]
		n_yz_e1[1] =  e1[1]
		n_yz_e2[0] = -e2[2]
		n_yz_e2[1] =  e2[1]
	else:
		n_yz_e0[0] =  e0[2]
		n_yz_e0[1] = -e0[1]
		n_yz_e1[0] =  e1[2]
		n_yz_e1[1] = -e1[1]
		n_yz_e2[0] =  e2[2]
		n_yz_e2[1] = -e2[1]
	
	# n.y >= 0
	if n[1] >= 0:
		n_zx_e0[0] = -e0[0]
		n_zx_e0[1] =  e0[2]
		n_zx_e1[0] = -e1[0]
		n_zx_e1[1] =  e1[2]
		n_zx_e2[0] = -e2[0]
		n_zx_e2[1] =  e2[2]
	else:
		n_zx_e0[0] =  e0[0]
		n_zx_e0[1] = -e0[2]
		n_zx_e1[0] =  e1[0]
		n_zx_e1[1] = -e1[2]
		n_zx_e2[0] =  e2[0]
		n_zx_e2[1] = -e2[2]


## Calculate separating edge distance projection on a 2D plane.[br]
## [param dp]: Box size projected on the 2D plane.[br]
## [param v]: Triangle vertex projected on the 2D plane.[br]
## [param n_edge]: Edge normal projection on the 2D plane.[br]
## Return: projected edge distance factor.[br]
func _calculate_separating_6_edge_distance(
	dp: PackedFloat64Array,
	v: PackedFloat64Array,
	n_edge: PackedFloat64Array
) -> float:
	var dp_n: float = 0.0
	var abs_n_x: float = absf(n_edge[0])
	var abs_n_y: float = absf(n_edge[1])
	if abs_n_x > abs_n_y:
		dp_n = dp[0] * abs_n_x / 2.0
	else:
		dp_n = dp[1] * abs_n_y / 2.0
	temp_v2_0[0] = dp[0] / 2.0
	temp_v2_0[1] = dp[1] / 2.0
	temp_v2_1[0] = v[0]
	temp_v2_1[1] = v[1]
	Dvector.sub(temp_v2_0, temp_v2_0, temp_v2_1)
	var dot: float = Dvector.dot(n_edge, temp_v2_0)
	return dot + dp_n


## Initialize distance factors and projected edge distances for 6-separating test.[br]
## [param dp]: Box size.[br]
func _init_separating_6(dp: PackedFloat64Array) -> void:
	var dp_n: float = 0.0
	
	var an: PackedFloat64Array = [absf(n[0]), absf(n[1]), absf(n[2])]
	
	# Triangle normal is most dominant on x-axis
	if an[0] > an[1] and an[0] > an[2]:
		dp_n = dp[0] * an[0]
	# Triangle normal is most dominant on y-axis
	elif an[1] > an[2] and an[1] > an[0]:
		dp_n = dp[1] * an[1]
	# Triangle normal is most dominant on z-axis
	else:
		dp_n = dp[2] * an[2]
	
	# TEMP = 1/2dp
	temp_v3_0[0] = dp[0] / 2.0
	temp_v3_0[1] = dp[1] / 2.0
	temp_v3_0[2] = dp[2] / 2.0
	
	# TEMP = 1/2dp - v0
	Dvector.sub(temp_v3_0, temp_v3_0, v0)
	
	# n.dot(1/2dp - v0)
	var ndpv: float = Dvector.dot(n, temp_v3_0)
	d1 = ndpv + dp_n / 2.0
	d2 = ndpv - dp_n / 2.0
	
	var dp_xy: PackedFloat64Array = [dp[0], dp[1]]
	var v0_xy: PackedFloat64Array = [v0[0], v0[1]]
	var v1_xy: PackedFloat64Array = [v1[0], v1[1]]
	var v2_xy: PackedFloat64Array = [v2[0], v2[1]]
	d_xy_e0 = _calculate_separating_6_edge_distance(dp_xy, v0_xy, n_xy_e0)
	d_xy_e1 = _calculate_separating_6_edge_distance(dp_xy, v1_xy, n_xy_e1)
	d_xy_e2 = _calculate_separating_6_edge_distance(dp_xy, v2_xy, n_xy_e2)
	
	var dp_yz: PackedFloat64Array = [dp[1], dp[2]]
	var v0_yz: PackedFloat64Array = [v0[1], v0[2]]
	var v1_yz: PackedFloat64Array = [v1[1], v1[2]]
	var v2_yz: PackedFloat64Array = [v2[1], v2[2]]
	d_yz_e0 = _calculate_separating_6_edge_distance(dp_yz, v0_yz, n_yz_e0)
	d_yz_e1 = _calculate_separating_6_edge_distance(dp_yz, v1_yz, n_yz_e1)
	d_yz_e2 = _calculate_separating_6_edge_distance(dp_yz, v2_yz, n_yz_e2)
	
	var dp_zx: PackedFloat64Array = [dp[2], dp[0]]
	var v0_zx: PackedFloat64Array = [v0[2], v0[0]]
	var v1_zx: PackedFloat64Array = [v1[2], v1[0]]
	var v2_zx: PackedFloat64Array = [v2[2], v2[0]]
	d_zx_e0 = _calculate_separating_6_edge_distance(dp_zx, v0_zx, n_zx_e0)
	d_zx_e1 = _calculate_separating_6_edge_distance(dp_zx, v1_zx, n_zx_e1)
	d_zx_e2 = _calculate_separating_6_edge_distance(dp_zx, v2_zx, n_zx_e2)


## Initialize distance factors and projected edge distances for 26-separating test.[br]
## [param dp]: Box size.[br]
func _init_separating_26(dp: PackedFloat64Array) -> void:
	# Critical point
	var c: PackedFloat64Array = [
		0.0 if n[0] <= 0 else dp[0],
		0.0 if n[1] <= 0 else dp[1],
		0.0 if n[2] <= 0 else dp[2]]
	
	# Critical point 1: c
	# d1 = n.dot(c-v0)
	Dvector.sub(temp_v3_0, c, v0)
	d1 = Dvector.dot(n, temp_v3_0)
	
	# Critical point 2: dp - c
	# d2 = n.dot((dp-c)-v0)
	Dvector.sub(temp_v3_1, dp, c)
	Dvector.sub(temp_v3_1, temp_v3_1, v0)
	d2 = Dvector.dot(n, temp_v3_1)
	
	#region Edges Distances' Projections

	# temp_v2_0 = v0_xy
	temp_v2_0[0] = v0[0]
	temp_v2_0[1] = v0[1]
	d_xy_e0 = maxf(0, dp[0]*n_xy_e0[0])\
			+ maxf(0, dp[1]*n_xy_e0[1])\
			- Dvector.dot(n_xy_e0, temp_v2_0)
			
	temp_v2_0[0] = v1[0]
	temp_v2_0[1] = v1[1]
	d_xy_e1 = maxf(0, dp[0]*n_xy_e1[0])\
			+ maxf(0, dp[1]*n_xy_e1[1])\
			- Dvector.dot(n_xy_e1, temp_v2_0)
			
	temp_v2_0[0] = v2[0]
	temp_v2_0[1] = v2[1]
	d_xy_e2 = maxf(0, dp[0]*n_xy_e2[0])\
			+ maxf(0, dp[1]*n_xy_e2[1])\
			- Dvector.dot(n_xy_e2, temp_v2_0)
	
	# temp_v2_0 = v0_yz
	temp_v2_0[0] = v0[1]
	temp_v2_0[1] = v0[2]
	d_yz_e0 = maxf(0, dp[1]*n_yz_e0[0])\
			+ maxf(0, dp[2]*n_yz_e0[1])\
			- Dvector.dot(n_yz_e0, temp_v2_0)
			
	temp_v2_0[0] = v1[1]
	temp_v2_0[1] = v1[2]
	d_yz_e1 = maxf(0, dp[1]*n_yz_e1[0])\
			+ maxf(0, dp[2]*n_yz_e1[1])\
			- Dvector.dot(n_yz_e1, temp_v2_0)
			
	temp_v2_0[0] = v2[1]
	temp_v2_0[1] = v2[2]
	d_yz_e2 = maxf(0, dp[1]*n_yz_e2[0])\
			+ maxf(0, dp[2]*n_yz_e2[1])\
			- Dvector.dot(n_yz_e2, temp_v2_0)
			
	# temp_v2_0 = v0_zx
	temp_v2_0[0] = v0[2]
	temp_v2_0[1] = v0[0]
	d_zx_e0 = maxf(0, dp[2]*n_zx_e0[0])\
			+ maxf(0, dp[0]*n_zx_e0[1])\
			- Dvector.dot(n_zx_e0, temp_v2_0)
			
	temp_v2_0[0] = v1[2]
	temp_v2_0[1] = v1[0]
	d_zx_e1 = maxf(0, dp[2]*n_zx_e1[0])\
			+ maxf(0, dp[0]*n_zx_e1[1])\
			- Dvector.dot(n_zx_e1, temp_v2_0)
			
	temp_v2_0[0] = v2[2]
	temp_v2_0[1] = v2[0]
	d_zx_e2 = maxf(0, dp[2]*n_zx_e2[0])\
			+ maxf(0, dp[0]*n_zx_e2[1])\
			- Dvector.dot(n_zx_e2, temp_v2_0)
	#endregion


## Return true if triangle's plane
## overlaps voxel at [param minimum_corner] position.[br]
func plane_overlaps(minimum_corner: Vector3) -> bool:
	Dvector.assign_v3(temp_v3_0, minimum_corner)
	var np: float = Dvector.dot(n, temp_v3_0)
	return (np + d1) * (np + d2) <= epsilon
	

func _test_edge_projections_overlap(
	n_e0: PackedFloat64Array, d_e0: float,
	n_e1: PackedFloat64Array, d_e1: float,
	n_e2: PackedFloat64Array, d_e2: float,
	coord0: float, coord1: float
) -> bool:
	temp_v2_0[0] = coord0
	temp_v2_0[1] = coord1
	var e0_overlaps: bool = Dvector.dot(n_e0, temp_v2_0) + d_e0 + epsilon >= 0
	var e1_overlaps: bool = Dvector.dot(n_e1, temp_v2_0) + d_e1 + epsilon >= 0
	var e2_overlaps: bool = Dvector.dot(n_e2, temp_v2_0) + d_e2 + epsilon >= 0
	return e0_overlaps and e1_overlaps and e2_overlaps


## Return true if projections on xy of triangle
## overlaps projections on xy of voxel at [param minimum_corner] position.[br]
func projection_xy_overlaps(minimum_corner: Vector3) -> bool:
	return _test_edge_projections_overlap(
		n_xy_e0, d_xy_e0,
		n_xy_e1, d_xy_e1,
		n_xy_e2, d_xy_e2,
		minimum_corner[0], minimum_corner[1]
	)


## Return true if projections on yz of triangle
## overlaps projections on yz of voxel at [param minimum_corner] position.[br]
func projection_yz_overlaps(minimum_corner: Vector3) -> bool:
	return _test_edge_projections_overlap(
		n_yz_e0, d_yz_e0,
		n_yz_e1, d_yz_e1,
		n_yz_e2, d_yz_e2,
		minimum_corner[1], minimum_corner[2]
	)


## Return true if projections on zx of triangle
## overlaps projections on zx of voxel at [param minimum_corner] position.[br]
func projection_zx_overlaps(minimum_corner: Vector3) -> bool:
	return _test_edge_projections_overlap(
		n_zx_e0, d_zx_e0,
		n_zx_e1, d_zx_e1,
		n_zx_e2, d_zx_e2,
		minimum_corner[2], minimum_corner[0]
	)


func x_projection_on_plane(y: float, z: float) -> float:
	if is_zero_approx(n[0]):
		return v0[0]
	return (n_dot_v0 - n[1]*y - n[2]*z) / n[0]

func y_projection_on_plane(x: float, z: float) -> float:
	if is_zero_approx(n[1]):
		return v0[1]
	return (n_dot_v0 - n[0]*x - n[2]*z) / n[1]

func z_projection_on_plane(x: float, y: float) -> float:
	if is_zero_approx(n[2]):
		return v0[2]
	return (n_dot_v0 - n[0]*x - n[1]*y) / n[2]
