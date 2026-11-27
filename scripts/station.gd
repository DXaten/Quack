extends Node2D
## Правила уровня. Рисунок станции и интерфейс вынесены в два дочерних узла.

const L = preload("res://scripts/level.gd")
const SEEN_EXAMPLE := "user://quack_lesson_example_seen"
const PAUSE_AT := 0.65
const WALK_AGAIN_AT := 1.9
enum Phase { READY, RECORD, ARMED, REPLAY, WON, LOST, EVAC }

var phase := Phase.READY
var duck := L.DUCK_START
var drone := L.DRONE_START
var facing := 1.0
var tape := PackedVector2Array()
var commands := PackedVector2Array()
var frame := 0
var max_frames := roundi(L.SECONDS * Engine.physics_ticks_per_second)
var switch_held := false
var fell := false
var clock := 0.0
var bridge_open_amount := 1.0 # Доля видимого настила; используется только для анимации.
var step_time := 0.0
var voice := AudioStreamPlayer.new()
var sounds := {}
var showing_example := false
var lesson := false
var duck_start := L.DUCK_START
var drone_start := L.DRONE_START
var example_hold := 0.0
var example_direction := Vector2.ZERO
var left := L.WATER_LEFT
var right := L.WATER_RIGHT
var pickup := L.BEACON
var passenger := L.BEACON
var attached := false
var return_open := false
var problem := ""
var retry_phase := Phase.REPLAY

func _ready() -> void:
	Campaign.set_playing(true)
	# Физические клавиши WASD работают и при русской раскладке.
	for binding in [["left", KEY_A, KEY_LEFT], ["right", KEY_D, KEY_RIGHT],
			["up", KEY_W, KEY_UP], ["down", KEY_S, KEY_DOWN],
			["action", KEY_SPACE], ["reset_tape", KEY_R], ["watch_example", KEY_TAB], ["interact", KEY_E]]:
		var action := StringName(binding[0])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in binding.slice(1):
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)
	add_child(voice)
	voice.volume_db = -14
	for cue in [["record", [392, 523]], ["armed", [523, 660]], ["switch", [294, 440]],
			["drop", [290, 175, 90]], ["empty", [290, 240]], ["rescue", [392, 494, 587, 784]]]:
		sounds[cue[0]] = make_chime(cue[1])
	lesson = Campaign.current == 0
	if lesson:
		duck_start = Vector2(347,L.BRIDGE_Y)
		drone_start = Vector2(235,L.SWITCH.y)
		pickup = Vector2(748,L.BRIDGE_Y)
		reset_level()
		if not FileAccess.file_exists(SEEN_EXAMPLE):
			start_example()

func _unhandled_input(event: InputEvent) -> void:
	# is_action_pressed по умолчанию игнорирует автоповтор удержанной клавиши.
	if event.is_action_pressed("action"):
		if showing_example:
			finish_example(true)
		else:
			advance()
	elif event.is_action_pressed("watch_example") and lesson and phase == Phase.READY and not showing_example:
		start_example()
	elif event.is_action_pressed("reset_tape") and not showing_example:
		reset_level()
	elif event.is_action_pressed("interact") and phase == Phase.EVAC and not showing_example:
		toggle_tow()

func start_example() -> void:
	reset_level()
	showing_example = true
	example_hold = 0.0
	example_direction = Vector2.ZERO

func finish_example(play_now: bool) -> void:
	showing_example = false
	# Запоминаем просмотр или осознанный пропуск. Tab с начального экрана
	# позволяет снова посмотреть пример даже после перезапуска игры.
	if not FileAccess.file_exists(SEEN_EXAMPLE):
		var marker := FileAccess.open(SEEN_EXAMPLE, FileAccess.WRITE)
		if marker:
			marker.store_8(1)
	reset_level()
	if play_now:
		advance()

func example_input(delta: float) -> Vector2:
	# Пример подаёт направления в ту же физику, что и клавиатура игрока.
	# И мост, и запись, и победа работают по обычным правилам уровня.
	match phase:
		Phase.RECORD:
			var t := float(frame) / Engine.physics_ticks_per_second
			if (t < PAUSE_AT or t >= WALK_AGAIN_AT) and duck.x < pickup.x:
				return Vector2.RIGHT
		Phase.REPLAY:
			if drone.x < L.SWITCH.x:
				return Vector2.RIGHT
		Phase.READY, Phase.ARMED, Phase.WON, Phase.LOST:
			example_hold += delta
			var hold_for := 1.8
			if example_hold >= hold_for:
				example_hold = 0.0
				if phase in [Phase.WON, Phase.LOST]:
					finish_example(false)
				else:
					advance()
					return Vector2.RIGHT
	return Vector2.ZERO

func advance() -> void:
	match phase:
		Phase.READY:
			tape = PackedVector2Array([duck_start])
			commands.clear()
			frame = 0
			phase = Phase.RECORD
			play("record")
		Phase.ARMED, Phase.LOST:
			if phase == Phase.LOST and retry_phase == Phase.EVAC:
				restore_evac()
				return
			# При повторной попытке оставляем запись и возвращаем обоих на старт.
			frame = 0
			duck = tape[0]
			drone = drone_start
			facing = 1.0
			switch_held = false
			fell = false
			phase = Phase.REPLAY
			bridge_open_amount = 0.0
			play("record")
		Phase.WON:
			Campaign.advance_mission()

