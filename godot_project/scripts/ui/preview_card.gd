class_name PreviewCard
extends Control
## Rounded, glossy card showing a live LanePreview, with an optional logo
## banner on top and a caption bar at the bottom. Highlights on hover.

const MASK_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(560.0, 330.0);
uniform float radius = 28.0;
void fragment() {
	vec2 p = UV * rect_size;
	vec2 q = abs(p - rect_size * 0.5) - (rect_size * 0.5 - vec2(radius));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	vec4 c = texture(TEXTURE, UV);
	c.a *= clamp(0.5 - d, 0.0, 1.0);
	COLOR = c;
}
"""

var show_logo := false
var caption := ""
var hovered := false
var radius := 28.0

var _viewport: LanePreview
var _view: TextureRect
var _overlay: Overlay
var _mat: ShaderMaterial


func _init(p_logo := false, p_caption := "") -> void:
	show_logo = p_logo
	caption = p_caption
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = LanePreview.new()
	add_child(_viewport)
	_view = TextureRect.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	var sh := Shader.new()
	sh.code = MASK_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_view.material = _mat
	add_child(_view)
	_overlay = Overlay.new()
	_overlay.card = self
	add_child(_overlay)


func _ready() -> void:
	_view.texture = _viewport.get_texture()


func _process(_d: float) -> void:
	_view.position = Vector2.ZERO
	_view.size = size
	_overlay.position = Vector2.ZERO
	_overlay.size = size
	_mat.set_shader_parameter("rect_size", size)
	# render at the card's aspect ratio (and 1.5x for crisp TVs)
	var want := Vector2i(maxi(64, int(size.x * 1.5)), maxi(64, int(size.y * 1.5)))
	if _viewport.size != want:
		_viewport.size = want
	_mat.set_shader_parameter("radius", radius)
	_overlay.queue_redraw()


class Overlay:
	extends Control
	var card: PreviewCard

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rad := int(card.radius)
		# glossy highlight across the top
		var gloss := StyleBoxFlat.new()
		gloss.bg_color = Color(1, 1, 1, 0.10)
		gloss.corner_radius_top_left = rad
		gloss.corner_radius_top_right = rad
		draw_style_box(gloss, Rect2(Vector2(4, 4), Vector2(size.x - 8, size.y * 0.32)))
		if card.show_logo:
			# logo on a clean white badge
			var badge := Rect2(Vector2(size.x * 0.5 - 190, 22), Vector2(380, 108))
			var sb := UI.panel_style(Color(1, 1, 1, 0.94), Color(1, 1, 1, 0), 30, 0)
			draw_style_box(sb, badge)
			UI.draw_logo(self, Vector2(size.x * 0.5, 80), 0.6)
		if card.caption != "":
			var bar := Rect2(Vector2(0, size.y - 58), Vector2(size.x, 58))
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = Color(1, 1, 1, 0.88)
			sb2.corner_radius_bottom_left = rad
			sb2.corner_radius_bottom_right = rad
			draw_style_box(sb2, bar)
			draw_string(UI.bold(), Vector2(24, size.y - 20), card.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.INK_DARK)
		# border
		var border := StyleBoxFlat.new()
		border.draw_center = false
		border.border_color = UI.BLUE if card.hovered else Color("d0d6dc")
		border.set_border_width_all(6 if card.hovered else 4)
		border.set_corner_radius_all(rad)
		border.anti_aliasing_size = 1.0
		draw_style_box(border, r)
		if card.hovered:
			var glow := StyleBoxFlat.new()
			glow.draw_center = false
			glow.border_color = Color(UI.BLUE, 0.25)
			glow.set_border_width_all(6)
			glow.set_corner_radius_all(rad + 6)
			draw_style_box(glow, r.grow(6))
