package root_window2

import "core:log"
import "core:strings"
import "base:runtime"
import "core:mem/virtual"
import "core:container/intrusive/list"

import B "../base"

// #region Events

Interaction_Key :: _Interaction_Key

Event_Kind :: enum {
	Close_Request,
	Resize,
	Key,
	Codepoint,
}

Event_Key_State :: enum {
	Pressed,
	Released,
}

// #region Event_Key

Event_Key :: enum {
	Unknown,

	Mouse_Left,
	Mouse_Right,
	Mouse_Middle,

	Escape,
	Enter,
	Tab,
	Backspace,
	Delete,
	Insert,
	Space,

	Left,
	Right,
	Up,
	Down,
	Home,
	End,
	Page_Up,
	Page_Down,
	Shift_Left,
	Shift_Right,
	Control_Left,
	Control_Right,
	Alt_Left,
	Alt_Right,
	Super_Left,
	Super_Right,

	A,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z,

	Num_0,
	Num_1,
	Num_2,
	Num_3,
	Num_4,
	Num_5,
	Num_6,
	Num_7,
	Num_8,
	Num_9,

	Minus,
	Equal,
	Left_Bracket,
	Right_Bracket,
	Backslash,
	Semicolon,
	Apostrophe,
	Grave,
	Comma,
	Period,
	Slash,

	F1,
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,

	Print_Screen,
	Pause,
	Menu,

	Keypad_0,
	Keypad_1,
	Keypad_2,
	Keypad_3,
	Keypad_4,
	Keypad_5,
	Keypad_6,
	Keypad_7,
	Keypad_8,
	Keypad_9,
	Keypad_Decimal,
	Keypad_Divide,
	Keypad_Multiply,
	Keypad_Subtract,
	Keypad_Add,
	Keypad_Enter,
	Keypad_Equal,
}

// #endregion

Event_Modifier :: enum {
	Shift,
	Control,
	Alt,
	Super,
}

Event_Modifiers :: bit_set[Event_Modifier]

Event :: struct {
	kind:        Event_Kind,
	size:        [2]int,
	pos:         [2]f32,
	key:         Event_Key,
	window:      Handle,
	key_state:   Event_Key_State,
	modifiers:   Event_Modifiers,
	codepoint:   rune,
	interaction: Interaction_Key,
}

Event_Node :: struct {
	using node: list.Node,
	event:      Event,
}

Event_List :: struct {
	events:    list.List,
	free_list: list.List,
	len:       int,
}

event_list_push :: proc(el: ^Event_List, ev: Event) -> (ev_node: ^Event_Node) {
	if node := list.pop_back(&el.free_list); node != nil {
		ev_node = container_of(node, Event_Node, "node")
	} else {
		ev_node = B.arena_new(arena(), Event_Node)
	}
	ev_node.event = ev
	list.push_back(&el.events, ev_node)
	el.len += 1
	return
}

event_list_remove :: proc(el: ^Event_List, node: ^Event_Node) {
	list.remove(&el.events, node)
	list.push_front(&el.free_list, node)
	el.len -= 1
}

event_list_clear :: proc(el: ^Event_List) {
	el.len = 0

	for it := event_list_iterator(el^); _, node in event_list_iterate(&it) {
		event_list_remove(el, node)
	}
}

Event_List_Iterator :: struct {
	it: list.Iterator(Event_Node),
}

event_list_iterator :: proc(el: Event_List) -> Event_List_Iterator {
	return {
		it = list.iterator_head(el.events, Event_Node, "node"),
	}
}

event_list_iterate :: proc(it: ^Event_List_Iterator) -> (ev: Event, node: ^Event_Node, ok: bool) {
	node = list.iterate_next(&it.it) or_return
	ev   = node.event
	ok   = true
	return
}

// #endregion

// #region Window

Window_Flag :: enum {
	Maximize_Supported,
	Minimize_Supported,
	Decoration_Context_Menu_Supported,

	Maximized,
}

Window_Flags :: bit_set[Window_Flag]

Handle :: struct {
	idx: u32,
	gen: u32,
}

NIL_WINDOW :: Handle {}

Window :: struct {
	handle: Handle,
	node:   list.Node,
	arena:  virtual.Arena,
	flags:  Window_Flags,
	title:  string,
	size:   [2]int,

	decoration_hit_proc: Decoration_Hit_Proc,

	_platform: _Window_Platform,
}

@private
window_arena :: proc(w: ^Window) -> ^virtual.Arena {
	return &w.arena
}

@private
window_allocator :: proc(w: ^Window) -> runtime.Allocator {
	return virtual.arena_allocator(window_arena(w))
}

window_from_handle :: proc(handle: Handle) -> ^Window {
	return B.hm_get(&state.window_map, handle) or_else B.hm_get(&state.window_map, NIL_WINDOW)
}

window_from_handle_try :: proc(handle: Handle) -> (^Window, bool) {
	if handle == NIL_WINDOW {
		return nil, false
	}

	return B.hm_get(&state.window_map, handle)
}

