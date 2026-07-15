#+build linux
package wayland

import "core:math"
generic_c_call :: proc "c" ()
dispatcher_func_t :: proc "c" (impl: rawptr, target: rawptr, opcode: u32, msg: ^message,args: [^]argument)
fixed_t :: i32
event_queue :: struct {}
proxy :: struct {}
argument :: union {}
message :: struct {
   name: cstring,
   signature: cstring,
   types: [^]^interface,
}
interface :: struct {
   name: cstring,
   version: i32,
   method_count: i32,
   methods: [^]message,
   event_count: i32,
   events: [^]message,
}
array :: struct {
   size: i64,
   alloc: i64,
   data: rawptr,
}

fixed_to_f32 :: proc "contextless" (f: fixed_t) -> f32 {
    return f32(f) / 256
}

fixed_from_f32 :: proc "contextless" (f: f32) -> fixed_t {
    return fixed_t(math.round(f * 256))
}

fixed_to_i32 :: proc "contextless" (f: fixed_t) -> i32 {
    return f / 256
}

fixed_from_i32 :: proc "contextless" (i: i32) -> fixed_t {
    return i * 256
}
