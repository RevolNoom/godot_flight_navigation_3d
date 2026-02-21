extends GutTest

class_name Morton3Test

const MAX_21 = 0b111_111_111_111_111_111_111


func test_encode64():
	var cases = [
		{ "x": 0b0, "y": 0b0, "z": 0b0, "expected": 0b0 },
		{ "x": MAX_21, "y": 0b0, "z": 0b0, "expected": Morton3.MASK_X },
		{ "x": 0b0, "y": MAX_21, "z": 0b0, "expected": Morton3.MASK_Y },
		{ "x": 0b0, "y": 0b0, "z": MAX_21, "expected": Morton3.MASK_Z },
		{
			"x": MAX_21,
			"y": MAX_21,
			"z": MAX_21,
			"expected": Morton3.MASK_XYZ,
		},
		{ "x": 0b1, "y": 0b10, "z": 0b11, "expected": 0b110_101 },
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.encode64(tc["x"], tc["y"], tc["z"])
		assert_eq(result, tc["expected"])


func test_encode64v():
	var cases = [
		{
			"input": Vector3i(0b0, 0b0, 0b0),
			"expected": 0b0,
		},
		{
			"input": Vector3i(MAX_21, 0b0, 0b0),
			"expected": Morton3.MASK_X,
		},
		{
			"input": Vector3i(0b0, MAX_21, 0b0),
			"expected": Morton3.MASK_Y,
		},
		{
			"input": Vector3i(0b0, 0b0, MAX_21),
			"expected": Morton3.MASK_Z,
		},
		{
			"input": Vector3i(MAX_21, MAX_21, MAX_21),
			"expected": Morton3.MASK_XYZ,
		},
		{
			"input": Vector3i(0b1, 0b10, 0b11),
			"expected": 0b110_101,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.encode64v(tc["input"])
		assert_eq(result, tc["expected"])


func test_decode_vec3():
	var cases = [
		{
			"code": 0b0,
			"expected": Vector3(0.0, 0.0, 0.0),
		},
		{
			"code": Morton3.MASK_X,
			"expected": Vector3(MAX_21, 0.0, 0.0),
		},
		{
			"code": Morton3.MASK_Y,
			"expected": Vector3(0.0, MAX_21, 0.0),
		},
		{
			"code": Morton3.MASK_Z,
			"expected": Vector3(0.0, 0.0, MAX_21),
		},
		{
			"code": Morton3.MASK_XYZ,
			"expected": Vector3(MAX_21, MAX_21, MAX_21),
		},
		{
			"code": 0b110_101,
			"expected": Vector3(0b1, 0b10, 0b11),
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.decode_vec3(tc["code"])
		assert_eq(result, tc["expected"])


func test_decode_vec3i():
	var cases = [
		{
			"code": 0b0,
			"expected": Vector3i(0, 0, 0),
		},
		{
			"code": Morton3.MASK_X,
			"expected": Vector3i(MAX_21, 0, 0),
		},
		{
			"code": Morton3.MASK_Y,
			"expected": Vector3i(0, MAX_21, 0),
		},
		{
			"code": Morton3.MASK_Z,
			"expected": Vector3i(0, 0, MAX_21),
		},
		{
			"code": Morton3.MASK_XYZ,
			"expected": Vector3i(MAX_21, MAX_21, MAX_21),
		},
		{
			"code": 0b110_101,
			"expected": Vector3i(0b1, 0b10, 0b11),
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.decode_vec3i(tc["code"])
		assert_eq(result, tc["expected"])


func test_set_x():
	var cases = [
		{
			"code": 0b0,
			"new_x": MAX_21,
			"expected": Morton3.MASK_X,
		},
		{
			"code": Morton3.MASK_XYZ,
			"new_x": 0b0,
			"expected": Morton3.MASK_Y | Morton3.MASK_Z,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.set_x(tc["code"], tc["new_x"])
		assert_eq(result, tc["expected"])


func test_set_y():
	var cases = [
		{
			"code": 0b0,
			"new_y": MAX_21,
			"expected": Morton3.MASK_Y,
		},
		{
			"code": Morton3.MASK_XYZ,
			"new_y": 0b0,
			"expected": Morton3.MASK_X | Morton3.MASK_Z,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.set_y(tc["code"], tc["new_y"])
		assert_eq(result, tc["expected"])


func test_set_z():
	var cases = [
		{
			"code": 0b0,
			"new_z": MAX_21,
			"expected": Morton3.MASK_Z,
		},
		{
			"code": Morton3.MASK_XYZ,
			"new_z": 0b0,
			"expected": Morton3.MASK_X | Morton3.MASK_Y,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.set_z(tc["code"], tc["new_z"])
		assert_eq(result, tc["expected"])


func test_add():
	var cases = [
		{
			"lhs": 0b110_101,
			"rhs": 0b001_110,
			"expected": 0b100_011_011,
		},
		{
			"lhs": Morton3.MASK_XYZ,
			"rhs": 0b001,
			"expected": Morton3.MASK_Y | Morton3.MASK_Z,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.add(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])


func test_sub():
	var cases = [
		{
			"lhs": 0b100_011_011,
			"rhs": 0b110_101,
			"expected": 0b001_110,
		},
		{
			"lhs": 0b0,
			"rhs": 0b001,
			"expected": Morton3.MASK_X,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.sub(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])


func test_add_x():
	var cases = [
		{
			"code": 0b110_101,
			"x": 1,
			"expected": 0b111_100,
		},
		{
			"code": 0b110_101,
			"x": -1,
			"expected": 0b110_100,
		},
		{
			"code": Morton3.MASK_X,
			"x": 1,
			"expected": 0b0,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.add_x(tc["code"], tc["x"])
		assert_eq(result, tc["expected"])


func test_add_y():
	var cases = [
		{
			"code": 0b110_101,
			"y": 1,
			"expected": 0b110_111,
		},
		{
			"code": 0b110_101,
			"y": -2,
			"expected": 0b100_101,
		},
		{
			"code": Morton3.MASK_Y,
			"y": 1,
			"expected": 0b0,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.add_y(tc["code"], tc["y"])
		assert_eq(result, tc["expected"])


func test_add_z():
	var cases = [
		{
			"code": 0b110_101,
			"z": 1,
			"expected": 0b100_010_001,
		},
		{
			"code": 0b110_101,
			"z": -1,
			"expected": 0b110_001,
		},
		{
			"code": Morton3.MASK_Z,
			"z": 1,
			"expected": 0b0,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.add_z(tc["code"], tc["z"])
		assert_eq(result, tc["expected"])


func test_sub_x():
	var cases = [
		{
			"code": 0b110_101,
			"x": 1,
			"expected": 0b110_100,
		},
		{
			"code": 0b110_101,
			"x": -1,
			"expected": 0b111_100,
		},
		{
			"code": 0b0,
			"x": 1,
			"expected": Morton3.MASK_X,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.sub_x(tc["code"], tc["x"])
		assert_eq(result, tc["expected"])


func test_sub_y():
	var cases = [
		{
			"code": 0b110_101,
			"y": 1,
			"expected": 0b100_111,
		},
		{
			"code": 0b110_101,
			"y": -2,
			"expected": 0b010_100_101,
		},
		{
			"code": 0b0,
			"y": 1,
			"expected": Morton3.MASK_Y,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.sub_y(tc["code"], tc["y"])
		assert_eq(result, tc["expected"])


func test_sub_z():
	var cases = [
		{
			"code": 0b110_101,
			"z": 1,
			"expected": 0b110_001,
		},
		{
			"code": 0b110_101,
			"z": -1,
			"expected": 0b100_010_001,
		},
		{
			"code": 0b0,
			"z": 1,
			"expected": Morton3.MASK_Z,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.sub_z(tc["code"], tc["z"])
		assert_eq(result, tc["expected"])


func test_inc_x():
	var cases = [
		{
			"code": 0b110_101,
			"expected": 0b111_100,
		},
		{
			"code": Morton3.MASK_X,
			"expected": 0b0,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.inc_x(tc["code"])
		assert_eq(result, tc["expected"])


func test_inc_y():
	var cases = [
		{
			"code": 0b110_101,
			"expected": 0b110_111,
		},
		{
			"code": Morton3.MASK_Y,
			"expected": 0b0,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.inc_y(tc["code"])
		assert_eq(result, tc["expected"])


func test_inc_z():
	var cases = [
		{
			"code": 0b110_101,
			"expected": 0b100_010_001,
		},
		{
			"code": Morton3.MASK_Z,
			"expected": 0b0,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.inc_z(tc["code"])
		assert_eq(result, tc["expected"])


func test_dec_x():
	var cases = [
		{
			"code": 0b110_101,
			"expected": 0b110_100,
		},
		{
			"code": 0b0,
			"expected": Morton3.MASK_X,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.dec_x(tc["code"])
		assert_eq(result, tc["expected"])


func test_dec_y():
	var cases = [
		{
			"code": 0b110_101,
			"expected": 0b100_111,
		},
		{
			"code": 0b0,
			"expected": Morton3.MASK_Y,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.dec_y(tc["code"])
		assert_eq(result, tc["expected"])


func test_dec_z():
	var cases = [
		{
			"code": 0b110_101,
			"expected": 0b110_001,
		},
		{
			"code": 0b0,
			"expected": Morton3.MASK_Z,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.dec_z(tc["code"])
		assert_eq(result, tc["expected"])


func test_gt():
	var cases = [
		{
			"lhs": 0b111_111,
			"rhs": 0b111_000,
			"expected": true,
		},
		{
			"lhs": 0b101_000_010,
			"rhs": 0b111_111,
			"expected": false,
		},
		{
			"lhs": 0b111_011,
			"rhs": 0b111_011,
			"expected": false,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.gt(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])


func test_ge():
	var cases = [
		{
			"lhs": 0b111_111,
			"rhs": 0b111_000,
			"expected": true,
		},
		{
			"lhs": 0b101_000_010,
			"rhs": 0b111_111,
			"expected": false,
		},
		{
			"lhs": 0b111_011,
			"rhs": 0b111_011,
			"expected": true,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.ge(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])


func test_lt():
	var cases = [
		{
			"lhs": 0b111_000,
			"rhs": 0b111_111,
			"expected": true,
		},
		{
			"lhs": 0b101_000_010,
			"rhs": 0b111_111,
			"expected": false,
		},
		{
			"lhs": 0b111_011,
			"rhs": 0b111_011,
			"expected": false,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.lt(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])


func test_le():
	var cases = [
		{
			"lhs": 0b111_000,
			"rhs": 0b111_111,
			"expected": true,
		},
		{
			"lhs": 0b101_000_010,
			"rhs": 0b111_111,
			"expected": false,
		},
		{
			"lhs": 0b111_011,
			"rhs": 0b111_011,
			"expected": true,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton3.le(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])
