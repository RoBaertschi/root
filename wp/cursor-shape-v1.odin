#+build linux
package wp
@(private)
cursor_shape_v1_types := []^interface {
	nil,
	nil,
	&cursor_shape_device_v1_interface,
	&wl.pointer_interface,
	&cursor_shape_device_v1_interface,
	&tablet_tool_v2_interface,
}
/* This global offers an alternative, optional way to set cursor images. This
      new way uses enumerated cursors instead of a wl_surface like
      wl_pointer.set_cursor does.

      Warning! The protocol described in this file is currently in the testing
      phase. Backward compatible changes may be added together with the
      corresponding interface version bump. Backward incompatible changes can
      only be done by creating a new major version of the extension. */
cursor_shape_manager_v1 :: struct {}
cursor_shape_manager_v1_set_user_data :: proc "contextless" (cursor_shape_manager_v1_: ^cursor_shape_manager_v1, user_data: rawptr) {
   proxy_set_user_data(cast(^proxy)cursor_shape_manager_v1_, user_data)
}

cursor_shape_manager_v1_get_user_data :: proc "contextless" (cursor_shape_manager_v1_: ^cursor_shape_manager_v1) -> rawptr {
   return proxy_get_user_data(cast(^proxy)cursor_shape_manager_v1_)
}

/* Destroy the cursor shape manager. */
CURSOR_SHAPE_MANAGER_V1_DESTROY :: 0
cursor_shape_manager_v1_destroy :: proc "contextless" (cursor_shape_manager_v1_: ^cursor_shape_manager_v1) {
	proxy_marshal_flags(cast(^proxy)cursor_shape_manager_v1_, CURSOR_SHAPE_MANAGER_V1_DESTROY, nil, proxy_get_version(cast(^proxy)cursor_shape_manager_v1_), 1)
}

/* Obtain a wp_cursor_shape_device_v1 for a wl_pointer object.

        When the pointer capability is removed from the wl_seat, the
        wp_cursor_shape_device_v1 object becomes inert. */
CURSOR_SHAPE_MANAGER_V1_GET_POINTER :: 1
cursor_shape_manager_v1_get_pointer :: proc "contextless" (cursor_shape_manager_v1_: ^cursor_shape_manager_v1, pointer_: ^wl.pointer) -> ^cursor_shape_device_v1 {
	ret := proxy_marshal_flags(cast(^proxy)cursor_shape_manager_v1_, CURSOR_SHAPE_MANAGER_V1_GET_POINTER, &cursor_shape_device_v1_interface, proxy_get_version(cast(^proxy)cursor_shape_manager_v1_), 0, nil, pointer_)
	return cast(^cursor_shape_device_v1)ret
}

/* Obtain a wp_cursor_shape_device_v1 for a zwp_tablet_tool_v2 object.

        When the zwp_tablet_tool_v2 is removed, the wp_cursor_shape_device_v1
        object becomes inert. */
CURSOR_SHAPE_MANAGER_V1_GET_TABLET_TOOL_V2 :: 2
cursor_shape_manager_v1_get_tablet_tool_v2 :: proc "contextless" (cursor_shape_manager_v1_: ^cursor_shape_manager_v1, tablet_tool_: ^tablet_tool_v2) -> ^cursor_shape_device_v1 {
	ret := proxy_marshal_flags(cast(^proxy)cursor_shape_manager_v1_, CURSOR_SHAPE_MANAGER_V1_GET_TABLET_TOOL_V2, &cursor_shape_device_v1_interface, proxy_get_version(cast(^proxy)cursor_shape_manager_v1_), 0, nil, tablet_tool_)
	return cast(^cursor_shape_device_v1)ret
}

@(private)
cursor_shape_manager_v1_requests := []message {
	{"destroy", "", raw_data(cursor_shape_v1_types)[0:]},
	{"get_pointer", "no", raw_data(cursor_shape_v1_types)[2:]},
	{"get_tablet_tool_v2", "no", raw_data(cursor_shape_v1_types)[4:]},
}

cursor_shape_manager_v1_interface : interface

/* This interface allows clients to set the cursor shape. */
cursor_shape_device_v1 :: struct {}
cursor_shape_device_v1_set_user_data :: proc "contextless" (cursor_shape_device_v1_: ^cursor_shape_device_v1, user_data: rawptr) {
   proxy_set_user_data(cast(^proxy)cursor_shape_device_v1_, user_data)
}

cursor_shape_device_v1_get_user_data :: proc "contextless" (cursor_shape_device_v1_: ^cursor_shape_device_v1) -> rawptr {
   return proxy_get_user_data(cast(^proxy)cursor_shape_device_v1_)
}

