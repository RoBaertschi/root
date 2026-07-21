#+private
package root_window

import "core:time"
import "core:c"
import "core:sys/posix"
import "core:math/linalg"
import "core:math/bits"
import "core:strings"
import "core:log"
import "base:runtime"
import "core:mem/virtual"
import "vendor:egl"

import B "../base"

import "../wayland/xdg"
import wl "../wayland"
import xkb "xkbcommon"

import gl "vendor:OpenGL"

Key :: struct {
	keysym: xkb.keysym_t,
	key:    Event_Key,
}

Key_Node :: struct {
	next: ^Key_Node,
	key:  Key,
}

State :: struct {
	ctx:                    runtime.Context,
	window_size:            [2]i32,
	arena:                  virtual.Arena,
	flags:                  Window_Flags,
	events:                 Event_List,
	dispatched:             bool,

	display:                ^wl.display,
	registry:               ^wl.registry,
	compositor:             ^wl.compositor,
	shm:                    ^wl.shm,
	xdg_wm_base:            ^xdg.wm_base,
	seat:                   ^wl.seat,

	capabilities:           Seat_Capabilities,

	pointer:                Maybe(^wl.pointer),
	pointer_pos:            [2]f32,
	cursor_image:           ^wl.cursor_image,
	cursor_surface:         ^wl.surface,

	xkb_ctx:                ^xkb.context_,
	keyboard:               Maybe(^wl.keyboard),
	keyboard_repeat_delay:  i32,
	keyboard_repeat_rate:   i32,
	keyboard_last_keycode:  xkb.keycode_t,
	keyboard_next_deadline: time.Tick,
	xkb_mapping:            ^xkb.keymap,
	xkb_state:              ^xkb.state,
	xkb_compose_table:      ^xkb.compose_table,
	xkb_compose_state:      ^xkb.compose_state,
	pressed_keys:           ^Key_Node,
	free_keys:              ^Key_Node,

	surface:                ^wl.surface,
	region:                 ^wl.region,
	xdg_surface:            ^xdg.surface,
	xdg_surface_configured: bool,
	xdg_toplevel:           ^xdg.toplevel,

	egl_context:            egl.Context,
	egl_display:            egl.Display,
	egl_surface:            egl.Surface,
	egl_window:             ^wl.egl_window,
}

_state_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(&state.arena)
}

state: ^State

Seat_Capability :: enum i32 {
	pointer,
	keyboard,
	touch,
}

Seat_Capabilities :: bit_set[Seat_Capability; i32]

Wl_Button :: enum u32 {
	Left   = 0x110,
	Right  = 0x111,
	Middle = 0x112,
}

keysym_push :: proc(key: Key) {
	node: ^Key_Node
	if state.free_keys != nil {
		node            = state.free_keys
		state.free_keys = node.next
		node^           = {}
	} else {
		node, _ = virtual.new(&state.arena, Key_Node)
	}

	node.key           = key
	node.next          = state.pressed_keys
	state.pressed_keys = node
}

keysym_is_pressed :: proc(keysym: xkb.keysym_t) -> bool {
	for node := state.pressed_keys; node != nil; node = node.next {
		if node.key.keysym == keysym {
			return true
		}
	}

	return false
}

keysym_remove :: proc(keysym: xkb.keysym_t) {
	next_ptr := &state.pressed_keys

	for node := state.pressed_keys; node != nil; node = node.next {
		if node.key.keysym == keysym {
			next_ptr^       = node.next
			state.free_keys = node
			return
		}

		next_ptr = &node.next
	}
	// not found
}

