## Fast triangle-box test as described by Michael Schwarz and Hans-Peter Seidel
class_name TriangleBoxTest

## Triangle bounding box
var aabb: AABB

## Triangle normal
var n: Vector3

## Initialize a new triangle-box test.[br]
## [br]
## [param v]: Positions of 3 triangle vertices.[br]
## [param dp]: Box size.
func _init(v: PackedVector3Array, dp: Vector3):
	# Bounding box
	aabb = AABB()
	aabb.position = v[0]
	aabb = aabb.expand(v[1])
	aabb = aabb.expand(v[2])
	
	# Edge equations
	var e: PackedVector3Array = [null, null, null]
	for i in range(0, 3):
		e[i] = v[(i+1)%3] - v[i]
	
	# NOTE: This order of vector is important. Copied from cuda_voxelizer
	n = (e[0]).cross(e[1])
	
	## Critical point
	var c = Vector3(
		0.0 if n.x <= 0 else dp.x,
		0.0 if n.y <= 0 else dp.y,
		0.0 if n.z <= 0 else dp.z)
	
	# Distance factors
	_d1 = n.dot(c - v[0])
	_d2 = n.dot((dp - c) - v[0])
	
	# Edges Normals/Distances' Projections
	for i in range(0, 3):
		_ne_xy[i] = Vector2(-e[i].y, e[i].x) * (1.0 if n.z >= 0.0 else -1.0)
		_ne_yz[i] = Vector2(-e[i].z, e[i].y) * (1.0 if n.x >= 0.0 else -1.0)
		
		# Don't even think about exchanging the signs!
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
	var np = n.dot(p) 
	return (np + _d1) * (np + _d2) <= 0


## Return true if triangle's projections on x, y, z overlaps those of voxel at position [param p].[br]
func _projection_2d_overlaps(p: Vector3) -> bool:
	var p_xy = Vector2(p.x, p.y)
	var p_yz = Vector2(p.y, p.z)
	var p_zx = Vector2(p.z, p.x)
		
	return  (_ne_xy[0].dot(p_xy) + _de_xy[0]) >= 0\
		and (_ne_xy[1].dot(p_xy) + _de_xy[1]) >= 0\
		and (_ne_xy[2].dot(p_xy) + _de_xy[2]) >= 0\
		
		and (_ne_yz[0].dot(p_yz) + _de_yz[0]) >= 0\
		and (_ne_yz[1].dot(p_yz) + _de_yz[1]) >= 0\
		and (_ne_yz[2].dot(p_yz) + _de_yz[2]) >= 0\

		and (_ne_zx[0].dot(p_zx) + _de_xz[0]) >= 0\
		and (_ne_zx[1].dot(p_zx) + _de_xz[1]) >= 0\
		and (_ne_zx[2].dot(p_zx) + _de_xz[2]) >= 0

## Distance factor from one critical point to triangle plane.
var _d1: float
## Distance factor from critical point on the opposite region of triangle plane
## to [member _d1] critical point.
var _d2: float

## Edges normal projections on xy.
var _ne_xy: PackedVector2Array = [null, null, null]
## Edges normal projections on yz.
var _ne_yz: PackedVector2Array = [null, null, null]
## Edges normal projections on zx.
var _ne_zx: PackedVector2Array = [null, null, null]

## 01/02/2025: Note to self: Calculate with float32 and store results into float64
## will cause bug on float precision. Happens in cases where triangles lie in
## x/y/z plane.

## Edges projected distances(?) on xy.
var _de_xy: PackedFloat32Array = [null, null, null]
## Edges projected distances(?) on yz.
var _de_yz: PackedFloat32Array = [null, null, null]
## Edges projected distances(?) on xz.
var _de_xz: PackedFloat32Array = [null, null, null]


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
	var test = TriangleBoxTest.new(v, box_size)
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
			errors += 1
			printerr("Got %s, expected %s for %s" % [test_result[key], expected_result[key], key])
	print("Completed with %d error%s" % [errors, "" if errors < 2 else "s"])
	
