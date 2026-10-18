@tool
@icon('res://addons/scatter/assets/scatter_region.svg')
class_name ScatterShape3D
extends Node3D

enum RegionShapeType {
	## Use rectangular shape.
	BOX,
	## Use sphere shape.
	SPHERE,
	## Use 2D projected polygon as shape.
	POLYGON,
	## Use [Path3D] as source shape, and pass when distance
	## to curve less than given radius.
	## To use this type, add [Path3D] as a child node.
	PATH,
}

enum RegionMode {
	## Subtraction operator of shape, so instances will be generated when [i]not[/i]
	## inside this region.
	SUBTRACTION,
	## Intersection operator of shape, so instances will be generated [i]only[/i]
	## when inside this region.
	INTERSECTION,
}


@export var operator: RegionMode = RegionMode.SUBTRACTION:
	set(val):
		operator = val
		notify_property_list_changed()
		update_gizmos()
## Type of this shape.
@export var shape: RegionShapeType = RegionShapeType.BOX:
	set(val):
		shape = val
		notify_property_list_changed()
		update_gizmos()
@export_group('Shape Properties')
## Size of the box.
@export_custom(PROPERTY_HINT_RANGE, '0.001,512,0.001,hide_control,suffix:m') var box_size: Vector3 = Vector3(5, 5, 5):
	set(val):
		box_size = val.clampf(0.001, 512)
		update_gizmos()
## Radius of the sphere.
@export_range(0.001, 512, 0.001, 'hide_control', 'suffix:m') var sphere_radius: float = 2.5:
	set(val):
		sphere_radius = val
		update_gizmos()
## Radius of path. Min distance to path for instance to be removed.
@export_range(0.001, 512, 0.001, 'hide_control', 'suffix:m') var path_radius: float = 1.0:
	set(val):
		path_radius = val
		update_gizmos()
@export var polygon_points: PackedVector2Array = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
	set(val):
		polygon_points = val
		update_gizmos()
@export_range(0, 1024, 0.001, 'or_greater', 'suffix:m', 'hide_control') var polygon_depth: float = 5.0:
	set(val):
		polygon_depth = val
		update_gizmos()

@export_group('Randomization')
## Random threshold of removing instance. For example,
## 0.6 will remove only 60% of instances inside remover shape.
@export_range(0, 1, 0.001) var remove_probability: float = 1.0
## Random seed. Useless if [code]probability == 0[/code].
## If set to [code]-1[/code], will always randomize seed.
@export_range(-1, 1, 1, 'or_greater') var seed: int = -1


func _validate_property(property: Dictionary) -> void:
	if property.name.begins_with('sphere_') and shape != RegionShapeType.SPHERE:
		property.usage = PROPERTY_USAGE_NONE
	if property.name.begins_with('box_') and shape != RegionShapeType.BOX:
		property.usage = PROPERTY_USAGE_NONE
	if property.name.begins_with('path_') and shape != RegionShapeType.PATH:
		property.usage = PROPERTY_USAGE_NONE
	if property.name.begins_with('polygon_') and shape != RegionShapeType.POLYGON:
		property.usage = PROPERTY_USAGE_NONE


func _get_configuration_warnings() -> PackedStringArray:
	var errors = PackedStringArray()
	if shape == RegionShapeType.PATH and not is_instance_valid(_get_path()):
		errors.append('Shape set to path but this node doesn\'t have any child Path3D nodes.')
	elif shape == RegionShapeType.POLYGON and polygon_points.size() <= 2:
		errors.append('Polygon must have at least 3 points.')
	return errors


func _get_path() -> Path3D:
	for i in get_children():
		if is_instance_valid(i) and i is Path3D and is_instance_valid(i.curve):
			return i
	return null


func _is_point_inside_shape(point: Vector3, scatter: Scatter3D, random: RandomNumberGenerator) -> bool:
	var local_pos = to_local(point)
	var remove = false
	var path = _get_path()
	if shape == RegionShapeType.BOX:
		# Remove inside box
		remove = (
			abs(local_pos.x) <= ((box_size.x + scatter.density) * 0.5)
			and abs(local_pos.y) <= ((box_size.y + scatter.density) * 0.5)
			and abs(local_pos.z) <= ((box_size.z + scatter.density) * 0.5)
		)
	elif shape == RegionShapeType.SPHERE:
		# Remove inside sphere
		remove = local_pos.distance_squared_to(Vector3.ZERO) <= (sphere_radius + scatter.density) ** 2
	elif shape == RegionShapeType.PATH and is_instance_valid(path) and is_instance_valid(path.curve):
		# Remove along curve
		var path_local_pos = path.to_local(point)
		var path_point = path.curve.get_closest_point(path_local_pos)
		remove = path_point.distance_squared_to(path_local_pos) <= (path_radius + scatter.density) ** 2
	elif shape == RegionShapeType.POLYGON and polygon_points.size() > 2:
		var relative_point_2d = Vector2(local_pos.x, local_pos.z)
		if local_pos.y > 0 or local_pos.y < -polygon_depth:
			remove = false
			print(local_pos.y)
		else:
			remove = Geometry2D.is_point_in_polygon(relative_point_2d, polygon_points)
	
	# Skip randomly
	if random.randf() > remove_probability:
		remove = false
	
	# Flip value for intersection shape operator.
	if operator == RegionMode.INTERSECTION:
		remove = !remove
	
	return remove
