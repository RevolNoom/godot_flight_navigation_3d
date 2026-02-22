extends GutTest

class_name PriorityQueueTest


func test_pop_default_comparator_returns_descending_order():
	var input = [3, 1, 4, 1, 5, 9, 2]
	var expected = [9, 5, 4, 3, 2, 1, 1]
	var queue = PriorityQueue.new(input)

	for i in range(expected.size()):
		assert_eq(queue.pop(), expected[i])

	assert_true(queue.is_empty())


func test_push_peek_and_size():
	var queue = PriorityQueue.new()
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


func test_clear_resets_queue_state():
	var queue = PriorityQueue.new([8, 6, 7, 5, 3, 0, 9])
	assert_false(queue.is_empty())
	assert_eq(queue.size(), 7)

	queue.clear()

	assert_true(queue.is_empty())
	assert_eq(queue.size(), 0)


func test_to_array_returns_sorted_values_without_mutating_queue():
	var input = [10, 4, 8, 2, 6]
	var expected = [10, 8, 6, 4, 2]
	var queue = PriorityQueue.new(input)

	var result = queue.to_array()
	assert_eq(result, expected)
	assert_eq(queue.size(), input.size())
	assert_eq(queue.peek(), 10)

	for i in range(expected.size()):
		assert_eq(queue.pop(), expected[i])


func test_pop_with_greater_comparator_returns_ascending_order():
	var input = [3, 1, 4, 1, 5, 9, 2]
	var expected = [1, 1, 2, 3, 4, 5, 9]
	var queue = PriorityQueue.new(input, Comparator.greater)

	for i in range(expected.size()):
		assert_eq(queue.pop(), expected[i])

	assert_true(queue.is_empty())
