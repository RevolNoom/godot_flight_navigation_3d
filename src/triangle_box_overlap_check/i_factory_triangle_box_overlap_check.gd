extends RefCounted
class_name IFactoryTriangleBoxOverlapCheck

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
	_float_error_margin: float) -> ITriangleBoxOverlapCheck:
		return null
