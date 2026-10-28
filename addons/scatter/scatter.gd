@tool
@icon('res://addons/scatter/assets/scatter.svg')
class_name Scatter3D
extends Node3D
## Procedural scatter node for placing meshes on a surface using Poisson disk sampling.
##
## Samples points across [member scatter_size], applies per-prototype filters,
## masks, then projects each candidate onto the parent [MeshInstance3D].
## Results are baked into [member bake] and spawned at runtime
## as raw RIDs through [RenderingServer] and [PhysicsServer3D] -
## no [Node3D] per instance, so tens of thousands of objects stay cheap.
##
## Run [method generate] from the editor to bake; instances spawn automatically
## on [code]_enter_tree[/code] and are freed on [code]_exit_tree[/code].

## Emmited when [method bake] is finished.
signal bake_finished()

## Emmited when all instances are spawned.
signal instances_spawned()

## Point generation strategy used during baking.
enum SamplingAlgorithm {
## Bridson's algorithm: evenly spaced points respecting per-prototype radii, no clumping. Slower but visually natural.
	POISSON_DISK,
## uniform random placement: fast, but produces clumps and gaps. Useful for quick iteration or dense grass where spacing is not critical.
	RANDOM
}

## Max attempts per point in Poisson Disk Sampling
const MAX_POINT_ATTEMPTS = 32

## Max time (ms) spent on baking per frame. When exceeded, the generator yields
## via `await get_tree().process_frame` and resumes next frame, keeping the
## editor responsive during long bakes (tens of thousands of points).
## Editor-only; not used at runtime.
const BAKE_FRAME_BUDGET_MS := 64

#region Export Variables
## List of instance types Scatter3D will generate.
## Types define generation rules, visual and physical properties of instance .
@export var prototypes: Array[ScatterPrototype]
@export_group('Generation')
## Strategy used to generate candidate points during bake. Changing this
## invalidates [member baked_data]; press Bake to rebuild. Parameters for the
## selected algorithm (radius range, tries, density) are read from
## [member prototypes] and Scatter3D's own settings.
@export var sampling_algorithm: SamplingAlgorithm = SamplingAlgorithm.POISSON_DISK
## Random generation seed. Changing this
## invalidates [member baked_data]; press Bake to rebuild.
@export_range(-1, 1, 1, 'or_greater', 'hide_control') var random_seed: int = -1
## Dimensions of scattering region. Changing this
## invalidates [member baked_data]; press Bake to rebuild.
@export var scatter_region: Vector3 = Vector3(20, 10, 20):
	set(val):
		scatter_region = val
		update_gizmos()
@export_group('Performance')
## Soft time budget (ms) for instance creation per frame during spawn.
## When the budget is exceeded, spawning pauses and resumes next frame - 
## keeps the editor and game responsive when loading
## scenes with tens of thousands of instances. 0 disables throttling.
## Do not recommended to disable, editor can crash when frame is too long.
@export_range(0, 100, 1, 'or_greater', 'prefer_slider') var frame_budget_ms: int = 16
## Hard upper bound on the number of instances a single Scatter3D can spawn.
## Generation stops early once this limit is reached, keeping the engine stable
## and preventing accidental "scatter the whole world" scenarios.
@export_range(1, 2 ** 20, 1, 'or_greater') var max_instances: int = 2 ** 18
@export_group('Data')
## Baked generation result: instance transforms, type indices, and seed.
## [code]null[/code] if the scatter has never been generated or the bake was invalidated
## (e.g. after changing prototypes or scatter_size). Persisted with the scene
## so instances can be re-spawned on load without regenerating.
@export var baked_data: ScatterData
#endregion

# RenderingServer instances
var _instances: Array[RID]
# PhysicsServer3D instances
var _colliders: Array[RID]
var _bodies: Array[RID]
var _is_baking: bool = false


# Called when the node enters the SceneTree.
func _enter_tree() -> void:
	_spawn_instances()


# Called when the object receives a notification.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			_spawn_instances()
		else:
			_despawn_instances()
	elif what == NOTIFICATION_PREDELETE:
		_despawn_instances()


# Called when the node is about to leave the SceneTree.
func _exit_tree() -> void:
	_despawn_instances()


