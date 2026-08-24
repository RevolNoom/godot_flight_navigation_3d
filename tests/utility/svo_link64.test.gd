extends GutTest

class_name SvoLink64Test

var _svolink64: SvoLink64 = SvoLink64.singleton


func _create_link(layer: int, offset: int, subgrid: int) -> int:
	return _svolink64.create(layer, offset, subgrid)


func test_svolink64_singleton_identity() -> void:
	var s1: SvoLink64 = SvoLink64.singleton
	var s2: SvoLink64 = _svolink64
	assert_same(s1, s2)


func test_svolink64_get_format_string(
	p: Dictionary = use_parameters([
		{
			"layer": 1,
			"offset": 2,
			"subgrid": 3,
			"expected_text": [
				"Svolink ",
				"Layer 1",
				"offset 2",
				"subgrid 3",
			],
		},
		{
			"layer": 2,
			"offset": 5,
			"subgrid": 1,
			"expected_text": [
				"Svolink ",
				"Layer 2",
				"offset 5",
				"subgrid 1",
			],
		},
	])
	) -> void:
	var input: int = _create_link(
		int(p["layer"]),
		int(p["offset"]),
		int(p["subgrid"])
	)
	var result: String = _svolink64.get_format_string(input)
	for expected_text_value in p["expected_text"]:
		var expected_text: String = str(expected_text_value)
		assert_string_contains(result, expected_text)


func test_svolink64_get_binary_string(
	p: Dictionary = use_parameters([
		{"layer": 1, "offset": 2, "subgrid": 3},
		{"layer": 7, "offset": 12_345, "subgrid": 31},
	])
	) -> void:
	var input: int = _create_link(
		int(p["layer"]),
		int(p["offset"]),
		int(p["subgrid"])
	)
	var binary_result: String = _svolink64.get_binary_string(input)
	var parts: PackedStringArray = binary_result.split("|")
	assert_eq(parts.size(), 3)
	assert_eq(parts[0].length(), 5)
	assert_eq(parts[1].length(), 53)
	assert_eq(parts[2].length(), 6)
