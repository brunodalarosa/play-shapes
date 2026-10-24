extends TestScript
## The bubble shell component: radius drives the drawn size, stretch reaches the shader, a pop
## hides the shell behind droplets and a re-form grows it back to full size.


func _run() -> void:
	var shell := BubbleShell3D.new()
	shell.radius = 0.8
	root.add_child(shell)
	var mesh := shell.get_node("Shell") as MeshInstance3D
	check(mesh.scale.is_equal_approx(Vector3.ONE * 0.8), "The shell is drawn at its radius")
	check(is_equal_approx(shell.shown_radius(), 0.8), "The shown radius is the full radius")

	shell.stretch = Vector2(0.15, -0.05)
	var material := mesh.material_override as ShaderMaterial
	var pull: Vector3 = material.get_shader_parameter(&"stretch")
	check(pull.is_equal_approx(Vector3(0.15, -0.05, 0.0)), "The stretch reaches the shader")
	shell.stretch = Vector2(3.0, 0.0)
	check(shell.stretch.length() <= 0.5, "An extreme stretch is limited")

	shell.tint = Color(1.0, 0.4, 0.4)
	check(
		material.get_shader_parameter(&"tint") == Color(1.0, 0.4, 0.4),
		"The tint reaches the shader",
	)

	shell.pop()
	check(shell.is_popped() and not mesh.visible, "A pop hides the shell")
	check(shell.is_bursting(), "A pop throws droplets")
	check(shell.shown_radius() == 0.0, "A popped shell shows no radius")

	shell.reform(0.2)
	check(not shell.is_popped() and mesh.visible, "A re-form shows the shell again")
	check(shell.shown_radius() < 0.8 * 0.2, "A re-form starts from a small bubble")
	check(shell.is_reforming(), "The re-form is under way")
	await create_timer(0.35).timeout
	check(not shell.is_reforming(), "The re-form finishes")
	check(is_equal_approx(shell.shown_radius(), 0.8), "A re-formed shell is back at full size")

	shell.radius = 1.4
	check(mesh.scale.is_equal_approx(Vector3.ONE * 1.4), "A new radius resizes the shell")
