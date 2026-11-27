extends "res://scripts/station.gd"
## Миссии 2–5. Запись хранит ввод, поэтому один приём можно исполнить
## с другой метки, на мокром покрытии или под поперечной струёй.
const ISLANDS := [Rect2(489,260,60,55), Rect2(578,315,64,56)]
const JUMP_GUIDES := [Vector2(414,301), Vector2(510,287), Vector2(533,291), Vector2(605,341), Vector2(628,341), Vector2(725,341)]
const JUMP_TIME := 0.56
# Координаты оси настила в четвёртом выезде. Рисунок и проверка опоры
# используют одну ломаную: идти напрямик через изгиб нельзя.
const WET_ROUTE := [Vector2(440,373), Vector2(516,373), Vector2(516,325), Vector2(637,325)]
const WET_BRAKE := 210.0
const GATE_CYCLE := 144 # Такты физики. Новая запись и каждый повтор начинают цикл с нуля.
const GATE_OPENS := 86
const GATE_GREEN := 102
const GATE_WARNING := 119
const GATE_CLOSES := 130
const GATE_HALF_SPAN := 30.0
var number := 2
var origin := Vector2.ZERO
var control := Vector2.ZERO
var launch := Vector2.ZERO
var velocity := Vector2.ZERO
var jump_left := 0.0
var jump_requested := false
var jumps := PackedByteArray()
var preview_fall := false
var imported := false
var saved_choice := PackedVector2Array()
var bridge_entry_tick := -1

func _ready() -> void:
	number = Campaign.current
	super._ready()
	configure()
	reset_level()

func configure() -> void:
	match number:
		2: origin = Vector2(325,301)
		3: origin = Vector2(279,308)
		4: origin = Vector2(297,WET_ROUTE[0].y)
		5: origin = Vector2(313,333)
	if number == 2:
		left = 430
		right = 700
	else:
		left = origin.x + 147
		right = left + (210 if number == 5 else 189)
	control = Vector2(left-38,181)
	launch = Vector2(107,181)
	match number:
		2: launch = Vector2(control.x-138,181)
		3:
			# Пульт за каналом: на первом шлюзе до кнопки было около 1,4 с.
			launch = Vector2(left-196,170)
			control = Vector2(right+59,170)
		4: launch = control-Vector2(79,0)
	pickup = Vector2(852,301 if number == 2 else 320)

func slot() -> String:
	match number:
		2: return "three_gaps"
		4: return "wet"
		5: return "sluice"
	return "deck"

func reset_level() -> void:
	super.reset_level()
	jump_left = 0
	jumps.clear()
	imported = false
	preview_fall = false
	bridge_entry_tick = -1
	reset_actors()
	find_saved_choice()

func find_saved_choice() -> void:
	# На старте лента пуста. Свой старый приём можно выбрать отдельно клавишей E.
	saved_choice = Campaign.recall(slot())
	if number == 2 and Campaign.recall_jumps(slot()).size() != saved_choice.size():
		saved_choice.clear()

func reset_actors() -> void:
	duck = origin
	drone = launch
	velocity = Vector2.ZERO
	jump_left = 0
	jump_requested = false
	switch_held = false
	fell = false
	facing = 1
	frame = 0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action"):
		advance()
	elif event.is_action_pressed("reset_tape"):
		reset_level()
	elif event.is_action_pressed("interact"):
		if phase == Phase.READY and not saved_choice.is_empty():
			commands = saved_choice.duplicate()
			if number == 2:
				jumps = Campaign.recall_jumps(slot())
			imported = true
			prepare_preview()
		elif phase == Phase.EVAC:
			toggle_tow()

func flight_ticks() -> int:
	var distance := launch.distance_to(control)-L.SWITCH_RADIUS
	return ceili(distance * Engine.physics_ticks_per_second / L.DRONE_SPEED)

