## SVOIterator that travels sequentially between layers or nodes in a layer of an SVO
extends SVOIterator
class_name SVOIteratorRandom

static func _new(svo: SVO, new_svolink: int = SVOLink.NULL) -> SVOIteratorRandom:
	var it = SVOIteratorRandom.new()
	it.svolink = new_svolink
	it._svo_data = svo.layers
	return it

func go_field(data_field: DataField) -> SVOIteratorRandom: 
	svolink = field(data_field)
	return self

func go(layer_idx: int, offset_idx: int) -> SVOIteratorRandom:
	svolink = SVOLink.from(layer_idx, offset_idx, 0)
	return self
