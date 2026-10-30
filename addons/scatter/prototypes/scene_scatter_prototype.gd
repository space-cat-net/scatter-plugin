@tool
@icon('res://addons/scatter/assets/scatter_prototype.svg')
class_name SceneScatterPrototype
extends BaseScatterPrototype
## Prototype instantiated as a full [PackedScene] node per point.
##
## Each instance is a scene tree node, so this backend supports scripts,
## signals, animations, and any node-based behavior. Expensive per instance -
## use only for interactive objects (chests, traps, pickups), not for mass
## decoration. For thousands of simple objects, prefer [MultiMeshScatterPrototype]
## or [IndividualScatterPrototype].


## Scene for all instances.
@export var scene: PackedScene
