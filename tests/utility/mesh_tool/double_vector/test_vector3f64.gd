extends GutTest

class_name Vector3F64Test


func _assert_array_eq(
	got: PackedFloat64Array,
	expected: PackedFloat64Array
):
	assert_eq(got.size(), expected.size())
	for i in range(got.size()):
		assert_eq(got[i], expected[i])


func test_new():
	var input = Vector3(1.25, -2.5, 8.0)
	var expected: PackedFloat64Array = [
		1.25, -2.5, 8.0
	]
	var result = Vector3F64.create(input)
	_assert_array_eq(result, expected)


func test_new_array():
	var input: Array[Vector3] = [
		Vector3(1.25, -2.5, 3.5),
		Vector3(0.0, 9.75, -7.25),
	]
	var expected: PackedFloat64Array = [
		1.25, -2.5, 3.5, 0.0, 9.75, -7.25
	]
	var result = Vector3F64.create_array(input)
	_assert_array_eq(result, expected)


func test_new_tarray():
	var input = PackedVector3Array([
		Vector3(1.25, -2.5, 3.5),
		Vector3(0.0, 9.75, -7.25),
	])
	var expected: PackedFloat64Array = [
		1.25, -2.5, 3.5, 0.0, 9.75, -7.25
	]
	var result = Vector3F64.create_tarray(input)
	_assert_array_eq(result, expected)


func test_sub():
	var a: PackedFloat64Array = [
		2.5, -1.0, 0.75, 9.0, 8.0, 7.0
	]
	var b: PackedFloat64Array = [
		0.5, 1.25, -0.25, 3.0, 4.0, 5.0
	]
	var c: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
	var expected: PackedFloat64Array = [
		2.0, -2.25, 1.0, 0.0
	]
	Vector3F64.sub(a, 0, b, 0, c, 0)
	_assert_array_eq(c, expected)


func test_sum():
	var a: PackedFloat64Array = [
		2.5, -1.0, 0.75, 9.0, 8.0, 7.0
	]
	var b: PackedFloat64Array = [
		0.5, 1.25, -0.25, 3.0, 4.0, 5.0
	]
	var c: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0]
	var expected: PackedFloat64Array = [
		3.0, 0.25, 0.5, 0.0
	]
	Vector3F64.sum(a, 0, b, 0, c, 0)
	_assert_array_eq(c, expected)


func test_assign():
	var a: PackedFloat64Array = [0.0, 0.0, 0.0, 9.0, 8.0, 7.0]
	var b: PackedFloat64Array = [2.5, -1.0, 0.75, 3.0, 4.0, 5.0]
	var expected: PackedFloat64Array = [
		2.5, -1.0, 0.75, 9.0, 8.0, 7.0
	]
	Vector3F64.assign(a, 0, b, 0)
	_assert_array_eq(a, expected)


func test_assignv():
	var a: PackedFloat64Array = [0.0, 0.0, 0.0, 9.0, 8.0, 7.0]
	var input = Vector3(2.5, -1.0, 0.75)
	var expected: PackedFloat64Array = [
		2.5, -1.0, 0.75, 9.0, 8.0, 7.0
	]
	Vector3F64.assignv(a, 0, input)
	_assert_array_eq(a, expected)


func test_dot():
	var a: PackedFloat64Array = [1.0, -2.0, 3.5]
	var b: PackedFloat64Array = [4.0, 0.5, -1.0]
	var expected = -0.5
	var result = Vector3F64.dot(a, 0, b, 0)
	assert_eq(result, expected)


func test_cross():
	var a: PackedFloat64Array = [1.0, 2.0, 3.0]
	var b: PackedFloat64Array = [4.0, 5.0, 6.0]
	var c: PackedFloat64Array = [0.0, 0.0, 0.0]
	var expected: PackedFloat64Array = [-3.0, 6.0, -3.0]
	Vector3F64.cross(a, 0, b, 0, c, 0)
	_assert_array_eq(c, expected)


func test_normalize():
	var a: PackedFloat64Array = [-2.0, 1.0, -2.0]
	var b: PackedFloat64Array = [0.0, 0.0, 0.0]
	var expected: PackedFloat64Array = [
		-0.6666666666666666,
		0.3333333333333333,
		-0.6666666666666666,
	]
	Vector3F64.normalize(a, 0, b, 0)
	assert_almost_eq(b[0], expected[0], 0.000001)
	assert_almost_eq(b[1], expected[1], 0.000001)
	assert_almost_eq(b[2], expected[2], 0.000001)
