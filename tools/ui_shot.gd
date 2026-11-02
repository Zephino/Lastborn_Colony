## Developer tool (not exported): opens the game, starts a colony, opens a
## dialog and saves screenshots. Run under a display:
##   godot --script res://tools/ui_shot.gd -- <outdir>
extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._start_new({"manifest": {"berth": 2, "alloy": 1, "rations": 1, "oxygen": 1, "pod": 1}}, 4, "Margin")
	main.close_modal()
	main.state["stock"]["parts"] = 30.0
	main.state["stock"]["alloy"] = 120.0
	# A small colony around the hull, so the map has something on it.
	const NewGame = preload("res://scripts/sim/new_game.gd")
	const Actions = preload("res://scripts/sim/actions.gd")
	const GameData = preload("res://scripts/sim/game_data.gd")
	var st: Dictionary = main.state
	for type in ["main", "bunk", "mirror", "vat", "main", "splitter", "commons", "forge", "workshop", "cutter", "drill", "vent", "lab", "main", "warden", "cache", "clinic"]:
		var placed := false
		for radius in range(1, 6):
			if placed:
				break
			for y in int(st["height"]):
				for x in int(st["width"]):
					if placed:
						break
					var rot := Actions.auto_rot(st, type, x, y)
					if Actions.structure_at(st, x, y).is_empty() and rot >= 0 and Actions.terrain_at(st, x, y) in GameData.building(type)["terrain"]:
						var hull: Dictionary = st["structures"]["1"]
						if absi(x - int(hull["x"])) + absi(y - int(hull["y"])) <= radius:
							NewGame.add_structure(st, type, x, y, type != "lab", 0, rot)
							placed = true
	# Something under construction, drones at work and satellites in orbit.
	for y in int(st["height"]):
		var done := false
		for x in int(st["width"]):
			if Actions.structure_at(st, x, y).is_empty() and Actions.auto_rot(st, "academy", x, y) >= 0 and Actions.terrain_at(st, x, y) == "regolith":
				NewGame.add_structure(st, "academy", x, y, false, 0, Actions.auto_rot(st, "academy", x, y))
				done = true
				break
		if done:
			break
	st["drones"] = {"grader": 1, "prospector": 2, "hauler": 1}
	st["satellites"] = {"weather": 1, "relay": 1, "power": 2}
	st["report"] = {"drone_slots": 8}
	main.refresh()
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/game.png")
	# The Deep: a shaft landing with a few buildings round it.
	var hull: Dictionary = st["structures"]["1"]
	var hx := int(hull["x"]) + 1
	var hy := int(hull["y"]) + 2
	for dy in range(-2, 3):
		for dx in range(-3, 4):
			if Actions.inside(st, hx + dx, hy + dy):
				st["deep"][hy + dy][hx + dx] = "cavern" if absi(dx) + absi(dy) < 4 else "rock"
	st["deep"][hy][hx + 2] = "vein"
	NewGame.add_structure(st, "shaft_base", hx, hy, true, 1)
	var deep_types := [["main", 1, 0], ["cutter", 2, 0], ["main", -1, 0], ["bunk", -2, 0], ["garden", 0, 1], ["lounge", 0, -1], ["main", 1, 1], ["lab", 1, -1]]
	for d in deep_types:
		NewGame.add_structure(st, d[0], hx + int(d[1]), hy + int(d[2]), true, 1)
	main._set_level(1)
	main.map_view.center_on(Vector2i(hx, hy))
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/deep.png")
	main._set_level(0)
	# The top of the same lift on the surface, with someone waiting.
	if Actions.structure_at(st, hx, hy, 0).is_empty():
		st["tiles"][hy][hx] = "regolith"
		NewGame.add_structure(st, "shaft", hx, hy, true, 0)
	main.map_view.center_on(Vector2i(hx, hy))
	main.refresh()
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/lift_top.png")
	# Select a building to show its picture in the side panel.
	var bunk_cell := Vector2i(-1, -1)
	for id in st["structures"]:
		if st["structures"][id]["type"] == "bunk" and int(st["structures"][id]["z"]) == 0:
			bunk_cell = Vector2i(int(st["structures"][id]["x"]), int(st["structures"][id]["y"]))
	main.map_view.selected = bunk_cell
	main.refresh()
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/selected.png")
	# Placing a Kelp Vat: the see-through preview with its doors.
	main.map_view.selected = Vector2i(-1, -1)
	main._set_build("vat")
	for y in int(st["height"]):
		for x in int(st["width"]):
			if main.map_view.hover.x < 0 and Actions.structure_at(st, x, y).is_empty() and Actions.auto_rot(st, "vat", x, y) >= 0 and Actions.terrain_at(st, x, y) == "regolith":
				main.map_view.hover = Vector2i(x, y)
	main.refresh()
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/placing.png")
	main._rotate_build()
	main.refresh()
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/placing_turned.png")
	main._set_build("")
	main.menus.show_help(5)
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/help.png")
	main.close_modal()
	main.show_fleet()
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/fleet.png")
	main.close_modal()
	main.show_build_menu()
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/build.png")
	quit()