window_make :: proc(size: [2]int, title: string) -> (handle: Handle) {
	handle, _ = B.hm_add(&state.window_map, Window{})

	w := window_from_handle(handle)

	if err := virtual.arena_init_growing(&w.arena); err != nil {
		_, _ = B.hm_remove(&state.window_map, handle)
		return NIL_WINDOW
	}

	w.size = size
	w.title = strings.clone(title, window_allocator(w))

	if !_window_platform_init(w) {
		virtual.arena_destroy(&w.arena)
		_, _ = B.hm_remove(&state.window_map, handle)
		return NIL_WINDOW
	}

	list.push_back(&state.windows, &w.node)

	return
}

window_destroy :: proc(handle: Handle) {
	if handle == NIL_WINDOW {
		return
	}

	w := window_from_handle(handle)

	found, err := B.hm_remove(&state.window_map, handle)
	if err != nil || !found {
		return
	}

	if state.context_current == handle {
		_set_current(nil)
	}

	p := &state._platform
	if p.pointer_current_window == handle {
		p.pointer_current_window = NIL_WINDOW
	}
	if p.keyboard_current_window == handle {
		p.keyboard_current_window = NIL_WINDOW
	}

	list.remove(&state.windows, &w.node)
	_window_platform_fini(w)
	virtual.arena_destroy(&w.arena)
}

window_flags :: proc(handle: Handle) -> Window_Flags {
	return window_from_handle(handle).flags
}

window_title :: proc(handle: Handle) -> string {
	return window_from_handle(handle).title
}

window_size :: proc(handle: Handle) -> [2]int {
	return window_from_handle(handle).size
}

window_pointer_pos :: proc(handle: Handle) -> [2]f32 {
	return _window_pointer_pos(handle)
}

// Set current window to use for the OpenGL context
set_current :: proc(handle: Handle) -> bool {
	w, ok := window_from_handle_try(handle)
	if !ok {
		_set_current(nil)
		return false
	}

	return _set_current(w)
}

@private
window_swap_buffers :: proc(handle: Handle) {
	w, ok := window_from_handle_try(handle)
	if !ok {
		return
	}

	_window_swap_buffers(w)
}

window_toggle_maximize :: proc(handle: Handle) {
	w, ok := window_from_handle_try(handle)
	if !ok {
		return
	}

	_window_toggle_maximize(w)
}

window_minimize :: proc(handle: Handle) {
	w, ok := window_from_handle_try(handle)
	if !ok {
		return
	}

	_window_minimize(w)
}

window_show_decoration_menu :: proc(handle: Handle, pos: [2]f32, key: Interaction_Key) {
	w, ok := window_from_handle_try(handle)
	if !ok {
		return
	}

	_window_show_decoration_menu(w, pos, key)
}

// #endregion

// #region State

State :: struct {
	arena:      virtual.Arena,
	ctx:        runtime.Context,
	window_map: B.Handle_Map(Window, Handle),
	windows:    list.List,
	events:     Event_List,

	context_current: Handle,

	_platform: _State_Platform,
}

@private
state: ^State

@private
arena :: proc() -> ^virtual.Arena {
	return &state.arena
}

@private
state_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(arena())
}

init :: proc() -> bool {
	state, _ = virtual.arena_growing_bootstrap_new(State, "arena")

	context.logger = log.create_console_logger(ident = "WINDOW", allocator = state_allocator())

	state.ctx = context

	B.hm_init(&state.window_map, Window{}, state_allocator())

	return _state_platform_init(state)
}

begin_frame :: proc() {
	gather_events()
}

end_frame :: proc() {
	event_list_clear(&state.events)
}

@(deferred_none=end_frame)
frame_guard :: proc() {
	begin_frame()
}

begin_window :: proc(handle: Handle) -> bool {
	return set_current(handle)
}

end_window :: proc() {
	if state.context_current == NIL_WINDOW {
		return
	}

	window_swap_buffers(state.context_current)
}

@(deferred_in=_window_guard_end)
window_guard :: proc(handle: Handle, loc := #caller_location) -> bool {
	return begin_window(handle)
}

_window_guard_end :: proc(handle: Handle, loc: runtime.Source_Code_Location) {
	end_window()
}

window_iterator :: proc() -> list.Iterator(Window) {
	return list.iterator_head(state.windows, Window, "node")
}

window_iterate :: proc(it: ^list.Iterator(Window)) -> (^Window, bool) {
	return list.iterate_next(it)
}

@private
gather_events :: proc() {
	_gather_events()
}

events :: proc() -> ^Event_List {
	return &state.events
}

// #endregion

Decoration_Hit_Result :: enum {
	None,

	Resize_Top,
	Resize_Bottom,
	Resize_Left,
	Resize_Right,
	Resize_Top_Left,
	Resize_Bottom_Left,
	Resize_Top_Right,
	Resize_Bottom_Right,

	Draggable,
}

Decoration_Hit_Proc :: #type proc(pos: [2]f32) -> Decoration_Hit_Result

set_decoration_hit_callback :: proc(handle: Handle, procedure: Decoration_Hit_Proc) {
	w, ok := window_from_handle_try(handle)
	if !ok {
		return
	}

	w.decoration_hit_proc = procedure
}
