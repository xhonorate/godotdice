extends SceneTree
## Godot 4.7.2 shader-leak reproduction, with no game scripts or assets.
## Correct order: godot --headless --path . --script tools/repro_particle_shader.gd
## Leaking order: append -- --mesh-first (also reproduces with Forward+/Metal).

func _init() -> void:
	var mesh_first: bool = OS.get_cmdline_user_args().has("--mesh-first")
	var particles := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.turbulence_enabled = true
	process.color_ramp = GradientTexture1D.new()
	process.color_ramp.gradient = Gradient.new()
	var mesh := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	if mesh_first:
		particles.draw_pass_1 = mesh
		particles.process_material = process
	else:
		particles.process_material = process
		particles.draw_pass_1 = mesh
	root.add_child(particles)
	await process_frame
	await process_frame
	particles.free()
	process = null
	mesh = null
	material = null
	for frame in range(5):
		await process_frame
	print("Particle shader reproduction: ", "mesh first (leaks)" if mesh_first else "process material first")
	quit()
