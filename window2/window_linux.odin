#+private
package root_window2

import "core:log"
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
	display:                 ^WL.display,
	registry:                ^WL.registry,
	compositor:              ^WL.compositor,
	shm:                     ^WL.shm,
	xdg_wm_base:             ^XDG.wm_base,
	seat:                    ^WL.seat,
	seat_capabilities:       Seat_Capabilities,

	pointer:                 Maybe(^WL.pointer),
	pointer_pos:             [2]f32,
	pointer_current_window:  ^Window,
	cursor_image:            ^WL.cursor_image,
	cursor_surface:          ^WL.surface,

	xkb_ctx:                 ^XKB.context_,
	keyboard:                Maybe(^WL.keyboard),
	keyboard_current_window: ^Window,
	keyboard_repeat_delay:   i32,
	keyboard_repeat_rate:    i32,
	keyboard_last_keycode:   XKB.keycode_t,
	keyboard_last_serial:    u32,
	keyboard_next_deadline:  time.Tick,
	xkb_mapping:             ^XKB.keymap,
	xkb_state:               ^XKB.state,
	xkb_compose_table:       ^XKB.compose_table,
	xkb_compose_state:       ^XKB.compose_state,
	pressed_keys:            ^Key_Node,
	free_keys:               ^Key_Node,
}

_state_platform_init :: proc(s: ^State) -> (ok: bool) {
	p := &s._platform

	p.xkb_ctx = XKB.context_new({})

	p.display = WL.display_connect(nil)
	if p.display == nil {
		log.fatal("could not connect to wayland display")
		return
	}
	defer if !ok {
		WL.display_disconnect(p.display)
	}

	@static
	registry_listener := WL.registry_listener{
		global = proc "c"(
			data: rawptr, registry: ^WL.registry, name: u32, interface_: cstring, version: u32,
		) {
			context = state.ctx
			s := cast(^State)data
			p := &s._platform

			switch interface_ {
			case WL.compositor_interface.name:
				p.compositor = cast(^WL.compositor)WL.registry_bind(registry, name, &WL.compositor_interface, version)
			case WL.seat_interface.name:
				p.seat = cast(^WL.seat)WL.registry_bind(registry, name, &WL.seat_interface, 7)
				WL.seat_add_listener(p.seat, &wl_seat_listener, nil)
			case WL.shm_interface.name:
				p.shm = cast(^WL.shm)WL.registry_bind(registry, name, &WL.shm_interface, 1)
			case XDG.wm_base_interface.name:
				p.xdg_wm_base = cast(^XDG.wm_base)WL.registry_bind(registry, name, &XDG.wm_base_interface, min(version, 5))
				XDG.wm_base_add_listener(p.xdg_wm_base, &xdg_wm_base_listener, nil)
			// case:
			// 	log.debugf("unhandled global %v:%v@%v", interface_, version, name)
			}
		},
		global_remove = proc "c"(data: rawptr, registry: ^WL.registry, name_: u32) {
			// TODO(robin): does this matter to us?
		},
	}

	p.registry = WL.display_get_registry(p.display)
	WL.registry_add_listener(p.registry, &registry_listener, s)

	WL.display_roundtrip(p.display)

	ok = true
	return
}

// #endregion
