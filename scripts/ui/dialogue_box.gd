extends CanvasLayer

signal dialogue_finished

@onready var panel: PanelContainer = $Panel
@onready var speaker_label: Label = $Panel/Margin/VBox/Speaker
@onready var line_label: RichTextLabel = $Panel/Margin/VBox/Line
@onready var continue_label: Label = $Panel/Margin/VBox/ContinueHint
@onready var player_portrait: TextureRect = $Portraits/PlayerPortrait
@onready var npc_portrait: TextureRect = $Portraits/NpcPortrait

var _lines: Array = []
var _current_line_index: int = 0
var _default_player_portrait: Texture2D
var _default_npc_portrait: Texture2D

func _ready() -> void:
	visible = false
	panel.visible = false
	continue_label.text = "Press E to continue"

func start_dialogue(player_texture: Texture2D, npc_texture: Texture2D, lines: Array) -> void:
	_lines = lines
	_current_line_index = 0
	_default_player_portrait = player_texture
	_default_npc_portrait = npc_texture
	player_portrait.texture = player_texture
	npc_portrait.texture = npc_texture
	visible = true
	panel.visible = true
	_show_current_line()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	_current_line_index += 1
	if _current_line_index >= _lines.size():
		_end_dialogue()
		return
	_show_current_line()

func _show_current_line() -> void:
	if _lines.is_empty():
		_end_dialogue()
		return

	var entry: Dictionary = _lines[_current_line_index]
	var speaker: String = String(entry.get("speaker", ""))
	var side: String = String(entry.get("side", "npc"))
	var text: String = String(entry.get("text", "..."))

	speaker_label.text = speaker
	line_label.text = text
	player_portrait.texture = _resolve_portrait(entry, "player_portrait", _default_player_portrait)
	npc_portrait.texture = _resolve_portrait(entry, "npc_portrait", _default_npc_portrait)
	_set_active_side(side)


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

func _end_dialogue() -> void:
	visible = false
	panel.visible = false
	emit_signal("dialogue_finished")
