@tool
extends EditorPlugin


const SCATTER_ICON = preload('res://addons/scatter/assets/scatter.svg')

const ScatterGizmo = preload('res://addons/scatter/gizmo/scatter_gizmo.gd')

var scatter_gizmo = ScatterGizmo.new() # Gizmo for Scatter3D

var buttons_container: HBoxContainer
var selected_scatter: Scatter3D

func _enter_tree() -> void:
	# Load gizmo
	add_node_3d_gizmo_plugin(scatter_gizmo)
	
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)


func _exit_tree() -> void:
	# Unload gizmo
	remove_node_3d_gizmo_plugin(scatter_gizmo)


func _on_selection_changed() -> void:
	var editor_selection = get_editor_interface().get_selection()
	selected_scatter = null
	
	for i in editor_selection.get_selected_nodes():
		if is_instance_valid(i) and i is Scatter3D:
			if selected_scatter and i != selected_scatter:
				# Display controls when selected only one Scatter3D
				return
			else:
				selected_scatter = i
	
	if is_instance_valid(buttons_container):
		buttons_container.queue_free()
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, buttons_container)
		buttons_container = null
	
	if is_instance_valid(selected_scatter):
		var bake_button = _create_button(_on_bake_button_pressed, 'Bake Scatter3D', 'Bake')
		var reload_button = _create_button(_on_reload_button_pressed, '', 'RotateRight', 'Reload scatter instances without generation')
		buttons_container = HBoxContainer.new()
		buttons_container.add_child(bake_button)
		buttons_container.add_child(reload_button)
		add_control_to_container.call_deferred(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, buttons_container)


func _create_button(callback: Callable, text: String, icon: String, tooltip: String = "") -> Button:
	var button = Button.new()
	
	button.text = text
	button.tooltip_text = tooltip
	button.theme = get_editor_interface().get_editor_theme()
	button.theme_type_variation = &'FlatMenuButton'
	button.icon = EditorInterface.get_editor_theme().get_icon(icon, &'EditorIcons')
	button.pressed.connect(callback)
	
	return button


func _on_bake_button_pressed() -> void:
	if not _is_selected_scatter_valid():
		return
	
	selected_scatter.bake()


func _on_reload_button_pressed() -> void:
	if not _is_selected_scatter_valid():
		return
	
	selected_scatter.reload_instances()


func _is_selected_scatter_valid() -> bool:
	return is_instance_valid(selected_scatter) \
		and selected_scatter in get_editor_interface().get_selection().get_selected_nodes()
