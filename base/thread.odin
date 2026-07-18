package root_base

import "core:sync"

Thread_Ctx :: struct {
	idx:          int,
	thread_count: int,
	barrier:      ^sync.Barrier,
	perm_arena:   ^virtual.Arena,
	temp_arenas:  [MAX_TEMP_ARENA_COUNT]virtual.Arena,
}

lane_idx :: proc() -> int {
	return thread_ctx.idx
}

lane_count :: proc() -> int {
	return thread_ctx.thread_count
}

lane_sync :: proc() {
	sync.barrier_wait(thread_ctx.barrier)
}

lane_range :: proc(values_count: int) -> (start, end: int) {
	return thread_distribute_values(values_count, lane_idx(), lane_count())
}

lane_sync_value :: proc(ptr: ^$T, src_lane_idx: int) {
	@function_static
	value: T

	if lane_idx() == src_lane_idx {
		value = ptr^
	} else {
		ptr^ = value
	}

	lane_sync()
}

@thread_local
thread_ctx: Thread_Ctx

thread_distribute_values :: proc(values_count, thread_idx, thread_count: int) -> (start, end: int) {
	values_per_thread     := values_count / thread_count
	leftover_values_count := values_count % thread_count
	thread_has_leftover   := thread_idx   < leftover_values_count

	leftovers_before_this_thread_idx := thread_idx if thread_has_leftover \
	                                               else leftover_values_count

	thread_first_value_idx := values_per_thread * thread_idx + leftovers_before_this_thread_idx
	thread_opl_value_idx   := thread_first_value_idx + values_per_thread + (thread_has_leftover ? 1
	                                                                                            : 0)
	return thread_first_value_idx, thread_opl_value_idx
}

import "core:mem/virtual"
import "base:runtime"

@(private="file")
MAX_TEMP_ARENA_COUNT :: 2
@(private="file")
MAX_TEMP_ARENA_COLLISIONS :: MAX_TEMP_ARENA_COUNT - 1

@(fini, private)
temp_allocator_fini :: proc "contextless" () {
    context = runtime.default_context()

    for &arena in thread_ctx.temp_arenas {
        virtual.arena_destroy(&arena)
    }
    thread_ctx.temp_arenas = {}
}

Temp_Allocator :: struct {
    using arena: ^virtual.Arena,
    using allocator: runtime.Allocator,
    tmp: virtual.Arena_Temp,
    loc: runtime.Source_Code_Location,
}

TEMP_ALLOCATOR_GUARD_END :: proc(temp: Temp_Allocator) {
    virtual.arena_temp_end(temp.tmp, temp.loc)
}

@(deferred_out=TEMP_ALLOCATOR_GUARD_END)
TEMP_ALLOCATOR_GUARD :: #force_inline proc(collisions: ..runtime.Allocator, loc := #caller_location) -> Temp_Allocator {
    assert(len(collisions) <= MAX_TEMP_ARENA_COLLISIONS, "Maximum collision count exceeded. MAX_TEMP_ARENA_COUNT must be increased!")
    good_arena: ^virtual.Arena
    for i in 0..<MAX_TEMP_ARENA_COUNT {
        good_arena = &thread_ctx.temp_arenas[i]
        for c in collisions {
            if good_arena == c.data {
                good_arena = nil
            }
        }
        if good_arena != nil {
            break
        }
    }
    assert(good_arena != nil)
    tmp := virtual.arena_temp_begin(good_arena, loc)
    return { good_arena, virtual.arena_allocator(good_arena), tmp, loc }
}

temp_allocator_begin :: virtual.arena_temp_begin
temp_allocator_end :: virtual.arena_temp_end
@(deferred_out=_temp_allocator_end)
temp_allocator_scope :: proc(tmp: Temp_Allocator) -> (virtual.Arena_Temp) {
    return temp_allocator_begin(tmp.arena)
}
@(private="file")
_temp_allocator_end :: proc(tmp: virtual.Arena_Temp) {
    temp_allocator_end(tmp)
}

@(init, private)
init_thread_local_cleaner :: proc "contextless" () {
    runtime.add_thread_local_cleaner(temp_allocator_fini)
}
