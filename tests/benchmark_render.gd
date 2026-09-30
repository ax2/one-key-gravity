extends SceneTree
## Render wall-time probe; results describe this machine only.
var game
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1280,720)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.disable_3d = true
	root.add_child(stage)
	game = load("res://main.tscn").instantiate()
	stage.add_child(game)
	game.test_mode = true
	game.test_autoplay = true
	game.start_run(0,424242)
	for i in range(30): await RenderingServer.frame_post_draw
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in range(300):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append(float(now-last)/1000.0)
		last = now
	var total := 0.0
	for dt in times: total += dt
	times.sort()
	print("RENDER_BENCHMARK frames=300 mean_ms=%.3f p95_ms=%.3f mean_fps=%.2f state=%s viewport=1280x720" % [total/times.size(),times[int(times.size()*0.95)],1000.0/(total/times.size()),game.state])
	game.queue_free()
	await process_frame
	await process_frame
	stage.queue_free()
	await process_frame
	quit()
