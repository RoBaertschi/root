package oui

import "core:fmt"
import "core:math/rand"
import B "../base"
import R "../render"
import F "../font"

@(private="file")
r: rand.PCG_Random_State

@init
_render_init :: proc "contextless" () {
	@(require_results)
	read_u64 :: proc "contextless" (r: ^rand.PCG_Random_State) -> u64 {
		old_state := r.state
		r.state = old_state * 6364136223846793005 + (r.inc|1)
		xor_shifted := (((old_state >> 59) + 5) ~ old_state) * 12605985483714917081
		rot := (old_state >> 59)
		return (xor_shifted >> rot) | (xor_shifted << ((-rot) & 63))
	}

	seed := u64(1000)
	r.state = 0
	r.inc = (seed << 1) | 1
	_ = read_u64(&r)
	r.state += seed
	_ = read_u64(&r)
}

render :: proc(debug := false) {
	local := r
	context.random_generator = rand.pcg_random_generator(&local)

	draw_text :: proc(text: string, pos: [2]f32) {
		r := F.get_run(0, 8, text)

		for it := F.glyph_list_iterator(r.glyphs); rglyph in F.glyph_list_iterate(&it) {
			_ = R.rect(
				r       = { pos = rglyph.pos + pos, size = B.array_cast(rglyph.glyph.used_rect.size, f32) },
				color   = { 1, 1, 1, 1 },
				tex_r   = B.rect_cast(rglyph.glyph.used_rect, f32),
				texture = rglyph.glyph.atlas.texture,
			)
		}
	}

	draw_textf :: proc(pos: [2]f32, format: string, args: ..any) {
		draw_text(fmt.aprintf(format, ..args, allocator = build_allocator()), pos)
	}

	render_box :: proc(b: ^Box, debug: bool) {
		if .Draw_Background in b.flags {
			att := b.att_rect

			background_color := att.background_color

			rect               := R.rect(b.rect, background_color)
			rect.corner_radius  = att.corner_radius

			if .Draw_Hover in b.flags {
				effective_hover := b.hovered_anim * (1 - b.active_anim)
				hover_alpha     := 0.2 * effective_hover * background_color.a

				hover_rect               := R.rect(b.rect)
				hover_rect.corner_radius  = att.corner_radius
				hover_rect.color = {
					._00 = { 1, 1, 1, hover_alpha },
					._01 = { 1, 1, 1, hover_alpha },
					._10 = { 0, 0, 0, hover_alpha },
					._11 = { 0, 0, 0, hover_alpha },
				}
			}

			if .Draw_Active in b.flags {
				active_alpha := 0.5 * b.active_anim * background_color.a

				active_rect               := R.rect(b.rect)
				active_rect.corner_radius  = att.corner_radius
				active_rect.color = {
					._00 = { 1, 1, 1, active_alpha },
					._01 = { 1, 1, 1, active_alpha },
					._10 = { 0, 0, 0, active_alpha },
					._11 = { 0, 0, 0, active_alpha },
				}
			}
		}

		if .Draw_Text in b.flags {
			text  := b.att_text
			color := text.color

			for it := F.glyph_list_iterator(text.run.glyphs); rglyph in F.glyph_list_iterate(&it) {
				_ = R.rect(
					r       = { pos = rglyph.pos + b.rect.pos, size = B.array_cast(rglyph.glyph.used_rect.size, f32) },
					color   = color,
					tex_r   = B.rect_cast(rglyph.glyph.used_rect, f32),
					texture = rglyph.glyph.atlas.texture,
				)
			}

			// debug_rect := R.rect(
			// 	r = { pos = text.run.visible.pos + b.rect.pos, size = text.run.visible.size },
			// 	color = { 0, 0, 0, 1 },
			// )
			// // debug_rect.corner_radius    = 4
			// debug_rect.border_thickness = 2
		}

		if .Draw_Custom in b.flags {
			b.att_draw.procedure(b)
		}

		if debug {
			R.rect(
				b.rect,
				{
					rand.float32(),
					rand.float32(),
					rand.float32(),
					0.2,
				},
			)

			name := "<none>"
			if b.att_text != nil {
				name = b.att_text.content
			}
			draw_textf(b.rect.pos, "box-%v", name)
		}

		if .Draw_Clip in b.flags {
			R.push_clip(B.rect_cast(b.rect, int))
		}
		defer if .Draw_Clip in b.flags {
			R.pop_clip()
		}

		for child := b.first; child != nil; child = child.next {
			render_box(child, debug)
		}
	}

	render_box(state.root, debug)
}
