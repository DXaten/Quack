extends "res://scripts/ink.gd"
## Чисто визуальный слой: вода, механизмы и персонажи рисуются в координатах уровня.

const L = preload("res://scripts/level.gd")
const S = preload("res://scripts/station.gd")
const DECK := Color("#758e89")
const SEAM := Color("#607a77")
const CONCRETE_INK := Color("#304f50")
const EDGE := Color("#253f42")
@onready var game: S = get_parent()

func _draw() -> void:
	box(32, 99, 1056, 427, Color("#091718"))
	box(32, 96, 1056, 426, Color("#3d5858"))
	box(36, 100, 1048, 418, DARK)
	box(42, 106, 1036, 405, DECK)
	floor_tiles()
	channel()
	shoreline(L.WATER_LEFT, -1)
	shoreline(L.WATER_RIGHT, 1)
	bridge()
	if not game.lesson:
		return_facilities()
	if game.phase in [S.Phase.RECORD,S.Phase.ARMED,S.Phase.REPLAY]:
		route()
	button()
	beacon(game.passenger)
	var show_roles := game.phase in [S.Phase.ARMED, S.Phase.REPLAY]
	if show_roles:
		flight_guide()
	if game.fell:
		splash()
	else:
		draw_duck()
	draw_drone()
	if game.showing_example and game.phase in [S.Phase.RECORD, S.Phase.REPLAY]:
		var t := float(game.frame) / Engine.physics_ticks_per_second
		if t >= S.PAUSE_AT and t < S.WALK_AGAIN_AT:
			var elapsed := (t-S.PAUSE_AT)/(S.WALK_AGAIN_AT-S.PAUSE_AT)
			ring(game.duck,32,DARK,4)
			draw_arc(game.duck,32,-PI/2,-PI/2+TAU*elapsed,48,AMBER,3,true)
			var p := game.duck + Vector2(0,39)
			circle(p.x,p.y,10,DARK)
			box(p.x-4,p.y-4,3,8,AMBER)
			box(p.x+1,p.y-4,3,8,AMBER)
	for x in [37,1083]:
		for y in [102,516]:
			circle(x, y, 2, MUTED)

func return_facilities() -> void:
	var ramp := L.return_ramp(game.left,game.right)
	if game.return_open:
		draw_rect(ramp,EDGE)
		draw_rect(ramp.grow(-4),Color("#83978a"))
		for x in range(int(ramp.position.x)+10,int(ramp.end.x)-4,14):
			line(x,ramp.position.y+5,x,ramp.end.y-5,Color("#5c7672"))
		var y := ramp.get_center().y
		for x in range(int(game.left)+23,int(game.right),39):
			line(x+6,y-5,x,y,AQUA,3)
			line(x,y,x+6,y+5,AQUA,3)
	# До сцепки видны только сложенные секции у берегов и вода между ними.
	for bank: float in [game.left,game.right]:
		if not game.return_open:
			box(bank-14,ramp.position.y,28,ramp.size.y,EDGE)
			for offset in [-8,-3,2,7]:
				box(bank+offset,ramp.position.y+4,3,ramp.size.y-8,Color("#83978a"))
			box(bank-4,ramp.position.y,8,ramp.size.y,DARK)
			for y in range(int(ramp.position.y)+7,int(ramp.end.y)-4,12):
				line(bank-4,y-3,bank+4,y+2,AMBER,3)
		var light := Vector2(bank,ramp.position.y-3)
		draw_circle(light,5,EDGE)
		draw_circle(light,3,AQUA if game.return_open else RED)
	var p := L.EVAC_PAD
	circle(p.x,p.y,45,Color("#496961"))
	ring(p,44,AQUA,3)
	ring(p,34,Color("#8cbbae"))
	line(p.x-11,p.y,p.x+11,p.y,AQUA,4)
	line(p.x,p.y-11,p.x,p.y+11,AQUA,4)
	if game.attached:
		draw_line(game.duck,game.passenger,DARK,5,true)
		draw_dashed_line(game.duck,game.passenger,AMBER,2,5,true,true)

func flight_guide() -> void:
	# Бирюзовые стрелки связывают дрон с кнопкой. Жёлтые точки на полу —
	# фактический маршрут Кряка, который будет воспроизведён независимо.
	var offset := L.SWITCH - game.drone
	var toward := offset.normalized()
	var across := toward.orthogonal()
	if not game.switch_held:
		var distance := 40.0
		if game.phase == S.Phase.REPLAY:
			distance += fmod(game.clock*20.0,29.0)
		while distance < offset.length()-33.0:
			var tip := game.drone + toward*distance
			var base := tip-toward*7.0
			draw_polyline(PackedVector2Array([base+across*4.0,tip,base-across*4.0]),DARK,4,true)
			draw_polyline(PackedVector2Array([base+across*4.0,tip,base-across*4.0]),AQUA,2,true)
			distance += 29.0
	ring(L.SWITCH,L.SWITCH_RADIUS+3.0+sin(game.clock*3.0)*1.5,AQUA,2)