## Bake scatter and save data.
func bake() -> Error:
	# Getting source mesh
	if not is_instance_valid(get_parent()) or \
		not get_parent() is MeshInstance3D or not is_instance_valid(get_parent().mesh):
		return FAILED
	var source_mesh_instance: MeshInstance3D = get_parent() as MeshInstance3D
	
	var time = Time.get_ticks_msec()
	
	# Clear cache and remove instances
	_despawn_instances()
	clear_bake()
	
	if baked_data == null:
		baked_data = ScatterData.new()
	
	_is_baking = true
	
	var source_mesh: Mesh = source_mesh_instance.mesh
	var source_triangle_mesh: TriangleMesh = source_mesh.generate_triangle_mesh()
	
	var type_indixes: PackedInt32Array = []
	var _weights: PackedFloat32Array = []
	var _masks: Array[Image] = []
	
	
	var min_radius_overall: float = INF
	var max_radius_overall: float = 0
	for index in range(prototypes.size()):
		if is_instance_valid(prototypes[index]):
			# Register prototype
			var prototype = prototypes[index]
			type_indixes.append(index)
			_weights.append(prototype.weight)
			
			# Register mask (if enabled)
			if prototype.masking_enabled:
				_masks.append(prototype.density_mask.get_image())
			else:
				_masks.append(null)
			
			# Compare radii
			if prototype.min_radius < min_radius_overall:
				min_radius_overall = prototype.min_radius
			if prototype.max_radius > max_radius_overall:
				max_radius_overall = prototype.max_radius
			
			# Create and register collision shape
			var shape: Shape3D = null
			if prototype.collision_shape_mode == ScatterPrototype.CollisionShapeMode.CONCAVE:
				shape = prototype.mesh.create_trimesh_shape()
			elif prototype.collision_shape_mode == ScatterPrototype.CollisionShapeMode.CONVEX:
				shape = prototype.mesh.create_convex_shape(true, false)
			elif prototype.collision_shape_mode == ScatterPrototype.CollisionShapeMode.CONVEX_SIMPLE:
				shape = prototype.mesh.create_convex_shape(true, true)
			elif prototype.collision_shape_mode == ScatterPrototype.CollisionShapeMode.CUSTOM:
				shape = prototype.collision_shape
			
			baked_data.collision_shapes.append(shape)
		else:
			push_error('Failed to bake Scatter3D - found invalid prototypes')
			_is_baking = false
			return FAILED
	
	await get_tree().process_frame
	
	# Create random generator
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	# Set its seed
	random.seed = random_seed
	if random_seed == -1:
		random.seed = randi()
	
	baked_data.random_seed = random.seed
	
	# Define variables
	var frame_start: float = Time.get_ticks_msec()
	var scatter_to_mesh: Transform3D = (
		source_mesh_instance.global_transform.affine_inverse() * global_transform
	)
	var half_boundaries: Vector3 = scatter_region * 0.5
	
	
	# Generate grid for Poisson disk sampling
	var grid_size: float = min_radius_overall / (1.4142135623730951 * 0.999)
	var grid_width = ceili(scatter_region.x / grid_size) + 2
	var grid_depth = ceili(scatter_region.z / grid_size) + 2
	var grid_min = -scatter_region * 0.5
	var grid_points: PackedVector3Array = []
	var grid_radii: PackedFloat32Array = []
	grid_points.resize(grid_width * grid_depth)
	grid_points.fill(Vector3.INF)
	grid_radii.resize(grid_width * grid_depth)
	grid_radii.fill(0)
	
	var active_points: PackedVector3Array = [
		Vector3.ZERO,
	]
	var active_radii: PackedFloat32Array = [max_radius_overall]
	var active_point: Vector3
	
	# Main generation loop
	while not active_points.is_empty() and baked_data.transforms.size() < max_instances:
		if Time.get_ticks_msec() - frame_start > BAKE_FRAME_BUDGET_MS:
			await get_tree().process_frame
			frame_start = Time.get_ticks_msec()
		
		# Find type
		var prototype_index = type_indixes[random.rand_weighted(_weights)]
		var prototype = prototypes[prototype_index]
		
		var point: Vector3
		
		if sampling_algorithm == SamplingAlgorithm.POISSON_DISK:
			var idx: int = random.randi_range(0, active_points.size() - 1)
			var point_radius: float = random.randf_range(prototype.min_radius, prototype.max_radius)
			var current: Vector3 = active_points[idx]
			var current_radius: float = active_radii[idx]
			var placed: bool = false
			
			for attempt in range(MAX_POINT_ATTEMPTS):
				var angle := random.randf_range(0, TAU)
				point = current + (Vector3(cos(angle), 0.0, sin(angle)) * maxf(point_radius, current_radius) * sqrt(random.randf_range(1.0, 4.0)))
				
				var ix := floori((point.x - grid_min.x) / grid_size)
				var iz := floori((point.z - grid_min.z) / grid_size)
				if ix < 0 or ix >= grid_width or iz < 0 or iz >= grid_depth or grid_points[ix + iz * grid_width] != Vector3.INF:
					continue
				
				var cell_range = ceili(max_radius_overall / grid_size)
				
				var can_place = true
				for dx in range(-cell_range, cell_range + 1):
					for dz in range(-cell_range, cell_range + 1):
						var nx := ix + dx
						var nz := iz + dz
						if nx < 0 or nx >= grid_width or nz < 0 or nz >= grid_depth:
							continue
						var neighbor := grid_points[nx + nz * grid_width]
						var r_n = grid_radii[nx + nz * grid_width]
						if neighbor != Vector3.INF and neighbor.distance_squared_to(point) < maxf(point_radius ** 2, r_n ** 2):
							can_place = false
							break
					if not can_place:
						break
				
				if not can_place:
					continue
			
				grid_points[ix + iz * grid_width] = point
				grid_radii[ix + iz * grid_width] = point_radius
				active_points.append(point)
				active_radii.append(point_radius)
				placed = true
				break
			
			if not placed:
				active_points.remove_at(idx)
				active_radii.remove_at(idx)
				continue
		elif sampling_algorithm == SamplingAlgorithm.RANDOM:
			point = Vector3(scatter_region.x * random.randf_range(-1, 1), 0, scatter_region.z * random.randf_range(-1, 1))
		
		# Intersect ray with source triangle mesh
		var raycast: Dictionary = source_triangle_mesh.intersect_ray(
			scatter_to_mesh * (point + Vector3(0, scatter_region.y * 0.5, 0)),
			Vector3.DOWN
		)
		if raycast.is_empty():
			continue
		
		var projected_position = source_mesh_instance.to_global(raycast.position)
		
		# Filter by height
		if prototype.height_filtering_enabled and \
			(
				projected_position.y < prototype.height_filtering_min_height
				or
				projected_position.y > prototype.height_filtering_max_height
			):
			continue
		
		# Filter normals using dot product
		if prototype.normal_filtering_enabled\
			and raycast.normal.dot(prototype.normal_filtering_normal) <= \
			remap(prototype.normal_filtering_angle, 0, TAU, 1, -1):
			continue
		
		# Texture masking
		if prototype.masking_enabled:
			var texture_mask_size: Vector2i = _masks[prototype_index].get_size()
			var texture_mask_value: float = _masks[prototype_index].get_pixel(
				clampi(roundi((point.x + half_boundaries.x) * float(texture_mask_size.x) / scatter_region.x), 0, texture_mask_size.x - 1),
				clampi(roundi((point.z + half_boundaries.z) * float(texture_mask_size.y) / scatter_region.z), 0, texture_mask_size.y - 1),
			).r
			
			if random.randf() > texture_mask_value:
				continue
		
		# Check, is instance inside scatter_region
		var local_projected_position = to_local(projected_position)
		if abs(local_projected_position.x) > scatter_region.x * 0.5\
			or abs(local_projected_position.y) > scatter_region.y * 0.5\
			or abs(local_projected_position.z) > scatter_region.z * 0.5:
			continue
		
		# Transform generation
		var xform: Transform3D = Transform3D(source_mesh_instance.global_basis, projected_position)
		xform = xform.translated_local(prototype.position_offset)
		xform = xform.scaled_local(
			Vector3.ONE
			 * (
				prototype.base_scale
				 + (random.randf_range(-1, 1) * prototype.random_scale)
			)
		)
		xform = xform.rotated_local(Vector3.UP, random.randf_range(-1, 1) * prototype.random_rotation)
		xform = xform.rotated_local(Vector3.RIGHT, random.randf_range(-1, 1) * prototype.random_tilt)
		xform = xform.rotated_local(Vector3.BACK, random.randf_range(-1, 1) * prototype.random_tilt)
		baked_data.prototypes.append(prototype_index)
		baked_data.transforms.append(xform)
	
	
	# Clear baking status
	_is_baking = false
	
	await get_tree().process_frame
	
	# Spawn generated instances
	_spawn_instances()
	
	# Emit signal
	bake_finished.emit()
	return OK


