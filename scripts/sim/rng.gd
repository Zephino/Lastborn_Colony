## Deterministic random numbers (mulberry32). The generator state lives in
## state["rng"], so a saved game replays identically.
## GDScript ints are 64-bit; every step is masked back to 32 bits.
extends RefCounted

const M32 := 0xFFFFFFFF


static func imul(a: int, b: int) -> int:
	a &= M32
	b &= M32
	var lo := (a & 0xFFFF) * b
	var hi := ((a >> 16) * b) & 0xFFFF
	return (lo + (hi << 16)) & M32


## Returns a float in [0, 1) and advances state["rng"].
static func next_float(state: Dictionary) -> float:
	var s: int = (int(state["rng"]) + 0x6D2B79F5) & M32
	state["rng"] = s
	var t: int = s
	t = imul(t ^ (t >> 15), t | 1)
	t ^= (t + imul(t ^ (t >> 7), t | 61)) & M32
	return float((t ^ (t >> 14)) & M32) / 4294967296.0


static func chance(state: Dictionary, p: float) -> bool:
	return next_float(state) < p


## Integer in [lo, hi], inclusive.
static func rand_int(state: Dictionary, lo: int, hi: int) -> int:
	return lo + int(floor(next_float(state) * float(hi - lo + 1)))


static func pick(state: Dictionary, list: Array) -> Variant:
	return list[int(floor(next_float(state) * float(list.size())))]


## Picks an index from a list of non-negative weights.
static func weighted_index(state: Dictionary, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := next_float(state) * total
	for i in weights.size():
		r -= float(weights[i])
		if r < 0.0:
			return i
	return weights.size() - 1


## FNV-1a hash of a string, for turning colony names into seeds.
static func hash_seed(text: String) -> int:
	var h := 2166136261
	for i in text.length():
		h ^= text.unicode_at(i)
		h = imul(h, 16777619)
	return h & M32
