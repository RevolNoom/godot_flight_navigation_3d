## Vector2 which has all x, y coordinates in float64
##
## Godot has built-in float32 for Vector types. 
## This class offers to work with doublets of element of PackedFloat64Array 
## as if they are Vector.
class_name Vector2F64

static func _new(a: Vector2) -> PackedFloat64Array:
	return [a[0], a[1]]
	
static func _new_array(a: Array[Vector2]) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	result.resize(a.size()<<1)
	var i2 = 0
	for i in range(a.size()<<1):
		i2 = i*2
		result[i2] = a[i][0]
		result[i2+1] = a[i][1]
	return result
	
static func _new_tarray(a: PackedVector3Array) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	result.resize(a.size()<<1)
	var i2 = 0
	for i in range(a.size()<<1):
		i2 = i*2
		result[i2] = a[i][0]
		result[i2+1] = a[i][1]
	return result

## Perform subtraction of Va - Vb where:[br]
## +) Va = Vector2(a[a_idx], a[a_idx+1])[br]
## +) Vb = Vector2(b[b_idx], b[b_idx+1])[br]
## then put the result in c[c_idx], c[c_idx+1]
static func sub(
	a: PackedFloat64Array, a_idx: int, 
	b: PackedFloat64Array, b_idx: int, 
	c: PackedFloat64Array, c_idx: int):
		c[c_idx] = a[a_idx] - b[b_idx]
		c[c_idx + 1] = a[a_idx + 1] - b[b_idx + 1]
		
## Perform summation of Va + Vb where:[br]
## +) Va = Vector2(a[a_idx], a[a_idx+1])[br]
## +) Vb = Vector2(b[b_idx], b[b_idx+1])[br]
## then put the result in c[c_idx], c[c_idx+1]
static func sum(
	a: PackedFloat64Array, a_idx: int, 
	b: PackedFloat64Array, b_idx: int, 
	c: PackedFloat64Array, c_idx: int):
		c[c_idx] = a[a_idx] + b[b_idx]
		c[c_idx + 1] = a[a_idx + 1] + b[b_idx + 1]
		
## Assign Va = Vb:[br]
## +) Va = Vector2(a[a_idx], a[a_idx+1])[br]
## +) Vb = Vector2(b[b_idx], b[b_idx+1])[br]
static func assign(
	a: PackedFloat64Array, a_idx: int, 
	b: PackedFloat64Array, b_idx: int):
		a[a_idx] = b[b_idx]
		a[a_idx + 1] = b[b_idx + 1]

## Assign Va = Vb
static func assignv(
	a: PackedFloat64Array, a_idx: int, 
	b: Vector2):
		a[a_idx] = b[0]
		a[a_idx + 1] = b[1]
		
## Perform Va.dot(Vb)
static func dot(
	a: PackedFloat64Array, a_idx: int, 
	b: PackedFloat64Array, b_idx: int) -> float:
		return a[a_idx] * b[b_idx]\
			+ a[a_idx + 1] * b[b_idx + 1]
