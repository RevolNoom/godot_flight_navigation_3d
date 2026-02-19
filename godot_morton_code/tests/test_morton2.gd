extends GutTest
class_name Morton2Test


func test_encode64():
	var cases = [
		{"x": 0b0, "y": 0b0, "expected": 0b0},
		{
			"x": 0b1111_1111_1111_1111_1111_1111_1111_1111,
			"y": 0b0,
			"expected":
				0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
		},
		{
			"x": 0b0,
			"y": 0b1111_1111_1111_1111_1111_1111_1111_1111,
			"expected":
				~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
		},
		{
			"x": 0b1111_1111_1111_1111_1111_1111_1111_1111,
			"y": 0b1111_1111_1111_1111_1111_1111_1111_1111,
			"expected": ~0b0,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.encode64(tc["x"], tc["y"])
		assert_eq(result, tc["expected"])


func test_encode64v():
	var cases = [
		{"input": Vector2i(0b0, 0b0), "expected": 0b0},
		{
			"input": Vector2i(
				0b1111_1111_1111_1111_1111_1111_1111_1111,
				0b0
			),
			"expected":
				0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
		},
		{
			"input": Vector2i(
				0b0,
				0b1111_1111_1111_1111_1111_1111_1111_1111
			),
			"expected":
				~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
		},
		{
			"input": Vector2i(
				0b1111_1111_1111_1111_1111_1111_1111_1111,
				0b1111_1111_1111_1111_1111_1111_1111_1111
			),
			"expected":
				~0b0,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.encode64v(tc["input"])
		assert_eq(result, tc["expected"])


func test_decode_vec2():
	var cases = [
		{"code": 0b0, "expected": Vector2(0.0, 0.0)},
		{"code": 0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101, 
		"expected": Vector2(0b1111_1111_1111_1111_1111_1111_1111_1111, 0b0)},
		{"code": ~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101, 
		"expected": Vector2(0b0, 0b1111_1111_1111_1111_1111_1111_1111_1111)},
		{"code": ~0b0, "expected": Vector2(0b1111_1111_1111_1111_1111_1111_1111_1111, 0b1111_1111_1111_1111_1111_1111_1111_1111)},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.decode_vec2(tc["code"])
		assert_eq(result, tc["expected"])


func test_decode_vec2i():
	var cases = [
		{"code": 0b0, "expected": Vector2i(0.0, 0.0)},
		{"code": 0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101, 
		"expected": Vector2i(0b1111_1111_1111_1111_1111_1111_1111_1111, 0b0)},
		{"code": ~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101, 
		"expected": Vector2i(0b0, 0b1111_1111_1111_1111_1111_1111_1111_1111)},
		{"code": ~0b0, "expected": Vector2i(0b1111_1111_1111_1111_1111_1111_1111_1111, 0b1111_1111_1111_1111_1111_0000)},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.decode_vec2i(tc["code"])
		assert_eq(result, tc["expected"])


func test_raw_x():
	var cases = [
		{"code": 0b0, "expected": 0b0},
		{"code": 0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101, 
		"expected": 0b1111_1111_1111_1111_1111_1111_1111_1111},
		{"code": ~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101, "expected": 0b0},
		{"code": ~0b0, "expected": 0b1111_1111_1111_1111_1111_1111_1111_1111},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.raw_x(tc["code"])
		assert_eq(result, tc["expected"])


func test_raw_y():
	var cases = [
		{"code": 0b0, "expected": 0b0},
		{"code": ~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101, 
		"expected": 0b1111_1111_1111_1111_1111_1111_1111_1111},
		{"code": 0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101, "expected": 0b0},
		{"code": ~0b0, "expected": 0b1111_1111_1111_1111_1111_1111_1111_1111},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.raw_y(tc["code"])
		assert_eq(result, tc["expected"])


func test_set_x():
	var cases = [
		{"code": 0b0, 
		"new_x": 0b1111_1111_1111_1111_1111_1111_1111_1111, 
		"expected": 0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101},
		{"code": ~0b0, "new_x": 0b0, "expected": ~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.set_x(tc["code"], tc["new_x"])
		assert_eq(result, tc["expected"])


func test_set_y():
	var cases = [
		{"code": 0b0, 
		"new_y": 0b1111_1111_1111_1111_1111_1111_1111_1111, 
		"expected": ~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101},
		{"code": ~0b0, "new_y": 0b0, "expected": 0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101},
	]
	
	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.set_y(tc["code"], tc["new_y"])
		assert_eq(result, tc["expected"])


func test_add():
	var cases = [
		{"lhs": 0b1110, "rhs": 0b10111, "expected": 0b1100001},
		{"lhs": 0b1110, "rhs": 0b11, "expected": 0b100101},
		{
			"lhs":
				0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			"rhs": 0b1,
			"expected": 0b0,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.add(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])


func test_sub():
	var cases = [
		{"lhs": 0b1100001, "rhs": 0b1110, "expected": 0b10111},
		{"lhs": 0b100101, "rhs": 0b1110, "expected": 0b11},
		{
			"lhs": 0b0,
			"rhs": 0b1,
			"expected":
				0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.sub(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])


func test_inc_x():
	var cases = [
		{"code": 0b10111, "expected": 0b1000010},
		{
			"code":
				0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
			"expected": 0b0,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.inc_x(tc["code"])
		assert_eq(result, tc["expected"])


func test_inc_y():
	var cases = [
		{"code": 0b10111, "expected": 0b11101},
		{"code": 0b1110, "expected": 0b100100},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.inc_y(tc["code"])
		assert_eq(result, tc["expected"])


func test_dec_x():
	var cases = [
		{"code": 0b10111, "expected": 0b10110},
		{
			"code": 0b0,
			"expected":
				0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.dec_x(tc["code"])
		assert_eq(result, tc["expected"])


func test_dec_y():
	var cases = [
		{"code": 0b10111, "expected": 0b10101},
		{
			"code": 0b0,
			"expected":
				~0b0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101_0101,
		},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.dec_y(tc["code"])
		assert_eq(result, tc["expected"])


func test_gt():
	var cases = [
		{"lhs": 0b1100001, "rhs": 0b1110, "expected": true},
		{"lhs": 0b1000010, "rhs": 0b11101, "expected": false},
		{"lhs": 0b100101, "rhs": 0b100101, "expected": false},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.gt(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])


func test_ge():
	var cases = [
		{"lhs": 0b1100001, "rhs": 0b1110, "expected": true},
		{"lhs": 0b1000010, "rhs": 0b11101, "expected": false},
		{"lhs": 0b100101, "rhs": 0b100101, "expected": true},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.ge(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])


func test_lt():
	var cases = [
		{"lhs": 0b10011, "rhs": 0b11101, "expected": true},
		{"lhs": 0b1000010, "rhs": 0b11101, "expected": false},
		{"lhs": 0b100101, "rhs": 0b100101, "expected": false},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.lt(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])


func test_le():
	var cases = [
		{"lhs": 0b10011, "rhs": 0b11101, "expected": true},
		{"lhs": 0b1000010, "rhs": 0b11101, "expected": false},
		{"lhs": 0b100101, "rhs": 0b100101, "expected": true},
	]

	for i in range(cases.size()):
		var tc = cases[i]
		var result = Morton2.le(tc["lhs"], tc["rhs"])
		assert_eq(result, tc["expected"])
