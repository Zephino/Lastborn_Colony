## Generates the surface map. Columns run from the frozen night side (west)
## to the scorched day side (east). Deterministic for a given seed.
extends RefCounted

const GameData = preload("res://scripts/sim/game_data.gd")
const Rng = preload("res://scripts/sim/rng.gd")

const BUILDABLE := ["regolith", "ice", "vent", "seam"]
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Returns {"tiles": Array of rows of terrain names, "hull": [x, y]}.
## The planet sets how much ice, rock, ore and vents there are; the landing
## site (an index into balance.json "landing_sites") moves the pad.
static func generate(map_seed: int, planet_id: String = "brume", site: int = 0) -> Dictionary:
	var b := GameData.balance()
	var planet := GameData.planet(planet_id)
	var w: int = int(b["map_width"])
	var h: int = int(b["map_height"])
	var r := {"rng": map_seed & Rng.M32}
	var tiles: Array = []

	# 1. Random ice, denser toward the night side.
	for y in h:
		var row: Array = []
		for x in w:
			var xf := float(x) / float(w - 1)
			row.append("ice" if Rng.next_float(r) < 0.62 * (1.0 - xf) * float(planet["ice"]) else "regolith")
		tiles.append(row)

	# 2. Smooth into patches.
	for _pass in 2:
		var next: Array = []
		for y in h:
			var row: Array = []
			for x in w:
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var yy := clampi(y + dy, 0, h - 1)
						var xx := clampi(x + dx, 0, w - 1)
						if tiles[yy][xx] == "ice":
							n += 1
				if n >= 5:
					row.append("ice")
				elif n <= 3:
					row.append("regolith")
				else:
					row.append(tiles[y][x])
			next.append(row)
		tiles = next

	# 3. Ridges: short random walks of impassable rock.
	for _i in int(planet["ridges"]):
		var p := Vector2i(Rng.rand_int(r, 3, w - 4), Rng.rand_int(r, 1, h - 2))
		for _step in Rng.rand_int(r, 5, 11):
			tiles[p.y][p.x] = "ridge"
			var d: Vector2i = Rng.pick(r, DIRS)
			p = Vector2i(clampi(p.x + d.x, 2, w - 3), clampi(p.y + d.y, 0, h - 1))

	# 4. Ore seams in small clusters.
	for _i in int(planet["seams"]):
		var c := Vector2i(Rng.rand_int(r, 4, w - 5), Rng.rand_int(r, 1, h - 2))
		tiles[c.y][c.x] = "seam"
		for _j in Rng.rand_int(r, 1, 3):
			var d: Vector2i = Rng.pick(r, DIRS)
			tiles[c.y + d.y][c.x + d.x] = "seam"

	# 5. Vents, mostly on the colder half.
	for _i in int(planet["vents"]):
		var x := Rng.rand_int(r, 3, w / 2 + 3)
		var y := Rng.rand_int(r, 0, h - 1)
		tiles[y][x] = "vent"

	# 6. Night-side and day-side edges cannot be built on.
	for y in h:
		for x in w:
			if x < 2:
				tiles[y][x] = "deepice"
			elif x >= w - 2:
				tiles[y][x] = "scorch"

	# 7. Clear a landing pad and guarantee a usable start.
	var sites: Array = b["landing_sites"]
	var offset: Array = sites[clampi(site, 0, sites.size() - 1)]
	var hull := Vector2i(w / 2 + int(offset[0]), h / 2 + int(offset[1]))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			tiles[hull.y + dy][hull.x + dx] = "regolith"
	_ensure_near(tiles, hull, "ice", Vector2i(-3, 2))
	_ensure_near(tiles, hull, "vent", Vector2i(-5, -2))
	_ensure_near(tiles, hull, "seam", Vector2i(3, 3))
	return {"tiles": tiles, "hull": [hull.x, hull.y]}


## Makes sure a tile of the given terrain can be reached from the pad within
## a short run of heat mains; otherwise places one at hull + fallback and
## clears a straight path to it.
static func _ensure_near(tiles: Array, hull: Vector2i, terrain: String, fallback: Vector2i) -> void:
	var dist := _reach(tiles, hull)
	for key in dist:
		var c: Vector2i = key
		if int(dist[key]) > 7:
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if _inside(tiles, n) and tiles[n.y][n.x] == terrain:
				return
	var p := hull + fallback
	var q := hull
	var step := Vector2i(signi(fallback.x), 0)
	while q.x != p.x:
		q += step
		if q != p and not (tiles[q.y][q.x] in ["regolith", "ice"]):
			tiles[q.y][q.x] = "regolith"
	step = Vector2i(0, signi(fallback.y))
	while q.y != p.y:
		q += step
		if q != p and not (tiles[q.y][q.x] in ["regolith", "ice"]):
			tiles[q.y][q.x] = "regolith"
	tiles[p.y][p.x] = terrain


## Steps from the pad to every regolith/ice tile (tiles a heat main can cross).
static func _reach(tiles: Array, start: Vector2i) -> Dictionary:
	var dist := {start: 0}
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if dist.has(n) or not _inside(tiles, n):
				continue
			if tiles[n.y][n.x] == "regolith" or tiles[n.y][n.x] == "ice":
				dist[n] = int(dist[c]) + 1
				queue.append(n)
	return dist


static func _inside(tiles: Array, c: Vector2i) -> bool:
	return c.y >= 0 and c.y < tiles.size() and c.x >= 0 and c.x < tiles[0].size()


static func is_buildable_terrain(terrain: String) -> bool:
	return terrain in BUILDABLE
