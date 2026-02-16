# Godot Flight Navigation 3D

## Project Overview

Godot Flight Navigation 3D provides flying and swimming navigation in free 3D space for Godot Engine. It builds a Sparse Voxel Octree (SVO) representing solid and empty space, and applies a Greedy A* algorithm for pathfinding.

## AI Assistant Workflow

1. **Understand Project Context**
   - Review this file and [README.md](README.md) for project details
   - Examine the project structure and key components
   - Note the supported Godot versions and system requirements

2. **Follow AI Context Guidelines**
   - Refer to [ai_context/AGENTS.md](ai_context/AGENTS.md) for the standard workflow
   - The AI context system provides structured guidance for development tasks

## Key Features

- **Multi-threaded CPU voxelization** for fast processing
- **Sparse Voxel Octree (SVO)** based navigation
- **Greedy A* algorithm** for efficient pathfinding
- Supports up to **9 layers of voxelization** (512 x 512 x 512) on 8GB RAM
- Works with various node types including CollisionObject3D and CSGShape3D
- Editor integration with single-click navigation data baking
- Customizable parameters for depth, voxelization, and resource format
- Debug visualization tools for SVO nodes and voxel occupancy

## Development Guidelines

- Follow the best practices defined in the ai_context directory
- Maintain clean, documented, and testable code
- Use GDScript for consistency with the existing codebase
- Keep performance in mind, especially for voxel operations
- Document any modifications to the SVO or pathfinding algorithms

## Getting Started

1. Clone the repository
2. Open the project in Godot 4.4.1 or 4.5 (check [README.md](README.md) for latest supported versions)
3. Review the [ai_context/AGENTS.md](ai_context/AGENTS.md) for development guidelines
4. Explore the editor tools for navigation data baking
5. Check the example scenes for implementation reference