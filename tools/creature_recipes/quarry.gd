extends RefCounted
## The Quarry's new creatures and its rebuilt boss, as recipes for tools/creature_bake.gd.

static func recipes() -> Dictionary:
	return {
		"RAIL_RAT": {"style": "low", "sway": 3.4, "tint": "a8927a", "accent": "ffb24a", "anchor": 0.9, "shadow": 1.8, "ring": 0.9, "parts": [
			## A low body, a wedge of a head, a long tail, and amber crystals along the spine.
			{"shape": "rock", "at": [0, 0.28, 0], "scale": [0.55, 0.3, 0.42], "material": "body", "motion": "core", "jitter": 0.18},
			{"shape": "rock", "at": [0.0, 0.3, 0.42], "scale": [0.26, 0.2, 0.3], "material": "body", "motion": "bob", "phase": 0.4, "jitter": 0.14},
			{"shape": "cone", "at": [0.09, 0.42, 0.52], "rot": [-20, 0, 15], "scale": [0.08, 0.14, 0.08], "material": "body", "radius": 1.0, "height": 1.0, "sides": 5},
			{"shape": "cone", "at": [-0.09, 0.42, 0.52], "rot": [-20, 0, -15], "scale": [0.08, 0.14, 0.08], "material": "body", "radius": 1.0, "height": 1.0, "sides": 5},
			{"shape": "sphere", "at": [0.08, 0.3, 0.58], "scale": 0.035, "material": "accent", "radius": 1.0, "segments": 6, "rings": 3},
			{"shape": "sphere", "at": [-0.08, 0.3, 0.58], "scale": 0.035, "material": "accent", "radius": 1.0, "segments": 6, "rings": 3},
			{"shape": "crystal", "at": [0.0, 0.5, 0.1], "rot": [-25, 0, 0], "material": "accent", "motion": "crystal", "radius": 0.05, "height": 0.32},
			{"shape": "crystal", "at": [0.08, 0.46, -0.08], "rot": [-10, 0, 25], "material": "accent", "motion": "crystal", "radius": 0.045, "height": 0.26},
			{"shape": "crystal", "at": [-0.07, 0.46, -0.22], "rot": [10, 0, -30], "material": "accent", "motion": "crystal", "radius": 0.04, "height": 0.22},
			{"shape": "capsule", "at": [0, 0.22, -0.55], "rot": [80, 0, 0], "scale": [0.05, 0.4, 0.05], "material": "body", "motion": "swing", "radius": 1.0, "height": 2.0, "segments": 6},
			{"shape": "cylinder", "at": [0.22, 0.1, 0.25], "rot": [0, 0, 20], "scale": [0.05, 0.2, 0.05], "material": "body", "top": 0.8, "bottom": 1.0, "height": 1.0, "sides": 5},
			{"shape": "cylinder", "at": [-0.22, 0.1, 0.25], "rot": [0, 0, -20], "scale": [0.05, 0.2, 0.05], "material": "body", "top": 0.8, "bottom": 1.0, "height": 1.0, "sides": 5},
			{"shape": "cylinder", "at": [0.22, 0.1, -0.2], "rot": [0, 0, 20], "scale": [0.05, 0.2, 0.05], "material": "body", "top": 0.8, "bottom": 1.0, "height": 1.0, "sides": 5},
			{"shape": "cylinder", "at": [-0.22, 0.1, -0.2], "rot": [0, 0, -20], "scale": [0.05, 0.2, 0.05], "material": "body", "top": 0.8, "bottom": 1.0, "height": 1.0, "sides": 5}]},
		"PIT_MOLE": {"style": "low", "sway": 2.0, "tint": "7a5a42", "accent": "ffd06a", "anchor": 1.3, "shadow": 2.4, "parts": [
			## A hunched velvet body half out of the floor, a pointed snout and two great crystal claws.
			{"shape": "rock", "at": [0, 0.5, -0.1], "scale": [0.8, 0.6, 0.85], "material": "body", "motion": "core", "jitter": 0.2},
			{"shape": "cone", "at": [0, 0.55, 0.75], "rot": [90, 0, 0], "scale": [0.3, 0.5, 0.3], "material": "body", "radius": 1.0, "height": 1.0, "sides": 7},
			{"shape": "sphere", "at": [0, 0.55, 1.0], "scale": 0.07, "material": "accent", "radius": 1.0, "segments": 6, "rings": 3},
			{"shape": "crystal", "at": [0.55, 0.25, 0.55], "rot": [60, 0, 20], "material": "accent", "motion": "crystal", "radius": 0.08, "height": 0.55},
			{"shape": "crystal", "at": [0.7, 0.25, 0.45], "rot": [60, 0, 35], "material": "accent", "motion": "crystal", "radius": 0.07, "height": 0.45},
			{"shape": "crystal", "at": [-0.55, 0.25, 0.55], "rot": [60, 0, -20], "material": "accent", "motion": "crystal", "radius": 0.08, "height": 0.55},
			{"shape": "crystal", "at": [-0.7, 0.25, 0.45], "rot": [60, 0, -35], "material": "accent", "motion": "crystal", "radius": 0.07, "height": 0.45},
			{"shape": "rock", "at": [0, 0.12, 0], "scale": [1.3, 0.14, 1.3], "material": "body", "jitter": 0.35, "seed": 3},
			{"shape": "rock", "at": [0.9, 0.1, -0.5], "scale": [0.3, 0.2, 0.3], "material": "body", "jitter": 0.3, "seed": 4},
			{"shape": "rock", "at": [-0.8, 0.1, 0.3], "scale": [0.25, 0.18, 0.25], "material": "body", "jitter": 0.3, "seed": 5}]},
		"THE_DRILL": {"style": "tower", "sway": 0.4, "tint": "6b625c", "accent": "ff5a2a", "anchor": 3.0, "warden": true, "shadow": 3.6, "ring": 1.7, "parts": [
			## A rusted mining rig on treads: a boxy hull, a great drill out front, a smokestack and a red lamp.
			{"shape": "slab", "at": [0, 0.75, -0.2], "material": "body", "motion": "block", "size": [1.9, 0.9, 2.0], "jitter": 0.04},
			{"shape": "slab", "at": [0, 1.45, -0.5], "rot": [0, 6, 0], "material": "body", "motion": "block", "size": [1.3, 0.6, 1.1], "jitter": 0.04},
			{"shape": "cylinder", "at": [1.05, 0.38, -0.2], "rot": [0, 0, 90], "material": "body", "motion": "tread", "top": 0.38, "bottom": 0.38, "height": 0.35, "sides": 10},
			{"shape": "cylinder", "at": [-1.05, 0.38, -0.2], "rot": [0, 0, 90], "material": "body", "motion": "tread", "top": 0.38, "bottom": 0.38, "height": 0.35, "sides": 10},
			{"shape": "box", "at": [1.05, 0.38, -0.2], "material": "core", "size": [0.4, 0.5, 1.9]},
			{"shape": "box", "at": [-1.05, 0.38, -0.2], "material": "core", "size": [0.4, 0.5, 1.9]},
			{"shape": "drill", "at": [0, 0.95, 1.75], "rot": [90, 0, 0], "material": "accent", "motion": "drill", "radius": 0.44, "height": 1.5, "flutes": 3, "turns": 1.75},
			{"shape": "cylinder", "at": [0, 0.95, 0.95], "rot": [90, 0, 0], "material": "body", "motion": "drill", "top": 0.3, "bottom": 0.42, "height": 0.5, "sides": 8},
			{"shape": "cylinder", "at": [-0.5, 2.2, -0.7], "material": "body", "top": 0.16, "bottom": 0.2, "height": 1.0, "sides": 7},
			{"shape": "sphere", "at": [-0.5, 2.85, -0.7], "scale": 0.22, "material": "core", "motion": "flicker", "radius": 1.0, "segments": 7, "rings": 4},
			{"shape": "sphere", "at": [0.45, 1.85, 0.1], "scale": 0.17, "material": "accent", "motion": "core", "radius": 1.0, "segments": 7, "rings": 4},
			{"shape": "crystal", "at": [0.6, 1.8, -0.9], "rot": [-15, 0, 20], "material": "core", "motion": "crystal", "radius": 0.12, "height": 0.8},
			{"shape": "crystal", "at": [-0.2, 1.85, -1.0], "rot": [-20, 0, -10], "material": "core", "motion": "crystal", "radius": 0.1, "height": 0.6}]}}
