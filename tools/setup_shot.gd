## Developer tool (not exported): opens the screens before landing and saves
## screenshots of the planet list, the probe target page, a probe report and
## the landing-site screen. Run under a display:
##   godot --script res://tools/setup_shot.gd -- <outdir>
extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _shot(out: String, name: String) -> void:
	for _i in 4:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._clear_screen()
	var flow: Control = load("res://scripts/ui/setup_flow.gd").new()
	main.add_child(flow)
	main.screen = flow
	flow.setup(4)
	flow.show_planets()
	await _shot(out, "probe_planets")
	flow.show_probe_target("brume")
	await _shot(out, "probe_target")
	# Find a site with a lucky find to show off the report.
	const Probe = preload("res://scripts/sim/probe.gd")
	var site := 0
	for i in 4:
		if Probe.find_for(4, "brume", i) != "":
			site = i
			break
	flow._send_probe("brume", site, flow.show_planets)
	await _shot(out, "probe_report")
	flow._settle("brume", site)
	flow.show_sites()
	await _shot(out, "probe_sites")
	quit()
