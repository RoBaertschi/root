package oui

import "base:runtime"
import F "../font"

Stacks :: struct {
	semantic_width: Stack(Size),
	semantic_height: Stack(Size),
	child_layout_axis: Stack(Axis),
	fixed_x: Stack(f32),
	fixed_y: Stack(f32),
	text_color: Stack(Color),
	border_color: Stack(Color),
	background_color: Stack(Color),
	border_thickness: Stack(f32),
	corner_radius: Stack(f32),
	font_size: Stack(u16),
	font: Stack(F.ID),
}

auto_pop_stacks :: proc() {
	stack_auto_pop(&state.stacks.semantic_width)
	stack_auto_pop(&state.stacks.semantic_height)
	stack_auto_pop(&state.stacks.child_layout_axis)
	stack_auto_pop(&state.stacks.fixed_x)
	stack_auto_pop(&state.stacks.fixed_y)
	stack_auto_pop(&state.stacks.text_color)
	stack_auto_pop(&state.stacks.border_color)
	stack_auto_pop(&state.stacks.background_color)
	stack_auto_pop(&state.stacks.border_thickness)
	stack_auto_pop(&state.stacks.corner_radius)
	stack_auto_pop(&state.stacks.font_size)
	stack_auto_pop(&state.stacks.font)
}

init_stacks :: proc() {
	stack_init(&state.stacks.semantic_width, pixels(800, 1))
	stack_init(&state.stacks.semantic_height, pixels(600, 1))
	stack_init(&state.stacks.child_layout_axis, Axis.X)
	stack_init(&state.stacks.fixed_x, 0)
	stack_init(&state.stacks.fixed_y, 0)
	stack_init(&state.stacks.text_color, Color{0, 0, 0, 1})
	stack_init(&state.stacks.border_color, Color{1, 1, 1, 1})
	stack_init(&state.stacks.background_color, Color{1, 1, 1, 1})
	stack_init(&state.stacks.border_thickness, 1)
	stack_init(&state.stacks.corner_radius, 0)
	stack_init(&state.stacks.font_size, 16)
	stack_init(&state.stacks.font, F.DEFAULT_ID)
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

//+fixed_x
fixed_x_set_next :: proc(v: f32) { stack_set_next(&state.stacks.fixed_x, v) }
fixed_x_push :: proc(v: f32) { stack_push(&state.stacks.fixed_x, v) }
fixed_x_pop :: proc() -> f32 { return stack_pop(&state.stacks.fixed_x) }
fixed_x_top :: proc() -> f32 { return stack_top(&state.stacks.fixed_x) }
@(deferred_in=_fixed_x_guard_end)
fixed_x_guard :: proc(v: f32, loc := #caller_location) { stack_push(&state.stacks.fixed_x, v) }
_fixed_x_guard_end :: proc(v: f32, loc: runtime.Source_Code_Location) {
	old := fixed_x_pop()
	assert(old == v, loc = loc)
}
//-fixed_x

//+fixed_y
fixed_y_set_next :: proc(v: f32) { stack_set_next(&state.stacks.fixed_y, v) }
fixed_y_push :: proc(v: f32) { stack_push(&state.stacks.fixed_y, v) }
fixed_y_pop :: proc() -> f32 { return stack_pop(&state.stacks.fixed_y) }
fixed_y_top :: proc() -> f32 { return stack_top(&state.stacks.fixed_y) }
@(deferred_in=_fixed_y_guard_end)
fixed_y_guard :: proc(v: f32, loc := #caller_location) { stack_push(&state.stacks.fixed_y, v) }
_fixed_y_guard_end :: proc(v: f32, loc: runtime.Source_Code_Location) {
	old := fixed_y_pop()
	assert(old == v, loc = loc)
}
//-fixed_y

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

//+border_color
border_color_set_next :: proc(v: Color) { stack_set_next(&state.stacks.border_color, v) }
border_color_push :: proc(v: Color) { stack_push(&state.stacks.border_color, v) }
border_color_pop :: proc() -> Color { return stack_pop(&state.stacks.border_color) }
border_color_top :: proc() -> Color { return stack_top(&state.stacks.border_color) }
@(deferred_in=_border_color_guard_end)
border_color_guard :: proc(v: Color, loc := #caller_location) { stack_push(&state.stacks.border_color, v) }
_border_color_guard_end :: proc(v: Color, loc: runtime.Source_Code_Location) {
	old := border_color_pop()
	assert(old == v, loc = loc)
}
//-border_color

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

//+border_thickness
border_thickness_set_next :: proc(v: f32) { stack_set_next(&state.stacks.border_thickness, v) }
border_thickness_push :: proc(v: f32) { stack_push(&state.stacks.border_thickness, v) }
border_thickness_pop :: proc() -> f32 { return stack_pop(&state.stacks.border_thickness) }
border_thickness_top :: proc() -> f32 { return stack_top(&state.stacks.border_thickness) }
@(deferred_in=_border_thickness_guard_end)
border_thickness_guard :: proc(v: f32, loc := #caller_location) { stack_push(&state.stacks.border_thickness, v) }
_border_thickness_guard_end :: proc(v: f32, loc: runtime.Source_Code_Location) {
	old := border_thickness_pop()
	assert(old == v, loc = loc)
}
//-border_thickness

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

//+font_size
font_size_set_next :: proc(v: u16) { stack_set_next(&state.stacks.font_size, v) }
font_size_push :: proc(v: u16) { stack_push(&state.stacks.font_size, v) }
font_size_pop :: proc() -> u16 { return stack_pop(&state.stacks.font_size) }
font_size_top :: proc() -> u16 { return stack_top(&state.stacks.font_size) }
@(deferred_in=_font_size_guard_end)
font_size_guard :: proc(v: u16, loc := #caller_location) { stack_push(&state.stacks.font_size, v) }
_font_size_guard_end :: proc(v: u16, loc: runtime.Source_Code_Location) {
	old := font_size_pop()
	assert(old == v, loc = loc)
}
//-font_size

//+font
font_set_next :: proc(v: F.ID) { stack_set_next(&state.stacks.font, v) }
font_push :: proc(v: F.ID) { stack_push(&state.stacks.font, v) }
font_pop :: proc() -> F.ID { return stack_pop(&state.stacks.font) }
font_top :: proc() -> F.ID { return stack_top(&state.stacks.font) }
@(deferred_in=_font_guard_end)
font_guard :: proc(v: F.ID, loc := #caller_location) { stack_push(&state.stacks.font, v) }
_font_guard_end :: proc(v: F.ID, loc: runtime.Source_Code_Location) {
	old := font_pop()
	assert(old == v, loc = loc)
}
//-font

