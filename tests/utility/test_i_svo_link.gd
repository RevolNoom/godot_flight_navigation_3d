extends GutTest

class_name ISvoLinkTest


func _case_singleton(case_data: Dictionary) -> ISvoLink:
	return case_data["singleton"] as ISvoLink


func _case_name(case_data: Dictionary) -> String:
	return str(case_data["name"])


func _create_case_link(case_data: Dictionary) -> int:
	var singleton: ISvoLink = _case_singleton(case_data)
	return singleton.create(
		int(case_data["layer"]),
		int(case_data["offset"]),
		int(case_data["subgrid"])
	)


func test_svo_link_null(
	p: Dictionary = use_parameters([
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
) -> void:
	var singleton: ISvoLink = _case_singleton(p)
	assert_eq(singleton.null_link(), int(p["expected"]), _case_name(p))


func test_svo_link_masks(
	p: Dictionary = use_parameters([
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
) -> void:
	var singleton: ISvoLink = _case_singleton(p)
	assert_eq(
		singleton.get_subgrid_mask(),
		int(p["expected_subgrid"]),
		"%s subgrid mask" % _case_name(p)
	)
	assert_eq(
		singleton.get_offset_mask(),
		int(p["expected_offset"]),
		"%s offset mask" % _case_name(p)
	)
	assert_eq(
		singleton.get_layer_mask(),
		int(p["expected_layer"]),
		"%s layer mask" % _case_name(p)
	)


func test_svo_link_create_and_getters(
	p: Dictionary = use_parameters([
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
) -> void:
	var singleton: ISvoLink = _case_singleton(p)
	var result: int = _create_case_link(p)
	assert_eq(singleton.get_layer(result), int(p["layer"]), _case_name(p))
	assert_eq(singleton.get_offset(result), int(p["offset"]), _case_name(p))
	assert_eq(singleton.get_subgrid(result), int(p["subgrid"]), _case_name(p))


func test_svo_link_set_layer(
	p: Dictionary = use_parameters([
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
	) -> void:
	var singleton: ISvoLink = _case_singleton(p)
	var input: int = singleton.create(
		int(p["input_layer"]),
		int(p["input_offset"]),
		int(p["input_subgrid"])
	)
	var result: int = singleton.set_layer(input, int(p["set_value"]))
	assert_eq(singleton.get_layer(result), int(p["set_value"]), _case_name(p))
	assert_eq(singleton.get_offset(result), int(p["input_offset"]), _case_name(p))
	assert_eq(singleton.get_subgrid(result), int(p["input_subgrid"]), _case_name(p))


func test_svo_link_set_offset(
	p: Dictionary = use_parameters([
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
	) -> void:
	var singleton: ISvoLink = _case_singleton(p)
	var input: int = singleton.create(
		int(p["input_layer"]),
		int(p["input_offset"]),
		int(p["input_subgrid"])
	)
	var result: int = singleton.set_offset(input, int(p["set_value"]))
	assert_eq(singleton.get_layer(result), int(p["input_layer"]), _case_name(p))
	assert_eq(singleton.get_offset(result), int(p["set_value"]), _case_name(p))
	assert_eq(singleton.get_subgrid(result), int(p["input_subgrid"]), _case_name(p))


func test_svo_link_set_subgrid(
	p: Dictionary = use_parameters([
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
	) -> void:
	var singleton: ISvoLink = _case_singleton(p)
	var input: int = singleton.create(
		int(p["input_layer"]),
		int(p["input_offset"]),
		int(p["input_subgrid"])
	)
	var result: int = singleton.set_subgrid(input, int(p["set_value"]))
	assert_eq(singleton.get_layer(result), int(p["input_layer"]), _case_name(p))
	assert_eq(singleton.get_offset(result), int(p["input_offset"]), _case_name(p))
	assert_eq(singleton.get_subgrid(result), int(p["set_value"]), _case_name(p))


func test_svo_link_create_truncates_out_of_range_values(
	p: Dictionary = use_parameters([
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
	) -> void:
	var singleton: ISvoLink = _case_singleton(p)
	var result: int = singleton.create(
		int(p["layer"]),
		int(p["offset"]),
		int(p["subgrid"])
	)
	assert_eq(singleton.get_layer(result), int(p["expected_layer"]), _case_name(p))
	assert_eq(
		singleton.get_offset(result),
		int(p["expected_offset"]),
		_case_name(p)
	)
	assert_eq(
		singleton.get_subgrid(result),
		int(p["expected_subgrid"]),
		_case_name(p)
	)
