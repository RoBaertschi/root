#+private
package root_window2

import "core:log"
import "core:time"
import "core:c"
import "core:sys/posix"
import "core:mem/virtual"

import WL "../wayland"
import XDG "../wayland/xdg"
import XKB "../window/xkbcommon"

import B "../base"

// #region Event

_Interaction_Key :: distinct u32

// #endregion

// #region Window

@(private="package")
_Window_Platform :: struct {}

_window_platform_init :: proc(w: ^Window) {
}

// #endregion

// #region Listeners


Wl_Button :: enum u32 {
	Left   = 0x110,
	Right  = 0x111,
	Middle = 0x112,
}

wl_pointer_listener := WL.pointer_listener{
	enter = proc "c"(data: rawptr, pointer: ^WL.pointer, serial_: u32, surface: ^WL.surface, surface_x: WL.fixed_t, surface_y: WL.fixed_t) {
		s := cast(^State)data
		p := &s._platform
		

		WL.pointer_set_cursor(pointer, serial_, p.cursor_surface, i32(p.cursor_image.hotspot_x), i32(p.cursor_image.hotspot_y))

		// TODO(robin): find window for event
		unimplemented_contextless()

		// if surface == p.surface {
		// 	p.pointer_pos = { WL.fixed_to_f32(surface_x), WL.fixed_to_f32(surface_y) }
		// }
	},
	leave = proc "c"(data: rawptr, pointer: ^WL.pointer, serial_: u32, surface_: ^WL.surface) {},
	motion = proc "c"(data: rawptr, pointer: ^WL.pointer, time: u32, surface_x: WL.fixed_t, surface_y: WL.fixed_t) {
		s := cast(^State)data
		p := &s._platform
		p.pointer_pos = { WL.fixed_to_f32(surface_x), WL.fixed_to_f32(surface_y) }
	},
	button = auto_cast proc "c"(data: rawptr, pointer: ^WL.pointer, serial: u32, time: u32, button_: u32, button_state_: u32) {
		s := cast(^State)data
		p := &s._platform
		
		button_state := WL.pointer_button_state(button_state_)
		button       := Wl_Button(button_)

		@static
		button_lookup := [Wl_Button]Event_Key{
			.Left   = .Mouse_Left,
			.Right  = .Mouse_Right,
			.Middle = .Mouse_Middle,
		}

		@static
		button_state_lookup := [WL.pointer_button_state]Event_Key_State{
			.released = .Released,
			.pressed  = .Pressed,
		}

		context = s.ctx

		// TODO(robin): implement hit testing
		// if button_state == .pressed && s.decoration_hit_proc != nil {
		// 	result := p.decoration_hit_proc(p.pointer_pos)
		// 	switch result {
		// 	case .None:
		// 	case .Resize_Top..=.Resize_Bottom_Right:
		// 		@static
		// 		wl_resize_lookup := #partial [Decoration_Hit_Result]xdg.toplevel_resize_edge{
		// 			.Resize_Top          = .top,
		// 			.Resize_Bottom       = .bottom,
		// 			.Resize_Left         = .left,
		// 			.Resize_Right        = .right,
		// 			.Resize_Top_Left     = .top_left,
		// 			.Resize_Bottom_Left  = .bottom_left,
		// 			.Resize_Top_Right    = .top_right,
		// 			.Resize_Bottom_Right = .bottom_right,
		// 		}
		// 		xdg.toplevel_resize(
		// 			state.xdg_toplevel,
		// 			state.seat,
		// 			serial,
		// 			wl_resize_lookup[result],
		// 		)
		// 	case .Draggable:
		// 		xdg.toplevel_move(
		// 			state.xdg_toplevel,
		// 			state.seat,
		// 			serial,
		// 		)
		// 	}
		// }

		event_list_push(
			&s.events,
			Event {
				kind        = .Key,
				pos         = p.pointer_pos,
				key         = button_lookup[button],
				key_state   = button_state_lookup[button_state],
				interaction = Interaction_Key(serial),
			},
		)

		// if button == .Left {
		// 	xdg.toplevel_move(state.xdg_toplevel, state.seat, serial)
		// } else if button == .Right {
		// 	xdg.toplevel_resize(state.xdg_toplevel, state.seat, serial, .bottom_right)
		// }
	},
	axis = auto_cast proc "c"(data: rawptr, pointer: ^WL.pointer, time_: u32, axis_: u32, value_: WL.fixed_t) {
		axis := WL.pointer_axis(axis_)
	},
	frame = proc "c"(data: rawptr, pointer: ^WL.pointer) {
		// TODO(robin): dispatch collected data
	},
	axis_source = auto_cast proc "c"(data: rawptr, pointer: ^WL.pointer, axis_source_: u32) {
		axis_source := WL.pointer_axis_source(axis_source_)
	},
	axis_stop = proc "c"(data: rawptr, pointer: ^WL.pointer, time_: u32, axis_: WL.pointer_axis) {},
	axis_discrete = auto_cast proc "c"(data: rawptr, pointer: ^WL.pointer, axis_: u32, discrete_: i32) {
		axis := WL.pointer_axis(axis_)
	},
}

