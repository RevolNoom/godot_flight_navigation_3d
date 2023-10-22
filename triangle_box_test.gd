class_name TriangleBoxTest

## https://github.com/Forceflow/cuda_voxelizer/blob/main/src/cpu_voxelizer.cpp

## Bounding box
var aabb: AABB

## Normal
var n: Vector3

func _init(v: PackedVector3Array, dp: Vector3):
	## Bounding box
	aabb = AABB()
	aabb.position = v[0]
	aabb = aabb.expand(v[1])
	aabb = aabb.expand(v[2])
	#print("AABB: " + str(aabb))
	
	#print("v: %s" % v)
	## Normal
	## NOTE: This order of vector is important. Copied from cuda_voxelizer
	n = (v[1]-v[0]).cross(v[2]-v[1]).normalized()
	#print("n: " + str(n))
	
	## Critical point
	var c = Vector3(
		0.0 if n.x <= 0 else dp.x,
		0.0 if n.y <= 0 else dp.y,
		0.0 if n.z <= 0 else dp.z)
	#print("c: " + str(c))
	
	## Distance factors
	_d1 = n.dot(c - v[0])
	_d2 = n.dot((dp - c) - v[0])
	
	#print("_d1: %f\n_d2: %f" % [_d1, _d2])
	
	## Edge equations ##
	## ei = v[(i+1)%3] - v[i]
	var e: PackedVector3Array = [null, null, null]
	for i in range(0, 3):
		e[i] = v[(i+1)%3] - v[i]
	#print("edges: %s" % str(e))
	
	## Edges Normals/Distances' Projections
	for i in range(0, 3):
		_ne_xy[i] = Vector2(-e[i].y, e[i].x) * (1.0 if n.z >= 0.0 else -1.0)
		_ne_yz[i] = Vector2(-e[i].z, e[i].y) * (1.0 if n.x >= 0.0 else -1.0)
		
		## Don't even think about exchanging the signs!
		_ne_zx[i] = Vector2(-e[i].x, e[i].z) * (1.0 if n.y >= 0.0 else -1.0)
		
		_de_xy[i] = - _ne_xy[i].dot(Vector2(v[i].x, v[i].y))\
					+ maxf(0, dp.x*_ne_xy[i].x)\
					+ maxf(0, dp.y*_ne_xy[i].y)
		
		_de_yz[i] = - _ne_yz[i].dot(Vector2(v[i].y, v[i].z))\
					+ maxf(0, dp.y*_ne_yz[i].x)\
					+ maxf(0, dp.z*_ne_yz[i].y)
		
		_de_xz[i] = - _ne_zx[i].dot(Vector2(v[i].z, v[i].x))\
					+ maxf(0.0, dp.x*_ne_zx[i].x)\
					+ maxf(0.0, dp.z*_ne_zx[i].y)
					
	#	print("_de_xz[%d] = %f + %f + %f" % [i, - _ne_zx[i].dot(Vector2(v[i].z, v[i].x)), maxf(0, dp.x*_ne_zx[i].x), maxf(0, dp.z*_ne_zx[i].y)])

	#print("_ne_xy: %s" % str(_ne_xy))
	#print("_ne_yz: %s" % str(_ne_yz))
	#print("_ne_zx: %s" % str(_ne_zx))
	
	#print("_de_xy: %s" % str(_de_xy))
	#print("_de_yz: %s" % str(_de_yz))
	#print("_de_xz: %s" % str(_de_xz))
	
## @p: voxel position
## This test omits Triangle's bounding-box-overlaps-voxel test 
## Do that test to get potential overlapping voxels and then feed them here
## @return true if triangle overlaps
func overlap_voxel(p: Vector3) -> bool:
	#print()
	var po = _plane_overlaps(p)
	var p2o = _projection_2d_overlaps(p)
	#print("Test overlap %s:\nPlane Overlap: %s\nProjection Overlaps: %s" % [p, po, p2o])
	return po and p2o
	#return _plane_overlaps(p) and _projection_2d_overlaps(p)


func _plane_overlaps(p: Vector3) -> bool:
	var np = n.dot(p) 
	return (np + _d1) * (np + _d2) <= 0


