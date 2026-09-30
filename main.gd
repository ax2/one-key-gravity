extends Node2D
## GRAVITY / ONE — deterministic, fixed-timestep arcade runner.
const W = 1280.0
const H = 720.0
const TOP = 220.0
const BOTTOM = 550.0
const PX = 264.0
const RADIUS = 15.0
const PALETTE = [Color("4fffd2"), Color("ad99ff"), Color("ffcf6a")]
var font = preload("res://assets/font.otf")
var state = "menu"
var mode = 0
var gravity_dir = 1
var py = BOTTOM - RADIUS
var vy = 0.0
var elapsed = 0.0
var clock_time = 0.0
var distance = 0.0
var speed = 310.0
var score = 0
var stars = 0
var flips = 0
var streak = 0
var best = 0
var total_stars = 0
var runs = 0
var skin = 0
var muted = false
var low_fx = false
var shake = 0.0
var flash = 0.0
var invulnerable = 0.0
var resume_wait = 0.0
var last_flip = -1.0
var seed_value = 0
var next_x = 1500.0
var obstacle_id = 0
var previous_side = 1
var hazards: Array = []
var pickups: Array = []
var particles: Array = []
var trail: Array = []
var buttons: Array = []
var rng = RandomNumberGenerator.new()
var background_rng = RandomNumberGenerator.new()
var points: Array = []
var music: AudioStreamPlayer
var sound: AudioStreamPlayer
var sounds = {}
var status_note = ""
var test_mode = false
var test_autoplay = false
var test_frames = 0
var test_output = ""
var capture_at = -1
var frame_times: Array = []

func _ready():
	font.fallbacks = [preload("res://assets/symbols.ttf")]
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()
	background_rng.seed = 7331
	for i in range(100):
		points.append(Vector3(background_rng.randf_range(0,W),background_rng.randf_range(0,H),background_rng.randf_range(0.3,1.0)))
	sound = AudioStreamPlayer.new()
	add_child(sound)
	music = AudioStreamPlayer.new()
	add_child(music)
	for key in ["flip","star","crash","start"]:
		sounds[key] = load("res://assets/" + key + ".wav")
	music.stream = load("res://assets/music.wav")
	music.volume_db = -19
	music.finished.connect(_on_music_finished)
	if DisplayServer.get_name() != "headless": music.play()
	update_audio()
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			test_mode = true
			test_autoplay = true
			start_run(0,424242)
		if arg.begins_with("--capture="):
			test_output = arg.trim_prefix("--capture=")
			capture_at = 600
		if arg == "--menu-capture": capture_at = 30
		if arg.begins_with("--frames="): test_frames = int(arg.trim_prefix("--frames="))
	get_window().focus_exited.connect(on_focus_lost)

func _exit_tree():
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	if is_instance_valid(sound):
		sound.stop()
		sound.stream = null
	sounds.clear()

func load_progress():
	var cfg = ConfigFile.new()
	if cfg.load("user://progress.cfg") == OK:
		best = int(cfg.get_value("stats","best",0))
		total_stars = int(cfg.get_value("stats","stars",0))
		runs = int(cfg.get_value("stats","runs",0))
		skin = clampi(int(cfg.get_value("settings","skin",0)),0,2)
		muted = bool(cfg.get_value("settings","muted",false))
		low_fx = bool(cfg.get_value("settings","low_fx",false))

func save_progress():
	if test_mode: return
	var cfg = ConfigFile.new()
	cfg.set_value("stats","best",best)
	cfg.set_value("stats","stars",total_stars)
	cfg.set_value("stats","runs",runs)
	cfg.set_value("settings","skin",skin)
	cfg.set_value("settings","muted",muted)
	cfg.set_value("settings","low_fx",low_fx)
	cfg.save("user://progress.cfg")

func _on_music_finished():
	music.play()

func update_audio():
	AudioServer.set_bus_mute(0,muted)

func sfx(which):
	if DisplayServer.get_name() == "headless": return
	if sounds.has(which):
		sound.stream = sounds[which]
		sound.volume_db = -10 if which != "crash" else -15
		sound.play()

