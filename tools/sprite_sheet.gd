## Renders the sprite concept sheets to PNG files. Needs a display:
##   xvfb-run -s "-screen 0 1900x1340x24" godot --rendering-driver opengl3 --resolution 1900x1340 --script res://tools/sprite_sheet.gd -- <out_dir>
## Pages: surface, deep, both (buildings by level), remade (the latest redrawn
## buildings together), units, tunnels, world. The "all" page (every building
## on one sheet) is bigger; draw it on its own:
##   xvfb-run -s "-screen 0 2840x2000x24" godot --rendering-driver opengl3 --resolution 2840x2000 --script res://tools/sprite_sheet.gd -- <out_dir> all
## The "complete" page (everything: buildings, units, tunnels, terrain) is
## bigger still:
##   xvfb-run -s "-screen 0 3800x4200x24" godot --rendering-driver opengl3 --resolution 3800x4200 --script res://tools/sprite_sheet.gd -- <out_dir> complete
extends SceneTree

const Canvas = preload("res://tools/sheet_canvas.gd")

var canvas: Control
var frames := 0
var out_dir := "user://"
var pages := ["surface", "deep", "both", "remade", "units", "tunnels", "world"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		# A comma list of pages to draw, e.g. "all" (run "all" at 2840x2000).
		pages = Array(args[1].split(","))
	canvas = Canvas.new()
	canvas.page = pages[0]
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)


func _process(_delta: float) -> bool:
	frames += 1
	if frames % 4 == 0:
		var page: String = pages[frames / 4 - 1]
		root.get_texture().get_image().save_png("%s/lastborn_sprites_%s.png" % [out_dir, page])
		if frames / 4 >= pages.size():
			quit()
		else:
			canvas.page = pages[frames / 4]
			canvas.queue_redraw()
	return false
