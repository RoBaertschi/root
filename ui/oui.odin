#+vet explicit-allocators
package oui

import "core:math"
// TODO(robin): figure the allocation error story out

import "core:strings"
import "base:runtime"
import "core:mem/virtual"
import "core:container/xar"

import W "../window"
import F "../font"
import B "../base"

// Based on https://www.dgtlgrove.com/p/ui-part-3-the-widget-building-language

Arena :: virtual.Arena

Rect :: B.Rect(f32)
Color :: [4]u8

NULL_KEY :: ""

Mouse_Button :: enum {
	Left,
	Right,
	Middle,
}

Context :: struct {
	// TODO(robin): don't move the arenas, that's invalid
	curr_arena: Arena,
	prev_arena: Arena,
	perm_arena: Arena,

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

_context_curr_allocator :: proc(c: ^Context) -> runtime.Allocator {
	return virtual.arena_allocator(&c.curr_arena)
}

_context_perm_allocator :: proc(c: ^Context) -> runtime.Allocator {
	return virtual.arena_allocator(&c.perm_arena)
}

context_init :: proc(c: ^Context) {
	c^ = {}

	_ = virtual.arena_init_growing(&c.curr_arena)
	_ = virtual.arena_init_growing(&c.prev_arena)
	_ = virtual.arena_init_growing(&c.perm_arena)

	xar.init(&c.boxes, _context_perm_allocator(c))
}

context_fini :: proc(c: ^Context) {
	virtual.arena_destroy(&c.curr_arena)
	virtual.arena_destroy(&c.prev_arena)
	virtual.arena_destroy(&c.perm_arena)

	c^ = {}
}

push_parent :: proc(b: ^Box, c: ^Context) {
	if c.current == nil {
		assert(b.parent == nil)
		c.root    = b
		c.current = b

		return
	}

	assert(c.current == b.parent)
	c.current = b
}

pop_parent :: proc(c: ^Context) -> ^Box {
	old := c.current
	if old != nil {
		c.current = old.parent
	}
	return old
}

_parent_guard_end :: proc(b: ^Box, c: ^Context) {
	old_box := pop_parent(c)
	assert(old_box == b)
}

@(deferred_in=_parent_guard_end)
parent_guard :: proc(b: ^Box, c: ^Context) {
	push_parent(b, c)
}

semantic_size_set_next :: proc(c: ^Context, a: Axis, s: Size) {
	@(static)
	LUT := [Axis]#type proc(c: ^Context, s: Size){
		.X = semantic_width_set_next,
		.Y = semantic_height_set_next,
	}

	LUT[a](c, s)
}

semantic_size_push :: proc(c: ^Context, a: Axis, s: Size) {
	@(static)
	LUT := [Axis]#type proc(c: ^Context, s: Size){
		.X = semantic_width_push,
		.Y = semantic_height_push,
	}

	LUT[a](c, s)
}

semantic_size_pop :: proc(c: ^Context, a: Axis) -> Size {
	@(static)
	LUT := [Axis]#type proc(c: ^Context) -> Size{
		.X = semantic_width_pop,
		.Y = semantic_height_pop,
	}

	return LUT[a](c)
}

semantic_size_top :: proc(c: ^Context, a: Axis) -> Size {
	@(static)
	LUT := [Axis]#type proc(c: ^Context) -> Size{
		.X = semantic_width_top,
		.Y = semantic_height_top,
	}

	return LUT[a](c)
}

Begin_Description :: struct {
	root_size:  [2]f32,
	root_key:   string,
	delta_time: f32,
}

begin :: proc(desc: Begin_Description, c: ^Context) {
	c.current_frame += 1

	temp_interned_strings   := c.curr_interned_strings
	c.curr_interned_strings  = c.prev_interned_strings
	c.prev_interned_strings  = temp_interned_strings

	delete(c.curr_interned_strings)
	c.curr_interned_strings = make(map[string]^Box, allocator = _context_curr_allocator(c))

	temp_arena   := c.curr_arena
	c.curr_arena  = c.prev_arena
	c.prev_arena  = temp_arena

	c.root, c.current = nil, nil

	virtual.arena_free_all(&c.curr_arena)

	init_stacks(c)

	c.events     = events_from_w_events(c, W.events())
	c.mouse_pos  = W.mouse()
	c.delta_time = desc.delta_time

	semantic_width_set_next(c, pixels(desc.root_size.x, 1))
	semantic_height_set_next(c, pixels(desc.root_size.y, 1))

	c.root = box_make({}, desc.root_key, c)
}

