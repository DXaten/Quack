extends RefCounted
## Геометрия общая для правил и рисунка. Если перенести кнопку здесь,
## изменятся сразу и её изображение, и зона срабатывания.

const FLOOR := Rect2(42, 114, 1036, 397)
const WATER_LEFT := 477.0
const WATER_RIGHT := 666.0
const BRIDGE_Y := 335.0
const BRIDGE_HALF := 32.0
const FOOT_RADIUS := 10.0
const DUCK_START := Vector2(330, BRIDGE_Y)
const DRONE_START := Vector2(151, 211)
const SWITCH := Vector2(407, 211)
const BEACON := Vector2(890, BRIDGE_Y)
const EVAC_PAD := Vector2(185,453)
const SWITCH_RADIUS := 26.0
const RESCUE_RADIUS := 34.0
const DUCK_SPEED := 172.0
const DRONE_SPEED := 164.0
const SECONDS := 5.0

static func return_ramp(left: float, right: float) -> Rect2:
	return Rect2(left-14,419,right-left+28,67)

static func on_canal(point: Vector2) -> bool:
	return point.x + FOOT_RADIUS > WATER_LEFT and point.x - FOOT_RADIUS < WATER_RIGHT

static func walkable(point: Vector2) -> bool:
	return not on_canal(point) or absf(point.y - BRIDGE_Y) <= BRIDGE_HALF - FOOT_RADIUS

static func walk(from: Vector2, step: Vector2) -> Vector2:
	# Обрабатываем оси отдельно: у ограждения утка скользит вдоль берега.
	var area := FLOOR.grow(-18)
	var result := from
	var x_move := Vector2(clampf(from.x + step.x, area.position.x, area.end.x), from.y)
	if walkable(x_move):
		result = x_move
	var y_move := Vector2(result.x, clampf(result.y + step.y, area.position.y, area.end.y))
	if walkable(y_move):
		result = y_move
	return result
