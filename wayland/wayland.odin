#+build linux
package wayland

// Functions from libwayland-client
import "core:c"

foreign import wl_lib "system:wayland-client"

@(default_calling_convention="c")
@(link_prefix="wl_")
foreign wl_lib {
	display_connect                           :: proc(name: cstring) -> ^display ---
	display_connect_to_fd                     :: proc(fd: i32) -> ^display ---
	display_disconnect                        :: proc(display: ^display) ---
	display_get_fd                            :: proc(display: ^display) -> i32 ---
	display_dispatch                          :: proc(display: ^display) -> i32 ---
	display_dispatch_queue                    :: proc(display: ^display, queue: event_queue) -> i32 ---
	display_dispatch_queue_pending            :: proc(display: ^display, queue: event_queue) -> i32 ---
	display_dispatch_pending                  :: proc(display: ^display) -> i32 ---
	display_get_error                         :: proc(display: ^display) -> i32 ---
	display_get_protocol_error                :: proc(display: ^display, intf: ^interface, id: ^u32) -> u32 ---
	display_flush                             :: proc(display: ^display) -> i32 ---
	display_roundtrip_queue                   :: proc(display: ^display, queue: ^event_queue) -> i32 ---
	display_roundtrip                         :: proc(display: ^display) -> i32 ---
	display_create_queue                      :: proc(display: ^display) -> ^event_queue ---
	display_prepare_read_queue                :: proc(display: ^display, queue: ^event_queue) -> i32 ---
	display_prepare_read                      :: proc(display: ^display) -> i32 ---
	display_cancel_read                       :: proc(display: ^display) ---
	display_read_events                       :: proc(display: ^display) -> i32 ---
	display_set_max_buffer_size               :: proc(display: ^display, max_buffer_size: c.size_t) ---

	proxy_marshal_flags                       :: proc(p: ^proxy, opcode: u32, intf: ^interface, version: u32, flags: u32, #c_vararg args: ..any) -> ^proxy ---
	proxy_marshal                             :: proc(p: ^proxy, opcode: u32, #c_vararg args: ..any) ---
	proxy_create                              :: proc(factory: ^proxy, intf: ^interface) -> ^proxy ---
	proxy_create_wrapper                      :: proc(proxy: rawptr) -> rawptr ---
	proxy_wrapper_destroy                     :: proc(proxy_wrapper: rawptr) ---
	proxy_marshal_constructor                 :: proc(p: ^proxy, opcode: u32, intf: ^interface, #c_vararg args: ..any) -> ^proxy ---
	proxy_marshal_constructor_versioned       :: proc(p: ^proxy, opcode: u32, intf: ^interface, version: u32, #c_vararg args: ..any) -> ^proxy ---
	proxy_marshal_array_constructor           :: proc(p: ^proxy, opcode: u32, args: ^argument, intf: ^interface) -> ^proxy ---
	proxy_marshal_array_constructor_versioned :: proc(p: ^proxy, opcode: u32, args: ^argument, intf: ^interface, version: u32) -> ^proxy ---
	proxy_destroy                             :: proc(p: ^proxy) ---
	proxy_add_listener                        :: proc(p: ^proxy, impl: ^generic_c_call, data: rawptr) -> i32 ---
	proxy_get_listener                        :: proc(p: ^proxy) -> rawptr ---
	proxy_add_dispatcher                      :: proc(p: ^proxy, func: dispatcher_func_t, dispatcher_data: rawptr, data: rawptr) -> i32 ---
	proxy_set_user_data                       :: proc(p: ^proxy, user_data: rawptr) ---
	proxy_get_user_data                       :: proc(p: ^proxy) -> rawptr ---
	proxy_get_version                         :: proc(p: ^proxy) -> u32 ---
	proxy_get_id                              :: proc(p: ^proxy) -> u32 ---
	proxy_set_tag                             :: proc(p: ^proxy, tag: ^u8) ---
	proxy_get_tag                             :: proc(p: ^proxy) -> ^u8 ---
	proxy_get_class                           :: proc(p: ^proxy) -> ^u8 ---
	proxy_set_queue                           :: proc(p: ^proxy, queue: ^event_queue) ---
}
