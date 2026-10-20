@tool
@icon('res://addons/scatter/assets/scatter_instance_cache.svg')
class_name ScatterData
extends Resource


## Baked output of [Scatter3D] generation.
##
## Stores instance transforms, per-instance type indices, and the seed used for
## generation in compact [PackedFloat32Array] / [PackedInt32Array] form - small
## enough to save with the scene without bloating it. [Scatter3D] reads this on
## [code]_enter_tree[/code] to spawn RIDs without re-running Poisson disk sampling.
##
## Created by [method Scatter3D.generate]. Do not edit manually.


# Per-instance cache
@export_storage var transforms: Array[Transform3D]
@export_storage var prototypes: PackedInt32Array

# Per-type cache
@export_storage var collision_shapes: Array[Shape3D]

# Individual cache
@export_storage var random_seed: int = -1
@export_storage var is_empty: bool = true:
	get():
		return transforms.is_empty()


func _get_property_list() -> Array[Dictionary]:
	var prop: Array[Dictionary] = []
	prop.append(
		#{
			#'name': &'',
			#'type': TYPE_,
			#'hint': PROPERTY_HINT_,
			#'hint_string': '',
		#},
		{
			'name': &'instance_count',
			'type': TYPE_STRING,
			'hint': PROPERTY_HINT_TYPE_STRING,
			'usage': 6 | PROPERTY_USAGE_READ_ONLY,
			'hint_string': '',
		},
	)
	
	prop.append(
		{
			'name': &'seed',
			'type': TYPE_STRING,
			'hint': PROPERTY_HINT_TYPE_STRING,
			'usage': 6 | PROPERTY_USAGE_READ_ONLY,
			'hint_string': '',
		},
	)
	
	return prop

func _get(property: StringName) -> Variant:
	if property == &'instance_count':
		return str(transforms.size())
	if property == &'seed':
		return str(seed)
	return
