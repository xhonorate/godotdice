extends RefCounted
## Where a fight happens. Every mine is its own rock: timbered galleries in the Quarry, wet
## seeps, crystal veins, a fungal hollow, the magma seam, the geode, and at the bottom of
## everything the Rift, which has no floor worth the name. Each mine deepens as it goes:
## every Warden beaten opens onto a darker, stranger stretch of the same rock (VARIANTS).
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

## Each mine changes as the party goes down it: every Warden beaten opens onto a deeper stretch
## of the same rock, and a variant is its base biome with only what is different written out.
## `family` is the base biome a variant is a deeper stretch of; the room builder reads it
## wherever it asks what kind of rock it is building in.
const VARIANTS: Dictionary = {
	"galleries_deep": {
		"base": "galleries", "name": "The Lower Workings",
		"rock": "564538", "rock_dark": "221a14", "floor": "463628", "background": "080504", "fog": "201510", "fog_density": 0.036,
		"ambient": "4e3e30", "ambient_energy": 0.45, "key_energy": 3.8, "lights": ["ff8a3a", "d86a2a"], "light_energy": 2.6, "flicker": 0.3,
		"accent": "ff9a45", "props": ["timber", "rails", "rubble", "boulders", "stalagmites", "stalactites"],
		"particles": ["dust", "ash"], "ground_mist": 0.35,
	},
	"galleries_quartz": {
		"base": "galleries", "name": "The Quartz Cut",
		"rock": "6a6058", "rock_dark": "2a2420", "floor": "4e463e", "moss": "e8e0d0", "background": "0a0807", "fog": "221c18",
		"vol_albedo": "f0e6d8", "key": "fff2dc", "lights": ["ffe2b0", "f4f0ff", "ffb46a"], "light_energy": 3.0, "flicker": 0.12,
		"accent": "fff0c8", "glow": 0.8, "props": ["timber", "crystals", "shards", "boulders", "rails"],
		"particles": ["dust", "sparkles"], "ground_mist": 0.2,
	},
	"seeps_flooded": {
		"base": "seeps", "name": "The Flooded Drifts",
		"rock": "334650", "rock_dark": "101a20", "floor": "26343c", "background": "03070a", "fog": "0b1c24", "fog_density": 0.05,
		"vol_density": 0.06, "ambient": "34505e", "lights": ["3fb8e0", "4fd6c2"], "light_energy": 2.3,
		"props": ["pools", "stalactites", "roots", "moss", "stalagmites"], "particles": ["drips", "motes"], "ground_mist": 0.85,
	},
	"seeps_sump": {
		"base": "seeps", "name": "The Black Sump",
		"rock": "232c32", "rock_dark": "080c0f", "floor": "1a2226", "moss": "3affc8", "background": "020405", "fog": "06121a", "fog_density": 0.045,
		"vol_emission": "021a18", "ambient": "24343c", "ambient_energy": 0.45, "key_energy": 4.4, "lights": ["2affc8", "2a8aff", "8a5aff"], "light_energy": 2.8,
		"accent": "3affd0", "glow": 0.9, "props": ["pools", "moss", "mushrooms", "stalagmites", "stalactites"], "particles": ["drips", "spores"], "ground_mist": 0.7,
	},
	"crystal_prism": {
		"base": "crystal", "name": "The Prism Halls",
		"rock": "48445e", "floor": "38344e", "fog": "1c1830", "ambient": "5a5480", "ambient_energy": 0.7, "key_energy": 5.2,
		"lights": ["ff8ae0", "8affd8", "ffe08a", "8ab8ff"], "light_energy": 3.2, "accent": "ffd0f4", "glow": 1.1, "saturation": 1.25,
		"props": ["crystals", "shards", "geode", "stalagmites"], "particles": ["sparkles", "motes"], "ground_mist": 0.25,
	},
	"crystal_dark": {
		"base": "crystal", "name": "The Black Glass",
		"rock": "201c2c", "rock_dark": "08060c", "floor": "18141f", "background": "030206", "fog": "0c0818", "fog_density": 0.036,
		"ambient": "2c2648", "ambient_energy": 0.45, "lights": ["8a5aff", "c04aff"], "light_energy": 3.2, "accent": "a07aff",
		"props": ["void_crystals", "shards", "basalt", "crystals"], "particles": ["sparkles", "void"], "ground_mist": 0.35,
	},
	"fungal_bloom": {
		"base": "fungal", "name": "The Bloom",
		"moss": "ff8ae0", "fog": "1a1424", "vol_albedo": "e8c8f0", "ambient": "54405e", "lights": ["ff6ad8", "5ff0c0", "ffb06a"], "light_energy": 2.6,
		"accent": "ff8ae0", "glow": 1.0, "saturation": 1.1, "props": ["mushrooms", "roots", "moss", "boulders"], "particles": ["spores", "sparkles"], "ground_mist": 0.7,
	},
	"fungal_rot": {
		"base": "fungal", "name": "The Rot",
		"rock": "3a3a26", "rock_dark": "14140a", "floor": "2e2e1c", "moss": "c8d84a", "background": "060602", "fog": "1c1e08", "fog_density": 0.05,
		"vol_density": 0.045, "vol_albedo": "d8d890", "vol_emission": "0a0a02", "ambient": "4a4a26", "lights": ["c8ff3a", "e0b03a"], "light_energy": 2.0, "flicker": 0.14,
		"accent": "d4f04a", "saturation": 0.85, "props": ["roots", "mushrooms", "pools", "boulders", "stalagmites"], "particles": ["spores", "ash"], "ground_mist": 0.8,
	},
	"magma_glow": {
		"base": "magma", "name": "The Ember Crystals",
		"rock": "241816", "rock_dark": "080404", "floor": "1c1210", "moss": "ff2a1a", "background": "060101", "fog": "1e0804", "ambient": "40180e", "ambient_energy": 0.4,
		"lights": ["ff2a1a", "ff5a1a", "ff8a3a"], "light_energy": 3.6, "accent": "ff3a1a", "glow": 1.2,
		"props": ["basalt", "crystals", "lava", "stalactites"], "particles": ["embers", "ash"], "ground_mist": 0.2,
	},
	"magma_falls": {
		"base": "magma", "name": "The Lavafalls",
		"rock": "2e1a14", "rock_dark": "0c0504", "background": "0e0301", "fog": "3a1006", "fog_density": 0.04, "vol_density": 0.04, "vol_emission": "2a0800",
		"ambient": "6a2a12", "ambient_energy": 0.55, "key": "ffd0a0", "lights": ["ff6a1a", "ffa02a", "ff3a0a"], "light_energy": 4.0, "flicker": 0.42,
		"accent": "ff8a2a", "glow": 1.3, "contrast": 1.15, "props": ["lavafalls", "lava", "basalt", "boulders"], "particles": ["embers", "ash", "sparkles"], "ground_mist": 0.15,
	},
	"geode_gold": {
		"base": "geode", "name": "The Gilded Vault",
		"rock": "4a3e2c", "rock_dark": "1a140a", "floor": "3a3020", "moss": "ffd76a", "fog": "2a2010", "vol_albedo": "ffe6a0",
		"lights": ["ffd76a", "ffb03a", "fff0b0"], "light_energy": 3.4, "accent": "ffe08a", "saturation": 1.2,
		"props": ["gold_veins", "geode", "crystals", "boulders"], "particles": ["sparkles", "dust"], "ground_mist": 0.2,
	},
	"geode_amethyst": {
		"base": "geode", "name": "The Amethyst Throat",
		"rock": "3a2c4a", "rock_dark": "120a18", "floor": "2c2238", "moss": "c08aff", "fog": "1e1230", "vol_albedo": "e0c8ff",
		"lights": ["b07aff", "e08aff", "7a8aff"], "light_energy": 3.2, "accent": "c89aff",
		"props": ["geode", "void_crystals", "shards", "crystals"], "particles": ["sparkles", "motes"], "ground_mist": 0.3,
	},
	"rift_shattered": {
		"base": "rift", "name": "The Shattered Deep",
		"rock": "221c30", "floor": "16121f", "fog": "0a0414", "lights": ["5ad8ff", "8a5aff", "ffffff"], "accent": "7ad8ff",
		"props": ["floating", "shards", "void_crystals", "basalt"], "particles": ["void", "sparkles", "ash"], "ground_mist": 0.5,
	},
	"rift_echo": {
		"base": "rift", "name": "The Echoing Deep",
		"rock": "2c2430", "floor": "1e1822", "lights": ["ff5ad8", "ffb03a", "5affb0"], "accent": "ff8ad8",
		"props": ["arches", "crystals", "mushrooms", "lava", "floating"], "particles": ["void", "spores", "embers"], "ground_mist": 0.4,
	},
}

