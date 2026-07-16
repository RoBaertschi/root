package root_base

import "base:intrinsics"

Rect :: struct($T: typeid) where intrinsics.type_is_comparable(T) {
	pos:  [2]T,
	size: [2]T,
}

rect_cast :: proc(rect: Rect($FROM), $TO: typeid) -> Rect(TO) {
	return {
		pos  = { TO(rect.pos.x),  TO(rect.pos.y) },
		size = { TO(rect.size.x), TO(rect.size.y) },
	}
}

rect_contains :: proc(rect: Rect($T), pos: [2]T) -> bool {
	return (rect.pos.x <= pos.x && pos.x < (rect.pos.x + rect.size.x)) && (rect.pos.y <= pos.y && pos.y < (rect.pos.y + rect.size.y))
}

rect_intersection :: proc(a, b: Rect($T)) -> (rect: Rect(T)) {
	a_right  := a.pos.x + a.size.x
	a_bottom := a.pos.y + a.size.y
	b_right  := b.pos.x + b.size.x
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