event_key_from_xkb_keysym :: proc(keysym: xkb.keysym_t) -> Event_Key {
	#partial switch xkb.keysyms(keysym) {
	case .a..=.z:       return .A + Event_Key(keysym - xkb.keysym_t(xkb.keysyms.a))
	case ._0..=._9:     return .Num_0 + Event_Key(keysym - xkb.keysym_t(xkb.keysyms._0))
	case .F1..=.F12:    return .F1 + Event_Key(keysym - xkb.keysym_t(xkb.keysyms.F1))

	case .Escape:       return .Escape
	case .Return:       return .Enter
	case .Tab:          return .Tab
	case .BackSpace:    return .Backspace
	case .Delete:       return .Delete
	case .Insert:       return .Insert
	case .space:        return .Space

	case .Left:         return .Left
	case .Right:        return .Right
	case .Up:           return .Up
	case .Down:         return .Down
	case .Home:         return .Home
	case .End:          return .End
	case .Prior:        return .Page_Up
	case .Next:         return .Page_Down
	case .Shift_L:      return .Shift_Left
	case .Shift_R:      return .Shift_Right
	case .Control_L:    return .Control_Left
	case .Control_R:    return .Control_Right
	case .Alt_L:        return .Alt_Left
	case .Alt_R:        return .Alt_Right
	case .Super_L:      return .Super_Left
	case .Super_R:      return .Super_Right

	case .minus:        return .Minus
	case .equal:        return .Equal
	case .bracketleft:  return .Left_Bracket
	case .bracketright: return .Right_Bracket
	case .backslash:    return .Backslash
	case .semicolon:    return .Semicolon
	case .apostrophe:   return .Apostrophe
	case .grave:        return .Grave
	case .comma:        return .Comma
	case .period:       return .Period
	case .slash:        return .Slash

	case .Print:        return .Print_Screen
	case .Pause:        return .Pause
	case .Menu:         return .Menu

	case .KP_Insert:    return .Keypad_0
	case .KP_End:       return .Keypad_1
	case .KP_Down:      return .Keypad_2
	case .KP_Next:      return .Keypad_3
	case .KP_Left:      return .Keypad_4
	case .KP_Begin:     return .Keypad_5
	case .KP_Right:     return .Keypad_6
	case .KP_Home:      return .Keypad_7
	case .KP_Up:        return .Keypad_8
	case .KP_Prior:     return .Keypad_9
	case .KP_Delete:    return .Keypad_Decimal
	case .KP_Divide:    return .Keypad_Divide
	case .KP_Multiply:  return .Keypad_Multiply
	case .KP_Subtract:  return .Keypad_Subtract
	case .KP_Add:       return .Keypad_Add
	case .KP_Enter:     return .Keypad_Enter
	case .KP_Equal:     return .Keypad_Equal
	}

	return .Unknown
}

event_modifiers_from_xkb_state :: proc(xkb_state: ^xkb.state) -> (modifiers: Event_Modifiers) {
	if xkb.state_mod_name_is_active(xkb_state, xkb.MOD_NAME_SHIFT, .MODS_EFFECTIVE) > 0 {
		modifiers += {.Shift}
	}
	if xkb.state_mod_name_is_active(xkb_state, xkb.MOD_NAME_CTRL, .MODS_EFFECTIVE) > 0 {
		modifiers += {.Control}
	}
	if xkb.state_mod_name_is_active(xkb_state, xkb.VMOD_NAME_ALT, .MODS_EFFECTIVE) > 0 {
		modifiers += {.Alt}
	}
	if xkb.state_mod_name_is_active(xkb_state, xkb.VMOD_NAME_SUPER, .MODS_EFFECTIVE) > 0 {
		modifiers += {.Super}
	}
	return
}

