## Small helpers shared by the interface scripts.
extends RefCounted


## Godot sizes a wrapping button for one line of text, so long labels would
## overlap the next button. This makes the button tall enough for its text at
## the given width (and at least 44 points, a comfortable touch target).
static func fit_button_height(b: Button, available_width: float) -> void:
	var font := b.get_theme_default_font()
	var font_size := b.get_theme_default_font_size()
	if font == null:
		b.custom_minimum_size = Vector2(0, 44)
		return
	var inner := maxf(40.0, available_width - 24.0)
	var lines := 0
	for paragraph in b.text.split("\n"):
		var w := font.get_string_size(paragraph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		lines += maxi(1, ceili(w / inner))
	var line_height := font.get_height(font_size)
	b.custom_minimum_size = Vector2(0, maxf(44.0, lines * line_height + 16.0))
