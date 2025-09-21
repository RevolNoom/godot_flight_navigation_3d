## Lookup tables, used for [FlightNavigation3D] voxelization.
class_name Fn3dLookupTable

## Used to quickly flip subgrid when rasterize triangles on xy plane.
static var x_column_flip_bitmask_by_subgrid_index: PackedInt64Array = \
	_generate_x_column_flip_bitmask_by_subgrid_index()

static func _generate_x_column_flip_bitmask_by_subgrid_index() -> PackedInt64Array:
	var list_bitmask: PackedInt64Array = []
	for i in range(64):
		var bitmask = _get_x_column_flip_bitmask_by_subgrid_index(i)
		list_bitmask.push_back(bitmask)
	#var list_bitmask_str = Array(list_bitmask).map(
		#func (bitmask): 
			#return Morton.int_to_bin(bitmask))
	return list_bitmask
	
static func _get_x_column_flip_bitmask_by_subgrid_index(subgrid_idx: int):
	var start_x = Morton3.decode_vec3i(subgrid_idx).x
	var list_flip_index: PackedInt32Array = []
	for next_x in range(start_x, 4):
		list_flip_index.push_back(Morton3.set_x(subgrid_idx, next_x))
	var bitmask = _compress_subgrid_indexes_into_bitmask(list_flip_index)
	return bitmask



## Indexes of subgrid voxel that makes up a face of a layer-0 node
static var subgrid_voxel_indexes_on_face: Dictionary[StringName, PackedInt32Array] = {
	"xn": _get_subgrid_voxel_indexes_where_component_equals(Vector3i(0, -1, -1)),
	"xp": _get_subgrid_voxel_indexes_where_component_equals(Vector3i(3, -1, -1)),
	"yn": _get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1, 0, -1)),
	"yp": _get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1, 3, -1)),
	"zn": _get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1, -1, 0)),
	"zp": _get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1, -1, 3)),
}

static var bitmask_of_subgrid_voxels_on_face_xp: int = \
	_compress_subgrid_indexes_into_bitmask(
		_get_subgrid_voxel_indexes_where_component_equals(Vector3i(3, -1, -1)))

## Return all subgrid voxels which has morton code coordinate
## equals to some of [param v]'s x, y, z components.
## [br]
## [param v]'s component is -1 if you want to disable checking that component.
static func _get_subgrid_voxel_indexes_where_component_equals(v: Vector3i) -> PackedInt32Array:
	var result: PackedInt32Array = []
	for i in range(64):
		var mv = Morton3.decode_vec3i(i)
		if (v.x == -1 or mv.x == v.x) and\
			(v.y == -1 or mv.y == v.y) and\
			(v.z == -1 or mv.z == v.z):
			result.push_back(i)
	return result
	

## Each face of a node has 4 children. Their indexes are listed here.
## Each index are shifted 6 bits to be added to SVOLink index field directly
static var children_node_by_face: Dictionary[StringName, PackedInt64Array] = {
	"xn": _shift_to_svolink_index_field([0, 2, 4, 6]),
	"xp": _shift_to_svolink_index_field([1, 3, 5, 7]),
	"yn": _shift_to_svolink_index_field([0, 1, 4, 5]),
	"yp": _shift_to_svolink_index_field([2, 3, 6, 7]),
	"zn": _shift_to_svolink_index_field([0, 1, 2, 3]),
	"zp": _shift_to_svolink_index_field([4, 5, 6, 7]),
}
static func _shift_to_svolink_index_field(list_index: PackedInt64Array) -> PackedInt64Array:
	var new_list: PackedInt64Array = []
	new_list.resize(list_index.size())
	for i in range(new_list.size()):
		new_list[i] = list_index[i] << 6
	return new_list

## Used for hierarchical inside/outside propagation.
static var neighbor_node_x_column_bits_by_subgrid_index: Dictionary[int, int] = {
	Morton3.encode64(3,0,0): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,0,0))),
	Morton3.encode64(3,1,0): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,1,0))),
	Morton3.encode64(3,2,0): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,2,0))),
	Morton3.encode64(3,3,0): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,3,0))),
	Morton3.encode64(3,0,1): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,0,1))),
	Morton3.encode64(3,1,1): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,1,1))),
	Morton3.encode64(3,2,1): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,2,1))),
	Morton3.encode64(3,3,1): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,3,1))),
	Morton3.encode64(3,0,2): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,0,2))),
	Morton3.encode64(3,1,2): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,1,2))),
	Morton3.encode64(3,2,2): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,2,2))),
	Morton3.encode64(3,3,2): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,3,2))),
	Morton3.encode64(3,0,3): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,0,3))),
	Morton3.encode64(3,1,3): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,1,3))),
	Morton3.encode64(3,2,3): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,2,3))),
	Morton3.encode64(3,3,3): _compress_subgrid_indexes_into_bitmask(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1,3,3))),
}

static func _compress_subgrid_indexes_into_bitmask(list_index: PackedInt32Array) -> int:
	var bitmask: int = 0
	for idx in list_index:
		bitmask = bitmask | (1 << idx)
	return bitmask


### Indexes of subgrid voxel that makes up a face of a layer-0 node
#static var subgrid_voxel_bitmasks_on_face_zp: PackedInt64Array =\
	#_get_subgrid_voxel_bitmasks_from_indexes(_get_subgrid_voxel_indexes_where_component_equals(Vector3i(-1, -1, 3)))
#
#static func _get_subgrid_voxel_bitmasks_from_indexes(list_index: PackedInt32Array) -> PackedInt64Array:
	#var list_bitmask: PackedInt64Array = []
	#for idx in list_index:
		#list_bitmask.push_back(1 << idx)
	#return list_bitmask
