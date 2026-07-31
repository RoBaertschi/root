#+build linux
package wp

@require import "base:intrinsics"
@require import wl ".."
@require import wayland ".."

/*
Generated with love by robaertschi/root/wayland/scanner/v2

Copyright:
Copyright 2018 The Chromium Authors
Copyright 2023 Simon Ser

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice (including the next
paragraph) shall be included in all copies or substantial portions of the
Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/


@(private)
cursor_shape_v1_types := []^wl.interface {
	nil,
	nil,
	&cursor_shape_device_v1_interface,
	&wayland.pointer_interface,
	&cursor_shape_device_v1_interface,
	&tablet_tool_v2_interface,
}

/*
Summary: cursor shape manager

This global offers an alternative, optional way to set cursor images. This
new way uses enumerated cursors instead of a wl_surface like
wl_pointer.set_cursor does.

Warning! The protocol described in this file is currently in the testing
phase. Backward compatible changes may be added together with the
corresponding interface version bump. Backward incompatible changes can
only be done by creating a new major version of the extension.
Version: 2
*/
cursor_shape_manager_v1 :: distinct wl.proxy

cursor_shape_manager_v1_interface : wl.interface

cursor_shape_manager_v1_set_user_data :: proc "contextless" (cursor_shape_manager_v1: ^cursor_shape_manager_v1, user_data: rawptr) {
	wl.proxy_set_user_data(cast(^wl.proxy)cursor_shape_manager_v1, user_data)
}

cursor_shape_manager_v1_get_user_data :: proc "contextless" (cursor_shape_manager_v1: ^cursor_shape_manager_v1) -> rawptr {
	return wl.proxy_get_user_data(cast(^wl.proxy)cursor_shape_manager_v1)
}

CURSOR_SHAPE_MANAGER_V1_DESTROY :: 0
/*
Summary: destroy the manager

Destroy the cursor shape manager.
*/
cursor_shape_manager_v1_destroy :: proc "contextless" (cursor_shape_manager_v1: ^cursor_shape_manager_v1) {
	wl.proxy_marshal_flags(cast(^wl.proxy)cursor_shape_manager_v1, CURSOR_SHAPE_MANAGER_V1_DESTROY, nil, wl.proxy_get_version(cast(^wl.proxy)cursor_shape_manager_v1), 1 /* DESTROY */)
	return
}

CURSOR_SHAPE_MANAGER_V1_GET_POINTER :: 1
/*
Summary: manage the cursor shape of a pointer device

Obtain a wp_cursor_shape_device_v1 for a wl_pointer object.

When the pointer capability is removed from the wl_seat, the
wp_cursor_shape_device_v1 object becomes inert.
*/
cursor_shape_manager_v1_get_pointer :: proc "contextless" (cursor_shape_manager_v1: ^cursor_shape_manager_v1, pointer: ^wayland.pointer) -> (cursor_shape_device: ^cursor_shape_device_v1) {
	cursor_shape_device = cast(^cursor_shape_device_v1)wl.proxy_marshal_flags(cast(^wl.proxy)cursor_shape_manager_v1, CURSOR_SHAPE_MANAGER_V1_GET_POINTER, &cursor_shape_device_v1_interface, wl.proxy_get_version(cast(^wl.proxy)cursor_shape_manager_v1), 0, nil, pointer)
	return
}

CURSOR_SHAPE_MANAGER_V1_GET_TABLET_TOOL_V2 :: 2
/*
Summary: manage the cursor shape of a tablet tool device

Obtain a wp_cursor_shape_device_v1 for a zwp_tablet_tool_v2 object.

When the zwp_tablet_tool_v2 is removed, the wp_cursor_shape_device_v1
object becomes inert.
*/
cursor_shape_manager_v1_get_tablet_tool_v2 :: proc "contextless" (cursor_shape_manager_v1: ^cursor_shape_manager_v1, tablet_tool: ^tablet_tool_v2) -> (cursor_shape_device: ^cursor_shape_device_v1) {
	cursor_shape_device = cast(^cursor_shape_device_v1)wl.proxy_marshal_flags(cast(^wl.proxy)cursor_shape_manager_v1, CURSOR_SHAPE_MANAGER_V1_GET_TABLET_TOOL_V2, &cursor_shape_device_v1_interface, wl.proxy_get_version(cast(^wl.proxy)cursor_shape_manager_v1), 0, nil, tablet_tool)
	return
}

/*
Summary: cursor shape for a device

This interface allows clients to set the cursor shape.
Version: 2
*/
cursor_shape_device_v1 :: distinct wl.proxy

cursor_shape_device_v1_interface : wl.interface

