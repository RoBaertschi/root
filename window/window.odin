package root_window

import "base:runtime"
import "core:container/intrusive/list"

Event_Kind :: enum {
	Close_Request,
	Resize,
}

Event :: struct {
	kind: Event_Kind,
	size: [2]int,
}

Event_Node :: struct {
	using node: list.Node,
	event:      Event,
}

Event_List :: struct {
	events:       list.List,
	free_list:    list.List,
	count:        int,
}

event_list_push :: proc(el: ^Event_List, ev: Event) -> (ev_node: ^Event_Node) {
	if node := list.pop_back(&el.free_list); node != nil {
		ev_node = container_of(node, Event_Node, "node")
	} else {
		ev_node = new(Event_Node, allocator = state_allocator())
	}
	ev_node.event = ev
	list.push_back(&el.events, ev_node)
	el.count += 1
	return
}

event_list_remove :: proc(el: ^Event_List, node: ^Event_Node) {
	list.remove(&el.events, node)
	list.push_front(&el.free_list, node)
	el.count -= 1
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

@private
state_allocator :: proc() -> runtime.Allocator {
	return _state_allocator()
}

Init_Description :: struct {
	title: string,
	size:  [2]int,
}

init :: proc(desc: Init_Description) -> bool {
	return _init(desc)
}

frame :: proc() {
	_frame()
}

events :: proc() -> ^Event_List {
	return _events()
}
