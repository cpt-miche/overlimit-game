extends CanvasLayer

signal continue_requested
signal choice_selected(choice_index: int)

@onready var panel: PanelContainer = $Panel
@onready var speaker_label: Label = $Panel/Margin/VBox/Speaker
@onready var line_label: RichTextLabel = $Panel/Margin/VBox/Line
@onready var continue_label: Label = $Panel/Margin/VBox/ContinueHint
@onready var player_portrait: TextureRect = $Portraits/PlayerPortrait
@onready var npc_portrait: TextureRect = $Portraits/NpcPortrait
@onready var vbox: VBoxContainer = $Panel/Margin/VBox

var _default_player_portrait: Texture2D
var _default_npc_portrait: Texture2D
var _choice_labels: Array[Label] = []
var _selected_choice: int = 0

func _ready() -> void:
	visible = false
	panel.visible = false
	continue_label.text = "Press E to continue"

func open_dialogue(player_texture: Texture2D, npc_texture: Texture2D) -> void:
	_default_player_portrait = player_texture
	_default_npc_portrait = npc_texture
	player_portrait.texture = player_texture
	npc_portrait.texture = npc_texture
	visible = true
	panel.visible = true
	_clear_choices()
	continue_label.visible = true

func close_dialogue() -> void:
	visible = false
	panel.visible = false
	_clear_choices()

func display_line(entry: Dictionary) -> void:
	speaker_label.text = String(entry.get("speaker", ""))
	line_label.text = String(entry.get("text", "..."))
	player_portrait.texture = _resolve_portrait(entry, "player_portrait", _default_player_portrait)
	npc_portrait.texture = _resolve_portrait(entry, "npc_portrait", _default_npc_portrait)
	_set_active_side(String(entry.get("side", "npc")))
	continue_label.visible = true
	_clear_choices()

func display_choices(choices: Array) -> void:
	continue_label.visible = false
	_clear_choices()
	if choices.is_empty():
		line_label.text = "..."
		return

	_selected_choice = 0
	for i: int in range(choices.size()):
		var choice: Dictionary = choices[i]
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "  %d. %s" % [i + 1, String(choice.get("text", "..."))]
		vbox.add_child(label)
		_choice_labels.append(label)
	_update_choice_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if not _choice_labels.is_empty():
		if event.is_action_pressed("ui_up"):
			_selected_choice = maxi(_selected_choice - 1, 0)
			_update_choice_highlight()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down"):
			_selected_choice = mini(_selected_choice + 1, _choice_labels.size() - 1)
			_update_choice_highlight()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("interact"):
			emit_signal("choice_selected", _selected_choice)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("interact"):
		emit_signal("continue_requested")
		get_viewport().set_input_as_handled()

func _resolve_portrait(entry: Dictionary, key: String, fallback: Texture2D) -> Texture2D:
	if not entry.has(key):
		return fallback

	var value: Variant = entry.get(key)
	if value is Texture2D:
		return value

	if value is String:
		var path := String(value)
		if path == "":
			return fallback
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded

	return fallback

func _set_active_side(side: String) -> void:
	if side == "player":
		player_portrait.modulate = Color(1, 1, 1, 1)
		npc_portrait.modulate = Color(0.55, 0.55, 0.55, 1)
	else:
		player_portrait.modulate = Color(0.55, 0.55, 0.55, 1)
		npc_portrait.modulate = Color(1, 1, 1, 1)

func _clear_choices() -> void:
	for label: Label in _choice_labels:
		if is_instance_valid(label):
			label.queue_free()
	_choice_labels.clear()

func _update_choice_highlight() -> void:
	for i: int in range(_choice_labels.size()):
		var prefix := ">" if i == _selected_choice else " "
		var content := _choice_labels[i].text.substr(2)
		_choice_labels[i].text = "%s %s" % [prefix, content]
