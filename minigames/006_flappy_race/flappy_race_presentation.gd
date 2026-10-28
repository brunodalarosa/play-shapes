class_name FlappyRacePresentation
extends Control
## The shared screen of a Flappy Race: the course, every Cubio drawn from the controller's
## settled flights and smoothed between ticks, the race camera with bubbles for racers behind
## it, the overlap dither (decision 0051) and the HUD. It reads the controller and never
## changes the race.

const CUBIO_SCENE: PackedScene = preload("res://characters/cubio_3d.tscn")
const CUBIO_HEIGHT := 2.62
## Cubio's body centre above its soles, metres; it turns about this point.
const BODY_CENTRE := 1.62
## Half the width and height of a Cubio's outline, metres: the body with its floating hands.
const OUTLINE := Vector2(1.6, 1.4)
## A disconnected Cubio's colour is mixed this far toward grey.
const GREY := Color(0.55, 0.57, 0.6)
const GREY_SHARE := 0.7
const TUMBLE_TURNS := 1.5
const GO_SECONDS := 0.6
const BURST_DROPS := 10
const BURST_REACH := 1.8


## One racer as drawn.
class RacerVisual:
	extends RefCounted

	var racer: FlappyRaceRacer
	var pivot := Node3D.new()
	var cubio: Cubio3D
	var heart := Label3D.new()
	var name_label := ScreenFollowLabel.new()
	var badge := ScreenFollowLabel.new()
	var color := Color.WHITE
	var slot := 0
	## Settled positions of the previous and the latest tick, and the position drawn now.
	var previous := Vector2.ZERO
	var current := Vector2.ZERO
	var drawn := Vector2.ZERO
	var was_flying := true
	var hit_at := -INF
	var hit_spot := Vector2.ZERO
	var pickup_at := -INF
	var tilt := 0.0
	var shown_color := Color.WHITE
	var face := ""


var controller: FlappyRaceController
var _visuals: Array[RacerVisual] = []
var _by_id: Dictionary[String, RacerVisual] = { }
var _leader := Vector2.ZERO
var _framed := false

@onready var camera: RaceCamera3D = %Camera
@onready var course_view: FlappyRaceCourseView = %CourseView
@onready var bubbles: OffscreenBubbles = %Bubbles
@onready var _racers_root: Node3D = %Racers
@onready var _bursts: Node3D = %Bursts
@onready var _labels: Control = %Labels
@onready var _timer: Label = %Timer
@onready var _cue: Label = %Cue


func _ready() -> void:
	(%Sun as DirectionalLight3D).rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	set_process(false)


## Draws [param race] from now on. Call once, after its countdown has started.
func bind(race: FlappyRaceController) -> void:
	controller = race
	var view := race.tuning.view
	camera.leader_share = view.leader_screen_share
	camera.closest_height = race.course.view_height
	camera.farthest_height = view.farthest_visible_height
	camera.centre_height = race.course.view_height * 0.5
	camera.smoothing_seconds = view.camera_smoothing_seconds
	camera.current = true
	course_view.build(race.course)

	var by_seat := race.racers()
	by_seat.sort_custom(
		func(a: FlappyRaceRacer, b: FlappyRaceRacer) -> bool:
			return a.seat < b.seat,
	)
	for slot: int in by_seat.size():
		_add_visual(by_seat[slot], slot)
	race.tick_settled.connect(_on_tick_settled)
	race.race_event.connect(_on_race_event)
	set_process(true)
	draw_frame(0.0)


func visual_for(player_id: String) -> RacerVisual:
	return _by_id.get(player_id)


## Seconds of race time drawn now, from GO, between settled ticks.
func race_seconds() -> float:
	if controller == null:
		return 0.0
	var ticks := controller.settled_tick + controller.settled_fraction()
	return ticks / FlappyFlightTuning.TICK_RATE


func timer_text() -> String:
	return _timer.text


func cue_text() -> String:
	return _cue.text


## 1st, 2nd, 3rd, 4th, ..., 11th, 12th, 13th, ..., 21st.
static func ordinal(place: int) -> String:
	var tens := place % 100
	var suffix := "th"
	if tens < 11 or tens > 13:
		suffix = { 1: "st", 2: "nd", 3: "rd" }.get(place % 10, "th")
	return "%d%s" % [place, suffix]


func _process(delta: float) -> void:
	draw_frame(delta)


