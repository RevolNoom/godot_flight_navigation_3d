extends GutTest

class_name Morton2Test

class BinaryIntCase:
	extends RefCounted

	var lhs: int
	var rhs: int
	var expected: int

	func _init(lhs_value: int, rhs_value: int, expected_value: int) -> void:
		lhs = lhs_value
		rhs = rhs_value
		expected = expected_value


class Vector2iEncodeCase:
	extends RefCounted

	var input: Vector2i
	var expected: int

	func _init(input_value: Vector2i, expected_value: int) -> void:
		input = input_value
		expected = expected_value


class Vector2DecodeCase:
	extends RefCounted

	var code: int
	var expected: Vector2

	func _init(code_value: int, expected_value: Vector2) -> void:
		code = code_value
		expected = expected_value


class Vector2iDecodeCase:
	extends RefCounted

	var code: int
	var expected: Vector2i

	func _init(code_value: int, expected_value: Vector2i) -> void:
		code = code_value
		expected = expected_value


class CodeIntCase:
	extends RefCounted

	var code: int
	var value: int
	var expected: int

	func _init(code_value: int, case_value: int, expected_value: int) -> void:
		code = code_value
		value = case_value
		expected = expected_value


class UnaryIntCase:
	extends RefCounted

	var code: int
	var expected: int

	func _init(code_value: int, expected_value: int) -> void:
		code = code_value
		expected = expected_value


class ComparisonCase:
	extends RefCounted

	var lhs: int
	var rhs: int
	var expected: bool

	func _init(lhs_value: int, rhs_value: int, expected_value: bool) -> void:
		lhs = lhs_value
		rhs = rhs_value
		expected = expected_value


func _assert_binary_int_result_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: BinaryIntCase = case_data_value
		var result: int = operation.call(case_data.lhs, case_data.rhs)
		assert_eq(result, case_data.expected)


func _assert_vector2i_encode_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: Vector2iEncodeCase = case_data_value
		var result: int = operation.call(case_data.input)
		assert_eq(result, case_data.expected)


func _assert_vector2_decode_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: Vector2DecodeCase = case_data_value
		var result: Vector2 = operation.call(case_data.code)
		assert_eq(result, case_data.expected)


func _assert_vector2i_decode_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: Vector2iDecodeCase = case_data_value
		var result: Vector2i = operation.call(case_data.code)
		assert_eq(result, case_data.expected)


func _assert_code_int_result_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: CodeIntCase = case_data_value
		var result: int = operation.call(case_data.code, case_data.value)
		assert_eq(result, case_data.expected)


func _assert_unary_int_result_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: UnaryIntCase = case_data_value
		var result: int = operation.call(case_data.code)
		assert_eq(result, case_data.expected)


func _assert_comparison_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: ComparisonCase = case_data_value
		var result: bool = operation.call(case_data.lhs, case_data.rhs)
		assert_eq(result, case_data.expected)


