package root_base

import "core:c/libc"
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

	err = virtual.commit(raw_data(data), commited)
	if err != nil {
		// TODO(robin): better error message
		oom(err)
	}

	sanitizer.address_poison(data)

	a.data = uintptr(raw_data(data))
	a.curr = &a

	arena      := new_clone(&a, a)
	arena.curr  = arena

	return arena
}

arena_destroy_single :: proc(a: ^Arena) {
	virtual.release(rawptr(a.data), a.reserved)
}

arena_destroy :: proc(a: ^Arena) {
	prev := a.curr.prev
	for curr := a.curr; curr != nil; curr = prev {
		prev = curr.prev

		arena_destroy_single(curr)
	}
}

arena_push_aligned :: proc(a: ^Arena, size: uint, align: uint) -> (data: []byte) {
	if size == 0 {
		return nil
	}

	curr := a.curr

	arena_align_used :: proc(a: ^Arena, align: uint) -> uint {
		return uint(mem.align_forward_uintptr(uintptr(a.used) + a.data, uintptr(align)) - a.data)
	}

	curr_used_aligned := arena_align_used(curr, align)
	if curr_used_aligned + size > curr.reserved {
		reserved := mem.align_forward_uint(max(curr.reserved,         size + size_of(Arena)), uint(mem.PAGE_SIZE))
		commited := mem.align_forward_uint(max(curr.initial_commited, size + size_of(Arena)), uint(mem.PAGE_SIZE))

		new_arena := arena_alloc(
			commited,
			reserved,
		)

		new_arena.base_pos = curr.base_pos + curr.used
		new_arena.prev     = curr

		a.curr = new_arena
		curr   = new_arena

		curr_used_aligned = arena_align_used(curr, align)
	}

	start := curr_used_aligned
	end   := start + size

	if !assert(end < curr.reserved) {
		end = curr.reserved
	}

	if curr.commited < end {
		next_commit_boundary := mem.align_forward_uint(end, uint(mem.PAGE_SIZE))
		if assert(next_commit_boundary > curr.commited) {
			_ = assert(next_commit_boundary <= curr.reserved)

			err := virtual.commit(rawptr(curr.data + uintptr(curr.commited)), next_commit_boundary - curr.commited)
			if err != nil {
				oom(err)
			}

			curr.commited = next_commit_boundary
		}
	}

	curr.used = end
	data      = ([^]byte)(curr.data)[start:end]

	sanitizer.address_unpoison(data)
	mem.zero_slice(data)

	return
}

arena_pop_to :: proc(a: ^Arena, pos: uint, loc := #caller_location) {
	pos := pos

	// don't allow to deallocate the initial arena
	pos = max(pos, size_of(Arena))

	curr := a.curr

	curr_pos := curr.base_pos + curr.used

	if !assert(pos < curr_pos, loc = loc) {
		return
	}

	for prev := curr.prev; pos <= curr.base_pos; curr = prev {
		prev = curr.prev

		a.curr = prev
		arena_destroy_single(curr)
	}

	a.curr = curr

	new_used := pos - curr.base_pos

	sanitizer.address_poison(rawptr(curr.data + uintptr(new_used)), curr.used - new_used)

	curr.used = new_used
}

arena_pop :: proc(a: ^Arena, size: int, loc := #caller_location) {
	size := size

	curr := a.curr
	used := curr.base_pos + curr.used

	if !assert(0 <= size) {
		return
	}

	size_uint := uint(size)

	if !assert(size_uint <= used) {
		size_uint = used
	}

	arena_pop_to(a, used - size_uint, loc = loc)
}

arena_clear :: proc(a: ^Arena) {
	arena_pop_to(a, 0)
}

Arena_Temp :: struct {
	arena: ^Arena, 
	pos:   uint,
}

arena_temp_start :: proc(a: ^Arena) -> Arena_Temp {
	return {
		arena = a,
		pos   = a.curr.base_pos + a.curr.used,
	}
}

arena_temp_end :: proc(temp: Arena_Temp, loc := #caller_location) {
	arena_pop_to(temp.arena, temp.pos, loc = loc)
}

@(deferred_out=arena_temp_end)
arena_guard :: proc(a: ^Arena, loc := #caller_location) -> (temp: Arena_Temp, out_loc: runtime.Source_Code_Location) {
	temp    = arena_temp_start(a)
	out_loc = loc
	return
}

// Tests

import "core:testing"

@test
arena_lifecycle_test :: proc(t: ^testing.T) {
	arena := arena_alloc()
	defer arena_destroy(arena)

	i  := new_clone(arena, 3)
	testing.expect_value(t, i^, 3)
	i^  = 2
	testing.expect_value(t, i^, 2)
}

@test
arena_allocate_across_reserve_test :: proc(t: ^testing.T) {
	arena := arena_alloc(0, uint(mem.PAGE_SIZE))
	defer arena_destroy(arena)

	lots_of_data := make(arena, []byte, 100000)

	arena_pop(arena, 100000 + size_of(Arena))
	testing.expect_value(t, arena.curr, arena)
}

@test
arena_clear_test :: proc(t: ^testing.T) {
	arena := arena_alloc(0, uint(mem.PAGE_SIZE))
	defer arena_destroy(arena)

	lots_of_data := make(arena, []byte, 100000)

	arena_clear(arena)
	testing.expect_value(t, arena.curr, arena)
	testing.expect_value(t, arena.used, size_of(Arena))
}

@test
arena_guard_test :: proc(t: ^testing.T) {
	arena := arena_alloc()
	defer arena_destroy(arena)

	{
		arena_guard(arena)

		i := new(arena, int)
		i^ = 202020
	}

	testing.expect_value(t, arena.used, size_of(Arena))
}

// NOTE: for testing only
//
// @(test, disabled=.Address in ODIN_SANITIZER_FLAGS)
// arena_address_sanitation_test :: proc(t: ^testing.T) {
// 	testing.expect_signal(t, libc.SIGABRT)
// 	arena := arena_alloc()
// 	defer arena_destroy(arena)
//
// 	i: ^int
// 	{
// 		arena_guard(arena)
//
// 		i = new(arena, int)
// 		i^ = 202020
// 	}
//
// 	i^ = 3
// }
