## Interface-like base for packed SVO link utilities.
## Concrete implementations define bit layout and mask widths.
extends RefCounted
class_name ISvoLink


func null_link() -> int:
	return ~0


func get_subgrid_mask() -> int:
	printerr("ISvoLink.get_subgrid_mask() is abstract.")
	return 0


func get_offset_mask() -> int:
	printerr("ISvoLink.get_offset_mask() is abstract.")
	return 0


func get_layer_mask() -> int:
	printerr("ISvoLink.get_layer_mask() is abstract.")
	return 0


func create(_layer: int, _index: int, _subgrid: int = 0) -> int:
	printerr("ISvoLink.create() is abstract.")
	return null_link()


func get_layer(_svolink: int) -> int:
	printerr("ISvoLink.get_layer() is abstract.")
	return 0


func set_layer(_svolink: int, _layer: int) -> int:
	printerr("ISvoLink.set_layer() is abstract.")
	return null_link()


func get_offset(_svolink: int) -> int:
	printerr("ISvoLink.get_offset() is abstract.")
	return 0


func set_offset(_svolink: int, _offset: int) -> int:
	printerr("ISvoLink.set_offset() is abstract.")
	return null_link()


func get_subgrid(_svolink: int) -> int:
	printerr("ISvoLink.get_subgrid() is abstract.")
	return 0


func set_subgrid(_svolink: int, _subgrid: int) -> int:
	printerr("ISvoLink.set_subgrid() is abstract.")
	return null_link()
