@tool
@abstract
@icon('res://addons/scatter/assets/base_scatter_prototype.svg')
class_name MeshScatterPrototype
extends BaseScatterPrototype
## Abstract base for prototypes that render a shared [Mesh] through
## [RenderingServer] (individual instances or a MultiMesh).
##
## Holds mesh, optional collision shape, render layers, shadow casting, GI mode,
## LOD bias, and visibility range settings shared by all mesh-based backends.


enum CollisionShapeMode {
	## Do not generate collision for instance.
	DISABLED,
	## Generate concave or trimesh collision for the mesh.
	CONCAVE,
	## Generate convex collision for the mesh.
	CONVEX,
	## Generate simplified convex collision for mesh.
	CONVEX_SIMPLE,
	## Use value of [member collision_shape] as collision shape.
	CUSTOM
}

#region Geometry
@export_group('Geometry')
## Visual mesh for this prototype.
@export var mesh: Mesh
## See [member GeometryInstance3D.cast_shadow]
@export var cast_shadow: RenderingServer.ShadowCastingSetting\
= RenderingServer.ShadowCastingSetting.SHADOW_CASTING_SETTING_ON
## See [member GeometryInstance3D.custom_aabb]
@export var custom_aabb: AABB
## See [member GeometryInstance3D.lod_bias]
@export_range(0.001, 128.0, 0.001) var lod_bias: float = 1.0
## See [member GeometryInstance3D.gi_mode]
@export var gi_mode: GeometryInstance3D.GIMode = GeometryInstance3D.GIMode.GI_MODE_DISABLED
## See [member VisualInstance3D.layers]
@export_flags_3d_render var layers: int = 0b00000000_00000000_00000000_00000001
#endregion

#region Geometry/Visibility Range
@export_group('Geometry/Visibility Range', 'visibility_range_')
## See [member GeometryInstance3D.visibility_range_begin]
@export_range(0, 4096, 0.001, 'or_greater', 'suffix:m')
var visibility_range_begin: float = 0.0
## See [member GeometryInstance3D.visibility_range_begin_margin]
@export_range(0, 4096, 0.001, 'or_greater', 'suffix:m')
var visibility_range_begin_margin: float = 0.0
## See [member GeometryInstance3D.visibility_range_end]
@export_range(0, 4096, 0.001, 'or_greater', 'suffix:m')
var visibility_range_end: float = 0.0
## See [member GeometryInstance3D.visibility_range_end_margin]
@export_range(0, 4096, 0.001, 'or_greater', 'suffix:m')
var visibility_range_end_margin: float = 0.0
## See [member GeometryInstance3D.visibility_range_fade_mode]
@export var visibility_range_fade_mode: RenderingServer.VisibilityRangeFadeMode\
= RenderingServer.VisibilityRangeFadeMode.VISIBILITY_RANGE_FADE_DISABLED
#endregion

#region Collision
@export_group('Collision', 'collision_')
## How to generate the collision shape for each instance. CUSTOM requires
## `collision_shape` to be set; other modes derive the shape from `mesh`.
@export var collision_shape_mode: CollisionShapeMode = CollisionShapeMode.DISABLED:
	set(val): collision_shape_mode = val; notify_property_list_changed()
## Custom collision shape, used only when `collision_shape_mode == CUSTOM`.
## Shared across all instances of this prototype (one shape RID per prototype).
@export var collision_shape: Shape3D
## See [member CollisionObject3D.collision_layer]
@export_flags_3d_physics var collision_layer: int = 0b00000000_00000000_00000000_00000001
## See [member CollisionObject3D.collision_mask]
@export_flags_3d_physics var collision_mask: int = 0b00000000_00000000_00000000_00000001
#endregion


func _validate_property(property: Dictionary) -> void:
	if property.name in [&'collision_shape']\
		and collision_shape_mode != CollisionShapeMode.CUSTOM:
			property.usage = PROPERTY_USAGE_NONE
	if property.name in [&'collision_layer', &'collision_mask']\
		and collision_shape_mode == CollisionShapeMode.DISABLED:
			property.usage = PROPERTY_USAGE_NONE
