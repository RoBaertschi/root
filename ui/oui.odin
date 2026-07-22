#+vet explicit-allocators
package oui

// TODO(robin): figure the allocation error story out

import "core:sync"
import "core:math"
import "core:strings"
import "base:runtime"
import "core:mem/virtual"
import "core:container/xar"

import W "../window"
import F "../font"
import B "../base"
import R "../render"

// Based on https://www.dgtlgrove.com/p/ui-part-3-the-widget-building-language

Arena :: virtual.Arena

Rect  :: B.Rect(f32)
Color :: R.Color

NULL_KEY :: ""

Mouse_Button :: enum {
	Left,
	Right,
	Middle,
}

State :: struct {
	perm_arena: Arena,
	arenas:     [2]Arena,

	root:    ^Box,
	current: ^Box,

	mouse_button_active: [Mouse_Button]string,
	mouse_hover:         string,

	current_frame: u64,

	//+stuff allocated in `perm_arena`

	boxes:    xar.Array(Box, 8),
	free_box: ^Box,   // free list of unused boxes

	//-stuff allocated in `perm_arena`

	curr_interned_strings: map[string]^Box,
	prev_interned_strings: map[string]^Box,

	stacks: Stacks,

	//+external stuff

	events:     Event_List,
	mouse_pos:  [2]f32,
	delta_time: f32,

	//-external stuff
}

build_arena :: proc() -> ^Arena {
	return &state.arenas[state.current_frame % 2]
}

build_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(build_arena())
}

perm_arena :: proc() -> ^Arena {
	return &state.perm_arena
}

perm_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(perm_arena())
}

init :: proc() {
	state, _ = virtual.arena_growing_bootstrap_new(State, "perm_arena")

	for &arena in state.arenas {
		_ = virtual.arena_init_growing(&arena)
	}

	xar.init(&state.boxes, perm_allocator())
}

fini :: proc() {
	for &arena in state.arenas {
		virtual.arena_destroy(&arena)
	}

	// locking the arena before freeing it
	sync.lock(&state.perm_arena.mutex)
	local       := state.perm_arena
	local.mutex  = {} // resetting the mutex, nobody except this function has the local copy of this mutex
	virtual.arena_destroy(&local)

	state = nil
}

push_parent :: proc(b: ^Box) {
	if state.current == nil {
		assert(b.parent == nil)
		state.root    = b
		state.current = b

		return
	}

	assert(state.current == b.parent)
	state.current = b
}

pop_parent :: proc() -> ^Box {
	old := state.current
	if old != nil {
		state.current = old.parent
	}
	return old
}

_parent_guard_end :: proc(b: ^Box) {
	old_box := pop_parent()
	assert(old_box == b)
}

@(deferred_in=_parent_guard_end)
parent_guard :: proc(b: ^Box) {
	push_parent(b)
}

semantic_size_set_next :: proc(a: Axis, s: Size) {
	@(static)
	LUT := [Axis]#type proc(s: Size){
		.X = semantic_width_set_next,
		.Y = semantic_height_set_next,
	}

	LUT[a](s)
}

semantic_size_push :: proc(a: Axis, s: Size) {
	@(static)
	LUT := [Axis]#type proc(s: Size){
		.X = semantic_width_push,
		.Y = semantic_height_push,
	}

	LUT[a](s)
}

semantic_size_pop :: proc(a: Axis) -> Size {
	@(static)
	LUT := [Axis]#type proc() -> Size{
		.X = semantic_width_pop,
		.Y = semantic_height_pop,
	}

	return LUT[a]()
}

semantic_size_top :: proc(a: Axis) -> Size {
	@(static)
	LUT := [Axis]#type proc() -> Size{
		.X = semantic_width_top,
		.Y = semantic_height_top,
	}

	return LUT[a]()
}

Begin_Description :: struct {
	root_size:  [2]f32,
	root_key:   string,
	delta_time: f32,
}

