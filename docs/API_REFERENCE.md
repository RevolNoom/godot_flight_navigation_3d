# API Reference

This document summarizes the main classes, public methods, and notable caveats for the current Godot Flight Navigation 3D implementation.

It focuses on the existing runtime and tooling API without changing behavior.

## Reference conventions

- `SVOLink` means the packed integer link format used by `SvoLink32` or `SvoLink64`.
- `layer 0` refers to the leaf-node layer whose subgrid contains `4 x 4 x 4` voxels.
- Positions returned by `SVO` methods are in SVO-local voxel units, while `FlightNavigation3D` converts to and from scene-global coordinates.
- Internal helper methods are intentionally summarized rather than exhaustively restated when they are large or implementation-specific.

## High-level flow

1. `VoxelizationTarget` marks supported obstacle sources.
2. `SvoVoxelizer` gathers target geometry and bakes an `SVO`.
3. `FlightNavigation3D.build_navigation()` stores the baked `SVO`.
4. `FlightNavigation3D.find_path()` converts global coordinates to `SVOLink`s.
5. `FlightPathfinder` implementations, typically `GreedyAStar`, compute a link path.
6. `FlightNavigation3D` converts the resulting links back to global positions.

---

## `FlightNavigation3D`

Scene node that defines the navigable cubic volume and exposes the public runtime API used by games.

### Key exported properties

- `sparse_voxel_octree: SVO`  
  The currently assigned baked navigation resource.
- `pathfinder: FlightPathfinder`  
  Resource used for path queries.

### Main methods

| Method | Purpose |
| --- | --- |
| `find_path(from: Vector3, to: Vector3) -> PackedVector3Array` | Converts global positions to `SVOLink`s, rejects invalid or solid endpoints, delegates to the pathfinder, then converts the result back to global positions |
| `build_navigation()` | Awaits exactly one child `ISvoVoxelizer`, bakes an `SVO`, and assigns it to `sparse_voxel_octree` |
| `draw()` | Awaits every child `ISvoVisualizer` and lets each visualize the current SVO |
| `get_global_position_of(svolink: int) -> Vector3` | Converts a node or subgrid voxel link into a world-space center position |
| `get_svolink_of(gposition: Vector3) -> int` | Converts a world-space position into the smallest enclosing node/voxel link |
| `morton_origin_offset() -> Vector3` | Returns the local-space corner from which Morton coordinates are measured |
| `calculate_node_size(flight_navigation_size, layer, svo_depth) -> Vector3` | Static helper used by bake and query code to derive node size for a given layer |

### Important behavior

- `find_path()` expects global coordinates.
- If either endpoint is outside the volume, null, or solid, it returns an empty path.
- Endpoint solidity rejection is intentional and now covered by tests.
- `build_navigation()` requires exactly one child voxelizer. More than one is treated as ambiguous.
- `get_svolink_of()` warns in its docs that positions exactly on faces may resolve differently because of floating-point precision.

---

## `FlightPathfinder`

Abstract resource interface for pathfinding strategies.

### Main methods

| Method | Purpose |
| --- | --- |
| `find_path(from, to, svo) -> PackedInt64Array` | Public entry point for subclasses |
| `compute_cost(start, destination, svo) -> float` | Cost used for traversing edges |
| `estimate_cost(start, destination, svo) -> float` | Heuristic used during search |

### Override points

| Method | Default behavior |
| --- | --- |
| `_find_path()` | Abstract, prints an error if not overridden |
| `_compute_cost()` | Euclidean distance between centers |
| `_estimate_cost()` | Euclidean distance between centers |

### Helper methods

| Method | Purpose |
| --- | --- |
| `compute_size_compensation_factor(node_layer, svo_depth)` | Lowers movement cost through larger nodes |
| `euclidean(pos1, pos2)` | Euclidean distance helper |
| `manhattan(pos1, pos2)` | Manhattan distance helper |
| `get_centers(svolink1, svolink2, svo)` | Returns the centers of two nodes/voxels |
| `get_closest_faces(svolink1, svolink2, svo)` | Currently warns once and falls back to `get_centers()` |

### Caveat

- `get_closest_faces()` is not implemented. Documentation and tests should treat it as a compatibility fallback, not a finished feature.

---

## `GreedyAStar`

