## Fast triangle-box test as described by Michael Schwarz and Hans-Peter Seidel.
##
## Godot Vector uses float32. At 
extends TriangleBoxTest
class_name TriangleBoxTestF64

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
	separability: Separability,
	epsilon_value: float):
	epsilon = epsilon_value
		
	v0 = Dvector._new_v3(v0_f32)
	v1 = Dvector._new_v3(v1_f32)
	v2 = Dvector._new_v3(v2_f32)
	
	var dp: PackedFloat64Array = Dvector._new_v3(dp_f32)
	
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
	
	# Edges Normal Projections
	
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
	
	# Distance factors
	match separability:
		Separability.SEPARATING_6:
			var dp_n: float = 0
			
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
			temp_v3_0[0] = dp[0] / 2
			temp_v3_0[1] = dp[1] / 2
			temp_v3_0[2] = dp[2] / 2
			
			# TEMP = 1/2dp - v0
			Dvector.sub(temp_v3_0, temp_v3_0, v0)
			
			# n.dot(1/2dp - v0)
			var ndpv = Dvector.dot(n, temp_v3_0)
			d1 = ndpv + dp_n / 2
			d2 = ndpv - dp_n / 2
			
			#region Calculate Projections of Edges Distances
			
			#region xy e0
			# dp_*|ne0_|
			var dp_n_xy_e0: float = 0
			var abs_n_xy_e0_x = absf(n_xy_e0[0])
			var abs_n_xy_e0_y = absf(n_xy_e0[1])
			if abs_n_xy_e0_x > abs_n_xy_e0_y:
				dp_n_xy_e0 = dp[0] * abs_n_xy_e0_x / 2
			else:
				dp_n_xy_e0 = dp[1] * abs_n_xy_e0_y / 2
			temp_v2_0[0] = dp[0] / 2
			temp_v2_0[1] = dp[1] / 2
			temp_v2_1[0] = v0[0]
			temp_v2_1[1] = v0[1]
			# 1/2 dpxy - v_xy_0
			Dvector.sub(temp_v2_0, temp_v2_0, temp_v2_1)
			# n_xy_e0.dot(1/2 dpxy - v_xy_0)
			var dot_xy_e0 = Dvector.dot(n_xy_e0, temp_v2_0)
			d_xy_e0 = dot_xy_e0 + dp_n_xy_e0
			#endregion
			
			#region xy e1
			# dp_*|ne1_|
			var dp_n_xy_e1: float = 0
			var abs_n_xy_e1_x = absf(n_xy_e1[0])
			var abs_n_xy_e1_y = absf(n_xy_e1[1])
			if abs_n_xy_e1_x > abs_n_xy_e1_y:
				dp_n_xy_e1 = dp[0] * abs_n_xy_e1_x / 2
			else:
				dp_n_xy_e1 = dp[1] * abs_n_xy_e1_y / 2
			temp_v2_0[0] = dp[0] / 2
			temp_v2_0[1] = dp[1] / 2
			temp_v2_1[0] = v1[0]
			temp_v2_1[1] = v1[1]
			# 1/2 dpxy - v_xy_1
			Dvector.sub(temp_v2_0, temp_v2_0, temp_v2_1)
			# n_xy_e1.dot(1/2 dpxy - v_xy_1)
			var dot_xy_e1 = Dvector.dot(n_xy_e1, temp_v2_0)
			d_xy_e1 = dot_xy_e1 + dp_n_xy_e1
			#endregion

			#region xy e2
			# dp_*|ne2_|
			var dp_n_xy_e2: float = 0
			var abs_n_xy_e2_x = absf(n_xy_e2[0])
			var abs_n_xy_e2_y = absf(n_xy_e2[1])
			if abs_n_xy_e2_x > abs_n_xy_e2_y:
				dp_n_xy_e2 = dp[0] * abs_n_xy_e2_x / 2
			else:
				dp_n_xy_e2 = dp[1] * abs_n_xy_e2_y / 2
			temp_v2_0[0] = dp[0] / 2
			temp_v2_0[1] = dp[1] / 2
			temp_v2_1[0] = v2[0]
			temp_v2_1[1] = v2[1]
			# 1/2 dpxy - v_xy_2
			Dvector.sub(temp_v2_0, temp_v2_0, temp_v2_1)
			# n_xy_e2.dot(1/2 dpxy - v_xy_2)
			var dot_xy_e2 = Dvector.dot(n_xy_e2, temp_v2_0)
			d_xy_e2 = dot_xy_e2 + dp_n_xy_e2
			#endregion
			
			#region yz e0
			# dp_*|ne0_|
			var dp_n_yz_e0: float = 0
			var abs_n_yz_e0_y = absf(n_yz_e0[0])
			var abs_n_yz_e0_z = absf(n_yz_e0[1])
			if abs_n_yz_e0_y > abs_n_yz_e0_z:
				dp_n_yz_e0 = dp[1] * abs_n_yz_e0_y / 2
			else:
				dp_n_yz_e0 = dp[2] * abs_n_yz_e0_z / 2
			temp_v2_0[0] = dp[1] / 2
			temp_v2_0[1] = dp[2] / 2
			temp_v2_1[0] = v0[1]
			temp_v2_1[1] = v0[2]
			# 1/2 dpyz - v_yz_0
			Dvector.sub(temp_v2_0, temp_v2_0, temp_v2_1)
			# n_yz_e0.dot(1/2 dpyz - v_yz_0)
			var dot_yz_e0 = Dvector.dot(n_yz_e0, temp_v2_0)
			d_yz_e0 = dot_yz_e0 + dp_n_yz_e0
			#endregion
			
			#region yz e1
			# dp_*|ne1_|
			var dp_n_yz_e1: float = 0
			var abs_n_yz_e1_y = absf(n_yz_e1[0])
			var abs_n_yz_e1_z = absf(n_yz_e1[1])
			if abs_n_yz_e1_y > abs_n_yz_e1_z:
				dp_n_yz_e1 = dp[1] * abs_n_yz_e1_y / 2
			else:
				dp_n_yz_e1 = dp[2] * abs_n_yz_e1_z / 2
			temp_v2_0[0] = dp[1] / 2
			temp_v2_0[1] = dp[2] / 2
			temp_v2_1[0] = v1[1]
			temp_v2_1[1] = v1[2]
			# 1/2 dpyz - v_yz_1
			Dvector.sub(temp_v2_0, temp_v2_0, temp_v2_1)
			# n_yz_e1.dot(1/2 dpyz - v_yz_1)
			var dot_yz_e1 = Dvector.dot(n_yz_e1, temp_v2_0)
			d_yz_e1 = dot_yz_e1 + dp_n_yz_e1
			#endregion

			#region yz e2
			# dp_*|ne2_|
			var dp_n_yz_e2: float = 0
			var abs_n_yz_e2_y = absf(n_yz_e2[0])
			var abs_n_yz_e2_z = absf(n_yz_e2[1])
			if abs_n_yz_e2_y > abs_n_yz_e2_z:
				dp_n_yz_e2 = dp[1] * abs_n_yz_e2_y / 2
			else:
				dp_n_yz_e2 = dp[2] * abs_n_yz_e2_z / 2
			temp_v2_0[0] = dp[1] / 2
			temp_v2_0[1] = dp[2] / 2
			temp_v2_1[0] = v2[1]
			temp_v2_1[1] = v2[2]
			# 1/2 dpyz - v_yz_2
			Dvector.sub(temp_v2_0, temp_v2_0, temp_v2_1)
			# n_yz_e2.dot(1/2 dpyz - v_yz_2)
			var dot_yz_e2 = Dvector.dot(n_yz_e2, temp_v2_0)
			d_yz_e2 = dot_yz_e2 + dp_n_yz_e2
			#endregion
			
			#region zx e0
			# dp_*|ne0_|
			var dp_n_zx_e0: float = 0
			var abs_n_zx_e0_z = absf(n_zx_e0[0])
			var abs_n_zx_e0_x = absf(n_zx_e0[1])
			if abs_n_zx_e0_z > abs_n_zx_e0_x:
				dp_n_zx_e0 = dp[2] * abs_n_zx_e0_z / 2
			else:
				dp_n_zx_e0 = dp[0] * abs_n_zx_e0_x / 2
			temp_v2_0[0] = dp[2] / 2
			temp_v2_0[1] = dp[0] / 2
			temp_v2_1[0] = v0[2]
			temp_v2_1[1] = v0[0]
			# 1/2 dpzx - v_zx_0
			Dvector.sub(temp_v2_0, temp_v2_0, temp_v2_1)
			# n_zx_e0.dot(1/2 dpzx - v_zx_0)
			var dot_zx_e0 = Dvector.dot(n_zx_e0, temp_v2_0)
			d_zx_e0 = dot_zx_e0 + dp_n_zx_e0
			#endregion
			
			#region zx e1
			# dp_*|ne1_|
			var dp_n_zx_e1: float = 0
			var abs_n_zx_e1_z = absf(n_zx_e1[0])
			var abs_n_zx_e1_x = absf(n_zx_e1[1])
			if abs_n_zx_e1_z > abs_n_zx_e1_x:
				dp_n_zx_e1 = dp[2] * abs_n_zx_e1_z / 2
			else:
				dp_n_zx_e1 = dp[0] * abs_n_zx_e1_x / 2
			temp_v2_0[0] = dp[2] / 2
			temp_v2_0[1] = dp[0] / 2
			temp_v2_1[0] = v1[2]
			temp_v2_1[1] = v1[0]
			# 1/2 dpzx - v_zx_1
			Dvector.sub(temp_v2_0, temp_v2_0, temp_v2_1)
			# n_zx_e1.dot(1/2 dpzx - v_zx_1)
			var dot_zx_e1 = Dvector.dot(n_zx_e1, temp_v2_0)
			d_zx_e1 = dot_zx_e1 + dp_n_zx_e1
			#endregion

			#region zx e2
			# dp_*|ne2_|
			var dp_n_zx_e2: float = 0
			var abs_n_zx_e2_z = absf(n_zx_e2[0])
			var abs_n_zx_e2_x = absf(n_zx_e2[1])
			if abs_n_zx_e2_z > abs_n_zx_e2_x:
				dp_n_zx_e2 = dp[2] * abs_n_zx_e2_z / 2
			else:
				dp_n_zx_e2 = dp[0] * abs_n_zx_e2_x / 2
			temp_v2_0[0] = dp[2] / 2
			temp_v2_0[1] = dp[0] / 2
			temp_v2_1[0] = v2[2]
			temp_v2_1[1] = v2[0]
			# 1/2 dpzx - v_zx_2
			Dvector.sub(temp_v2_0, temp_v2_0, temp_v2_1)
			# n_zx_e2.dot(1/2 dpzx - v_zx_2)
			var dot_zx_e2 = Dvector.dot(n_zx_e2, temp_v2_0)
			d_zx_e2 = dot_zx_e2 + dp_n_zx_e2
			#endregion
			#endregion
	
		Separability.SEPARATING_26:
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
	
	pass # Debug breakpoint


