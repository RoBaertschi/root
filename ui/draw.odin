package oui

import "core:math/bits"

import B "../base"
import R "../render"
import F "../font"

render :: proc(c: ^Context) {
	normalize_color :: proc(color: [4]u8) -> R.Color {
		return {
			f32(color.r) / bits.U8_MAX,
			f32(color.g) / bits.U8_MAX,
			f32(color.b) / bits.U8_MAX,
			f32(color.a) / bits.U8_MAX,
		}
	}

	render_box :: proc(b: ^Box) {
		if .Draw_Background in b.flags {
			att := b.att_rect

			background_color := normalize_color(att.background_color)

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
			color := normalize_color(text.color)

			for it := F.glyph_list_iterator(text.run.glyphs); rglyph in F.glyph_list_iterate(&it) {
				_ = R.rect(
					r       = { pos = rglyph.pos + b.rect.pos, size = B.array_cast(rglyph.glyph.used_rect.size, f32) },
					color   = color,
					tex_r   = B.rect_cast(rglyph.glyph.used_rect, f32),
					texture = rglyph.glyph.atlas.texture,
				)
			}

			debug_rect := R.rect(
				r = { pos = text.run.visible.pos + b.rect.pos, size = text.run.visible.size },
				color = { 0, 0, 0, 1 },
			)
			// debug_rect.corner_radius    = 4
			debug_rect.border_thickness = 2
		}

		if .Draw_Custom in b.flags {
			b.att_draw.procedure(b)
		}

		if .Draw_Clip in b.flags {
			R.push_clip(B.rect_cast(b.rect, int))
		}
		defer if .Draw_Clip in b.flags {
			R.pop_clip()
		}

		for child := b.first; child != nil; child = child.next {
			render_box(child)
		}
	}

	render_box(c.root)
}
