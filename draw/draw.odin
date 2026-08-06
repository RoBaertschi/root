package root_draw

import B "../base"
import R "../render"
import F "../font"

rect :: proc(r: B.Rect(f32)) -> ^R.Rect {
	return R.batch_push_rect(
		{
			dst_00 = r.pos,
			dst_11 = r.pos + r.size,
		},
		{
			texture = R.NIL_TEXTURE,
			clip    = R.top_clip(),
		},
	)
}

rect_with_texture :: proc(r: B.Rect(f32), texture: R.Texture_Handle, texture_rect: B.Rect(f32)) -> ^R.Rect {
	return R.batch_push_rect(
		{
			dst_00 = r.pos,
			dst_11 = r.pos + r.size,
			src_00 = texture_rect.pos,
			src_11 = texture_rect.pos + texture_rect.size,
		},
		{
			texture = texture,
			clip    = R.top_clip(),
		},
	)
}

rect_with_color :: proc(r: B.Rect(f32), color: R.Color) -> ^R.Rect {
	r_ := rect(r)
	rect_set_color(r_, color)
	return r_
}

rect_set_color :: proc(r: ^R.Rect, color: R.Color) -> ^R.Rect {
	r.color = {
		._00 = color,
		._10 = color,
		._01 = color,
		._11 = color,
	}
	return r
}

text_run :: proc(run: ^F.Run, r: B.Rect(f32), text_color: R.Color) {
	R.push_clip(B.rect_f32_to_int(r))
	defer R.pop_clip()

	for it := F.glyph_list_iterator(run.glyphs); rglyph in F.glyph_list_iterate(&it) {
		used_rect := B.rect_cast(rglyph.glyph.used_rect, f32)

		glyph_pos := r.pos + rglyph.pos
		// glyph_pos.x = math.round(glyph_pos.x)
		// glyph_pos.y = math.round(glyph_pos.y)

		rect_set_color(rect_with_texture(
			{
				pos  = glyph_pos,
				size = used_rect.size,
			},
			rglyph.glyph.atlas.texture,
			used_rect,
		), text_color)
	}
}

push_clip :: R.push_clip
pop_clip  :: R.pop_clip
top_clip  :: R.top_clip