func reset_level() -> void:
	phase = Phase.READY
	frame = 0
	tape.clear()
	commands.clear()
	duck = duck_start
	drone = drone_start
	facing = 1.0
	switch_held = false
	fell = false
	passenger = pickup
	attached = false
	return_open = false
	problem = ""
	retry_phase = Phase.REPLAY
	bridge_open_amount = 1.0
	voice.stop()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("left", "right", "up", "down")
	if showing_example:
		example_direction = example_input(delta)
		direction = example_direction
	match phase:
		Phase.RECORD:
			var next := L.walk(duck, direction * L.DUCK_SPEED * delta)
			move_duck(next)
			# Записываем позицию каждый физический тик, даже когда Кряк стоит.
			# Поэтому пауза на краю сохранится с той же длительностью.
			tape.append(duck)
			commands.append(direction)
			frame += 1
			if frame >= max_frames or (lesson and duck.distance_to(pickup)<=L.RESCUE_RADIUS):
				phase = Phase.ARMED
				# Оба героя ждут пробела на старте. Пока лента стоит,
				# направлением нельзя дать Шайбе фору.
				duck = tape[0]
				facing = 1.0
				play("armed")
		Phase.REPLAY:
			# С первого же тика повтора ввод двигает Шайбу, а лента — Кряка.
			fly_drone(direction, delta)
			# Сначала считываем кнопку, затем берём очередную позицию с ленты.
			# Кряк в этот момент уже не зависит от клавиш движения.
			frame += 1
			move_duck(tape[frame])
			if L.on_canal(duck) and not switch_held:
				fell = true
				phase = Phase.LOST
				problem = "Я упал! Держи кнопку, пока я на мосту."
				play("drop")
			elif duck.distance_to(pickup) <= L.RESCUE_RADIUS:
				if lesson:
					# Для зачёта нужны собственная запись и синхронный полёт к кнопке.
					phase = Phase.WON
					if not showing_example:
						Campaign.complete()
					play("rescue")
				else:
					Campaign.remember("deck",commands.slice(0,frame))
					begin_evac()
			elif frame == tape.size() - 1:
				phase = Phase.LOST
				problem = "Не дошёл до Маячка. Перезапишем путь?"
				play("empty")
		Phase.EVAC:
			evacuation_step(direction,delta)

func begin_evac() -> void:
	switch_held = false
	phase = Phase.EVAC
	play("armed")

func restore_evac() -> void:
	duck = pickup-Vector2(33,0)
	passenger = pickup
	attached = false
	return_open = false
	fell = false
	phase = Phase.EVAC

func toggle_tow() -> void:
	if attached:
		attached = false
	elif duck.distance_to(passenger) <= 47:
		attached = true
		# Замок срабатывает от первой сцепки. Если отпустить трос на мосту,
		# настил остаётся под Кряком до конца этой попытки.
		return_open = true
		play("switch")

func guard_return(from: Vector2, to: Vector2) -> Vector2:
	# Закрытый шлагбаум удерживает Кряка на берегу у входа в пандус.
	var ramp := L.return_ramp(left,right)
	if not return_open and to.y >= ramp.position.y and to.y <= ramp.end.y:
		if from.x <= left-5:
			to.x = minf(to.x,left-5)
		elif from.x >= right+5:
			to.x = maxf(to.x,right+5)
	return to

func safe_return(point: Vector2) -> bool:
	if point.x <= left-5 or point.x >= right+5:
		return true
	return return_open and L.return_ramp(left,right).grow(-5).has_point(point)

func evacuation_step(direction: Vector2, dt: float) -> void:
	var area := L.FLOOR.grow(-16)
	var speed := 132.0 if attached else 190.0
	move_duck(guard_return(duck,(duck+direction*speed*dt).clamp(area.position,area.end)))
	if attached and passenger.distance_to(duck)>30:
		passenger = duck+(passenger-duck).normalized()*30
	if not safe_return(duck) or (attached and not safe_return(passenger)):
		problem = "Сорвались! Обратно едем по нижнему пандусу."
		retry_phase = Phase.EVAC
		phase = Phase.LOST
		fell = true
		play("drop")
	elif attached and duck.distance_to(L.EVAC_PAD)<=45 and passenger.distance_to(L.EVAC_PAD)<=45:
		phase = Phase.WON
		if not showing_example:
			Campaign.complete()
		play("rescue")

func fly_drone(direction: Vector2, delta: float) -> void:
	var area := L.FLOOR.grow(-16.0)
	drone = (drone + direction * L.DRONE_SPEED * delta).clamp(area.position, area.end)
	var pressing := drone.distance_to(L.SWITCH) <= L.SWITCH_RADIUS
	if pressing and not switch_held:
		play("switch")
	switch_held = pressing

func move_duck(next: Vector2) -> void:
	if absf(next.x - duck.x) > 0.01:
		facing = signf(next.x - duck.x)
	step_time += duck.distance_to(next) * 0.14
	duck = next

func bridge_down() -> bool:
	return phase in [Phase.READY, Phase.RECORD] or switch_held

func _process(delta: float) -> void:
	clock += delta
	bridge_open_amount = move_toward(bridge_open_amount, float(bridge_down()), delta * 8.0)
	$Canal.queue_redraw()
	$Panel.queue_redraw()

func play(cue: String) -> void:
	voice.stream = sounds[cue]
	voice.play()

func make_chime(notes: Array) -> AudioStreamWAV:
	# Короткие сигналы станции синтезируются один раз, без внешних звуковых файлов.
	const RATE := 22050
	const SAMPLES := 2000
	var bytes := PackedByteArray()
	bytes.resize(notes.size() * SAMPLES * 2)
	for n in notes.size():
		for i in SAMPLES:
			var envelope := minf(i / 90.0, 1.0) * pow(1.0 - float(i) / SAMPLES, 1.6)
			var sample := sin(TAU * float(notes[n]) * i / RATE) * envelope
			bytes.encode_s16((n * SAMPLES + i) * 2, roundi(sample * 18000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav
