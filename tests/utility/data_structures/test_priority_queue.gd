extends GutTest

class_name PriorityQueueTest


func _assert_queue_pop_order(queue: PriorityQueue, expected: Array[int]) -> void:
	for i in range(expected.size()):
		assert_eq(queue.pop(), expected[i])


func test_pop_default_comparator_returns_descending_order() -> void:
	var input: Array[int] = [3, 1, 4, 1, 5, 9, 2]
	var expected: Array[int] = [9, 5, 4, 3, 2, 1, 1]
	var queue: PriorityQueue = PriorityQueue.new(input)

	_assert_queue_pop_order(queue, expected)

	assert_true(queue.is_empty())


func test_push_peek_and_size() -> void:
	var queue: PriorityQueue = PriorityQueue.new()
	assert_eq(queue.size(), 0)
	assert_true(queue.is_empty())

	queue.push(4)
	assert_eq(queue.peek(), 4)
	assert_eq(queue.size(), 1)

	queue.push(2)
	assert_eq(queue.peek(), 4)
	assert_eq(queue.size(), 2)

	queue.push(7)
	assert_eq(queue.peek(), 7)
	assert_eq(queue.size(), 3)


func test_clear_resets_queue_state() -> void:
	var queue: PriorityQueue = PriorityQueue.new([8, 6, 7, 5, 3, 0, 9])
	assert_false(queue.is_empty())
	assert_eq(queue.size(), 7)

	queue.clear()

	assert_true(queue.is_empty())
	assert_eq(queue.size(), 0)


func test_to_array_returns_sorted_values_without_mutating_queue() -> void:
	var input: Array[int] = [10, 4, 8, 2, 6]
	var expected: Array[int] = [10, 8, 6, 4, 2]
	var queue: PriorityQueue = PriorityQueue.new(input)

	var result: Array = queue.to_array()
	assert_eq(result, expected)
	assert_eq(queue.size(), input.size())
	assert_eq(queue.peek(), 10)

	_assert_queue_pop_order(queue, expected)


func test_pop_with_greater_comparator_returns_ascending_order() -> void:
	var input: Array[int] = [3, 1, 4, 1, 5, 9, 2]
	var expected: Array[int] = [1, 1, 2, 3, 4, 5, 9]
	var queue: PriorityQueue = PriorityQueue.new(input, Comparator.greater)

	_assert_queue_pop_order(queue, expected)

	assert_true(queue.is_empty())
