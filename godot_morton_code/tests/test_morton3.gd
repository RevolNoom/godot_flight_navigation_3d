extends GutTest

class_name Morton3Test

const MAX_21 = 0b111_111_111_111_111_111_111


class TernaryIntCase:
	extends RefCounted

	var x: int
	var y: int
	var z: int
	var expected: int

	func _init(x_value: int, y_value: int, z_value: int, expected_value: int) -> void:
		x = x_value
		y = y_value
		z = z_value
		expected = expected_value


class Vector3iEncodeCase:
	extends RefCounted

	var input: Vector3i
	var expected: int

	func _init(input_value: Vector3i, expected_value: int) -> void:
		input = input_value
		expected = expected_value


class Vector3DecodeCase:
	extends RefCounted

	var code: int
	var expected: Vector3

	func _init(code_value: int, expected_value: Vector3) -> void:
		code = code_value
		expected = expected_value


class Vector3iDecodeCase:
	extends RefCounted

	var code: int
	var expected: Vector3i

	func _init(code_value: int, expected_value: Vector3i) -> void:
		code = code_value
		expected = expected_value


class BinaryIntCase:
	extends RefCounted

	var lhs: int
	var rhs: int
	var expected: int

	func _init(lhs_value: int, rhs_value: int, expected_value: int) -> void:
		lhs = lhs_value
		rhs = rhs_value
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


func _assert_ternary_int_result_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: TernaryIntCase = case_data_value
		var result: int = operation.call(case_data.x, case_data.y, case_data.z)
		assert_eq(result, case_data.expected)


func _assert_vector3i_encode_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: Vector3iEncodeCase = case_data_value
		var result: int = operation.call(case_data.input)
		assert_eq(result, case_data.expected)


func _assert_vector3_decode_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: Vector3DecodeCase = case_data_value
		var result: Vector3 = operation.call(case_data.code)
		assert_eq(result, case_data.expected)


func _assert_vector3i_decode_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: Vector3iDecodeCase = case_data_value
		var result: Vector3i = operation.call(case_data.code)
		assert_eq(result, case_data.expected)


func _assert_binary_int_result_cases(cases: Array, operation: Callable) -> void:
	for case_data_value in cases:
		var case_data: BinaryIntCase = case_data_value
		var result: int = operation.call(case_data.lhs, case_data.rhs)
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
		TernaryIntCase.new(0b0, 0b0, 0b0, 0b0),
		TernaryIntCase.new(MAX_21, 0b0, 0b0, Morton3.MASK_X),
		TernaryIntCase.new(0b0, MAX_21, 0b0, Morton3.MASK_Y),
		TernaryIntCase.new(0b0, 0b0, MAX_21, Morton3.MASK_Z),
		TernaryIntCase.new(MAX_21, MAX_21, MAX_21, Morton3.MASK_XYZ),
		TernaryIntCase.new(0b1, 0b10, 0b11, 0b110_101),
	]

	_assert_ternary_int_result_cases(cases, Morton3.encode64)


func test_encode64v() -> void:
	var cases: Array = [
		Vector3iEncodeCase.new(Vector3i(0, 0, 0), 0b0),
		Vector3iEncodeCase.new(Vector3i(MAX_21, 0, 0), Morton3.MASK_X),
		Vector3iEncodeCase.new(Vector3i(0, MAX_21, 0), Morton3.MASK_Y),
		Vector3iEncodeCase.new(Vector3i(0, 0, MAX_21), Morton3.MASK_Z),
		Vector3iEncodeCase.new(Vector3i(MAX_21, MAX_21, MAX_21), Morton3.MASK_XYZ),
		Vector3iEncodeCase.new(Vector3i(0b1, 0b10, 0b11), 0b110_101),
	]

	_assert_vector3i_encode_cases(cases, Morton3.encode64v)


