class_name LoadingScreen
extends Screen
## Short "get ready" card before a match: sport name, a tip and a bouncing ball.

var sport := "Bowling"
var duration := 1.8
var _tip := ""

const TIPS := {
	"Bowling": ["Swing straight and smooth – the speed of your swing is the speed of the ball.",
		"Twist your wrist as you let go of B to hook the ball into the pocket.",
		"Aim between the 1 and 3 pins (or 1 and 2 if you're left-handed) for strikes."],
	"Cricket": ["Point the phone at the floor in your stance – the bat copies every move.",
		"Swing on time to keep the ball down. Too early pops it up!",
		"Stop the meter in the gold for your fastest, straightest delivery."],
	"Tennis": ["Swing early to go cross-court, late to go down the line.",
		"Finish your swing high for topspin, low for slice.",
		"Toss with B, then swing as the ball reaches the very top for a big serve."],
}


func _init() -> void:
	super()
	wants_pointer = false
	phone_hint = "Get ready!"


func _ready() -> void:
	var tips: Array = TIPS.get(sport, ["Have fun!"])
	_tip = tips[randi() % tips.size()]


func _process(delta: float) -> void:
	super(delta)
	if _t >= duration:
		set_process(false)
		done.emit("ok")


func _draw() -> void:
	draw_stripes()
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	var card := Rect2(Vector2(size.x * 0.5 - 420, size.y * 0.5 - 220), Vector2(840, 400))
	draw_style_box(UI.panel_style(Color(1, 1, 1, 0.96), UI.BLUE, 36, 4), card)
	var f := UI.bold()
	var title := sport.to_upper()
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	draw_string(f, Vector2(c.x - tw * 0.5, card.position.y + 100), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, UI.BLUE)
	# bouncing ball with a squash at the bottom
	var ph := fmod(_t * 1.6, 1.0)
	var hgt := 4.0 * ph * (1.0 - ph)
	var by := card.position.y + 250 - hgt * 80.0
	var squash := 1.0 - (1.0 - smoothstep(0.0, 0.12, hgt)) * 0.25
	var col := {"Bowling": Color("2b6cb0"), "Cricket": Color("c0392b"), "Tennis": Color("d9f23c")}.get(sport, UI.BLUE) as Color
	draw_set_transform(Vector2(c.x, by), 0.0, Vector2(1.0 / squash, squash))
	draw_circle(Vector2.ZERO, 26, col)
	draw_arc(Vector2.ZERO, 26, 0, TAU, 32, col.darkened(0.3), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(c.x, card.position.y + 280), 22.0 * (0.6 + 0.4 * (1.0 - hgt)), Color(0, 0, 0, 0.08))
	# tip
	var reg := UI.regular()
	draw_string(f, Vector2(card.position.x + 50, card.position.y + 330), "TIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffb020"))
	draw_multiline_string(reg, Vector2(card.position.x + 110, card.position.y + 330), _tip, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 160, 22, 2, UI.INK_DARK)
	# progress bar
	var pr := Rect2(Vector2(card.position.x + 50, card.end.y - 36), Vector2(card.size.x - 100, 10))
	draw_style_box(UI.panel_style(Color("e8edf2"), Color(0, 0, 0, 0), 5, 0), pr)
	var k := clampf(_t / duration, 0.0, 1.0)
	draw_style_box(UI.panel_style(UI.BLUE, Color(0, 0, 0, 0), 5, 0), Rect2(pr.position, Vector2(pr.size.x * ease(k, 0.6), pr.size.y)))
