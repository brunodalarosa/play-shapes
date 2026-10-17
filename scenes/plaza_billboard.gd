class_name PlazaBillboard
extends Node3D
## The plaza billboard. Its display shows the game logo and the live join QR, drawn in a
## SubViewport that renders only when its content changes.

@onready var qr: QRCodeRect = %JoinQR
@onready var _screen: SubViewport = $Screen
@onready var _qr_background: Control = %JoinQRBackground
@onready var _no_address: Label = %NoAddress


func _ready() -> void:
	var display := find_child("Display", true, false) as MeshInstance3D
	assert(display != null, "Billboard model has no Display surface")
	var material := StandardMaterial3D.new()
	# Unshaded keeps the QR at full contrast whatever the plaza lighting does.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _screen.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	display.material_override = material
	show_no_address()


func show_join_url(url: String) -> void:
	qr.data = url.to_utf8_buffer()
	qr.update()
	_qr_background.show()
	_no_address.hide()
	_redraw()


func show_no_address() -> void:
	_qr_background.hide()
	_no_address.show()
	_redraw()


func is_showing_qr() -> bool:
	return _qr_background.visible


func _redraw() -> void:
	_screen.render_target_update_mode = SubViewport.UPDATE_ONCE
