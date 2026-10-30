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

@export_group('Normal Filter', 'normal_filtering_')
## Enables normal filtering, so instances can't generate on
## steep surfaces, For example, don't spawn trees on
## mountains.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, '') var normal_filtering_enabled: bool = false
## Reference normal used by the surface-orientation filter. A candidate point
## is rejected if dot(surface_normal, filter_normal) < filter_threshold.
@export var normal_filtering_normal: Vector3 = Vector3.UP
## Maximum angle in radians between the surface normal and `filter_normal`.
## Candidates whose surface normal deviates more than this are rejected.
@export_range(0, 360, 0.001, 'radians_as_degrees') var normal_filtering_angle: float = deg_to_rad(15)
@export_group('Height Filter', 'height_filtering_')
## Enables height filtering, so instances will be placed only in given
## range on global vertical (Y) axis.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, '') var height_filtering_enabled: bool = false
## Minimum height, on which instances will be generated. In global space.
@export_range(-1024, 1024, 0.001, 'or_greater', 'or_less', 'suffix:m') var height_filtering_min_height: float = 0
## Maximum height, on which instances will be generated. In global space.
@export_range(-1024, 1024, 0.001, 'or_greater', 'or_less', 'suffix:m') var height_filtering_max_height: float = 10
@export_group('Masking')
## Enables scattering masking using texture.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, '') var masking_enabled: bool = false
## Mask texture for scattering. In darker areas there will be less instances, in bright areas - more.
## Used red texture channel.
@export var density_mask: Texture2D
