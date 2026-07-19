## Stages reported while building the sparse voxel octree, in execution order.
class_name ProgressStep

enum Enum {
	## Collecting every mesh/collision target to voxelize.
	GET_ALL_VOXELIZATION_TARGET,

	## Building the combined triangle mesh from targets.
	BUILD_MESH,

	## Discarding triangles too thin to contribute voxels.
	REMOVE_THIN_TRIANGLES,

	## Translating vertices into the octree's local coordinate space.
	OFFSET_VERTICES_TO_LOCAL_COORDINATE,

	## Marking which layer-1 nodes are active.
	DETERMINE_ACTIVE_LAYER_1_NODES,

	## Constructing the sparse voxel octree structure.
	CONSTRUCT_SVO,

	## Flagging voxels inside the solid geometry.
	SOLID_VOXELIZATION,

	## Propagating inside/outside flags through the hierarchy.
	HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION,

	## Rasterizing triangles onto the YZ plane.
	YZ_PLANE_RASTERIZATION,

	## Preparing flip flags and head nodes.
	PREPARE_FLAGS_AND_HEAD_NODES,

	## Propagating bit flips along the +X axis.
	XP_BIT_FLIP_PROPAGATION,

	## Preparing the layer-1 flip flags.
	PREPARE_FLIP_FLAG_LAYER_1,

	## Flipping layer-1 flags bottom-up.
	FLIP_BOTTOM_UP_LAYER_1,

	## Propagating layer-1 flip information.
	PROPAGATE_FLIP_INFORMATION_LAYER_1,

	## Preparing flip flags from layer 2 upward.
	PREPARE_FLIP_FLAG_FROM_LAYER_2,

	## Flipping flags bottom-up from layer 2.
	FLIP_BOTTOM_UP_FROM_LAYER_2,

	## Propagating flip information from layer 2.
	PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2,

	## Propagating inside flags top-down for tree nodes.
	PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES,

	## Propagating inside flags to subgrid voxels.
	PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS,

	## Flagging voxels on the solid surface.
	SURFACE_VOXELIZATION,

	## Computing the per-voxel coverage factor.
	CALCULATE_COVERAGE_FACTOR,

	## Sentinel marking the number of steps.
	MAX_STEP,
}
