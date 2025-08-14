extends Object
class_name Algorithm

## Return the index in the array where [param target_value] matches.
## [br]
## Return -1 if not found.
## [br]
## [b]NOTE 1:[/b] [param target_value] must supports operator<, operator==, operator!=
## (int, float, String, Vector, ...)
## [br]
## [b]NOTE 1:[/b] [param array] must be of type Array or PackedArray
## with elements of the same type as [param target_value].
## [br]
## [b]NOTE 2:[/b] It is assumed that [param array] is already sorted in ascending order.
static func binary_search(array, target_value: Variant) -> int:
	# Binary search to find the node with specified morton
	var array_size = array.size()
	if array_size == 0:
		return -1
		
	var begin: int = 0
	var end: int = array_size
	while begin != end:
		@warning_ignore("integer_division")
		var middle = (begin+end)/2
		var current_value = array[middle]
		if current_value < target_value:
			begin = middle + 1
		else:
			end = middle
			
	if begin == array_size:
		return -1
		
	if array[begin] != target_value:
		return -1
		
	return begin