Default `FlightPathfinder` implementation.

### Key exported properties

- `endpoints`  
  Currently only `Voxel Centers` is supported.
- `distance_function`  
  `Euclidean` or `Manhattan`.
- `w`  
  Heuristic bias weight.
- `use_size_compensation_factor`  
  Reduces traversal cost through large nodes.
- `use_unit_cost`  
  Uses `unit_cost` instead of geometric distance.
- `unit_cost`  
  Flat traversal cost when enabled.

### Main methods

| Method | Purpose |
| --- | --- |
| `_find_path(start, destination, svo)` | Searches the SVO neighbor graph using a frontier priority queue |
| `_compute_cost(start, destination, svo)` | Computes traversal cost with optional size compensation |
| `_estimate_cost(start, destination, svo)` | Computes weighted heuristic cost |

### Important behavior and caveats

- The serialized endpoint option `Face Centers` is no longer honored. Setting it is normalized back to `Voxel Centers` for backward compatibility.
- `use_unit_cost` is explicitly marked TODO in the source and should be treated as experimental.
- The code notes that `w = 2` can freeze the search. Keep tuning conservative until that issue is fully investigated.

---

## `ISvo`

Abstract resource contract for SVO storage and queries.

It defines the interface expected by pathfinding, debug tools, and bake logic.

### Main API groups

- Structural accessors: layer count, node count, Morton values, parents, children, neighbors
- Occupancy accessors: inside flags, flip flags, coverage
- Query helpers: centers, neighbors, face contents, Morton lookup, solid tests
- Aggregate helpers: solid bit counts and parallel counting

### Notes

- All methods assert if called on the abstract base directly.
- `SVO` is the concrete implementation used by the project.

---

## `SVO`

Concrete sparse voxel octree resource stored as packed parallel arrays.

### Main exported data

| Property | Meaning |
| --- | --- |
| `morton` | Morton code per node, grouped by layer |
| `parent` | Parent link per node |
| `first_child` | First child link per node, or null for leaf/terminal nodes |
| `subgrid` | 64-bit occupancy bitmask for leaf-node subgrid voxels |
| `xp`, `yp`, `zp`, `xn`, `yn`, `zn` | Neighbor links by axis direction |
| `inside` | Inside/outside state per node when solid voxelization is available |
| `flip` | Debug or intermediate propagation flags |
| `coverage` | Experimental coverage values |

### Main methods

| Method | Purpose |
| --- | --- |
| `support_query_solid()` | True when inside/outside data is available |
| `support_query_coverage()` | True when coverage data exists |
| `get_layer_count()` / `set_layer_count()` | Resize and inspect layer count |
| `get_node_count_in_layer()` / `set_node_count_in_layer()` | Resize and inspect node counts |
| `get_svolink_from_node_morton(layer, morton3_value)` | Finds a node link by Morton code |
| `get_svolink_from_voxel_morton(morton3_value)` | Finds a leaf subgrid voxel link by Morton code |
| `get_neighbors_of(svolink)` | Returns six-direction adjacency expanded to the highest available resolution |
| `is_solid(layer_or_svolink, index = -1)` | Tests node or voxel solidity |
| `get_center(svolink)` | Returns node/voxel center in SVO-local voxel units |
| `get_node_center(svolink)` | Returns center of a node |
| `get_voxel_center(svolink)` | Alias of `get_center()` for voxel-oriented callers |
| `get_voxels_and_nodes_on_face_xp/...` | Expands a face into the highest-resolution links that cover it |
| `get_solid_bit_counts_by_subgrid()` | Returns per-leaf-node solid voxel counts as `PackedInt32Array` |
| `parallel_get_solid_bit_counts_by_subgrid()` | Parallel version of the same count query |
| `deep_compare(other)` | Deep structural comparison for tests and validation |

### Important behavior

- `support_inside` is derived from whether the `inside` array is populated.
- `is_solid()` supports both whole-node queries and leaf-subgrid voxel queries.
- For branch nodes, solidity means the node is inside and has no children.
- `get_center()` uses internal voxel-unit coordinates; `FlightNavigation3D` is responsible for mapping those units into scene space.

### Caveats

- The data structure is optimized for read/query performance after bake, not for incremental mutation.
- Coverage support exists but is still marked experimental.

---

