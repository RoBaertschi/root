package oui_raylib

import "base:runtime"

import "core:strings"

import "vendor:raylib"

import ".."

// TODO(robin): support custom settings for font size and such

gather_events :: proc(allocator: runtime.Allocator) -> (el: oui.Event_List) {
	buttons := [oui.Mouse_Button]raylib.MouseButton{
		.Left   = .LEFT,
		.Right  = .RIGHT,
		.Middle = .MIDDLE,
	}

	oui.event_list_init(&el, allocator)

	pos := raylib.GetMousePosition()

	for button in oui.Mouse_Button {
		if raylib.IsMouseButtonPressed(buttons[button]) {
			oui.event_list_push(&el, {
				key  = oui.Event_Key.Mouse_Left + oui.Event_Key(button),
				kind = .Pressed,
				pos  = pos,
			})
		}

		if raylib.IsMouseButtonReleased(buttons[button]) {
			oui.event_list_push(&el, {
				key  = oui.Event_Key.Mouse_Left + oui.Event_Key(button),
				kind = .Released,
				pos  = pos,
			})
		}
	}

	return el
}

meassure_text_impl : oui.Impl_Meassure_Text : proc(data: rawptr, s: string, a: oui.Axis) -> f32 {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	cstr := strings.clone_to_cstring(s, context.temp_allocator)
	defer delete(cstr, allocator = context.temp_allocator)

	size := raylib.MeasureTextEx(raylib.GetFontDefault(), cstr, 20, 1)

	switch a {
	case .X:
		return size.x
	case .Y:
		return size.y
	case:
		panic("unhandled missing oui.Axis")
	}
}

impl :: proc() -> oui.Impl {
	return {
		meassure_text = meassure_text_impl,
	}
}

render_box :: proc(b: ^oui.Box, c: ^oui.Context) {
	if .Draw_Background in b.flags {
		#assert(size_of(b.rect) == size_of(raylib.Rectangle))
		#assert(align_of(b.rect) == align_of(raylib.Rectangle))

		att := b.att_rect

		rect := transmute(raylib.Rectangle)b.rect
		raylib.DrawRectangleRounded(rect, att.corner_radius, 0, raylib.Color(att.background_color))

		if .Draw_Hover in b.flags {
			effective_hover := b.hovered_anim * (1 - b.active_anim)
			hover_alpha := u8(0.2 * effective_hover * f32(att.background_color.a))
			raylib.DrawRectangleGradientEx(
				rect,
				{255, 255, 255, hover_alpha},
				{0, 0, 0, hover_alpha},
				{0, 0, 0, hover_alpha},
				{255, 255, 255, hover_alpha},
			)
		}

		if .Draw_Active in b.flags {
			active_alpha := u8(0.5 * b.active_anim * f32(att.background_color.a))
			raylib.DrawRectangleGradientEx(
				rect,
				{255, 255, 255, active_alpha},
				{0, 0, 0, active_alpha},
				{0, 0, 0, active_alpha},
				{255, 255, 255, active_alpha},
			)
		}
	}

	if .Draw_Text in b.flags {
		runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

		// raylib.BeginScissorMode(i32(b.rect.pos.x), i32(b.rect.pos.y), i32(b.rect.size.x), i32(b.rect.size.y))

		att := b.att_text

		ctext := strings.clone_to_cstring(att.content, context.temp_allocator)
		defer delete(ctext, allocator = context.temp_allocator)
		raylib.DrawTextPro(raylib.GetFontDefault(), ctext, b.rect.pos, {}, 0, 20, 1, raylib.Color(att.color))

		// raylib.EndScissorMode()
	}

	if .Draw_Custom in b.flags {
		b.att_draw.procedure(b)
	}

	// Clip after rendering box itself
	if .Draw_Clip in b.flags {
		raylib.BeginScissorMode(i32(b.rect.pos.x), i32(b.rect.pos.y), i32(b.rect.size.x), i32(b.rect.size.y))
	}
	defer if .Draw_Clip in b.flags {
		raylib.EndScissorMode()
	}

	for child := b.first; child != nil; child = child.next {
		render_box(child, c)
	}
}

render :: proc(c: ^oui.Context) {
	render_box(c.root, c)
}
