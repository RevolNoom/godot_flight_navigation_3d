## Fast triangle-box test as described by Michael Schwarz and Hans-Peter Seidel.
##
## This triangle-box test uses float32. 
## Since Vector in Godot also uses float32, it helps the test runs faster 
## and consumes less memory
extends TriangleBoxTest
class_name TriangleBoxTestF32

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
	separability: TriangleBoxTest.Separability,
	epsilon_value: float):
	epsilon = epsilon_value
		
	v0 = v0_f32
	v1 = v1_f32
	v2 = v2_f32
	
	var dp: Vector3 = dp_f32
	
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
	
	# Edges Normal Projections
	
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
	
	# Distance factors
	match separability:
		TriangleBoxTest.Separability.SEPARATING_6:
			var dp_n: float = 0
			
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
			var ndpv = n.dot(dp / 2 - v0)
			d1 = ndpv + dp_n / 2
			d2 = ndpv - dp_n / 2
			
			#region Calculate Projections of Edges Distances
			
			#region xy e0
			# dp_*|ne0_|
			var dp_n_xy_e0: float = 0
			var abs_n_xy_e0_x = absf(n_xy_e0.x)
			var abs_n_xy_e0_y = absf(n_xy_e0.y)
			if abs_n_xy_e0_x > abs_n_xy_e0_y:
				dp_n_xy_e0 = dp.x * abs_n_xy_e0_x / 2
			else:
				dp_n_xy_e0 = dp.y * abs_n_xy_e0_y / 2
			# n_xy_e0.dot(1/2 dpxy - v_xy_0)
			var dot_xy_e0 = n_xy_e0.dot(Vector2(dp.x, dp.y) / 2 - Vector2(v0.x, v0.y))
			d_xy_e0 = dot_xy_e0 + dp_n_xy_e0
			#endregion
			
			#region xy e1
			# dp_*|ne1_|
			var dp_n_xy_e1: float = 0
			var abs_n_xy_e1_x = absf(n_xy_e1.x)
			var abs_n_xy_e1_y = absf(n_xy_e1.y)
			if abs_n_xy_e1_x > abs_n_xy_e1_y:
				dp_n_xy_e1 = dp.x * abs_n_xy_e1_x / 2
			else:
				dp_n_xy_e1 = dp.y * abs_n_xy_e1_y / 2
			# n_xy_e1.dot(1/2 dpxy - v_xy_1)
			var dot_xy_e1 = n_xy_e1.dot(Vector2(dp.x, dp.y) / 2 - Vector2(v1.x, v1.y))
			d_xy_e1 = dot_xy_e1 + dp_n_xy_e1
			#endregion

			#region xy e2
			# dp_*|ne2_|
			var dp_n_xy_e2: float = 0
			var abs_n_xy_e2_x = absf(n_xy_e2.x)
			var abs_n_xy_e2_y = absf(n_xy_e2.y)
			if abs_n_xy_e2_x > abs_n_xy_e2_y:
				dp_n_xy_e2 = dp.x * abs_n_xy_e2_x / 2
			else:
				dp_n_xy_e2 = dp.y * abs_n_xy_e2_y / 2
			# n_xy_e2.dot(1/2 dpxy - v_xy_2)
			var dot_xy_e2 = n_xy_e2.dot(Vector2(dp.x, dp.y) / 2 - Vector2(v2.x, v2.y))
			d_xy_e2 = dot_xy_e2 + dp_n_xy_e2
			#endregion
			
			#region yz e0
			# dp_*|ne0_|
			var dp_n_yz_e0: float = 0
			var abs_n_yz_e0_y = absf(n_yz_e0.x)
			var abs_n_yz_e0_z = absf(n_yz_e0.y)
			if abs_n_yz_e0_y > abs_n_yz_e0_z:
				dp_n_yz_e0 = dp.y * abs_n_yz_e0_y / 2
			else:
				dp_n_yz_e0 = dp.z * abs_n_yz_e0_z / 2
			# n_yz_e0.dot(1/2 dpyz - v_yz_0)
			var dot_yz_e0 = n_yz_e0.dot(Vector2(dp.y, dp.z) / 2 - Vector2(v0.y, v0.z))
			d_yz_e0 = dot_yz_e0 + dp_n_yz_e0
			#endregion
			
			#region yz e1
			# dp_*|ne1_|
			var dp_n_yz_e1: float = 0
			var abs_n_yz_e1_y = absf(n_yz_e1.x)
			var abs_n_yz_e1_z = absf(n_yz_e1.y)
			if abs_n_yz_e1_y > abs_n_yz_e1_z:
				dp_n_yz_e1 = dp.y * abs_n_yz_e1_y / 2
			else:
				dp_n_yz_e1 = dp.z * abs_n_yz_e1_z / 2
			# n_yz_e1.dot(1/2 dpyz - v_yz_1)
			var dot_yz_e1 = n_yz_e1.dot(Vector2(dp.y, dp.z) / 2 - Vector2(v1.y, v1.z))
			d_yz_e1 = dot_yz_e1 + dp_n_yz_e1
			#endregion

			#region yz e2
			# dp_*|ne2_|
			var dp_n_yz_e2: float = 0
			var abs_n_yz_e2_y = absf(n_yz_e2.x)
			var abs_n_yz_e2_z = absf(n_yz_e2.y)
			if abs_n_yz_e2_y > abs_n_yz_e2_z:
				dp_n_yz_e2 = dp.y * abs_n_yz_e2_y / 2
			else:
				dp_n_yz_e2 = dp.z * abs_n_yz_e2_z / 2
			# n_yz_e2.dot(1/2 dpyz - v_yz_2)
			var dot_yz_e2 = n_yz_e2.dot(Vector2(dp.y, dp.z) / 2 - Vector2(v2.y, v2.z))
			d_yz_e2 = dot_yz_e2 + dp_n_yz_e2
			#endregion
			
			#region zx e0
			# dp_*|ne0_|
			var dp_n_zx_e0: float = 0
			var abs_n_zx_e0_z = absf(n_zx_e0.x)
			var abs_n_zx_e0_x = absf(n_zx_e0.y)
			if abs_n_zx_e0_z > abs_n_zx_e0_x:
				dp_n_zx_e0 = dp.z * abs_n_zx_e0_z / 2
			else:
				dp_n_zx_e0 = dp.x * abs_n_zx_e0_x / 2
			# n_zx_e0.dot(1/2 dpzx - v_zx_0)
			var dot_zx_e0 = n_zx_e0.dot(Vector2(dp.z, dp.x) / 2 - Vector2(v0.z, v0.x))
			d_zx_e0 = dot_zx_e0 + dp_n_zx_e0
			#endregion
			
			#region zx e1
			# dp_*|ne1_|
			var dp_n_zx_e1: float = 0
			var abs_n_zx_e1_z = absf(n_zx_e1.x)
			var abs_n_zx_e1_x = absf(n_zx_e1.y)
			if abs_n_zx_e1_z > abs_n_zx_e1_x:
				dp_n_zx_e1 = dp.z * abs_n_zx_e1_z / 2
			else:
				dp_n_zx_e1 = dp.x * abs_n_zx_e1_x / 2
			# n_zx_e1.dot(1/2 dpzx - v_zx_1)
			var dot_zx_e1 = n_zx_e1.dot(Vector2(dp.z, dp.x) / 2 - Vector2(v1.z, v1.x))
			d_zx_e1 = dot_zx_e1 + dp_n_zx_e1
			#endregion

			#region zx e2
			# dp_*|ne2_|
			var dp_n_zx_e2: float = 0
			var abs_n_zx_e2_z = absf(n_zx_e2.x)
			var abs_n_zx_e2_x = absf(n_zx_e2.y)
			if abs_n_zx_e2_z > abs_n_zx_e2_x:
				dp_n_zx_e2 = dp.z * abs_n_zx_e2_z / 2
			else:
				dp_n_zx_e2 = dp.x * abs_n_zx_e2_x / 2
			# n_zx_e2.dot(1/2 dpzx - v_zx_2)
			var dot_zx_e2 = n_zx_e2.dot(Vector2(dp.z, dp.x) / 2 - Vector2(v2.z, v2.x))
			d_zx_e2 = dot_zx_e2 + dp_n_zx_e2
			#endregion
			#endregion
	
		TriangleBoxTest.Separability.SEPARATING_26:
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
	
	pass # Debug breakpoint