## Return true if triangle's plane
## overlaps voxel at [param minimum_corner] position.[br]
func plane_overlaps(minimum_corner: Vector3) -> bool:
	Dvector.assign_v3(temp_v3_0, minimum_corner)
	var np: float = Dvector.dot(n, temp_v3_0)
	var np_d1: float = np + d1
	var np_d2: float = np + d2
	return np_d1 * np_d2 <= epsilon
	

## Return true if projections on xy of triangle
## overlaps projections on xy of voxel at [param minimum_corner] position.[br]
func projection_xy_overlaps(minimum_corner: Vector3) -> bool:
	temp_v2_0[0] = minimum_corner[0]
	temp_v2_0[1] = minimum_corner[1]
	
	return Dvector.dot(n_xy_e0, temp_v2_0) + d_xy_e0 + epsilon >= 0\
	and Dvector.dot(n_xy_e1, temp_v2_0) + d_xy_e1 + epsilon >= 0\
	and Dvector.dot(n_xy_e2, temp_v2_0) + d_xy_e2 + epsilon >= 0
	

## Return true if projections on yz of triangle
## overlaps projections on yz of voxel at [param minimum_corner] position.[br]
func projection_yz_overlaps(minimum_corner: Vector3) -> bool:
	temp_v2_0[0] = minimum_corner[1]
	temp_v2_0[1] = minimum_corner[2]
	
	#var prot0 = Dvector.dot(n_yz_e0, temp_v2_0) + d_yz_e0 + epsilon
	#var prot1 = Dvector.dot(n_yz_e1, temp_v2_0) + d_yz_e1 + epsilon
	#var prot2 = Dvector.dot(n_yz_e2, temp_v2_0) + d_yz_e2 + epsilon
	return Dvector.dot(n_yz_e0, temp_v2_0) + d_yz_e0 + epsilon >= 0\
	and Dvector.dot(n_yz_e1, temp_v2_0) + d_yz_e1 + epsilon >= 0\
	and Dvector.dot(n_yz_e2, temp_v2_0) + d_yz_e2 + epsilon >= 0


## Return true if projections on zx of triangle
## overlaps projections on zx of voxel at [param minimum_corner] position.[br]
func projection_zx_overlaps(minimum_corner: Vector3) -> bool:
	temp_v2_0[0] = minimum_corner[2]
	temp_v2_0[1] = minimum_corner[0]
	
	return Dvector.dot(n_zx_e0, temp_v2_0) + d_zx_e0 + epsilon >= 0\
	and Dvector.dot(n_zx_e1, temp_v2_0) + d_zx_e1 + epsilon >= 0\
	and Dvector.dot(n_zx_e2, temp_v2_0) + d_zx_e2 + epsilon >= 0


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
