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