## Return true if triangle's plane
## overlaps voxel at [param minimum_corner] position.[br]
func plane_overlaps(minimum_corner: Vector3) -> bool:
	var np: float = n.dot(minimum_corner)
	var np_d1: float = np + d1
	var np_d2: float = np + d2
	return np_d1 * np_d2 <= epsilon
	

## Return true if projections on xy of triangle
## overlaps projections on xy of voxel at [param minimum_corner] position.[br]
func projection_xy_overlaps(minimum_corner: Vector3) -> bool:
	var minimum_corner_xy = Vector2(minimum_corner.x, minimum_corner.y)
	
	return n_xy_e0.dot(minimum_corner_xy) + d_xy_e0 + epsilon >= 0\
	and n_xy_e1.dot(minimum_corner_xy) + d_xy_e1 + epsilon >= 0\
	and n_xy_e2.dot(minimum_corner_xy) + d_xy_e2 + epsilon >= 0
	

## Return true if projections on yz of triangle
## overlaps projections on yz of voxel at [param minimum_corner] position.[br]
func projection_yz_overlaps(minimum_corner: Vector3) -> bool:
	var minimum_corner_yz = Vector2(minimum_corner.y, minimum_corner.z)
	
	#var prot0 = n_yz_e0.dot(minimum_corner_yz) + d_yz_e0 + epsilon
	#var prot1 = n_yz_e1.dot(minimum_corner_yz) + d_yz_e1 + epsilon
	#var prot2 = n_yz_e2.dot(minimum_corner_yz) + d_yz_e2 + epsilon
	return n_yz_e0.dot(minimum_corner_yz) + d_yz_e0 + epsilon >= 0\
	and n_yz_e1.dot(minimum_corner_yz) + d_yz_e1 + epsilon >= 0\
	and n_yz_e2.dot(minimum_corner_yz) + d_yz_e2 + epsilon >= 0


## Return true if projections on zx of triangle
## overlaps projections on zx of voxel at [param minimum_corner] position.[br]
func projection_zx_overlaps(minimum_corner: Vector3) -> bool:
	var minimum_corner_zx = Vector2(minimum_corner.z, minimum_corner.x)
	
	return n_zx_e0.dot(minimum_corner_zx) + d_zx_e0 + epsilon >= 0\
	and n_zx_e1.dot(minimum_corner_zx) + d_zx_e1 + epsilon >= 0\
	and n_zx_e2.dot(minimum_corner_zx) + d_zx_e2 + epsilon >= 0


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
