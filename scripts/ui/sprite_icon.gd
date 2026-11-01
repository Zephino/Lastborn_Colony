## A small picture of one building, drawn with its angled sprite on its usual
## ground. Used in the build list, the Build menu and the Info panel.
extends Control

const Sprites = preload("res://scripts/ui/sprites.gd")
const GameData = preload("res://scripts/sim/game_data.gd")

var type := ""


func _init(building: String = "", px: float = 56.0) -> void:
	type = building
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func show_type(building: String) -> void:
	type = building
	visible = building != ""
	queue_redraw()


func _draw() -> void:
	if type == "" or not GameData.has_building(type):
		return
	var tw := minf(size.x, size.y * 1.4) * 0.80
	var c := Vector2(size.x * 0.5, size.y * 0.68)
	# Stand it on the ground it is usually built on (ice for a drill, a vent for a tap...).
	var ground: String = GameData.building(type)["terrain"][0]
	Sprites.terrain_iso(self, ground, c, tw, false)
	Sprites.draw_iso(self, type, c, tw, {"links": []})
