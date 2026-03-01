extends GutTest

class_name SvoLink32Test

var _svolink32 = SvoLink32.singleton


func test_svolink32_singleton_identity():
	var s1 = SvoLink32.singleton
	var s2 = SvoLink32.singleton
	assert_same(s1, s2)


func test_svolink32_null():
	assert_eq(_svolink32.null_link(), ~0)


func test_svolink32_masks():
	assert_eq(_svolink32.get_subgrid_mask(), 0x3F)
	assert_eq(_svolink32.get_offset_mask(), 0x0FFF_FFC0)
	assert_eq(_svolink32.get_layer_mask(), 0xF000_0000)


func test_svolink32_create_and_getters():
	var layer = 0b0011
	var offset = 0b00_0000_0000_0000_0000_1010_10
	var subgrid = 0b01_0001
	var result = _svolink32.create(layer, offset, subgrid)
	assert_eq(_svolink32.get_layer(result), layer)
	assert_eq(_svolink32.get_offset(result), offset)
	assert_eq(_svolink32.get_subgrid(result), subgrid)


func test_svolink32_setters():
	var input_layer = 0b0001
	var input_offset = 0x0000_012C
	var input_subgrid = 0b01_0111
	var input = _svolink32.create(input_layer, input_offset, input_subgrid)

	var set_layer_value = 0b0111
	var set_layer = _svolink32.set_layer(input, set_layer_value)
	assert_eq(_svolink32.get_layer(set_layer), set_layer_value)
	assert_eq(_svolink32.get_offset(set_layer), input_offset)
	assert_eq(_svolink32.get_subgrid(set_layer), input_subgrid)

	var set_offset_value = 0x0000_03E7
	var set_offset = _svolink32.set_offset(input, set_offset_value)
	assert_eq(_svolink32.get_layer(set_offset), input_layer)
	assert_eq(_svolink32.get_offset(set_offset), set_offset_value)
	assert_eq(_svolink32.get_subgrid(set_offset), input_subgrid)

	var set_subgrid_value = 0b11_1101
	var set_subgrid = _svolink32.set_subgrid(input, set_subgrid_value)
	assert_eq(_svolink32.get_layer(set_subgrid), input_layer)
	assert_eq(_svolink32.get_offset(set_subgrid), input_offset)
	assert_eq(_svolink32.get_subgrid(set_subgrid), set_subgrid_value)


func test_svolink32_create_truncates_out_of_range_values():
	var out_of_range_layer = 0b1_1111
	var out_of_range_offset = 0x00FF_FFFF
	var out_of_range_subgrid = 0b111_1111
	var link = _svolink32.create(
		out_of_range_layer,
		out_of_range_offset,
		out_of_range_subgrid
	)
	assert_eq(_svolink32.get_layer(link), out_of_range_layer & 0b1111)
	assert_eq(_svolink32.get_offset(link), out_of_range_offset & 0x3F_FFFF)
	assert_eq(_svolink32.get_subgrid(link), out_of_range_subgrid & 0x3F)
