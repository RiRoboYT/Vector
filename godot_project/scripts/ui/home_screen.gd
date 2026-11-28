class_name HomeScreen
extends Screen
## Channel-style home: pinstripe background with one large VectorSports tile.

var tile: PreviewCard
var _hover := false
var _hover_s := 1.0
var connected := false
var exit_btn: PillButton


func _init() -> void:
	super()
	tile = PreviewCard.new(true)
	add_child(tile)
	exit_btn = PillButton.new("Exit", Vector2(150, 64))
	exit_btn.font_size = 26
	exit_btn.pressed.connect(func(): done.emit("exit"))
	add_child(exit_btn)


func _process(delta: float) -> void:
	super(delta)
	var tsz := Vector2(620, 360)
	tile.size = tsz
	tile.position = Vector2(size.x * 0.5 - tsz.x * 0.5, size.y * 0.42 - tsz.y * 0.5)
	tile.pivot_offset = tsz * 0.5
	exit_btn.position = Vector2(40, size.y - 100)
	var was := _hover
	_hover = Pad.pointer_visible and tile.get_global_rect().has_point(Pad.pointer)
	if _hover and not was:
		Sfx.click(0.45, 1.25)
	_hover_s = lerpf(_hover_s, 1.04 if _hover else 1.0, 1.0 - exp(-delta * 14.0))
	tile.scale = Vector2.ONE * _hover_s
	tile.hovered = _hover
	if _hover and Pad.just_pressed(Pad.A):
		Sfx.click()
		done.emit("sports")


func _draw() -> void:
	draw_stripes()
	var r := tile.get_rect()
	var c := r.get_center()
	r = Rect2(c - r.size * 0.5 * _hover_s, r.size * _hover_s)
	# soft drop shadow under the card
	var sh := UI.panel_style(Color(0, 0, 0, 0.10), Color(0, 0, 0, 0), 40, 0)
	draw_style_box(sh, r.grow(4).grow_side(SIDE_BOTTOM, 10))
	# footer
	var fy := size.y - 120
	draw_rect(Rect2(Vector2(0, fy), Vector2(size.x, 120)), Color("f4f4f4"))
	draw_line(Vector2(0, fy), Vector2(size.x, fy), UI.BLUE, 4.0)
	var f := UI.bold()
	var status := "Phone connected" if connected else "Scan the QR code to connect your phone"
	var ts := f.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	var sx := size.x * 0.5 - ts.x * 0.5
	draw_circle(Vector2(sx - 22, fy + 58), 9, Color("2fbf5b") if connected else Color("f1a417"))
	draw_string(f, Vector2(sx, fy + 67), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.INK)
