extends GutTest

class_name ParallelTest


const STRESS_ENVIRONMENT_VARIABLE: String = "FN3D_RUN_PARALLEL_STRESS"


func _process_frame_signal() -> Signal:
	return get_tree().process_frame


func test_make_start_write_index_array_from_count_array() -> void:
	var input: PackedInt64Array = [2, 3, 1, 4]
	var expected: PackedInt64Array = [0, 2, 5, 6]
	var result: PackedInt64Array = Parallel.make_start_write_index_array_from_count_array(
		input)
	assert_eq(result, expected)


func test_count_by_batch_returns_single_batch_for_small_input() -> void:
	var async_context: Signal = _process_frame_signal()
	var input: PackedInt64Array = [2, 1, 2, 3, 2, 4, 2]
	var target: int = 2
	var result: Dictionary = await Parallel.count_by_batch(
		async_context,
		Thread.PRIORITY_LOW,
		input,
		target)

	assert_false(result.is_empty())
	assert_true(result.has("batch_size"))
	assert_true(result.has("list_count_by_batch"))
	assert_eq(result["batch_size"], input.size())
	assert_eq(result["list_count_by_batch"], PackedInt64Array([4]))


func test_count_by_batch_large_input_optional_stress() -> void:
	if OS.get_environment(STRESS_ENVIRONMENT_VARIABLE) != "1":
		pending("Set %s=1 to enable large multi-batch coverage." % STRESS_ENVIRONMENT_VARIABLE)
		return

	var async_context: Signal = _process_frame_signal()
	var input: PackedInt64Array = []
	input.resize(500000)
	for i in range(input.size()):
		input[i] = i % 100000
	var target: int = 2
	var result: Dictionary = await Parallel.count_by_batch(
		async_context,
		Thread.PRIORITY_LOW,
		input,
		target)

	assert_false(result.is_empty())
	assert_eq(result["batch_size"], 166667)
	assert_eq(result["list_count_by_batch"], PackedInt64Array([2, 2, 1]))



func test_count() -> void:
	var async_context: Signal = _process_frame_signal()
	var input: Array[int] = [1, 2, 2, 3, 2, 4]
	var target: int = 2
	var expected: int = 3
	var result: int = await Parallel.count(
		async_context,
		Thread.PRIORITY_LOW,
		input,
		target)
	assert_eq(result, expected)


func test_count_if_by_batch() -> void:
	var async_context: Signal = _process_frame_signal()
	var task_size: int = 8
	var max_batch_size: int = 4
	var result: Dictionary = await Parallel.count_if_by_batch(
		async_context,
		task_size,
		Thread.PRIORITY_LOW,
		max_batch_size,
		func(index: int) -> bool:
			return index % 2 == 0
	)

	assert_false(result.is_empty())
	assert_eq(result["batch_size"], 4)
	assert_eq(result["list_count_if_by_batch"], PackedInt64Array([2, 2]))


func test_count_if() -> void:
	var async_context: Signal = _process_frame_signal()
	var task_size: int = 8
	var max_batch_size: int = 4
	var expected: int = 4
	var result: int = await Parallel.count_if(
		async_context,
		task_size,
		Thread.PRIORITY_LOW,
		max_batch_size,
		func(index: int) -> bool:
			return index % 2 == 0
	)
	assert_eq(result, expected)



func test_execute() -> void:
	var async_context: Signal = _process_frame_signal()
	var task_size: int = 16
	var result: Array[int] = []
	result.resize(task_size)
	result.fill(-1)

	await Parallel.execute(
		async_context,
		task_size,
		Thread.PRIORITY_LOW,
		func(index: int) -> void:
			result[index] = index * 2
	)

	for i in range(task_size):
		assert_eq(result[i], i * 2)


func test_execute_batched() -> void:
	var async_context: Signal = _process_frame_signal()
	var task_size: int = 16
	var max_batch_size: int = 4
	var result: Array[int] = []
	result.resize(task_size)
	result.fill(-1)

	await Parallel.execute_batched(
		async_context,
		task_size,
		Thread.PRIORITY_LOW,
		max_batch_size,
		func(_batch_index: int, batch_start: int, batch_end: int) -> void:
			for i in range(batch_start, batch_end):
				result[i] = i * 3
	)

	for i in range(task_size):
		assert_eq(result[i], i * 3)


func test_count_if_by_batch_with_zero_task_size_returns_empty_dictionary() -> void:
	var async_context: Signal = _process_frame_signal()
	var task_size: int = 0
	var max_batch_size: int = 8
	var result: Dictionary = await Parallel.count_if_by_batch(
		async_context,
		task_size,
		Thread.PRIORITY_LOW,
		max_batch_size,
		func(_index: int) -> bool:
			return true
	)
	assert_true(result.is_empty())