## `ISvoVoxelizer`

Abstract node interface for baking an `SVO` from scene geometry.

### Signal

- `progress(step, svo, work_completed, total_work)`  
  Emitted during bake stages.

### Key exported configuration

- Multi-threading flags and thread priority
- Voxelization mask and preprocessing options
- Layer count and resource format
- float64 support toggle
- Solid voxelization controls
- Surface voxelization controls
- Debug cleanup flags

### Main methods

| Method | Purpose |
| --- | --- |
| `voxelize(fn3d) -> SVO` | Abstract bake entry point |
| `get_resolution()` | Returns `2 ** (layer_count + 1)` |

### Notes

- `set_layer_count()` clamps values to the supported `[2, 15]` range.
- Concrete implementations are expected to be reentrant when invoked asynchronously.

---

## `SvoVoxelizer`

Concrete bake pipeline implementation.

### Public method

| Method | Purpose |
| --- | --- |
| `voxelize(fn3d) -> SVO` | Validates input, runs the bake pipeline, and returns a new `SVO` |

### Pipeline summary

The internal pipeline includes:

- target discovery
- mesh and triangle preparation
- thin-triangle filtering
- SVO construction
- optional solid voxelization and inside/outside propagation
- optional surface voxelization
- optional coverage calculation

### Important behavior and caveats

- Configuration is copied into local variables near the start of the bake so that concurrent runs are safer.
- `support_float64` selects the float64 triangle-box overlap implementation, but upstream Godot mesh and transform data still originates from float32 values.
- Precision differences between float32 and float64 bake paths remain a known investigation area.

---

## `VoxelizationTarget`

Scene marker used to include supported geometry in voxelization.

### Exported properties

- `voxelization_mask`
- `radial_segments`
- `rings`

### Main methods

| Method | Purpose |
| --- | --- |
| `get_csg() -> Array[CSGShape3D]` | Converts the parent node into one or more CSG shapes for baking |

### Supported parent/source types

- `CollisionObject3D`
- `CollisionShape3D`
- `MeshInstance3D`
- `CSGShape3D`

### Supported shape and mesh conversion highlights

- Box, sphere, capsule, cylinder, convex polygon, concave polygon
- BoxMesh, SphereMesh, CapsuleMesh, CylinderMesh, ArrayMesh, TorusMesh

### Caveats

- `MultiMeshInstance3D` is recognized but currently not converted.
- The node expects identity local transform and warns when it is offset.
- Mask matching is done against the voxelizer mask, allowing multiple navigation systems to coexist in one scene.

---

## `Fn3dLookupTable`

Static lookup table container for common SVO face and bit operations.

### Main data groups

| Data | Purpose |
| --- | --- |
| `subgrid_voxel_indexes_on_face` | Maps each face to the 16 leaf subgrid indices touching that face |
| `children_node_by_face` | Maps each face to the 4 child offsets touching that face |
| `bit_1_count_by_u8` | Small popcount lookup table |
| `x_column_flip_bitmask_by_subgrid_index` | Used during solid voxelization rasterization and flip propagation |
| `neighbor_node_x_column_bits_by_subgrid_index` | Used by inside/outside propagation logic |

### Notes

- Tables are generated and validated by `Fn3dLookupTableGenerator` and then made read-only in `_static_init()`.

---

## `Fn3dLookupTableGenerator`

Utility class that generates lookup tables used by `Fn3dLookupTable`.

### Main methods

| Method | Purpose |
| --- | --- |
| `generate_lut_bit_1_count_by_u8()` | Builds the popcount table |
| `generate_lut_subgrid_voxel_indexes_on_face()` | Builds face-to-subgrid index mappings |
| `generate_lut_children_node_by_face()` | Builds face-to-child offset mappings |
| `generate_x_column_flip_bitmask_by_subgrid_index()` | Builds subgrid flip bitmasks |
| `generate_lut_neighbor_node_x_column_bits_by_subgrid_index()` | Builds neighbor propagation lookup data |

This class is primarily useful for validation, regeneration, and documentation of the packed tables.

---

## `ISvoLink`, `SvoLink32`, and `SvoLink64`

Helpers for packing and unpacking node-layer, node-offset, and subgrid information into integers.

### Common API