begin :: proc(desc: Begin_Description) {
	temp_interned_strings       := state.curr_interned_strings
	state.curr_interned_strings  = state.prev_interned_strings
	state.prev_interned_strings  = temp_interned_strings

	state.current_frame += 1
	virtual.arena_free_all(build_arena())

	delete(state.curr_interned_strings)
	state.curr_interned_strings = make(map[string]^Box, allocator = build_allocator())

	state.root, state.current = nil, nil

	init_stacks()

	state.events     = events_from_w_events(W.events())
	state.mouse_pos  = W.mouse()
	state.delta_time = desc.delta_time

	semantic_width_set_next(pixels(desc.root_size.x, 1))
	semantic_height_set_next(pixels(desc.root_size.y, 1))

	state.root = box_make({}, desc.root_key)
}

end :: proc() {
	Mode :: enum {
		Sum,
		Max,
	}

	box_mode :: proc(b: ^Box, a: Axis) -> (mode: Mode, stack_direction: Axis) {
		stack_direction = b.child_layout_axis

		mode = a == stack_direction ? Mode.Sum : Mode.Max
		return
	}

	box_size :: proc(b: ^Box, a: Axis) -> (value: f32, mode: Mode, stack_direction: Axis) {
		mode, stack_direction = box_mode(b, a)

		switch mode {
		case .Sum:
			for child := b.first; child != nil; child = child.next {
				value += child.computed_size[a]
			}

		case .Max:
			for child := b.first; child != nil; child = child.next {
				value = max(child.computed_size[a], value)
			}
		}

		return
	}

	box_is_overflow_on_axis :: proc(b: ^Box, a: Axis) -> bool {
		switch a {
		case .X: return .Overflow_X in b.flags
		case .Y: return .Overflow_Y in b.flags
		}
		return false
	}

	calculate_standalone_sizes :: proc(b: ^Box, a: Axis) {
		size := b.semantic_size[a]

		#partial switch size.kind {
		case .Pixels:
			b.computed_size[a] = size.value
		case .Text_Content:
			if b.att_text != nil {
				b.computed_size[a] = b.att_text.run.layout[a]
			}
		}

		for child := b.first; child != nil; child = child.next {
			calculate_standalone_sizes(child, a)
		}
	}

	calculate_upwards_dependent :: proc(b: ^Box, a: Axis) {
		size := b.semantic_size[a]

		#partial switch size.kind {
		case .Percent_Of_Parent:
			b.computed_size[a] = b.parent.computed_size[a] * size.value
		}

		for child := b.first; child != nil; child = child.next {
			calculate_upwards_dependent(child, a)
		}
	}

	calculate_downwards_dependent :: proc(b: ^Box, a: Axis) {
		for child := b.first; child != nil; child = child.next {
			calculate_downwards_dependent(child, a)
		}

		size := b.semantic_size[a]

		#partial switch size.kind {
		case .Children_Sum:
			b.computed_size[a], _, _ = box_size(b, a)
		}
	}

	solve_violations :: proc(b: ^Box, a: Axis) {
		if box_is_overflow_on_axis(b, a) {
			return
		}

		// TODO(robin): allow for scrollable areas and such
		mode, _ := box_mode(b, a)

		switch mode {
		case .Sum:
			size, _, _ := box_size(b, a)

			children_sum := size
			total_weight: f32

			for child := b.first; child != nil; child = child.next {
				child_size   := child.semantic_size[a]
				total_weight += child.computed_size[a] * (1 - child_size.strictness)
			}

			violation := children_sum - b.computed_size[a]

			if 0 < violation && 0 < total_weight {
				for child := b.first; child != nil; child = child.next {
					child_size             := child.semantic_size[a]
					flexibility            := 1 - child_size.strictness
					weight                 := child.computed_size[a] * flexibility
					shrink                 := violation * weight / total_weight
					child.computed_size[a] -= shrink
				}
			}
		case .Max:
			for child := b.first; child != nil; child = child.next {
				if child.computed_size[a] < b.computed_size[a] {
					continue
				}

				violation              := child.computed_size[a] - b.computed_size[a]
				flexibility            := 1 - child.semantic_size[a].strictness
				child.computed_size[a] -= violation * flexibility
			}
		}

		for child := b.first; child != nil; child = child.next {
			solve_violations(child, a)
		}
	}

	calculate_relative_positions :: proc(b: ^Box, pos: [Axis]f32) {
		b.computed_rel_position = pos
		b.rect = {
			pos  = transmute([2]f32)pos,
			size = transmute([2]f32)b.computed_size,
		}

		stack_direction := b.child_layout_axis

		new_pos := pos
		for child := b.first; child != nil; child = child.next {
			calculate_relative_positions(child, new_pos)

			new_pos[stack_direction] += child.computed_size[stack_direction]
		}
	}

	autolayout_axis :: proc(b: ^Box, a: Axis) {
		calculate_standalone_sizes(b, a)
		calculate_upwards_dependent(b, a)
		calculate_downwards_dependent(b, a)
		solve_violations(b, a)
	}

	autolayout_axis(state.root, .X)
	autolayout_axis(state.root, .Y)
	calculate_relative_positions(state.root, {})

	animate :: proc() {
		transition := math.pow(f32(2), -40 * state.delta_time)
		for key, b in state.curr_interned_strings {
			is_hovered := state.mouse_hover == key
			is_active  := false

			for mb_key in state.mouse_button_active {
				if key == mb_key {
					is_active = true
					break
				}
			}

			b.hovered_anim += (f32(int(is_hovered)) - b.hovered_anim) * transition
			b.active_anim  += (f32(int(is_active))  - b.active_anim)  * transition
		}
	}

	animate()

	// Ensure to use valid keys
	for &mb in state.mouse_button_active {
		if mb in state.curr_interned_strings {
			b  := state.curr_interned_strings[mb]
			mb  = b.key
		} else {
			mb = ""
		}
	}

	state.mouse_hover = ""

	// Free unused boxes

	for it := xar.iterator(&state.boxes); w in xar.iterate_by_ptr(&it) {
		if ._Free in w.flags {
			continue
		}

		if w.framed == state.current_frame {
			continue
		}

		box_free(w)
	}
}

