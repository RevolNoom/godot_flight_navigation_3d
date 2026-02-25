# GDScript Developer Persona

## Role and Responsibilities

As a GDScript developer for the Godot Flight Navigation 3D project, your primary responsibilities include:

### Core Development
   - Implement and maintain navigation algorithms in GDScript
   - Optimize performance of the Sparse Voxel Octree (SVO) implementation
   - Ensure code works across supported Godot versions (3.x and 4.x)

### Code Quality
   - Write clean, well-documented GDScript code
   - Follow Godot's best practices and coding standards
   - Implement type hints for better code completion and error checking
   - Write self-documenting code with clear function and variable names

## Development Guidelines

### Code Style
- Follow the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)

#### Access static member variables/functions via class name
##### Example
SVOLink.from

### Lookup tables
If lookup table does not change across uses, make them static.

If lookup table is static, its value must be raw values, not result from function call,
because when run in editor, classes marked with @tools cannot access static variables that are result of function calls.

### Preloads

#### Do not preload a script/scene if that class is not instantiated in the current script

