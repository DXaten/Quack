extends Node2D
## Примитивы для обеих частей изображения. Координаты заданы в пикселях сцены.

const FG := Color("#f1f3e3")
const MUTED := Color("#a2b6b3")
const AQUA := Color("#77e8d0")
const AMBER := Color("#ffd05f")
const RED := Color("#ff997b")
const DARK := Color("#172b30")
var sans := SystemFont.new()
var bold := SystemFont.new()
var mono := SystemFont.new()

func _ready() -> void:
	sans.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial"])
	bold.font_names = sans.font_names
	bold.font_weight = 700
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New"])

func label(x: float, y: float, words: String, size: int, color: Color, font: Font = null) -> void:
	draw_string(sans if font == null else font, Vector2(x,y), words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x,y,w,h), color)

func line(x1: float, y1: float, x2: float, y2: float, color: Color, width := 1.0) -> void:
	draw_line(Vector2(x1,y1), Vector2(x2,y2), color, width, true)

func circle(x: float, y: float, rad: float, color: Color) -> void:
	draw_circle(Vector2(x,y), rad, color, true, -1, true)

func ring(center: Vector2, radius: float, color: Color, width := 1.0) -> void:
	draw_arc(center, radius, 0, TAU, 72, color, width, true)

func poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)
