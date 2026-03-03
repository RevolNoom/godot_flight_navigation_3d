## 32-bit packed SVO link.
## Layout: 4 layer bits, 22 offset bits, 6 subgrid bits.
@tool
extends ISvoLink
class_name SvoLink32

const _NULL: int = ~0
const _SUBGRID_BITS: int = 6
const _OFFSET_BITS: int = 22
const _LAYER_BITS: int = 4
const _LAYER_SHIFT: int = _SUBGRID_BITS + _OFFSET_BITS
const _SUBGRID_MASK: int = 0x3F
const _OFFSET_MASK: int = 0x0FFF_FFC0
const _LAYER_MASK: int = 0xF000_0000

static var singleton = SvoLink32.new()


func null_link() -> int:
	return _NULL


func get_subgrid_mask() -> int:
	return _SUBGRID_MASK


func get_offset_mask() -> int:
	return _OFFSET_MASK


func get_layer_mask() -> int:
	return _LAYER_MASK


func create(layer: int, index: int, subgrid: int = 0) -> int:
	return ((layer << _LAYER_SHIFT) & _LAYER_MASK)\
		| ((index << _SUBGRID_BITS) & _OFFSET_MASK)\
		| (subgrid & _SUBGRID_MASK)


func get_layer(svolink: int) -> int:
	return (svolink >> _LAYER_SHIFT) & ((1 << _LAYER_BITS) - 1)


func set_layer(svolink: int, layer: int) -> int:
	return (svolink & ~_LAYER_MASK) | ((layer << _LAYER_SHIFT) & _LAYER_MASK)


func get_offset(svolink: int) -> int:
	return (svolink & _OFFSET_MASK) >> _SUBGRID_BITS


func set_offset(svolink: int, offset: int) -> int:
	return (svolink & ~_OFFSET_MASK) | ((offset << _SUBGRID_BITS) & _OFFSET_MASK)


func get_subgrid(svolink: int) -> int:
	return svolink & _SUBGRID_MASK


func set_subgrid(svolink: int, subgrid: int) -> int:
	return (svolink & ~_SUBGRID_MASK) | (subgrid & _SUBGRID_MASK)
