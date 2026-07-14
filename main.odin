package root

import "core:os"
import "core:log"

import "font"

main :: proc() {
	context.logger = log.create_console_logger()

	if !font.init() {
		os.exit(1)
	}

	get_test_font :: proc() -> font.ID {
		return font.from_path("/usr/share/fonts/Adwaita/AdwaitaMono-Regular.ttf", 0)
	}

	adwaita := get_test_font()
	// fmt.println(adwaita, font._from_id(adwaita))
	ensure(adwaita == get_test_font())
	ensure(adwaita == get_test_font())
	ensure(adwaita == get_test_font())
	ensure(adwaita == get_test_font())
	ensure(adwaita == get_test_font())
	ensure(adwaita == get_test_font())
	ensure(adwaita == get_test_font())

	f := font._from_id(adwaita)
	ensure(f == font._from_id(adwaita))
	ensure(f == font._from_id(adwaita))
	ensure(f == font._from_id(adwaita))
	ensure(f == font._from_id(adwaita))
	ensure(f == font._from_id(adwaita))
	ensure(f == font._from_id(adwaita))
	ensure(f == font._from_id(adwaita))
}
