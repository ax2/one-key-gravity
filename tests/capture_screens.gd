extends SceneTree
## Real-render visual regression gallery. Run without --headless.
var game
var stage: SubViewport
var failed := false

func _initialize() -> void:
	call_deferred("run")

func capture(label: String, target_size: Vector2i, screen: String) -> void:
	stage.size = target_size
	game.state = screen
	game._physics_process(0.0)
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := stage.get_texture().get_image()
	var file := "res://screenshots/" + label + ".png"
	var error := img.save_png(file)
	if error != OK or img.get_size() != target_size: failed = true
	print("SCREENSHOT ",label," size=",img.get_size()," error=",error," scale=",game.scale," offset=",game.position)

func run() -> void:
	stage = SubViewport.new()
	stage.size = Vector2i(1280,720)
	stage.disable_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	game = load("res://main.tscn").instantiate()
	stage.add_child(game)
	game.set_physics_process(false)
	game.test_mode = true
	game.capture_at = -1
	game.test_frames = 0
	game.best = 2840
	game.total_stars = 26
	await capture("01-menu",Vector2i(1280,720),"menu")
	game.test_autoplay = true
	game.start_run(0,424242)
	for i in range(1270): game._physics_process(1.0/120.0)
	await capture("02-gameplay",Vector2i(1280,720),"play")
	await capture("03-pause",Vector2i(1280,720),"pause")
	await capture("04-settings",Vector2i(1280,720),"settings")
	game.state = "play"
	game.end_run()
	await capture("05-result",Vector2i(1280,720),"result")
	await capture("06-portrait-menu",Vector2i(720,1280),"menu")
	await capture("07-portrait-play",Vector2i(720,1280),"play")
	await capture("08-ultrawide-play",Vector2i(1600,720),"play")
	await capture("09-compact-menu",Vector2i(854,480),"menu")
	game.low_fx = true
	await capture("10-low-fx",Vector2i(1280,720),"play")
	game.low_fx = false
	await capture("12-four-three-menu",Vector2i(1024,768),"menu")
	await capture("13-four-three-play",Vector2i(1024,768),"play")
	# Pointer mapping on a letterboxed portrait stage: click transformed menu start.
	await capture("11-portrait-settings",Vector2i(720,1280),"settings")
	game.state = "menu"
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var p: Vector2 = game.position + Vector2(321,442)*game.scale
	game.handle_pointer(p)
	print("PORTRAIT_POINTER state=",game.state)
	if game.state != "play": failed = true
	game.queue_free()
	stage.queue_free()
	await process_frame
	print("VISUAL_SUMMARY failure=",failed)
	quit(1 if failed else 0)