| Method | Purpose |
| --- | --- |
| `null_link()` | Sentinel null value |
| `create(layer, index, subgrid = 0)` | Packs a link |
| `get_layer(svolink)` / `set_layer(...)` | Layer access |
| `get_offset(svolink)` / `set_offset(...)` | Offset access |
| `get_subgrid(svolink)` / `set_subgrid(...)` | Subgrid access |

### Notes

- `SvoLink64` is the primary runtime format used throughout the project.
- `SvoLink32` remains available for comparison, reference, and utility/test coverage.
- `SvoLink64` also exposes debug helpers such as formatted and binary string output.

---

## Triangle-box overlap checker family

These classes support rasterization by testing whether a triangle overlaps a voxel-aligned box.

### `ITriangleBoxOverlapCheck`

Abstract overlap contract.

#### Main methods

| Method | Purpose |
| --- | --- |
| `overlap_voxel(minimum_corner)` | Full overlap test composed from the plane and projection tests |
| `plane_overlaps(minimum_corner)` | Plane-vs-box test |
| `projection_xy_overlaps(minimum_corner)` | XY projection overlap |
| `projection_yz_overlaps(minimum_corner)` | YZ projection overlap |
| `projection_zx_overlaps(minimum_corner)` | ZX projection overlap |
| `x_projection_on_plane(...)`, `y_projection_on_plane(...)`, `z_projection_on_plane(...)` | Projection helpers |

### `TriangleBoxOverlapCheckF32`

float32 implementation. Faster and aligned with Godot's native vector precision.

### `TriangleBoxOverlapCheckF64`

float64-oriented implementation using helper double-vector utilities.

### Factory classes

| Class | Purpose |
| --- | --- |
| `IFactoryTriangleBoxOverlapCheck` | Abstract factory interface |
| `FactoryTriangleBoxOverlapCheckF32` | Creates `TriangleBoxOverlapCheckF32` instances |
| `FactoryTriangleBoxOverlapCheckF64` | Creates `TriangleBoxOverlapCheckF64` instances |

### Caveat

- The presence of float64 overlap math does not by itself eliminate all precision issues, because scene geometry enters from Godot-side float32 structures.

---

## Visualizer family

Optional scene nodes used for debugging and inspection.

### `ISvoVisualizer`

Abstract base with one required method:

| Method | Purpose |
| --- | --- |
| `draw(fn3d)` | Visualizes data from a `FlightNavigation3D` instance |

### `SvoVisualizerLayer`

Draws SVO nodes by layer, with per-layer enable flags and multithreaded transform generation.

#### Main methods

- `draw(fn3d)`
- `set_draw_layer(layer_index, enabled)`
- `get_draw_layer(layer_index)`

### `SvoVisualizerLink`

Draws specific nodes and voxels identified by `SVOLink`.

#### Main methods

- `draw(fn3d)`
- `add_node(svolink, label_text = "")`
- `add_voxel(svolink, label_text = "")`
- `remove_node(svolink)`
- `remove_voxel(svolink)`

### `SvoVisualizerSubgrid`

Draws subgrid voxels using multimesh instances for leaf visualization.

### Notes

- Visualizers are optional helpers for debugging, editor workflows, and demonstrations.
- `FlightNavigation3D.draw()` will call all child visualizers, not just one.

---

## Tests as behavioral reference

Several behaviors documented above are explicitly backed by tests under `tests/`, including:

- `FlightNavigation3D.build_navigation()` assigning the result of a single voxelizer child
- `FlightNavigation3D.find_path()` rejecting solid endpoints
- `FlightNavigation3D` link/position round-tripping for leaf centers
- `GreedyAStar` normalizing unsupported `Face Centers` back to `Voxel Centers`
- `FlightPathfinder.get_closest_faces()` warning and falling back to centers
- `SVO.is_solid()` handling both voxel and node queries

When runtime behavior and prose ever drift apart, the tests should be treated as the more authoritative source.

---

## Outstanding gaps

- The project still has many large internal helper functions inside `SvoVoxelizer`; this reference documents their purpose at the pipeline level rather than every private helper signature.
- Precision behavior across float32 and float64 rasterization paths remains a future investigation topic.
- Some engine-facing debug helpers and editor plugin scripts are intentionally omitted from the main API summary because they are secondary to the runtime integration surface.
