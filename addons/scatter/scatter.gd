@tool
@icon('res://addons/scatter/assets/scatter.svg')
class_name Scatter3D
extends Node3D


## 3D mesh and collision scattering implementation.
##
## Configurable solution for scattering objects on surface.
## Supports collisions, randomization, filtering and masking.


## Maximum number of generated instances
const MAX_INSTANCES = 65536

## Maximum seconds to generate instances
const MAX_GENERATION_TIME = 120 * 1000

## Maximum try count for Poisson disk sampling.
const MAX_POINT_ATTEMPTS = 16

enum CollisionShapeMode {
	## Disable any collisions for this type of instance.
	DISABLED,
	## Use concave (trimesh) collisions. Most accurate way,
	## but slow at runtime. For more see [ConcavePolygonShape3D]
	CONCAVE,
	## Use convex collision, less acurate then convex,
	## but way faster.
	CONVEX,
	## Use convex collisions, but simplified.
	## The least accurate but has fastest generation.
	CONVEX_SIMPLE,
	## Use custom collisions, fastest
	## way, because don't need to generate shapes.
	CUSTOM
}

#region Properties
## List of instance types Scatter3D can generate. See [ScatterInstanceType]
@export var instance_types: Array[ScatterInstanceType] = []
## Source mesh, on which surface instances will be generated.
@export_node_path('MeshInstance3D') var source_mesh_path: NodePath
## Seed of random numbers used by scatterer. Set to [code]-1[/code]
## for random seed every generation.
## [br][b]Notice:[/b] if set to [code]-1[/code], it will randomize
## every generation but [b]not[/b] population. Population uses
## generation cache, so it will be same.
@export_range(-1, 1, 1, 'or_greater') var generator_seed: int = -1
@export_range(0, 100, 0.001, 'or_greater', 'suffix:m') var radius: float = 1.0
## Dimensions of a box, inside which instances will be scattered.
@export_custom(PROPERTY_HINT_RANGE, '0.001,512,0.001,hide_control,suffix:m') var boundaries: Vector3 = Vector3(20, 10, 20):
	set(val):
		boundaries = val.clampf(0.001, 512)
		update_gizmos()
## Max distance between scattered instances.
@export_range(0.1, 32, 0.001, 'suffix:m', 'or_greater') var density: float = 1.0
## Generation probability threshold. For example,
## if set to 0.5, only 50% of possible instances will
## be placed.
@export_range(0, 1, 0.001) var distribution_mask: float = 0.8
## Cached instance data; can be exported as a file.
@export var cache: ScatterInstanceCache
#endregion

# RenderingServer instances
var _instances: Array[RID]
# PhysicsServer3D instances
var _colliders: Array[RID]
var _bodies: Array[RID]

# Generation arrays
var _subtractions: Array[ScatterShape3D] = []
var _types: PackedInt32Array = []
var _weights: PackedFloat32Array = []
var _masks: Array[Image] = []


func _enter_tree() -> void:
	populate_instances()

func _exit_tree() -> void:
	clear_instances()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			populate_instances()
		else:
			clear_instances()
	if what == NOTIFICATION_PREDELETE:
		clear_instances()