/*
Summary: cursor shapes

This enum describes cursor shapes.

The names are taken from the CSS W3C specification:
https://w3c.github.io/csswg-drafts/css-ui/#cursor
with a few additions.

Note that there are some groups of cursor shapes that are related:
The first group is drag-and-drop cursors which are used to indicate
the selected action during dnd operations. The second group is resize
cursors which are used to indicate resizing and moving possibilities
on window borders. It is recommended that the shapes in these groups
should use visually compatible images and metaphors.
*/
cursor_shape_device_v1_shape :: enum u32 {
	default = 1, // default cursor
	context_menu = 2, // a context menu is available for the object under the cursor
	help = 3, // help is available for the object under the cursor
	pointer = 4, // pointer that indicates a link or another interactive element
	progress = 5, // progress indicator
	wait = 6, // program is busy, user should wait
	cell = 7, // a cell or set of cells may be selected
	crosshair = 8, // simple crosshair
	text = 9, // text may be selected
	vertical_text = 10, // vertical text may be selected
	alias = 11, // drag-and-drop: alias of/shortcut to something is to be created
	copy = 12, // drag-and-drop: something is to be copied
	move = 13, // drag-and-drop: something is to be moved
	no_drop = 14, // drag-and-drop: the dragged item cannot be dropped at the current cursor location
	not_allowed = 15, // drag-and-drop: the requested action will not be carried out
	grab = 16, // drag-and-drop: something can be grabbed
	grabbing = 17, // drag-and-drop: something is being grabbed
	e_resize = 18, // resizing: the east border is to be moved
	n_resize = 19, // resizing: the north border is to be moved
	ne_resize = 20, // resizing: the north-east corner is to be moved
	nw_resize = 21, // resizing: the north-west corner is to be moved
	s_resize = 22, // resizing: the south border is to be moved
	se_resize = 23, // resizing: the south-east corner is to be moved
	sw_resize = 24, // resizing: the south-west corner is to be moved
	w_resize = 25, // resizing: the west border is to be moved
	ew_resize = 26, // resizing: the east and west borders are to be moved
	ns_resize = 27, // resizing: the north and south borders are to be moved
	nesw_resize = 28, // resizing: the north-east and south-west corners are to be moved
	nwse_resize = 29, // resizing: the north-west and south-east corners are to be moved
	col_resize = 30, // resizing: that the item/column can be resized horizontally
	row_resize = 31, // resizing: that the item/row can be resized vertically
	all_scroll = 32, // something can be scrolled in any direction
	zoom_in = 33, // something can be zoomed in
	zoom_out = 34, // something can be zoomed out
	/*
	Since: 2
	*/
	dnd_ask = 35, // drag-and-drop: the user will select which action will be carried out (non-css value)
	/*
	Since: 2
	*/
	all_resize = 36, // resizing: something can be moved or resized in any direction (non-css value)
}

cursor_shape_device_v1_error :: enum u32 {
	invalid_shape = 1, // the specified shape value is invalid
}

cursor_shape_device_v1_set_user_data :: proc "contextless" (cursor_shape_device_v1: ^cursor_shape_device_v1, user_data: rawptr) {
	wl.proxy_set_user_data(cast(^wl.proxy)cursor_shape_device_v1, user_data)
}

cursor_shape_device_v1_get_user_data :: proc "contextless" (cursor_shape_device_v1: ^cursor_shape_device_v1) -> rawptr {
	return wl.proxy_get_user_data(cast(^wl.proxy)cursor_shape_device_v1)
}

CURSOR_SHAPE_DEVICE_V1_DESTROY :: 0
/*
Summary: destroy the cursor shape device

Destroy the cursor shape device.

The device cursor shape remains unchanged.
*/
cursor_shape_device_v1_destroy :: proc "contextless" (cursor_shape_device_v1: ^cursor_shape_device_v1) {
	wl.proxy_marshal_flags(cast(^wl.proxy)cursor_shape_device_v1, CURSOR_SHAPE_DEVICE_V1_DESTROY, nil, wl.proxy_get_version(cast(^wl.proxy)cursor_shape_device_v1), 1 /* DESTROY */)
	return
}

CURSOR_SHAPE_DEVICE_V1_SET_SHAPE :: 1
/*
Summary: set device cursor to the shape

Sets the device cursor to the specified shape. The compositor will
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
Otherwise the request will be ignored.
*/
cursor_shape_device_v1_set_shape :: proc "contextless" (cursor_shape_device_v1: ^cursor_shape_device_v1, serial: u32, shape: cursor_shape_device_v1_shape) {
	wl.proxy_marshal_flags(cast(^wl.proxy)cursor_shape_device_v1, CURSOR_SHAPE_DEVICE_V1_SET_SHAPE, nil, wl.proxy_get_version(cast(^wl.proxy)cursor_shape_device_v1), 0, serial, shape)
	return
}

@(private)
cursor_shape_manager_v1_requests := []wl.message {
	{"destroy", "", raw_data(cursor_shape_v1_types)[0:]},
	{"get_pointer", "no", raw_data(cursor_shape_v1_types)[2:]},
	{"get_tablet_tool_v2", "no", raw_data(cursor_shape_v1_types)[4:]},
}

@(private)
cursor_shape_device_v1_requests := []wl.message {
	{"destroy", "", raw_data(cursor_shape_v1_types)[0:]},
	{"set_shape", "uu", raw_data(cursor_shape_v1_types)[0:]},
}

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
