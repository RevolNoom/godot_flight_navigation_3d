## Fast triangle-box test as described by Michael Schwarz and Hans-Peter Seidel
extends RefCounted
class_name TriangleBoxTest

## Triangle bounding box
var aabb: AABB

## All member variables are serialized as float 64 and referenced via enum Field.[br]
## This is to make sure that all calculations are done in float 64, not float 32 
## when variables are stored as Vector2 or Vector3.
var _fields: PackedFloat64Array

enum Field {
	## Triangle normal
	V3_N = 0,
	## Edges normal projections on xy. 3 edges.
	V2_NE_XY = 3,
	## Edges normal projections on yz. 3 edges.
	V2_NE_YZ = 9,
	## Edges normal projections on zx. 3 edges.
	V2_NE_ZX = 15,
	## Edges projected distances(?) on xy. 3 edges.
	F_DE_XY = 21,
	## Edges projected distances(?) on yz. 3 edges.
	F_DE_YZ = 24,
	## Edges projected distances(?) on zx. 3 edges.
	F_DE_ZX = 27,
	## Temporary field for calculation result. 1 Vector3 or 2 Vector2
	TEMP = 30,
	## Distance factor 1
	F_D1 = 34,
	## Distance factor 2
	F_D2,
	FIELD_MAX,
}


## Initialize a new triangle-box test.[br]
## [br]
## [param v]: Positions of 3 triangle vertices.[br]
## [param dp]: Box size.
func _init(v: PackedVector3Array, dp: Vector3):
	var vf64 = Vector3F64._new_tarray(v)
	var dpf64 = Vector3F64._new(dp)
	_fields = PackedFloat64Array()
	_fields.resize(Field.FIELD_MAX)
	
	# Bounding box
	aabb = AABB(v[0], Vector3()).expand(v[1]).expand(v[2]).abs()
	
	# Edge equations
	var e: PackedFloat64Array = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	Vector3F64.sub(vf64, 3, vf64, 0, e, 0)
	Vector3F64.sub(vf64, 6, vf64, 3, e, 3)
	Vector3F64.sub(vf64, 0, vf64, 6, e, 6)
	
	# Triangle normal
	# NOTE: This order of vector is important. Copied from cuda_voxelizer
	Vector3F64.cross(e, 0, e, 3, _fields, Field.V3_N)
	
	# Critical point
	var c: PackedFloat64Array = [
		0.0 if _fields[Field.V3_N] <= 0 else dp.x,
		0.0 if _fields[Field.V3_N + 1] <= 0 else dp.y,
		0.0 if _fields[Field.V3_N + 2] <= 0 else dp.z]
	
	# Distance factors
	Vector3F64.sub(c, 0, vf64, 0, _fields, Field.TEMP)
	_fields[Field.F_D1] = Vector3F64.dot(_fields, Field.V3_N, _fields, Field.TEMP) 
	
	Vector3F64.sub(dpf64, 0, c, 0, _fields, Field.TEMP)
	Vector3F64.sub(_fields, Field.TEMP, vf64, 0, _fields, Field.TEMP)
	_fields[Field.F_D2] = Vector3F64.dot(_fields, Field.V3_N, _fields, Field.TEMP)
	
	# Edges Normals/Distances' Projections
	for i in range(3):
		if _fields[Field.V3_N + 2] >= 0: # n.z >= 0
			_fields[Field.V2_NE_XY + i * 2 + 0] = -e[i*3+1] 
			_fields[Field.V2_NE_XY + i * 2 + 1] = e[i*3+0]
		else:
			_fields[Field.V2_NE_XY + i * 2 + 0] = e[i*3+1]
			_fields[Field.V2_NE_XY + i * 2 + 1] = -e[i*3+0]
			
		if _fields[Field.V3_N + 0] >= 0: # n.x >= 0
			_fields[Field.V2_NE_YZ + i * 2 + 0] = -e[i*3+2]
			_fields[Field.V2_NE_YZ + i * 2 + 1] = e[i*3+1]
		else:
			_fields[Field.V2_NE_YZ + i * 2 + 0] = e[i*3+2]
			_fields[Field.V2_NE_YZ + i * 2 + 1] = -e[i*3+1]
			
		if _fields[Field.V3_N+1] >= 0: # n.y >= 0
			_fields[Field.V2_NE_ZX + i * 2 + 0] = -e[i*3+0]
			_fields[Field.V2_NE_ZX + i * 2 + 1] = e[i*3+2]
		else:
			_fields[Field.V2_NE_ZX + i * 2 + 0] = e[i*3+0]
			_fields[Field.V2_NE_ZX + i * 2 + 1] = -e[i*3+2]

		_fields[Field.F_DE_XY + i] = \
			- Vector2F64.dot(_fields, Field.V2_NE_XY + i*2, vf64, i*3)\
			+ maxf(0, dpf64[0]*_fields[Field.V2_NE_XY + i*2 + 0])\
			+ maxf(0, dpf64[1]*_fields[Field.V2_NE_XY + i*2 + 1])
			
		#i*3+1 so we are dotting yz
		_fields[Field.F_DE_YZ + i] = \
			- Vector2F64.dot(_fields, Field.V2_NE_YZ + i*2, vf64, i*3+1)\
			+ maxf(0, dpf64[1]*_fields[Field.V2_NE_YZ + i*2 + 0])\
			+ maxf(0, dpf64[2]*_fields[Field.V2_NE_YZ + i*2 + 1])
		
		_fields[Field.TEMP + 0] = vf64[i*3+2] # z
		_fields[Field.TEMP + 1] = vf64[i*3+0] # x
		_fields[Field.F_DE_ZX + i] = \
			- Vector2F64.dot(_fields, Field.V2_NE_ZX + i*2, _fields, Field.TEMP)\
			+ maxf(0, dpf64[0]*_fields[Field.V2_NE_ZX + i*2 + 0])\
			+ maxf(0, dpf64[2]*_fields[Field.V2_NE_ZX + i*2 + 1])


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
	Vector3F64.assignv(_fields, Field.TEMP, p)
	var np = Vector3F64.dot(_fields, Field.V3_N, _fields, Field.TEMP)
	return (np + _fields[Field.F_D1]) * (np + _fields[Field.F_D2]) <= 0
	#var npd1 = (np + _fields[Field.F_D1])
	#var npd2 = (np + _fields[Field.F_D2])
	#return npd1 * npd2 <= 0

