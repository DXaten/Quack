extends "res://scripts/board.gd"
const E = preload("res://scripts/expedition.gd")
@onready var trip: E = get_parent()

func _draw() -> void:
	box(32,96,1056,426,EDGE)
	box(42,106,1036,405,DECK)
	floor_tiles(false)
	river()
	if trip.number == 2:
		viaduct()
	else:
		crossings()
	valve()
	if trip.phase in [S.Phase.ARMED,S.Phase.RECORD,S.Phase.REPLAY]:
		route()
	if trip.phase == S.Phase.ARMED and trip.preview_fall:
		var end := trip.tape[trip.tape.size()-1]
		line(end.x-6,end.y-6,end.x+6,end.y+6,RED,4)
		line(end.x-6,end.y+6,end.x+6,end.y-6,RED,4)
	return_facilities()
	beacon(trip.passenger)
	if trip.fell:
		splash()
	else:
		var height := 27.0*sin(PI*trip.jump_left/E.JUMP_TIME)
		draw_duck(height)
	draw_drone()

func river() -> void:
	var width := trip.right-trip.left
	box(trip.left,106,width,405,Color("#174552"))
	for i in 82:
		var x := trip.left+9+fmod(i*61,width-38)
		var y := 110+fmod(i*101+trip.clock*(4+i%4),391)
		line(x,y,x+7+i%13,y+1,Color("#346772"),1.4)
	for bank in [trip.left,trip.right]:
		line(bank,108,bank,510,EDGE,6)
		for y in range(115,507,21):
			line(bank-2,y,bank+2,y+6,Color("#c3ba8b"),2)

func viaduct() -> void:
	var raised := trip.phase != S.Phase.REPLAY or trip.switch_held
	for island: Rect2 in E.ISLANDS:
		draw_rect(island,EDGE)
		draw_rect(island.grow(-4),Color("#9ba899") if raised else Color("#37606b"))
		if not raised:
			for y in range(int(island.position.y)+10,int(island.end.y)-5,12):
				line(island.position.x+6,y,island.end.x-6,y,Color("#51909c"),2)
		for x in range(int(island.position.x)+9,int(island.end.x)-6,16):
			line(x,island.position.y+7,x+6,island.position.y+7,AMBER,3)
	for i in range(0,E.JUMP_GUIDES.size(),2):
		for n in 8:
			var t := n/7.0
			var p: Vector2 = E.JUMP_GUIDES[i].lerp(E.JUMP_GUIDES[i+1],t)
			circle(p.x,p.y-sin(t*PI)*15,2.2,AMBER)

func crossings() -> void:
	if trip.number == 4:
		for far_bank in [false,true]:
			var apron := trip.wet_apron(far_bank)
			draw_rect(apron,Color("#77a4a4"))
			for x in range(int(apron.position.x)+4,int(apron.end.x)-8,16):
				line(x,apron.end.y-6,x+8,apron.end.y-9,Color("#c4e6df"),2)
		slippery_deck()
		wet_warning(trip.wet_apron(false).position + Vector2(66,-4))
	else:
		deck()
	if trip.number == 5:
		sluice()
	if trip.phase==S.Phase.RECORD and trip.on_wet_surface(trip.duck) and trip.velocity.length()>35:
		var stop := trip.duck+trip.velocity.normalized()*trip.velocity.length_squared()/(2*E.WET_BRAKE)
		draw_dashed_line(trip.duck,stop,Color("#e4fcdf"),2,4,true,true)
		ring(stop,4,Color("#e4fcdf"))
	if trip.number == 3 and trip.phase in [S.Phase.READY,S.Phase.RECORD,S.Phase.ARMED,S.Phase.REPLAY]:
		approach_light()
	ring(trip.origin,24,AMBER,2)
	var x := trip.right+23
	for y in range(164,462,15):
		box(x,y,3,7,Color("#e1d3a1"))

func sluice() -> void:
	var wet := trip.sluice_approach()
	draw_rect(wet,Color("#84b7ba"))
	for x in range(int(wet.position.x)+5,int(wet.end.x)-6,14):
		line(x,wet.position.y+12,x+8,wet.position.y+9,Color("#d4f5f6"),2)
	wet_warning(wet.position+Vector2(18,-8))
	var gx := trip.gate_x()
	var cy := trip.origin.y
	# Рифлёный карман даёт сцепление перед движущимися створками.
	box(wet.end.x,wet.position.y,gx-16-wet.end.x,wet.size.y,Color("#566f6a"))
	for x in range(int(wet.end.x)+3,int(gx)-18,7):
		line(x,wet.position.y+2,x,wet.end.y-2,Color("#ebce88"),2)
	var t := trip.frame % E.GATE_CYCLE
	var aperture := trip.gate_opening(t)*E.GATE_HALF_SPAN
	var light := RED
	if t>=E.GATE_GREEN and t<E.GATE_WARNING: light = Color("#87f1b0")
	elif t>=E.GATE_OPENS: light = AMBER
	for side in [-1,1]:
		var housing_y: float = cy+side*(E.GATE_HALF_SPAN+6)
		var y1: float = cy+side*aperture
		var y2: float = cy+side*E.GATE_HALF_SPAN
		if absf(y1-y2)>0.1:
			box(gx-5,minf(y1,y2),10,absf(y1-y2),DARK)
			line(gx,y1,gx,y2,Color("#da995c"),4)
		box(gx-9,housing_y-6,18,12,EDGE)
		circle(gx,housing_y,3.5,light)
	var active := not trip.switch_held and trip.phase != S.Phase.RECORD
	var y0 := cy-55
	var first_jet := gx+23
	box(first_jet,y0-9,trip.right-14-first_jet,12,EDGE)
	for x in range(int(first_jet)+5,int(trip.right)-15,12):
		box(x-3,y0-3,7,7,Color("#8aaba8"))
		if active:
			for k in 3:
				var y := y0+6+fmod(trip.clock*79+k*28+x,86)
				line(x,y,x,y+9,Color("#baf6ef"),2)
				line(x,y+9,x+3,y+6,Color("#baf6ef"),2)

