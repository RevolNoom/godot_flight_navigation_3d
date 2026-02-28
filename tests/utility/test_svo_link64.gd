extends GutTest

class_name SvoLink64Test

var _svolink64 = SvoLink64.singleton


func test_svolink64_singleton_identity():
	var s1 = SvoLink64.singleton
	var s2 = SvoLink64.singleton
	assert_same(s1, s2)


func test_svolink64_null():
	assert_eq(_svolink64.null_link(), ~0)


func test_svolink64_masks():
	assert_eq(_svolink64.get_subgrid_mask(), 0x3F)
	assert_eq(_svolink64.get_offset_mask(), 0x0FFF_FFFF_FFFF_FFC0)
	assert_eq(_svolink64.get_layer_mask(), ~0x0FFF_FFFF_FFFF_FFFF)


func test_svolink64_create_and_getters():
	var layer = 3
	var offset = (1 << 53) + 12345
	var subgrid = 17
	var result = _svolink64.create(layer, offset, subgrid)
	assert_eq(_svolink64.get_layer(result), layer)
	assert_eq(_svolink64.get_offset(result), offset)
	assert_eq(_svolink64.get_subgrid(result), subgrid)


func test_svolink64_setters():
	var input = _svolink64.create(3, 987654321, 7)
	var set_layer = _svolink64.set_layer(input, 4)
	assert_eq(_svolink64.get_layer(set_layer), 4)
	assert_eq(_svolink64.get_offset(set_layer), 987654321)
	assert_eq(_svolink64.get_subgrid(set_layer), 7)

	var set_offset = _svolink64.set_offset(input, (1 << 53) + 99)
	assert_eq(_svolink64.get_layer(set_offset), 3)
	assert_eq(_svolink64.get_offset(set_offset), (1 << 53) + 99)
	assert_eq(_svolink64.get_subgrid(set_offset), 7)

	var set_subgrid = _svolink64.set_subgrid(input, 61)
	assert_eq(_svolink64.get_layer(set_subgrid), 3)
	assert_eq(_svolink64.get_offset(set_subgrid), 987654321)
	assert_eq(_svolink64.get_subgrid(set_subgrid), 61)


func test_svolink64_create_truncates_out_of_range_values():
	var out_of_range_layer = 63
	var out_of_range_offset = (1 << 56) - 1
	var out_of_range_subgrid = 127
	var link = _svolink64.create(
		out_of_range_layer,
		out_of_range_offset,
		out_of_range_subgrid
	)
	var expected_layer = ((out_of_range_layer << 60) >> 60) & 0b1_1111
	assert_eq(_svolink64.get_layer(link), expected_layer)
	assert_eq(_svolink64.get_offset(link), out_of_range_offset & ((1 << 54) - 1))
	assert_eq(_svolink64.get_subgrid(link), out_of_range_subgrid & 0x3F)


func test_svolink64_debug_helpers():
	var input = _svolink64.create(1, 2, 3)
	var format_result = _svolink64.get_format_string(input)
	assert_string_contains(format_result, "Svolink ")
	assert_string_contains(format_result, "Layer 1")
	assert_string_contains(format_result, "offset 2")
	assert_string_contains(format_result, "subgrid 3")

	var binary_result = _svolink64.get_binary_string(input)
	assert_eq(binary_result.count("|"), 2)
	assert_eq(binary_result.length(), 66)
