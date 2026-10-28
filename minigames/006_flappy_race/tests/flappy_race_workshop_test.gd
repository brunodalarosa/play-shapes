extends TestScript
## The Flappy Race workshop runs the real race: the designer and autopilots race, autopilots fly
## through the phone input path, a seed gives the same course as a normal race, quick setups
## and the course strip place racers, live values reach the shared screen at once, and other
## edits wait for a restart.

const SCENE_PATH := "res://minigames/006_flappy_race/workshop/flappy_race_workshop.tscn"


func _run() -> void:
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18120
	host.settings.websocket_port = 18121
	if not check(host.boot(BootRequest.new([&"servers_this_pc"])), "This-PC servers start"):
		return

	change_scene_to_file(SCENE_PATH)
	await scene_changed
	for frame: int in 3:
		await process_frame
	var workshop := current_scene as FlappyRaceWorkshop
	if not check(workshop.controller != null, "The workshop starts a race"):
		return

	_check_racers(workshop)
	await _check_autopilots_fly(workshop)
	_check_same_course(workshop)
	_check_setups(workshop)
	_check_live_and_restart(workshop)
	host.stop()


func _check_racers(workshop: FlappyRaceWorkshop) -> void:
	var racers := workshop.controller.racers()
	check(racers.size() == 4, "The designer and three autopilots race")
	check(racers[0].display_name == "You", "The designer races first")
	check(workshop.presentation.visual_for(racers[3].player_id) != null, "Every racer is drawn")


func _check_autopilots_fly(workshop: FlappyRaceWorkshop) -> void:
	var race := workshop.controller
	var countdown := race.tuning.countdown_seconds
	var give_up := Time.get_ticks_msec() + roundi((countdown + 4.0) * 1000.0)
	while race.settled_tick < 120 and Time.get_ticks_msec() < give_up:
		await process_frame
	var pilot := race.racers()[1]
	check(race.settled_tick >= 120, "The race runs on the clock")
	check(pilot.last_seq > 0, "An autopilot taps through the protocol")
	check(pilot.state.flying and pilot.state.hearts.full == pilot.state.hearts.count, "Flies well")


func _check_same_course(workshop: FlappyRaceWorkshop) -> void:
	var seed_value := workshop.seed_value
	var normal := FlappyRaceCourse.generate(seed_value, workshop.controller.tuning)
	var shown := workshop.controller.course
	check(
		JSON.stringify(normal.to_dictionary()) == JSON.stringify(shown.to_dictionary()),
		"A seed gives the course a normal race would",
	)
	workshop.restart()
	check(workshop.seed_value == seed_value, "Restart keeps the seed")
	workshop._on_new_course()
	check(workshop.seed_value != seed_value, "New course draws a new seed")


func _check_setups(workshop: FlappyRaceWorkshop) -> void:
	workshop.restart("Spread pack")
	var racers := workshop.controller.racers()
	check(racers[0].distance() > racers[3].distance(), "Spread pack puts racers apart")
	workshop.restart("Out of hearts")
	check(workshop.controller.racers()[2].state.hearts.full == 0, "Out of hearts empties rows")
	workshop.restart("Leader near finish")
	var finish := workshop.controller.course.flight.finish_x
	check(workshop.controller.racers()[0].distance() > finish * 0.9, "The leader nears the end")
	workshop.restart("", 30)
	var spot := workshop.controller.course.flight.obstacles[30].respawn_x
	for racer: FlappyRaceRacer in workshop.controller.racers():
		check(is_equal_approx(racer.distance(), spot), "The course strip moves the pack")


func _check_live_and_restart(workshop: FlappyRaceWorkshop) -> void:
	var tuning := workshop.window.tuning
	var share := tuning.tunable("view/leader_screen_share")
	tuning.set_value(share, 0.5)
	check(workshop.presentation.camera.leader_share == 0.5, "A shared-screen value is live")
	var gravity := tuning.tunable("flight/gravity")
	tuning.set_value(gravity, 70.0)
	check(workshop.controller.tuning.flight.gravity == 75.0, "A flight value waits")
	workshop.restart()
	check(workshop.controller.tuning.flight.gravity == 70.0, "Restart applies it")
	tuning.revert()
