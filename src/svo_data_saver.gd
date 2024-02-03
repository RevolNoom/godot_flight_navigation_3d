## Save SVO as binary data.[br]
##
## [b]NOTE:[/b] This is my failed attempt to save/load custom .svo extension.[br]
## An SVO binary data file has the following format:[br]
## [br]
## HEADER - Act1Nodes - Subgrids [br]
## [br]
## [b]HEADER:[/b][br]
## + 8-byte magic string "SVO_DATA".[br]
## + Version number (int32).[br]
## + SVO Depth (int32).[br]
## + Number of active layer-1 nodes (int64).[br]
## [br]
## [b]Act1Nodes:[/b][br]
## An array of Morton codes of nodes in layer 1, with length specified in HEADER.
## Each morton code is an int64.[br]
## [br]
## [b]Subgrids:[/b][br]
## Array contains all of layer-0 [member SVONode.subgrid], serialized.[br]
## Length equals 8 times the length of Act1Nodes.[br]
## Each subgrid is an int64.[br]
## [br]
## [b]Version history:[/b][br]
## - Version 1: First SpecificationVO binary data file has the following format:[br]
extends ResourceFormatSaver
class_name SVODataSaver

const VERSION_NUMBER: int = 1

func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	if resource is SVO:
		return ["res"]
	return []


func _recognize(resource: Resource) -> bool:
	return resource is SVO


## Return [constant @GlobalScope.OK] or [constant @GlobalScope.FAILED]
func _save(resource: Resource, path: String, flags: int) -> Error:
	#ResourceSaver.save()
	print("I'm Saving SVO")
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		printerr("SVODataSaver: Can't open file for writing: %s" % [path])
		return FAILED
	
	var svo = resource as SVO
	if svo == null:
		printerr("SVODataSaver: Resource is not SVO")
		return FAILED
	
	# Header
	for char_pos in range("SVO_DATA".length()):
		file.store_8("SVO_DATA".unicode_at(char_pos))
	
	file.store_32(VERSION_NUMBER)
	file.store_32(svo.depth)
	file.store_64(svo.layer[1].size())
	
	var act1nodes: PackedInt64Array = (svo._nodes[1] as Array[SVO.SVONode]).map(
		func(node): return node.morton)
	for act1node in act1nodes:
		file.store_64(act1node)
	
	var subgrids: PackedInt64Array = (svo._nodes[0] as Array[SVO.SVONode]).map(
		func(node): return node.subgrid)
	for subgrid in subgrids:
		file.store_64(subgrid)
	
	file.close()
	return OK