wl_pointer_listener := wl.pointer_listener{
	enter = proc "c"(data: rawptr, pointer: ^wl.pointer, serial_: u32, surface: ^wl.surface, surface_x: wl.fixed_t, surface_y: wl.fixed_t) {
		wl.pointer_set_cursor(pointer, serial_, state.cursor_surface, i32(state.cursor_image.hotspot_x), i32(state.cursor_image.hotspot_y))
		if surface == state.surface {
			state.pointer_pos = { wl.fixed_to_f32(surface_x), wl.fixed_to_f32(surface_y) }
		}
	},
	leave = proc "c"(data: rawptr, pointer: ^wl.pointer, serial_: u32, surface_: ^wl.surface) {},
	motion = proc "c"(data: rawptr, pointer: ^wl.pointer, time: u32, surface_x: wl.fixed_t, surface_y: wl.fixed_t) {
		state.pointer_pos = { wl.fixed_to_f32(surface_x), wl.fixed_to_f32(surface_y) }
	},
	button = auto_cast proc "c"(data: rawptr, pointer: ^wl.pointer, serial: u32, time: u32, button_: u32, button_state_: u32) {
		button_state := wl.pointer_button_state(button_state_)
		button       := Wl_Button(button_)

		@static
		button_lookup := [Wl_Button]Event_Key{
			.Left   = .Mouse_Left,
			.Right  = .Mouse_Right,
			.Middle = .Mouse_Middle,
		}

		@static
		button_state_lookup := [wl.pointer_button_state]Event_Key_State{
			.released = .Released,
			.pressed  = .Pressed,
		}

		context = state.ctx

		event_list_push(
			&state.events,
			Event {
				kind      = .Key,
				pos       = state.pointer_pos,
				key       = button_lookup[button],
				key_state = button_state_lookup[button_state],
			},
		)

		// if button == .Left {
		// 	xdg.toplevel_move(state.xdg_toplevel, state.seat, serial)
		// } else if button == .Right {
		// 	xdg.toplevel_resize(state.xdg_toplevel, state.seat, serial, .bottom_right)
		// }
	},
	axis = auto_cast proc "c"(data: rawptr, pointer: ^wl.pointer, time_: u32, axis_: u32, value_: wl.fixed_t) {
		axis := wl.pointer_axis(axis_)
	},
	frame = proc "c"(data: rawptr, pointer: ^wl.pointer) {
		// TODO(robin): dispatch collected data
	},
	axis_source = auto_cast proc "c"(data: rawptr, pointer: ^wl.pointer, axis_source_: u32) {
		axis_source := wl.pointer_axis_source(axis_source_)
	},
	axis_stop = proc "c"(data: rawptr, pointer: ^wl.pointer, time_: u32, axis_: wl.pointer_axis) {},
	axis_discrete = auto_cast proc "c"(data: rawptr, pointer: ^wl.pointer, axis_: u32, discrete_: i32) {
		axis := wl.pointer_axis(axis_)
	},
}

event_list_push_keysym :: proc(keysym: xkb.keysym_t, mods: Event_Modifiers, key_state: Event_Key_State) {
	event_key := event_key_from_xkb_keysym(keysym)

	switch key_state {
	case .Pressed:
		if !keysym_is_pressed(keysym) {
			keysym_push({
				keysym = keysym,
				key    = event_key,
			})
		}
	case .Released:
		keysym_remove(keysym)
	}

	event_list_push(
		&state.events,
		Event {
			kind      = .Key,
			modifiers = mods,
			key       = event_key,
			key_state = key_state,
		},
	)
}

keysym_from_keycode_level_0_only :: proc(keycode: xkb.keycode_t) -> xkb.keysym_t {
	out_raw: [^]xkb.keysym_t
	count := xkb.keymap_key_get_syms_by_level(state.xkb_mapping, keycode, 0, 0, &out_raw)
	out := out_raw[:count]

	if len(out) > 1 || len(out) < 1 {
		return xkb.keysym_t(xkb.keysyms.NoSymbol)
	}

	return out[0]
}

keycode_pressed :: proc(keycode: xkb.keycode_t) {
	keysym := keysym_from_keycode_level_0_only(keycode)

	if xkb.keymap_key_repeats(state.xkb_mapping, keycode) {
		state.keyboard_last_keycode  = keycode
		state.keyboard_next_deadline = time.tick_add(
			time.tick_now(),
			time.Duration(state.keyboard_repeat_delay) * time.Millisecond,
		)
	}

	mods := event_modifiers_from_xkb_state(state.xkb_state)

	if is_shortcut(keysym) {
		event_list_push_keysym(keysym, mods, .Pressed)
	} else {
		temp := B.TEMP_ALLOCATOR_GUARD()
		result := ""

		key_get_utf8 :: proc(keycode: xkb.keycode_t, allocator: runtime.Allocator) -> string {
			result_size := xkb.state_key_get_utf8(state.xkb_state, keycode, nil, 0)
			if result_size <= 0 {
				return ""
			}

			result_data := make([]u8, result_size + 1, allocator = allocator)
			xkb.state_key_get_utf8(state.xkb_state, keycode, raw_data(result_data), len(result_data))
			return string(cstring(raw_data(result_data)))
		}

		if state.xkb_compose_state != nil {
			xkb.compose_state_feed(state.xkb_compose_state, keysym)
			status := xkb.compose_state_get_status(state.xkb_compose_state)

			switch status {
			case .COMPOSING: // do nothing
			case .COMPOSED:
				result_size := xkb.compose_state_get_utf8(state.xkb_compose_state, nil, 0)
				result_data := make([]u8, result_size + 1, allocator = temp)
				xkb.compose_state_get_utf8(state.xkb_compose_state, raw_data(result_data), len(result_data))
				xkb.compose_state_reset(state.xkb_compose_state)

				result = string(cstring(raw_data(result_data)))
			case .NOTHING:
				result = key_get_utf8(keycode, temp)
			case .CANCELLED:
				xkb.compose_state_reset(state.xkb_compose_state)
			}
		} else {
			result = key_get_utf8(keycode, temp)
		}

		if result != "" {
			for r in result {
				// TODO(robin): is this reasonable or should we pass the whole string?
				log.debugf("rune: %r", r)
				event_list_push(
					&state.events,
					{
						kind      = .Codepoint,
						codepoint = r,
					},
				)
			}
		}
	}
}

