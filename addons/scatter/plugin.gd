@tool
extends EditorPlugin


const SCATTER_ICON = preload('res://addons/scatter/assets/scatter.svg')

const ScatterGizmo = preload('res://addons/scatter/gizmo/scatter_gizmo.gd')
const ScatterShapeGizmo = preload('res://addons/scatter/gizmo/scatter_shape_gizmo.gd')

var scatter_gizmo = ScatterGizmo.new() # Gizmo for Scatter3D
var remover_modifier_gizmo = ScatterShapeGizmo.new() # Gizmo for InstanceRemoverScatterModifier3D

var scatter_buttons: HBoxContainer
var generate_button: Button
var separator: VSeparator
var icon: Button

func _enable_plugin() -> void:
	pass


func get_operating_scatters() -> Array[Scatter3D]:
	var editor_selection: EditorSelection = EditorInterface.get_selection()
	var scatters: Array[Scatter3D] = []
	for node in editor_selection.get_selected_nodes():
		if is_instance_valid(node):
			if node is Scatter3D:
				scatters.append(node)
			if node.get_parent() is Scatter3D:
				scatters.append(node.get_parent())
	return scatters


func _generate_button_pressed() -> void:
	var scatters = get_operating_scatters()
	
	for i in scatters:
		i._btn_generate()


func _editor_interface_selection_changed() -> void:
	var editor_selection: EditorSelection = EditorInterface.get_selection()
	scatter_buttons.visible = _can_show_scatter_buttons(editor_selection)
	var scatters = get_operating_scatters()


func _can_show_scatter_buttons(editor_selection: EditorSelection) -> bool:
	if editor_selection.get_selected_nodes().is_empty():
		return false
	var res = true
	for node in editor_selection.get_selected_nodes():
		if node is not Scatter3D and node is not ScatterShape3D:
			res = false
		if node is not Scatter3D and node.get_parent() is not Scatter3D:
			res = false
	return res


func _disable_plugin() -> void:
	pass


func _enter_tree() -> void:
	# Load gizmo
	add_node_3d_gizmo_plugin(scatter_gizmo)
	add_node_3d_gizmo_plugin(remover_modifier_gizmo)
	
	# Add buttons
	scatter_buttons = HBoxContainer.new()
	scatter_buttons.tooltip_text = 'Controls of all available scatterers.'
	
	icon = Button.new()
	icon.flat = true
	icon.text = 'Scatter3D'
	icon.theme = get_editor_interface().get_editor_theme()
	icon.theme_type_variation = 'FlatMenuButton'
	icon.icon = SCATTER_ICON
	scatter_buttons.add_child(icon)
	
	separator = VSeparator.new()
	separator.theme = get_editor_interface().get_editor_theme()
	separator.theme_type_variation = 'FlatMenuButton'
	scatter_buttons.add_child(separator)
	
	generate_button = Button.new()
	generate_button.text = 'Generate'
	generate_button.tooltip_text = 'Generate'
	generate_button.theme = get_editor_interface().get_editor_theme()
	generate_button.theme_type_variation = 'FlatMenuButton'
	generate_button.icon = get_editor_interface().get_editor_theme().get_icon(&'RandomNumberGenerator', &'EditorIcons')
	generate_button.pressed.connect(_generate_button_pressed)
	scatter_buttons.add_child(generate_button)
	
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, scatter_buttons)
	scatter_buttons.hide.call_deferred()
	
	EditorInterface.get_selection().selection_changed.connect(_editor_interface_selection_changed)


func _exit_tree() -> void:
	# Unload gizmo
	remove_node_3d_gizmo_plugin(scatter_gizmo)
	remove_node_3d_gizmo_plugin(remover_modifier_gizmo)
	
	# Clean-up of the plugin goes here.
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, scatter_buttons)
	scatter_buttons.queue_free()
	
	var editor_selection: EditorSelection = EditorInterface.get_selection()
	if editor_selection.selection_changed.is_connected(_editor_interface_selection_changed):
		editor_selection.selection_changed.disconnect(_editor_interface_selection_changed)
