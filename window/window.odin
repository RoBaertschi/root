package root_window

import "base:runtime"
import "core:container/intrusive/list"
import "core:mem/virtual"

import B "../base"

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

Window_Flag :: enum {
	Maximize_Supported,
	Minimize_Supported,
	Decoration_Context_Menu_Supported,

	Maximized,
	Minimized,
}

Window_Flags :: bit_set[Window_Flag]

@private
arena :: proc() -> ^virtual.Arena {
	return _arena()
}

@private
state_allocator :: proc() -> runtime.Allocator {
	return virtual.arena_allocator(arena())
}

Init_Description :: struct {
	title: string,
	size:  [2]int,
}

init :: proc(desc: Init_Description) -> bool {
	return _init(desc)
}

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

set_decoration_hit_callback :: proc(procedure: Decoration_Hit_Proc) {
	_set_decoration_hit_callback(procedure)
}

frame :: proc() {
	_frame()
}

events :: proc() -> ^Event_List {
	return _events()
}

mouse :: proc() -> [2]f32 {
	return _mouse()
}

flags :: proc() -> Window_Flags {
	return _flags()
}

size :: proc() -> [2]int {
	return _size()
}

toggle_maximize :: proc() {
	_toggle_maximize()
}

minimize :: proc() {
	_minimize()
}

show_decoration_menu :: proc(pos: [2]f32, key: Interaction_Key) {
	_show_decoration_menu(
		pos,
		key,
	)
}
