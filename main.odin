package root

import "core:fmt"
import "core:os"
import "core:log"

import "font"

main :: proc() {
	context.logger = log.create_console_logger()

	if !font.init() {
		os.exit(1)
	}

	get_test_font :: proc() -> font.ID {
		return font.from_path("/usr/share/fonts/noto/NotoSans-Regular.ttf", 0)
	}

	adwaita := get_test_font()
	fmt.println(adwaita, font._from_id(adwaita))

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
