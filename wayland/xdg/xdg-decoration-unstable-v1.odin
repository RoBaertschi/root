#+build linux
package xdg

@require import "base:intrinsics"
@require import wl ".."

/*
Generated with love by robaertschi/root/wayland/scanner/v2

Copyright:
Copyright © 2018 Simon Ser

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
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/


@(private)
xdg_decoration_unstable_v1_types := []^wl.interface {
	nil,
	&toplevel_decoration_v1_interface,
	&toplevel_interface,
}

/*
Summary: window decoration manager

This interface allows a compositor to announce support for server-side
decorations.

A window decoration is a set of window controls as deemed appropriate by
the party managing them, such as user interface components used to move,
resize and change a window's state.

A client can use this protocol to request being decorated by a supporting
compositor.

If compositor and client do not negotiate the use of a server-side
decoration using this protocol, clients continue to self-decorate as they
see fit.

Warning! The protocol described in this file is experimental and
backward incompatible changes may be made. Backward compatible changes
may be added together with the corresponding interface version bump.
Backward incompatible changes are done by bumping the version number in
the protocol and interface names and resetting the interface version.
Once the protocol is to be declared stable, the 'z' prefix and the
version number in the protocol and interface names are removed and the
interface version number is reset.
Version: 1
*/
decoration_manager_v1 :: distinct wl.proxy

decoration_manager_v1_interface : wl.interface

decoration_manager_v1_set_user_data :: proc "contextless" (decoration_manager_v1: ^decoration_manager_v1, user_data: rawptr) {
	wl.proxy_set_user_data(cast(^wl.proxy)decoration_manager_v1, user_data)
}

decoration_manager_v1_get_user_data :: proc "contextless" (decoration_manager_v1: ^decoration_manager_v1) -> rawptr {
	return wl.proxy_get_user_data(cast(^wl.proxy)decoration_manager_v1)
}

DECORATION_MANAGER_V1_DESTROY :: 0
/*
Summary: destroy the decoration manager object

Destroy the decoration manager. This doesn't destroy objects created
with the manager.
*/
decoration_manager_v1_destroy :: proc "contextless" (decoration_manager_v1: ^decoration_manager_v1) {
	wl.proxy_marshal_flags(cast(^wl.proxy)decoration_manager_v1, DECORATION_MANAGER_V1_DESTROY, nil, wl.proxy_get_version(cast(^wl.proxy)decoration_manager_v1), 1 /* DESTROY */)
	return
}

DECORATION_MANAGER_V1_GET_TOPLEVEL_DECORATION :: 1
/*
Summary: create a new toplevel decoration object

Create a new decoration object associated with the given toplevel.

Creating an xdg_toplevel_decoration from an xdg_toplevel which has a
buffer attached or committed is a client error, and any attempts by a
client to attach or manipulate a buffer prior to the first
xdg_toplevel_decoration.configure event must also be treated as
errors.
*/
decoration_manager_v1_get_toplevel_decoration :: proc "contextless" (decoration_manager_v1: ^decoration_manager_v1, toplevel: ^toplevel) -> (id: ^toplevel_decoration_v1) {
	id = cast(^toplevel_decoration_v1)wl.proxy_marshal_flags(cast(^wl.proxy)decoration_manager_v1, DECORATION_MANAGER_V1_GET_TOPLEVEL_DECORATION, &toplevel_decoration_v1_interface, wl.proxy_get_version(cast(^wl.proxy)decoration_manager_v1), 0, nil, toplevel)
	return
}

/*
Summary: decoration object for a toplevel surface

The decoration object allows the compositor to toggle server-side window
decorations for a toplevel surface. The client can request to switch to
another mode.

The xdg_toplevel_decoration object must be destroyed before its
xdg_toplevel.
Version: 1
*/
toplevel_decoration_v1 :: distinct wl.proxy

toplevel_decoration_v1_interface : wl.interface

toplevel_decoration_v1_error :: enum u32 {
	unconfigured_buffer = 0, // xdg_toplevel has a buffer attached before configure
	already_constructed = 1, // xdg_toplevel already has a decoration object
	orphaned = 2, // xdg_toplevel destroyed before the decoration object
	invalid_mode = 3, // invalid mode
}

/*
Summary: window decoration modes

These values describe window decoration modes.
*/
toplevel_decoration_v1_mode :: enum u32 {
	client_side = 1, // no server-side window decoration
	server_side = 2, // server-side window decoration
}

toplevel_decoration_v1_set_user_data :: proc "contextless" (toplevel_decoration_v1: ^toplevel_decoration_v1, user_data: rawptr) {
	wl.proxy_set_user_data(cast(^wl.proxy)toplevel_decoration_v1, user_data)
}

toplevel_decoration_v1_get_user_data :: proc "contextless" (toplevel_decoration_v1: ^toplevel_decoration_v1) -> rawptr {
	return wl.proxy_get_user_data(cast(^wl.proxy)toplevel_decoration_v1)
}

