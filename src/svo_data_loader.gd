## A loader for SVO binary data file
##
## [b]NOTE:[/b] This is my failed attempt to save/load custom .svo extension.[br]
## See [SVODataSaver] for SVO binary data file format
extends ResourceFormatLoader
class_name SVODataLoader


func _get_recognized_extensions() -> PackedStringArray:
	return ["res"]


## Return [SVO] on success, [constant @GlobalScope.FAILED] on error
func _load(path: String, original_path: String, use_sub_threads: bool, cache_mode: int) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("SVODataLoader: Error: %d. Can't open svo file: %s" % [FileAccess.get_open_error(), path])
		return FAILED
		
	var filesize = file.get_length()
	
	# Header
	var header_length = 64*3
	if filesize < header_length:
		printerr("SVODataLoader: Missing file header. Can't open svo file: %s" % [FileAccess.get_open_error(), path])
		return FAILED
		
	var magic_string = file.get_64()
	for char_pos in range(8):
		if (magic_string >> ((7-char_pos) * 8)) & 0xFF != "SVO_DATA".unicode_at(char_pos):
			printerr("""SVODataLoader: Magic string doesn't match at %d. 
				Can't load svo at %s""" % [char_pos, path])
			return FAILED
			
	var _version_number = file.get_32()	# There's currently only version 1. So, don't care
	
	var depth = file.get_32()
	if depth != clamp(depth, 2, 16):
		printerr("""SVODataLoader: Depth = %d, not in range 2, 16 as required by SVO.
			Can't load SVO at %s""" % [depth, path])
		return FAILED
		
	var act1nodes_length = file.get_64()
	var subgrids_length = act1nodes_length * 8
	var content_length = act1nodes_length + subgrids_length
	
	if filesize < header_length + content_length:
		printerr("""SVODataLoader: Missing file content. 
			Expect %d bytes, but got only %d bytes. 
			Can't open svo file: %s""" % [content_length, filesize - header_length, path])
		return FAILED
	
	var act1nodes: PackedInt64Array = []
	act1nodes.resize(act1nodes_length)
	act1nodes.resize(0)
	for i in range(act1nodes_length):
		act1nodes.push_back(file.get_64())
	
	var subgrids: PackedInt64Array = []
	subgrids.resize(subgrids_length)
	subgrids.resize(0)
	for i in range(subgrids_length):
		subgrids.push_back(file.get_64())
	return SVO.create_new(depth, act1nodes, subgrids)