func _projection_2d_overlaps(p: Vector3) -> bool:
	var p_xy = Vector2(p.x, p.y)
	var p_yz = Vector2(p.y, p.z)
	var p_xz = Vector2(p.x, p.z)
	#print("p: %v" % p)
	#print("p_xz: %v" % p_xz)
	
	#print( (_ne_xy[0].dot(p_xy) + _de_xy[0]))
	#print( (_ne_xy[1].dot(p_xy) + _de_xy[1]))
	#print( (_ne_xy[2].dot(p_xy) + _de_xy[2]))
	
	#print( (_ne_yz[0].dot(p_yz) + _de_yz[0]))
	#print( (_ne_yz[1].dot(p_yz) + _de_yz[1]))
	#print( (_ne_yz[2].dot(p_yz) + _de_yz[2]))
	
	#print( (_ne_zx[0].dot(p_xz) + _de_xz[0]))
	#print( (_ne_zx[1].dot(p_xz) + _de_xz[1]))
	#print( (_ne_zx[2].dot(p_xz) + _de_xz[2]))
		
	return  (_ne_xy[0].dot(p_xy) + _de_xy[0]) >= 0\
		and (_ne_xy[1].dot(p_xy) + _de_xy[1]) >= 0\
		and (_ne_xy[2].dot(p_xy) + _de_xy[2]) >= 0\
		
		and (_ne_yz[0].dot(p_yz) + _de_yz[0]) >= 0\
		and (_ne_yz[1].dot(p_yz) + _de_yz[1]) >= 0\
		and (_ne_yz[2].dot(p_yz) + _de_yz[2]) >= 0\

		and (_ne_zx[0].dot(p_xz) + _de_xz[0]) >= 0\
		and (_ne_zx[1].dot(p_xz) + _de_xz[1]) >= 0\
		and (_ne_zx[2].dot(p_xz) + _de_xz[2]) >= 0


## Distance Factor from each 
## critical point to triangle plane
var _d1: float
var _d2: float

### EDGE NORMALS' PROJECTIONS
## On xy
var _ne_xy: PackedVector2Array = [null, null, null]
## On yz
var _ne_yz: PackedVector2Array = [null, null, null]
## On xz
var _ne_zx: PackedVector2Array = [null, null, null]

### EDGE PROJECTED DISTANCES (??)
## On xy
var _de_xy: PackedFloat64Array = [null, null, null]
## On yz
var _de_yz: PackedFloat64Array = [null, null, null]
## On xz
var _de_xz: PackedFloat64Array = [null, null, null]



static func _automated_test():
	# Triangle on YZ plane
	_auto_test_triangle([Vector3(1,0,0), Vector3(1,2,1), Vector3(1,0,2)])
	
	# Triangle on XZ plane
	_auto_test_triangle([Vector3(0,1,0), Vector3(1,1,2), Vector3(2,1,0)])
	
	# Triangle on XY plane
	_auto_test_triangle([Vector3(0,0,1), Vector3(1,2,1), Vector3(2,0,1)])
	
	var solid_voxels = []
	for y in range(0, 2):
		solid_voxels.append_array([
			Vector3(-1,y,-1),
			Vector3(-1,y,0),
			Vector3(-1,y,1),
			Vector3(-1,y,2),
			Vector3(0,y,-1),
			Vector3(0,y,0),
			Vector3(0,y,1),
			Vector3(0,y,2),
			Vector3(1,y,0),
			Vector3(1,y,1),
			Vector3(2,y,0),
			Vector3(2,y,1),
		])
	_auto_test_triangle_extended(
		[Vector3(0,1,0), Vector3(1,1,2), Vector3(2,1,0)], 
		range(-1, 3),
		solid_voxels
		)
	
static func _auto_test_triangle(v: PackedVector3Array):
	var test = TriangleBoxTest.new(v, Vector3(1, 1, 1))
	var test_result = {}
	
	var box_range = range(0, 2)
	for x in box_range:
		for y in box_range:
			for z in box_range:
				test_result[Vector3(x, y, z)] = test.overlap_voxel(Vector3(x, y, z))
				
	var expected_result = {}
	for key in test_result.keys():
		expected_result[key] = false
	
	for x in range(0, 2):
		for y in range(0, 2):
			for z in range(0, 2):
				expected_result[Vector3(x, y, z)] = true

	print("Triangle-Box Overlapping automated test")
	var errors = 0
	for key in test_result.keys():
		if test_result[key] != expected_result[key]:
			errors += 1
			printerr("Test result for %s is %s, expected %s" % [key, test_result[key], expected_result[key]])
	print("Completed with %d error%s" % [errors, "" if errors < 2 else "s"])
	


static func _auto_test_triangle_extended(v: PackedVector3Array, box_range: PackedInt64Array, solid_voxels: PackedVector3Array):
	var test = TriangleBoxTest.new(v, Vector3(1, 1, 1))
	var test_result = {}
	
	for x in box_range:
		for y in box_range:
			for z in box_range:
				test_result[Vector3(x, y, z)] = test.overlap_voxel(Vector3(x, y, z))
				
	var expected_result = {}
	for key in test_result.keys():
		expected_result[key] = false
	
	for sol_vox in solid_voxels:
		expected_result[sol_vox] = true

	print("Triangle-Box Overlapping automated test")
	var errors = 0
	for key in test_result.keys():
		if test_result[key] != expected_result[key]:
			errors += 1
			printerr("Test result for %s is %s, expected %s" % [key, test_result[key], expected_result[key]])
	print("Completed with %d error%s" % [errors, "" if errors < 2 else "s"])
	
