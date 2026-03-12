extends RefCounted

const SpeakerRegistryScript = preload("res://scripts/dialogue/speaker_registry.gd")

var _speaker_registry: RefCounted
var _session_defaults := DialogueSessionDefaults.new()

func _init(speaker_registry: RefCounted = null) -> void:
	_speaker_registry = speaker_registry if speaker_registry != null else SpeakerRegistryScript.new()

func begin_dialogue(dialogue_sequence: DialogueSequence) -> DialogueSessionDefaults:
	_session_defaults = DialogueSessionDefaults.new()
	_session_defaults.player_portrait = _resolve_dialogue_default(dialogue_sequence.player_portrait, dialogue_sequence.player_speaker_id)
	_session_defaults.npc_portrait = _resolve_dialogue_default(dialogue_sequence.npc_portrait, dialogue_sequence.npc_speaker_id)
	return _session_defaults

func present_line(line: DialogueLine) -> DialoguePresentedLine:
	var output := DialoguePresentedLine.new()
	var speaker_id := line.speaker_id
	var side := line.side
	if side == "":
		side = _speaker_registry.get_side(speaker_id, "npc")

	var speaker := line.speaker
	if speaker == "":
		speaker = _speaker_registry.get_display_name(speaker_id, "")

	var player_portrait := _resolve_line_portrait(line.player_portrait, line.player_speaker_id, _session_defaults.player_portrait)
	var npc_portrait := _resolve_line_portrait(line.npc_portrait, line.npc_speaker_id, _session_defaults.npc_portrait)

	if side == "player" and player_portrait == _session_defaults.player_portrait:
		player_portrait = _speaker_registry.get_default_portrait(speaker_id, player_portrait)
	if side == "npc" and npc_portrait == _session_defaults.npc_portrait:
		npc_portrait = _speaker_registry.get_default_portrait(speaker_id, npc_portrait)

	output.speaker = speaker
	output.text = line.text
	output.side = side
	output.player_portrait = player_portrait
	output.npc_portrait = npc_portrait
	return output

func _resolve_dialogue_default(portrait_value: Variant, speaker_id: StringName) -> Texture2D:
	if portrait_value != null:
		return _speaker_registry.resolve_texture(portrait_value, null)
	if speaker_id != &"":
		return _speaker_registry.get_default_portrait(speaker_id, null)
	return null

func _resolve_line_portrait(portrait_value: Variant, speaker_id: StringName, fallback: Texture2D) -> Texture2D:
	if portrait_value != null:
		return _speaker_registry.resolve_texture(portrait_value, fallback)
	if speaker_id != &"":
		return _speaker_registry.get_default_portrait(speaker_id, fallback)
	return fallback
