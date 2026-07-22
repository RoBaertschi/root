#+vet explicit-allocators
package oui

import "core:fmt"

button :: proc(name: string) -> Signal {
	semantic_width_set_next(text_content(1))
	semantic_height_set_next(text_content(1))
	button := box_make(
		{ .Draw_Background, .Clickable, .Draw_Hover, .Draw_Active, .Draw_Text },
		name
	)

	return signal_from_box(button)
}

buttonf :: proc(format: string, args: ..any) -> Signal {
	return button(fmt.aprintf(format, ..args, allocator = build_allocator()))
}

label :: proc(text: string) {
	label := box_make(
		{ .Draw_Text },
		text,
	)
}

labelf :: proc(format: string, args: ..any) {
	semantic_width_set_next(text_content(1))
	semantic_height_set_next(text_content(1))
	label(fmt.aprintf(format, ..args, allocator = build_allocator()))
}

spacer :: proc(a: Axis, size: Size) {
	semantic_size_set_next(a, size)
	semantic_size_set_next(axis_flip(a), pixels(0, 0))
	box_make({}, "")
}

// Used like `if center()`
@(deferred_in=_center_end)
center :: proc(a: Axis) -> bool {
	child_layout_axis_set_next(a)
	container := box_make({}, "")
	push_parent(container)

	spacer(a, percent_of_parent(100, 0))

	return true
}

_center_end :: proc(a: Axis) {
	spacer(a, percent_of_parent(100, 0))

	pop_parent()
}