func start_run(selected_mode: int, forced_seed: int = -1):
	mode = selected_mode
	state = "play"
	var date = Time.get_date_dict_from_system(true)
	seed_value = int(date.year) * 10000 + int(date.month) * 100 + int(date.day) if mode == 1 else int(Time.get_ticks_usec()) % 999999
	if forced_seed >= 0: seed_value = forced_seed
	rng.seed = seed_value
	py = BOTTOM - RADIUS
	vy = 0
	gravity_dir = 1
	elapsed = 0
	distance = 0
	score = 0
	stars = 0
	flips = 0
	streak = 0
	speed = 310
	next_x = 1500
	obstacle_id = 0
	previous_side = 1
	hazards.clear()
	pickups.clear()
	particles.clear()
	trail.clear()
	last_flip = -1
	invulnerable = 0
	resume_wait = 0.3
	flash = 0
	shake = 0
	sfx("start")
	spawn_until()

func spawn_until():
	while next_x < distance + W + 1000:
		# Every group has ONE blocked rail. There are no forced midair gates.
		# At maximum speed, at least 0.98 s separates groups; full transit <0.5 s.
		var side = 1 if obstacle_id == 0 else (previous_side if rng.randf() < 0.25 else -previous_side)
		var width = rng.randf_range(62,92)
		var height = rng.randf_range(62,90)
		hazards.append({"x":next_x,"side":side,"w":width,"h":height,"passed":false,"id":obstacle_id})
		pickups.append({"x":next_x+width*0.5,"y":TOP+45 if side == 1 else BOTTOM-45,"taken":false,"bonus":false})
		if obstacle_id > 2 and obstacle_id % 3 == 0:
			# Optional mid-channel bonus, well after the obstacle, never required.
			pickups.append({"x":next_x+230,"y":385.0,"taken":false,"bonus":true})
		next_x += rng.randf_range(540,660) if elapsed < 12 else rng.randf_range(470,590)
		previous_side = side
		obstacle_id += 1

func flip():
	if state != "play" or resume_wait > 0: return
	if elapsed-last_flip < 0.085: return
	gravity_dir *= -1
	vy = 240 * gravity_dir
	last_flip = elapsed
	flips += 1
	flash = 0.10
	burst(Vector2(PX,py),PALETTE[skin],12)
	sfx("flip")

func end_run(won = false):
	if state != "play": return
	state = "result"
	score = int(distance/12)+stars*25
	best = maxi(score,best)
	total_stars += stars
	runs += 1
	status_note = "今日航线完成" if won else "再试一次，就差一点"
	shake = 8
	burst(Vector2(PX,py),Color("ff6386"),32)
	sfx("start" if won else "crash")
	save_progress()
	queue_redraw()

func pause_game():
	if state == "play": state = "pause"