## Moves everything to the race as it stands; [param delta] zero jumps the camera there.
func draw_frame(delta: float) -> void:
	if controller == null:
		return

	var now := race_seconds()
	var fraction := controller.settled_fraction()
	var results := controller.phase == FlappyRaceController.Phase.RESULTS
	var places: Dictionary[String, int] = { }
	var order := (
		controller.ranking() if results else FlappyRaceController.rank(controller.racers())
	)
	for index: int in order.size():
		places[order[index].player_id] = index + 1

	for visual: RacerVisual in _visuals:
		_draw_racer(visual, now, fraction, places.get(visual.racer.player_id, 0), delta)
	_frame_camera(delta)
	_dither_overlaps()
	_show_bubbles()
	_draw_hud(now)
	for visual: RacerVisual in _visuals:
		visual.name_label.follow()
		visual.badge.follow()
	_stack_labels()


func _add_visual(racer: FlappyRaceRacer, slot: int) -> void:
	var visual := RacerVisual.new()
	visual.racer = racer
	visual.slot = slot
	visual.color = Color.html(racer.character_color)
	visual.shown_color = visual.color
	visual.current = Vector2(racer.state.x, racer.state.y)
	visual.previous = visual.current
	visual.drawn = visual.current
	visual.was_flying = racer.state.flying

	visual.pivot.name = "Racer_%s" % racer.player_id.validate_node_name()
	_racers_root.add_child(visual.pivot)
	visual.cubio = CUBIO_SCENE.instantiate() as Cubio3D
	visual.cubio.standing_height = CUBIO_HEIGHT
	visual.cubio.player_color = visual.color
	visual.cubio.position.y = -BODY_CENTRE
	visual.pivot.add_child(visual.cubio)
	visual.cubio.nameplate.visible = false

	visual.heart.text = "♥"
	visual.heart.font_size = 256
	visual.heart.pixel_size = 0.012
	visual.heart.outline_size = 24
	visual.heart.outline_modulate = Color(0.25, 0.1, 0.12)
	visual.heart.modulate = visual.color
	visual.heart.visible = false
	_racers_root.add_child(visual.heart)

	for label: ScreenFollowLabel in [visual.name_label, visual.badge]:
		label.target = visual.pivot
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.16))
		label.add_theme_constant_override("outline_size", 8)
		_labels.add_child(label)
		# Placed by draw_frame, after the Cubios move and before the crowd is stacked.
		label.set_process(false)
	visual.name_label.text = racer.display_name
	visual.name_label.add_theme_font_size_override("font_size", 30)
	visual.name_label.world_offset = Vector3(0.0, CUBIO_HEIGHT - BODY_CENTRE + 0.4, 0.0)
	visual.name_label.screen_offset = Vector2(0.0, -46.0)
	visual.badge.add_theme_font_size_override("font_size", 26)
	visual.badge.world_offset = visual.name_label.world_offset
	var plate := StyleBoxFlat.new()
	plate.bg_color = visual.color.darkened(0.25)
	plate.set_corner_radius_all(12)
	plate.content_margin_left = 10.0
	plate.content_margin_right = 10.0
	visual.badge.add_theme_stylebox_override("normal", plate)

	_visuals.append(visual)
	_by_id[racer.player_id] = visual


func _on_tick_settled(_tick: int) -> void:
	for visual: RacerVisual in _visuals:
		visual.previous = visual.current
		visual.current = Vector2(visual.racer.state.x, visual.racer.state.y)


func _on_race_event(kind: StringName, player_id: String, data: Dictionary) -> void:
	var visual: RacerVisual = _by_id.get(player_id)
	if kind != &"pickup" or visual == null:
		return
	visual.pickup_at = race_seconds()
	var index := int(data.get("pickup", -1))
	var pickups := controller.course.flight.pickups
	if index >= 0 and index < pickups.size():
		_burst(Vector3(pickups[index].x, pickups[index].y, 0.8), visual.color)


