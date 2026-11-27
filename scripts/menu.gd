extends "res://scripts/ink.gd"
## Выбор выезда не запускает симуляцию: только «Старт» загружает уровень.
const DUCK := preload("res://duck.svg")
var selected := 0
var choices: Array[Button] = []
var start: Button

func _ready() -> void:
	super._ready()
	Campaign.set_playing(false)
	var group := ButtonGroup.new()
	for id in Campaign.TITLES.size():
		var name_text := "%02d     %s" % [id,Campaign.TITLES[id]]
		var b := Campaign.make_button(name_text,Rect2(38,105+id*51,350,43))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "   "+b.text
		b.disabled = id > Campaign.unlocked
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(select_level.bind(id))
		if b.disabled:
			b.tooltip_text = "Сначала пройди уровень %02d" % (id-1)
			b.draw.connect(draw_lock.bind(b))
		add_child(b)
		choices.append(b)
	start = Campaign.make_button("Старт    ▶",Rect2(727,326,285,56))
	start.add_theme_font_size_override("font_size",21)
	for color_name in ["font_color","font_focus_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
		start.add_theme_color_override(color_name,DARK)
	for state in ["normal","hover","pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = AQUA.lightened(0.12) if state == "hover" else AQUA
		style.set_corner_radius_all(4)
		start.add_theme_stylebox_override(state,style)
	add_child(start)
	start.pressed.connect(func(): Campaign.go_to(selected))
	select_level(Campaign.current)
	start.grab_focus()

func select_level(id: int) -> void:
	selected = id
	choices[id].button_pressed = true
	queue_redraw()

func draw_lock(button: Button) -> void:
	var tint := Color("#819793")
	button.draw_arc(Vector2(326,20),4.5,PI,TAU,14,tint,1.8,true)
	button.draw_rect(Rect2(319.5,20,13,9),tint)
	button.draw_circle(Vector2(326,24),1.4,DARK)

func _draw() -> void:
	box(0,0,1056,428,Color("#102126"))
	box(0,0,408,428,Color("#172d31"))
	draw_texture_rect(DUCK,Rect2(39,22,50,50),false)
	label(102,61,"QUACK",39,FG,bold)
	label(39,94,"ВЫБОР УРОВНЯ",13,MUTED,mono)
	label(439,68,Campaign.TITLES[selected],30,FG,bold)
	label(439,96,Campaign.TASKS[selected],16,MUTED)
	# Карточка повторяет схему берегов, препятствия и обратного пандуса.
	box(439,118,573,182,Color("#78908a"))
	for x in range(445,1010,29):
		line(x,118,x,300,Color("#68817d"))
	for y in range(130,300,26):
		line(439,y,1012,y,Color("#68817d"))
	box(665,118,138,182,Color("#1a4a58"))
	for n in 35:
		var x := 672+(n*53)%108
		var y := 124+(n*67)%166
		line(x,y,x+12,y+1,Color("#376774"))
	if selected==2:
		box(695,179,34,27,Color("#b3b798"))
		box(753,207,34,27,Color("#b3b798"))
	elif selected==4:
		draw_polyline(PackedVector2Array([Vector2(664,224),Vector2(726,224),Vector2(726,202),Vector2(804,202)]),Color("#92c5c8"),13,true)
	else:
		box(665,188,138,28,Color("#c2b27e"))
		for x in range(667,803,10):
			line(x,190,x,214,DARK)
		if selected==5:
			box(661,191,48,22,Color("#84b7ba"))
			for y in [183,210]:
				box(727,y,8,12,Color("#d6945a"))
			for x in range(751,790,8):
				line(x,171,x,208,AQUA,2)
	if selected!=0:
		for bank in [665,803]:
			box(bank-4,254,8,17,DARK)
			line(bank,256,bank,269,AMBER,2)
	for x in range(572,895,10):
		if selected not in [2,4] or x<658 or x>812:
			circle(x,224 if selected==4 and x<658 else 201,1.9,AMBER)
	if selected in [0,1,3]:
		var end_x := 837 if selected==3 else 633
		draw_dashed_line(Vector2(543,148),Vector2(end_x,148),AQUA,2,6,true,true)
		circle(537,148,9,DARK)
		ring(Vector2(537,148),7,AQUA,2)
		circle(end_x,148,9,DARK)
		ring(Vector2(end_x,148),6,AMBER,2)
	draw_texture_rect(DUCK,Rect2(539,197 if selected==4 else 174,43,43),false)
	if selected!=0:
		circle(509,262,14,Color("#395d58"))
		ring(Vector2(509,262),14,AQUA,2)
		line(503,262,515,262,AQUA,2)
		line(509,256,509,268,AQUA,2)
	box(887,187,25,22,DARK)
	box(890,189,19,14,Color("#e6dcc1"))
	box(893,191,13,6,DARK)
	circle(896,194,1.6,AMBER)
	circle(903,194,1.6,AMBER)
	label(440,359,"ВЫЕЗД   %02d / 05" % selected,14,MUTED,mono)
