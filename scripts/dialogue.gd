extends "res://scripts/ink.gd"
## Реплики привязаны к действию и к говорящему. Обычный игровой экран
## снова освобождается, когда у игрока было время прочесть подсказку.
const S = preload("res://scripts/station.gd")
const E = preload("res://scripts/expedition.gd")
@onready var g: S = get_parent()
@onready var trip: E = get_parent() as E
var cue: Array = []
var age := 0.0
var bounds := Rect2()
var bubble := StyleBoxFlat.new()
var corner := -1
const BODY := 15
const TEXT_WIDTH := 215.0

func _ready() -> void:
	super._ready()
	bubble.set_corner_radius_all(10)
	bubble.set_border_width_all(1)
	bubble.shadow_size = 4
	bubble.shadow_offset = Vector2(0,2)

func repeat_hint() -> void:
	age = 0.0
	corner = -1
	queue_redraw()

func _process(delta: float) -> void:
	var next := dialogue()
	if next != cue:
		cue = next
		age = 0.0
		corner = -1
	else:
		age += delta
	queue_redraw()

func dialogue() -> Array:
	if g.showing_example:
		match g.phase:
			S.Phase.READY: return [false,"Смотри! Пробел — играть."]
			S.Phase.RECORD:
				var t := float(g.frame)/Engine.physics_ticks_per_second
				if t < S.PAUSE_AT: return [false,"Смотри! Пробел — играть."]
				if t < S.WALK_AGAIN_AT: return [false,"Дам Шайбе фору."]
				return [false,"А теперь перейду мост!"]
			S.Phase.ARMED: return [true,"Теперь я к кнопке!"]
			S.Phase.REPLAY:
				return [true,"Держу! Иди, Кряк."] if g.switch_held else [true,"Лечу! Кряк идёт сам."]
			S.Phase.WON: return [true,"Получилось! Теперь твоя очередь."]
	match g.phase:
		S.Phase.READY:
			var keys := "Пробел — запись."
			if g.lesson: return [false,"Пробел — запись.","Стрелками веди к Маячку."]
			if trip:
				if not trip.saved_choice.is_empty():
					keys = "Пробел — запись. E — своя."
				match trip.number:
					2: return [false,"По дугам в три прыжка!",keys]
					3: return [true,"Мой пульт за каналом!",keys]
					4: return [false,"На повороте я скольжу.",keys]
					5: return [false,"Створки откроются сами.",keys]
			return [false,"Стрелками веди меня.",keys]
		S.Phase.RECORD:
			if not g.lesson and at_return_gate():
				return [false,"Здесь пойдём с Маячком."]
			if trip and trip.number==2:
				return [false,"Ко второй — вправо и вниз!"] if E.ISLANDS[0].has_point(g.duck) else [false,"У края жми пробел!"]
			if trip and trip.number==3:
				if trip.bridge_entry_tick>=0:
					return [false,"Запомнил путь до берега."]
				return [true,"Теперь успею. Иди!"] if trip.frame>=trip.flight_ticks() else [false,"Жду зелёного у моста."]
			if trip and trip.number==4:
				if trip.on_wet_surface(g.duck): return [false,"Скольжу! Тормози до угла."]
				return [false,"Капля? Там скользко."]
			if trip and trip.number==5:
				if g.duck.x>trip.gate_x()+15: return [true,"На повторе перекрою струю."]
				return [false,"Пережду на полосках.","Зелёный — иду!"]
			return [false,"У края немного постою."]
		S.Phase.ARMED:
			if trip and trip.preview_fall:
				return [false,"У креста я сорвусь!","R — записать заново."]
			if trip and trip.number==3 and trip.bridge_entry_tick>=0:
				var missing := trip.flight_ticks()-trip.bridge_entry_tick
				if missing>0:
					var seconds := ("%.1f" % (ceilf(10.0*missing/Engine.physics_ticks_per_second)/10.0)).replace(".",",")
					return [true,"Не успеваю на %s с!" % seconds,"R — записать с паузой."]
				return [true,"Успеваю! Пробел — старт."]
			return [true,"Пробел — летим вместе!"]
		S.Phase.REPLAY:
			if g.switch_held:
				return [true,"Воду отвела!"] if trip and trip.number==5 else [true,"Держу! Отпусти стрелку."]
			if trip and trip.number==2: return [true,"К пульту! Подниму опору."]
			if trip and trip.number==3: return [true,"Лечу на дальний берег!"]
			if trip and trip.number==5: return [true,"Я к вентилю!"]
			return [true,"Я к кнопке. Кряк идёт сам."]
		S.Phase.EVAC:
			if g.attached: return [false,"Мост открыт! Домой по стрелкам."]
			if g.duck.distance_to(g.passenger)<=47:
				return [false,"Маячок, цепляйся! Нажми E."]
			if at_return_gate(): return [false,"Зацеплю Маячка — открою мост."]
			return [false,"Подведи меня к Маячку."]
		S.Phase.LOST:
			var retry := "Пробел — ещё раз. R — запись."
			if g.retry_phase==S.Phase.EVAC: retry = "Пробел — к Маячку."
			return [trip!=null and trip.number==3 and g.retry_phase==S.Phase.REPLAY,g.problem,retry]
		S.Phase.WON:
			if g.lesson: return [true,"Сработались!","Пробел — уровень 01."]
			return [true,"Оба на базе!", "Пробел — в меню." if Campaign.current==5 else "Пробел — следующий выезд."]
	return []