## Generate transforms and save them to cache.
## If [code]populate[/code] is [code]true[/code]
## it will automatically call [method populate_instances]
## after generation.
func generate_transforms(populate: bool = true) -> void:
	var time = Time.get_ticks_msec()
	# Clear cache and remove instances
	clear_instances()
	clear_cache()
	
	# Getting source mesh
	var source_mesh_instance: MeshInstance3D = get_node_or_null(source_mesh_path)
	# Push error when source mesh isn't valid
	if not is_instance_valid(source_mesh_instance):
		push_error('Can\'t generate data because source mesh is null.')
		if Engine.is_editor_hint():
			EditorInterface.get_editor_toaster().push_toast(
				'Can\'t generate data because source mesh is null.',
				EditorToaster.Severity.SEVERITY_ERROR,
				'Set "source_mesh_path" property to generate data.'
			)
		return
	
	var source_mesh: Mesh = source_mesh_instance.mesh
	var source_triangle_mesh: TriangleMesh = source_mesh.generate_triangle_mesh()
	
	# Parse types and weights
	_types.clear()
	_weights.clear()
	_masks.clear()
	
	# Generate collision shapes
	# WARNING: Native collision generation is slow
	var shape: Shape3D
	for idx in range(instance_types.size()):
		if is_instance_valid(instance_types[idx]):
			var type = instance_types[idx]
			_types.append(idx)
			_weights.append(type.generation_weight)
			if type.masking_enabled:
				_masks.append(type.masking_texture.get_image())
			else:
				_masks.append(null)
			
			if type.collision_shape_mode == CollisionShapeMode.CONCAVE:
				# Trimesh (Concave)
				shape = type.mesh.create_trimesh_shape()
			elif type.collision_shape_mode == CollisionShapeMode.CONVEX:
				# Convex
				shape = type.mesh.create_convex_shape(true, false)
			elif type.collision_shape_mode == CollisionShapeMode.CONVEX_SIMPLE:
				# Convex simplified
				shape = type.mesh.create_convex_shape(true, true)
			elif type.collision_shape_mode == CollisionShapeMode.CUSTOM:
				# Custom
				shape = type.collision_shape
			else:
				# No collisions
				shape = null
			
			# Add shape to list
			cache.cached_type_collision_shapes.append(shape)
		else:
			push_error('Can\'t generate data. Instance types are invalid.')
			return
	
	# Getting all subtractions
	_subtractions.clear()
	for i in get_children():
		if is_instance_valid(i) and i is ScatterShape3D:
			_subtractions.append(i)
	
	# Create random generator
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	# Set its seed
	random.seed = generator_seed
	if generator_seed == -1:
		random.seed = randi()
	
	cache.cached_seed = random.seed
	
	# Define variables
	var loop: int
	var point: Vector3
	var type: int
	var is_inside_remover: bool
	
	var points: Array = []
	var point_angle: float
	var point_on_grid: Vector2i
	var can_place: bool
	
	var grid_size: float = radius / (1.4142135623730951 * 0.999)
	var grid_width = ceili(boundaries.x / grid_size) + 2
	var grid_depth = ceili(boundaries.z / grid_size) + 2
	var grid_min = -boundaries * 0.5
	var grid_points: PackedVector3Array = []
	grid_points.resize(grid_width * grid_depth)
	grid_points.fill(Vector3.INF)
	
	
	var active_points: PackedVector3Array = [
		Vector3(boundaries.x * 0.25, 0, boundaries.z * 0.25),
	]
	print(active_points)
	var active_point: Vector3
	var tries: int
	
	var raycast: Dictionary = {}
	var local_ray_pos: Vector3
	var texture_mask_value: float
	var texture_mask_size: Vector2i
	
	var xform: Transform3D
	var type_data: ScatterInstanceType
	
	# Main generation loop
	while Time.get_ticks_msec() - time < MAX_GENERATION_TIME and (not active_points.is_empty() or loop == 0) and cache.cached_transforms.size() <= MAX_INSTANCES:
		loop += 1
		
		var idx := random.randi_range(0, active_points.size() - 1)
		var current := active_points[idx]
		var placed := false
		
		for attempt in range(MAX_POINT_ATTEMPTS):
			var angle := random.randf_range(0, TAU)
			point = current + (Vector3(cos(angle), 0.0, sin(angle)) * radius * sqrt(random.randf_range(1.0, 4.0)))
			
			
			var ix := floori((point.x - grid_min.x) / grid_size)
			var iz := floori((point.z - grid_min.z) / grid_size)
			if ix < 0 or ix >= grid_width or iz < 0 or iz >= grid_depth or grid_points[ix + iz * grid_width] != Vector3.INF:
				continue
			
			can_place = true
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var nx := ix + dx
					var nz := iz + dz
					if nx < 0 or nx >= grid_width or nz < 0 or nz >= grid_depth:
						continue
					var neighbor := grid_points[nx + nz * grid_width]
					if neighbor != Vector3.INF and neighbor.distance_squared_to(point) < radius ** 2:
						can_place = false
						break
				if not can_place:
					break
			
			if not can_place:
				continue
			
			grid_points[ix + iz * grid_width] = point
			points.append(point)
			active_points.append(point)
			placed = true
			break
		
		if not placed:
			active_points.remove_at(idx)
			continue
		
		# Use distribution mask
		if random.randf() > distribution_mask:
			continue
		
		# Adjust point
		point = point + Vector3(0, boundaries.y * 0.5, 0)
		#point += Vector3(
			#random.randf_range(-density * 0.4, density * 0.4),
			#0,
			#random.randf_range(-density * 0.4, density * 0.4)
		#)
		
		# Intersect ray with source triangle mesh
		raycast = source_triangle_mesh.intersect_ray(source_mesh_instance.to_local(to_global(point)), Vector3.DOWN)
		
		# Ray do not collided
		if raycast.is_empty():
			continue
		
		# Find type
		type = _types[random.rand_weighted(_weights)]
		type_data = instance_types[type]
		
		# Texture masking
		if type_data.masking_enabled:
			texture_mask_size = _masks[type].get_size()
			texture_mask_value = _masks[type].get_pixel(
				clampi(roundi(remap(point.x, -boundaries.x * 0.5, boundaries.x * 0.5, 0, 1) * texture_mask_size.x), 0, texture_mask_size.x - 1),
				clampi(roundi(remap(point.z, -boundaries.z * 0.5, boundaries.z * 0.5, 0, 1) * texture_mask_size.y), 0, texture_mask_size.y - 1),
			).get_luminance()
			
			if random.randf() > texture_mask_value:
				continue
		
		# Filter normals using dot product
		if type_data.normal_filtering_enabled\
			and raycast.normal.dot(type_data.normal_filtering_normal) <= \
			remap(type_data.normal_filtering_threshold, 0, 360, 1, -1):
			continue
		
		if type_data.height_filtering_enabled and\
			(
				raycast.position.y < type_data.height_filtering_min_height
				or
				raycast.position.y > type_data.height_filtering_max_height
			):
			continue
		
		# Get global point
		point = source_mesh_instance.to_global(raycast.position)
		
		# Check subtractions
		is_inside_remover = false
		for subtraction in _subtractions:
			if subtraction._is_point_inside_shape(point, self, random):
				is_inside_remover = true
				break
		
		if is_inside_remover:
			continue
		
		# Check, is instance inside boundaries
		local_ray_pos = to_local(point)
		if abs(local_ray_pos.x) > boundaries.x * 0.5\
			or abs(local_ray_pos.y) > boundaries.y * 0.5\
			or abs(local_ray_pos.z) > boundaries.z * 0.5:
			continue
		
		# Transform generation
		xform = Transform3D(source_mesh_instance.global_basis, point)
		xform = xform.translated_local(type_data.position_offset)
		xform = xform.scaled_local(
			Vector3.ONE
			 * (
				type_data.base_scale
				 + (random.randf_range(-1, 1) * type_data.random_scale)
			)
		)
		xform = xform.rotated_local(Vector3.UP, random.randf_range(-1, 1) * type_data.random_rotation)
		xform = xform.rotated_local(Vector3.RIGHT, random.randf_range(-1, 1) * type_data.random_tilt)
		xform = xform.rotated_local(Vector3.BACK, random.randf_range(-1, 1) * type_data.random_tilt)
		cache.cached_instance_types.append(type)
		cache.cached_transforms.append(xform)
	
	if loop > 0:
		cache.is_empty = false
	
	print_debug('Generation in ', Time.get_ticks_msec() - time, ' milliseconds with ', cache.cached_transforms.size(), ' instances.')
	
	# Auto populate
	if populate and not cache.is_empty:
		populate_instances()

