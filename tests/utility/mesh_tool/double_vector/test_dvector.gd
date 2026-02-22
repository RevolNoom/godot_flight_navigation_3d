extends GutTest

class_name DvectorTest


func _assert_array_eq(
	got: PackedFloat64Array,
	expected: PackedFloat64Array
):
	assert_eq(got.size(), expected.size())
	for i in range(got.size()):
		assert_eq(got[i], expected[i])


func test_new_v2():
	var input = Vector2(1.25, -2.5)
	var expected: PackedFloat64Array = [1.25, -2.5]
	var result = Dvector.create_v2(input)
	_assert_array_eq(result, expected)


func test_new_array_v2():
	var input: Array[Vector2] = [
		Vector2(1.25, -2.5),
		Vector2(0.0, 9.75),
	]
	var expected: PackedFloat64Array = [
		1.25, -2.5, 0.0, 9.75
	]
	var result = Dvector.create_array_v2(input)
	_assert_array_eq(result, expected)


func test_new_array_pv2():
	var input = PackedVector2Array([
		Vector2(1.25, -2.5),
		Vector2(0.0, 9.75),
	])
	var expected: PackedFloat64Array = [
		1.25, -2.5, 0.0, 9.75
	]
	var result = Dvector.create_array_pv2(input)
	_assert_array_eq(result, expected)


func test_new_v3():
	var input = Vector3(1.25, -2.5, 8.0)
	var expected: PackedFloat64Array = [
		1.25, -2.5, 8.0
	]
	var result = Dvector.create_v3(input)
	_assert_array_eq(result, expected)


func test_new_array_v3():
	var input: Array[Vector3] = [
		Vector3(1.25, -2.5, 3.5),
		Vector3(0.0, 9.75, -7.25),
	]
	var expected: PackedFloat64Array = [
		1.25, -2.5, 3.5, 0.0, 9.75, -7.25
	]
	var result = Dvector.create_array_v3(input)
	_assert_array_eq(result, expected)


func test_new_array_pv3():
	var input = PackedVector3Array([
		Vector3(1.25, -2.5, 3.5),
		Vector3(0.0, 9.75, -7.25),
	])
	var expected: PackedFloat64Array = [
		1.25, -2.5, 3.5, 0.0, 9.75, -7.25
	]
	var result = Dvector.create_array_pv3(input)
	_assert_array_eq(result, expected)


func test_sub():
	var a: PackedFloat64Array = [2.5, -1.0, 0.75]
	var b: PackedFloat64Array = [0.5, 1.25, -0.25]
	var out: PackedFloat64Array = [0.0, 0.0, 0.0]
	var expected: PackedFloat64Array = [2.0, -2.25, 1.0]
	Dvector.sub(out, a, b)
	_assert_array_eq(out, expected)


func test_sum():
	var a: PackedFloat64Array = [2.5, -1.0, 0.75]
	var b: PackedFloat64Array = [0.5, 1.25, -0.25]
	var out: PackedFloat64Array = [0.0, 0.0, 0.0]
	var expected: PackedFloat64Array = [3.0, 0.25, 0.5]
	Dvector.sum(out, a, b)
	_assert_array_eq(out, expected)


func test_assign():
	var out: PackedFloat64Array = [0.0, 0.0, 0.0]
	var a: PackedFloat64Array = [2.5, -1.0, 0.75]
	var expected: PackedFloat64Array = [2.5, -1.0, 0.75]
	Dvector.assign(out, a)
	_assert_array_eq(out, expected)


func test_assign_v2():
	var out: PackedFloat64Array = [0.0, 0.0]
	var input = Vector2(2.5, -1.0)
	var expected: PackedFloat64Array = [2.5, -1.0]
	Dvector.assign_v2(out, input)
	_assert_array_eq(out, expected)


func test_assign_v3():
	var out: PackedFloat64Array = [0.0, 0.0, 0.0]
	var input = Vector3(2.5, -1.0, 0.75)
	var expected: PackedFloat64Array = [2.5, -1.0, 0.75]
	Dvector.assign_v3(out, input)
	_assert_array_eq(out, expected)


func test_dot():
	var a: PackedFloat64Array = [1.0, -2.0, 3.5]
	var b: PackedFloat64Array = [4.0, 0.5, -1.0]
	var expected = -0.5
	var result = Dvector.dot(a, b)
	assert_eq(result, expected)


func test_cross():
	var a: PackedFloat64Array = [1.0, 2.0, 3.0]
	var b: PackedFloat64Array = [4.0, 5.0, 6.0]
	var out: PackedFloat64Array = [0.0, 0.0, 0.0]
	var expected: PackedFloat64Array = [-3.0, 6.0, -3.0]
	Dvector.cross(out, a, b)
	_assert_array_eq(out, expected)


func test_normalize():
	var a: PackedFloat64Array = [-2.0, 1.0, -2.0]
	var out: PackedFloat64Array = [0.0, 0.0, 0.0]
	var expected: PackedFloat64Array = [
		-0.6666666666666666,
		0.3333333333333333,
		-0.6666666666666666,
	]
	Dvector.normalize(out, a)
	assert_almost_eq(out[0], expected[0], 0.000001)
	assert_almost_eq(out[1], expected[1], 0.000001)
	assert_almost_eq(out[2], expected[2], 0.000001)