// #region Keyboard Helpers

keysym_push :: proc(key: Key) {
	node: ^Key_Node
	if platform.free_keys != nil {
		node               = platform.free_keys
		platform.free_keys = node.next
		node^              = {}
	} else {
		node = B.arena_new(arena(), Key_Node)
	}

	node.key              = key
	node.next             = platform.pressed_keys
	platform.pressed_keys = node
}

keysym_is_pressed :: proc(keysym: XKB.keysym_t) -> bool {
	for node := platform.pressed_keys; node != nil; node = node.next {
		if node.key.keysym == keysym {
			return true
		}
	}

	return false
}

keysym_remove :: proc(keysym: XKB.keysym_t) {
	next_ptr := &platform.pressed_keys

	for node := platform.pressed_keys; node != nil; node = node.next {
		if node.key.keysym == keysym {
			next_ptr^       = node.next
			platform.free_keys = node
			return
		}

		next_ptr = &node.next
	}
	// not found
}

event_key_from_xkb_keysym :: proc(keysym: XKB.keysym_t) -> Event_Key {
	#partial switch XKB.keysyms(keysym) {
	case .a..=.z:       return .A + Event_Key(keysym - XKB.keysym_t(XKB.keysyms.a))
	case ._0..=._9:     return .Num_0 + Event_Key(keysym - XKB.keysym_t(XKB.keysyms._0))
	case .F1..=.F12:    return .F1 + Event_Key(keysym - XKB.keysym_t(XKB.keysyms.F1))

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

event_modifiers_from_xkb_state :: proc(xkb_state: ^XKB.state) -> (modifiers: Event_Modifiers) {
	if XKB.state_mod_name_is_active(xkb_state, XKB.MOD_NAME_SHIFT, .MODS_EFFECTIVE) > 0 {
		modifiers += {.Shift}
	}
	if XKB.state_mod_name_is_active(xkb_state, XKB.MOD_NAME_CTRL, .MODS_EFFECTIVE) > 0 {
		modifiers += {.Control}
	}
	if XKB.state_mod_name_is_active(xkb_state, XKB.VMOD_NAME_ALT, .MODS_EFFECTIVE) > 0 {
		modifiers += {.Alt}
	}
	if XKB.state_mod_name_is_active(xkb_state, XKB.VMOD_NAME_SUPER, .MODS_EFFECTIVE) > 0 {
		modifiers += {.Super}
	}
	return
}

event_list_push_keysym :: proc(keysym: XKB.keysym_t, mods: Event_Modifiers, key_state: Event_Key_State, serial: u32) {
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
			kind        = .Key,
			modifiers   = mods,
			key         = event_key,
			key_state   = key_state,
			interaction = Interaction_Key(serial),
		},
	)
}

keysym_from_keycode_level_0_only :: proc(keycode: XKB.keycode_t) -> XKB.keysym_t {
	out_raw: [^]XKB.keysym_t
	count := XKB.keymap_key_get_syms_by_level(platform.xkb_mapping, keycode, 0, 0, &out_raw)
	out := out_raw[:count]

	if len(out) > 1 || len(out) < 1 {
		return XKB.keysym_t(XKB.keysyms.NoSymbol)
	}

	return out[0]
}

