extends Control

signal action_pressed(action_id: StringName)
signal infusion_changed(value: float)
signal debug_mode_toggled(enabled: bool)
signal exit_requested

@onready var combat_log: RichTextLabel = $Margin/VBox/Log
@onready var infusion_slider: HSlider = $Margin/VBox/InfusionRow/InfusionSlider
@onready var infusion_label: Label = $Margin/VBox/InfusionRow/InfusionValue
@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_label: RichTextLabel = $DebugPanel/Margin/Stats
@onready var transform_menu: MenuButton = $Margin/VBox/Actions/TransformMenu
@onready var exit_box: PanelContainer = $Margin/VBox/ExitBox
@onready var exit_button: Button = get_node_or_null("Margin/VBox/ExitBox/Margin/ExitBattleButton")

var debug_mode_enabled := false

func _ready() -> void:
	infusion_slider.value_changed.connect(_on_infusion_changed)
	for child: Node in $Margin/VBox/Actions.get_children():
		if child is Button and not (child is MenuButton):
			var button := child as Button
			button.pressed.connect(func() -> void: action_pressed.emit(StringName(button.name)))
	_setup_transform_menu()
	if exit_button != null:
		exit_button.pressed.connect(func() -> void: exit_requested.emit())
	else:
		push_warning("ExitBattleButton node not found; exit action disabled for this BattleUI instance.")
	debug_panel.visible = false
	exit_box.visible = false
	_on_infusion_changed(infusion_slider.value)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.ctrl_pressed and key_event.keycode == KEY_T:
			debug_mode_enabled = not debug_mode_enabled
			debug_panel.visible = debug_mode_enabled
			debug_mode_toggled.emit(debug_mode_enabled)
			get_viewport().set_input_as_handled()

func append_log(line: String) -> void:
	if combat_log.text.is_empty() or combat_log.text == "Combat log...":
		combat_log.text = line
	else:
		combat_log.text = "%s\n%s" % [combat_log.text, line]
	combat_log.scroll_to_line(maxi(combat_log.get_line_count() - 1, 0))

func clear_log() -> void:
	combat_log.text = ""

func _setup_transform_menu() -> void:
	var popup := transform_menu.get_popup()
	popup.clear()
	popup.add_item("Super Saiyan", 0)
	popup.add_item("Kaioken", 1)
	popup.id_pressed.connect(_on_transform_option_selected)

func _on_transform_option_selected(id: int) -> void:
	match id:
		0:
			action_pressed.emit(&"transform_form")
		1:
			action_pressed.emit(&"kaioken")

func _on_infusion_changed(value: float) -> void:
	infusion_label.text = "%d%%" % int(value)
	infusion_changed.emit(value / 100.0)

func set_debug_stats(lines: PackedStringArray) -> void:
	debug_label.text = "\n".join(lines)

func set_battle_active(is_active: bool) -> void:
	for child: Node in $Margin/VBox/Actions.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = not is_active
	infusion_slider.editable = is_active
	exit_box.visible = not is_active

func set_exit_message(message: String) -> void:
	if exit_button != null:
		exit_button.text = message
