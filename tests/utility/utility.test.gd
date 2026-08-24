extends GutTest

class_name Fn3dUtilityTest


const FLOAT_TOLERANCE: float = 0.000001


func test_sum_number_array() -> void:
	var input_int: PackedInt64Array = [2, 4, 6, 8]
	var expected_int: int = 20
	var result_int: int = Fn3dUtility.sum_number_array(input_int)
	assert_eq(result_int, expected_int)

	var input_float: PackedFloat64Array = [1.5, 2.25, 3.25]
	var expected_float: float = 7.0
	var result_float: float = Fn3dUtility.sum_number_array(input_float)
	assert_almost_eq(result_float, expected_float, FLOAT_TOLERANCE)


func test_count_unique_element_on_sorted_array() -> void:
	var empty_input: Array[int] = []
	var expected_empty: int = 0
	var result_empty: int = \
		Fn3dUtility.count_unique_element_on_sorted_array(
			empty_input)
	assert_eq(result_empty, expected_empty)

	var one_element_input: Array[int] = [5]
	var expected_one_element: int = 1
	var result_one_element: int = \
		Fn3dUtility.count_unique_element_on_sorted_array(
			one_element_input)
	assert_eq(result_one_element, expected_one_element)

	var input: Array[int] = [1, 1, 2, 2, 2, 4, 7, 7]
	var expected: int = 4
	var result: int = \
		Fn3dUtility.count_unique_element_on_sorted_array(
			input)
	assert_eq(result, expected)


func test_make_unique_from_sorted_array() -> void:
	var empty_input: Array[int] = []
	var expected_empty: Array[int] = []
	var result_empty: Array[int] = \
		Fn3dUtility.make_unique_from_sorted_array(
			empty_input)
	assert_eq(result_empty, expected_empty)

	var one_element_input: Array[int] = [9]
	var expected_one_element: Array[int] = [9]
	var result_one_element: Array[int] = \
		Fn3dUtility.make_unique_from_sorted_array(
			one_element_input)
	assert_eq(result_one_element, expected_one_element)

	var input: Array[int] = [1, 1, 2, 2, 2, 4, 7, 7]
	var expected: Array[int] = [1, 2, 4, 7]
	var result: Array[int] = \
		Fn3dUtility.make_unique_from_sorted_array(
			input)
	assert_eq(result, expected)
	assert_eq(input, [1, 1, 2, 2, 2, 4, 7, 7])


func test_count_unique_element_appearance() -> void:
	var empty_input: Array[int] = []
	var expected_empty: PackedInt64Array = []
	var result_empty: PackedInt64Array = \
		Fn3dUtility.count_unique_element_appearance(
			empty_input)
	assert_eq(result_empty, expected_empty)

	var one_element_input: Array[int] = [5]
	var expected_one_element: PackedInt64Array = [1]
	var result_one_element: PackedInt64Array = \
		Fn3dUtility.count_unique_element_appearance(
			one_element_input)
	assert_eq(result_one_element, expected_one_element)

	var input: Array[int] = [1, 1, 2, 2, 2, 4, 7, 7]
	var expected: PackedInt64Array = [2, 3, 1, 2]
	var result: PackedInt64Array = \
		Fn3dUtility.count_unique_element_appearance(
			input)
	assert_eq(result, expected)


func test_filter_in_place() -> void:
	var input: Array[int] = [10, 11, 12, 13, 14, 15]
	var expected: Array[int] = [10, 12, 14]
	Fn3dUtility.filter_in_place(
		input,
		func(_element: int, index: int) -> bool:
			return index % 2 == 0
	)
	assert_eq(input, expected)


func test_count_bit_1() -> void:
	var cases: Array[Dictionary] = [
		{"number": 0b0, "expected": 0},
		{"number": 0b1, "expected": 1},
		{"number": 0b101010, "expected": 3},
		{"number": 0b0000_1111_0000_1111_0000_1111_0000_1111_0000_1111_0000_1111_0000_1111_0000_1111, "expected": 32},
		{"number": 0b0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111, "expected": 63},
		{"number": ~0b0, "expected": 64},
		{"number": ~0b0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111, "expected": 1},
	]

	for case_data in cases:
		var result: int = Fn3dUtility.count_bit_1(int(case_data["number"]))
		assert_eq(result, int(case_data["expected"]), "Unexpected bit-count result for %s" % [case_data])
