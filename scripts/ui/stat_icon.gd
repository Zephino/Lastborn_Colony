## A small resource icon (see people.gd) as a Control, for the top bar.
extends Control

const People = preload("res://scripts/ui/people.gd")

var key := ""


func _init(stat: String = "", px: float = 18.0) -> void:
	key = stat
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	People.draw_icon(self, key, size * 0.5, minf(size.x, size.y))
