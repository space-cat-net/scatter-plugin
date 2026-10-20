# Non-Destructive Scatter

Procedural object scattering for Godot 4. Uses Poisson disk sampling with variable radius,
projects onto mesh surfaces via TriangleMesh, and renders/physics instances directly
through RenderingServer and PhysicsServer3D - no Node per instance,
so tens of thousands of objects stay cheap.

## Features

- **Poisson disk sampling** - natural even distribution, no clumping, no gaps
- **Multiple prototypes** - grass, rocks, trees, etc. in one Scatter3D, each with its own mesh, collision, and radius
- **Variable radius** - each prototype picks a radius per instance in [min_radius, max_radius]; conflict rule is max(r1, r2)
- **Weighted random** - control relative frequency per prototype
- **Surface projection** - instances land on real mesh geometry, not a virtual plane
- **Filters** - by surface normal (slope), by height, by density mask
- **Baked data** - generation result is saved as a resource and re-spawned on scene load without regenerating
- **Direct server access** - RID created via RenderingServer / PhysicsServer3D; huge memory and time savings over nodes
- **Batched spawn with progress** - editor stays responsive even at 60k+ instances

## Install

1. Copy `addons/scatter3d/` into your project
2. Enable Scatter3D in `Project → Project Settings → Plugins`

## Quick start

1. Add a *MeshInstance3D*
2. Add a **Scatter3D** node as a child of your scene.
3. Set Scatter Size - X/Z define the sampling area, Y is the vertical raycast range.
4. Add one or more **ScatterPrototype** entries in Prototypes:
	- Mesh - visual
	- Collision Shape Mode - CONCAVE / CONVEX / CONVEX_SIMPLE / DISABLED / CUSTOM
	- Min Radius / Max Radius - Poisson disk spacing
5. Click **Bake Scatter3D** in the *Scatter3D* panel.

## How it works

- *Bake* runs Poisson disk sampling over the area, applies filters/masks modifiers, projects onto the mesh, writes to **ScatterData**.
- ScatterData is saved with the scene - reloading doesn't regenerate.
- *_enter_tree* spawns RIDs; *_exit_tree* frees them.

This separates expensive baking (seconds) from scene loading (must be fast).

## Demo

A demo scene is included at `test_scene/test.tscn` - a 400×400 m forest generated with `Scatter3D`,
with a first-person character to walk through it.