func test_decode_vec3() -> void:
	var cases: Array = [
		Vector3DecodeCase.new(0b0, Vector3(0.0, 0.0, 0.0)),
		Vector3DecodeCase.new(Morton3.MASK_X, Vector3(MAX_21, 0.0, 0.0)),
		Vector3DecodeCase.new(Morton3.MASK_Y, Vector3(0.0, MAX_21, 0.0)),
		Vector3DecodeCase.new(Morton3.MASK_Z, Vector3(0.0, 0.0, MAX_21)),
		Vector3DecodeCase.new(Morton3.MASK_XYZ, Vector3(MAX_21, MAX_21, MAX_21)),
		Vector3DecodeCase.new(0b110_101, Vector3(0b1, 0b10, 0b11)),
	]

	_assert_vector3_decode_cases(cases, Morton3.decode_vec3)


func test_decode_vec3i() -> void:
	var cases: Array = [
		Vector3iDecodeCase.new(0b0, Vector3i(0, 0, 0)),
		Vector3iDecodeCase.new(Morton3.MASK_X, Vector3i(MAX_21, 0, 0)),
		Vector3iDecodeCase.new(Morton3.MASK_Y, Vector3i(0, MAX_21, 0)),
		Vector3iDecodeCase.new(Morton3.MASK_Z, Vector3i(0, 0, MAX_21)),
		Vector3iDecodeCase.new(Morton3.MASK_XYZ, Vector3i(MAX_21, MAX_21, MAX_21)),
		Vector3iDecodeCase.new(0b110_101, Vector3i(0b1, 0b10, 0b11)),
	]

	_assert_vector3i_decode_cases(cases, Morton3.decode_vec3i)


func test_set_x() -> void:
	var cases: Array = [
		CodeIntCase.new(0b0, MAX_21, Morton3.MASK_X),
		CodeIntCase.new(Morton3.MASK_XYZ, 0b0, Morton3.MASK_Y | Morton3.MASK_Z),
	]

	_assert_code_int_result_cases(cases, Morton3.set_x)


func test_set_y() -> void:
	var cases: Array = [
		CodeIntCase.new(0b0, MAX_21, Morton3.MASK_Y),
		CodeIntCase.new(Morton3.MASK_XYZ, 0b0, Morton3.MASK_X | Morton3.MASK_Z),
	]

	_assert_code_int_result_cases(cases, Morton3.set_y)


func test_set_z() -> void:
	var cases: Array = [
		CodeIntCase.new(0b0, MAX_21, Morton3.MASK_Z),
		CodeIntCase.new(Morton3.MASK_XYZ, 0b0, Morton3.MASK_X | Morton3.MASK_Y),
	]

	_assert_code_int_result_cases(cases, Morton3.set_z)


func test_add() -> void:
	var cases: Array = [
		BinaryIntCase.new(0b110_101, 0b001_110, 0b100_011_011),
		BinaryIntCase.new(Morton3.MASK_XYZ, 0b001, Morton3.MASK_Y | Morton3.MASK_Z),
	]

	_assert_binary_int_result_cases(cases, Morton3.add)


func test_sub() -> void:
	var cases: Array = [
		BinaryIntCase.new(0b100_011_011, 0b110_101, 0b001_110),
		BinaryIntCase.new(0b0, 0b001, Morton3.MASK_X),
	]

	_assert_binary_int_result_cases(cases, Morton3.sub)


func test_add_x() -> void:
	var cases: Array = [
		CodeIntCase.new(0b110_101, 1, 0b111_100),
		CodeIntCase.new(0b110_101, -1, 0b110_100),
		CodeIntCase.new(Morton3.MASK_X, 1, 0b0),
	]

	_assert_code_int_result_cases(cases, Morton3.add_x)


func test_add_y() -> void:
	var cases: Array = [
		CodeIntCase.new(0b110_101, 1, 0b110_111),
		CodeIntCase.new(0b110_101, -2, 0b100_101),
		CodeIntCase.new(Morton3.MASK_Y, 1, 0b0),
	]

	_assert_code_int_result_cases(cases, Morton3.add_y)


func test_add_z() -> void:
	var cases: Array = [
		CodeIntCase.new(0b110_101, 1, 0b100_010_001),
		CodeIntCase.new(0b110_101, -1, 0b110_001),
		CodeIntCase.new(Morton3.MASK_Z, 1, 0b0),
	]

	_assert_code_int_result_cases(cases, Morton3.add_z)


