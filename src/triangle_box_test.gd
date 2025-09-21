## Fast triangle-box test as described by Michael Schwarz and Hans-Peter Seidel.
## Used for surface voxelization.
extends RefCounted
class_name TriangleBoxTest

## Triangle bounding box
var aabb: AABB

## Triangle normal
var n: PackedFloat64Array = [0, 0, 0]

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

## Distance factor
var d1: float = 0
var d2: float = 0

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

## Vector to store temporary result
var temp_v2_0: PackedFloat64Array = [0, 0]
var temp_v2_1: PackedFloat64Array = [0, 0]
var temp_v2_2: PackedFloat64Array = [0, 0]
var temp_v3_0: PackedFloat64Array = [0, 0, 0]
var temp_v3_1: PackedFloat64Array = [0, 0, 0]


## Initialize a new triangle-box test.[br]
## [br]
## [param v]: Positions of 3 triangle vertices.[br]
## [param dp]: Box size.
func _init(
	v_f32: PackedVector3Array, 
	dp_f32: Vector3, 
	separability: Separability, 
	critical_point_max_x_face_shift: float = 0):
		
	# Bounding box
	aabb = AABB(v_f32[0], Vector3()).expand(v_f32[1]).expand(v_f32[2]).abs()
	
	var v0 = Dvector._new_v3(v_f32[0])
	var v1 = Dvector._new_v3(v_f32[1])
	var v2 = Dvector._new_v3(v_f32[2])
	
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
			# Critical point 2: dp - c
			Dvector.sub(temp_v3_1, dp, c)
			
			# Schwarz's modification for active level-1 nodes:
			# shifting all critical points that are on the voxel’s max x face
			# in +x direction by one subgrid voxel
			if c[0] > temp_v3_1[0]:
				c[0] += critical_point_max_x_face_shift
			else:
				temp_v3_1[0] += critical_point_max_x_face_shift
			
			# d1 = n.dot(c-v0)
			Dvector.sub(temp_v3_0, c, v0)
			d1 = Dvector.dot(n, temp_v3_0)
			
			# d2 = n.dot((dp-c)-v0)
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
			d_zx_e0 = maxf(0, dp[0]*n_zx_e0[0])\
					+ maxf(0, dp[2]*n_zx_e0[1])\
					- Dvector.dot(n_zx_e0, temp_v2_0)
					
			temp_v2_0[0] = v1[2]
			temp_v2_0[1] = v1[0]
			d_zx_e1 = maxf(0, dp[0]*n_zx_e1[0])\
					+ maxf(0, dp[2]*n_zx_e1[1])\
					- Dvector.dot(n_zx_e1, temp_v2_0)
					
			temp_v2_0[0] = v2[2]
			temp_v2_0[1] = v2[0]
			d_zx_e2 = maxf(0, dp[0]*n_zx_e2[0])\
					+ maxf(0, dp[2]*n_zx_e2[1])\
					- Dvector.dot(n_zx_e2, temp_v2_0)
			#endregion


## Return true if triangle overlaps voxel at position [param p].[br]
## [br]
## [b]Note:[/b] This test doesn't check whether triangle's bounding box overlaps voxel, 
## which is a prerequisite. Do that test first to get potential overlapping voxels
## and then feed them here.
func overlap_voxel(p: Vector3) -> bool:
	#var po = _plane_overlaps(p)
	#var p2o = _projection_2d_overlaps(p)
	#return po and p2o
	# Use this version for faster performance (short-circuit).
	return _plane_overlaps(p) and _projection_2d_overlaps(p)


## Return true if triangle's plane overlaps voxel at position [param p].[br]
func _plane_overlaps(p: Vector3) -> bool:
	Dvector.assign_v3(temp_v3_0, p)
	var np: float = Dvector.dot(n, temp_v3_0)
	var np_d1: float = np + d1
	var np_d2: float = np + d2
	return np_d1 * np_d2 <= 0

## Return true if triangle's projections on x, y, z overlaps those of voxel at position [param p].[br]
func _projection_2d_overlaps(p: Vector3) -> bool:
	temp_v2_0[0] = p[0]
	temp_v2_0[1] = p[1]
	
	temp_v2_1[0] = p[1]
	temp_v2_1[1] = p[2]
	
	temp_v2_2[0] = p[2]
	temp_v2_2[1] = p[0]
	
	return Dvector.dot(n_xy_e0, temp_v2_0) + d_xy_e0 >= 0\
	and Dvector.dot(n_xy_e1, temp_v2_0) + d_xy_e1 >= 0\
	and Dvector.dot(n_xy_e2, temp_v2_0) + d_xy_e2 >= 0\
	
	and Dvector.dot(n_yz_e0, temp_v2_1) + d_yz_e0 >= 0\
	and Dvector.dot(n_yz_e1, temp_v2_1) + d_yz_e1 >= 0\
	and Dvector.dot(n_yz_e2, temp_v2_1) + d_yz_e2 >= 0\
	
	and Dvector.dot(n_zx_e0, temp_v2_2) + d_zx_e0 >= 0\
	and Dvector.dot(n_zx_e1, temp_v2_2) + d_zx_e1 >= 0\
	and Dvector.dot(n_zx_e2, temp_v2_2) + d_zx_e2 >= 0


