extends Object
class_name PriorityQueue


## @comp: func(a, b) -> bool, comparator of two elements
## Default to Less comparison. pop() returns the greatest element
## Use
func _init(comp := Comparator.LESS):
	_comp = comp
	_heap = []
	_size = 0


## TODO: Process an array in-place
static func from(array: Array, _comp := Comparator.LESS) -> PriorityQueue:
	var pq := PriorityQueue.new(Comparator.LESS)
	for obj in array:
		pq.push(obj)
	return pq


## Pop all elements in the queue into an Array
func to_array() -> Array:
	var result = []
	result.resize(_size)
	result.resize(0)
	while _size > 0:
		result.push_back(pop())
	return result
	

## Add a new object into the tree
func push(obj: Variant):
	if _size == _heap.size():
		# size * 2 + 1
		_heap.resize((_size<<1) | 1)
	_heap[_size] = obj
	_bubble_up(_size)
	_size += 1


## Pop the object at the top of the tree
## WARNING: Test size > 0 before doing this
func pop() -> Variant:
	var result = _heap[0]
	_heap[0] = null
	_size -= 1
	_swap(0, _size)
	_slide_down(0)
	return result


## Return true if this node has at least 1 child
## BUG: 
func _has_child(idx: int) -> bool:
	return (idx & ~1)>>1 < _size

## Return the left child of this node
func _left(idx: int) -> int:
	return (idx<<1) | 1


## Return the right child of this node
func _right(idx: int) -> int:
	return (idx<<1) + 2


## Return the parent of this node
## WARN: Not checking idx as root node
func _parent(idx: int) -> int:
	return (idx - 2 + idx%2)>>1


func _swap(i: int, j: int):
	var tmp = _heap[i]
	_heap[i] = _heap[j]
	_heap[j] = tmp


## Put the element at idx to its proper place in the pqueue
## The element starts from top
func _slide_down(idx: int):
	var l = _left(idx)
	if l >= _size:
		return
	var greatest_child = l 
	var r = _right(idx)
	if r < _size:
		greatest_child = r if _heap[l] < _heap[r] else l
	if _comp.call(_heap[idx], _heap[greatest_child]):
		_swap(idx, greatest_child)
		_slide_down(greatest_child)
		return


## TODO: Loop instead of recursing
## Put the element at idx to its proper place in the pqueue
## The element starts from bottom
func _bubble_up(idx: int):
	var parent := _parent(idx)
	if idx == 0 or _comp.call(_heap[idx], _heap[parent]):
		return
		
	_swap(idx, parent)
	_bubble_up(parent)

##
var _heap: Array = []
## A function used to compare elements in pqueue 
var _comp
## Number of elements inside the heap
var _size: int


static func _automated_test():
	print("Starting Priority Queue Automated Test")
	var test_size = 1024
	var test = range(test_size)
	var result = PriorityQueue.from(test).to_array()
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
		