const color_FIELDS: Array = ["rock", "rock_dark", "floor", "moss", "background", "fog", "vol_albedo", "vol_emission", "ambient", "key", "accent"]

## Which biome each band of the shaft is, by the first depth it starts at.
const DEFAULT_BANDS: Array = [[1, "galleries"], [5, "seeps"], [9, "crystal"], [13, "fungal"], [17, "magma"], [21, "geode"], [25, "rift"]]

static func exists(key: String) -> bool:
	return BIOMES.has(key) or VARIANTS.has(key)

static func written(key: String) -> Dictionary:
	## A biome as written: a base biome, or a variant laid over the base it deepens.
	if BIOMES.has(key):
		var base: Dictionary = BIOMES[key].duplicate()
		base.family = key
		return base
	var variant: Dictionary = VARIANTS.get(key, {})
	if variant.is_empty():
		return written("galleries")
	var out: Dictionary = written(str(variant.get("base", "galleries")))
	for field in variant:
		if field != "base":
			out[field] = variant[field]
	return out

static func phase_for(mine_key: String, depth: int, wardens: Array = []) -> int:
	## Which stretch of a mine a depth is in: how many of its Wardens stand above it. A
	## run passes the Wardens where they really stand; without them, where they are written.
	## An endless mine moves on every time another Warden's worth of floors is behind it.
	var mine: Dictionary = DeepContent.mine(mine_key)
	if bool(mine.get("endless", false)):
		return maxi(0, depth - 1) / maxi(1, int(mine.get("warden_every", 8)))
	var listed: Array = wardens if not wardens.is_empty() else mine.get("warden_depths", [])
	var bottom: int = DeepContent.mine_bottom(mine_key)
	var passed: int = 0
	for at in listed:
		if int(at) < depth and int(at) != bottom:
			passed += 1
	return passed

