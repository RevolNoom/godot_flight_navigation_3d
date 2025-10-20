# SVOLinkProbe

A runtime voxel/node inspection tool for FlightNavigation3D.

## Overview

SVOLinkProbe is a debugging and inspection tool that allows you to interactively query SVOLink information at runtime by pointing your mouse at positions in the 3D world.

## Features

- **Visual Probe Sphere**: A sphere mesh that follows your mouse cursor projected into 3D space
- **Click to Query**: Click to print detailed SVOLink information to the console
- **3D Label Display**: Click and hold to show SVOLink info in a 3D label at the probe position
- **Configurable Distance**: Adjust how far from the camera the probe projects
- **Customizable Appearance**: Configure sphere size, color, and label font size

## Setup

### Basic Setup

1. Add SVOLinkProbe as a child of a Camera3D node:
   ```
   Camera3D
   └── SVOLinkProbe
   ```

2. Assign a reference to your FlightNavigation3D in the inspector:
   - Select the SVOLinkProbe node
   - Set the `Flight Navigation` property to your FlightNavigation3D node

3. Run your scene and start inspecting!

### Example Scene Structure

```
Scene Root
├── Camera3D
│   └── SVOLinkProbe (script: svo_link_probe.gd)
└── FlightNavigation3D
```

## Usage

### Mouse Controls

- **Move Mouse**: Position the probe sphere in 3D space
- **Left Click**: Print SVOLink information to console
- **Click and Hold**: Display 3D label with SVOLink info

### Console Output

When you click, the console will display:
```
=== SVOLink Probe ===
SVOLink: 123456789
Layer: 0
Offset: 42
Subgrid: 15 (Vector3i(1, 2, 3))
Position: Vector3(1.5, 2.5, 3.5)
Is Solid: true
====================
```

### 3D Label Display

Click and hold to see a floating label showing:
```
SVOLink: 123456789
L:0 O:42 S:15
Solid: Yes
```

## Exported Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `probe_distance` | float | 10.0 | Distance from camera to project the probe sphere |
| `flight_navigation` | FlightNavigation3D | null | Reference to the FlightNavigation3D to query |
| `sphere_radius` | float | 0.1 | Size of the probe sphere indicator |
| `sphere_color` | Color | Yellow | Color of the probe sphere |
| `label_font_size` | int | 32 | Font size for the 3D label |
| `show_probe` | bool | true | Whether to show the probe sphere |

## Demo Scene

A demo scene is provided: `svo_link_probe_demo.tscn`

Run this scene to see SVOLinkProbe in action with:
- Camera controls (right-click drag to rotate, mouse wheel to zoom)
- A simple voxelized cube
- Full SVOLinkProbe functionality

## Requirements

- Must be a child of Camera3D
- Requires a valid FlightNavigation3D reference with built SVO data

## Notes

- The probe will return `SVOLink.NULL` for positions outside the navigation volume
- Solid state information is only available if the SVO was built with `perform_solid_voxelization = true`
- The probe updates in real-time as you move the mouse
