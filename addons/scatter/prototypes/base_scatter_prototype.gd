@tool
@abstract
@icon('res://addons/scatter/assets/base_scatter_prototype.svg')
class_name BaseScatterPrototype
extends Resource
## Abstract base for all scatter prototypes.
##
## Holds parameters that affect a single instance's placement and appearance:
## selection weight, spacing radius range, random offsets, surface alignment,
## filters (normal, height, density mask), and transform randomness. The render
## backend is provided by subclasses - see [IndividualScatterPrototype],
## [MultiMeshScatterPrototype], and [SceneScatterPrototype].
##
## Not usable on its own. Add a subclass instance to [member Scatter3D.prototypes].


#region Transform
@export_group('Transform')
## Relative offset of each instance.
@export_custom(PROPERTY_HINT_RANGE, '-1,1,0.001,hide_control,or_greater,suffix:m') var position_offset: Vector3 = Vector3.ZERO
## Random position jitter strength.
@export_custom(PROPERTY_HINT_RANGE, '0.01,100,0.001,or_greater,suffix:m,hide_control') var position_jitter: Vector3 = Vector3(0.0, 0.0, 0.0)
## Randomizing the rotation around the up axis of the source mesh.
@export_range(0, 180, 0.001, 'radians_as_degrees') var random_rotation: float = 0.0
## Randomizing the overall rotation of the source mesh.
@export_range(0, 180, 0.001, 'radians_as_degrees') var random_tilt: float = 0.0
## Randomizing the scale of the source mesh.
@export_range(0, 1024, 0.001, 'or_greater', 'hide_control') var random_scale: float = 0.0
## The scale of the source mesh that will be placed over the target surface.
@export_range(0.001, 1024, 0.001, 'or_greater', 'hide_control') var base_scale: float = 1.0
## 0 = keep world up (trees, grass), 1 = fully align to surface normal (rocks,
## decals). Values in between blend the two orientations.
@export_range(0.0, 1.0) var normal_alignment: float = 0.0
#endregion

#region Distribution
@export_group('Distribution')
## Relative weight for weighted random selection of the prototype when placing
## new points. Values are normalized across all prototypes in the scatter.
## [0, 1]; prototypes with weight 0 are never placed.
@export_range(0.0, 1.0, 0.001, 'or_greater', 'hide_control') var weight: float = 1.0
## Minimum Poisson disk radius in meters. Two instances of this prototype
## never spawn closer than this to each other.
@export_range(0.01, 100, 0.001, 'or_greater', 'suffix:m') var min_radius: float = 1.0
## Maximum Poisson disk radius in meters. Each instance's radius is sampled
## uniformly in [min_radius, max_radius].
@export_range(0.01, 100, 0.001, 'or_greater', 'suffix:m') var max_radius: float = 1.0
## Probability that a placed instance is randomly discarded after generation
## (0.0–1.0). Applied after the point is committed to the sampling grid.
## In JITTERED_GRID each cell is independent, so removal cleanly skips cells
## without affecting neighbors - the primary use case (sparse patches, worn
## spots, uneven debris). In POISSON_DISK removed points still occupy their
## grid slot and block neighbors, so the result is thinning with extra bake
## time spent on points that never appear - use sparingly.
## Random, not position-selective. For selective removal use the density mask.
@export_range(0.0, 1.0, 0.001) var removal_probability: float = 0.0
#endregion

#region Normal Filter
@export_group('Normal Filter', 'normal_filtering_')
## Restricts placement by surface slope. When enabled, candidates whose surface
## normal deviates from [member normal_filtering_normal] outside the
## [member normal_filtering_angle_min]–[member normal_filtering_angle_max] range
## are rejected. Useful for keeping trees off cliffs, grass off vertical walls,
## or rocks only on steep terrain.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, '') var normal_filtering_enabled: bool = false
## Reference direction used by the slope filter. Typically [constant Vector3.UP]
## for "flat ground" filtering. Set to a custom axis for tilted terrain, or
## [constant Vector3.DOWN] to accept only downward-facing surfaces.
@export var normal_filtering_normal: Vector3 = Vector3.UP
## Lower bound of the accepted deviation angle (in radians, shown as degrees in
## the inspector). Candidates with a smaller angle between their surface normal
## and [member normal_filtering_normal] are rejected. Use 0 to accept flat
## ground; raise it to exclude flat ground (e.g. rocks only on slopes ≥ 20°).
@export_range(0, 180, 0.001, 'radians_as_degrees') var normal_filtering_angle_min: float = 0.0
## Upper bound of the accepted deviation angle (in radians, shown as degrees in
## the inspector). Candidates whose surface normal deviates further from
## [member normal_filtering_normal] are rejected. Set to 180° to accept any
## orientation; set to 45° for "no slopes steeper than 45°".
@export_range(0, 180, 0.001, 'radians_as_degrees') var normal_filtering_angle_max: float = PI
#endregion

#region Height Filter
@export_group('Height Filter', 'height_filtering_')
## Restricts placement by world Y position. When enabled, candidates are
## weighted by [member height_filtering_curve] based on their Y coordinate.
## Useful for altitude-based distribution: dense grass in valleys, sparse bushes
## on peaks, snow only above a snowline.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, '') var height_filtering_enabled: bool = false
## Maps world Y position to a placement weight. Curve X axis is Y (relative to
## [member Scatter3D.scatter_size].y), Y axis is the weight: 0 = never place,
## 1 = full density. Values in between are treated as probability.
@export var height_filtering_curve: Curve
#endregion

#region Masking
@export_group('Masking')
## Enables density masking from [member density_mask]. When enabled, placement
## density in XZ is modulated by the texture — darker areas receive fewer
## instances, brighter areas more. Use to shape clearings, patches, or biome
## boundaries without drawing geometry.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, '') var masking_enabled: bool = false
## Density mask sampled over [member Scatter3D.scatter_size] in XZ. The red
## channel is used as a per-point placement weight: 0 (black) rejects the
## candidate, 1 (white) accepts it fully, values in between are treated as
## probability. Matches the sampling convention of [member MultiMeshScatterPrototype.colors_mask].
@export var density_mask: Texture2D
#endregion