is_shortcut :: proc(keysym: xkb.keysym_t) -> bool {
	#partial switch xkb.keysyms(keysym) {
	case .Control_L, .Control_R,
		 .Super_L,   .Super_R,
		 .Escape,    .Return,
		 .Tab,       .ISO_Left_Tab,
		 .BackSpace, .Delete,
		 .Insert,    .Left,
		 .Right,     .Up,
		 .Down,      .Home,
		 .End,       .Prior,
		 .Next,      .Print,
		 .Pause,     .Menu,
		 .F1..=.F12:
		return true
	case:
		mods := event_modifiers_from_xkb_state(state.xkb_state)
		return .Control in mods || .Super in mods
	}
}

wl_keyboard_listener := wl.keyboard_listener{
	enter = proc "c"(data: rawptr, keyboard: ^wl.keyboard, serial_: u32, surface_: ^wl.surface, keys_: wl.array) {},

	leave = proc "c"(data: rawptr, keyboard: ^wl.keyboard, serial_: u32, surface_: ^wl.surface) {
		context = state.ctx

		node := state.pressed_keys
		for node != nil {
			event_list_push(
				&state.events,
				Event {
					kind      = .Key,
					key       = node.key.key,
					key_state = .Released,
					modifiers = event_modifiers_from_xkb_state(state.xkb_state),
				},
			)

			next := node.next
			node.next       = state.free_keys
			state.free_keys = node
			node = next
		}
		state.pressed_keys = nil

		xkb.state_update_mask(state.xkb_state, 0, 0, 0, 0, 0, 0)
		state.keyboard_last_keycode  = {}
		state.keyboard_next_deadline = {}

		if state.xkb_compose_state != nil {
			xkb.compose_state_reset(state.xkb_compose_state)
		}
	},

	keymap = proc "c"(data: rawptr, keyboard: ^wl.keyboard, format: wl.keyboard_keymap_format, fd: i32, size: u32) {
		context = state.ctx

		if format != .xkb_v1 {
			log.errorf("unsupported wayland keyboard keymap format: %v", format)
			return
		}

		keymap := posix.mmap(nil, c.size_t(size), { .READ }, { .PRIVATE }, posix.FD(fd))
		if keymap == posix.MAP_FAILED {
			log.errorf("could not map keymap file from wayland compositor: %v", posix.errno())
			return
		}
 
		locale := posix.setlocale(.CTYPE, nil)

		state.xkb_mapping       = xkb.keymap_new_from_string(state.xkb_ctx, cast(cstring)keymap, .TEXT_V1, {})
		state.xkb_state         = xkb.state_new(state.xkb_mapping)
		state.xkb_compose_table = xkb.compose_table_new_from_locale(state.xkb_ctx, locale, {})
		if state.xkb_compose_table == nil {
			log.errorf("could not create xkb compose table")
		} else {
			state.xkb_compose_state = xkb.compose_state_new(state.xkb_compose_table, {})
		}
	},

	key = proc "c"(data: rawptr, keyboard: ^wl.keyboard, serial: u32, time_: u32, key: u32, key_state: wl.keyboard_key_state) {
		context = state.ctx

		keycode := xkb.keycode_t(key + 8)

		switch key_state {
		case .pressed, .repeated:  // .repeated is technically not because of the bound version but you never know
			keycode_pressed(keycode)
		case .released:
			if key_state != .pressed {
				if state.keyboard_last_keycode == keycode {
					state.keyboard_next_deadline = {}
				}

				mods   := event_modifiers_from_xkb_state(state.xkb_state)
				keysym := keysym_from_keycode_level_0_only(keycode)
				if keysym_is_pressed(keysym) {
					event_list_push_keysym(keysym, mods, .Released)
				}

				return
			}
		}
	},

	modifiers = proc "c"(data: rawptr, keyboard: ^wl.keyboard, serial_: u32, mods_depressed_: u32, mods_latched_: u32, mods_locked_: u32, group_: u32) {
		xkb.state_update_mask(
			state.xkb_state,
			xkb.mod_mask_t(mods_depressed_),
			xkb.mod_mask_t(mods_latched_),
			xkb.mod_mask_t(mods_locked_),
			0,
			0,
			xkb.layout_index_t(group_),
		)
	},

	repeat_info = proc "c"(data: rawptr, keyboard: ^wl.keyboard, rate: i32, delay: i32) {
		state.keyboard_repeat_delay = delay
		state.keyboard_repeat_rate  = rate
	},
}

