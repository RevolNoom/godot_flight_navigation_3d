extends GutTest

class_name SvoLink32Test

var _svolink32: SvoLink32 = SvoLink32.singleton


func test_svolink32_singleton_identity() -> void:
	var s1: SvoLink32 = SvoLink32.singleton
	var s2: SvoLink32 = _svolink32
	assert_same(s1, s2)