keycode_pressed :: proc(keycode: XKB.keycode_t, serial: u32) {
	keysym := keysym_from_keycode_level_0_only(keycode)

	if XKB.keymap_key_repeats(platform.xkb_mapping, keycode) {
		platform.keyboard_last_keycode = keycode
		platform.keyboard_last_serial  = serial
		platform.keyboard_next_deadline = time.tick_add(
			time.tick_now(),
			time.Duration(platform.keyboard_repeat_delay) * time.Millisecond,
		)
	}

	mods := event_modifiers_from_xkb_state(platform.xkb_state)

	if is_shortcut(keysym) {
		event_list_push_keysym(keysym, mods, .Pressed, serial)
	} else {
		temp := B.TEMP_ALLOCATOR_GUARD()
		result := ""

		key_get_utf8 :: proc(keycode: XKB.keycode_t, arena: ^virtual.Arena) -> string {
			result_size := XKB.state_key_get_utf8(platform.xkb_state, keycode, nil, 0)
			if result_size <= 0 {
				return ""
			}

			result_data := B.arena_make(arena, []u8, result_size + 1)
			XKB.state_key_get_utf8(platform.xkb_state, keycode, raw_data(result_data), len(result_data))
			return string(cstring(raw_data(result_data)))
		}

		if platform.xkb_compose_state != nil {
			XKB.compose_state_feed(platform.xkb_compose_state, keysym)
			status := XKB.compose_state_get_status(platform.xkb_compose_state)

			switch status {
			case .COMPOSING: // do nothing
			case .COMPOSED:
				result_size := XKB.compose_state_get_utf8(platform.xkb_compose_state, nil, 0)
				result_data := B.arena_make(temp.arena, []u8, result_size + 1)
				XKB.compose_state_get_utf8(platform.xkb_compose_state, raw_data(result_data), len(result_data))
				XKB.compose_state_reset(platform.xkb_compose_state)

				result = string(cstring(raw_data(result_data)))
			case .NOTHING:
				result = key_get_utf8(keycode, temp.arena)
			case .CANCELLED:
				XKB.compose_state_reset(platform.xkb_compose_state)
			}
		} else {
			result = key_get_utf8(keycode, temp.arena)
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

is_shortcut :: proc(keysym: XKB.keysym_t) -> bool {
	#partial switch XKB.keysyms(keysym) {
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
		mods := event_modifiers_from_xkb_state(platform.xkb_state)
		return .Control in mods || .Super in mods
	}
}

// #endregion

wl_keyboard_listener := WL.keyboard_listener{
	enter = proc "c"(data: rawptr, keyboard: ^WL.keyboard, serial_: u32, surface_: ^WL.surface, keys_: WL.array) {},

	leave = proc "c"(data: rawptr, keyboard: ^WL.keyboard, serial: u32, surface_: ^WL.surface) {
		s := cast(^State)data
		p := &s._platform
		
		context = s.ctx

		node := p.pressed_keys
		for node != nil {
			event_list_push(
				&s.events,
				Event {
					kind        = .Key,
					key         = node.key.key,
					key_state   = .Released,
					modifiers   = event_modifiers_from_xkb_state(p.xkb_state),
					interaction = Interaction_Key(serial),
				},
			)

			next := node.next
			node.next       = p.free_keys
			p.free_keys = node
			node = next
		}
		p.pressed_keys = nil

		XKB.state_update_mask(p.xkb_state, 0, 0, 0, 0, 0, 0)
		p.keyboard_last_keycode  = {}
		p.keyboard_last_serial   = {}
		p.keyboard_next_deadline = {}

		if p.xkb_compose_state != nil {
			XKB.compose_state_reset(p.xkb_compose_state)
		}
	},

	keymap = proc "c"(data: rawptr, keyboard: ^WL.keyboard, format: WL.keyboard_keymap_format, fd: i32, size: u32) {
		s := cast(^State)data
		p := &s._platform
		
		context = s.ctx

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

		p.xkb_mapping       = XKB.keymap_new_from_string(p.xkb_ctx, cast(cstring)keymap, .TEXT_V1, {})
		p.xkb_state         = XKB.state_new(p.xkb_mapping)
		p.xkb_compose_table = XKB.compose_table_new_from_locale(p.xkb_ctx, locale, {})
		if p.xkb_compose_table == nil {
			log.errorf("could not create xkb compose table")
		} else {
			p.xkb_compose_state = XKB.compose_state_new(p.xkb_compose_table, {})
		}
	},

	key = proc "c"(data: rawptr, keyboard: ^WL.keyboard, serial: u32, time_: u32, key: u32, key_state: WL.keyboard_key_state) {
		s := cast(^State)data
		p := &s._platform
		
		context = s.ctx

		keycode := XKB.keycode_t(key + 8)

		switch key_state {
		case .pressed, .repeated:  // .repeated is technically not because of the bound version but you never know
			keycode_pressed(keycode, serial)
		case .released:
			if key_state != .pressed {
				if p.keyboard_last_keycode == keycode {
					p.keyboard_next_deadline = {}
					p.keyboard_last_serial   = {}
				}

				mods   := event_modifiers_from_xkb_state(p.xkb_state)
				keysym := keysym_from_keycode_level_0_only(keycode)
				if keysym_is_pressed(keysym) {
					event_list_push_keysym(keysym, mods, .Released, serial)
				}

				return
			}
		}
	},

	modifiers = proc "c"(data: rawptr, keyboard: ^WL.keyboard, serial_: u32, mods_depressed_: u32, mods_latched_: u32, mods_locked_: u32, group_: u32) {
		s := cast(^State)data
		p := &s._platform
		
		XKB.state_update_mask(
			p.xkb_state,
			XKB.mod_mask_t(mods_depressed_),
			XKB.mod_mask_t(mods_latched_),
			XKB.mod_mask_t(mods_locked_),
			0,
			0,
			XKB.layout_index_t(group_),
		)
	},

	repeat_info = proc "c"(data: rawptr, keyboard: ^WL.keyboard, rate: i32, delay: i32) {
		s := cast(^State)data
		p := &s._platform

		p.keyboard_repeat_delay = delay
		p.keyboard_repeat_rate  = rate
	},
}

wl_seat_listener := WL.seat_listener{
	capabilities = auto_cast proc "c"(data: rawptr, seat: ^WL.seat, capabilities: bit_set[Seat_Capability; i32]) {
		s := cast(^State)data
		p := &s._platform

		p.seat_capabilities = capabilities

		if .pointer in p.seat_capabilities {
			p.pointer = WL.seat_get_pointer(seat)
			WL.pointer_add_listener(p.pointer.?, &wl_pointer_listener, s)
		} else if p.pointer != nil {
			WL.pointer_release(p.pointer.?)
			WL.pointer_destroy(p.pointer.?)
		}

		if .keyboard in p.seat_capabilities {
			p.keyboard = WL.seat_get_keyboard(seat)
			WL.keyboard_add_listener(p.keyboard.?, &wl_keyboard_listener, s)
		} else if p.keyboard != nil {
			WL.keyboard_release(p.keyboard.?)
			WL.keyboard_destroy(p.keyboard.?)
		}
	},
	name = proc "c"(data: rawptr, seat: ^WL.seat, name_: cstring) {},
}


xdg_wm_base_listener := XDG.wm_base_listener{
	ping = proc "c"(data: rawptr, wm_base: ^XDG.wm_base, serial: u32) {
		XDG.wm_base_pong(wm_base, serial)
	},
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

platform: ^_State_Platform

_state_platform_init :: proc(s: ^State) -> (ok: bool) {
	p        := &s._platform
	platform  = p

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
				WL.seat_add_listener(p.seat, &wl_seat_listener, s)
			case WL.shm_interface.name:
				p.shm = cast(^WL.shm)WL.registry_bind(registry, name, &WL.shm_interface, 1)
			case XDG.wm_base_interface.name:
				p.xdg_wm_base = cast(^XDG.wm_base)WL.registry_bind(registry, name, &XDG.wm_base_interface, min(version, 5))
				XDG.wm_base_add_listener(p.xdg_wm_base, &xdg_wm_base_listener, s)
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

	if p.compositor == nil {
		log.fatal("no wl.compositor, broken compositor?")
		return
	}

	if p.seat == nil {
		log.fatal("no wl.seat, broken compositor?")
		return
	}

	if p.xdg_wm_base == nil {
		log.fatal("no xdg.wm_base, compositor without wm support?")
		return
	}

	ok = true
	return
}

// #endregion
