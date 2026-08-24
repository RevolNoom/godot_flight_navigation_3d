extends AFactoryTriangleBoxOverlapCheck
class_name FactoryTriangleBoxOverlapCheckF64

## Initialize a new triangle-box test.[br]
## [br]
## [param v]: Positions of 3 triangle vertices.[br]
## [param dp]: Box size.
func create(
	v0_f32: Vector3, 
	v1_f32: Vector3, 
	v2_f32: Vector3, 
	dp_f32: Vector3, 
	separability: Separability.Enum,
	float_error_margin: float) -> ATriangleBoxOverlapCheck:
		return TriangleBoxOverlapCheckF64.new(
			v0_f32,
			v1_f32,
			v2_f32,
			dp_f32,
			separability,
			float_error_margin
		)
