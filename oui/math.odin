package oui

rect_contains :: proc(rect: Rect, pos: [2]f32) -> bool {
	return (rect.pos.x <= pos.x && pos.x < (rect.pos.x + rect.size.x)) && (rect.pos.y <= pos.y && pos.y < (rect.pos.y + rect.size.y))
}

rect_intersection :: proc(a, b: Rect) -> (rect: Rect) {
	a_right := a.pos.x + a.size.x
	a_bottom := a.pos.y + a.size.y
	b_right := b.pos.x + b.size.x
	b_bottom := b.pos.y + b.size.y
	rect = {
		pos = {
			max(a.pos.x, b.pos.x),
			max(a.pos.y, b.pos.y),
		},
	}

	rect.size = {
		min(a_right, b_right) - rect.pos.x,
		min(a_bottom, b_bottom) - rect.pos.y,
	}

	return
}
