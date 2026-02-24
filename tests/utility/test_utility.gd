extends GutTest

class_name Fn3dUtilityTest


func test_sum_number_array():
	var input_int: PackedInt64Array = [2, 4, 6, 8]
	var expected_int = 20
	var result_int = Fn3dUtility.sum_number_array(input_int)
	assert_eq(result_int, expected_int)

	var input_float: PackedFloat64Array = [1.5, 2.25, 3.25]
	var expected_float = 7.0
	var result_float = Fn3dUtility.sum_number_array(input_float)
	assert_eq(result_float, expected_float)


func test_count_unique_element_on_sorted_array():
	var empty_input: Array[int] = []
	var expected_empty = 0
	var result_empty = \
		Fn3dUtility.count_unique_element_on_sorted_array(
			empty_input)
	assert_eq(result_empty, expected_empty)

	var one_element_input: Array[int] = [5]
	var expected_one_element = 1
	var result_one_element = \
		Fn3dUtility.count_unique_element_on_sorted_array(
			one_element_input)
	assert_eq(result_one_element, expected_one_element)

	var input: Array[int] = [1, 1, 2, 2, 2, 4, 7, 7]
	var expected = 4
	var result = \
		Fn3dUtility.count_unique_element_on_sorted_array(
			input)
	assert_eq(result, expected)


func test_make_unique_from_sorted_array():
	var empty_input: Array[int] = []
	var expected_empty: Array[int] = []
	var result_empty = \
		Fn3dUtility.make_unique_from_sorted_array(
			empty_input)
	assert_eq(result_empty, expected_empty)

	var one_element_input: Array[int] = [9]
	var expected_one_element: Array[int] = [9]
	var result_one_element = \
		Fn3dUtility.make_unique_from_sorted_array(
			one_element_input)
	assert_eq(result_one_element, expected_one_element)

	var input: Array[int] = [1, 1, 2, 2, 2, 4, 7, 7]
	var expected: Array[int] = [1, 2, 4, 7]
	var result = \
		Fn3dUtility.make_unique_from_sorted_array(
			input)
	assert_eq(result, expected)
	assert_eq(input, [1, 1, 2, 2, 2, 4, 7, 7])


func test_count_unique_element_appearance():
	var empty_input: Array[int] = []
	var expected_empty: PackedInt64Array = []
	var result_empty = \
		Fn3dUtility.count_unique_element_appearance(
			empty_input)
	assert_eq(result_empty, expected_empty)

	var one_element_input: Array[int] = [5]
	var expected_one_element: PackedInt64Array = [1]
	var result_one_element = \
		Fn3dUtility.count_unique_element_appearance(
			one_element_input)
	assert_eq(result_one_element, expected_one_element)

	var input: Array[int] = [1, 1, 2, 2, 2, 4, 7, 7]
	var expected: PackedInt64Array = [2, 3, 1, 2]
	var result = \
		Fn3dUtility.count_unique_element_appearance(
			input)
	assert_eq(result, expected)


func test_filter_in_place():
	var input: Array[int] = [10, 11, 12, 13, 14, 15]
	var expected: Array[int] = [10, 12, 14]
	Fn3dUtility.filter_in_place(
		input,
		func(_element: int, index: int) -> bool:
			return index % 2 == 0
	)
	assert_eq(input, expected)

