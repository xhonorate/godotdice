extends RefCounted
## Where a fight happens. The shaft changes as it goes down: timbered galleries near the
## workshop, wet seeps, crystal veins, a fungal hollow, the magma seam, the geode at the
## heart of the mine, and below the third Warden the Rift, which has no floor worth the name.
##
## A biome is a palette, a fog, a light rig, a set of props and a set of drifting particles.
## `for_depth` picks one from the mine's own list (content may name one; the default is the
## order below), tints it with the mine's palette, and darkens and thickens it with depth, so
## depth 3 and depth 7 of the same band still look like two different rooms. The chamber
## builder seeds its prop layout from the mine and depth, so every depth is its own room.

const BIOMES: Dictionary = {
	"galleries": {
		"name": "The Upper Galleries",
		"rock": "6b5442", "rock_dark": "2c2119", "floor": "54402f", "moss": "7a6a4a",
		"background": "0c0806", "fog": "2a1c12", "fog_density": 0.030,
		"vol_density": 0.02, "vol_albedo": "d8c4aa", "vol_emission": "0c0603",
		"ambient": "6a5440", "ambient_energy": 0.55,
		"key": "ffd9a8", "key_energy": 4.2, "lights": ["ffa04a", "ff8a3a"], "light_energy": 3.2, "flicker": 0.22,
		"accent": "ffae55", "glow": 0.5, "saturation": 1.08, "contrast": 1.06,
		"props": ["timber", "rails", "lanterns", "rubble", "stalactites", "boulders"],
		"particles": ["dust", "motes"], "ground_mist": 0.25,
	},
	"seeps": {
		"name": "The Seeps",
		"rock": "3f5058", "rock_dark": "172026", "floor": "2f3d44", "moss": "4fae8f",
		"background": "05090b", "fog": "0f2027", "fog_density": 0.040,
		"vol_density": 0.045, "vol_albedo": "a9d8e6", "vol_emission": "021014",
		"ambient": "3f5a66", "ambient_energy": 0.6,
		"key": "cfe9ff", "key_energy": 5.0, "lights": ["4fd6c2", "5aa8ff"], "light_energy": 2.6, "flicker": 0.06,
		"accent": "5fe0d0", "glow": 0.6, "saturation": 1.0, "contrast": 1.08,
		"props": ["pools", "stalactites", "stalagmites", "moss", "boulders"],
		"particles": ["drips", "motes"], "ground_mist": 0.55,
	},
	"crystal": {
		"name": "The Crystal Veins",
		"rock": "3a3552", "rock_dark": "15121f", "floor": "2b2740", "moss": "7f6fd6",
		"background": "06040c", "fog": "140f26", "fog_density": 0.032,
		"vol_density": 0.035, "vol_albedo": "c9b8ff", "vol_emission": "0a0418",
		"ambient": "4a4270", "ambient_energy": 0.6,
		"key": "e6dcff", "key_energy": 4.6, "lights": ["b58cff", "6fb8ff", "ff8ae0"], "light_energy": 3.0, "flicker": 0.05,
		"accent": "c7a6ff", "glow": 0.9, "saturation": 1.15, "contrast": 1.08,
		"props": ["crystals", "stalagmites", "shards", "stalactites"],
		"particles": ["sparkles", "motes"], "ground_mist": 0.3,
	},
	"fungal": {
		"name": "The Mycelium",
		"rock": "3b4a36", "rock_dark": "141a12", "floor": "2d3a26", "moss": "8fe07a",
		"background": "050904", "fog": "12200f", "fog_density": 0.038,
		"vol_density": 0.028, "vol_albedo": "b8d8b0", "vol_emission": "030802",
		"ambient": "44603c", "ambient_energy": 0.5,
		"key": "f0ffe8", "key_energy": 4.4, "lights": ["8fff6a", "5ff0c0", "ffd06a"], "light_energy": 2.2, "flicker": 0.08,
		"accent": "a6ff7a", "glow": 0.8, "saturation": 0.95, "contrast": 1.08,
		"props": ["mushrooms", "roots", "stalagmites", "moss", "boulders"],
		"particles": ["spores", "motes"], "ground_mist": 0.6,
	},
	"magma": {
		"name": "The Magma Seam",
		"rock": "3a2622", "rock_dark": "120a09", "floor": "2a1a17", "moss": "ff6a2a",
		"background": "0a0302", "fog": "2a0d05", "fog_density": 0.034,
		"vol_density": 0.03, "vol_albedo": "e8b098", "vol_emission": "180500",
		"ambient": "5a2a1a", "ambient_energy": 0.45,
		"key": "ffe0c0", "key_energy": 4.2, "lights": ["ff5a1a", "ff8a2a", "ffb02a"], "light_energy": 3.4, "flicker": 0.3,
		"accent": "ff7a2a", "glow": 1.1, "saturation": 0.98, "contrast": 1.12,
		"props": ["lava", "basalt", "stalactites", "boulders"],
		"particles": ["embers", "ash"], "ground_mist": 0.2,
	},
	"geode": {
		"name": "The Geode Heart",
		"rock": "4a3f5a", "rock_dark": "1a1420", "floor": "3a2f40", "moss": "ffd76a",
		"background": "0a0708", "fog": "22182a", "fog_density": 0.028,
		"vol_density": 0.03, "vol_albedo": "ffe6c0", "vol_emission": "140c06",
		"ambient": "6a5a70", "ambient_energy": 0.6,
		"key": "fff0d0", "key_energy": 5.0, "lights": ["ffd76a", "ff9ad8", "9ad8ff"], "light_energy": 3.2, "flicker": 0.04,
		"accent": "ffd76a", "glow": 1.0, "saturation": 1.18, "contrast": 1.08,
		"props": ["geode", "crystals", "gold_veins", "shards"],
		"particles": ["sparkles", "motes"], "ground_mist": 0.25,
	},
	"rift": {
		"name": "The Rift",
		"rock": "2a2438", "rock_dark": "0a0812", "floor": "1c1828", "moss": "8a5aff",
		"background": "030208", "fog": "0c0618", "fog_density": 0.03,
		"vol_density": 0.035, "vol_albedo": "b09aff", "vol_emission": "0c0420",
		"ambient": "3a2a60", "ambient_energy": 0.6,
		"key": "d8ccff", "key_energy": 4.2, "lights": ["8a5aff", "ff5ad8", "5ad8ff"], "light_energy": 3.4, "flicker": 0.12,
		"accent": "a07aff", "glow": 1.1, "saturation": 1.15, "contrast": 1.1,
		"props": ["floating", "arches", "void_crystals", "shards"],
		"particles": ["void", "sparkles"], "ground_mist": 0.45,
	},
}

