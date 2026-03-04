extends GutTest

class_name ISvoLinkTest


func test_svo_link_null(
	p = use_parameters([
		{
			"name": "SvoLink32",
			"singleton": SvoLink32.singleton,
			"expected": 0xFFFF_FFFF,
		},
		{
			"name": "SvoLink64",
			"singleton": SvoLink64.singleton,
			"expected": ~0,
		},
	])
):
	var singleton = p["singleton"]
	assert_eq(singleton.null_link(), p["expected"], p["name"])


func test_svo_link_masks(
	p = use_parameters([
		{
			"name": "SvoLink32",
			"singleton": SvoLink32.singleton,
			"expected_subgrid": 0x3F,
			"expected_offset": 0x0FFF_FFC0,
			"expected_layer": 0xF000_0000,
		},
		{
			"name": "SvoLink64",
			"singleton": SvoLink64.singleton,
			"expected_subgrid": 0x3F,
			"expected_offset": 0x0FFF_FFFF_FFFF_FFC0,
			"expected_layer": ~0x0FFF_FFFF_FFFF_FFFF,
		},
	])
):
	var singleton = p["singleton"]
	assert_eq(
		singleton.get_subgrid_mask(),
		p["expected_subgrid"],
		"%s subgrid mask" % p["name"]
	)
	assert_eq(
		singleton.get_offset_mask(),
		p["expected_offset"],
		"%s offset mask" % p["name"]
	)
	assert_eq(
		singleton.get_layer_mask(),
		p["expected_layer"],
		"%s layer mask" % p["name"]
	)


func test_svo_link_create_and_getters(
	p = use_parameters([
		{
			"name": "SvoLink32 basic",
			"singleton": SvoLink32.singleton,
			"layer": 0b0011,
			"offset": 0b00_0000_0000_0000_0000_1010_10,
			"subgrid": 0b01_0001,
		},
		{
			"name": "SvoLink32 min",
			"singleton": SvoLink32.singleton,
			"layer": 0b0000,
			"offset": 0x0000_0000,
			"subgrid": 0b00_0000,
		},
		{
			"name": "SvoLink32 max in range",
			"singleton": SvoLink32.singleton,
			"layer": 0b1111,
			"offset": 0x003F_FFFF,
			"subgrid": 0b11_1111,
		},
		{
			"name": "SvoLink64 basic",
			"singleton": SvoLink64.singleton,
			"layer": 0b0_0011,
			"offset": 0x0020_0000_0000_3039,
			"subgrid": 0b01_0001,
		},
		{
			"name": "SvoLink64 min",
			"singleton": SvoLink64.singleton,
			"layer": 0b0_0000,
			"offset": 0x0000_0000_0000_0000,
			"subgrid": 0b00_0000,
		},
		{
			"name": "SvoLink64 max in range",
			"singleton": SvoLink64.singleton,
			"layer": 0b0_0111,
			"offset": 0x003F_FFFF_FFFF_FFFF,
			"subgrid": 0b11_1111,
		},
	])
):
	var singleton = p["singleton"]
	var result = singleton.create(
		p["layer"],
		p["offset"],
		p["subgrid"]
	)
	assert_eq(singleton.get_layer(result), p["layer"], p["name"])
	assert_eq(singleton.get_offset(result), p["offset"], p["name"])
	assert_eq(singleton.get_subgrid(result), p["subgrid"], p["name"])


func test_svo_link_set_layer(
	p = use_parameters([
		{
			"name": "SvoLink32 set layer",
			"singleton": SvoLink32.singleton,
			"input_layer": 0b0001,
			"input_offset": 0x0000_012C,
			"input_subgrid": 0b01_0111,
			"set_value": 0b0111,
		},
		{
			"name": "SvoLink32 set layer to min",
			"singleton": SvoLink32.singleton,
			"input_layer": 0b1111,
			"input_offset": 0x003F_FFFF,
			"input_subgrid": 0b11_1111,
			"set_value": 0b0000,
		},
		{
			"name": "SvoLink64 set layer",
			"singleton": SvoLink64.singleton,
			"input_layer": 0b0_0011,
			"input_offset": 0x0000_0000_3ADE_68B1,
			"input_subgrid": 0b00_0111,
			"set_value": 0b0_0100,
		},
		{
			"name": "SvoLink64 set layer to 1",
			"singleton": SvoLink64.singleton,
			"input_layer": 0b0_0111,
			"input_offset": 0x003F_FFFF_FFFF_FFFF,
			"input_subgrid": 0b11_1111,
			"set_value": 0b0_0001,
		},
	])
):
	var singleton = p["singleton"]
	var input = singleton.create(
		p["input_layer"],
		p["input_offset"],
		p["input_subgrid"]
	)
	var result = singleton.set_layer(input, p["set_value"])
	assert_eq(singleton.get_layer(result), p["set_value"], p["name"])
	assert_eq(singleton.get_offset(result), p["input_offset"], p["name"])
	assert_eq(singleton.get_subgrid(result), p["input_subgrid"], p["name"])


