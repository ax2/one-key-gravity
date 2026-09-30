extends SceneTree
## Deterministic regression suite. Does not save player progress.
var game
var failures: Array[String] = []
var checks := 0
const STEP = 1.0 / 120.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures.append(label)
		printerr("FAIL: ", label)

func tick(count: int = 1) -> void:
	for i in range(count): game._physics_process(STEP)

func key(code: int, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	game._unhandled_input(event)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.test_mode = true
	game.test_autoplay = false
	game.test_frames = 0
	game.capture_at = -1
	check(game.state == "menu", "Boot opens menu")
	check(game.sounds.size() == 4 and game.music.stream != null, "Four sound effects and music load")
	key(KEY_SPACE)
	check(game.state == "play" and game.mode == 0, "Space starts endless run")
	check(game.gravity_dir == 1 and game.score == 0 and game.flips == 0, "Run resets initial state")
	tick(40)
	key(KEY_SPACE)
	check(game.gravity_dir == -1 and game.flips == 1, "Space flips gravity")
	key(KEY_SPACE, true)
	check(game.flips == 1, "Key repeat does not retrigger")
	key(KEY_SPACE)
	check(game.flips == 1, "Rapid repeat debounced")
	tick(12)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(800, 385)
	game.buttons.clear()
	game._unhandled_input(mouse)
	check(game.gravity_dir == 1 and game.flips == 2, "Mouse press flips gravity")
	tick(12)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(800, 385)
	game._unhandled_input(touch)
	check(game.gravity_dir == -1 and game.flips == 3, "Touch press flips gravity")
	tick(12)
	touch.index = 1
	game._unhandled_input(touch)
	check(game.flips == 3, "Secondary touch ignored")
	key(KEY_P)
	var paused_distance: float = game.distance
	tick(120)
	check(game.state == "pause" and game.distance == paused_distance, "Pause freezes gameplay")
	key(KEY_ESCAPE)
	check(game.state == "play" and game.resume_wait == 1.0, "Escape resumes with one-second buffer")
	key(KEY_SPACE)
	check(game.flips == 3, "Resume buffer blocks accidental flip")
	tick(60)
	check(game.distance == paused_distance, "Resume buffer freezes travel")
	tick(70)
	check(game.distance > paused_distance, "Travel resumes after buffer")
	game.on_focus_lost()
	check(game.state == "pause", "Losing focus pauses")
	key(KEY_R)
	check(game.state == "play" and game.score == 0 and game.stars == 0 and game.flips == 0, "R restarts without stale run state")
	game.resume_wait = 0
	game.distance = 11.9
	game.best = 0
	game.hazards = [{"x":game.PX + game.distance,"side":1,"w":80.0,"h":80.0,"passed":false,"id":0}]
	game.pickups.clear()
	tick()
	check(game.state == "result", "Collision ends normal run")
	check(game.best == game.score and game.score > 0, "Collision final score matches newly saved best")
	key(KEY_ENTER)
	check(game.state == "play", "Enter restarts from results")
	var restarts_ok := true
	for i in range(10):
		game.pause_game()
		key(KEY_R)
		if game.state != "play" or game.score != 0 or game.hazards.is_empty(): restarts_ok = false
	check(restarts_ok, "Ten consecutive pause/restart cycles remain clean")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.state == "pause", "Background notification pauses run")
	game.resume_game()
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.state == "pause", "Android back notification pauses run")
	game.start_run(2, 123)
	game.resume_wait = 0
	game.hazards = [{"x":game.PX,"side":1,"w":80.0,"h":80.0,"passed":false,"id":0}]
	game.pickups.clear()
	tick()
	check(game.state == "play" and game.invulnerable > 0 and game.speed == 285, "Practice collision gives grace period at fixed speed")
	game.start_run(0, 100)
	game.resume_wait = 0
	game.hazards.clear()
	game.next_x = 1000000
	game.pickups = [{"x":game.PX + 3,"y":game.py,"taken":false,"bonus":false}]
	tick()
	check(game.stars == 1 and game.score >= 25, "Star awards points")
	game.pickups = [{"x":game.PX + game.distance + 3,"y":game.py,"taken":false,"bonus":true}]
	tick()
	check(game.stars == 4, "Bonus pickup awards three stars")
	game.start_run(1)
	var daily_seed: int = game.seed_value
	game.start_run(1)
	check(game.seed_value == daily_seed, "Daily seed repeats for same UTC date")
	game.start_run(0, 424242)
	var layout_a: String = str(game.hazards)
	game.start_run(0, 424242)
	check(str(game.hazards) == layout_a, "Forced seed generates identical layout")
	game.test_autoplay = true
	var survived := true
	var seeds := [0, 1, 42, 123, 424242, 999999]
	for seed_num in seeds:
		game.start_run(0, seed_num)
		tick(14440)
		if game.state != "play": survived = false
		print("SURVIVAL seed=", seed_num, " seconds=", snapped(game.elapsed,0.01), " score=",game.score," speed=",game.speed)
	check(survived, "Autopilot survives six seeds for 120 seconds including maximum speed")
	check(game.speed == 440, "Endless speed capped at 440")
	game.start_run(1, 424242)
	tick(7300)
	check(game.state == "result" and game.status_note == "今日航线完成" and game.elapsed >= 60, "Daily run completes after 60 seconds")
	game.act("menu")
	game.act("settings")
	check(game.state == "settings", "Settings navigation")
	var before_mute: bool = game.muted
	game.act("mute")
	check(game.muted != before_mute and AudioServer.is_bus_mute(0) == game.muted, "Mute setting updates audio bus")
	var before_fx: bool = game.low_fx
	game.act("fx")
	check(game.low_fx != before_fx, "Low-FX setting toggles")
	game.total_stars = 0
	game.skin = 0
	game.act("skin")
	check(game.skin == 0, "Locked skins cannot be selected")
	game.total_stars = 60
	game.act("skin")
	game.act("skin")
	check(game.skin == 2, "All skins unlock at 60 stars")
	print("TEST_SUMMARY checks=", checks, " failures=", failures.size())
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