Axis :: enum {
	X,
	Y,
}

Size_Kind :: enum u8 {
	Null,
	Pixels,
	Text_Content,
	Percent_Of_Parent,
	Children_Sum,
}

Size :: struct {
	value, strictness: f32,
	kind: Size_Kind,
}

pixels :: proc(value, strictness: f32) -> Size {
	return {
		kind       = .Pixels,
		value      = value,
		strictness = strictness,
	}
}

text_content :: proc(strictness: f32) -> Size {
	return {
		kind       = .Text_Content,
		strictness = strictness,
	}
}

percent_of_parent :: proc(percent: f32, strictness: f32) -> Size {
	return {
		kind       = .Percent_Of_Parent,
		value      = percent,
		strictness = strictness,
	}
}

children_sum :: proc(strictness: f32) -> Size {
	return {
		kind       = .Children_Sum,
		strictness = strictness,
	}
}

Box_Flag :: enum {
	// Layout
	Overflow_X,
	Overflow_Y,

	// Drawing
	Draw_Clip, // WARN: The box has to be retained across frames for clipping to work correctly
	Draw_Background,
	Draw_Hover,
	Draw_Active,
	Draw_Text,
	Draw_Custom,

	// Interactivity
	Clickable,

	_Free, // NOTE: internal, used to mark boxes that are inside the free list, use with caution
}

Box_Flags :: bit_set[Box_Flag]

Box_Attachment_Text :: struct {
	run:     ^F.Run,
	color:   Color,
	content: string,
	// TODO(robin): text size
}

Box_Attachment_Rect :: struct {
	background_color: Color,
	corner_radius:    f32,
	// TODO(robin): rounded corners, borders
}

Custom_Draw_Proc :: #type proc(b: ^Box)

Box_Attachment_Draw :: struct {
	procedure: Custom_Draw_Proc,
	user_data: rawptr,
}

Box :: struct {
	first, last: ^Box, // children
	next,  prev: ^Box, // siblings
	parent:      ^Box,

	key:    string,
	framed: u64,

	flags:             Box_Flags,
	semantic_size:     [Axis]Size,
	child_layout_axis: Axis,

	att_text: ^Box_Attachment_Text,
	att_rect: ^Box_Attachment_Rect,
	att_draw: ^Box_Attachment_Draw,

	//+computed every frame

	computed_rel_position: [Axis]f32,
	computed_size:         [Axis]f32,
	rect:                  Rect,

	//-computed every frame

	//+persistent data
	hovered_anim: f32,
	active_anim:  f32,
	//-persistent data
}