func test_svo_link_set_offset(
	p = use_parameters([
		{
			"name": "SvoLink32 set offset",
			"singleton": SvoLink32.singleton,
			"input_layer": 0b0001,
			"input_offset": 0x0000_012C,
			"input_subgrid": 0b01_0111,
			"set_value": 0x0000_03E7,
		},
		{
			"name": "SvoLink32 set offset to max",
			"singleton": SvoLink32.singleton,
			"input_layer": 0b1111,
			"input_offset": 0x0000_0001,
			"input_subgrid": 0b00_0001,
			"set_value": 0x003F_FFFF,
		},
		{
			"name": "SvoLink64 set offset",
			"singleton": SvoLink64.singleton,
			"input_layer": 0b0_0011,
			"input_offset": 0x0000_0000_3ADE_68B1,
			"input_subgrid": 0b00_0111,
			"set_value": 0x0020_0000_0000_0063,
		},
		{
			"name": "SvoLink64 set offset to max",
			"singleton": SvoLink64.singleton,
			"input_layer": 0b0_0001,
			"input_offset": 0x0000_0000_0000_0001,
			"input_subgrid": 0b00_0001,
			"set_value": 0x003F_FFFF_FFFF_FFFF,
		},
	])
):
	var singleton = p["singleton"]
	var input = singleton.create(
		p["input_layer"],
		p["input_offset"],
		p["input_subgrid"]
	)
	var result = singleton.set_offset(input, p["set_value"])
	assert_eq(singleton.get_layer(result), p["input_layer"], p["name"])
	assert_eq(singleton.get_offset(result), p["set_value"], p["name"])
	assert_eq(singleton.get_subgrid(result), p["input_subgrid"], p["name"])


func test_svo_link_set_subgrid(
	p = use_parameters([
		{
			"name": "SvoLink32 set subgrid",
			"singleton": SvoLink32.singleton,
			"input_layer": 0b0001,
			"input_offset": 0x0000_012C,
			"input_subgrid": 0b01_0111,
			"set_value": 0b11_1101,
		},
		{
			"name": "SvoLink32 set subgrid small",
			"singleton": SvoLink32.singleton,
			"input_layer": 0b0101,
			"input_offset": 0x003A_AAAA,
			"input_subgrid": 0b00_0000,
			"set_value": 0b00_0011,
		},
		{
			"name": "SvoLink64 set subgrid",
			"singleton": SvoLink64.singleton,
			"input_layer": 0b0_0011,
			"input_offset": 0x0000_0000_3ADE_68B1,
			"input_subgrid": 0b00_0111,
			"set_value": 0b11_1101,
		},
		{
			"name": "SvoLink64 set subgrid small",
			"singleton": SvoLink64.singleton,
			"input_layer": 0b0_0101,
			"input_offset": 0x0020_0000_0000_000A,
			"input_subgrid": 0b00_0000,
			"set_value": 0b00_0011,
		},
	])
):
	var singleton = p["singleton"]
	var input = singleton.create(
		p["input_layer"],
		p["input_offset"],
		p["input_subgrid"]
	)
	var result = singleton.set_subgrid(input, p["set_value"])
	assert_eq(singleton.get_layer(result), p["input_layer"], p["name"])
	assert_eq(singleton.get_offset(result), p["input_offset"], p["name"])
	assert_eq(singleton.get_subgrid(result), p["set_value"], p["name"])


func test_svo_link_create_truncates_out_of_range_values(
	p = use_parameters([
		{
			"name": "SvoLink32 over by one bit",
			"singleton": SvoLink32.singleton,
			"layer": 0b1_1111,
			"offset": 0x00FF_FFFF,
			"subgrid": 0b111_1111,
			"expected_layer": 0b1111,
			"expected_offset": 0x3F_FFFF,
			"expected_subgrid": 0x3F,
		},
		{
			"name": "SvoLink32 all bits set",
			"singleton": SvoLink32.singleton,
			"layer": ~0,
			"offset": ~0,
			"subgrid": ~0,
			"expected_layer": 0b1111,
			"expected_offset": 0x3F_FFFF,
			"expected_subgrid": 0x3F,
		},
		{
			"name": "SvoLink64 over by one bit",
			"singleton": SvoLink64.singleton,
			"layer": 0b11_1111,
			"offset": 0x00FF_FFFF_FFFF_FFFF,
			"subgrid": 0b111_1111,
			"expected_layer": 0b1_1111,
			"expected_offset": 0x003F_FFFF_FFFF_FFFF,
			"expected_subgrid": 0x3F,
		},
		{
			"name": "SvoLink64 all bits set",
			"singleton": SvoLink64.singleton,
			"layer": ~0,
			"offset": ~0,
			"subgrid": ~0,
			"expected_layer": 0b1_1111,
			"expected_offset": 0x003F_FFFF_FFFF_FFFF,
			"expected_subgrid": 0x3F,
		},
	])
):
	var singleton = p["singleton"]
	var result = singleton.create(
		p["layer"],
		p["offset"],
		p["subgrid"]
	)
	assert_eq(singleton.get_layer(result), p["expected_layer"], p["name"])
	assert_eq(
		singleton.get_offset(result),
		p["expected_offset"],
		p["name"]
	)
	assert_eq(
		singleton.get_subgrid(result),
		p["expected_subgrid"],
		p["name"]
	)