func test_sub_x() -> void:
	var cases: Array = [
		CodeIntCase.new(0b110_101, 1, 0b110_100),
		CodeIntCase.new(0b110_101, -1, 0b111_100),
		CodeIntCase.new(0b0, 1, Morton3.MASK_X),
	]

	_assert_code_int_result_cases(cases, Morton3.sub_x)


func test_sub_y() -> void:
	var cases: Array = [
		CodeIntCase.new(0b110_101, 1, 0b100_111),
		CodeIntCase.new(0b110_101, -2, 0b010_100_101),
		CodeIntCase.new(0b0, 1, Morton3.MASK_Y),
	]

	_assert_code_int_result_cases(cases, Morton3.sub_y)


func test_sub_z() -> void:
	var cases: Array = [
		CodeIntCase.new(0b110_101, 1, 0b110_001),
		CodeIntCase.new(0b110_101, -1, 0b100_010_001),
		CodeIntCase.new(0b0, 1, Morton3.MASK_Z),
	]

	_assert_code_int_result_cases(cases, Morton3.sub_z)


func test_inc_x() -> void:
	var cases: Array = [
		UnaryIntCase.new(0b110_101, 0b111_100),
		UnaryIntCase.new(Morton3.MASK_X, 0b0),
	]

	_assert_unary_int_result_cases(cases, Morton3.inc_x)


func test_inc_y() -> void:
	var cases: Array = [
		UnaryIntCase.new(0b110_101, 0b110_111),
		UnaryIntCase.new(Morton3.MASK_Y, 0b0),
	]

	_assert_unary_int_result_cases(cases, Morton3.inc_y)


func test_inc_z() -> void:
	var cases: Array = [
		UnaryIntCase.new(0b110_101, 0b100_010_001),
		UnaryIntCase.new(Morton3.MASK_Z, 0b0),
	]

	_assert_unary_int_result_cases(cases, Morton3.inc_z)


func test_dec_x() -> void:
	var cases: Array = [
		UnaryIntCase.new(0b110_101, 0b110_100),
		UnaryIntCase.new(0b0, Morton3.MASK_X),
	]

	_assert_unary_int_result_cases(cases, Morton3.dec_x)


func test_dec_y() -> void:
	var cases: Array = [
		UnaryIntCase.new(0b110_101, 0b100_111),
		UnaryIntCase.new(0b0, Morton3.MASK_Y),
	]

	_assert_unary_int_result_cases(cases, Morton3.dec_y)


func test_dec_z() -> void:
	var cases: Array = [
		UnaryIntCase.new(0b110_101, 0b110_001),
		UnaryIntCase.new(0b0, Morton3.MASK_Z),
	]

	_assert_unary_int_result_cases(cases, Morton3.dec_z)


func test_gt() -> void:
	var cases: Array = [
		ComparisonCase.new(0b111_111, 0b111_000, true),
		ComparisonCase.new(0b101_000_010, 0b111_111, false),
		ComparisonCase.new(0b111_011, 0b111_011, false),
	]

	_assert_comparison_cases(cases, Morton3.gt)


func test_ge() -> void:
	var cases: Array = [
		ComparisonCase.new(0b111_111, 0b111_000, true),
		ComparisonCase.new(0b101_000_010, 0b111_111, false),
		ComparisonCase.new(0b111_011, 0b111_011, true),
	]

	_assert_comparison_cases(cases, Morton3.ge)


func test_lt() -> void:
	var cases: Array = [
		ComparisonCase.new(0b111_000, 0b111_111, true),
		ComparisonCase.new(0b101_000_010, 0b111_111, false),
		ComparisonCase.new(0b111_011, 0b111_011, false),
	]

	_assert_comparison_cases(cases, Morton3.lt)


func test_le() -> void:
	var cases: Array = [
		ComparisonCase.new(0b111_000, 0b111_111, true),
		ComparisonCase.new(0b101_000_010, 0b111_111, false),
		ComparisonCase.new(0b111_011, 0b111_011, true),
	]

	_assert_comparison_cases(cases, Morton3.le)
