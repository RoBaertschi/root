package root_base

import "core:fmt"
import "base:sanitizer"
import "core:mem/virtual"
import "core:mem"
import "base:runtime"

Arena :: struct {
	prev: ^Arena,
	curr: ^Arena,

	base_pos:         uint, // absolute pos in linked list chain
	data:             uintptr,
	used:             uint,
	reserved:         uint,
	commited:         uint,
	initial_commited: uint,
}

@(private="file")
oom :: proc(err := mem.Allocator_Error.Out_Of_Memory) -> ! {
	fmt.panicf("Out of memory: %v", err)
}

// TODO(robin): rename
arena_alloc :: proc(commited: uint = runtime.Megabyte * 4, reserved: uint = runtime.Gigabyte * 2) -> ^Arena {
	a := Arena {
		used             = 0,
		reserved         = reserved,
		commited         = commited,
		initial_commited = commited,
	}

	data, err := virtual.reserve(reserved)
	if err != nil {
		// TODO(robin): better error message
		oom(err)
	}
	sanitizer.address_poison(data)

	a.data = uintptr(raw_data(data))

	arena      := new_clone(&a, a)
	arena.curr  = arena

	return arena
}

// The `new` procedure allocates memory for a type `T` from a `base.Arena`. The second argument is a type,
// not a value, and the value return is a pointer to a newly allocated value of that type using the specified allocator.
new :: proc(a: ^Arena, $T: typeid, loc := #caller_location) -> (ptr: ^T, err: mem.Allocator_Error) {
	return new_aligned(a, T, align_of(T), loc)
}

// The `new_aligned` procedure allocates memory for a type `T` from a `base.Arena` with a specified `alignment`.
// The second argument is a type, not a value, and the value return is a pointer to a newly allocated value of
// that type using the specified allocator.
new_aligned :: proc(a: ^Arena, $T: typeid, alignment: uint, loc := #caller_location) -> (ptr: ^T) {
	data := arena_push_aligned(a, size_of(T), alignment)
	ptr = (^T)(raw_data(data))
	return
}

// The `new_clone` procedure allocates memory for a type `T` from a `base.Arena`. The second argument is a value that
// is to be copied to the allocated data. The value returned is a pointer to a newly allocated value of that type using the specified allocator.
new_clone :: proc(a: ^Arena, data: $T, loc := #caller_location) -> (ptr: ^T) {
	ptr = new_aligned(a, T, align_of(T), loc)
	if ptr != nil {
		ptr^ = data
	}
	return
}

// `make_slice` allocates and initializes a slice. Like `new`, the second argument is a type, not a value.
// Unlike `new`, `make`'s return value is the same as the type of its argument, not a pointer to it.
//
// Note: Prefer using the procedure group `make`.
make_slice :: proc(a: ^Arena, $T: typeid/[]$E, #any_int len: int, loc := #caller_location) -> T {
	return make_aligned(a, T, len, align_of(E), loc)
}

// `make_aligned` allocates and initializes a slice. Like `new`, the second argument is a type, not a value.
// Unlike `new`, `make`'s return value is the same as the type of its argument, not a pointer to it.
//
// Note: Prefer using the procedure group `make`.
make_aligned :: proc(a: ^Arena, $T: typeid/[]$E, #any_int len: int, alignment: uint, loc := #caller_location) -> T {
	runtime.make_slice_error_loc(loc, len)
	data := arena_push_aligned(a, size_of(E)*uint(len), alignment, loc)
	if data == nil && size_of(E) != 0 {
		return nil
	}
	s := ([^]E)(raw_data(data))[:len]
	return T(s)
}

// `make_multi_pointer` allocates and initializes a dynamic array. Like `new`, the second argument is a type, not a value.
// Unlike `new`, `make`'s return value is the same as the type of its argument, not a pointer to it.
//
// This is "similar" to doing `raw_data(make([]E, len, allocator))`.
//
// Note: Prefer using the procedure group `make`.
make_multi_pointer :: proc(a: ^Arena, $T: typeid/[^]$E, #any_int len: int, loc := #caller_location) -> T {
	runtime.make_slice_error_loc(loc, len)
	data := arena_push_aligned(a, size_of(E)*uint(len), align_of(E), loc)
	if data == nil && size_of(E) != 0 {
		return nil
	}
	return (T)(raw_data(data))
}

make :: proc{
	make_slice,
	make_multi_pointer,
}

arena_push_aligned :: proc(a: ^Arena, size: uint, align: uint) -> (data: []byte) {
	if size == 0 {
		return nil
	}

	curr := a.curr

	aligned_used := mem.align_forward_uint(a.used, align)
	start        := aligned_used
	end          := aligned_used + size

	if end > a.reserved {
		reserved := a.reserved
		commited := a.initial_commited

		if reserved < size {
			reserved = mem.align_forward_uint(size, uint(mem.PAGE_SIZE))
			commited = size
		}

		next := arena_alloc(
			a.initial_commited,
			reserved,
		)

		next.prev = curr
		curr.curr = curr
		curr      = next
	}

	if end > a.commited {
		next_commit_boundary := mem.align_forward_uint(end, uint(mem.PAGE_SIZE))
		if assert(next_commit_boundary > a.commited) {
			err := virtual.commit(rawptr(a.data + uintptr(a.commited)), next_commit_boundary - a.commited)
			if err != nil {
				oom()
			}

			a.commited = next_commit_boundary
		}
	}

	a.used = end
	data   = ([^]byte)(a.data)[start:end]
	sanitizer.address_unpoison(data)
	mem.zero_slice(data)

	return
}

arena_pop_to :: proc(a: ^Arena, pos: uint, loc := #caller_location) {
	pos := pos

	if !assert(pos < a.used, loc = loc) {
		return
	}

	if !assert(pos <= a.commited, loc = loc) {
		pos = a.commited
	}

	sanitizer.address_poison(rawptr(a.data + uintptr(pos)), a.used - pos)
	a.used = pos
}

arena_pop :: proc(a: ^Arena, size: int, loc := #caller_location) {
	size := size

	if !assert(0 <= size) {
		return
	}

	size_uint := uint(size)

	if !assert(size_uint <= a.used) {
		size_uint = a.used
	}

	arena_pop_to(a, a.used - size_uint, loc = loc)
}
