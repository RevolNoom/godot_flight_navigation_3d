# Godot Flight Navigation 3D 

This package provides flying/swimming navigation in free 3D space. It builds a
Sparse Voxel Octree representing the solid/empty state, and then applies Greedy
A* algorithm for path finding.

## General Information

- Tested on Godot versions: v4.5.beta2.official.e1b4101e3

## Features

- Multi-threading voxelization on CPU

- Upto 9 layers of voxelization (512 x 512 x 512) on 8GB RAM

- Works with many type of nodes:
	+ All CollisionObject3D nodes
	+ All CSGShape3D nodes
	+ Collision shape:
		* BoxShape3D
		* SphereShape3D
		* CapsuleShape3D
		* CylinderShape3D
		* ConcavePolygonShape3D
		* ConvexPolygonShape3D
	+ Mesh:
		* BoxMesh
		* SphereMesh
		* CapsuleMesh
		* CylinderMesh
		* ArrayMesh
		* TorusMesh

## How To Use

### Setup scene

- In your scene, add VoxelizationTarget as a child to any obstacle objects.
Note that all voxelize targets should be objects that never move, because of "No runtime update" limitation (see below).

![Obstacles setup](imgs/obstacles_setup.png "Obstacles setup")

- Create a FlightNavigation3D, and set $Extent.size property to encompass the navigation space

![FlightNavigation3D object setup](imgs/flight_navigation_object_setup.png "FlightNavigation3D object setup")

### Build navigation space

#### Using editor plugin

- Select FlightNavigation3D node. On editor toolbar, a "Voxelize" button will appear. 
Click the button to show the option dialog. 

	+ `Depth` controls how detailed the navigation space will be. 
	Memory and computational power consumption rises exponentially per depth level.
	It is recommended to start off small, and then increase depth only when you need finer-grained movement. 

	+ Resource file format should be one of Godot supported resource file extension (.tres or .res).

- Click "Start voxelization" to start the baking process. A progress popup will show. 
When it is done, you will see SVO resource in the Inspector tab.

![Bake navigation using editor plugin](imgs/bake_navigation.png "Bake navigation using editor plugin")

#### Using GDScript

```gdscript
	var params = FlightNavigation3DParameter.new()
	params.depth = 7
	var svo = await $FlightNavigation3D.build_navigation_data(params)
	$FlightNavigation3D.sparse_voxel_octree = svo

	# Use this for visual confirmation.
	$FlightNavigation3D.draw_debug_boxes()
```

### Find path between two positions in space

	```gdscript
	# find_path works with global positions. 
	var path = $FlightNavigation3D.find_path($Start.global_position, $End.global_position)

	# Use this for visual confirmation
	var svolink_path = Array(path).map(func(pos): return $FlightNavigation3D.get_svolink_of(pos))
	for svolink in svolink_path:
		$FlightNavigation3D.draw_svolink_box(svolink)
	```

![Find path - Result illustration](imgs/find_path_result_illustration.png "Find path - Result illustration")

### Write your own pathfinding algorithm

/TODO/

## Limitations

- No runtime update

By design, the SVO packs data tightly to save space and lookup neighbor quickly.
Thus, addition/removal/transformation of objects inside the navigation space 
cannot be updated trivially. You must re-voxelize every time there are 
relative movements of static objects to FlightNavigation3D. 

- No inside/outside state.

The SVO doesn't store information or provide a way to figure out whether a position
is inside an object. This could be a future improvement.

## Future Improvements

- Implement some tips and tricks from paper to speedup voxelization.

- Voxelization using GPU

## Credits

- Schwarz, M., Seidel, H.-P. 2010. Fast parallel surface and solid voxelization on GPUs. ACM Transactions on Graphics, 29, 6 (Proceedings of SIGGRAPH Asia 2010), Article 179: http://research.michael-schwarz.com/publ/2010/vox/

- 3D Flight Navigation Using Sparse Voxel Octrees, Daniel Brewer: https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter21_3D_Flight_Navigation_Using_Sparse_Voxel_Octrees.pdf

- Forceflow's code on triangle/box test, without whose work I would have been stuck,
	jerking hair out of my head wondering why my overlap test doesn't work:
	https://github.com/Forceflow/cuda_voxelizer/blob/main/src/cpu_voxelizer.cpp

### Modifications From Papers

#### SVOLink: 32-bit to 64-bit

SVO Link is originally an int32, packed with: 

+ 4 bits - layer index (0 to 15).

+ 22 bits - node index (0 to 4,194,303).

+ 6 bit - subnode index (0 to 63) (only used for indexing voxels inside leaf nodes).

SVO Link implemented in GDScript is int64, packed with:

+ 4 bits - layer index (0 to 15).

+ 54 bits - node index 

+ 6 bit - subnode index (0 to 63).

It was felt that 54 is a beautiful number that can represent a full space of 2^18 x 2^18 x 2^18 SVO Node.
Such requirements does not exist in real life. Therefore, the number of bits for layer and node index might change in the future.

#### Sparse voxel octree structure

Daniel Brewer's approach structures data into layers of SVO Nodes. 
Each node contains all relevant information to it (morton code, link to parents, link to neighbors,...).
Since GDScript does not support `struct` like C++, implementing SVO Node means it has to extends Object (or RefCounted/Resource).
Such implementation in GDScript faces a few drawbacks:

+ Billions of separate SVONode memory allocations would terribly fragments physical memory. 

+ Memory access takes 1 extra pointer jump (for a total of 3).

+ Redundant memory usage (inherited attributes from Object).

+ Sparse Voxel Octree cannot be serialized into Resource in a simple manner.

Drawbacks in general include:

+ SVO Node in the leaf layer has no children, only voxels. 
As such, 1 int64 (SVO Link to first child) of the most crowded layer is wasted for storing nothing.
With 64-bit SVOLink, this attribute can be used to store subgrid mask instead, 
but it makes logic hard to read and maintain.

After 2 overhauls, I have found the most simple data structure to work with GDScript:

![Compare old - new data structure](imgs/data_structure_old_compare_new.png "Compare old - new data structure")

Instead of packing all data into 1 big tree, each attribute of SVO Node splits into its own tree.
Each tree is an Array[PackedArray]. The advantages of this approach are:

+ Little redundant memory usage. There's only little extra overhead in arrays management.

+ Memory allocations are contiguous, can be easily pre-allocated.

+ Memory access takes only 2 pointer jumps.

+ Sparse Voxel Octree can be simply serialized, because PackedArray supports serialization.

+ Use only as much memory as needed. 
Things like coverage percentage (implemented in the future) can be turned on and off depending on the need of the game.

The disadvantages are:

+ Accessing data of a single node takes extra time, as its attributes are spread all over the places.