end :: proc(c: ^Context) {
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

	calculate_standalone_sizes :: proc(c: ^Context, b: ^Box, a: Axis) {
		size := b.semantic_size[a]

		#partial switch size.kind {
		case .Pixels:
			b.computed_size[a] = size.value
		case .Text_Content:
			if b.att_text != nil {
				b.computed_size = transmute([Axis]f32)b.att_text.run.metrics.size
			}
		}

		for child := b.first; child != nil; child = child.next {
			calculate_standalone_sizes(c, child, a)
		}
	}

	calculate_upwards_dependent :: proc(c: ^Context, b: ^Box, a: Axis) {
		size := b.semantic_size[a]

		#partial switch size.kind {
		case .Percent_Of_Parent:
			b.computed_size[a] = b.parent.computed_size[a] * size.value
		}

		for child := b.first; child != nil; child = child.next {
			calculate_upwards_dependent(c, child, a)
		}
	}

	calculate_downwards_dependent :: proc(c: ^Context, b: ^Box, a: Axis) {
		for child := b.first; child != nil; child = child.next {
			calculate_downwards_dependent(c, child, a)
		}

		size := b.semantic_size[a]

		#partial switch size.kind {
		case .Children_Sum:
			b.computed_size[a], _, _ = box_size(b, a)
		}
	}

	solve_violations :: proc(c: ^Context, b: ^Box, a: Axis) {
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
			solve_violations(c, child, a)
		}
	}

	calculate_relative_positions :: proc(c: ^Context, b: ^Box, pos: [Axis]f32) {
		b.computed_rel_position = pos
		b.rect = {
			pos  = transmute([2]f32)pos,
			size = transmute([2]f32)b.computed_size,
		}

		stack_direction := b.child_layout_axis

		new_pos := pos
		for child := b.first; child != nil; child = child.next {
			calculate_relative_positions(c, child, new_pos)

			new_pos[stack_direction] += child.computed_size[stack_direction]
		}
	}

	autolayout_axis :: proc(c: ^Context, b: ^Box, a: Axis) {
		calculate_standalone_sizes(c, b, a)
		calculate_upwards_dependent(c, b, a)
		calculate_downwards_dependent(c, b, a)
		solve_violations(c, b, a)
	}

	autolayout_axis(c, c.root, .X)
	autolayout_axis(c, c.root, .Y)
	calculate_relative_positions(c, c.root, {})

	animate :: proc(c: ^Context) {
		transition := math.pow(f32(2), -40 * c.delta_time)
		for key, b in c.curr_interned_strings {
			is_hovered := c.mouse_hover == key
			is_active  := false

			for mb_key in c.mouse_button_active {
				if key == mb_key {
					is_active = true
					break
				}
			}

			b.hovered_anim += (f32(int(is_hovered)) - b.hovered_anim) * transition
			b.active_anim  += (f32(int(is_active))  - b.active_anim)  * transition
		}
	}

	animate(c)

	// Ensure to use valid keys
	for &mb in c.mouse_button_active {
		if mb in c.curr_interned_strings {
			b  := c.curr_interned_strings[mb]
			mb  = b.key
		} else {
			mb = ""
		}
	}

	c.mouse_hover = ""

	// Free unused boxes

	for it := xar.iterator(&c.boxes); w in xar.iterate_by_ptr(&it) {
		if ._Free in w.flags {
			continue
		}

		if w.framed == c.current_frame {
			continue
		}

		box_free(w, c)
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

global_context: Context

context_insert_child_box :: proc(c: ^Context, b: ^Box) {
	// Reset all tree data
	b.first, b.last = nil, nil
	b.next,  b.prev = nil, nil
	b.parent        = nil

	if c.current == nil {
		// Make as new root
		c.root    = b
		c.current = b
		return
	}

	curr := c.current
	last := c.current.last

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

box_intern_key :: proc(b: ^Box, c: ^Context) {
	if b.key == NULL_KEY {
		b.key = NULL_KEY // Make sure to use the static string and not the potentially user allocated one
		return
	}

	if interned_w, w_found := c.curr_interned_strings[b.key]; w_found {
		if interned_w == nil {
			c.curr_interned_strings[b.key] = b
			return
		}

		if interned_w != b {
			// We have a problem
			// TODO(robin): what to do on collision
			panic("duplicate box key")
		}

		// already proberly interned
		return
	}

	interned_string                          := strings.clone(b.key, _context_curr_allocator(c))
	c.curr_interned_strings[interned_string]  = b
	b.key                                     = interned_string
}

box_mark_used :: proc(b: ^Box, c: ^Context) {
	b.framed = c.current_frame
}

box_new :: proc(c: ^Context) -> ^Box {
	if w := c.free_box; w != nil {
		c.free_box = w.next
		ensure(._Free in w.flags)
		w^ = {
			framed = c.current_frame
		}
		return w
	}

	w, _ := xar.append_and_get_ptr(&c.boxes, Box{})
	return w
}

box_free :: proc(b: ^Box, c: ^Context) {
	// NOTE: Keys are recycled automatically
	b^ = {
		next  = c.free_box,
		flags = { ._Free },
	}

	c.free_box = b
}

box_attach_text :: proc(b: ^Box, text: string, c: ^Context) {
	// TODO(robin): better text handling?
	cloned_text := strings.clone(text, _context_curr_allocator(c))

	if b.att_text == nil {
		b.att_text = new(Box_Attachment_Text, _context_curr_allocator(c))
	}

	b.att_text.content = text
	b.att_text.run     = F.get_run(0, 24, text)
	b.att_text.color   = text_color_top(c)
}

box_attach_rect :: proc(b: ^Box, c: ^Context) {
	if b.att_rect == nil {
		b.att_rect = new(Box_Attachment_Rect, _context_curr_allocator(c))
	}

	b.att_rect.background_color = background_color_top(c)
	b.att_rect.corner_radius    = corner_radius_top(c)
}

box_attach_draw :: proc(b: ^Box, procedure: Custom_Draw_Proc, user_data: rawptr, c: ^Context) {
	if b.att_draw == nil {
		b.att_draw = new(Box_Attachment_Draw, _context_curr_allocator(c))
	}

	b.att_draw^ = {
		procedure = procedure,
		user_data = user_data,
	}
}

/*
Creates a new box. Uses the cache to reuse if possible. `key` is used as the key and interned.

WARN: Key collisions currently result in an `panic()` so be carefull.

NOTE: `key` only needs to be valid for this function call
*/
box_make :: proc(flags: Box_Flags, key: string, c: ^Context) -> (b: ^Box) {
	ensure(._Free not_in flags)

	_box_get_cached :: proc(key: string, c: ^Context) -> (b: ^Box, ok: bool) {
		b = c.prev_interned_strings[key] or_return
		ensure(._Free not_in b.flags)
		ok = true
		return
	}

	// NOTE(robin): why not zero? -> The permanent data must be retained, so we don't zero the full box
	b       = _box_get_cached(key, c) or_else box_new(c)
	b.flags = flags
	b.key   = key

	b.att_rect = nil
	b.att_text = nil

	box_intern_key(b, c)
	box_mark_used(b, c)

	if .Draw_Background in flags {
		box_attach_rect(b, c)
	}

	if .Draw_Text in flags {
		box_attach_text(b, key, c)
	}

	context_insert_child_box(c, b)

	b.semantic_size[.X] = semantic_width_top(c)
	b.semantic_size[.Y] = semantic_height_top(c)
	b.child_layout_axis = child_layout_axis_top(c)

	auto_pop_stacks(c)

	return b
}

// main :: proc() {
// 	context_init(
// 		&global_context,
// 		{
// 			meassure_text = proc(_: rawptr, s: string, _: Axis) -> f32 {
// 				return 3
// 			}
// 		},
// 	)
//
// 	desc := Begin_Description{ root_size = { 800, 600 }, root_key = "root", events = {} }
// 	begin(desc, &global_context)
//
// 	{
// 		semantic_width_guard(&global_context, pixels(20, 1))
// 		semantic_height_guard(&global_context, pixels(40, 1))
//
// 		semantic_width_set_next(&global_context, children_sum(1))
// 		semantic_height_set_next(&global_context, children_sum(1))
// 		parent_guard(box_make({}, "Hello", &global_context), &global_context)
//
// 		box_make({}, "World", &global_context)
// 		box_make({}, "World2", &global_context)
// 		box_make({}, "World3", &global_context)
// 	}
//
// 	end(&global_context)
//
// 	fmt.printfln("%#v", global_context)
//
// 	begin(desc, &global_context)
//
// 	{
// 		semantic_width_guard(&global_context, pixels(20, 1))
// 		semantic_height_guard(&global_context, pixels(40, 1))
//
// 		semantic_width_set_next(&global_context, children_sum(1))
// 		semantic_height_set_next(&global_context, children_sum(1))
// 		parent_guard(box_make({}, "Hello", &global_context), &global_context)
// 		box_make({}, "World", &global_context)
// 		box_make({}, "World2", &global_context)
// 		box_make({}, "World3", &global_context)
// 	}
//
// 	end(&global_context)
//
// 	begin(desc, &global_context)
//
// 	{
// 		semantic_width_guard(&global_context, pixels(20, 1))
// 		semantic_height_guard(&global_context, pixels(40, 1))
//
// 		semantic_width_set_next(&global_context, children_sum(1))
// 		semantic_height_set_next(&global_context, children_sum(1))
// 		parent_guard(box_make({}, "Hello", &global_context), &global_context)
// 	}
//
// 	end(&global_context)
//
// 	fmt.printfln("%#v", global_context)
// }