func on_focus_lost():
	pause_game()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED: pause_game()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == "play": pause_game()
		elif state == "pause": resume_game()
		else: state = "menu"

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if state == "play": pause_game()
			elif state == "pause": resume_game()
			elif state != "menu": state = "menu"
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if state == "play": flip()
			elif state == "menu": start_run(0)
			elif state == "result": start_run(mode)
		elif event.keycode == KEY_R and (state == "result" or state == "pause"): start_run(mode)
		elif event.keycode == KEY_M:
			muted = not muted
			update_audio()
			save_progress()
	if event is InputEventScreenTouch and event.pressed and event.index == 0:
		handle_pointer(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_pointer(event.position)

func handle_pointer(screen_pos):
	var p = (screen_pos-position)/scale
	for b in buttons:
		if b.rect.has_point(p):
			act(b.action)
			return
	if state == "play": flip()

func resume_game():
	state = "play"
	resume_wait = 1.0

func act(action):
	match action:
		"start": start_run(0)
		"daily": start_run(1)
		"practice": start_run(2)
		"retry": start_run(mode)
		"menu": state = "menu"
		"pause": pause_game()
		"resume": resume_game()
		"settings": state = "settings"
		"mute":
			muted = not muted
			update_audio()
			save_progress()
		"fx":
			low_fx = not low_fx
			save_progress()
		"skin":
			var count = 1 + int(total_stars >= 20) + int(total_stars >= 60)
			skin = (skin+1)%count
			save_progress()

func burst(p,col,count):
	if low_fx: count = mini(count,5)
	for i in range(count):
		var a = float(i)/count*TAU+clock_time
		particles.append({"p":p,"v":Vector2(cos(a),sin(a))*randf_range(45,220),"life":0.6,"col":col})

func _physics_process(dt):
	clock_time += dt
	var viewport = get_viewport_rect().size
	var factor = minf(viewport.x/W,viewport.y/H)
	scale = Vector2.ONE*factor
	position = (viewport-Vector2(W,H)*factor)*0.5
	shake = move_toward(shake,0,dt*25)
	flash = move_toward(flash,0,dt)
	for p in particles:
		p.p += p.v*dt
		p.v *= 0.97
		p.life -= dt
	particles = particles.filter(func(p): return p.life > 0)
	if state == "play":
		if resume_wait > 0:
			resume_wait -= dt
		else:
			elapsed += dt
			speed = minf(440,310+elapsed*1.65) if mode != 2 else 285.0
			distance += speed*dt
			if test_autoplay: autopilot()
			vy += gravity_dir*2100*dt
			py = clampf(py+vy*dt,TOP+RADIUS,BOTTOM-RADIUS)
			if py == TOP+RADIUS or py == BOTTOM-RADIUS: vy = 0
			invulnerable = maxf(0,invulnerable-dt)
			spawn_until()
			for h in hazards:
				var x = h.x-distance
				var rect = Rect2(x, BOTTOM-h.h if h.side == 1 else TOP,h.w,h.h)
				var nearest = Vector2(clampf(PX,rect.position.x,rect.end.x),clampf(py,rect.position.y,rect.end.y))
				# Inset collision radius means the visible halo never kills the player.
				if Vector2(PX,py).distance_squared_to(nearest) < pow(RADIUS-3,2) and invulnerable <= 0:
					if mode == 2:
						invulnerable = 1.8
						burst(Vector2(PX,py),Color("ff6386"),15)
					else:
						end_run()
						return
				if x+h.w < PX-RADIUS and not h.passed:
					h.passed = true
					streak += 1
					burst(Vector2(PX,py),PALETTE[skin],4)
			for star in pickups:
				if not star.taken and Vector2(star.x-distance,star.y).distance_to(Vector2(PX,py)) < 36:
					star.taken = true
					stars += 3 if star.bonus else 1
					burst(Vector2(star.x-distance,star.y),Color("ffcf6a"),14)
					sfx("star")
			score = int(distance/12)+stars*25
			hazards = hazards.filter(func(h): return h.x-distance > -200)
			pickups = pickups.filter(func(s): return s.x-distance > -100)
			if mode == 1 and elapsed >= 60: end_run(true)
		if Engine.get_physics_frames()%3 == 0:
			trail.push_front(Vector2(PX,py))
			if trail.size() > (10 if low_fx else 24): trail.pop_back()
		for i in range(trail.size()): trail[i].x -= speed*dt
	if capture_at >= 0 and Engine.get_physics_frames() == capture_at:
		capture.call_deferred()
	if test_frames > 0 and Engine.get_physics_frames() >= test_frames:
		print("BENCHMARK state=%s score=%d stars=%d elapsed=%.2f seed=%d frames=%d" % [state,score,stars,elapsed,seed_value,Engine.get_physics_frames()])
		get_tree().quit()
	queue_redraw()

func autopilot():
	for h in hazards:
		var dx = h.x-distance-PX
		if dx > -h.w-RADIUS and dx < 240:
			if gravity_dir == h.side: flip()
			return

func capture():
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	if img != null:
		var error = img.save_png(test_output)
		print("CAPTURE ",test_output," ",error)

func txt(text_value,at,size=20,col=Color("dce8ff")):
	draw_string(font,at,str(text_value),HORIZONTAL_ALIGNMENT_LEFT,-1,size,col)

func panel(rect,col,border=Color.TRANSPARENT,radius=18):
	var style = StyleBoxFlat.new()
	style.bg_color = col
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border
	style.set_border_width_all(1)
	draw_style_box(style,rect)

func button(label,rect,action,primary=false):
	buttons.append({"rect":rect.grow(8),"action":action})
	panel(rect,Color("49f5cf") if primary else Color("131f39"),Color("49f5cf") if primary else Color("2d3f5c"),13)
	var size = 23 if primary else 19
	var width = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	txt(label,Vector2(rect.get_center().x-width/2,rect.get_center().y+size*0.36),size,Color("061f27") if primary else Color("dfebff"))

func _draw():
	buttons.clear()
	draw_rect(Rect2(-500,-500,2280,1720),Color("070d20"))
	draw_background()
	if state == "menu": draw_menu()
	elif state == "settings": draw_settings()
	else:
		draw_arena()
		draw_hud()
		if state == "pause": draw_pause()
		if state == "result": draw_result()
	for p in particles:
		var col = p.col
		col.a = p.life/0.6
		draw_circle(p.p,2.5,col)
	# Keep exactly the same preview and interactive area on every aspect ratio.
	var matte = Color("070d20")
	draw_rect(Rect2(-10000,-10000,10000,20000),matte)
	draw_rect(Rect2(W,-10000,10000,20000),matte)
	draw_rect(Rect2(0,-10000,W,10000),matte)
	draw_rect(Rect2(0,H,W,10000),matte)

func draw_background():
	for pt in points:
		var x = fposmod(pt.x-distance*pt.z*0.10-clock_time*pt.z*2,W)
		draw_circle(Vector2(x,pt.y),pt.z*1.6,Color(0.5,0.7,1,pt.z*0.5))
	if not low_fx:
		for i in range(8):
			var col = Color(0.13,0.27,0.5,0.016)
			draw_circle(Vector2(980,260),220+i*25,col)
	for i in range(12):
		var x = fposmod(i*140-distance*0.18,1680)-200
		draw_line(Vector2(x,550),Vector2(x-170,720),Color("13203a"),1)
	for i in range(4): draw_line(Vector2(0,585+i*i*10),Vector2(W,585+i*i*10),Color("12203a"),1)

func draw_logo(at,compact=false):
	txt("G R A V I T Y  /  O N E",at,15,Color("55e8d1"))
	if not compact:
		txt("一键引力",at+Vector2(-3,73),64,Color("f0f5ff"))
		txt("翻转世界。保持前进。",at+Vector2(0,117),21,Color("8da1c2"))

func draw_menu():
	draw_logo(Vector2(86,130))
	panel(Rect2(86,299,470,85),Color("101c32"),Color("233550"))
	txt("个人最佳",Vector2(109,329),16,Color("8297b9"))
	txt(str(best).pad_zeros(5),Vector2(109,365),30)
	txt("累计星尘",Vector2(340,329),16,Color("8297b9"))
	txt("✦  "+str(total_stars),Vector2(340,365),30,Color("ffcf6a"))
	button("开始航行  →",Rect2(86,410,470,64),"start",true)
	button("每日航线 · 60 秒",Rect2(86,491,227,53),"daily")
	button("自由练习",Rect2(329,491,227,53),"practice")
	button("设置 / 外观",Rect2(86,562,227,48),"settings")
	txt("点击屏幕 / 空格   ·   只有一个动作",Vector2(86,657),17,Color("778cab"))
	# A large orbital exhibit doubles as a visual explanation of the mechanic.
	var center = Vector2(908,385)
	for i in range(3): draw_arc(center,137+i*39,0,TAU,96,Color(0.2,0.44,0.6,0.13),1,true)
	draw_line(Vector2(682,TOP),Vector2(1134,TOP),Color("355f73"),3)
	draw_line(Vector2(682,BOTTOM),Vector2(1134,BOTTOM),Color("355f73"),3)
	var demo_y = 385+130*sin(clock_time*1.1)
	for i in range(18):
		var yy = 385+130*sin((clock_time-i*0.023)*1.1)
		draw_circle(Vector2(908-i*5,yy),12-float(i)*0.5,Color(0.2,1,0.82,(1-i/18.0)*0.35))
	draw_ball(Vector2(908,demo_y),1.45)
	draw_hazard(1058,1,66,67)
	draw_hazard(712,-1,66,67)
	draw_star(Vector2(1055,236),13,Color("ffcf6a"))
	txt("01  /  FLIP THE FLOW",Vector2(780,602),16,Color("6b809f"))

func draw_ball(p,mult=1.0):
	var col = PALETTE[skin]
	if invulnerable > 0 and int(clock_time*12)%2 == 0: col.a = 0.3
	if not low_fx:
		for i in range(3): draw_circle(p,(RADIUS+7+i*5)*mult,Color(col,0.04))
	draw_arc(p,22*mult,clock_time*2,clock_time*2+TAU*0.72,32,Color(col,0.6),1.5,true)
	draw_circle(p,RADIUS*mult,col)
	draw_circle(p+Vector2(-3,-4)*mult,6*mult,Color("e8fff8"))

func draw_hazard(x,side,width,height):
	var base = BOTTOM if side == 1 else TOP
	var rect = Rect2(x,base-height if side == 1 else base,width,height)
	panel(rect,Color("3d1d39"),Color("fb6a8c"),4)
	for i in range(3):
		var xx = x+10+i*(width-20)/3
		draw_line(Vector2(xx,rect.position.y+7),Vector2(xx+15,rect.end.y-7),Color("aa426b"),3)
	draw_line(Vector2(x,base-height*side),Vector2(x+width,base-height*side),Color("ffc0c9"),3)

func draw_star(p,r,col):
	var verts = PackedVector2Array()
	for i in range(8):
		var a = i*PI/4-clock_time*0.6
		verts.append(p+Vector2(cos(a),sin(a))*(r if i%2 == 0 else r*0.35))
	if not low_fx: draw_circle(p,r*1.8,Color(col,0.06))
	draw_colored_polygon(verts,col)

func draw_arena():
	panel(Rect2(54,TOP,W-108,BOTTOM-TOP),Color(0.035,0.065,0.125,0.70),Color("152c47"),3)
	for y in [TOP,BOTTOM]:
		draw_line(Vector2(54,y),Vector2(W-54,y),Color("3a7793"),2)
		draw_line(Vector2(PX-50,y),Vector2(PX+75,y),Color("5af9d6") if (y == BOTTOM and gravity_dir == 1) or (y == TOP and gravity_dir == -1) else Color("36516a"),3)
		for i in range(20):
			var x = fposmod(i*76-distance,1520)-120
			draw_line(Vector2(x,y+(-10 if y == TOP else 10)),Vector2(x+18,y+(-10 if y == TOP else 10)),Color("25516b"),2)
	for h in hazards:
		var x = h.x-distance
		if x > -100 and x < W+100: draw_hazard(x,h.side,h.w,h.h)
	for star in pickups:
		if not star.taken:
			var p = Vector2(star.x-distance,star.y)
			if p.x > -50 and p.x < W+50:
				draw_star(p,12 if not star.bonus else 16,Color("ffcf6a"))
				if star.bonus: txt("×3",p+Vector2(-10,33),13,Color("c49d65"))
	for i in range(trail.size()):
		var alpha = (1-float(i)/trail.size())*0.30
		draw_circle(trail[i],maxf(2,RADIUS-i*0.48),Color(PALETTE[skin],alpha))
	if state != "result": draw_ball(Vector2(PX,py))
	if elapsed < 4 and state == "play":
		txt("点击任意空白处 / 空格",Vector2(482,349),25,Color("c3d8ec"))
		txt("翻转引力，避开珊瑚红障碍",Vector2(476,390),19,Color("829aba"))
	if resume_wait > 0.3 and state == "play":
		panel(Rect2(524,319,232,102),Color("101d36"),Color("50e4cb"))
		txt("准备继续",Vector2(585,360),23)
		txt("1",Vector2(632,396),26,Color("50e4cb"))

func draw_hud():
	draw_logo(Vector2(64,60),true)
	txt(["无尽航行","每日航线","自由练习"][mode]+"   /   SECTOR "+str(1+int(elapsed/15)).pad_zeros(2),Vector2(64,107),22)
	txt(str(score).pad_zeros(5),Vector2(545,102),47,Color("f2f7ff"))
	txt("✦ "+str(stars),Vector2(803,93),28,Color("ffcf6a"))
	if state == "play": button("Ⅱ  暂停",Rect2(1055,53,159,52),"pause")
	var progress = fmod(elapsed,15)/15.0
	if mode == 1: progress = elapsed/60
	panel(Rect2(64,149,1150,4),Color("1d304a"),Color.TRANSPARENT,2)
	if progress > 0: panel(Rect2(64,149,1150*progress,4),PALETTE[skin],Color.TRANSPARENT,2)
	txt("↑ ↓  引力"+ ("向下" if gravity_dir == 1 else "向上"),Vector2(65,625),18,Color("7999b0"))
	txt("连续通过  "+str(streak),Vector2(548,625),19,Color("8dabc2"))
	txt(("剩余 %02d 秒" % maxi(0,60-int(elapsed))) if mode == 1 else "速度  %03d" % int(speed),Vector2(1051,625),18,Color("7999b0"))
	txt("P / ESC 暂停   ·   M 静音" if mode != 2 else "练习模式 · 碰撞不会结束 · 速度固定",Vector2(65,672),14,Color("465f7e"))

func overlay():
	draw_rect(Rect2(0,0,W,H),Color(0.015,0.025,0.06,0.88))
	panel(Rect2(350,135,580,455),Color("0d182e"),Color("304864"),23)

func draw_pause():
	overlay()
	txt("暂时停靠",Vector2(511,216),38)
	txt("进度已冻结，继续时有 1 秒缓冲",Vector2(476,260),19,Color("8da4c1"))
	button("继续航行",Rect2(427,300,426,63),"resume",true)
	button("重新开始",Rect2(427,383,426,55),"retry")
	button("返回主菜单",Rect2(427,459,426,55),"menu")

func draw_result():
	overlay()
	txt(status_note,Vector2(425,199),29)
	txt(str(score).pad_zeros(5),Vector2(512,278),64,Color("e8fff8"))
	txt("本次星尘  "+str(stars)+"     连续通过  "+str(streak),Vector2(477,325),20,Color("9bb2cb"))
	txt("最佳  "+str(best)+"   /   航线种子  "+str(seed_value),Vector2(451,363),15,Color("6c87a7"))
	button("再来一次  ↻",Rect2(427,397,426,62),"retry",true)
	button("返回主菜单",Rect2(427,480,426,52),"menu")
	txt("空格快速重开",Vector2(581,564),14,Color("607a98"))

func draw_settings():
	draw_logo(Vector2(85,100),true)
	txt("让航行更合你的节奏",Vector2(85,164),37)
	panel(Rect2(85,205,1100,365),Color("0e1b31"),Color("283c57"))
	txt("声音",Vector2(121,260),24)
	txt("原创电子氛围 + 翻转、星尘与碰撞音效",Vector2(121,295),17,Color("809ab9"))
	button("已静音" if muted else "已开启",Rect2(954,239,186,52),"mute")
	txt("视觉效果",Vector2(121,365),24)
	txt("低特效减少粒子与光晕，保持障碍清晰",Vector2(121,400),17,Color("809ab9"))
	button("低特效" if low_fx else "完整特效",Rect2(954,344,186,52),"fx")
	txt("引力核心",Vector2(121,470),24)
	txt("星尘解锁：薄荷 0  /  紫晶 20  /  琥珀 60",Vector2(121,505),17,Color("809ab9"))
	button(["薄荷","紫晶","琥珀"][skin]+"  →",Rect2(954,449,186,52),"skin")
	button("返回主菜单",Rect2(85,605,270,57),"menu",true)
	txt("仅本机保存 · 无广告 · 无账号 · 每日航线按 UTC 日期更新",Vector2(440,643),16,Color("6b84a1"))
