class_name GameStateQuery
extends RefCounted

func has_quest_flag(_flag_id: StringName) -> bool:
	return false

func has_prior_victory(_enemy_id: StringName) -> bool:
	return false

func has_inventory_item(_item_id: StringName) -> bool:
	return false