TOPLEVEL_DECORATION_V1_DESTROY :: 0
/*
Summary: destroy the decoration object

Switch back to a mode without any server-side decorations at the next
commit.
*/
toplevel_decoration_v1_destroy :: proc "contextless" (toplevel_decoration_v1: ^toplevel_decoration_v1) {
	wl.proxy_marshal_flags(cast(^wl.proxy)toplevel_decoration_v1, TOPLEVEL_DECORATION_V1_DESTROY, nil, wl.proxy_get_version(cast(^wl.proxy)toplevel_decoration_v1), 1 /* DESTROY */)
	return
}

TOPLEVEL_DECORATION_V1_SET_MODE :: 1
/*
Summary: set the decoration mode

Set the toplevel surface decoration mode. This informs the compositor
that the client prefers the provided decoration mode.

After requesting a decoration mode, the compositor will respond by
emitting an xdg_surface.configure event. The client should then update
its content, drawing it without decorations if the received mode is
server-side decorations. The client must also acknowledge the configure
when committing the new content (see xdg_surface.ack_configure).

The compositor can decide not to use the client's mode and enforce a
different mode instead.

Clients whose decoration mode depend on the xdg_toplevel state may send
a set_mode request in response to an xdg_surface.configure event and wait
for the next xdg_surface.configure event to prevent unwanted state.
Such clients are responsible for preventing configure loops and must
make sure not to send multiple successive set_mode requests with the
same decoration mode.

If an invalid mode is supplied by the client, the invalid_mode protocol
error is raised by the compositor.
*/
toplevel_decoration_v1_set_mode :: proc "contextless" (toplevel_decoration_v1: ^toplevel_decoration_v1, mode: toplevel_decoration_v1_mode) {
	wl.proxy_marshal_flags(cast(^wl.proxy)toplevel_decoration_v1, TOPLEVEL_DECORATION_V1_SET_MODE, nil, wl.proxy_get_version(cast(^wl.proxy)toplevel_decoration_v1), 0, mode)
	return
}

TOPLEVEL_DECORATION_V1_UNSET_MODE :: 2
/*
Summary: unset the decoration mode

Unset the toplevel surface decoration mode. This informs the compositor
that the client doesn't prefer a particular decoration mode.

This request has the same semantics as set_mode.
*/
toplevel_decoration_v1_unset_mode :: proc "contextless" (toplevel_decoration_v1: ^toplevel_decoration_v1) {
	wl.proxy_marshal_flags(cast(^wl.proxy)toplevel_decoration_v1, TOPLEVEL_DECORATION_V1_UNSET_MODE, nil, wl.proxy_get_version(cast(^wl.proxy)toplevel_decoration_v1), 0)
	return
}

toplevel_decoration_v1_listener :: struct {
	/*
	Summary: notify a decoration mode change

	The configure event configures the effective decoration mode. The
	configured state should not be applied immediately. Clients must send an
	ack_configure in response to this event. See xdg_surface.configure and
	xdg_surface.ack_configure for details.
	
	A configure event can be sent at any time. The specified mode must be
	obeyed by the client.
	*/
	configure: proc "c" (data: rawptr, toplevel_decoration_v1: ^toplevel_decoration_v1, mode: toplevel_decoration_v1_mode),
}

toplevel_decoration_v1_add_listener :: proc "contextless" (toplevel_decoration_v1: ^toplevel_decoration_v1, listener: ^toplevel_decoration_v1_listener, data: rawptr) {
	wl.proxy_add_listener(cast(^wl.proxy)toplevel_decoration_v1, cast(^wl.generic_c_call)listener, data)
}

@(private)
decoration_manager_v1_requests := []wl.message {
	{"destroy", "", raw_data(xdg_decoration_unstable_v1_types)[0:]},
	{"get_toplevel_decoration", "no", raw_data(xdg_decoration_unstable_v1_types)[1:]},
}

@(private)
toplevel_decoration_v1_requests := []wl.message {
	{"destroy", "", raw_data(xdg_decoration_unstable_v1_types)[0:]},
	{"set_mode", "u", raw_data(xdg_decoration_unstable_v1_types)[0:]},
	{"unset_mode", "", raw_data(xdg_decoration_unstable_v1_types)[0:]},
}

@(private)
toplevel_decoration_v1_events := []wl.message {
	{"configure", "u", raw_data(xdg_decoration_unstable_v1_types)[0:]},
}

@(private)
@(init)
init_interfaces_xdg_decoration_unstable_v1 :: proc "contextless" () {
	decoration_manager_v1_interface.name = "zxdg_decoration_manager_v1"
	decoration_manager_v1_interface.version = 1
	decoration_manager_v1_interface.method_count = 2
	decoration_manager_v1_interface.event_count = 0
	decoration_manager_v1_interface.methods = raw_data(decoration_manager_v1_requests)
	toplevel_decoration_v1_interface.name = "zxdg_toplevel_decoration_v1"
	toplevel_decoration_v1_interface.version = 1
	toplevel_decoration_v1_interface.method_count = 3
	toplevel_decoration_v1_interface.event_count = 1
	toplevel_decoration_v1_interface.methods = raw_data(toplevel_decoration_v1_requests)
	toplevel_decoration_v1_interface.events = raw_data(toplevel_decoration_v1_events)
}
