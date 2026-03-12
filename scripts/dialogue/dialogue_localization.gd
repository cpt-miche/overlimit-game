extends RefCounted

var _entries: Dictionary = {}

func configure(entries: Dictionary) -> void:
	_entries.clear()
	for key: Variant in entries.keys():
		_entries[StringName(key)] = String(entries[key])

func resolve_text(text_key: StringName, fallback: String = "...") -> String:
	if text_key != &"" and _entries.has(text_key):
		return String(_entries[text_key])
	return fallback
