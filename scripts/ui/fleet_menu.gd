## The Drones & Orbit dialog: build work drones at a Drone Bay, launch
## satellites from a Spin Launcher, and call supply pods down from the ship.
## `main` is the main screen (scripts/ui/main.gd), which owns the state and
## the dialog layer.
extends RefCounted

const Actions = preload("res://scripts/sim/actions.gd")
const Fleet = preload("res://scripts/sim/fleet.gd")
const ColonyText = preload("res://scripts/ui/colony_text.gd")

var main  # the main screen; untyped so its own methods can be called


func _init(owner_screen: Object) -> void:
	main = owner_screen


func show() -> void:
	var state: Dictionary = main.state
	var options: Array = []
	for t in Fleet.drone_order():
		var d := Fleet.drone_def(t)
		var label := "Build a %s (%d alloy, %d parts). You have %d.\n%s" % [d["name"], int(d["alloy"]), int(d["parts"]), Fleet.owned(state, t), d["desc"]]
		options.append([label, _act.bind("drone", t), Actions.check_drone(state, t)["ok"]])
	for t in Fleet.sat_order():
		var d := Fleet.sat_def(t)
		var label := "Launch a %s (%d alloy, %d parts, %d marks). In orbit: %d of %d.\n%s" % [str(d["name"]).to_lower(), int(d["alloy"]), int(d["parts"]), int(d["credits"]), Fleet.sats(state, t), int(d["max"]), d["desc"]]
		options.append([label, _act.bind("sat", t), Actions.check_satellite(state, t)["ok"]])
	if int(state["pods"]) > 0:
		options.append(["Call down a supply pod (%d left aboard the ship)" % int(state["pods"]), _act.bind("pod", ""), state["ending"] == ""])
	options.append(["Back", Callable(main, "close_modal"), true])
	main.show_modal("Drones & orbit", ColonyText.fleet_summary(state), options, true)


func _act(kind: String, type: String) -> void:
	var r: Dictionary
	match kind:
		"drone":
			r = Actions.build_drone(main.state, type)
		"sat":
			r = Actions.launch_satellite(main.state, type)
		_:
			r = Actions.call_pod(main.state)
	if not r["ok"]:
		main._toast(r["reason"])
	main.refresh()
	show()