func _draw_racer(
	visual: RacerVisual,
	now: float,
	fraction: float,
	place: int,
	delta: float,
) -> void:
	var racer := visual.racer
	var state := racer.state
	if racer.dnf:
		visual.pivot.visible = false
		visual.heart.visible = false
		return

	var view := controller.tuning.view
	var between := visual.previous.lerp(visual.current, fraction)
	visual.drawn = between if state.flying else visual.current
	if visual.was_flying and not state.flying:
		visual.hit_at = now
	if state.flying:
		visual.hit_spot = visual.drawn
	visual.was_flying = state.flying
	var tumbling := not state.flying and now - visual.hit_at < view.hit_tumble_seconds
	var spot := visual.hit_spot if tumbling else visual.drawn
	visual.pivot.visible = state.flying or tumbling or state.ready
	visual.pivot.position = Vector3(spot.x, spot.y, visual.slot * view.depth_slot)

	var tuning := controller.tuning.flight
	var speed := state.vertical_speed
	var target := deg_to_rad(
		(
			view.tilt_up_degrees * minf(1.0, speed / tuning.flap_velocity)
			if speed >= 0.0
			else -view.tilt_down_degrees * minf(1.0, -speed / tuning.max_fall_speed)
		)
	)
	var response := view.tilt_response_seconds
	var follow := 1.0 if response <= 0.0 else 1.0 - exp(-delta / response)
	visual.tilt = lerpf(visual.tilt, target, follow)
	var spin := -(now - visual.hit_at) * TAU * TUMBLE_TURNS
	visual.pivot.rotation.z = spin if tumbling else visual.tilt

	var color := visual.color if racer.connected else visual.color.lerp(GREY, GREY_SHARE)
	if color != visual.shown_color:
		visual.shown_color = color
		visual.cubio.player_color = color
	var face := _face(visual, now, tumbling, place)
	if face != visual.face:
		visual.face = face
		visual.cubio.expressions.base_face = face

	var waiting := not state.flying and not tumbling
	var results := controller.phase == FlappyRaceController.Phase.RESULTS
	visual.heart.visible = waiting and not results
	if visual.heart.visible:
		var depth := visual.slot * view.depth_slot + 0.4
		visual.heart.position = Vector3(state.x, state.y, depth)
		var alpha := 0.35 if state.hearts.owed else (1.0 if state.ready else 0.7)
		visual.heart.modulate = Color(visual.color, alpha)
		var pulse := 1.0 + 0.15 * sin(now * 9.0) if state.ready else 1.0
		visual.heart.scale = Vector3.ONE * pulse
	visual.badge.text = ordinal(place) if place > 0 else ""


func _face(visual: RacerVisual, now: float, tumbling: bool, place: int) -> String:
	var state := visual.racer.state
	match controller.phase:
		FlappyRaceController.Phase.COUNTDOWN:
			return "face_scheming"
		FlappyRaceController.Phase.RESULTS:
			if _visuals.size() == 1:
				return "face_slightly_smiling" if visual.racer.finished() else "face_disappointed"
			return "face_mischievous" if place <= 3 else "face_disappointed"
	if tumbling:
		return "face_dizzy"
	if not state.flying:
		return "face_worried"
	if now - visual.pickup_at < controller.tuning.view.pickup_face_seconds:
		return "face_beaming"
	return "face_slightly_smiling"


## Follows the leader still racing, counting waiting and frozen players where they are, and
## fits the others still racing.
func _frame_camera(delta: float) -> void:
	var racing := _visuals.filter(
		func(visual: RacerVisual) -> bool:
			return not visual.racer.dnf and not visual.racer.finished(),
	)
	var others := PackedVector2Array()
	if not racing.is_empty():
		var leader: RacerVisual = racing[0]
		for visual: RacerVisual in racing:
			if visual.drawn.x > leader.drawn.x:
				leader = visual
		_leader = Vector2(leader.drawn.x, leader.drawn.y)
		for visual: RacerVisual in racing:
			if visual != leader:
				others.append(visual.drawn)
	elif not _framed:
		_leader = _visuals[0].drawn
	camera.frame_race(_leader, others, delta if _framed else 0.0)
	_framed = true


## Dithers each visible Cubio whose outline covers one in a slot behind it.
func _dither_overlaps() -> void:
	var view := controller.tuning.view
	var pixels := get_viewport_rect().size.y / camera.visible_height
	var outlines: Dictionary[RacerVisual, Rect2] = { }
	for visual: RacerVisual in _visuals:
		if visual.pivot.is_visible_in_tree():
			var centre := camera.unproject_position(visual.pivot.global_position)
			outlines[visual] = Rect2(centre - OUTLINE * pixels, OUTLINE * pixels * 2.0)
	for visual: RacerVisual in _visuals:
		var covers := false
		if outlines.has(visual):
			for other: RacerVisual in outlines:
				if other.slot < visual.slot and outlines[visual].intersects(outlines[other]):
					covers = true
					break
		visual.cubio.set_dither(view.overlap_dither if covers else 0.0)


