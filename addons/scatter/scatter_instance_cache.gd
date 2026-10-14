@tool
@icon('res://addons/scatter/assets/scatter_instance_cache.svg')
class_name ScatterInstanceCache
extends Resource


# Per-instance cache
@export_storage var cached_transforms: Array[Transform3D]
@export_storage var cached_instance_types: PackedInt32Array

# Per-type cache
@export_storage var cached_type_collision_shapes: Array[Shape3D]

# Individual cache
@export_storage var cached_seed: int = -1
@export_storage var is_empty: bool = true


## Resets all cache.
func reset() -> void:
	cached_transforms = []
	cached_instance_types = []
	cached_type_collision_shapes = []
	cached_seed = -1
	is_empty = true

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
		return str(cached_transforms.size())
	if property == &'seed':
		return str(cached_seed)
	return
