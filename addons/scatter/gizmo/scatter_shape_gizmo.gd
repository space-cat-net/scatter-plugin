extends EditorNode3DGizmoPlugin


func _init():
	create_material("main", Color(0.81, 0.103, 0.024, 1.0))

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is ScatterShape3D

func _get_gizmo_name() -> String:
	return 'ScatterShape3D'

func make_wireframe_cube(size: Vector3) -> PackedVector3Array:
	var h = size / 2.0
	var d := [-1, 1]
	var verts := PackedVector3Array()
	for x in d:
		for y in d:
			for z in d:
				verts.append(Vector3(x, y, z) * h)
	
	var lines := PackedVector3Array()
	var edges := [
		0,1, 1,3, 3,2, 2,0,
		4,5, 5,7, 7,6, 6,4,
		0,4, 1,5, 3,7, 2,6
	]
	for i in range(0, edges.size(), 2):
		lines.append(verts[edges[i]])
		lines.append(verts[edges[i + 1]])
	return lines

func make_wireframe_sphere(radius: float, resolution: int = 64) -> PackedVector3Array:
	var points := PackedVector3Array()
	var step := TAU / resolution
	
	for i in range(resolution):
		var a0 := i * step
		var a1 := (i + 1) % resolution * step
		var p0 := Vector3(cos(a0), sin(a0), 0.0) * radius
		var p1 := Vector3(cos(a1), sin(a1), 0.0) * radius
		points.append(p0)
		points.append(p1)
	
	for i in range(resolution):
		var a0 := i * step
		var a1 := (i + 1) % resolution * step
		var p0 := Vector3(cos(a0), 0.0, sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0.0, sin(a1)) * radius
		points.append(p0)
		points.append(p1)
	
	for i in range(resolution):
		var a0 := i * step
		var a1 := (i + 1) % resolution * step
		var p0 := Vector3(0.0, cos(a0), sin(a0)) * radius
		var p1 := Vector3(0.0, cos(a1), sin(a1)) * radius
		points.append(p0)
		points.append(p1)
	
	return points

func make_wireframe_polygon(polygon: PackedVector2Array, distance: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var count := polygon.size()
	if count < 2:
		return points
	
	# Top polygon (y = 0)
	for i in range(count):
		var p0 := Vector3(polygon[i].x, 0.0, polygon[i].y)
		var p1 := Vector3(polygon[(i + 1) % count].x, 0.0, polygon[(i + 1) % count].y)
		points.append(p0)
		points.append(p1)
	
	# Bottom polygon (y = -distance)
	for i in range(count):
		var p0 := Vector3(polygon[i].x, -distance, polygon[i].y)
		var p1 := Vector3(polygon[(i + 1) % count].x, -distance, polygon[(i + 1) % count].y)
		points.append(p0)
		points.append(p1)
	
	# Vertical edges connecting top to bottom
	for i in range(count):
		var top := Vector3(polygon[i].x, 0.0, polygon[i].y)
		var bottom := Vector3(polygon[i].x, -distance, polygon[i].y)
		points.append(top)
		points.append(bottom)
	
	return points


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	
	var lines := PackedVector3Array()
	var node: ScatterShape3D = gizmo.get_node_3d()
	if node.shape == ScatterShape3D.RegionShapeType.BOX:
		lines = make_wireframe_cube(node.box_size)
	elif node.shape == ScatterShape3D.RegionShapeType.SPHERE:
		lines = make_wireframe_sphere(node.sphere_radius)
	elif node.shape == ScatterShape3D.RegionShapeType.POLYGON:
		lines = make_wireframe_polygon(node.polygon_points, node.polygon_depth)
	
	gizmo.add_lines(lines, get_material("main", gizmo), false)
