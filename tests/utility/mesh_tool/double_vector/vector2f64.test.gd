extends GutTest

class_name Vector2F64Test


const FLOAT_TOLERANCE: float = 0.000001


func _assert_array_eq(
	got: PackedFloat64Array,
	expected: PackedFloat64Array
	) -> void:
	assert_eq(got.size(), expected.size())
	for i in range(got.size()):
		assert_almost_eq(got[i], expected[i], FLOAT_TOLERANCE)


func test_new() -> void:
	var input: Vector2 = Vector2(1.25, -2.5)
	var expected: PackedFloat64Array = [1.25, -2.5]
	var result: PackedFloat64Array = Vector2F64.create(input)
	_assert_array_eq(result, expected)


func test_new_array() -> void:
	var input: Array[Vector2] = [
		Vector2(1.25, -2.5),
		Vector2(0.0, 9.75),
	]
	var expected: PackedFloat64Array = [
		1.25, -2.5, 0.0, 9.75
	]
	var result: PackedFloat64Array = Vector2F64.create_array(input)
	_assert_array_eq(result, expected)


func test_new_tarray() -> void:
	var input: PackedVector3Array = PackedVector3Array([
		Vector3(1.25, -2.5, 3.5),
		Vector3(0.0, 9.75, -7.25),
	])
	var expected: PackedFloat64Array = [
		1.25, -2.5, 0.0, 9.75
	]
	var result: PackedFloat64Array = Vector2F64.create_tarray(input)
	_assert_array_eq(result, expected)


func test_sub() -> void:
	var a: PackedFloat64Array = [2.5, -1.0, 9.0, 8.0]
	var b: PackedFloat64Array = [0.5, 1.25, 3.0, 4.0]
	var c: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
	var expected: PackedFloat64Array = [
		2.0, -2.25, 0.0, 0.0
	]
	Vector2F64.sub(a, 0, b, 0, c, 0)
	_assert_array_eq(c, expected)


func test_sum() -> void:
	var a: PackedFloat64Array = [2.5, -1.0, 9.0, 8.0]
	var b: PackedFloat64Array = [0.5, 1.25, 3.0, 4.0]
	var c: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
	var expected: PackedFloat64Array = [
		3.0, 0.25, 0.0, 0.0
	]
	Vector2F64.sum(a, 0, b, 0, c, 0)
	_assert_array_eq(c, expected)


func test_assign() -> void:
	var a: PackedFloat64Array = [0.0, 0.0, 9.0, 8.0]
	var b: PackedFloat64Array = [2.5, -1.0, 3.0, 4.0]
	var expected: PackedFloat64Array = [
		2.5, -1.0, 9.0, 8.0
	]
	Vector2F64.assign(a, 0, b, 0)
	_assert_array_eq(a, expected)


func test_assignv() -> void:
	var a: PackedFloat64Array = [0.0, 0.0, 9.0, 8.0]
	var input: Vector2 = Vector2(2.5, -1.0)
	var expected: PackedFloat64Array = [
		2.5, -1.0, 9.0, 8.0
	]
	Vector2F64.assignv(a, 0, input)
	_assert_array_eq(a, expected)


func test_dot() -> void:
	var a: PackedFloat64Array = [1.0, -2.0]
	var b: PackedFloat64Array = [4.0, 0.5]
	var expected: float = 3.0
	var result: float = Vector2F64.dot(a, 0, b, 0)
	assert_almost_eq(result, expected, FLOAT_TOLERANCE)


func test_normalize() -> void:
	var a: PackedFloat64Array = [-3.0, 4.0]
	var b: PackedFloat64Array = [0.0, 0.0]
	var expected: PackedFloat64Array = [-0.6, 0.8]
	Vector2F64.normalize(a, 0, b, 0)
	assert_almost_eq(b[0], expected[0], 0.000001)
	assert_almost_eq(b[1], expected[1], 0.000001)
