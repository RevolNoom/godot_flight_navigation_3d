## SVOIterator that travels sequentially between layers or nodes in a layer of an SVO
extends SVOIterator
class_name SVOIteratorSequential

## Vertical Iterator
## Travels from top (biggest voxel) to bottom (smallest voxel) layer
static func v_begin(svo: SVO_V3) -> SVOIteratorSequential:
	return SVOIteratorSequential._new(svo, 
		SVOLink.from(svo.layers.size()-1, 0, 0), 
		Vector2i(0, -1))

## Vertical Iterator
## Travels from bottom (smallest voxel) to top (biggest voxel) layer
static func v_rbegin(svo: SVO_V3) -> SVOIteratorSequential:
	return SVOIteratorSequential._new(svo, 
		SVOLink.from(0, 0, 0), 
		Vector2i(0, 1))
		
## Horizontal Iterator
## Traverses over all nodes in a layer
static func h_begin(svo: SVO_V3, new_svolink: int) -> SVOIteratorSequential:
	return SVOIteratorSequential._new(svo, 
		new_svolink, 
		Vector2i(1, 0))

static func _new(svo: SVO_V3, new_svolink: int, direction: Vector2i) -> SVOIteratorSequential:
	var it = SVOIteratorSequential.new()
	it._direction = direction
	it.svolink = new_svolink
	it._svo_data = svo.layers
	
	it._has_ended = it._is_current_link_out_of_range()
	return it

var _direction: Vector2i
var _has_ended: bool = false

func end() -> bool:
	return _has_ended

func next() -> void:
	_add_step(_direction)

func prev() -> void:
	_add_step(-_direction)

func _add_step(direction: Vector2i):
	_has_ended = (layer == 0 and direction.y < 0) \
	or (offset == 0 and direction.x < 0)
	svolink = SVOLink.from(layer + direction.y, offset + direction.x, 0)
	_has_ended = _has_ended || _is_current_link_out_of_range()

func _is_current_link_out_of_range() -> bool:
	var l = SVOLink.layer(svolink)
	return l >= _svo_data.size() \
	or SVOLink.offset(svolink)*DataField.MAX_FIELD >= _svo_data[l].size()
