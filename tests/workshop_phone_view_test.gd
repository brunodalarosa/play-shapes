extends TestScript
## The phone view keeps the native page over its frame in the window's physical pixels, whatever
## the stretch and whether subwindows are embedded. godot-wry reads the control's screen
## position and size; a plain control stands in for it here.


func _run() -> void:
	var phone := WorkshopPhoneView.new()
	phone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(phone)
	var page := Control.new()
	page.set_script(_stand_in())
	phone._screen.add_child(page)
	phone.web_view = page

	for embedded: bool in [true, false]:
		for scale: float in [1.0, 1.5, 0.75]:
			root.gui_embed_subwindows = embedded
			root.content_scale_factor = scale
			await process_frame
			await process_frame
			var to_pixels := root.get_final_transform()
			var frame := phone._screen
			var wanted := to_pixels * frame.get_global_transform_with_canvas().origin
			var case_name := "at %s with embedded subwindows %s" % [scale, embedded]
			check(page.get_screen_position().is_equal_approx(wanted), "In place " + case_name)
			var pixels := frame.size * to_pixels.get_scale()
			check(page.size.is_equal_approx(pixels), "Sized in pixels " + case_name)

	root.content_scale_factor = 1.0
	root.gui_embed_subwindows = true
	phone.web_view = null


## A control answering the page calls the phone view makes.
func _stand_in() -> GDScript:
	var script := GDScript.new()
	script.source_code = (
		"extends Control
"
		+ "func eval(_script: String) -> void:
	pass
"
		+ "func zoom(_factor: float) -> void:
	pass
"
	)
	script.reload()
	return script
