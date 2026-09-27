## Constructs SVO tree hierarchies bottom-up and resolves neighbor links.
@tool
extends RefCounted
class_name SvoTreeBuilder

signal progress(
	step: ProgressStep.Enum,
	svo: SVO,
	work_completed: int,
	total_work: int
)


## Builds an [SVO] tree from grouped Morton codes at layer 1.[br]
## [param async_context]: Signal for awaiting async execution frames.[br]
## [param list_node_1_morton_grouped]: Layer 1 active node Morton codes.[br]
## [param depth]: Total octree depth.[br]
## [param multi_threading_enabled]: Whether to run parallel jobs.[br]
## [param multi_threading_priority]: Thread priority for parallel jobs.[br]
## Return: Fully constructed and linked [SVO], or null if input is empty.[br]
func construct_svo(
	async_context: Signal,
	list_node_1_morton_grouped: PackedInt64Array,
	depth: int,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority
) -> SVO:
	var svo: SVO = SVO.new()
	progress.emit(ProgressStep.Enum.CONSTRUCT_SVO, svo, 0, 2)

	if list_node_1_morton_grouped.size() == 0:
		return null

	var list_node_1_morton_sorted: PackedInt64Array = list_node_1_morton_grouped.duplicate()
	list_node_1_morton_sorted.sort()

	var layer_0_size: int = list_node_1_morton_sorted.size() * 8
	init_svo_layers_and_layer_0(svo, depth, layer_0_size)

	var current_active_layer_nodes: PackedInt64Array = list_node_1_morton_sorted
	var parent_idx: PackedInt64Array = current_active_layer_nodes.duplicate()

	for layer: int in range(1, depth):
		for i: int in range(current_active_layer_nodes.size()):
			for child: int in range(8):
				svo.morton[layer - 1][i * 8 + child] = (current_active_layer_nodes[i] << 3) | child

		parent_idx[0] = 0

		if layer == depth - 1:
			init_root_layer(svo, layer)
		else:
			for i: int in range(1, current_active_layer_nodes.size()):
				parent_idx[i] = parent_idx[i - 1]
				if mortons_different_parent(
					current_active_layer_nodes[i - 1],
					current_active_layer_nodes[i]
				):
					parent_idx[i] += 1

			var current_layer_size: int = (parent_idx[parent_idx.size() - 1] + 1) * 8
			allocate_svo_layer_arrays(svo, layer, current_layer_size)

		for active_node_idx: int in range(current_active_layer_nodes.size()):
			var active_node_offset: int = 8 * parent_idx[active_node_idx] + (current_active_layer_nodes[active_node_idx] & 0b111)
			svo.first_child[layer][active_node_offset] = SvoLink64.singleton.create(layer - 1, 8 * active_node_idx)
			var link_to_parent: int = SvoLink64.singleton.create(layer, active_node_offset)
			for child: int in range(8):
				svo.parent[layer - 1][8 * active_node_idx + child] = link_to_parent

		var new_active_layer_nodes: PackedInt64Array = []
		if current_active_layer_nodes.size() > 0:
			new_active_layer_nodes.resize(current_active_layer_nodes.size())
			new_active_layer_nodes.resize(0)
			new_active_layer_nodes.push_back(current_active_layer_nodes[0] >> 3)

			for morton: int in current_active_layer_nodes:
				var parent_code: int = morton >> 3
				if new_active_layer_nodes[new_active_layer_nodes.size() - 1] != parent_code:
					new_active_layer_nodes.push_back(parent_code)

		current_active_layer_nodes = new_active_layer_nodes
		parent_idx.resize(current_active_layer_nodes.size())

	progress.emit(ProgressStep.Enum.CONSTRUCT_SVO, svo, 1, 2)

	await fill_neighbor_links(
		svo,
		async_context,
		multi_threading_enabled,
		multi_threading_priority
	)

	progress.emit(ProgressStep.Enum.CONSTRUCT_SVO, svo, 2, 2)
	return svo


