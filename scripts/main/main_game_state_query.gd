extends GameStateQuery

var _quest_flags: Dictionary
var _victories: Dictionary
var _inventory: Dictionary

func _init(quest_flags: Dictionary, victories: Dictionary, inventory: Dictionary) -> void:
	_quest_flags = quest_flags
	_victories = victories
	_inventory = inventory

func has_quest_flag(flag_id: StringName) -> bool:
	return bool(_quest_flags.get(flag_id, false))

func has_prior_victory(enemy_id: StringName) -> bool:
	return bool(_victories.get(enemy_id, false))

func has_inventory_item(item_id: StringName) -> bool:
	return int(_inventory.get(item_id, 0)) > 0
