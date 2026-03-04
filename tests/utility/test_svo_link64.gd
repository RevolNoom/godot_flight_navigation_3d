extends GutTest

class_name SvoLink64Test

var _svolink64 = SvoLink64.singleton


func test_svolink64_singleton_identity(_p = use_parameters([null])):
	var s1 = SvoLink64.singleton
	var s2 = SvoLink64.singleton
	assert_same(s1, s2)


func test_svolink64_get_format_string(
	p = use_parameters([
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
):
	var input = _svolink64.create(
		p["layer"],
		p["offset"],
		p["subgrid"]
	)
	var result = _svolink64.get_format_string(input)
	for expected_text in p["expected_text"]:
		assert_string_contains(result, expected_text)


func test_svolink64_get_binary_string(
	p = use_parameters([
		{"layer": 1, "offset": 2, "subgrid": 3},
		{"layer": 7, "offset": 12_345, "subgrid": 31},
	])
):
	var input = _svolink64.create(
		p["layer"],
		p["offset"],
		p["subgrid"]
	)
	var binary_result = _svolink64.get_binary_string(input)
	var parts = binary_result.split("|")
	assert_eq(parts.size(), 3)
	assert_eq(parts[0].length(), 5)
	assert_eq(parts[1].length(), 53)
	assert_eq(parts[2].length(), 6)
