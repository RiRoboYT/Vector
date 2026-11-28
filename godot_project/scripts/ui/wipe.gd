class_name Wipe
extends Control
## Screen transition: a slanted blue panel with a white leading stripe sweeps
## across to cover the screen, then carries on to reveal the next one.
## progress 0 = clear, 1 = covered, 2 = cleared again.

var progress := 0.0:
	set(v):
		progress = v
		visible = progress > 0.001 and progress < 1.999
		queue_redraw()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	var w := size.x
	var h := size.y
	var slant := h * 0.35
	var span := w + slant
	# leading and trailing edges move left -> right
	var lead: float
	var trail: float
	if progress <= 1.0:
		lead = -slant + span * progress
		trail = -slant - 10.0
	else:
		lead = w + slant + 10.0
		trail = -slant + span * (progress - 1.0)
	_band(trail, lead, Color("31b8e8"), slant, h)
	_band(lead - 26.0, lead, Color.WHITE, slant, h)
	_band(lead - 40.0, lead - 30.0, Color("bfe9f8"), slant, h)
	if progress > 0.6 and progress < 1.4:
		var a := 1.0 - absf(progress - 1.0) / 0.4
		UI.draw_logo(self, Vector2(w * 0.5, h * 0.5), 0.8)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.19, 0.72, 0.91, 1.0 - a))


func _band(x0: float, x1: float, c: Color, slant: float, h: float) -> void:
	if x1 <= x0:
		return
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0 + slant, 0), Vector2(x1 + slant, 0), Vector2(x1, h), Vector2(x0, h)]), c)