static func run_phase(state: Dictionary, depth: int) -> int:
	## The stretch a run is in at a depth, by where this run's own Wardens stand.
	return phase_for(str(state.get("mine", "")), depth, state.get("schedule", {}).get("wardens", []))

static func band_for(mine_key: String, depth: int, phase: int = -1) -> String:
	## A mine lists its biomes one per stretch, the next one opening past each Warden (older
	## packs listed them by the first depth each began at, which still reads).
	var mine: Dictionary = DeepContent.mine(mine_key)
	var bands: Array = mine.get("biomes", DEFAULT_BANDS)
	if not bands.is_empty() and bands[0] is String:
		var at: int = phase if phase >= 0 else phase_for(mine_key, depth)
		var named: String = str(bands[at % bands.size()])
		return named if exists(named) else "galleries"
	var chosen: String = "galleries"
	for band in bands:
		if band is Array and band.size() >= 2 and depth >= int(band[0]) and exists(str(band[1])):
			chosen = str(band[1])
	return chosen

static func for_depth(mine_key: String, depth: int, kind: String = "fight", phase: int = -1) -> Dictionary:
	## The biome for this depth with its colors resolved, tinted by the mine and pressed
	## darker and foggier the further down the band it sits.
	var key: String = band_for(mine_key, depth, phase)
	var raw: Dictionary = written(key)
	var out: Dictionary = {"id": key, "depth": depth, "kind": kind, "mine": mine_key}
	var tint := Color(str(DeepContent.mine(mine_key).get("palette", "c9a26b")))
	for field in raw:
		var value: Variant = raw[field]
		if field == "family":
			out[field] = value
		elif field in color_FIELDS:
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
	if str(out.family) == "rift" and depth > 8:
		## The Rift never settles: its colors turn with every Warden passed.
		var turn: float = fmod(float(depth - 9) * 0.07, 1.0)
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
	return BIOMES.keys() + VARIANTS.keys()