const color_FIELDS: Array = ["rock", "rock_dark", "floor", "moss", "background", "fog", "vol_albedo", "vol_emission", "ambient", "key", "accent"]

## Which biome each band of the shaft is, by the first depth it starts at.
const DEFAULT_BANDS: Array = [[1, "galleries"], [5, "seeps"], [9, "crystal"], [13, "fungal"], [17, "magma"], [21, "geode"], [25, "rift"]]

static func band_for(mine_key: String, depth: int) -> String:
	var mine: Dictionary = DeepContent.mine(mine_key)
	var bands: Array = mine.get("biomes", DEFAULT_BANDS)
	var chosen: String = "galleries"
	for band in bands:
		if band is Array and band.size() >= 2 and depth >= int(band[0]) and BIOMES.has(str(band[1])):
			chosen = str(band[1])
	return chosen

static func for_depth(mine_key: String, depth: int, kind: String = "fight") -> Dictionary:
	## The biome for this depth with its colors resolved, tinted by the mine and pressed
	## darker and foggier the further down the band it sits.
	var key: String = band_for(mine_key, depth)
	var raw: Dictionary = BIOMES[key]
	var out: Dictionary = {"id": key, "depth": depth, "kind": kind, "mine": mine_key}
	var tint := Color(str(DeepContent.mine(mine_key).get("palette", "c9a26b")))
	for field in raw:
		var value: Variant = raw[field]
		if field in color_FIELDS:
			var color := Color(str(value))
			if field in ["rock", "rock_dark", "floor"]:
				color = color.lerp(Color(tint, 1.0) * color.get_luminance() * 1.6, 0.12)
			out[field] = color
		elif field == "lights":
			out[field] = value.map(func(c: String) -> Color: return Color(c))
		elif value is Array:
			out[field] = value.duplicate()
		else:
			out[field] = value
	## Depth inside the band: deeper rooms are denser, darker and a little stranger.
	var within: float = clampf(float((depth - 1) % 4) / 3.0, 0.0, 1.0)
	var deep: float = clampf(float(depth) / 24.0, 0.0, 1.6)
	out.fog_density = float(out.fog_density) * (1.0 + 0.25 * within + 0.2 * deep)
	out.vol_density = float(out.vol_density) * (1.0 + 0.3 * within + 0.25 * deep)
	out.ambient_energy = float(out.ambient_energy) * (1.0 - 0.12 * within)
	out.intensity = clampf(0.6 + 0.4 * within + 0.3 * deep, 0.5, 1.6)
	out.warden = kind == "warden"
	out.elite = kind == "elite"
	if key == "rift" and depth > 24:
		## The Rift never settles: its colors turn with every Warden passed.
		var turn: float = fmod(float(depth - 25) * 0.07, 1.0)
		out.lights = out.lights.map(func(c: Color) -> Color: return Color.from_hsv(fmod(c.h + turn, 1.0), c.s, c.v))
		out.accent = Color.from_hsv(fmod(Color(out.accent).h + turn, 1.0), Color(out.accent).s, Color(out.accent).v)
	if out.warden:
		## A Warden's hall: pillars, a red rim, heavier air and the ceiling shedding dust.
		out.props = out.props + ["pillars", "braziers"]
		out.particles = out.particles + ["embers"]
		out.vol_density = float(out.vol_density) * 1.35
		out.lights = out.lights + [Color("ff3a2a")]
		out.name = "%s · Warden's Hall" % str(out.name)
	elif out.elite:
		out.props = out.props + ["braziers"]
		out.lights = out.lights + [Color("ff5a4a")]
	return out

static func names() -> Array:
	return BIOMES.keys()
