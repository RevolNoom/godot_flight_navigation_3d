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
	var layer = 3
	var offset = 42
	var subgrid = 17
	var result = _svolink32.create(layer, offset, subgrid)
	assert_eq(_svolink32.get_layer(result), layer)
	assert_eq(_svolink32.get_offset(result), offset)
	assert_eq(_svolink32.get_subgrid(result), subgrid)


func test_svolink32_setters():
	var input = _svolink32.create(1, 300, 23)
	var set_layer = _svolink32.set_layer(input, 7)
	assert_eq(_svolink32.get_layer(set_layer), 7)
	assert_eq(_svolink32.get_offset(set_layer), 300)
	assert_eq(_svolink32.get_subgrid(set_layer), 23)

	var set_offset = _svolink32.set_offset(input, 999)
	assert_eq(_svolink32.get_layer(set_offset), 1)
	assert_eq(_svolink32.get_offset(set_offset), 999)
	assert_eq(_svolink32.get_subgrid(set_offset), 23)

	var set_subgrid = _svolink32.set_subgrid(input, 61)
	assert_eq(_svolink32.get_layer(set_subgrid), 1)
	assert_eq(_svolink32.get_offset(set_subgrid), 300)
	assert_eq(_svolink32.get_subgrid(set_subgrid), 61)


func test_svolink32_create_truncates_out_of_range_values():
	var out_of_range_layer = 31
	var out_of_range_offset = (1 << 24) - 1
	var out_of_range_subgrid = 127
	var link = _svolink32.create(
		out_of_range_layer,
		out_of_range_offset,
		out_of_range_subgrid
	)
	assert_eq(_svolink32.get_layer(link), out_of_range_layer & 0b1111)
	assert_eq(_svolink32.get_offset(link), out_of_range_offset & 0x3F_FFFF)
	assert_eq(_svolink32.get_subgrid(link), out_of_range_subgrid & 0x3F)
