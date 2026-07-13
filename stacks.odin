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

auto_pop_stacks :: proc(c: ^Context) {
	stack_auto_pop(&c.stacks.semantic_width)
	stack_auto_pop(&c.stacks.semantic_height)
	stack_auto_pop(&c.stacks.child_layout_axis)
	stack_auto_pop(&c.stacks.text_color)
	stack_auto_pop(&c.stacks.background_color)
	stack_auto_pop(&c.stacks.corner_radius)
}

init_stacks :: proc(c: ^Context) {
	stack_init(&c.stacks.semantic_width, pixels(800, 1), _context_curr_allocator(c))
	stack_init(&c.stacks.semantic_height, pixels(600, 1), _context_curr_allocator(c))
	stack_init(&c.stacks.child_layout_axis, Axis.X, _context_curr_allocator(c))
	stack_init(&c.stacks.text_color, Color{0, 0, 0, 255}, _context_curr_allocator(c))
	stack_init(&c.stacks.background_color, Color{255, 255, 255, 255}, _context_curr_allocator(c))
	stack_init(&c.stacks.corner_radius, 0, _context_curr_allocator(c))
}

//+semantic_width
semantic_width_set_next :: proc(c: ^Context, v: Size) { stack_set_next(&c.stacks.semantic_width, v, _context_curr_allocator(c)) }
semantic_width_push :: proc(c: ^Context, v: Size) { stack_push(&c.stacks.semantic_width, v, _context_curr_allocator(c)) }
semantic_width_pop :: proc(c: ^Context) -> Size { return stack_pop(&c.stacks.semantic_width) }
semantic_width_top :: proc(c: ^Context) -> Size { return stack_top(&c.stacks.semantic_width) }
@(deferred_in=_semantic_width_guard_end)
semantic_width_guard :: proc(c: ^Context, v: Size, loc := #caller_location) { stack_push(&c.stacks.semantic_width, v, _context_curr_allocator(c)) }
_semantic_width_guard_end :: proc(c: ^Context, v: Size, loc: runtime.Source_Code_Location) {
	old := semantic_width_pop(c)
	assert(old == v, loc = loc)
}
//-semantic_width

//+semantic_height
semantic_height_set_next :: proc(c: ^Context, v: Size) { stack_set_next(&c.stacks.semantic_height, v, _context_curr_allocator(c)) }
semantic_height_push :: proc(c: ^Context, v: Size) { stack_push(&c.stacks.semantic_height, v, _context_curr_allocator(c)) }
semantic_height_pop :: proc(c: ^Context) -> Size { return stack_pop(&c.stacks.semantic_height) }
semantic_height_top :: proc(c: ^Context) -> Size { return stack_top(&c.stacks.semantic_height) }
@(deferred_in=_semantic_height_guard_end)
semantic_height_guard :: proc(c: ^Context, v: Size, loc := #caller_location) { stack_push(&c.stacks.semantic_height, v, _context_curr_allocator(c)) }
_semantic_height_guard_end :: proc(c: ^Context, v: Size, loc: runtime.Source_Code_Location) {
	old := semantic_height_pop(c)
	assert(old == v, loc = loc)
}
//-semantic_height

//+child_layout_axis
child_layout_axis_set_next :: proc(c: ^Context, v: Axis) { stack_set_next(&c.stacks.child_layout_axis, v, _context_curr_allocator(c)) }
child_layout_axis_push :: proc(c: ^Context, v: Axis) { stack_push(&c.stacks.child_layout_axis, v, _context_curr_allocator(c)) }
child_layout_axis_pop :: proc(c: ^Context) -> Axis { return stack_pop(&c.stacks.child_layout_axis) }
child_layout_axis_top :: proc(c: ^Context) -> Axis { return stack_top(&c.stacks.child_layout_axis) }
@(deferred_in=_child_layout_axis_guard_end)
child_layout_axis_guard :: proc(c: ^Context, v: Axis, loc := #caller_location) { stack_push(&c.stacks.child_layout_axis, v, _context_curr_allocator(c)) }
_child_layout_axis_guard_end :: proc(c: ^Context, v: Axis, loc: runtime.Source_Code_Location) {
	old := child_layout_axis_pop(c)
	assert(old == v, loc = loc)
}
//-child_layout_axis

//+text_color
text_color_set_next :: proc(c: ^Context, v: Color) { stack_set_next(&c.stacks.text_color, v, _context_curr_allocator(c)) }
text_color_push :: proc(c: ^Context, v: Color) { stack_push(&c.stacks.text_color, v, _context_curr_allocator(c)) }
text_color_pop :: proc(c: ^Context) -> Color { return stack_pop(&c.stacks.text_color) }
text_color_top :: proc(c: ^Context) -> Color { return stack_top(&c.stacks.text_color) }
@(deferred_in=_text_color_guard_end)
text_color_guard :: proc(c: ^Context, v: Color, loc := #caller_location) { stack_push(&c.stacks.text_color, v, _context_curr_allocator(c)) }
_text_color_guard_end :: proc(c: ^Context, v: Color, loc: runtime.Source_Code_Location) {
	old := text_color_pop(c)
	assert(old == v, loc = loc)
}
//-text_color

//+background_color
background_color_set_next :: proc(c: ^Context, v: Color) { stack_set_next(&c.stacks.background_color, v, _context_curr_allocator(c)) }
background_color_push :: proc(c: ^Context, v: Color) { stack_push(&c.stacks.background_color, v, _context_curr_allocator(c)) }
background_color_pop :: proc(c: ^Context) -> Color { return stack_pop(&c.stacks.background_color) }
background_color_top :: proc(c: ^Context) -> Color { return stack_top(&c.stacks.background_color) }
@(deferred_in=_background_color_guard_end)
background_color_guard :: proc(c: ^Context, v: Color, loc := #caller_location) { stack_push(&c.stacks.background_color, v, _context_curr_allocator(c)) }
_background_color_guard_end :: proc(c: ^Context, v: Color, loc: runtime.Source_Code_Location) {
	old := background_color_pop(c)
	assert(old == v, loc = loc)
}
//-background_color

//+corner_radius
corner_radius_set_next :: proc(c: ^Context, v: f32) { stack_set_next(&c.stacks.corner_radius, v, _context_curr_allocator(c)) }
corner_radius_push :: proc(c: ^Context, v: f32) { stack_push(&c.stacks.corner_radius, v, _context_curr_allocator(c)) }
corner_radius_pop :: proc(c: ^Context) -> f32 { return stack_pop(&c.stacks.corner_radius) }
corner_radius_top :: proc(c: ^Context) -> f32 { return stack_top(&c.stacks.corner_radius) }
@(deferred_in=_corner_radius_guard_end)
corner_radius_guard :: proc(c: ^Context, v: f32, loc := #caller_location) { stack_push(&c.stacks.corner_radius, v, _context_curr_allocator(c)) }
_corner_radius_guard_end :: proc(c: ^Context, v: f32, loc: runtime.Source_Code_Location) {
	old := corner_radius_pop(c)
	assert(old == v, loc = loc)
}
//-corner_radius

