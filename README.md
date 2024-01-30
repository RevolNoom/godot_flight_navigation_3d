# Godot Flight Navigation 3D 

/In development/

This package provides flying/swimming navigation in free 3D space. It builds a
Sparse Voxel Octree representing the solid/empty state, and then applies Greedy
A* algorithm for path finding.

## General Information

- Tested on Godot versions: 
	+ v4.2.1.stable.official.b09f793f5

## Features

- Multi-threading voxelization on CPU
- Upto 9 layers of voxelization (512 x 512 x 512) on 8GB RAM

## How To Use

/TODO/

### Write your own pathfinding algorithm

/TODO/

## Limitations

- No runtime update

By design, the SVO packs data tightly to save space and quick neighbor lookup.
Thus, addition/removal/transformation of objects inside the navigation space 
cannot be updated trivially, and you must re-voxelize the space every time. 

## Future Improvements

- Save/load resource file for SVO data
- Add some tips and tricks from paper to speedup voxelization
- GPU voxelization (? uhhhh I'm not sure how to do this with Godot yet. 
Will figure out later)

## Credits

- Schwarz, M., Seidel, H.-P. 2010. Fast parallel surface and solid voxelization on GPUs. ACM Transactions on Graphics, 29, 6 (Proceedings of SIGGRAPH Asia 2010), Article 179: http://research.michael-schwarz.com/publ/2010/vox/
- 3D Flight Navigation Using Sparse Voxel Octrees, Daniel Brewer: https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter21_3D_Flight_Navigation_Using_Sparse_Voxel_Octrees.pdf

### Modifications From Papers
/TODO/
