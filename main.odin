package root

import "core:os"
import "core:log"

import F "font"
import W "window"
import R "render"

main :: proc() {
	context.logger = log.create_console_logger()

	if !F.init() {
		os.exit(1)
	}

	if !W.init({
		size  = { 800, 600 },
		title = "root",
	}) {
		os.exit(1)
	}

	R.init()

	R.texture_from_size({ 1024, 1024 })

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
