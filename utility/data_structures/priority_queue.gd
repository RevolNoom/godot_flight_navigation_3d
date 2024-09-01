## A type of queue that arranges elements based on their priority values
##
## A priority queue is a special type of queue in which each element is associated
## with a priority value. And, elements are served on the basis of their priority.
## That is, higher priority elements are served first.[br]
##
## [PriorityQueue] orders its element based on a comparator [Callable]. Some default
## comparators are given in [Comparator] class. For user-defined datatype, usually
## you'll have to define your own comparator function.[br]
extends Object
class_name PriorityQueue

## Create a PriorityQueue with [param initial_values] that orders element by [param comp][br]
##
## [param comp]: a Callable of signature: 
## [code]func(a, b) -> bool[/code]
## that returns the order of two elements in the queue.  
## Default to [method Comparator.LESS] 
## ([method pop] and [method peek] returns the greatest element)
func _init(initial_values: Array = [], comp := Comparator.LESS):
	_comp = comp
	_heap = initial_values.duplicate()
	_size = _heap.size()
	for i in range(_size):
		_bubble_up(i)


## Return true if the PriorityQueue has no element
func is_empty() -> bool:
	return _size == 0


## Return the number of elements in the PriorityQueue
func size() -> int: 
	return _size


## Remove all elements from the PriorityQueue
func clear() -> void:
	_size = 0


## Return all elements in the queue sorted by [member _comp] as an Array 
func to_array() -> Array:
	var result = []
	result.resize(_size)
	result.resize(0)
	var duplicate_queue = PriorityQueue.new(_heap.slice(0, _size), _comp)
	for i in range(_size):
		result.push_back(duplicate_queue.pop())
	return result
	

## Add a new object into the tree
func push(obj: Variant):
	if _size == _heap.size():
		# size * 2 + 1
		_heap.resize((_size<<1) | 1)
	_heap[_size] = obj
	_bubble_up(_size)
	_size += 1


## Remove and return the object at the top of the queue[br]
## [b]WARNING:[/b] If PriorityQueue [method is_empty], [method pop] will crash
func pop() -> Variant:
	var result = _heap[0]
	_heap[0] = null
	_size -= 1
	_swap(0, _size)
	_slide_down(0)
	return result


## Return the object at the top of the queue without modifying it[br]
## [b]WARNING:[/b] If PriorityQueue [method is_empty], [method peek] will crash
func peek() -> Variant:
	return _heap[0]


# Return true if this node has at least 1 child
func _has_child(idx: int) -> bool:
	return (idx & ~1)>>1 < _size

# Return the left child of this node
func _left(idx: int) -> int:
	return (idx<<1) | 1

# Return the right child of this node
func _right(idx: int) -> int:
	return (idx<<1) + 2

# Return the parent of this node
# [b]WARNING:[/b] Not checking idx as root node
func _parent(idx: int) -> int:
	return (idx - 2 + idx%2)>>1


# Swap two elements at index [param i] and [param j] in the PriorityQueue
func _swap(i: int, j: int):
	var tmp = _heap[i]
	_heap[i] = _heap[j]
	_heap[j] = tmp


# Put the element at idx to its proper place in the PriorityQueue[br]
# The element starts from top
func _slide_down(idx: int):
	var l = _left(idx)
	if l >= _size:
		return
	var greatest_child = l 
	var r = _right(idx)
	if r < _size:
		greatest_child = r if _comp.call(_heap[l], _heap[r]) else l
	if _comp.call(_heap[idx], _heap[greatest_child]):
		_swap(idx, greatest_child)
		_slide_down(greatest_child)
		return


# TODO: Loop instead of recursing[br]
# Put the element at idx to its proper place in the PriorityQueue[br]
# The element starts from bottom
func _bubble_up(idx: int):
	var parent := _parent(idx)
	if idx == 0 or _comp.call(_heap[idx], _heap[parent]):
		return
		
	_swap(idx, parent)
	_bubble_up(parent)


var _heap: Array = []
# A Callable used to compare elements in pqueue 
var _comp: Callable
# Number of elements inside the heap
var _size: int


static func _automated_test():
	print("Starting Priority Queue Automated Test")
	var test_size = 1024
	var test = range(test_size)
	var result = PriorityQueue.new(test).flush()
	var expected = range(test_size-1, -1, -1)
	
	var errs = 0
	for i in range(0, result.size()):
		if result[i] != expected[i]:
			errs += 1
			printerr("result[%d] != expected[%d]:  %d != %d" % [i, i, result[i], expected[i]])
	
	if errs == 0:
		print("Priority Queue Automated Test completed without errors")
	else:
		printerr("Priority Queue Automated Test completed with %d error%s" % [errs, "" if errs == 1 else "s"])
		
