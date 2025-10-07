extends RefCounted
class_name Fn3dUtility

static func sum_array_number(array_type: Variant) -> Variant:
	var result: Variant = 0
	for element in array_type:
		result += element
	return result


## Count unique elements in a sorted array.
## [param sorted_array] must be sorted. If not, the result is undefined.
## Return the count of unique elements.
static func count_unique_element_on_sorted_array(sorted_array: Variant) -> int:
	if sorted_array.size() == 0:
		return 0

	if sorted_array.size() == 1:
		return 1

	var unique_count: int = 1
	for i in range(1, sorted_array.size()):
		if sorted_array[i] != sorted_array[i-1]:
			unique_count += 1

	return unique_count


## [param sorted_array] must be sorted. If not, the result is undefined.
## Return a new array, with no pair of elements equals to each other (using operator==).
static func make_sorted_array_become_unique_array(sorted_array: Variant) -> Variant:
	var unique_array = sorted_array.duplicate()
	
	if unique_array.size() <= 1:
		return unique_array

	var write_ptr: int = 1
	for read_ptr in range(1, unique_array.size()):
		if unique_array[read_ptr] != unique_array[read_ptr-1]:
			unique_array[write_ptr] = unique_array[read_ptr]
			write_ptr += 1
	unique_array.resize(write_ptr)

	return unique_array


## 
static func count_element_appearance_per_unique_element(sorted_array: Variant) -> PackedInt64Array:
	if sorted_array.size() == 0:
		return []

	if sorted_array.size() == 1:
		return [1]
		
	var unique_count = count_unique_element_on_sorted_array(sorted_array)
	
	var list_element_appearance_per_unique_element: PackedInt64Array = []
	list_element_appearance_per_unique_element.resize(unique_count)
	list_element_appearance_per_unique_element.fill(0)
	
	var write_ptr: int = 0
	var compare_element = sorted_array[0]
	for current_element_ptr in range(1, sorted_array.size()):
		var current_element = sorted_array[current_element_ptr]
		if compare_element != current_element:
			compare_element = current_element
			write_ptr += 1
		list_element_appearance_per_unique_element[write_ptr] += 1

	return list_element_appearance_per_unique_element
