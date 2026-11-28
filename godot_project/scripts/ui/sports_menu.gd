class_name SportsMenu
extends Screen
## Sport list on the left, preview on the right.

var buttons: Array[PillButton] = []
var back_btn: PillButton
var _preview := "Bowling"
var card: PreviewCard
var cricket_card: PreviewCard
var tennis_card: PreviewCard


func _init() -> void:
	super()
	var names := [["Bowling", true], ["Cricket", true], ["Tennis", true], ["Golf", false], ["Baseball", false]]
	for n in names:
		var b := PillButton.new(n[0], Vector2(330, 76))
		b.enabled = n[1]
		b.badge = "" if n[1] else "Soon"
		b.font_size = 30
		if n[1]:
			var sport := str(n[0]).to_lower()
			b.pressed.connect(func(): done.emit(sport))
		add_child(b)
		buttons.append(b)
	card = PreviewCard.new(false, "Bowling  ·  1–8 players  ·  10 frames")
	add_child(card)
	cricket_card = PreviewCard.new(false, "Cricket  ·  1–8 players  ·  Super Over / 2 / 5 overs", "cricket")
	add_child(cricket_card)
	tennis_card = PreviewCard.new(false, "Tennis  ·  1–4 players  ·  Doubles  ·  1 / 3 / 5 games", "tennis")
	add_child(tennis_card)
	back_btn = PillButton.new("Back", Vector2(170, 66))
	back_btn.font_size = 26
	back_btn.pressed.connect(func(): done.emit("back"))
	add_child(back_btn)


func _process(delta: float) -> void:
	super(delta)
	for i in buttons.size():
		buttons[i].position = Vector2(70, 150 + i * 92)
		if buttons[i].hovered:
			_preview = buttons[i].text
	back_btn.position = Vector2(70, size.y - 100)
	for c in [card, cricket_card, tennis_card]:
		c.position = Vector2(470, 160)
		c.size = Vector2(size.x - 540, size.y - 300)
	var is_cricket := _preview == "Cricket"
	var is_tennis := _preview == "Tennis"
	cricket_card.visible = is_cricket
	tennis_card.visible = is_tennis
	card.visible = not is_cricket and not is_tennis
	var soon := _preview != "Bowling" and _preview != "Cricket" and _preview != "Tennis"
	card.caption = (_preview + "  ·  coming soon") if soon else "Bowling  ·  1–8 players  ·  10 frames"
	card.modulate = Color(0.78, 0.78, 0.8) if soon else Color.WHITE
	card.hovered = buttons[0].hovered
	cricket_card.hovered = buttons[1].hovered
	tennis_card.hovered = buttons[2].hovered


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
