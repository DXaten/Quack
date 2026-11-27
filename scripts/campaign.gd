extends CanvasLayer
## Общая карта выездов и локальное сохранение. Список команд хранится
## относительно стартовой метки, поэтому подходит для другой миссии.
const SAVE := "user://quack_campaign.cfg"
const TITLES := ["Обучение", "Переправа", "Разрывы между опорами", "Дальний пульт", "Скользкий поворот", "Водоотвод"]
const TASKS := ["Запиши путь Кряка. На повторе ты управляешь Шайбой.", "Запиши путь и успей к кнопке.", "Перепрыгни две опоры. Средний прыжок — по диагонали.", "Пульт за каналом. Запиши паузу до зелёного сигнала.", "На мокром повороте отпусти стрелку заранее.", "Пройди створки на зелёный. Шайбой перекрой струю."]
var current := 0
var last_completed := -1
var unlocked: int:
	get: return mini(last_completed+1,TITLES.size()-1)
var profile := ConfigFile.new()
var overlay: ColorRect
var toolbar := Control.new()
var playing := false
var changing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	if profile.load(SAVE) == OK:
		# Раньше просмотр примера тоже открывал выезд. Для новой цепочки
		# сохраняем именно победы. Старые ленты остаются в том же профиле.
		last_completed = clampi(int(profile.get_value("campaign","last_completed_from_tutorial",-1)),-1,TITLES.size()-1)
	current = unlocked
	add_child(toolbar)
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar.hide()
	var pause_button := make_button("Ⅱ",Rect2(943,13,43,38))
	pause_button.tooltip_text = "Пауза (Esc)"
	var menu_button := make_button("☰",Rect2(995,13,43,38))
	menu_button.tooltip_text = "Выйти в меню (M)"
	for b in [pause_button,menu_button]:
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size",22)
		toolbar.add_child(b)
	pause_button.pressed.connect(toggle_pause)
	menu_button.pressed.connect(go_menu)

func set_playing(value: bool) -> void:
	playing = value
	toolbar.visible = value

func make_button(caption: String, rect: Rect2) -> Button:
	var b := Button.new()
	b.text = caption
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size",16)
	for kind in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#243d40") if kind == "normal" else Color("#315951")
		if kind == "disabled":
			style.bg_color = Color("#192a2e")
		style.set_corner_radius_all(4)
		b.add_theme_stylebox_override(kind,style)
	return b

func _input(event: InputEvent) -> void:
	if playing and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			get_viewport().set_input_as_handled()
			go_menu()
		elif event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			toggle_pause()

func toggle_pause() -> void:
	if changing:
		return
	if is_instance_valid(overlay):
		resume_game()
		return
	get_tree().paused = true
	overlay = ColorRect.new()
	toolbar.hide()
	overlay.color = Color("#07161de8")
	overlay.size = Vector2(1056,428)
	add_child(overlay)
	var title := Label.new()
	title.position = Vector2(380,49)
	title.text = "Пауза"
	title.add_theme_font_size_override("font_size",34)
	overlay.add_child(title)
	var back := make_button("Продолжить",Rect2(380,121,296,48))
	var hint := make_button("Повторить подсказку",Rect2(380,182,296,48))
	var menu := make_button("Выйти в меню",Rect2(380,243,296,48))
	for b in [back,hint,menu]:
		overlay.add_child(b)
	back.pressed.connect(resume_game)
	hint.pressed.connect(repeat_hint)
	menu.pressed.connect(go_menu)
	var controls := Label.new()
	controls.position = Vector2(40,319)
	controls.size = Vector2(976,72)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.text = "WASD / стрелки — движение     ·     Пробел — запись и повтор     ·     E — буксир     ·     R — начать заново"
	var detail := "Подведи Кряка к Маячку и зацепи трос клавишей E. Вернись по нижнему мосту."
	if current==0:
		detail = "Tab на старте — посмотреть пример. Пробел во время показа — играть самому."
	elif current==2:
		detail = "На кромке жми пробел. Между опорами веди Кряка вправо и вниз."
	elif current==3:
		detail = "Жди зелёного огня перед мостом. При повторе сразу лети к пульту на дальнем берегу."
	elif current==4:
		detail = "Капля у моста означает скольжение. Белая черта показывает тормозной путь."
	elif current==5:
		detail = "На полосках можно остановиться. Створки повторяют ритм записи. На повторе Шайба держит вентиль."
	controls.text += "\n"+detail
	controls.add_theme_font_size_override("font_size",15)
	overlay.add_child(controls)
	back.grab_focus()

func repeat_hint() -> void:
	resume_game()
	get_tree().current_scene.get_node("Panel").repeat_hint()

func resume_game() -> void:
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
		overlay = null
	get_tree().paused = false
	toolbar.visible = playing

func go_to(id: int) -> void:
	if changing or id < 0 or id > unlocked:
		return
	current = id
	var path := "res://station.tscn" if id <= 1 else "res://expedition.tscn"
	switch_scene(path)

func go_menu() -> void:
	if playing and not changing:
		switch_scene("res://menu.tscn")

func switch_scene(path: String) -> void:
	changing = true
	resume_game()
	set_playing(false)
	get_tree().change_scene_to_file.call_deferred(path)
	await get_tree().scene_changed
	changing = false

func complete() -> void:
	if current == last_completed+1:
		last_completed = current
		save_profile()

func advance_mission() -> void:
	if current < TITLES.size()-1:
		go_to(current+1)
	else:
		go_menu()

func remember(slot: String, inputs: PackedVector2Array, jumps := PackedByteArray()) -> void:
	if not inputs.is_empty():
		profile.set_value("moves",slot,inputs.duplicate())
		if not jumps.is_empty():
			profile.set_value("moves",slot+"_jumps",jumps.duplicate())
		save_profile()

func recall_jumps(slot: String) -> PackedByteArray:
	var data = profile.get_value("moves",slot+"_jumps",PackedByteArray())
	return data.duplicate() if data is PackedByteArray else PackedByteArray()

func recall(slot: String) -> PackedVector2Array:
	var data = profile.get_value("moves",slot,PackedVector2Array())
	if data is PackedVector2Array and data.size() <= 300:
		return data.duplicate()
	return PackedVector2Array()

func save_profile() -> void:
	profile.set_value("campaign","last_completed_from_tutorial",last_completed)
	if profile.save(SAVE) != OK:
		push_warning("Не удалось сохранить прогресс выездов.")