## Populate instances (Meshes and collisions) from cache. This method won't generate
## new instances, use [method generate_transforms] instead.
func populate_instances() -> void:
	# Clear previous instances
	clear_instances()
	if not visible:
		return
	
	# Error when populating before generation
	if not is_instance_valid(cache) or cache.is_empty:
		return
	
	# Generate body
	_bodies = []
	var generated_any_physical_body: bool = false
	for idx in range(len(instance_types)):
		_bodies.append(PhysicsServer3D.body_create())
		if instance_types[idx].collision_shape_mode != CollisionShapeMode.DISABLED:
			generated_any_physical_body = true
			PhysicsServer3D.body_set_space.call_deferred(_bodies[idx], get_world_3d().space)
			PhysicsServer3D.body_set_mode.call_deferred(_bodies[idx], PhysicsServer3D.BODY_MODE_STATIC)
			PhysicsServer3D.body_set_collision_layer.call_deferred(_bodies[idx], instance_types[idx].collision_layer)
			PhysicsServer3D.body_set_collision_mask.call_deferred(_bodies[idx], instance_types[idx].collision_mask)
	
	# Define variables
	var instance: RID
	var type: ScatterInstanceType
	var type_idx: int
	var do_physics_pass: bool = (
		generated_any_physical_body
		and len(cache.cached_type_collision_shapes) == len(instance_types)
		and len(cache.cached_type_collision_shapes) > 0
		and not Engine.is_editor_hint()
	)
	
	
	# Main population loop
	for idx in range(len(cache.cached_transforms)):
		type_idx = cache.cached_instance_types[idx]
		type = instance_types[type_idx]
		if not is_instance_valid(type) or not is_instance_valid(type.mesh):
			continue
		
		# Mesh instance creation on RenderingServer
		instance = RenderingServer.instance_create()
		RenderingServer.instance_set_scenario.call_deferred(instance, get_world_3d().scenario)
		RenderingServer.instance_set_base.call_deferred(instance, type.mesh)
		
		RenderingServer.instance_set_transform.call_deferred(instance, cache.cached_transforms[idx])
		RenderingServer.instance_set_visibility_parent.call_deferred(instance, self)
		
		RenderingServer.instance_set_layer_mask.call_deferred(instance, type.layers)
		RenderingServer.instance_attach_object_instance_id.call_deferred(instance, get_instance_id())
		RenderingServer.instance_geometry_set_cast_shadows_setting.call_deferred(instance, type.cast_shadow)
		RenderingServer.instance_geometry_set_lod_bias.call_deferred(instance, type.lod_bias)
		
		RenderingServer.instance_geometry_set_flag.call_deferred(
			instance,
			RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_BAKED_LIGHT,
			type.gi_mode == GeometryInstance3D.GIMode.GI_MODE_STATIC
		)
		RenderingServer.instance_geometry_set_flag.call_deferred(
			instance,
			RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_DYNAMIC_GI,
			type.gi_mode == GeometryInstance3D.GIMode.GI_MODE_DYNAMIC
		)
		
		RenderingServer.instance_geometry_set_visibility_range.call_deferred(
			instance,
			type.visibility_range_begin,
			type.visibility_range_end,
			type.visibility_range_begin_margin,
			type.visibility_range_end_margin,
			type.visibility_range_fade_mode,
		)
		
		if type.custom_aabb.has_volume():
			RenderingServer.instance_set_custom_aabb.call_deferred(instance, type.custom_aabb)
		
		_instances.append(instance)
		
		# Physics shape adding
		if (
				do_physics_pass
				and type.collision_shape_mode != CollisionShapeMode.DISABLED
				and _bodies[type_idx].is_valid()
				and is_instance_valid(cache.cached_type_collision_shapes[type_idx])
			):
			PhysicsServer3D.body_add_shape(
				_bodies[type_idx],
				cache.cached_type_collision_shapes[type_idx],
				cache.cached_transforms[idx]
			)

## Clear cached instances transforms and types.
## Do not removes instances, see [method clear_instances()].
func clear_cache() -> void:
	if not is_instance_valid(cache):
		cache = ScatterInstanceCache.new()
	cache.reset()
	cache.is_empty = true

## Clear all instances, but keep cache. See
## [method clear_cache()]
func clear_instances() -> void:
	for i in _instances:
		RenderingServer.free_rid(i)
	
	for i in _colliders + _bodies:
		PhysicsServer3D.free_rid(i)
	
	
	_instances = []
	_colliders = []
	_bodies = []

## Returns [code]true[/code] if cache is generated.
func is_generated() -> bool:
	return is_instance_valid(cache) and not cache.is_empty

## Returns true if instances are populated.
func is_populated() -> bool:
	return not _instances.is_empty()

#region Editor buttons
func _btn_generate() -> void:
	cache = ScatterInstanceCache.new()
	generate_transforms()

func _btn_populate() -> void:
	clear_instances()
	populate_instances()
#endregion