/* Destroy the cursor shape device.

        The device cursor shape remains unchanged. */
CURSOR_SHAPE_DEVICE_V1_DESTROY :: 0
cursor_shape_device_v1_destroy :: proc "contextless" (cursor_shape_device_v1_: ^cursor_shape_device_v1) {
	proxy_marshal_flags(cast(^proxy)cursor_shape_device_v1_, CURSOR_SHAPE_DEVICE_V1_DESTROY, nil, proxy_get_version(cast(^proxy)cursor_shape_device_v1_), 1)
}

/* Sets the device cursor to the specified shape. The compositor will
        change the cursor image based on the specified shape.

        The cursor actually changes only if the input device focus is one of
        the requesting client's surfaces. If any, the previous cursor image
        (surface or shape) is replaced.

        The "shape" argument must be a valid enum entry, otherwise the
        invalid_shape protocol error is raised.

        This is similar to the wl_pointer.set_cursor and
        zwp_tablet_tool_v2.set_cursor requests, but this request accepts a
        shape instead of contents in the form of a surface. Clients can mix
        set_cursor and set_shape requests.

        The serial parameter must match the latest wl_pointer.enter or
        zwp_tablet_tool_v2.proximity_in serial number sent to the client.
        Otherwise the request will be ignored. */
CURSOR_SHAPE_DEVICE_V1_SET_SHAPE :: 1
cursor_shape_device_v1_set_shape :: proc "contextless" (cursor_shape_device_v1_: ^cursor_shape_device_v1, serial_: u32, shape_: cursor_shape_device_v1_shape) {
	proxy_marshal_flags(cast(^proxy)cursor_shape_device_v1_, CURSOR_SHAPE_DEVICE_V1_SET_SHAPE, nil, proxy_get_version(cast(^proxy)cursor_shape_device_v1_), 0, serial_, shape_)
}

/* This enum describes cursor shapes.

        The names are taken from the CSS W3C specification:
        https://w3c.github.io/csswg-drafts/css-ui/#cursor
        with a few additions.

        Note that there are some groups of cursor shapes that are related:
        The first group is drag-and-drop cursors which are used to indicate
        the selected action during dnd operations. The second group is resize
        cursors which are used to indicate resizing and moving possibilities
        on window borders. It is recommended that the shapes in these groups
        should use visually compatible images and metaphors. */
cursor_shape_device_v1_shape :: enum {
	default = 1,
	context_menu = 2,
	help = 3,
	pointer = 4,
	progress = 5,
	wait = 6,
	cell = 7,
	crosshair = 8,
	text = 9,
	vertical_text = 10,
	alias = 11,
	copy = 12,
	move = 13,
	no_drop = 14,
	not_allowed = 15,
	grab = 16,
	grabbing = 17,
	e_resize = 18,
	n_resize = 19,
	ne_resize = 20,
	nw_resize = 21,
	s_resize = 22,
	se_resize = 23,
	sw_resize = 24,
	w_resize = 25,
	ew_resize = 26,
	ns_resize = 27,
	nesw_resize = 28,
	nwse_resize = 29,
	col_resize = 30,
	row_resize = 31,
	all_scroll = 32,
	zoom_in = 33,
	zoom_out = 34,
	dnd_ask = 35,
	all_resize = 36,
}
/*  */
cursor_shape_device_v1_error :: enum {
	invalid_shape = 1,
}
@(private)
cursor_shape_device_v1_requests := []message {
	{"destroy", "", raw_data(cursor_shape_v1_types)[0:]},
	{"set_shape", "uu", raw_data(cursor_shape_v1_types)[0:]},
}

cursor_shape_device_v1_interface : interface

@(private)
@(init)
init_interfaces_cursor_shape_v1 :: proc "contextless" () {
	cursor_shape_manager_v1_interface.name = "wp_cursor_shape_manager_v1"
	cursor_shape_manager_v1_interface.version = 2
	cursor_shape_manager_v1_interface.method_count = 3
	cursor_shape_manager_v1_interface.event_count = 0
	cursor_shape_manager_v1_interface.methods = raw_data(cursor_shape_manager_v1_requests)
	cursor_shape_device_v1_interface.name = "wp_cursor_shape_device_v1"
	cursor_shape_device_v1_interface.version = 2
	cursor_shape_device_v1_interface.method_count = 2
	cursor_shape_device_v1_interface.event_count = 0
	cursor_shape_device_v1_interface.methods = raw_data(cursor_shape_device_v1_requests)
}

// Functions from libwayland-client
import wl ".."
