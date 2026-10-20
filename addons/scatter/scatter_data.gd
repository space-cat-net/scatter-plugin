@tool
@icon('res://addons/scatter/assets/scatter_instance_cache.svg')
class_name ScatterData
extends Resource


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
