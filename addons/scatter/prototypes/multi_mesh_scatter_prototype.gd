@tool
@icon('res://addons/scatter/assets/scatter_prototype.svg')
class_name MultiMeshScatterPrototype
extends MeshScatterPrototype
## Prototype rendered as a single [RenderingServer] MultiMesh instance.
##
## All instances of this prototype are drawn in one draw call - the fastest
## backend for large counts of simple geometry (coins, pebbles, grass, debris).
## Trade-offs: no per-instance frustum culling (the whole MultiMesh is culled
## as one AABB), no per-instance visibility range, and only a single surface
## of [member mesh] is supported. Physics is still per-instance via [PhysicsServer3D].
##
## Optionally supports per-instance colors - see [member color_mode].


enum ColorMode {
	## No per-instance color, the mesh's own vertex color is used.
	DISABLED,
	## Random color per instance, constrained by the HSV ranges below.
	RANDOM,
	## Color sampled from [member colors_mask] at the instance's XZ position.
	MASK,
	## Random color from [member colors_palette].
	PALETTE
}

@export_group('Colors', 'colors_')
## How per-instance colors are determined for this MultiMesh prototype.
@export var colors_mode: ColorMode = ColorMode.DISABLED:
	set(val): colors_mode = val; notify_property_list_changed()

## Lower bound of the hue range for [constant ColorMode.RANDOM] (0.0–1.0).
## Hue wraps around the color wheel: 0.0 = red, 0.33 = green, 0.66 = blue.
## Narrow a hue band to keep a consistent palette (e.g. 0.08–0.12 for warm
## autumn leaves); leave 0.0–1.0 for full rainbow. Ignored in other modes.
@export_range(0.0, 1.0, 0.001) var colors_random_hue_min: float = 0.0

## Upper bound of the hue range for [constant ColorMode.RANDOM] (0.0–1.0).
## Must be greater than [member colors_random_hue_min] — otherwise the range
## wraps around red (e.g. 0.9–0.1 gives reds and pinks).
@export_range(0.0, 1.0, 0.001) var colors_random_hue_max: float = 1.0

## Lower bound of the saturation range for [constant ColorMode.RANDOM] (0.0–1.0).
## Keep above 0 to avoid washed-out gray — 0.6 is a good floor for vivid colors.
@export_range(0.0, 1.0, 0.001) var colors_random_saturation_min: float = 0.0

## Upper bound of the saturation range for [constant ColorMode.RANDOM] (0.0–1.0).
## Values near 1.0 give fully saturated colors; drop below 1.0 for a softer look.
@export_range(0.0, 1.0, 0.001) var colors_random_saturation_max: float = 1.0

## Lower bound of the value (brightness) range for [constant ColorMode.RANDOM]
## (0.0–1.0). Values below ~0.3 make instances hard to read, especially in
## shadow — 0.6 is a safe floor.
@export_range(0.0, 1.0, 0.001) var colors_random_value_min: float = 0.0

## Upper bound of the value (brightness) range for [constant ColorMode.RANDOM]
## (0.0–1.0). 1.0 means some instances reach full brightness; lower it to keep
## the palette muted.
@export_range(0.0, 1.0, 0.001) var colors_random_value_max: float = 1.0

## Color mask for [constant ColorMode.MASK]. Sampled in XZ over the scatter
## area the same way as the density mask. Use an RGB texture for hand-painted
## variation (meadow, biome map). Alpha is ignored - only RGB is used.
@export var colors_mask: Texture2D

## Colors for [constant ColorMode.PALETTE]. If [member colors_palette_weights]
## is empty, all entries are equally likely.
@export var colors_palette: PackedColorArray = PackedColorArray([Color.WHITE])

## Optional weights for [member colors_palette]. Length must match
## [member colors_palette]. Values are normalized internally; an empty array
## means uniform selection. Useful for "80% green, 20% yellow" style mixes.
@export var colors_palette_weights: PackedFloat32Array = PackedFloat32Array()


func _validate_property(property: Dictionary) -> void:
	super(property)
	var random_fields := [
		"colors_random_hue_min", "colors_random_hue_max",
		"colors_random_saturation_min", "colors_random_saturation_max",
		"colors_random_value_min", "colors_random_value_max",
	]
	var mask_fields := ["colors_mask"]
	var palette_fields := ["colors_palette", "colors_palette_weights"]
	
	match colors_mode:
		ColorMode.DISABLED:
			_hide_properties(property, random_fields + mask_fields + palette_fields)
		ColorMode.RANDOM:
			_hide_properties(property, mask_fields + palette_fields)
		ColorMode.MASK:
			_hide_properties(property, random_fields + palette_fields)
		ColorMode.PALETTE:
			_hide_properties(property, random_fields + mask_fields)


func _hide_properties(property: Dictionary, names: Array) -> void:
	if property.name in names:
		property.usage &= ~PROPERTY_USAGE_EDITOR