static func _automated_test():
	print("Test triangle on YZ")
	_auto_test_triangle_extended(
		[Vector3(1,0,0), Vector3(1,2,1), Vector3(1,0,2)], 
		range(0, 2), 
		[Vector3(0,0,0), Vector3(0,0,1), Vector3(0,1,0), Vector3(0,1,1),
		Vector3(1,0,0), Vector3(1,0,1), Vector3(1,1,0), Vector3(1,1,1)]
		)
	print()
	print("Test triangle on XZ")
	_auto_test_triangle_extended(
		[Vector3(0,1,0), Vector3(1,1,2), Vector3(2,1,0)], 
		range(0, 2), 
		[Vector3(0,0,0), Vector3(0,0,1), Vector3(0,1,0), Vector3(0,1,1),
		Vector3(1,0,0), Vector3(1,0,1), Vector3(1,1,0), Vector3(1,1,1)]
		)
	print()
	print("Test triangle on XY")
	_auto_test_triangle_extended(
		[Vector3(0,0,1), Vector3(1,2,1), Vector3(2,0,1)], 
		range(0, 2), 
		[Vector3(0,0,0), Vector3(0,0,1), Vector3(0,1,0), Vector3(0,1,1),
		Vector3(1,0,0), Vector3(1,0,1), Vector3(1,1,0), Vector3(1,1,1)]
		)
	print()
	
	var solid_voxels = []
	for y in range(0, 2):
		solid_voxels.append_array([
			Vector3(-1,y,-1),
			Vector3(-1,y,0),
			Vector3(-1,y,0),
			Vector3(-1,y,0),
			Vector3(0,y,-1),
			Vector3(0,y,0),
			Vector3(0,y,1),
			Vector3(0,y,2),
			Vector3(1,y,-1),
			Vector3(1,y,0),
			Vector3(1,y,1),
			Vector3(1,y,2),
			Vector3(2,y,-1),
			Vector3(2,y,0),
		])
	print()
	print("Test triangle in XZ with bigger bound")
	_auto_test_triangle_extended(
		[Vector3(0,1,0), Vector3(1,1,2), Vector3(2,1,0)], 
		range(-1, 3),
		solid_voxels
		)
	
	solid_voxels = []
	
	for z_idx in range(0, 2):
		var z = z_idx*0.5
		solid_voxels.append_array([
			Vector3(0, -1, z),
			Vector3(0, -0.5, z),
			Vector3(0, 0, z),
			Vector3(0, 0.5, z),
			
			Vector3(0.5, -1, z),
			Vector3(0.5, -0.5, z),
			Vector3(0.5, 0, z),
			Vector3(0.5, 0.5, z),
			
			Vector3(1, -0.5, z),
			Vector3(1, 0, z),
			Vector3(1, 0.5, z),
			
			Vector3(1.5, 0, z),
			Vector3(1.5, 0.5, z),
		])
	print()
	print("Isolated test from tree voxelization")
	_auto_test_triangle_extended(
		[Vector3(0.5, 0.5, 0.5), Vector3(1.5, 0.5, 0.5), Vector3(0.5, -0.5, 0.5)],
		range(-2,4),
		solid_voxels,
		Vector3(0.5, 0.5, 0.5))
	
	
static func _auto_test_triangle_extended(v: PackedVector3Array, box_range: PackedInt64Array, solid_voxels: PackedVector3Array, box_size:= Vector3(1,1,1)):
	var test = TriangleBoxTest.new(v, box_size, Separability.SEPARATING_26)
	var test_result = {}
	
	for x in box_range:
		for y in box_range:
			for z in box_range:
				test_result[Vector3(x, y, z) * box_size] = test.overlap_voxel(Vector3(x, y, z) * box_size)
				
	var expected_result = {}
	for key in test_result.keys():
		expected_result[key] = false
	
	for sol_vox in solid_voxels:
		expected_result[sol_vox] = true

	print("Triangle-Box Overlapping automated test")
	var errors = 0
	for key in test_result.keys():
		if test_result[key] != expected_result[key]:
			test.overlap_voxel(key)
			errors += 1
			printerr("Got %s, expected %s for %s" % [test_result[key], expected_result[key], key])
	print("Completed with %d error%s" % [errors, "" if errors < 2 else "s"])
	
