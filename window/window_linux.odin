package root_window

import "core:math/bits"
import "core:strings"
import "core:log"
import "base:runtime"
import "core:mem/virtual"
import wl "../wayland"
import "../wayland/xdg"
import "vendor:egl"
import gl "vendor:OpenGL"
import "../base"


State :: struct {
	ctx:         runtime.Context,
	window_size: [2]i32,
	arena:       virtual.Arena,
	events:      Event_List,

	display:     ^wl.display,
	registry:    ^wl.registry,
	compositor:  ^wl.compositor,
	xdg_wm_base: ^xdg.wm_base,

	surface:                ^wl.surface,
	region:                 ^wl.region,
	xdg_surface:            ^xdg.surface,
	xdg_surface_configured: bool,
	xdg_toplevel:           ^xdg.toplevel,

	egl_context: egl.Context,
	egl_display: egl.Display,
	egl_surface: egl.Surface,
	egl_window:  ^wl.egl_window,
}

@private
_state_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(&state.arena)
}

state: State

@private
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
}

@private
xdg_surface_listener := xdg.surface_listener{
	configure = proc "c"(data: rawptr, surface: ^xdg.surface, serial: u32) {
		xdg.surface_ack_configure(surface, serial)
		state.xdg_surface_configured = true
	},
}

@private
xdg_wm_base_listener := xdg.wm_base_listener{
	ping = proc "c"(data: rawptr, wm_base: ^xdg.wm_base, serial: u32) {
		xdg.wm_base_pong(wm_base, serial)
	},
}

@private
_init :: proc(desc: Init_Description) -> (ok: bool) {
	base.perf_scoped()

	assert(desc.size.x <= bits.I32_MAX)
	assert(desc.size.y <= bits.I32_MAX)
	assert(desc.size.x >= bits.I32_MIN)
	assert(desc.size.y >= bits.I32_MIN)

	state = {}

	context.logger = log.create_console_logger(ident = "WINDOW")
	state.ctx = context

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
			case xdg.wm_base_interface.name:
				state.xdg_wm_base = cast(^xdg.wm_base)wl.registry_bind(registry, name, &xdg.wm_base_interface, version)
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

@private
_frame :: proc() {
	gl.ClearColor(1, 1, 1, 1)
	gl.Clear(gl.COLOR_BUFFER_BIT)
	egl.SwapBuffers(state.egl_display, state.egl_surface)
}

@private
_events :: proc() -> ^Event_List {
	if wl.display_dispatch(state.display) == -1 {
		log.errorf("could not dispatch wayland display: %v", wl.display_get_error(state.display))
	}

	return &state.events
}
