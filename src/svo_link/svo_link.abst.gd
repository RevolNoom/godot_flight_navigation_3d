## Interface-like base for packed SVO link utilities.
## Concrete implementations define bit layout and mask widths.
extends RefCounted
class_name ASvoLink


func null_link() -> int:
	assert(false, "Not implemented")
	return 0


func get_subgrid_mask() -> int:
	assert(false, "Not implemented")
	return 0


func get_offset_mask() -> int:
	assert(false, "Not implemented")
	return 0


func get_layer_mask() -> int:
	assert(false, "Not implemented")
	return 0


func create(_layer: int, _index: int, _subgrid: int = 0) -> int:
	assert(false, "Not implemented")
	return null_link()


func get_layer(_svolink: int) -> int:
	assert(false, "Not implemented")
	return 0


func set_layer(_svolink: int, _layer: int) -> int:
	assert(false, "Not implemented")
	return null_link()


func get_offset(_svolink: int) -> int:
	assert(false, "Not implemented")
	return 0


func set_offset(_svolink: int, _offset: int) -> int:
	assert(false, "Not implemented")
	return null_link()


func get_subgrid(_svolink: int) -> int:
	assert(false, "Not implemented")
	return 0


func set_subgrid(_svolink: int, _subgrid: int) -> int:
	assert(false, "Not implemented")
	return null_link()
