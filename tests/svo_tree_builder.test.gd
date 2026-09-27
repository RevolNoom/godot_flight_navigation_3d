extends GutTest

class_name SvoTreeBuilderTest


func test_mortons_different_parent_identifies_siblings() -> void:
	# Nodes with same parent differ only in lowest 3 bits
	assert_false(SvoTreeBuilder.mortons_different_parent(0, 1))
	assert_false(SvoTreeBuilder.mortons_different_parent(0, 7))
	assert_false(SvoTreeBuilder.mortons_different_parent(8, 9))
	assert_false(SvoTreeBuilder.mortons_different_parent(8, 15))

	# Different parents
	assert_true(SvoTreeBuilder.mortons_different_parent(0, 8))
	assert_true(SvoTreeBuilder.mortons_different_parent(7, 8))
	assert_true(SvoTreeBuilder.mortons_different_parent(15, 16))


func test_init_svo_layers_and_layer_0() -> void:
	var svo := SVO.new()
	var depth := 4
	var layer_0_size := 16
	SvoTreeBuilder.init_svo_layers_and_layer_0(svo, depth, layer_0_size)

	assert_eq(svo.morton.size(), depth)
	assert_eq(svo.parent.size(), depth)
	assert_eq(svo.first_child.size(), depth)
	assert_eq(svo.xp.size(), depth)
	assert_eq(svo.morton[0].size(), layer_0_size)
	assert_eq(svo.first_child[0].size(), 0)
	assert_eq(svo.subgrid.size(), layer_0_size)
	assert_eq(svo.morton[0][0], SvoLink64.singleton.null_link())


func test_construct_svo_empty_returns_null() -> void:
	var builder := SvoTreeBuilder.new()
	var svo := await builder.construct_svo(
		get_tree().process_frame,
		PackedInt64Array(),
		3,
		false,
		Thread.PRIORITY_LOW
	)
	assert_null(svo)


func test_construct_svo_single_node() -> void:
	var builder := SvoTreeBuilder.new()
	var svo := await builder.construct_svo(
		get_tree().process_frame,
		PackedInt64Array([0]),
		3,
		false,
		Thread.PRIORITY_LOW
	)
	assert_not_null(svo)
	assert_eq(svo.morton.size(), 3)
	assert_eq(svo.morton[0].size(), 8)
	assert_eq(svo.morton[2].size(), 1)
	assert_eq(svo.morton[2][0], 0)
