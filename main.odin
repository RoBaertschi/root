package root

import "core:math/linalg"
import "core:fmt"
import "core:os"
import "core:log"

import F "font"
import W "window"
import R "render"
import B "base"

main :: proc() {
	temp := B.TEMP_ALLOCATOR_GUARD()
	context.logger = log.create_console_logger(allocator = temp)

	if !F.init() {
		os.exit(1)
	}

	font := F.from_path("/usr/share/fonts/noto/NotoSansMyanmar-Regular.ttf", 0)

	if !W.init({
		size  = { 800, 600 },
		title = "root",
	}) {
		os.exit(1)
	}

	if !R.init() {
		os.exit(1)
	}

	// gl, lines := F.shape_text(font, "Hello World!^a â ö یکအမည်မရှိیک", temp)
	// gl, lines := F.shape_text(font, 16, "Hello World!", temp)
	// if true {
	// 	for it := F.glyph_list_iterator(gl); render_glyph in F.glyph_list_iterate(&it) {
	// 		fmt.println(render_glyph)
	// 	}
	// }
	// gl, lines = F.shape_text(font, 32, "Hello World!", temp)
	// if true {
	// 	for it := F.glyph_list_iterator(gl); render_glyph in F.glyph_list_iterate(&it) {
	// 		fmt.println(render_glyph)
	// 	}
	//
	// 	return
	// }

	// R.texture_from_size({ 1024, 1024 })

	run := true
	for run {
		events := W.events()

		for it := W.event_list_iterator(events^);
			ev, ev_node in W.event_list_iterate(&it)
		{
			if ev.kind == .Close_Request {
				W.event_list_remove(events, ev_node)
				run = false
			}
		}


		for x in 0..<20 {
			for y in 0..<20 {
				R.rect({ pos = { 10 + f32(x) * 40, 10 + f32(y) * 40 }, size = { 30, 30 } }, { 1, 0, 0, 1 })
			}
		}

		gl, lines := F.shape_text(font, 64, "Hello World!^a â ö یکအမည်မရှိیک", temp)
		if true {
			for it := F.glyph_list_iterator(gl); render_glyph in F.glyph_list_iterate(&it) {
				{
					r := R.rect(
						r       = { pos = render_glyph.pos, size = linalg.array_cast(render_glyph.glyph.used_rect.size, f32) },
						color   = { 0, 0, 1, 1 },
						tex_r   = B.rect_cast(render_glyph.glyph.used_rect, f32),
						texture = render_glyph.glyph.atlas.texture,
					)

					r.color[._00] = { 1, 0, 0, 1 }
					r.color[._11] = { 1, 0, 0, 1 }
					r.edge_softness = 0.5
					r.corner_radius = 4
				}
				{
					r := R.rect(
						r       = { pos = render_glyph.pos, size = linalg.array_cast(render_glyph.glyph.used_rect.size, f32) },
						color   = { 0, 0, 1, 1 },
						// tex_r   = B.rect_cast(render_glyph.glyph.used_rect, f32),
						// texture = render_glyph.glyph.atlas.texture,
					)

					// r.color[._10] = { 1, 0, 0, 1 }
					// r.color[._01] = { 1, 0, 0, 1 }
					r.edge_softness = 0.5
					r.corner_radius = 4
					r.border_thickness = 4
				}
			}
		}

		R.frame(W.size())
		W.frame()
	}

	// proposed api
	// W.init()
	//
	// for ... {
	//     events := W.events() // does the polling and such
	//     ...handle events...
	//     ...do rendering...
	//     W.frame()
	// }

	// for _ in 0..<100 {
	// 	// ensure(adwaita == get_test_font())
	// }
	//
	// f := font._from_id(adwaita)
	// ensure(f == font._from_id(adwaita))
	// ensure(f == font._from_id(adwaita))
	// ensure(f == font._from_id(adwaita))
	// ensure(f == font._from_id(adwaita))
	// ensure(f == font._from_id(adwaita))
	// ensure(f == font._from_id(adwaita))
	// ensure(f == font._from_id(adwaita))
}
