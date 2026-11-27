class_name UI
extends RefCounted
## Shared look: soft greys, white, sky blue, rounded everything.

const BG := Color("ececec")
const BG_LINE := Color("e3e3e3")
const PANEL := Color("f8f8f8")
const BORDER := Color("cfcfcf")
const BLUE := Color("31b8e8")
const BLUE_DARK := Color("1a98c9")
const BLUE_SOFT := Color("bfe9f8")
const INK := Color("5b5b5b")
const INK_DARK := Color("3c3c3c")
const INK_SOFT := Color("9a9a9a")
const WHITE := Color.WHITE

static var _bold: Font
static var _regular: Font


static func bold() -> Font:
	if _bold == null:
		_bold = load("res://fonts/Rounded-ExtraBold.ttf")
	return _bold


static func regular() -> Font:
	if _regular == null:
		_regular = load("res://fonts/Rounded-Medium.ttf")
	return _regular


static func label(text: String, size: int, color := INK, is_bold := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", bold() if is_bold else regular())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel_style(bg := PANEL, border := BORDER, radius := 26, border_w := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.08)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing_size = 1.2
	return sb


## Light grey background with fine horizontal pinstripes.
static func stripes_texture() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(BG)
	for x in 8:
		img.set_pixel(x, 0, BG_LINE)
		img.set_pixel(x, 4, BG_LINE)
	return ImageTexture.create_from_image(img)


static func stripes_background() -> TextureRect:
	var t := TextureRect.new()
	t.texture = stripes_texture()
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Draws the VectorSports logo centred on `center` (used by several screens).
static func draw_logo(ci: CanvasItem, center: Vector2, scale := 1.0) -> void:
	var f := bold()
	var big := int(96 * scale)
	var small := int(40 * scale)
	var w1 := f.get_string_size("VECTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	var icon_w := 86.0 * scale
	var total := icon_w + 14.0 * scale + w1
	var x0 := center.x - total * 0.5
	# chevron badge
	var c := Vector2(x0 + icon_w * 0.5, center.y - 30 * scale)
	ci.draw_circle(c, 43 * scale, BLUE)
	ci.draw_circle(c, 36 * scale, WHITE)
	var pts := PackedVector2Array([c + Vector2(-20, -16) * scale, c + Vector2(0, 18) * scale, c + Vector2(20, -16) * scale])
	ci.draw_polyline(pts, BLUE, 10 * scale, true)
	# wordmark
	var base := Vector2(x0 + icon_w + 14 * scale, center.y)
	ci.draw_string(f, base + Vector2(3, 4) * scale, "VECTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(0, 0, 0, 0.07))
	ci.draw_string(f, base, "VECTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, big, BLUE)
	var sp := "S  P  O  R  T  S"
	var w2 := f.get_string_size(sp, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	ci.draw_string(f, Vector2(base.x + w1 - w2, center.y + 46 * scale), sp, HORIZONTAL_ALIGNMENT_LEFT, -1, small, INK)
