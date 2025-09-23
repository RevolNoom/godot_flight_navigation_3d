## A collection of multi-threading functions.
##
## All functions are await-able, thanks to async_context.
## async_context is a periodical signal.
## Most of the time, [member Node.get_tree().process_frame] is good.
@warning_ignore_start("integer_division")
extends RefCounted
class_name Parallel

## Count the number of elements in [param array_type]
## that equals to [param value], using operator==.
static func count(
	async_context: Signal,
	thread_priority: Thread.Priority,
	array_type: Variant,
	value: Variant,
	) -> int:
	var result: Dictionary = await Parallel.count_by_batch(
		async_context,
		thread_priority,
		array_type,
		value)
	var list_count_by_batch = result.list_count_by_batch
	
	var count_sum: int = 0
	for count_amount in list_count_by_batch:
		count_sum += count_amount
	return count_sum


## Divide tasks into batches.
## In each batch, count the number of elements in [param array_type]
## that equals to [param value], using operator==.
static func count_by_batch(
	async_context: Signal, 
	thread_priority: Thread.Priority,
	array_type: Variant,
	value: Variant,
	) -> Dictionary:
	var task_size = array_type.size()
	var max_batch_size = 200000
	var batch_count: int = _calculate_batch_count(task_size, max_batch_size)
	if batch_count == 0:
		return {}
	var batch_size: int = task_size/batch_count
	var list_count_by_batch: PackedInt64Array = []
	list_count_by_batch.resize(batch_count)
	list_count_by_batch.fill(0)
			
	await Parallel.execute_batched(
		async_context,
		task_size,
		thread_priority,
		max_batch_size,
		_parallel_count_by_batch.bind(
			list_count_by_batch,
			array_type,
			value
			))
	
	return {
		"batch_size": batch_size,
		"list_count_by_batch": list_count_by_batch,
	}



## Count the number of tasks that passes [param predicate].
static func count_if(
	async_context: Signal, 
	task_size: int,
	thread_priority: Thread.Priority,
	max_batch_size: int,
	predicate: Callable
	) -> int:
	var result: Dictionary = await Parallel.count_if_by_batch(
		async_context,
		task_size,
		thread_priority,
		max_batch_size,
		predicate)
	var list_count_if_by_batch = result.list_count_if_by_batch
	
	var count_sum: int = 0
	for count_amount in list_count_if_by_batch:
		count_sum += count_amount
	return count_sum


## Divide tasks into batches.
## In each batch, count the number of tasks that passes [param predicate].
static func count_if_by_batch(
	async_context: Signal, 
	task_size: int,
	thread_priority: Thread.Priority,
	max_batch_size: int,
	predicate: Callable
	) -> Dictionary:
	var batch_count: int = _calculate_batch_count(task_size, max_batch_size)
	if batch_count == 0:
		return {}
	var batch_size: int = task_size/batch_count
	var list_count_if_by_batch: PackedInt64Array = []
	list_count_if_by_batch.resize(batch_count)
	list_count_if_by_batch.fill(0)
			
	await Parallel.execute_batched(
		async_context,
		task_size,
		thread_priority,
		max_batch_size,
		_parallel_count_if_by_batch.bind(
			list_count_if_by_batch, 
			predicate, 
			batch_size))
	
	return {
		"batch_size": batch_size,
		"list_count_if_by_batch": list_count_if_by_batch,
	}


## Dedicate 1 thread to each task.
## Useful when the task is computationally expensive. 
## [param task] has the signature: func (task_index: int) -> void.
## [br]
## [param task] will be called with index from 0 to [param task_size] (exclusive)
static func execute(
	async_context: Signal, 
	task_size: int,
	thread_priority: Thread.Priority,
	task: Callable
):
	## Task id returned by [WorkerThreadPool]. 
	var list_task_id: PackedInt64Array = []
	list_task_id.resize(task_size)
	
	var is_high_priority: bool = thread_priority == Thread.Priority.PRIORITY_HIGH
	for task_index in range(list_task_id.size()):
		list_task_id[task_index] = WorkerThreadPool.add_task(
				task.bind(task_index), is_high_priority)
	
	for i in range(list_task_id.size()):
		var task_id = list_task_id[i]
		while true:
			# In case the owner is removed,
			# block the main thread until everything is resolved
			if WorkerThreadPool.is_task_completed(task_id):
				WorkerThreadPool.wait_for_task_completion(task_id)
				break
			await async_context


## Each thread will execute tasks in batch.
## Useful when the task is simple. 
## TODO: Example
## [br]
## [param task]: (batch_index: int, task_index_start: int, task_index_end: int) -> void.
## [br]
## [param max_batch_size] determines the maximum number of tasks that 1 batch can run.
static func execute_batched(
	async_context: Signal, 
	task_size: int,
	thread_priority: Thread.Priority,
	max_batch_size: int,
	task: Callable
):
	## Task id returned by [WorkerThreadPool]. 
	var list_task_id: PackedInt64Array = []
	list_task_id.resize(0)
	var batch_count = _calculate_batch_count(task_size, max_batch_size)
	if batch_count == 0:
		return
	list_task_id.resize(batch_count)
	
	var is_high_priority: bool = thread_priority == Thread.Priority.PRIORITY_HIGH
	var batch_size = task_size/batch_count
	for batch_index in range(list_task_id.size()):
		var batch_start = batch_index*batch_size
		var batch_end = mini((batch_index+1)*batch_size, task_size)
		list_task_id[batch_index] = WorkerThreadPool.add_task(
				task.bind(
					batch_index,
					batch_start, 
					batch_end),
					is_high_priority)
	
	for i in range(list_task_id.size()):
		var task_id = list_task_id[i]
		while true:
			# In case the owner is removed,
			# block the main thread until everything is resolved
			if WorkerThreadPool.is_task_completed(task_id):
				WorkerThreadPool.wait_for_task_completion(task_id)
				break
			await async_context

static func _parallel_for(task: Callable, start: int, end: int):
	for i in range(start, end):
		task.call(i)


static func _parallel_count_by_batch(
	batch_index: int,
	batch_start: int,
	batch_end: int,
	list_count_by_batch: PackedInt64Array,
	array_type: Variant,
	value: Variant) -> void:
		for array_index in range(batch_start, batch_end):
			list_count_by_batch[batch_index] += int(array_type[array_index] == value)


static func _parallel_count_if_by_batch(
	batch_index: int,
	batch_start: int,
	batch_end: int,
	list_count_if_by_batch: PackedInt64Array,
	predicate: Callable) -> void:
		for array_index in range(batch_start, batch_end):
			var predicate_result = int(predicate.call(array_index))
			list_count_if_by_batch[batch_index] += predicate_result


static func _calculate_batch_count(task_size: int, max_batch_size: int) -> int:
	return ceili(float(task_size)/max_batch_size)