func floor_tiles(first_station := true) -> void:
	for x in range(49,1078,78):
		line(x,106,x,511, SEAM)
	for y in range(119,511,62):
		line(42,y,1078,y, SEAM)
		for x in range(53,1070,78):
			circle(x, y+5, 1.2, SEAM)
	# Неровности поверхности детерминированы, поэтому бетон не мерцает.
	for i in 245:
		var x := 47 + (i * 271) % 1023
		var y := 111 + (i * 139) % 395
		line(x,y,x+2+i%6,y, Color("#829b94"))
	# Магистральные трубы и вентиляционные решётки вдоль края площадки.
	for y in [462,480]:
		box(42,y,191,12, Color("#4b6967"))
		box(42,y-2,182,8, Color("#a1b1a2"))
		box(42,y-1,182,2, Color("#c2caba"))
		for x in [60,117,180,216]:
			box(x,y-4,6,13, Color("#526d68"))
			box(x+1,y-3,2,10, Color("#bac6af"))
	for x in [963, 1004]:
		box(x,124,32,56, EDGE)
		box(x+2,126,28,52, Color("#516d6b"))
		for y in range(130,175,6):
			box(x+5,y,22,3, EDGE)
	for x in range(735,1056,13):
		line(x,470,x+6,462, SEAM,2)
	line(728,475,1055,475,SEAM)
	# Светлая пунктирная ось соединяет старт, настил и спасательный пост.
	if first_station:
		for x in range(77,1000,24):
			box(x,L.BRIDGE_Y-1,12,2,Color("#acb9a7"))

func channel() -> void:
	var left := L.WATER_LEFT
	var right := L.WATER_RIGHT
	box(left,106,right-left,405,Color("#173f4b"))
	box(left,106,16,405, Color("#133640"))
	box(right-9,106,9,405, Color("#20505a"))
	for i in 69:
		var x := left + 17.0 + fmod(i*59.0, right-left-54)
		var y := 112.0 + fmod(i*81.0 + game.clock*(5+i%4), 391.0)
		var width := 6.0 + i%16
		var c := Color("#2a5660") if i%3 else Color("#36646a")
		draw_polyline(PackedVector2Array([Vector2(x,y),Vector2(x+width*0.4,y+2),Vector2(x+width,y)]),c,1.5,true)
	for y in [162, 439]:
		for j in 2:
			var cy: int = y + j*9
			line(555,cy,569,cy+7,Color("#39636a"),2)
			line(569,cy+7,583,cy,Color("#39636a"),2)

func shoreline(x: float, side: float) -> void:
	for span in [Vector2(106, L.BRIDGE_Y-L.BRIDGE_HALF), Vector2(L.BRIDGE_Y+L.BRIDGE_HALF,511)]:
		var top: float = span.x
		var bottom: float = span.y
		line(x,top,x,bottom,EDGE,6)
		line(x + side*9,top,x + side*9,bottom, Color("#bdba91"),8)
		for y in range(int(top)+8,int(bottom)-5,16):
			line(x+side*6,y-5,x+side*12,y+2, Color("#5c6661"),3)
		for y in range(int(top)+18,int(bottom)-7,47):
			circle(x+side*20,y,2,CONCRETE_INK)

func bridge() -> void:
	var mid := (L.WATER_RIGHT+L.WATER_LEFT)*0.5
	var top := L.BRIDGE_Y-L.BRIDGE_HALF
	var bottom := L.BRIDGE_Y+L.BRIDGE_HALF
	for side in [-1,1]:
		var shore: float = L.WATER_LEFT if side == -1 else L.WATER_RIGHT
		var tip: float = lerpf(shore,mid,0.09+0.91*game.bridge_open_amount)
		var x0 := minf(shore,tip)
		var width := absf(shore-tip)
		box(x0,top+6,width,bottom-top+6,Color("#102c33"))
		box(x0,top,width,bottom-top,Color("#50605b"))
		for i in 8:
			var slat := width/8.0
			box(x0+i*slat+0.5,top+3,maxf(1,slat-1.5),bottom-top-6, Color("#bdac78") if i%2 else Color("#c5b481"))
		for y in [top+2,bottom-3]:
			line(x0,y,x0+width,y,Color("#e5cb84"),3)
		for y in [top-8,bottom+6]:
			box(shore-8,y-4,16,10,EDGE)
			circle(shore,y+1,3, AQUA if game.bridge_down() else RED)

