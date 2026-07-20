package root

import "core:time"
import "core:fmt"
import "core:math/linalg"
import "core:os"
import "core:log"

import F "font"
import W "window"
import R "render"
import B "base"
import UI "ui"

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

	c: UI.Context
	UI.context_init(&c)
	defer UI.context_fini(&c)

	last_time: time.Tick

	run := true
	for run {
		current_time := f32(time.tick_lap_time(&last_time)) / f32(time.Second)

		events := W.events()

		for it := W.event_list_iterator(events^);
			ev, ev_node in W.event_list_iterate(&it)
		{
			if ev.kind == .Close_Request {
				W.event_list_remove(events, ev_node)
				run = false
			}
		}

		R.begin_frame(W.size())

		UI.begin({
			root_key   = "",
			root_size  = B.array_cast(W.size(), f32),
			delta_time = current_time,
		}, &c)
		{
			UI.corner_radius_guard(&c, 0.2)
			UI.semantic_width_set_next(&c, UI.pixels(200, 1))
			UI.semantic_height_set_next(&c, UI.pixels(400, 1))
			UI.box_make({ .Draw_Background }, "", &c)

			UI.semantic_width_set_next(&c, UI.children_sum(1))
			UI.semantic_height_set_next(&c, UI.children_sum(1))
			UI.background_color_set_next(&c, { 222, 22, 222, 255 })
			b := UI.box_make({ .Draw_Background, .Draw_Clip, .Overflow_X }, "clipped", &c)

			{
				UI.parent_guard(b, &c)
				UI.semantic_width_set_next(&c, UI.pixels(10, 1))
				UI.semantic_height_set_next(&c, UI.pixels(0, 1))
				UI.box_make({}, "", &c)

				UI.semantic_width_set_next(&c, UI.text_content(1))
				UI.semantic_height_set_next(&c, UI.text_content(1))
				UI.background_color_set_next(&c, { 222, 22, 222, 255 })
				button := UI.box_make({ .Draw_Text, .Draw_Background, .Draw_Hover, .Draw_Active, .Clickable }, "button", &c)
				s := UI.signal_from_box(button, &c)

				if .Clicked_Left in s.flags {
					fmt.println("button", s.flags)
				}

				UI.semantic_width_set_next(&c, UI.pixels(10, 1))
				UI.semantic_height_set_next(&c, UI.pixels(0, 1))
				UI.box_make({}, "", &c)
			}
		}
		UI.end(&c)

		for x in 0..<20 {
			for y in 0..<20 {
				R.rect({ pos = { 10 + f32(x) * 40, 10 + f32(y) * 40 }, size = { 30, 30 } }, { 1, 0, 0, 1 })
			}
		}

		text := "Yolo!!!!????>= ==="

		run := F.get_run(0, 64, text)

		draw_text :: proc(pos: [2]f32, s: string) {
			run := F.get_run(0, 32, s)

			for it := F.glyph_list_iterator(run.glyphs); rglyph in F.glyph_list_iterate(&it) {
				_ = R.rect(
					r       = { pos = rglyph.pos + pos, size = linalg.array_cast(rglyph.glyph.used_rect.size, f32) },
					color   = { 0, 0, 0, 1 },
					tex_r   = B.rect_cast(rglyph.glyph.used_rect, f32),
					texture = rglyph.glyph.atlas.texture,
				)
			}
		}

		temp := B.TEMP_ALLOCATOR_GUARD()
		mouse_pos     := W.mouse()
		mouse_pos_str := fmt.aprintf("x: %v, y: %v", mouse_pos.x, mouse_pos.y)
		draw_text({}, mouse_pos_str)

		gl := run.glyphs
		for it := F.grapheme_list_iterator(run.graphemes); grapheme in F.grapheme_list_iterate(&it) {
			glyph_node := grapheme.start

			for i in 0..<grapheme.count {
				render_glyph := glyph_node.glyph

				{
					used_rect := B.rect_cast(render_glyph.glyph.used_rect, f32)

					r := R.rect(
						r       = { pos = render_glyph.pos + { 0, 800 }, size = used_rect.size },
						color   = { 0, 0, 1, 1 },
						tex_r   = used_rect,
						texture = render_glyph.glyph.atlas.texture,
					)

					r.color[._00] = { 1, 0, 0, 1 }
					r.color[._11] = { 1, 0, 0, 1 }
					// r.edge_softness = 0.5
					// r.corner_radius = 4

					draw_text({ r.dst_00.x, 800 + 64 }, text[render_glyph.source.start:render_glyph.source.end])
				}

				{
					r := R.rect(
						r     = { pos = run.metrics.pos + { 0, 800 } - { 2, 2 }, size = run.metrics.size + { 4, 4 } },
						color = { 0, 0, 1, 1 },
					)
					r.color[._00] = { 1, 0, 0, 1 }
					r.color[._11] = { 1, 0, 0, 1 }
					r.corner_radius = 4
					r.border_thickness = 2
				}

				glyph_node = glyph_node.next
			}

			UI.render(&c)


			// {
			// 	r := R.rect(
			// 		r       = { pos = render_glyph.pos - { 4, 4 }, size = linalg.array_cast(render_glyph.glyph.used_rect.size, f32) + { 8, 8 } },
			// 		color   = { 0, 0, 1, 1 },
			// 		// tex_r   = B.rect_cast(render_glyph.glyph.used_rect, f32),
			// 		// texture = render_glyph.glyph.atlas.texture,
			// 	)
			//
			// 	// r.color[._10] = { 1, 0, 0, 1 }
			// 	// r.color[._01] = { 1, 0, 0, 1 }
			// 	r.edge_softness = 0.5
			// 	r.corner_radius = 4
			// 	r.border_thickness = 4
			// }
		}

		R.end_frame()
		W.frame()
		F.frame()
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