func at_return_gate() -> bool:
	return not g.return_open and S.L.return_ramp(g.left,g.right).grow(29).has_point(g.duck)

func _draw() -> void:
	bounds = Rect2()
	# Маленькое кольцо у активного героя заменяет отдельную панель таймера.
	if g.phase in [S.Phase.RECORD,S.Phase.REPLAY]:
		var rec := g.phase==S.Phase.RECORD
		var total := g.max_frames if rec or not trip else g.commands.size()
		var at := g.duck if rec else g.drone
		var fraction := clampf(float(g.frame)/maxi(1,total),0,1)
		draw_arc(at,29,-PI/2,-PI/2+TAU*maxf(0.005,fraction),52,AMBER if rec else AQUA,2,true)
	if cue.is_empty():
		return
	var duration := 4.2 if cue.size()>2 else 3.2
	var outcome := not g.showing_example and g.phase in [S.Phase.WON,S.Phase.LOST]
	if not outcome and age>duration:
		return
	var alpha := 1.0 if outcome else minf(1.0,(duration-age)*3.5)
	var drone_speaks: bool = cue[0]
	var who := "ШАЙБА" if drone_speaks else "КРЯК"
	if g.showing_example:
		who += "  ·  ДЕМО"
	var tint := AQUA if drone_speaks else AMBER
	var actor := g.drone if drone_speaks else g.duck
	var lines := PackedStringArray()
	var w := bold.get_string_size(who,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
	for i in range(1,cue.size()):
		var row := ""
		for word in String(cue[i]).split(" ",false):
			var joined := row+" "+word if row!="" else word
			if row!="" and sans.get_string_size(joined,HORIZONTAL_ALIGNMENT_LEFT,-1,BODY).x>TEXT_WIDTH:
				lines.append(row)
				joined = word
			row = joined
		lines.append(row)
	for row in lines:
		w = maxf(w,sans.get_string_size(row,HORIZONTAL_ALIGNMENT_LEFT,-1,BODY).x)
	bounds = free_corner(Vector2(ceilf(w)+18,20+lines.size()*17),actor)
	var x := bounds.position.x
	var y := bounds.position.y
	var bg := Color("#142a2e")
	bg.a = alpha
	tint.a = alpha
	bubble.bg_color = bg
	bubble.border_color = tint
	bubble.shadow_color = Color(0,0,0,alpha*0.25)
	draw_style_box(bubble,bounds)
	var tx := clampf(actor.x,x+12,bounds.end.x-12)
	var top := actor.y < bounds.get_center().y
	var edge := y if top else bounds.end.y
	poly([Vector2(tx-4,edge),Vector2(tx+4,edge),Vector2(tx,edge+(-4 if top else 4))],tint)
	label(x+9,y+13,who,11,tint,bold)
	for i in lines.size():
		label(x+9,y+30+17*i,lines[i],BODY,Color(FG,alpha))

func free_corner(size: Vector2, speaker: Vector2) -> Rect2:
	# Все четыре места находятся на суше. Оставляем над каналом и кнопку,
	# и ближайшие к действующим героям участки свободными.
	var positions := [Vector2(48,112),Vector2(962-size.x,112),
			Vector2(48,506-size.y),Vector2(1072-size.x,506-size.y)]
	var targets := [g.duck,g.drone,g.passenger,S.L.EVAC_PAD,trip.control if trip else S.L.SWITCH]
	var best := INF
	var choice := 0
	for i in positions.size():
		var rect := Rect2(positions[i],size)
		var score := rect.get_center().distance_to(speaker)
		if i==corner: score -= 1200.0
		for target: Vector2 in targets:
			if rect.grow(38).has_point(target): score += 10000.0
		if trip and trip.number==3 and rect.grow(26).intersects(Rect2(trip.launch,Vector2(trip.control.x-trip.launch.x,1))):
			score += 5000.0
		if score<best:
			best = score
			choice = i
	corner = choice
	return Rect2(positions[choice],size)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if g.showing_example and bounds.has_point(get_local_mouse_position()):
			g.finish_example(true)
			get_viewport().set_input_as_handled()
