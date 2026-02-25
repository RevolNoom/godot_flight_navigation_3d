extends GutTest

class_name FlightNavigation3DTest


func test_mortons_different_parent():
	var parent_morton: int = 0b101_010_111_000
	var left_child: int = (parent_morton << 3) | 0b001
	var right_child: int = (parent_morton << 3) | 0b110
	var result_same_parent: int = FlightNavigation3D._mortons_different_parent(
		left_child,
		right_child
	)
	assert_eq(result_same_parent, 0)

	var another_parent_morton: int = 0b101_010_111_001
	var child_from_another_parent: int = (another_parent_morton << 3) | 0b001
	var result_different_parent: int = FlightNavigation3D._mortons_different_parent(
		left_child,
		child_from_another_parent
	)
	assert_ne(result_different_parent, 0)
