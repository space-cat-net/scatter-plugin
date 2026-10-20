extends EditorNode3DGizmoPlugin


func _init():
	create_material("main", Color(0.311, 0.7, 0.0, 1.0))

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is Scatter3D

func _get_gizmo_name() -> String:
	return 'Scatter3D'

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

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	
	var lines := PackedVector3Array()
	var node: Scatter3D = gizmo.get_node_3d()
	
	var size: Vector3 = node.scatter_region
	
	lines = make_wireframe_cube(size)
	
	lines.append(Vector3(0, (0.5 * size.y), 0))
	lines.append(Vector3(0, (0.5 * size.y) - 2, 0))
	
	
	gizmo.add_lines(lines, get_material("main", gizmo), false)