func advance() -> void:
	match phase:
		Phase.READY:
			new_recording()
		Phase.RECORD:
			if number == 2:
				jump_requested = true
			elif at_finish(duck):
				finish_recording()
		Phase.ARMED:
			reset_actors()
			phase = Phase.REPLAY
			bridge_open_amount = float(number == 5)
			play("record")
		Phase.LOST:
			if retry_phase == Phase.REPLAY:
				phase = Phase.ARMED
				advance()
			elif retry_phase == Phase.RECORD:
				new_recording()
			else:
				restore_evac()
		Phase.WON:
			Campaign.advance_mission()

func new_recording() -> void:
	reset_actors()
	bridge_entry_tick = -1
	imported = false
	commands.clear()
	jumps.clear()
	tape = PackedVector2Array([origin])
	phase = Phase.RECORD
	play("record")

func finish_recording() -> void:
	if not at_finish(duck):
		fail("Запись закончилась до дальней метки",Phase.RECORD,false)
		return
	Campaign.remember(slot(),commands,jumps)
	prepare_preview()
	play("armed")

func prepare_preview() -> void:
	reset_actors()
	phase = Phase.ARMED
	tape = PackedVector2Array([origin])
	var point := origin
	var speed := Vector2.ZERO
	var air := 0.0
	preview_fall = false
	bridge_entry_tick = -1
	var dt := 1.0 / Engine.physics_ticks_per_second
	for i in commands.size():
		var direction := commands[i]
		speed = next_speed(point,speed,direction,dt)
		if number == 2:
			air = jump_tick(air,jumps[i] != 0,dt)
		point = guard_return(point,bounded(point + speed*dt))
		tape.append(point)
		if bridge_entry_tick < 0 and over_water(point):
			bridge_entry_tick = i+1
		if (air <= 0 and not supported(point)) or (number == 5 and hits_gate(point,i+1)):
			preview_fall = true
			break

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("left","right","up","down")
	match phase:
		Phase.EVAC:
			evacuation_step(direction,delta)
		Phase.RECORD:
			commands.append(direction)
			if number == 2:
				jumps.append(int(jump_requested))
				jump_left = jump_tick(jump_left,jump_requested,delta)
				jump_requested = false
			traverse(direction,delta)
			if bridge_entry_tick<0 and over_water(duck):
				bridge_entry_tick = frame+1
			tape.append(duck)
			frame += 1
			if phase == Phase.RECORD and frame >= max_frames:
				finish_recording()
		Phase.REPLAY:
			# Шайба и лента двигаются на одном физическом тике, как в первом шлюзе.
			drone = bounded(drone + direction*L.DRONE_SPEED*delta)
			var pressed := drone.distance_to(control) <= L.SWITCH_RADIUS
			if pressed and not switch_held:
				play("switch")
			switch_held = pressed
			if number == 2:
				jump_left = jump_tick(jump_left,jumps[frame] != 0,delta)
			traverse(commands[frame],delta)
			frame += 1
			if phase == Phase.REPLAY and frame >= commands.size():
				if at_finish(duck):
					velocity = Vector2.ZERO
					jump_left = 0
					begin_evac()
				else:
					fail("Приём закончился до финишной метки",Phase.REPLAY,false)

func next_speed(point: Vector2, speed: Vector2, direction: Vector2, dt: float) -> Vector2:
	if number == 2:
		return direction*190.0
	var target := direction * L.DUCK_SPEED
	if on_wet_surface(point):
		return speed.move_toward(target,(WET_BRAKE if direction.is_zero_approx() else 475.0)*dt)
	return target

func bounded(point: Vector2) -> Vector2:
	var area := L.FLOOR.grow(-16)
	return point.clamp(area.position,area.end)

func over_water(point: Vector2) -> bool:
	return point.x > left-5 and point.x < right+5

func on_route(point: Vector2, path: Array, margin: float) -> bool:
	for i in range(1,path.size()):
		var closest := Geometry2D.get_closest_point_to_segment(point,path[i-1],path[i])
		if point.distance_squared_to(closest)<=margin*margin:
			return true
	return false

