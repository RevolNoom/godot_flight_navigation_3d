## 64-bit packed SVO link.
## Layout: 4 layer bits, 54 offset bits, 6 subgrid bits.
@tool
extends ISvoLink
class_name SvoLink64

const _NULL: int = ~0
const _SUBGRID_BITS: int = 6
const _OFFSET_BITS: int = 54
const _LAYER_BITS: int = 5
const _LAYER_SHIFT: int = _SUBGRID_BITS + _OFFSET_BITS
const _GET_LAYER_MASK: int = (1 << _LAYER_BITS) - 1
const _SUBGRID_MASK: int = 0x3F
const _OFFSET_MASK: int = 0x0FFF_FFFF_FFFF_FFC0
const _LAYER_MASK: int = ~(_SUBGRID_MASK | _OFFSET_MASK)

static var singleton = SvoLink64.new()

func null_link() -> int:
	return _NULL


func get_subgrid_mask() -> int:
	return _SUBGRID_MASK


func get_offset_mask() -> int:
	return _OFFSET_MASK


func get_layer_mask() -> int:
	return _LAYER_MASK


func create(layer: int, index: int, subgrid: int = 0) -> int:
	return (layer << _LAYER_SHIFT)\
		| ((index << _SUBGRID_BITS) & _OFFSET_MASK)\
		| (subgrid & _SUBGRID_MASK)


func get_layer(svolink: int) -> int:
	return (svolink >> _LAYER_SHIFT) & _GET_LAYER_MASK


func set_layer(svolink: int, layer: int) -> int:
	return (svolink & ~_LAYER_MASK) | (layer << _LAYER_SHIFT)


func get_offset(svolink: int) -> int:
	return (svolink & _OFFSET_MASK) >> _SUBGRID_BITS


func set_offset(svolink: int, offset: int) -> int:
	return (svolink & ~_OFFSET_MASK) | ((offset << _SUBGRID_BITS) & _OFFSET_MASK)


func get_subgrid(svolink: int) -> int:
	return svolink & _SUBGRID_MASK


func set_subgrid(svolink: int, subgrid: int) -> int:
	return (svolink & ~_SUBGRID_MASK) | (subgrid & _SUBGRID_MASK)


## Debug helper.
func get_format_string(svolink: int) -> String:
	return "Svolink %d\n Layer %d\n offset %s\n subgrid %d\n subgrid vec3 %s\n" % [
		svolink,
		get_layer(svolink),
		get_offset(svolink),
		get_subgrid(svolink),
		Morton3.decode_vec3i(get_subgrid(svolink))
	]


## Debug helper.
func get_binary_string(svolink: int) -> String:
	var result = ""
	for i in range(63, -1, -1):
		if svolink & (1 << i):
			result += "1"
		else:
			result += "0"
	result = result.insert(58, "|")
	result = result.insert(5, "|")
	return result