@private
state: ^State

insert_child_box :: proc(b: ^Box) {
	// Reset all tree data
	b.first, b.last = nil, nil
	b.next,  b.prev = nil, nil
	b.parent        = nil

	if state.current == nil {
		// Make as new root
		state.root    = b
		state.current = b
		return
	}

	curr := state.current
	last := state.current.last

	b.parent = curr

	if last != nil {
		last.next      = b
		b.next, b.prev = nil, last
		curr.last      = b
	} else {
		curr.first, curr.last = b, b
		b.next, b.prev        = nil, nil
	}
}

box_intern_key :: proc(b: ^Box) {
	if b.key == NULL_KEY {
		b.key = NULL_KEY // Make sure to use the static string and not the potentially user allocated one
		return
	}

	if interned_w, w_found := state.curr_interned_strings[b.key]; w_found {
		if interned_w == nil {
			state.curr_interned_strings[b.key] = b
			return
		}

		if interned_w != b {
			// We have a problem
			// TODO(robin): what to do on collision
			panic("duplicate box key")
		}

		// already properly interned
		return
	}

	interned_string                              := strings.clone(b.key, build_allocator())
	state.curr_interned_strings[interned_string]  = b
	b.key                                         = interned_string
}

box_mark_used :: proc(b: ^Box) {
	b.framed = state.current_frame
}

box_new :: proc() -> ^Box {
	if w := state.free_box; w != nil {
		state.free_box = w.next
		ensure(._Free in w.flags)
		w^ = {
			framed = state.current_frame
		}
		return w
	}

	w, _ := xar.append_and_get_ptr(&state.boxes, Box{})
	return w
}

box_free :: proc(b: ^Box) {
	// NOTE: Keys are recycled automatically
	b^ = {
		next  = state.free_box,
		flags = { ._Free },
	}

	state.free_box = b
}

box_attach_text :: proc(b: ^Box, text: string) {
	// TODO(robin): better text handling?
	cloned_text := strings.clone(text, build_allocator())

	if b.att_text == nil {
		b.att_text = B.arena_new(build_arena(), Box_Attachment_Text)
	}

	b.att_text.content = cloned_text
	b.att_text.run     = F.get_run(0, 24, text)
	b.att_text.color   = text_color_top()
}

box_attach_rect :: proc(b: ^Box) {
	if b.att_rect == nil {
		b.att_rect = B.arena_new(build_arena(), Box_Attachment_Rect)
	}

	b.att_rect.background_color = background_color_top()
	b.att_rect.corner_radius    = corner_radius_top()
}

box_attach_draw :: proc(b: ^Box, procedure: Custom_Draw_Proc, user_data: rawptr) {
	if b.att_draw == nil {
		b.att_draw = B.arena_new(build_arena(), Box_Attachment_Draw)
	}

	b.att_draw^ = {
		procedure = procedure,
		user_data = user_data,
	}
}

/*
Creates a new box. Uses the cache to reuse if possible. `key` is used as the key and interned.

WARN: Key collisions currently result in an `panic()` so be careful.

NOTE: `key` only needs to be valid for this function call
*/
box_make :: proc(flags: Box_Flags, key: string) -> (b: ^Box) {
	ensure(._Free not_in flags)

	_box_get_cached :: proc(key: string) -> (b: ^Box, ok: bool) {
		b = state.prev_interned_strings[key] or_return
		ensure(._Free not_in b.flags)
		ok = true
		return
	}

	// NOTE(robin): why not zero? -> The permanent data must be retained, so we don't zero the full box
	b       = _box_get_cached(key) or_else box_new()
	b.flags = flags
	b.key   = key

	b.att_rect = nil
	b.att_text = nil

	box_intern_key(b)
	box_mark_used(b)

	if .Draw_Background in flags {
		box_attach_rect(b)
	}

	if .Draw_Text in flags {
		box_attach_text(b, key)
	}

	insert_child_box(b)

	b.semantic_size[.X] = semantic_width_top()
	b.semantic_size[.Y] = semantic_height_top()
	b.child_layout_axis = child_layout_axis_top()

	auto_pop_stacks()

	return b
}
