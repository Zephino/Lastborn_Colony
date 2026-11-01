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
					if Actions.structure_at(st, x, y).is_empty() and Actions.touches_colony(st, x, y) and Actions.terrain_at(st, x, y) in GameData.building(type)["terrain"]:
						var hull: Dictionary = st["structures"]["1"]
						if absi(x - int(hull["x"])) + absi(y - int(hull["y"])) <= radius:
							NewGame.add_structure(st, type, x, y, type != "lab")
							placed = true
	main.refresh()
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/game.png")
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