func test_encode64() -> void:
	var cases: Array = [
		BinaryIntCase.new(0b0, 0b0, 0b0),
		BinaryIntCase.new(
			0b1111_1111_1111_1111_1111_1111_1111_1111,
			0b0,
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
		BinaryIntCase.new(
			0b0,
			0b1111_1111_1111_1111_1111_1111_1111_1111,
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
		BinaryIntCase.new(
			0b1111_1111_1111_1111_1111_1111_1111_1111,
			0b1111_1111_1111_1111_1111_1111_1111_1111,
			~0b0
		),
	]

	_assert_binary_int_result_cases(cases, Morton2.encode64)


func test_encode64v() -> void:
	var cases: Array = [
		Vector2iEncodeCase.new(Vector2i(0, 0), 0b0),
		Vector2iEncodeCase.new(
			Vector2i(0b1111_1111_1111_1111_1111_1111_1111_1111, 0b0),
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
		Vector2iEncodeCase.new(
			Vector2i(0b0, 0b1111_1111_1111_1111_1111_1111_1111_1111),
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
		Vector2iEncodeCase.new(
			Vector2i(
				0b1111_1111_1111_1111_1111_1111_1111_1111,
				0b1111_1111_1111_1111_1111_1111_1111_1111
			),
			~0b0
		),
	]

	_assert_vector2i_encode_cases(cases, Morton2.encode64v)


func test_decode_vec2() -> void:
	var cases: Array = [
		Vector2DecodeCase.new(0b0, Vector2(0.0, 0.0)),
		Vector2DecodeCase.new(
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			Vector2(0b1111_1111_1111_1111_1111_1111_1111_1111, 0b0)
		),
		Vector2DecodeCase.new(
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			Vector2(0b0, 0b1111_1111_1111_1111_1111_1111_1111_1111)
		),
		Vector2DecodeCase.new(
			~0b0,
			Vector2(
				0b1111_1111_1111_1111_1111_1111_1111_1111,
				0b1111_1111_1111_1111_1111_1111_1111_1111
			)
		),
	]

	_assert_vector2_decode_cases(cases, Morton2.decode_vec2)


func test_decode_vec2i() -> void:
	var cases: Array = [
		Vector2iDecodeCase.new(0b0, Vector2i(0, 0)),
		Vector2iDecodeCase.new(
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			Vector2i(0b1111_1111_1111_1111_1111_1111_1111_1111, 0b0)
		),
		Vector2iDecodeCase.new(
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			Vector2i(0b0, 0b1111_1111_1111_1111_1111_1111_1111_1111)
		),
		Vector2iDecodeCase.new(
			~0b0,
			Vector2i(
				0b1111_1111_1111_1111_1111_1111_1111_1111,
				0b1111_1111_1111_1111_1111_1111_1111_1111
			)
		),
	]

	_assert_vector2i_decode_cases(cases, Morton2.decode_vec2i)


func test_set_x() -> void:
	var cases: Array = [
		CodeIntCase.new(
			0b0,
			4294967295,
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
		CodeIntCase.new(
			~0b0,
			0,
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
	]

	_assert_code_int_result_cases(cases, Morton2.set_x)


func test_set_y() -> void:
	var cases: Array = [
		CodeIntCase.new(
			0b0,
			4294967295,
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
		CodeIntCase.new(
			~0b0,
			0,
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
	]

	_assert_code_int_result_cases(cases, Morton2.set_y)


func test_add() -> void:
	var cases: Array = [
		BinaryIntCase.new(0b1110, 0b10111, 0b1100001),
		BinaryIntCase.new(0b1110, 0b11, 0b100101),
		BinaryIntCase.new(
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			0b10,
			0b0
		),
		BinaryIntCase.new(
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			0b1,
			0b0
		),
	]

	_assert_binary_int_result_cases(cases, Morton2.add)


func test_sub() -> void:
	var cases: Array = [
		BinaryIntCase.new(0b1100001, 0b1110, 0b10111),
		BinaryIntCase.new(0b100101, 0b1110, 0b11),
		BinaryIntCase.new(
			0b0,
			0b10,
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
		BinaryIntCase.new(
			0b0,
			0b1,
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
	]

	_assert_binary_int_result_cases(cases, Morton2.sub)


func test_add_x() -> void:
	var cases: Array = [
		CodeIntCase.new(0b10111, 1, 0b1000010),
		CodeIntCase.new(0b10111, -1, 0b10110),
		CodeIntCase.new(
			0b0,
			-1,
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
		CodeIntCase.new(
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			1,
			0b0
		),
	]

	_assert_code_int_result_cases(cases, Morton2.add_x)


func test_add_y() -> void:
	var cases: Array = [
		CodeIntCase.new(0b10111, 1, 0b11101),
		CodeIntCase.new(0b10111, -1, 0b10101),
		CodeIntCase.new(
			0b0,
			-1,
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
		CodeIntCase.new(
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			1,
			0b0
		),
	]

	_assert_code_int_result_cases(cases, Morton2.add_y)


func test_sub_x() -> void:
	var cases: Array = [
		CodeIntCase.new(0b10111, 1, 0b10110),
		CodeIntCase.new(0b10111, -1, 0b1000010),
		CodeIntCase.new(
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			-1,
			0b0
		),
		CodeIntCase.new(
			0b0,
			1,
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
	]

	_assert_code_int_result_cases(cases, Morton2.sub_x)


func test_sub_y() -> void:
	var cases: Array = [
		CodeIntCase.new(0b10111, 1, 0b10101),
		CodeIntCase.new(0b10111, -1, 0b11101),
		CodeIntCase.new(
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			-1,
			0b0
		),
		CodeIntCase.new(
			0b0,
			1,
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
	]

	_assert_code_int_result_cases(cases, Morton2.sub_y)


func test_inc_x() -> void:
	var cases: Array = [
		UnaryIntCase.new(0b10111, 0b1000010),
		UnaryIntCase.new(
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			0b0
		),
	]

	_assert_unary_int_result_cases(cases, Morton2.inc_x)


func test_inc_y() -> void:
	var cases: Array = [
		UnaryIntCase.new(0b10111, 0b11101),
		UnaryIntCase.new(0b1110, 0b100100),
		UnaryIntCase.new(
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			0b0
		),
	]

	_assert_unary_int_result_cases(cases, Morton2.inc_y)


func test_dec_x() -> void:
	var cases: Array = [
		UnaryIntCase.new(0b10111, 0b10110),
		UnaryIntCase.new(
			0b0,
			0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
	]

	_assert_unary_int_result_cases(cases, Morton2.dec_x)


func test_dec_y() -> void:
	var cases: Array = [
		UnaryIntCase.new(0b10111, 0b10101),
		UnaryIntCase.new(
			0b0,
			~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101
		),
	]

	_assert_unary_int_result_cases(cases, Morton2.dec_y)


func test_gt() -> void:
	var cases: Array = [
		ComparisonCase.new(0b1100001, 0b1110, true),
		ComparisonCase.new(0b1000010, 0b11101, false),
		ComparisonCase.new(0b100101, 0b100101, false),
	]

	_assert_comparison_cases(cases, Morton2.gt)


func test_ge() -> void:
	var cases: Array = [
		ComparisonCase.new(0b1100001, 0b1110, true),
		ComparisonCase.new(0b1000010, 0b11101, false),
		ComparisonCase.new(0b100101, 0b100101, true),
	]

	_assert_comparison_cases(cases, Morton2.ge)


func test_lt() -> void:
	var cases: Array = [
		ComparisonCase.new(0b10011, 0b11101, true),
		ComparisonCase.new(0b1000010, 0b11101, false),
		ComparisonCase.new(0b100101, 0b100101, false),
	]

	_assert_comparison_cases(cases, Morton2.lt)


func test_le() -> void:
	var cases: Array = [
		ComparisonCase.new(0b10011, 0b11101, true),
		ComparisonCase.new(0b1000010, 0b11101, false),
		ComparisonCase.new(0b100101, 0b100101, true),
	]

	_assert_comparison_cases(cases, Morton2.le)