func wet_apron(far_bank: bool) -> Rect2:
	if far_bank:
		return Rect2(right,WET_ROUTE[-1].y-18,48,36)
	return Rect2(left-90,WET_ROUTE[0].y-18,90,36)

func on_wet_surface(point: Vector2) -> bool:
	if number == 5:
		return sluice_approach().has_point(point)
	if number != 4:
		return false
	if over_water(point):
		return on_route(point,WET_ROUTE,17)
	return wet_apron(false).has_point(point) or wet_apron(true).has_point(point)

func supported(point: Vector2) -> bool:
	if not over_water(point):
		return true
	if number == 2:
		for island: Rect2 in ISLANDS:
			if island.grow(-4).has_point(point):
				return true
		return false
	if number == 4:
		return on_wet_surface(point)
	return absf(point.y-origin.y)<=22.0

func at_finish(point: Vector2) -> bool:
	return point.x >= right+23 and supported(point) and jump_left <= 0

func sluice_approach() -> Rect2:
	return Rect2(left-36,origin.y-24,90,48)

func gate_x() -> float:
	return left+98

func gate_opening(tick: int) -> float:
	var t := tick % GATE_CYCLE
	if t < GATE_OPENS: return 0.0
	if t < GATE_GREEN: return float(t-GATE_OPENS)/(GATE_GREEN-GATE_OPENS)
	if t < GATE_CLOSES: return 1.0
	return float(GATE_CYCLE-t)/(GATE_CYCLE-GATE_CLOSES)

func hits_gate(point: Vector2, tick: int) -> bool:
	if absf(point.x-gate_x()) >= 5.0+L.FOOT_RADIUS:
		return false
	var opening := gate_opening(tick)*GATE_HALF_SPAN
	return opening < GATE_HALF_SPAN and absf(point.y-origin.y)+L.FOOT_RADIUS > opening

func in_stream(point: Vector2) -> bool:
	return point.x > gate_x()+23 and point.x < right-14

func traverse(direction: Vector2, dt: float) -> void:
	var previous := duck
	velocity = next_speed(duck,velocity,direction,dt)
	var step := velocity*dt
	if phase == Phase.REPLAY and number == 5 and not switch_held and in_stream(duck):
		step.y += 132.0*dt
	move_duck(guard_return(duck,bounded(duck+step)))
	if number == 5 and hits_gate(duck,frame+1):
		fail("Створки! Пережду на полосках.",phase,false)
		return
	if jump_left > 0:
		return
	if not supported(duck):
		var cause := "Кряк соскользнул с опоры"
		if number == 2:
			cause = "Целься по дуге на опору!"
		if number == 4:
			cause = "Скользко! Тормози до угла." if on_wet_surface(previous) else "Свернул мимо настила!"
		if number == 5 and phase == Phase.REPLAY and not switch_held and in_stream(duck):
			cause = "Поток снёс Кряка"
		fail(cause,phase)
	elif phase == Phase.REPLAY and number != 5 and over_water(duck) and not switch_held:
		var why := "Шайба, держи настил!"
		if number==2: why = "Опора под водой!"
		if number==3 and bridge_entry_tick < flight_ticks(): why = "Мне нужна пауза подлиннее!"
		fail(why,Phase.REPLAY)

func jump_tick(remaining: float, pressed: bool, dt: float) -> float:
	# Храним нажатие рядом с направлением того же кадра. Симулятор, прогноз
	# и живой повтор используют одно время полёта и одну точку приземления.
	if pressed and remaining <= 0:
		remaining = JUMP_TIME
	return maxf(0,remaining-dt)

func fail(message: String, retry: Phase, in_water := true) -> void:
	problem = message
	retry_phase = retry
	fell = in_water
	phase = Phase.LOST
	play("drop")

func bridge_down() -> bool:
	return number == 5 or phase == Phase.RECORD or switch_held