static func init_svo_layers_and_layer_0(svo: SVO, depth: int, layer_0_size: int) -> void:
	svo.morton.resize(depth)
	svo.parent.resize(depth)
	svo.first_child.resize(depth)
	svo.xp.resize(depth)
	svo.yp.resize(depth)
	svo.zp.resize(depth)
	svo.xn.resize(depth)
	svo.yn.resize(depth)
	svo.zn.resize(depth)

	svo.morton[0].resize(layer_0_size)
	svo.parent[0].resize(layer_0_size)
	svo.first_child[0].resize(0)
	svo.subgrid.resize(layer_0_size)
	svo.xp[0].resize(layer_0_size)
	svo.yp[0].resize(layer_0_size)
	svo.zp[0].resize(layer_0_size)
	svo.xn[0].resize(layer_0_size)
	svo.yn[0].resize(layer_0_size)
	svo.zn[0].resize(layer_0_size)

	svo.morton[0].fill(SvoLink64.singleton.null_link())
	svo.parent[0].fill(SvoLink64.singleton.null_link())
	svo.xp[0].fill(SvoLink64.singleton.null_link())
	svo.yp[0].fill(SvoLink64.singleton.null_link())
	svo.zp[0].fill(SvoLink64.singleton.null_link())
	svo.xn[0].fill(SvoLink64.singleton.null_link())
	svo.yn[0].fill(SvoLink64.singleton.null_link())
	svo.zn[0].fill(SvoLink64.singleton.null_link())


static func init_root_layer(svo: SVO, layer: int) -> void:
	svo.morton[layer].resize(1)
	svo.parent[layer].resize(1)
	svo.first_child[layer].resize(1)
	svo.xp[layer].resize(1)
	svo.yp[layer].resize(1)
	svo.zp[layer].resize(1)
	svo.xn[layer].resize(1)
	svo.yn[layer].resize(1)
	svo.zn[layer].resize(1)

	svo.morton[layer][0] = 0
	svo.parent[layer][0] = SvoLink64.singleton.null_link()
	svo.first_child[layer][0] = SvoLink64.singleton.create(layer - 1, 0)
	svo.xp[layer][0] = SvoLink64.singleton.null_link()
	svo.yp[layer][0] = SvoLink64.singleton.null_link()
	svo.zp[layer][0] = SvoLink64.singleton.null_link()
	svo.xn[layer][0] = SvoLink64.singleton.null_link()
	svo.yn[layer][0] = SvoLink64.singleton.null_link()
	svo.zn[layer][0] = SvoLink64.singleton.null_link()


static func allocate_svo_layer_arrays(
	svo: SVO,
	layer: int,
	current_layer_size: int
) -> void:
	svo.morton[layer].resize(current_layer_size)
	svo.parent[layer].resize(current_layer_size)
	svo.first_child[layer].resize(current_layer_size)
	svo.xp[layer].resize(current_layer_size)
	svo.yp[layer].resize(current_layer_size)
	svo.zp[layer].resize(current_layer_size)
	svo.xn[layer].resize(current_layer_size)
	svo.yn[layer].resize(current_layer_size)
	svo.zn[layer].resize(current_layer_size)

	svo.morton[layer].fill(~0)
	svo.parent[layer].fill(SvoLink64.singleton.null_link())
	svo.first_child[layer].fill(SvoLink64.singleton.null_link())
	svo.xp[layer].fill(SvoLink64.singleton.null_link())
	svo.yp[layer].fill(SvoLink64.singleton.null_link())
	svo.zp[layer].fill(SvoLink64.singleton.null_link())
	svo.xn[layer].fill(SvoLink64.singleton.null_link())
	svo.yn[layer].fill(SvoLink64.singleton.null_link())
	svo.zn[layer].fill(SvoLink64.singleton.null_link())


