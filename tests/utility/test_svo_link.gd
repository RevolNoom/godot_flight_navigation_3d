extends GutTest

class_name SVOLinkTest


func test_from():
	var layer = 3
	var offset = 42
	var subgrid = 17
	var result = SVOLink.from(layer, offset, subgrid)
	assert_eq(SVOLink.layer(result), layer)
	assert_eq(SVOLink.offset(result), offset)
	assert_eq(SVOLink.subgrid(result), subgrid)


func test_layer():
	var input = SVOLink.from(7, 0, 0)
	var expected = 7
	var result = SVOLink.layer(input)
	assert_eq(result, expected)

	var input_layer_8 = SVOLink.from(8, 0, 0)
	var expected_layer_8 = 8
	var result_layer_8 = SVOLink.layer(input_layer_8)
	assert_eq(result_layer_8, expected_layer_8)

	var input_layer_11 = SVOLink.from(11, 0, 0)
	var expected_layer_11 = 11
	var result_layer_11 = SVOLink.layer(input_layer_11)
	assert_eq(result_layer_11, expected_layer_11)

	var input_layer_15 = SVOLink.from(15, 0, 0)
	var expected_layer_15 = 15
	var result_layer_15 = SVOLink.layer(input_layer_15)
	assert_eq(result_layer_15, expected_layer_15)


func test_offset():
	var input = SVOLink.from(0, 123456, 0)
	var expected = 123456
	var result = SVOLink.offset(input)
	assert_eq(result, expected)


func test_subgrid():
	var input = SVOLink.from(0, 0, 55)
	var expected = 55
	var result = SVOLink.subgrid(input)
	assert_eq(result, expected)


func test_set_layer():
	var input = SVOLink.from(1, 300, 23)
	var expected_layer = 7
	var result = SVOLink.set_layer(expected_layer, input)
	assert_eq(SVOLink.layer(result), expected_layer)
	assert_eq(SVOLink.offset(result), 300)
	assert_eq(SVOLink.subgrid(result), 23)


func test_set_offset():
	var input = SVOLink.from(5, 11, 29)
	var expected_offset = 999
	var result = SVOLink.set_offset(expected_offset, input)
	assert_eq(SVOLink.layer(result), 5)
	assert_eq(SVOLink.offset(result), expected_offset)
	assert_eq(SVOLink.subgrid(result), 29)


func test_set_subgrid():
	var input = SVOLink.from(6, 111, 7)
	var expected_subgrid = 61
	var result = SVOLink.set_subgrid(expected_subgrid, input)
	assert_eq(SVOLink.layer(result), 6)
	assert_eq(SVOLink.offset(result), 111)
	assert_eq(SVOLink.subgrid(result), expected_subgrid)


# func test_get_format_string():
# 	var input = SVOLink.from(2, 9, 5)
# 	var result = SVOLink.get_format_string(input)
# 	assert_string_contains(result, "Svolink ")
# 	assert_string_contains(result, "Layer 2")
# 	assert_string_contains(result, "offset 9")
# 	assert_string_contains(result, "subgrid 5")


# func test_get_binary_string():
# 	var input = SVOLink.from(1, 2, 3)
# 	var result = SVOLink.get_binary_string(input)
# 	assert_eq(result.count("|"), 2)
# 	assert_eq(result.length(), 66)