## Clears the baked data (transforms, indices, seed). Does not touch spawned
## RIDs — use _despawn_instances() for that. After clearing, has_bake() returns
## false and the next generate() rebuilds from scratch.
func clear_bake() -> void:
	if not is_instance_valid(baked_data):
		return
	baked_data.prototypes = []
	baked_data.transforms = []
	baked_data.collision_shapes = []
	baked_data.random_seed = -1


## Reload instances from cache.
func reload_instances() -> void:
	_despawn_instances.call_deferred()
	if is_baking() or not is_baked():
		return
	_spawn_instances.call_deferred()


## Returns true if a valid bake exists and matches the current configuration.
## Stale bakes (prototypes or scatter_size changed since baking) return false.
func is_baked() -> bool:
	return is_instance_valid(baked_data) and not baked_data.is_empty


## Returns true if Scatter3D is currently baking instances.
func is_baking() -> bool:
	return _is_baking


## Returns true if RIDs for the current bake are currently spawned in the
## RenderingServer and PhysicsServer. Does not imply has_bake() by itself.
func has_instances() -> bool:
	return not _instances.is_empty()


func _spawn_instances() -> void:
	# Clear previous instances
	_despawn_instances()
	if not visible or not is_baked() or is_baking():
		return
	
	# Generate body
	_bodies = []
	var generated_any_physical_body: bool = false
	for prototype_index in range(len(prototypes)):
		_bodies.append(PhysicsServer3D.body_create())
		if prototypes[prototype_index].collision_shape_mode != ScatterPrototype.CollisionShapeMode.DISABLED:
			generated_any_physical_body = true
			PhysicsServer3D.body_set_space(_bodies[prototype_index], get_world_3d().space)
			PhysicsServer3D.body_set_mode(_bodies[prototype_index], PhysicsServer3D.BODY_MODE_STATIC)
			PhysicsServer3D.body_set_collision_layer(_bodies[prototype_index], prototypes[prototype_index].collision_layer)
			PhysicsServer3D.body_set_collision_mask(_bodies[prototype_index], prototypes[prototype_index].collision_mask)
	
	# Define variables
	var frame_start: float = 0
	
	# Main population loop
	for i in range(len(baked_data.transforms)):
		if frame_budget_ms > 0 and Time.get_ticks_msec() - frame_start > frame_budget_ms:
			await get_tree().process_frame
			frame_start = Time.get_ticks_msec()
		
		var prototype_index: int = baked_data.prototypes[i]
		var prototype = prototypes[prototype_index]
		
		if not is_instance_valid(prototype) or not is_instance_valid(prototype.mesh):
			continue
		
		# Creating and vonfiguring instance.
		var instance: RID = RenderingServer.instance_create()
		RenderingServer.instance_set_scenario.call_deferred(instance, get_world_3d().scenario)
		RenderingServer.instance_set_base.call_deferred(instance, prototype.mesh)
		
		RenderingServer.instance_set_transform.call_deferred(instance, baked_data.transforms[i])
		RenderingServer.instance_set_visibility_parent.call_deferred(instance, self)
		
		RenderingServer.instance_set_layer_mask.call_deferred(instance, prototype.layers)
		RenderingServer.instance_attach_object_instance_id.call_deferred(instance, get_instance_id())
		RenderingServer.instance_geometry_set_cast_shadows_setting.call_deferred(instance, prototype.cast_shadow)
		RenderingServer.instance_geometry_set_lod_bias.call_deferred(instance, prototype.lod_bias)
		
		RenderingServer.instance_geometry_set_flag.call_deferred(
			instance,
			RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_BAKED_LIGHT,
			prototype.gi_mode == GeometryInstance3D.GIMode.GI_MODE_STATIC
		)
		RenderingServer.instance_geometry_set_flag.call_deferred(
			instance,
			RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_DYNAMIC_GI,
			prototype.gi_mode == GeometryInstance3D.GIMode.GI_MODE_DYNAMIC
		)
		
		RenderingServer.instance_geometry_set_visibility_range.call_deferred(
			instance,
			prototype.visibility_range_begin,
			prototype.visibility_range_end,
			prototype.visibility_range_begin_margin,
			prototype.visibility_range_end_margin,
			prototype.visibility_range_fade_mode,
		)
		
		if prototype.custom_aabb.has_volume():
			RenderingServer.instance_set_custom_aabb.call_deferred(instance, prototype.custom_aabb)
		
		# Append instance
		_instances.append(instance)
		
		# Adding collision shape
		if (
				prototype.collision_shape_mode != ScatterPrototype.CollisionShapeMode.DISABLED
				and _bodies[prototype_index].is_valid()
				and is_instance_valid(baked_data.collision_shapes[prototype_index])
			):
			PhysicsServer3D.body_add_shape(
				_bodies[prototype_index],
				baked_data.collision_shapes[prototype_index],
				baked_data.transforms[i]
			)
	
	# Emit signal
	instances_spawned.emit()


func _despawn_instances() -> void:
	for i in _instances:
		RenderingServer.free_rid(i)
	
	for i in _colliders + _bodies:
		PhysicsServer3D.free_rid(i)
	
	_instances = []
	_colliders = []
	_bodies = []
