package oui

import "base:runtime"

Stacks :: struct {
	semantic_width: Stack(Size),
	semantic_height: Stack(Size),
	child_layout_axis: Stack(Axis),
	text_color: Stack(Color),
	background_color: Stack(Color),
	corner_radius: Stack(f32),
}

auto_pop_stacks :: proc() {
	stack_auto_pop(&state.stacks.semantic_width)
	stack_auto_pop(&state.stacks.semantic_height)
	stack_auto_pop(&state.stacks.child_layout_axis)
	stack_auto_pop(&state.stacks.text_color)
	stack_auto_pop(&state.stacks.background_color)
	stack_auto_pop(&state.stacks.corner_radius)
}

init_stacks :: proc() {
	stack_init(&state.stacks.semantic_width, pixels(800, 1))
	stack_init(&state.stacks.semantic_height, pixels(600, 1))
	stack_init(&state.stacks.child_layout_axis, Axis.X)
	stack_init(&state.stacks.text_color, Color{0, 0, 0, 1})
	stack_init(&state.stacks.background_color, Color{1, 1, 1, 1})
	stack_init(&state.stacks.corner_radius, 0)
}

//+semantic_width
semantic_width_set_next :: proc(v: Size) { stack_set_next(&state.stacks.semantic_width, v) }
semantic_width_push :: proc(v: Size) { stack_push(&state.stacks.semantic_width, v) }
semantic_width_pop :: proc() -> Size { return stack_pop(&state.stacks.semantic_width) }
semantic_width_top :: proc() -> Size { return stack_top(&state.stacks.semantic_width) }
@(deferred_in=_semantic_width_guard_end)
semantic_width_guard :: proc(v: Size, loc := #caller_location) { stack_push(&state.stacks.semantic_width, v) }
_semantic_width_guard_end :: proc(v: Size, loc: runtime.Source_Code_Location) {
	old := semantic_width_pop()
	assert(old == v, loc = loc)
}
//-semantic_width

//+semantic_height
semantic_height_set_next :: proc(v: Size) { stack_set_next(&state.stacks.semantic_height, v) }
semantic_height_push :: proc(v: Size) { stack_push(&state.stacks.semantic_height, v) }
semantic_height_pop :: proc() -> Size { return stack_pop(&state.stacks.semantic_height) }
semantic_height_top :: proc() -> Size { return stack_top(&state.stacks.semantic_height) }
@(deferred_in=_semantic_height_guard_end)
semantic_height_guard :: proc(v: Size, loc := #caller_location) { stack_push(&state.stacks.semantic_height, v) }
_semantic_height_guard_end :: proc(v: Size, loc: runtime.Source_Code_Location) {
	old := semantic_height_pop()
	assert(old == v, loc = loc)
}
//-semantic_height

//+child_layout_axis
child_layout_axis_set_next :: proc(v: Axis) { stack_set_next(&state.stacks.child_layout_axis, v) }
child_layout_axis_push :: proc(v: Axis) { stack_push(&state.stacks.child_layout_axis, v) }
child_layout_axis_pop :: proc() -> Axis { return stack_pop(&state.stacks.child_layout_axis) }
child_layout_axis_top :: proc() -> Axis { return stack_top(&state.stacks.child_layout_axis) }
@(deferred_in=_child_layout_axis_guard_end)
child_layout_axis_guard :: proc(v: Axis, loc := #caller_location) { stack_push(&state.stacks.child_layout_axis, v) }
_child_layout_axis_guard_end :: proc(v: Axis, loc: runtime.Source_Code_Location) {
	old := child_layout_axis_pop()
	assert(old == v, loc = loc)
}
//-child_layout_axis

//+text_color
text_color_set_next :: proc(v: Color) { stack_set_next(&state.stacks.text_color, v) }
text_color_push :: proc(v: Color) { stack_push(&state.stacks.text_color, v) }
text_color_pop :: proc() -> Color { return stack_pop(&state.stacks.text_color) }
text_color_top :: proc() -> Color { return stack_top(&state.stacks.text_color) }
@(deferred_in=_text_color_guard_end)
text_color_guard :: proc(v: Color, loc := #caller_location) { stack_push(&state.stacks.text_color, v) }
_text_color_guard_end :: proc(v: Color, loc: runtime.Source_Code_Location) {
	old := text_color_pop()
	assert(old == v, loc = loc)
}
//-text_color

//+background_color
background_color_set_next :: proc(v: Color) { stack_set_next(&state.stacks.background_color, v) }
background_color_push :: proc(v: Color) { stack_push(&state.stacks.background_color, v) }
background_color_pop :: proc() -> Color { return stack_pop(&state.stacks.background_color) }
background_color_top :: proc() -> Color { return stack_top(&state.stacks.background_color) }
@(deferred_in=_background_color_guard_end)
background_color_guard :: proc(v: Color, loc := #caller_location) { stack_push(&state.stacks.background_color, v) }
_background_color_guard_end :: proc(v: Color, loc: runtime.Source_Code_Location) {
	old := background_color_pop()
	assert(old == v, loc = loc)
}
//-background_color

//+corner_radius
corner_radius_set_next :: proc(v: f32) { stack_set_next(&state.stacks.corner_radius, v) }
corner_radius_push :: proc(v: f32) { stack_push(&state.stacks.corner_radius, v) }
corner_radius_pop :: proc() -> f32 { return stack_pop(&state.stacks.corner_radius) }
corner_radius_top :: proc() -> f32 { return stack_top(&state.stacks.corner_radius) }
@(deferred_in=_corner_radius_guard_end)
corner_radius_guard :: proc(v: f32, loc := #caller_location) { stack_push(&state.stacks.corner_radius, v) }
_corner_radius_guard_end :: proc(v: f32, loc: runtime.Source_Code_Location) {
	old := corner_radius_pop()
	assert(old == v, loc = loc)
}
//-corner_radius

