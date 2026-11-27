class_name SportsMenu
extends Screen
## Sport list on the left, preview on the right.

var buttons: Array[PillButton] = []
var back_btn: PillButton
var _preview := "Bowling"
var card: PreviewCard


func _init() -> void:
	super()
	var names := [["Bowling", true], ["Tennis", false], ["Golf", false], ["Baseball", false]]
	for n in names:
		var b := PillButton.new(n[0], Vector2(330, 84))
		b.enabled = n[1]
		b.badge = "" if n[1] else "Soon"
		b.font_size = 32
		if n[1]:
			b.pressed.connect(func(): done.emit("bowling"))
		add_child(b)
		buttons.append(b)
	card = PreviewCard.new(false, "Bowling  ·  1 player  ·  10 frames")
	add_child(card)
	back_btn = PillButton.new("Back", Vector2(170, 66))
	back_btn.font_size = 26
	back_btn.pressed.connect(func(): done.emit("back"))
	add_child(back_btn)


func _process(delta: float) -> void:
	super(delta)
	for i in buttons.size():
		buttons[i].position = Vector2(70, 170 + i * 108)
		if buttons[i].hovered:
			_preview = buttons[i].text
	back_btn.position = Vector2(70, size.y - 100)
	card.position = Vector2(470, 160)
	card.size = Vector2(size.x - 540, size.y - 300)
	var soon := _preview != "Bowling"
	card.caption = (_preview + "  ·  coming soon") if soon else "Bowling  ·  1 player  ·  10 frames"
	card.modulate = Color(0.78, 0.78, 0.8) if soon else Color.WHITE
	card.hovered = buttons[0].hovered


func _draw() -> void:
	draw_stripes()
	# header strip
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 110)), UI.WHITE)
	draw_rect(Rect2(Vector2(0, 110), Vector2(size.x, 5)), UI.BLUE)
	var f := UI.bold()
	draw_string(f, Vector2(70, 74), "Choose a sport", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, UI.INK)
	UI.draw_logo(self, Vector2(size.x - 210, 70), 0.42)
	# shadow under the preview card
	var pr := Rect2(Vector2(470, 160), Vector2(size.x - 540, size.y - 300))
	draw_style_box(UI.panel_style(Color(0, 0, 0, 0.10), Color(0, 0, 0, 0), 34, 0), pr.grow(4).grow_side(SIDE_BOTTOM, 10))
