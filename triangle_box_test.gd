class_name TriangleBoxTest

## Bounding box
var aabb: AABB

## Normal
var n: Vector3

func _init(v: PackedVector3Array, dp: float):
	## Bounding box
	aabb = AABB()
	aabb.position = v[0]
	aabb.expand(v[1])
	aabb.expand(v[2])
	
	## Normal
	n = (v[0]-v[1]).cross(v[0]-v[2])
	
	## Critical point
	var c = Vector3(
		0 if n.x < 0 else dp,
		0 if n.y < 0 else dp,
		0 if n.z < 0 else dp)
	
	## Distance factors
	var _d1 = n * (c - v[0])
	var _d2 = n * ((Vector3(dp, dp, dp) - c) - v[0])
	
	## Edge equations ##
	## ei = v[(i+1)%3] - v[i]
	var e: PackedVector3Array
	for i in range(0, 3):
		e[i] = v[(i+1)%3] - v[i]
	
	## Edges Normals/Distances' Projections
	for i in range(0, 3):
		_ne_xy[i] = Vector2(-e[i].y, e[i].x)
		_ne_yz[i] = Vector2(-e[i].z, e[i].y)
		_ne_xz[i] = Vector2(-e[i].z, e[i].x)
		
		_de_xy[i] = - _ne_xy[i].dot(Vector2(v[i].x, v[i].y))\
					+ maxf(0, dp*_ne_xy[i].x)\
					+ maxf(0, dp*_ne_xy[i].y)
					
		## WARNING: _ne_yz[i].x doesn't sound so right.
		## If something happens, test this
		_de_yz[i] = - _ne_yz[i].dot(Vector2(v[i].y, v[i].z))\
					+ maxf(0, dp*_ne_yz[i].x)\
					+ maxf(0, dp*_ne_yz[i].y)
					
		_de_xz[i] = - _ne_yz[i].dot(Vector2(v[i].x, v[i].z))\
					+ maxf(0, dp*_ne_xz[i].x)\
					+ maxf(0, dp*_ne_xz[i].y)


	
## @p: voxel position
## This test omits Triangle's bounding-box-overlaps-voxel test 
## Do that test to get potential overlapping voxels and then feed them here
## @return true if triangle overlaps
func overlap_voxel(p: Vector3) -> bool:
	return _plane_overlaps(p) and _projection_2d_overlaps(p)


func _plane_overlaps(p: Vector3) -> bool:
	return (n.dot(p) + _d1) * (n.dot(p) + _d2) <= 0


func _projection_2d_overlaps(p: Vector3) -> bool:
	var p_xy = Vector2(p.x, p.y)
	var p_yz = Vector2(p.y, p.z)
	var p_xz = Vector2(p.x, p.z)
	
	return  (_ne_xy[0].dot(p_xy) + _de_xy[0]) >= 0\
		and (_ne_xy[1].dot(p_xy) + _de_xy[1]) >= 0\
		and (_ne_xy[2].dot(p_xy) + _de_xy[2]) >= 0\
		
		and (_ne_yz[0].dot(p_yz) + _de_yz[0]) >= 0\
		and (_ne_yz[1].dot(p_yz) + _de_yz[1]) >= 0\
		and (_ne_yz[2].dot(p_yz) + _de_yz[2]) >= 0\
		
		and (_ne_xz[0].dot(p_xz) + _de_xz[0]) >= 0\
		and (_ne_xz[1].dot(p_xz) + _de_xz[1]) >= 0\
		and (_ne_xz[2].dot(p_xz) + _de_xz[2]) >= 0


## Distance Factor from each 
## critical point to triangle plane
var _d1: float
var _d2: float

### EDGE NORMALS' PROJECTIONS
## On xy
var _ne_xy: PackedVector2Array
## On yz
var _ne_yz: PackedVector2Array
## On xz
var _ne_xz: PackedVector2Array

### EDGE PROJECTED DISTANCES (??)
## On xy
var _de_xy: PackedFloat64Array
## On yz
var _de_yz: PackedFloat64Array
## On xz
var _de_xz: PackedFloat64Array