func approach_light() -> void:
	var p := Vector2(trip.left-27,trip.origin.y-43)
	var tick := trip.frame if trip.bridge_entry_tick<0 else trip.bridge_entry_tick
	var fraction := clampf(float(tick)/trip.flight_ticks(),0,1)
	var ready := fraction>=1.0
	if trip.phase==S.Phase.REPLAY:
		fraction = clampf(1.0-(trip.drone.distance_to(trip.control)-L.SWITCH_RADIUS)/(trip.launch.distance_to(trip.control)-L.SWITCH_RADIUS),0,1)
		ready = trip.switch_held
	var ink := Color("#87f1b0") if ready else AMBER
	if trip.phase==S.Phase.ARMED and not ready:
		ink = RED
	circle(p.x,p.y,16,DARK)
	ring(p,13,Color("#577575"),2)
	draw_arc(p,13,-PI/2,-PI/2+TAU*maxf(fraction,0.005),48,ink,3,true)
	draw_line(p,p+Vector2.UP*7,ink,2,true)
	draw_line(p,p+Vector2.RIGHT*5,ink,2,true)
	draw_dashed_line(Vector2(p.x,trip.origin.y-22),Vector2(p.x,trip.origin.y+21),ink,2,5,true,true)

func slippery_deck() -> void:
	var points := PackedVector2Array(E.WET_ROUTE)
	var half := 22.0
	var fill := Color("#92c5c8")
	var accent := Color("#d4f5f6")
	var stage := trip.retry_phase if trip.phase==S.Phase.LOST else trip.phase
	if stage in [S.Phase.EVAC,S.Phase.WON] or (stage==S.Phase.REPLAY and not trip.switch_held):
		for end in [points[0],points[-1]]:
			draw_rect(Rect2(end-Vector2(6,half),Vector2(12,half*2)),EDGE)
		for pillar in points.slice(1,-1):
			draw_circle(pillar,4,Color("#44676c"))
		return
	for layer in [0,1]:
		var radius := half+2 if layer==0 else half
		var tint := EDGE if layer==0 else fill
		draw_polyline(points,tint,radius*2,true)
		for v in points: draw_circle(v,radius,tint,true,-1,true)
	for i in range(1,points.size()):
		var heading := points[i-1].direction_to(points[i])
		var normal := heading.orthogonal()
		var dist := 8.0
		while dist<points[i-1].distance_to(points[i])-5:
			var p := points[i-1]+heading*dist
			draw_line(p+normal*12,p+normal*15+heading*10,accent,1.6,true)
			dist += 13
		var mid := (points[i-1]+points[i])*0.5
		draw_polyline(PackedVector2Array([mid-heading*6+normal*4,mid,mid-heading*6-normal*4]),EDGE,2,true)

func wet_warning(p: Vector2) -> void:
	poly([p+Vector2(0,-12),p+Vector2(13,10),p+Vector2(-13,10)],DARK)
	var ink := Color("#b7f5f3")
	poly([p+Vector2(0,-6),p+Vector2(-3.6,1),p+Vector2(3.6,1)],ink)
	draw_circle(p+Vector2(0,2),3.8,ink,true,-1,true)

func deck() -> void:
	var half := 30.0
	var amount := trip.bridge_open_amount
	var edge := Color("#d9c58d")
	for side in [0,1]:
		var start := float(side)
		var stop := lerpf(start,0.5,0.07+0.93*amount)
		for i in 9:
			var a := lerpf(start,stop,i/9.0)
			var b := lerpf(start,stop,(i+1)/9.0)
			var xa := lerpf(trip.left,trip.right,a)
			var xb := lerpf(trip.left,trip.right,b)
			var ya := trip.origin.y
			var yb := trip.origin.y
			var fill := Color("#b7a77b")
			poly([Vector2(xa,ya-half),Vector2(xb,yb-half),Vector2(xb,yb+half),Vector2(xa,ya+half)],fill)
			line(xa,ya-half,xa,ya+half,EDGE,1)
			line(xa,ya-half,xb,yb-half,edge,3)
			line(xa,ya+half,xb,yb+half,edge,3)

func valve() -> void:
	var p := trip.control
	var glow := AQUA if trip.switch_held else AMBER
	circle(p.x,p.y,22,DARK)
	ring(p,18,glow,3)
	if trip.number == 5:
		for i in 4:
			var tip := Vector2.RIGHT.rotated(i*PI/2+0.5)*13
			draw_line(p,p+tip,glow,3,true)
	else:
		line(p.x-6,p.y,p.x+6,p.y,glow,3)
		line(p.x,p.y-6,p.x,p.y+6,glow,3)
	if (trip.phase in [S.Phase.ARMED,S.Phase.REPLAY] or (trip.number==3 and trip.phase==S.Phase.READY)) and not trip.switch_held:
		var heading := trip.drone.direction_to(p)
		var gap := 38.0
		while gap < trip.drone.distance_to(p)-24:
			var tip := trip.drone + heading*gap
			draw_polyline(PackedVector2Array([tip-heading*6+heading.orthogonal()*3,tip,tip-heading*6-heading.orthogonal()*3]),AQUA,2,true)
			gap += 25