wl_seat_listener := wl.seat_listener{
	capabilities = auto_cast proc "c"(data: rawptr, seat: ^wl.seat, capabilities: bit_set[Seat_Capability; i32]) {
		state.capabilities = capabilities

		if .pointer in state.capabilities {
			state.pointer = wl.seat_get_pointer(seat)
			wl.pointer_add_listener(state.pointer.?, &wl_pointer_listener, nil)
		} else if state.pointer != nil {
			wl.pointer_release(state.pointer.?)
			wl.pointer_destroy(state.pointer.?)
		}

		if .keyboard in state.capabilities {
			state.keyboard = wl.seat_get_keyboard(seat)
			wl.keyboard_add_listener(state.keyboard.?, &wl_keyboard_listener, nil)
		} else if state.keyboard != nil {
			wl.keyboard_release(state.keyboard.?)
			wl.keyboard_destroy(state.keyboard.?)
		}
	},
	name = proc "c"(data: rawptr, seat: ^wl.seat, name_: cstring) {},
}

xdg_toplevel_listener := xdg.toplevel_listener{
	configure = proc "c"(data: rawptr, toplevel: ^xdg.toplevel, width_: i32, height_: i32, states_: wl.array) {
		if width_ == 0 && height_ == 0 {
			return
		}

		context = state.ctx

		new_size := [2]i32{width_, height_}
		if state.window_size != new_size {
			state.window_size = new_size

			wl.egl_window_resize(state.egl_window, **new_size, 0, 0)
			wl.surface_commit(state.surface)

			event_list_push(
				&state.events,
				Event {
					kind = .Resize,
					size = { int(new_size.x), int(new_size.y) },
				},
			)
		}
	},
	close = proc "c"(data: rawptr, toplevel: ^xdg.toplevel) {
		context = state.ctx
		event_list_push(
			&state.events,
			Event {
				kind = .Close_Request,
			},
		)
	},
	configure_bounds = proc "c"(data: rawptr, toplevel: ^xdg.toplevel, width: i32, height: i32) {
		state.window_size = { width, height }
	},
	wm_capabilities = proc "c"(data: rawptr, toplevel: ^xdg.toplevel, capabilities_: wl.array) {
		caps := ([^]u32)(capabilities_.data)[:capabilities_.size / size_of(u32)]

		state.flags = {}

		for cap in caps {
			switch xdg.toplevel_wm_capabilities(cap) {
			case .window_menu:
				state.flags += {.Decoration_Context_Menu_Supported}
			case .maximize:
				state.flags += {.Maximize_Supported}
			case .minimize:
				state.flags += {.Minimize_Supported}
			case .fullscreen: // ignore
			}
		}
	},
}

xdg_surface_listener := xdg.surface_listener{
	configure = proc "c"(data: rawptr, surface: ^xdg.surface, serial: u32) {
		xdg.surface_ack_configure(surface, serial)
		state.xdg_surface_configured = true
	},
}

