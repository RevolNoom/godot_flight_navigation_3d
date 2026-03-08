extends GutTest

class_name MortonTest


class IntToBinCase:
	extends RefCounted

	var input: int
	var expected: String

	func _init(input_value: int, expected_value: String) -> void:
		input = input_value
		expected = expected_value


func _assert_int_to_bin_cases(cases: Array) -> void:
	for case_data_value in cases:
		var case_data: IntToBinCase = case_data_value
		var result: String = Morton.int_to_bin(case_data.input)
		assert_eq(result, case_data.expected)


func test_int_to_bin() -> void:
	var cases: Array = [
		IntToBinCase.new(0, "0000000000000000000000000000000000000000000000000000000000000000"),
		IntToBinCase.new(1, "0000000000000000000000000000000000000000000000000000000000000001"),
		IntToBinCase.new(2, "0000000000000000000000000000000000000000000000000000000000000010"),
		IntToBinCase.new(
			0x0123_4567_89AB_CDEF,
			"0000000100100011010001010110011110001001101010111100110111101111"
		),
		IntToBinCase.new(
			9223372036854775807,
			"0111111111111111111111111111111111111111111111111111111111111111"
		),
		IntToBinCase.new(
			-9223372036854775808,
			"1000000000000000000000000000000000000000000000000000000000000000"
		),
		IntToBinCase.new(
			-1,
			"1111111111111111111111111111111111111111111111111111111111111111"
		),
	]

	_assert_int_to_bin_cases(cases)