func _show_bubbles() -> void:
	var left := camera.visible_rect().position.x
	var entries: Array[OffscreenBubbles.Entry] = []
	for visual: RacerVisual in _visuals:
		var racer := visual.racer
		if racer.dnf or racer.finished() or visual.drawn.x + OUTLINE.x >= left:
			continue
		var height := camera.unproject_position(Vector3(left, visual.drawn.y, 0.0)).y
		var entry := OffscreenBubbles.Entry.new(
			racer.player_id,
			racer.display_name,
			visual.shown_color,
			visual.face,
			height,
		)
		entries.append(entry)
	bubbles.show_racers(entries)


func _draw_hud(now: float) -> void:
	var view := controller.tuning.view
	var left_ticks := controller.race_ticks() - controller.settled_tick
	var seconds_left := ceili(float(left_ticks) / FlappyFlightTuning.TICK_RATE)
	_timer.text = "%d:%02d" % [floori(seconds_left / 60.0), seconds_left % 60]

	var cue := ""
	match controller.phase:
		FlappyRaceController.Phase.COUNTDOWN:
			cue = str(maxi(1, ceili(controller.countdown_remaining_msec() / 1000.0)))
		FlappyRaceController.Phase.RACING:
			if now < GO_SECONDS:
				cue = "GO!"
			elif controller.settled_tick >= controller.last_seconds_tick():
				cue = str(seconds_left)
	_cue.text = cue

	var alpha := 1.0
	if now > view.name_seconds:
		var faded := (now - view.name_seconds) / maxf(view.name_fade_seconds, 0.001)
		alpha = clampf(1.0 - faded, 0.0, 1.0)
	for visual: RacerVisual in _visuals:
		visual.name_label.modulate.a = alpha
		# A place among one says nothing.
		var racing := controller.phase == FlappyRaceController.Phase.RACING and _visuals.size() > 1
		visual.badge.modulate.a = 1.0 if racing else 0.0


## Lifts each racer's name and badge, together, above any that would cover them, lowest first,
## so a crowd stays readable and every name keeps its place.
func _stack_labels() -> void:
	var units: Array[Array] = []
	for visual: RacerVisual in _visuals:
		var labels: Array[Label] = []
		for label: Label in [visual.name_label, visual.badge]:
			if label.visible and label.modulate.a > 0.0 and label.text != "":
				labels.append(label)
		if not labels.is_empty():
			units.append(labels)
	var bounds := func(labels: Array) -> Rect2:
		var rect := Rect2(labels[0].position, labels[0].size)
		for label: Label in labels:
			rect = rect.merge(Rect2(label.position, label.size))
		return rect
	units.sort_custom(
		func(a: Array, b: Array) -> bool:
			return bounds.call(a).end.y > bounds.call(b).end.y,
	)

	var placed: Array[Rect2] = []
	for labels: Array in units:
		var rect: Rect2 = bounds.call(labels)
		var start := rect.position.y
		var moved := true
		while moved:
			moved = false
			for other: Rect2 in placed:
				if rect.intersects(other):
					rect.position.y = other.position.y - rect.size.y - 2.0
					moved = true
		for label: Label in labels:
			label.position.y += rect.position.y - start
		placed.append(rect)


func _burst(at: Vector3, color: Color) -> void:
	var seconds := controller.tuning.view.burst_seconds
	var drop := SphereMesh.new()
	drop.radius = 0.18
	drop.height = 0.36
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = material
	for index: int in BURST_DROPS:
		var mesh := MeshInstance3D.new()
		mesh.mesh = drop
		mesh.position = at
		_bursts.add_child(mesh)
		var angle := TAU * index / BURST_DROPS
		var reach := at + Vector3(cos(angle), sin(angle), 0.0) * BURST_REACH
		var tween := mesh.create_tween().set_parallel()
		tween.tween_property(mesh, "position", reach, seconds).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh, "scale", Vector3.ONE * 0.05, seconds)
		tween.chain().tween_callback(mesh.queue_free)


func bursts() -> int:
	return _bursts.get_child_count()


func _exit_tree() -> void:
	if controller == null or not is_instance_valid(controller):
		return
	if controller.tick_settled.is_connected(_on_tick_settled):
		controller.tick_settled.disconnect(_on_tick_settled)
	if controller.race_event.is_connected(_on_race_event):
		controller.race_event.disconnect(_on_race_event)
