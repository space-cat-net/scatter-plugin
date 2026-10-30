@tool
@icon('res://addons/scatter/assets/scatter_prototype.svg')
class_name IndividualScatterPrototype
extends MeshScatterPrototype
## Prototype rendered as one independent [RenderingServer] instance per point.
##
## Supports per-instance visibility range, frustum culling, and individual
## shadow/GI settings - the most flexible backend, but slowest at very high
## instance counts. Each instance is backed by a [RID] created in [RenderingServer]
## and (if collision is enabled) a [RID] in [PhysicsServer3D].
##
## Use for complex geometry, mixed LOD, or scenes where instances need to
## appear/disappear independently (e.g. trees in a forest).