func fill_neighbor_links(
	svo: SVO,
	async_context: Signal,
	multi_threading_enabled: bool,
	multi_threading_priority: Thread.Priority
) -> void:
	var list_neighbor_direction: Array = [
		svo.xn, svo.yn, svo.zn,
		svo.xp, svo.yp, svo.zp
	]
	var list_next_neighbor_calculator: Array[Callable] = [
		Morton3.dec_x, Morton3.dec_y, Morton3.dec_z,
		Morton3.inc_x, Morton3.inc_y, Morton3.inc_z
	]
	if multi_threading_enabled:
		await Parallel.execute(
			async_context,
			list_neighbor_direction.size(),
			multi_threading_priority,
			_parallel_fill_neighbor_in_direction.bind(
				svo,
				list_neighbor_direction,
				list_next_neighbor_calculator
			)
		)
	else:
		for i: int in range(list_neighbor_direction.size()):
			_parallel_fill_neighbor_in_direction(
				i,
				svo,
				list_neighbor_direction,
				list_next_neighbor_calculator
			)


static func mortons_different_parent(m1: int, m2: int) -> bool:
	return ((m1 ^ m2) & 0x7FFF_FFFF_FFFF_FFF8) != 0


static func parallel_fill_neighbor_in_direction(
	index: int,
	svo: SVO,
	list_neighbor_direction: Array,
	list_next_neighbor_calculator: Array[Callable]
) -> void:
	_parallel_fill_neighbor_in_direction(
		index,
		svo,
		list_neighbor_direction,
		list_next_neighbor_calculator
	)


static func _parallel_fill_neighbor_in_direction(
	index: int,
	svo: SVO,
	list_neighbor_direction: Array,
	list_next_neighbor_calculator: Array[Callable]
) -> void:
	var neighbor_direction = list_neighbor_direction[index]
	var next_neighbor_calculator = list_next_neighbor_calculator[index]
	for layer in range(svo.depth - 2, -1, -1):
		for offset in range(svo.morton[layer].size()):
			var current_node_morton = svo.morton[layer][offset]
			var parent_svolink = svo.parent[layer][offset]
			var parent_layer = SvoLink64.singleton.get_layer(parent_svolink)
			var parent_offset = SvoLink64.singleton.get_offset(parent_svolink)
			var parent_first_child_offset = offset & ~0b111

			var neighbor_morton = next_neighbor_calculator.call(current_node_morton)

			if mortons_different_parent(neighbor_morton, current_node_morton):
				var parent_neighbor_svolink = neighbor_direction[parent_layer][parent_offset]

				if parent_neighbor_svolink == SvoLink64.singleton.null_link():
					neighbor_direction[layer][offset] = SvoLink64.singleton.null_link()
					continue

				var parent_neighbor_layer = SvoLink64.singleton.get_layer(parent_neighbor_svolink)

				if parent_layer != parent_neighbor_layer:
					neighbor_direction[layer][offset] = parent_neighbor_svolink
					continue

				var parent_neighbor_offset = SvoLink64.singleton.get_offset(parent_neighbor_svolink)

				if parent_neighbor_layer == 0 or\
					svo.first_child[parent_neighbor_layer][parent_neighbor_offset] == SvoLink64.singleton.null_link():
					neighbor_direction[layer][offset] = parent_neighbor_svolink
					continue

				var parent_neighbor_first_child_svolink = svo.first_child[parent_neighbor_layer][parent_neighbor_offset]
				var child_link_offset: int = (SvoLink64.singleton.get_offset(parent_neighbor_first_child_svolink) & ~0b111) | (neighbor_morton & 0b111)
				neighbor_direction[layer][offset] = SvoLink64.singleton.create(parent_layer - 1, child_link_offset)
				continue
			else:
				neighbor_direction[layer][offset] = SvoLink64.singleton.create(layer, parent_first_child_offset | (neighbor_morton & 0b111))