xdg_wm_base_listener := xdg.wm_base_listener{
	ping = proc "c"(data: rawptr, wm_base: ^xdg.wm_base, serial: u32) {
		xdg.wm_base_pong(wm_base, serial)
	},
}

_init :: proc(desc: Init_Description) -> (ok: bool) {
	assert(desc.size.x <= bits.I32_MAX)
	assert(desc.size.y <= bits.I32_MAX)
	assert(desc.size.x >= bits.I32_MIN)
	assert(desc.size.y >= bits.I32_MIN)

	state, _ = virtual.arena_growing_bootstrap_new(State, "arena")

	context.logger = log.create_console_logger(ident = "WINDOW")
	state.ctx     = context
	state.flags   = { .Maximize_Supported, .Minimize_Supported, .Decoration_Context_Menu_Supported }
	state.xkb_ctx = xkb.context_new({})

	state.display = wl.display_connect(nil)
	if state.display == nil {
		log.fatal("could not connet to wayland display")
		return
	}
	defer if !ok {
		wl.display_disconnect(state.display)
	}

	@static
	registry_listener := wl.registry_listener{
		global = proc "c"(
			data: rawptr, registry: ^wl.registry, name: u32, interface_: cstring, version: u32,
		) {
			context = state.ctx

			switch interface_ {
			case wl.compositor_interface.name:
				state.compositor = cast(^wl.compositor)wl.registry_bind(registry, name, &wl.compositor_interface, version)
			case wl.seat_interface.name:
				state.seat = cast(^wl.seat)wl.registry_bind(registry, name, &wl.seat_interface, 7)
				wl.seat_add_listener(state.seat, &wl_seat_listener, nil)
			case wl.shm_interface.name:
				state.shm = cast(^wl.shm)wl.registry_bind(registry, name, &wl.shm_interface, 1)
			case xdg.wm_base_interface.name:
				state.xdg_wm_base = cast(^xdg.wm_base)wl.registry_bind(registry, name, &xdg.wm_base_interface, min(version, 5))
				xdg.wm_base_add_listener(state.xdg_wm_base, &xdg_wm_base_listener, nil)
			// case:
			// 	log.debugf("unhandled global %v:%v@%v", interface_, version, name)
			}
		},
		global_remove = proc "c"(data: rawptr, registry: ^wl.registry, name_: u32) {
			// TODO(robin): does this matter to us?
		},
	}

	state.registry = wl.display_get_registry(state.display)
	wl.registry_add_listener(state.registry, &registry_listener, nil)

	wl.display_dispatch(state.display)
	wl.display_roundtrip(state.display)

	if state.compositor == nil {
		log.fatal("no wl.compositor, broken compositor?")
		return
	}

	if state.seat == nil {
		log.fatal("no wl.seat, broken compositor?")
		return
	}

	if state.xdg_wm_base == nil {
		log.fatal("no xdg.wm_base, compositor without wm support?")
		return
	}

	state.surface = wl.compositor_create_surface(state.compositor)
	if state.surface == nil {
		log.fatal("could not create wayland surface from compositor")
		return
	}

	state.xdg_surface = xdg.wm_base_get_xdg_surface(state.xdg_wm_base, state.surface)
	xdg.surface_add_listener(state.xdg_surface, &xdg_surface_listener, nil)
	defer if !ok {
		xdg.surface_destroy(state.xdg_surface)
	}

	state.xdg_toplevel = xdg.surface_get_toplevel(state.xdg_surface)
	xdg.toplevel_set_title(state.xdg_toplevel, strings.clone_to_cstring(desc.title, allocator = state_allocator()))
	xdg.toplevel_add_listener(state.xdg_toplevel, &xdg_toplevel_listener, nil)
	defer if !ok {
		xdg.toplevel_destroy(state.xdg_toplevel)
	}

	wl.surface_commit(state.surface)

	state.window_size = { i32(desc.size.x), i32(desc.size.y) }

	state.region = wl.compositor_create_region(state.compositor)
	wl.region_add(state.region, 0, 0, **state.window_size)
	wl.surface_set_opaque_region(state.surface, state.region)
	defer if !ok {
		wl.region_destroy(state.region)
	}

	cursor_theme         := wl.cursor_theme_load(nil, 24, state.shm)
	cursor               := wl.cursor_theme_get_cursor(cursor_theme, "left_ptr")
	state.cursor_image    = cursor.images[0]
	cursor_buffer        := wl.cursor_image_get_buffer(state.cursor_image)
	state.cursor_surface  = wl.compositor_create_surface(state.compositor)
	wl.surface_attach(state.cursor_surface, cursor_buffer, 0, 0)
	wl.surface_commit(state.cursor_surface)

	state.egl_display = egl.GetDisplay(egl.NativeDisplayType(state.display))
	if state.egl_display == nil {
		log.fatal("could not create egl display")
		return
	}

	if !egl.Initialize(state.egl_display, nil, nil) {
		log.fatal("could not initialize egl")
		return
	}
	defer if !ok {
		egl.Terminate(state.egl_display)
	}

	egl.BindAPI(egl.OPENGL_API)
	attributes := [?]i32{
		egl.RED_SIZE,        8,
		egl.GREEN_SIZE,      8,
		egl.BLUE_SIZE,       8,
		egl.ALPHA_SIZE,      8,
		egl.SURFACE_TYPE,    egl.WINDOW_BIT,
		egl.RENDERABLE_TYPE, egl.OPENGL_BIT,
		egl.NONE,
	}

	config: egl.Config
	num_config: i32
	if !egl.ChooseConfig(state.egl_display, &attributes[0], &config, 1, &num_config) {
		log.fatal("could not choose an egl config")
		return
	}

	ctx_attributes := [?]i32{
		egl.CONTEXT_MAJOR_VERSION, 4,
		egl.CONTEXT_MINOR_VERSION, 6,
		// egl.CONTEXT_OPENGL_DEBUG,  1,
		egl.NONE,
	}
	state.egl_context = egl.CreateContext(state.egl_display, config, egl.NO_CONTEXT, &ctx_attributes[0])
	if state.egl_context == egl.NO_CONTEXT {
		log.fatal("could not create egl context")
		return
	}
	defer if !ok {
		egl.DestroyContext(state.egl_display, state.egl_context)
	}

	state.egl_window = wl.egl_window_create(state.surface, **state.window_size)
	if state.egl_window == nil {
		log.fatal("could not create wayland egl window")
		return
	}
	defer if !ok {
		wl.egl_window_destroy(state.egl_window)
	}

	state.egl_surface = egl.CreateWindowSurface(state.egl_display, config, egl.NativeWindowType(state.egl_window), nil)
	if state.egl_surface == egl.NO_SURFACE {
		log.fatal("could not create egl surface")
		return
	}
	defer if !ok {
		egl.DestroySurface(state.egl_display, state.egl_surface)
	}

	if !egl.MakeCurrent(state.egl_display, state.egl_surface, state.egl_surface, state.egl_context) {
		log.fatal("could not make egl context current")
		return
	}

	// egl.SwapInterval(state.egl_display, 0)

	gl.load_up_to(4, 6, proc(ptr: rawptr, s: cstring) {
		p := egl.GetProcAddress(s)
		(^rawptr)(ptr)^ = p
		if p == nil {
			log.warnf("missing OpenGL function %q", s)
		}
	})

	ok = true
	return
}

_frame :: proc() {
	context = state.ctx
	state.dispatched = false
	egl.SwapBuffers(state.egl_display, state.egl_surface)
	event_list_clear(&state.events)
}

_events :: proc() -> ^Event_List {
	context = state.ctx

	// poll events once per frame
	if !state.dispatched && wl.display_dispatch(state.display) == -1 {
		log.errorf("could not dispatch wayland display: %v", wl.display_get_error(state.display))
	}

	// handle keyboard repeat
	if (state.keyboard_next_deadline != time.Tick{} &&
		time.tick_diff(time.tick_now(), state.keyboard_next_deadline) < 0) {

		state.keyboard_next_deadline = time.tick_add(time.tick_now(), time.Second / time.Duration(state.keyboard_repeat_rate))

		keycode_pressed(state.keyboard_last_keycode)
	}

	state.dispatched = true

	return &state.events
}

_mouse :: proc() -> [2]f32 {
	return state.pointer_pos
}

_flags :: proc() -> Window_Flags {
	return state.flags
}

_size :: proc() -> [2]int {
	return linalg.array_cast(state.window_size, int)
}
