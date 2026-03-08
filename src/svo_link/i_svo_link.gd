## Interface-like base for packed SVO link utilities.
## Concrete implementations define bit layout and mask widths.
extends RefCounted
class_name ISvoLink


func _abstract_fail(method_name: String) -> void:
	var message: String = "ISvoLink.%s() is abstract. Override in subclass." % method_name
	push_error(message)
	assert(false, message)


func null_link() -> int:
	return ~0


func get_subgrid_mask() -> int:
	_abstract_fail("get_subgrid_mask")
	return 0


func get_offset_mask() -> int:
	_abstract_fail("get_offset_mask")
	return 0


func get_layer_mask() -> int:
	_abstract_fail("get_layer_mask")
	return 0


func create(_layer: int, _index: int, _subgrid: int = 0) -> int:
	_abstract_fail("create")
	return null_link()


func get_layer(_svolink: int) -> int:
	_abstract_fail("get_layer")
	return 0


func set_layer(_svolink: int, _layer: int) -> int:
	_abstract_fail("set_layer")
	return null_link()


func get_offset(_svolink: int) -> int:
	_abstract_fail("get_offset")
	return 0


func set_offset(_svolink: int, _offset: int) -> int:
	_abstract_fail("set_offset")
	return null_link()


func get_subgrid(_svolink: int) -> int:
	_abstract_fail("get_subgrid")
	return 0


func set_subgrid(_svolink: int, _subgrid: int) -> int:
	_abstract_fail("set_subgrid")
	return null_link()
