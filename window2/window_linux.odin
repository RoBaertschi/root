#+private
package root_window2

import "core:time"
import WL "../wayland"
import XDG "../wayland/xdg"
import XKB "../window/xkbcommon"

// #region Event

_Interaction_Key :: distinct u32

// #endregion

// #region Window

@(private="package")
_Window_Platform :: struct {}

_window_platform_init :: proc(w: ^Window) {
}

// #endregion

// #region State


Seat_Capability :: enum i32 {
	pointer,
	keyboard,
	touch,
}

Seat_Capabilities :: bit_set[Seat_Capability; i32]

Key :: struct {
	keysym: XKB.keysym_t,
	key:    Event_Key,
}

Key_Node :: struct {
	next: ^Key_Node,
	key:  Key,
}

_State_Platform :: struct {
	display:                ^WL.display,
	registry:               ^WL.registry,
	compositor:             ^WL.compositor,
	shm:                    ^WL.shm,
	xdg_wm_base:            ^XDG.wm_base,
	seat:                   ^WL.seat,
	seat_capabilities:      Seat_Capabilities,

	pointer:                Maybe(^WL.pointer),
	pointer_pos:            [2]f32,
	cursor_image:           ^WL.cursor_image,
	cursor_surface:         ^WL.surface,

	xkb_ctx:                ^XKB.context_,
	keyboard:               Maybe(^WL.keyboard),
	keyboard_repeat_delay:  i32,
	keyboard_repeat_rate:   i32,
	keyboard_last_keycode:  XKB.keycode_t,
	keyboard_last_serial:   u32,
	keyboard_next_deadline: time.Tick,
	xkb_mapping:            ^XKB.keymap,
	xkb_state:              ^XKB.state,
	xkb_compose_table:      ^XKB.compose_table,
	xkb_compose_state:      ^XKB.compose_state,
	pressed_keys:           ^Key_Node,
	free_keys:              ^Key_Node,
}

_state_platform_init :: proc(s: ^State) -> bool {
	

	return true
}

// #endregion
