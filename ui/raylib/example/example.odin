package oui_raylib_example

import "core:fmt"
import "vendor:raylib"

import oui "../.."
import oui_raylib ".."

main :: proc() {
	raylib.InitWindow(800, 600, "Hello World!")
	defer raylib.CloseWindow()

	c: oui.Context
	oui.context_init(&c, oui_raylib.impl())

	for !raylib.WindowShouldClose() {
		free_all(context.temp_allocator)

		oui.begin({
			root_size  = {800, 600},
			root_key   = "",
			events     = oui_raylib.gather_events(context.temp_allocator),
			mouse_pos  = raylib.GetMousePosition(),
			delta_time = raylib.GetFrameTime(),
		}, &c)
		{
			oui.corner_radius_guard(&c, 0.2)
			oui.semantic_width_set_next(&c, oui.pixels(200, 1))
			oui.semantic_height_set_next(&c, oui.pixels(400, 1))
			oui.box_make({ .Draw_Background }, "", &c)

			oui.semantic_width_set_next(&c, oui.children_sum(1))
			oui.semantic_height_set_next(&c, oui.children_sum(1))
			oui.background_color_set_next(&c, { 222, 22, 222, 255 })
			b := oui.box_make({ .Draw_Background, .Draw_Clip, .Overflow_X }, "clipped", &c)

			{
				oui.parent_guard(b, &c)
				oui.semantic_width_set_next(&c, oui.pixels(10, 1))
				oui.semantic_height_set_next(&c, oui.pixels(0, 1))
				oui.box_make({}, "", &c)

				oui.semantic_width_set_next(&c, oui.text_content(1))
				oui.semantic_height_set_next(&c, oui.text_content(1))
				oui.background_color_set_next(&c, { 222, 22, 222, 255 })
				button := oui.box_make({ .Draw_Text, .Draw_Background, .Draw_Hover, .Draw_Active, .Clickable }, "button", &c)
				s := oui.signal_from_box(button, &c)

				if .Clicked_Left in s.flags {
					fmt.println("button", s.flags)
				}

				oui.semantic_width_set_next(&c, oui.pixels(10, 1))
				oui.semantic_height_set_next(&c, oui.pixels(0, 1))
				oui.box_make({}, "", &c)
			}

			oui.semantic_width_set_next(&c, oui.children_sum(1))
			oui.semantic_height_set_next(&c, oui.children_sum(1))
			oui.background_color_set_next(&c, { 222, 22, 222, 255 })
			b = oui.box_make({ .Draw_Background, .Draw_Clip, .Overflow_X }, "clipped1", &c)

			{
				oui.parent_guard(b, &c)
				oui.semantic_width_set_next(&c, oui.pixels(10, 1))
				oui.semantic_height_set_next(&c, oui.pixels(0, 1))
				oui.box_make({}, "", &c)

				oui.semantic_width_set_next(&c, oui.text_content(1))
				oui.semantic_height_set_next(&c, oui.text_content(1))
				button := oui.box_make({ .Draw_Text, .Draw_Background, .Draw_Hover, .Draw_Active, .Clickable }, "button1", &c)
				s := oui.signal_from_box(button, &c)

				if .Clicked_Left in s.flags {
					fmt.println("button1", s.flags)
				}

				oui.semantic_width_set_next(&c, oui.pixels(10, 1))
				oui.semantic_height_set_next(&c, oui.pixels(0, 1))
				oui.box_make({}, "", &c)
			}

			oui.semantic_width_set_next(&c, oui.pixels(200, 1))
			oui.semantic_height_set_next(&c, oui.pixels(400, 1))
			custom := oui.box_make({ .Draw_Background, .Draw_Custom }, "", &c)
			oui.box_attach_draw(custom, proc(b: ^oui.Box) {
				raylib.DrawText("Hello World", 20, 20, 20, raylib.BLACK)
			}, nil, &c)
		}
		oui.end(&c)

		raylib.BeginDrawing()
			raylib.ClearBackground(raylib.RAYWHITE)

			oui_raylib.render(&c)
		raylib.EndDrawing()
	}
}