## Return true if triangle's projections on x, y, z overlaps those of voxel at position [param p].[br]
func _projection_2d_overlaps(p: Vector3) -> bool:
	# XY, YZ, ZX Projections
	_fields[Field.TEMP + 0] = p[0]
	_fields[Field.TEMP + 1] = p[1]
	_fields[Field.TEMP + 2] = p[2]
	_fields[Field.TEMP + 3] = p[0]
	
	#var b1 = (Vector2F64.dot(_fields, Field.V2_NE_XY, _fields, Field.TEMP)\
	#+ _fields[Field.F_DE_XY]) >= 0
	#var b2 = (Vector2F64.dot(_fields, Field.V2_NE_XY + 2, _fields, Field.TEMP)\
	#+ _fields[Field.F_DE_XY + 1]) >= 0
	#var b3 = (Vector2F64.dot(_fields, Field.V2_NE_XY + 4, _fields, Field.TEMP)\
	#+ _fields[Field.F_DE_XY + 2]) >= 0
#
	#var b4 = (Vector2F64.dot(_fields, Field.V2_NE_YZ, _fields, Field.TEMP + 1)\
	#+ _fields[Field.F_DE_YZ]) >= 0
	#var b5 = (Vector2F64.dot(_fields, Field.V2_NE_YZ + 2, _fields, Field.TEMP + 1)\
	#+ _fields[Field.F_DE_YZ + 1]) >= 0
	#var b6 = (Vector2F64.dot(_fields, Field.V2_NE_YZ + 4, _fields, Field.TEMP + 1)\
	#+ _fields[Field.F_DE_YZ + 2]) >= 0
	#
	#var b7 = (Vector2F64.dot(_fields, Field.V2_NE_ZX, _fields, Field.TEMP + 2)\
	#+ _fields[Field.F_DE_ZX]) >= 0
	#var b8 = (Vector2F64.dot(_fields, Field.V2_NE_ZX + 2, _fields, Field.TEMP + 2)\
	#+ _fields[Field.F_DE_ZX + 1]) >= 0
	#var b9 = (Vector2F64.dot(_fields, Field.V2_NE_ZX + 4, _fields, Field.TEMP + 2)\
	#+ _fields[Field.F_DE_ZX + 2]) >= 0
	#return b1 and b2 and b3 and b4 and b5 and b6 and b7 and b8 and b9
	
	return\
	(Vector2F64.dot(_fields, Field.V2_NE_XY, _fields, Field.TEMP)\
	+ _fields[Field.F_DE_XY]) >= 0\
and (Vector2F64.dot(_fields, Field.V2_NE_XY + 2, _fields, Field.TEMP)\
	+ _fields[Field.F_DE_XY + 1]) >= 0\
and (Vector2F64.dot(_fields, Field.V2_NE_XY + 4, _fields, Field.TEMP)\
	+ _fields[Field.F_DE_XY + 2]) >= 0\

and (Vector2F64.dot(_fields, Field.V2_NE_YZ, _fields, Field.TEMP + 1)\
	+ _fields[Field.F_DE_YZ]) >= 0\
and (Vector2F64.dot(_fields, Field.V2_NE_YZ + 2, _fields, Field.TEMP + 1)\
	+ _fields[Field.F_DE_YZ + 1]) >= 0\
and (Vector2F64.dot(_fields, Field.V2_NE_YZ + 4, _fields, Field.TEMP + 1)\
	+ _fields[Field.F_DE_YZ + 2]) >= 0\
	
and (Vector2F64.dot(_fields, Field.V2_NE_ZX, _fields, Field.TEMP + 2)\
	+ _fields[Field.F_DE_ZX]) >= 0\
and (Vector2F64.dot(_fields, Field.V2_NE_ZX + 2, _fields, Field.TEMP + 2)\
	+ _fields[Field.F_DE_ZX + 1]) >= 0\
and (Vector2F64.dot(_fields, Field.V2_NE_ZX + 4, _fields, Field.TEMP + 2)\
	+ _fields[Field.F_DE_ZX + 2]) >= 0


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
			test.overlap_voxel(key)
			errors += 1
			printerr("Got %s, expected %s for %s" % [test_result[key], expected_result[key], key])
	print("Completed with %d error%s" % [errors, "" if errors < 2 else "s"])
	
