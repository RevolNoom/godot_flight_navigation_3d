## Vector3 which has all x, y, z coordinates in float64
##
## Godot has built-in float32 for Vector types. 
## This class offers to work with triplets of element of PackedFloat64Array 
## as if they are Vector.
class_name Vector3F64

static func _new(a: Vector3) -> PackedFloat64Array:
	return [a[0], a[1], a[2]]
	
static func _new_array(a: Array[Vector3]) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	result.resize(a.size()*3)
	var i3 = 0
	for i in range(a.size()):
		i3 = i*3
		result[i3] = a[i][0]
		result[i3+1] = a[i][1]
		result[i3+2] = a[i][2]
	return result
	
static func _new_tarray(a: PackedVector3Array) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	result.resize(a.size()*3)
	var i3 = 0
	for i in range(a.size()):
		i3 = i*3
		result[i3] = a[i][0]
		result[i3+1] = a[i][1]
		result[i3+2] = a[i][2]
	return result

## Perform subtraction of Va - Vb where:[br]
## +) Va = Vector3(a[a_idx], a[a_idx+1], a[a_idx+2])[br]
## +) Vb = Vector3(b[b_idx], b[b_idx+1], b[b_idx+2])[br]
## then put the result in c[c_idx], c[c_idx+1], c[c_idx+2]
static func sub(
	a: PackedFloat64Array, a_idx: int, 
	b: PackedFloat64Array, b_idx: int, 
	c: PackedFloat64Array, c_idx: int):
		c[c_idx] = a[a_idx] - b[b_idx]
		c[c_idx + 1] = a[a_idx + 1] - b[b_idx + 1]
		c[c_idx + 2] = a[a_idx + 2] - b[b_idx + 2]
		
## Perform summation of Va + Vb where:[br]
## +) Va = Vector3(a[a_idx], a[a_idx+1], a[a_idx+2])[br]
## +) Vb = Vector3(b[b_idx], b[b_idx+1], b[b_idx+2])[br]
## then put the result in c[c_idx], c[c_idx+1], c[c_idx+2]
static func sum(
	a: PackedFloat64Array, a_idx: int, 
	b: PackedFloat64Array, b_idx: int, 
	c: PackedFloat64Array, c_idx: int):
		c[c_idx] = a[a_idx] + b[b_idx]
		c[c_idx + 1] = a[a_idx + 1] + b[b_idx + 1]
		c[c_idx + 2] = a[a_idx + 2] + b[b_idx + 2]
		
## Assign Va = Vb:[br]
## +) Va = Vector3(a[a_idx], a[a_idx+1], a[a_idx+2])[br]
## +) Vb = Vector3(b[b_idx], b[b_idx+1], b[b_idx+2])[br]
static func assign(
	a: PackedFloat64Array, a_idx: int, 
	b: PackedFloat64Array, b_idx: int):
		a[a_idx] = b[b_idx]
		a[a_idx + 1] = b[b_idx + 1]
		a[a_idx + 2] = b[b_idx + 2]
		
## Assign Va = Vb
static func assignv(
	a: PackedFloat64Array, a_idx: int, 
	b: Vector3):
		a[a_idx] = b[0]
		a[a_idx + 1] = b[1]
		a[a_idx + 2] = b[2]
		
## Perform Va.dot(Vb)
static func dot(
	a: PackedFloat64Array, a_idx: int, 
	b: PackedFloat64Array, b_idx: int) -> float:
		return a[a_idx] * b[b_idx]\
			+ a[a_idx + 1] * b[b_idx + 1]\
			+ a[a_idx + 2] * b[b_idx + 2]
		
## Perform Va.cross(Vb) where:[br]
## +) Va = Vector3(a[a_idx], a[a_idx+1], a[a_idx+2])[br]
## +) Vb = Vector3(b[b_idx], b[b_idx+1], b[b_idx+2])[br]
## then put the result in c[c_idx], c[c_idx+1], c[c_idx+2].
## https://en.wikipedia.org/wiki/Cross_product
static func cross(
	a: PackedFloat64Array, a_idx: int, 
	b: PackedFloat64Array, b_idx: int, 
	c: PackedFloat64Array, c_idx: int):
		c[c_idx] = a[a_idx + 1] * b[b_idx + 2] - a[a_idx + 2] * b[b_idx + 1]
		c[c_idx + 1] = a[a_idx + 2] * b[b_idx] - a[a_idx] * b[b_idx + 2]
		c[c_idx + 2] = a[a_idx] * b[b_idx + 1] - a[a_idx + 1] * b[b_idx]
		#c[c_idx] = -c[c_idx]
		#c[c_idx + 1] = -c[c_idx + 1]
		#c[c_idx + 2] = -c[c_idx + 2]
