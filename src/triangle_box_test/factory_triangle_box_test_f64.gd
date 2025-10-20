extends FactoryTriangleBoxTest
class_name FactoryTriangleBoxTestF64

## Initialize a new triangle-box test.[br]
## [br]
## [param v]: Positions of 3 triangle vertices.[br]
## [param dp]: Box size.
func create(
	v0_f32: Vector3, 
	v1_f32: Vector3, 
	v2_f32: Vector3, 
	dp_f32: Vector3, 
	separability: TriangleBoxTest.Separability,
	epsilon_value: float) -> TriangleBoxTest:
		return TriangleBoxTestF64.new(
			v0_f32,
			v1_f32,
			v2_f32,
			dp_f32,
			separability,
			epsilon_value
		)
