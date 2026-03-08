extends RefCounted
class_name IFactoryTriangleBoxOverlapCheck


func _abstract_fail(method_name: String) -> void:
	var message: String = "IFactoryTriangleBoxOverlapCheck.%s() is abstract. Override in subclass." % method_name
	push_error(message)
	assert(false, message)


## Initialize a new triangle-box test.[br]
## [br]
## [param v]: Positions of 3 triangle vertices.[br]
## [param dp]: Box size.
func create(
	_v0_f32: Vector3,
	_v1_f32: Vector3,
	_v2_f32: Vector3,
	_dp_f32: Vector3,
	_separability: ITriangleBoxOverlapCheck.Separability,
	_float_error_margin: float
) -> ITriangleBoxOverlapCheck:
	_abstract_fail("create")
	return null
