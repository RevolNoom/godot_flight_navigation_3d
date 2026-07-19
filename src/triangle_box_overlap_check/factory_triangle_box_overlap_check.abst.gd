## Interface-like base for factories constructing triangle-box overlap tests.
## Concrete implementations pick the float32 or float64 [ATriangleBoxOverlapCheck] variant.
extends RefCounted
class_name AFactoryTriangleBoxOverlapCheck


## Initialize a new triangle-box test.[br]
## [br]
## [param v]: Positions of 3 triangle vertices.[br]
## [param dp]: Box size.
func create(
	_v0_f32: Vector3,
	_v1_f32: Vector3,
	_v2_f32: Vector3,
	_dp_f32: Vector3,
	_separability: Separability.Enum,
	_float_error_margin: float
) -> ATriangleBoxOverlapCheck:
	assert(false, "Not implemented")
	return null
