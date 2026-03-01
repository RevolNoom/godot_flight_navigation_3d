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
	var layer = 0b0_0011
	var offset = 0x0020_0000_0000_3039
	var subgrid = 0b01_0001
	var result = _svolink64.create(layer, offset, subgrid)
	assert_eq(_svolink64.get_layer(result), layer)
	assert_eq(_svolink64.get_offset(result), offset)
	assert_eq(_svolink64.get_subgrid(result), subgrid)


func test_svolink64_setters():
	var input_layer = 0b0_0011
	var input_offset = 0x0000_0000_3ADE_68B1
	var input_subgrid = 0b00_0111
	var input = _svolink64.create(input_layer, input_offset, input_subgrid)

	var set_layer_value = 0b0_0100
	var set_layer = _svolink64.set_layer(input, set_layer_value)
	assert_eq(_svolink64.get_layer(set_layer), set_layer_value)
	assert_eq(_svolink64.get_offset(set_layer), input_offset)
	assert_eq(_svolink64.get_subgrid(set_layer), input_subgrid)

	var set_offset_value = 0x0020_0000_0000_0063
	var set_offset = _svolink64.set_offset(input, set_offset_value)
	assert_eq(_svolink64.get_layer(set_offset), input_layer)
	assert_eq(_svolink64.get_offset(set_offset), set_offset_value)
	assert_eq(_svolink64.get_subgrid(set_offset), input_subgrid)

	var set_subgrid_value = 0b11_1101
	var set_subgrid = _svolink64.set_subgrid(input, set_subgrid_value)
	assert_eq(_svolink64.get_layer(set_subgrid), input_layer)
	assert_eq(_svolink64.get_offset(set_subgrid), input_offset)
	assert_eq(_svolink64.get_subgrid(set_subgrid), set_subgrid_value)


func test_svolink64_create_truncates_out_of_range_values():
	var out_of_range_layer = 0b11_1111
	var out_of_range_offset = 0x00FF_FFFF_FFFF_FFFF
	var out_of_range_subgrid = 0b111_1111
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
