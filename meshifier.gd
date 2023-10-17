extends Object

class_name Meshifier

func get_box_triangles(body, body_shape_index):
	var body_shape_owner = body.shape_find_owner(body_shape_index)
	var body_shape_node = body.shape_owner_get_owner(body_shape_owner)
