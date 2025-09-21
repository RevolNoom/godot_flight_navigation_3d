## Vector with coordinates stored in float64
##
## Godot has built-in float32 for Vector types. 
## This class offers to work with PackedFloat64Array of same arbitrary size.
class_name Dvector


static func _new_v2(a: Vector3) -> PackedFloat64Array:
	return [a[0], a[1]]


static func _new_array_v2(a: Array[Vector2]) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	result.resize(a.size()*2)
	var i2 = 0
	for i in range(a.size()):
		i2 = i*2
		result[i2] = a[i][0]
		result[i2+1] = a[i][1]
	return result


static func _new_array_pv2(a: PackedVector2Array) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	result.resize(a.size()*2)
	var i2 = 0
	for i in range(a.size()):
		i2 = i*2
		result[i2] = a[i][0]
		result[i2+1] = a[i][1]
	return result


static func _new_v3(a: Vector3) -> PackedFloat64Array:
	return [a[0], a[1], a[2]]


static func _new_array_v3(a: Array[Vector3]) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	result.resize(a.size()*3)
	var i3 = 0
	for i in range(a.size()):
		i3 = i*3
		result[i3] = a[i][0]
		result[i3+1] = a[i][1]
		result[i3+2] = a[i][2]
	return result


static func _new_array_pv3(a: PackedVector3Array) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	result.resize(a.size()*3)
	var i3 = 0
	for i in range(a.size()):
		i3 = i*3
		result[i3] = a[i][0]
		result[i3+1] = a[i][1]
		result[i3+2] = a[i][2]
	return result


## Perform [param out] = [param a] - [param b]
static func sub(
	out: PackedFloat64Array,
	a: PackedFloat64Array,
	b: PackedFloat64Array
):
	for i in range(out.size()):
		out[i] = a[i] - b[i]


## Perform [param out] = [param a] + [param b]
static func sum(
	out: PackedFloat64Array,
	a: PackedFloat64Array,
	b: PackedFloat64Array
):
	for i in range(out.size()):
		out[i] = a[i] + b[i]


## Perform [param out] = [param a]
static func assign(
	out: PackedFloat64Array,
	a: PackedFloat64Array
):
	for i in range(out.size()):
		out[i] = a[i]


## Perform [param out] = [param a]
static func assign_v2(
	out: PackedFloat64Array,
	a: Vector2
):
	out[0] = a[0]
	out[1] = a[1]


## Perform [param out] = [param a]
static func assign_v3(
	out: PackedFloat64Array,
	a: Vector3
):
	out[0] = a[0]
	out[1] = a[1]
	out[2] = a[2]


## Perform [param a].dot([param b])
static func dot(
	a: PackedFloat64Array, 
	b: PackedFloat64Array) -> float:
	var result: float = 0
	for i in range(a.size()):
		result += a[i] * b[i]
	return result


## Perform [param out] = [param a].cross([param b]).
## All of them should be array of size 3
## https://en.wikipedia.org/wiki/Cross_product
static func cross(
	out: PackedFloat64Array,
	a: PackedFloat64Array,
	b: PackedFloat64Array):
		out[0] = a[1] * b[2] - a[2] * b[1]
		out[1] = a[2] * b[0] - a[0] * b[2]
		out[2] = a[0] * b[1] - a[1] * b[0]


## Perform [param out] = Vector.normalize([param a])
static func normalize(
	out: PackedFloat64Array, 
	a: PackedFloat64Array):
		var a0_squared: float = a[0] * a[0]
		var a1_squared: float = a[1] * a[1]
		var a2_squared: float = a[2] * a[2]
		var sum_squared: float = a0_squared + a1_squared + a2_squared
		
		out[0] = sqrt(a0_squared / sum_squared)
		out[1] = sqrt(a1_squared / sum_squared)
		out[2] = sqrt(a2_squared / sum_squared)
