## Determines how "thick" the surface voxelization is.
class_name Separability

enum Enum {
	## Thin voxelization.[br]
	## [b]WARNING: [/b]Due to floating-point inaccuracy,
	## a water-tight object might have a non-water-tight voxel representation.[br]
	## Thus, it is recommended to also perform a solid voxelization.
	SEPARATING_6,

	## Conservative voxelization.[br]
	## The surface contains all voxels it cuts through, even merely touched.
	SEPARATING_26,
}