func route() -> void:
	# Редкая штриховая линия показывает настоящий записанный маршрут, включая повороты.
	var distance := 0.0
	for i in range(1,game.tape.size()):
		var pos := game.tape[i]
		distance += pos.distance_to(game.tape[i-1])
		if distance >= 13.0:
			draw_circle(pos,2.2,Color("#fbe49d"),true,-1,true)
			distance = 0

func button() -> void:
	var p := L.SWITCH
	draw_set_transform(p)
	var lit := AQUA if game.switch_held else AMBER
	var casing := PackedVector2Array([Vector2(-22,-16),Vector2(-15,-23),Vector2(16,-23),Vector2(23,-16),Vector2(23,16),Vector2(16,23),Vector2(-16,23),Vector2(-23,16)])
	draw_colored_polygon(casing, EDGE)
	ring(Vector2.ZERO,19,Color("#8ba19a"),2)
	circle(0,0,15,Color("#274d50"))
	ring(Vector2.ZERO,13,lit,2)
	line(-5,0,5,0,lit,2)
	line(0,-5,0,5,lit,2)
	draw_set_transform(Vector2.ZERO)

func beacon(p := L.BEACON) -> void:
	draw_set_transform(p)
	var lit := AQUA if game.phase == S.Phase.WON else AMBER
	ring(Vector2.ZERO,29,Color("#a9bdab"),2)
	ring(Vector2.ZERO,35,Color("#93a99a"))
	circle(2,8,18, Color("#526e6b"))
	box(-15,6,9,12, EDGE)
	box(6,6,9,12, EDGE)
	box(-18,-12,36,26, EDGE)
	box(-15,-11,30,21, Color("#dfdfc8"))
	box(-11,-8,22,10, DARK)
	circle(-6,-3,2,lit)
	circle(6,-3,2,lit)
	line(-6,7,6,7,SEAM,2)
	line(0,-12,0,-24, EDGE,3)
	circle(0,-25,5,Color("#55665b"))
	circle(0,-25,3,lit)
	var pulse := fmod(game.clock*0.55,1)
	draw_arc(Vector2(0,-25),8+pulse*11,PI*1.12,PI*1.88,18,Color(lit,1-pulse),2,true)
	draw_set_transform(Vector2.ZERO)

func draw_duck(jump_height := 0.0) -> void:
	var p := game.duck
	draw_set_transform(p+Vector2(1,10),0,Vector2(1,0.38))
	circle(0,0,25,Color("#233e409a"))
	draw_set_transform(p-Vector2(0,jump_height),0,Vector2(game.facing,1))
	var stride := sin(game.step_time)*2
	# Широкие лапы, корпус с крылышком и тёмный визор робоутки.
	box(-11,8+stride,9,8,Color("#df813d"))
	box(5,8-stride,10,8,Color("#ed9548"))
	poly([Vector2(-25,-7),Vector2(-8,-2),Vector2(-13,8),Vector2(-22,3)],AMBER)
	circle(-4,0,16,Color("#d29135"))
	circle(-4,-2,15,AMBER)
	circle(7,-13,13,Color("#e5a23d"))
	circle(7,-15,12,Color("#ffe484"))
	box(3,-20,16,9,DARK)
	circle(13,-16,2.6,AQUA)
	poly([Vector2(17,-11),Vector2(29,-8),Vector2(26,-5),Vector2(16,-5)],Color("#ff9c45"))
	poly([Vector2(-17,-4),Vector2(-4,-1),Vector2(1,-4),Vector2(-4,5),Vector2(-14,6)],Color("#dca23d"))
	circle(-11,1,1.6,Color("#ffe898"))
	draw_set_transform(Vector2.ZERO)

func draw_drone() -> void:
	var p := game.drone
	var hover := sin(game.clock*3)*1.5
	draw_set_transform(p+Vector2(0,8),0,Vector2(1,0.45))
	circle(0,0,23, Color("#284846aa"))
	draw_set_transform(p+Vector2(0,hover-3))
	for x in [-18,18]:
		box(x-4,-5,8,10,EDGE)
		box(x-3,-3,6,2,AQUA)
	circle(0,0,17,EDGE)
	ring(Vector2.ZERO,14,AQUA,3)
	circle(0,-1,10,Color("#42666a"))
	circle(0,-2,6,DARK)
	circle(-1,-3,3,Color("#bcffee"))
	for i in 3:
		var angle := game.clock*1.3 + i*TAU/3
		draw_arc(Vector2.ZERO,20,angle,angle+0.5,8,Color("#b5ecd9"),2,true)
	draw_set_transform(Vector2.ZERO)

func splash() -> void:
	for i in 3:
		var k := fmod(game.clock*0.8+i/3.0,1)
		ring(game.duck,9+22*k,Color(AQUA,1-k),2)
