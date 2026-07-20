package oui

import "base:runtime"
import "core:container/intrusive/list"

import W "../window"

Event_Kind :: enum {
	None,
	Pressed,
	Released,
}

Event_Key :: enum {
	Mouse_Left,
	Mouse_Right,
	Mouse_Middle,
}

event_key_to_mouse_button :: proc(key: Event_Key) -> Mouse_Button {
	return Mouse_Button(key - .Mouse_Left)
}

Event :: struct {
	kind: Event_Kind,
	key:  Event_Key,
	pos:  [2]f32,
}

Event_Node :: struct {
	node:  list.Node,
	event: Event,
}

Event_List :: struct {
	nodes:     list.List,
	allocator: runtime.Allocator,
}

// Do NOT use the standard allocator, this requires an allocator that can
// free all allocations at once using something like free_all.
// Ideally use mem.Arena or even better, virtual.Arena. context.temp_allocator also works if cleared on each frame.
event_list_init :: proc(el: ^Event_List, allocator: runtime.Allocator) {
	el.allocator = allocator
}

event_list_push :: proc(el: ^Event_List, event: Event) {
	assert(el.allocator.procedure != nil)
	node := new_clone(Event_Node{ event = event }, allocator = el.allocator)
	list.push_back(&el.nodes, &node.node)
}

event_list_remove :: proc(el: ^Event_List, node: ^Event_Node) {
	list.remove(&el.nodes, &node.node)
}

Event_List_Iterator :: struct {
	it: list.Iterator(Event_Node),
}

event_list_iterator :: proc(el: Event_List) -> Event_List_Iterator {
	return {
		list.iterator_head(el.nodes, Event_Node, "node"),
	}
}

event_list_iterate :: proc(it: ^Event_List_Iterator) -> (event: Event, event_node: ^Event_Node, ok: bool) {
	next := list.iterate_next(&it.it) or_return
	return next.event, next, true
}

Signal_Flag :: enum {
	Clicked_Left,
	Clicked_Right,
	Clicked_Middle,
	Pressed_Left,
	Pressed_Right,
	Pressed_Middle,
	Released_Left,
	Released_Right,
	Released_Middle,
	Hovering,
}

Signal_Flags :: bit_set[Signal_Flag]

Signal :: struct {
	flags: Signal_Flags,
}

signal_from_box :: proc(b: ^Box, c: ^Context) -> (s: Signal) {
	clipped_rect := b.rect

	for parent := b; parent != nil; parent = parent.parent {
		if .Draw_Clip in parent.flags {
			clipped_rect = rect_intersection(clipped_rect, parent.rect)
		}
	}

	for it := event_list_iterator(c.events); event, node in event_list_iterate(&it) {
		consume := false
		defer if consume {
			event_list_remove(&c.events, node)
		}

		is_mouse_event      := event.kind == .Pressed || event.kind == .Released
		is_mouse_inside_box := rect_contains(clipped_rect, event.pos)

		if is_mouse_event {
			mouse_button := event_key_to_mouse_button(event.key)
			if event.kind == .Released && c.mouse_button_active[mouse_button] == b.key {
				s.flags += {
					.Released_Left + Signal_Flag(mouse_button),
					.Clicked_Left  + Signal_Flag(mouse_button),
				}
				c.mouse_button_active[mouse_button] = ""
				consume = true
			}

			if event.kind == .Pressed && is_mouse_inside_box && .Clickable in b.flags {
				s.flags                             += {.Pressed_Left + Signal_Flag(mouse_button)}
				c.mouse_button_active[mouse_button]  = b.key

				consume = true
			}
		}
	}

	if rect_contains(clipped_rect, c.mouse_pos) && c.mouse_hover == "" {
		s.flags += {.Hovering}
		is_active := false

		for key in c.mouse_button_active {
			if key == b.key {
				is_active = true
				break
			}
		}

		if !is_active {
			c.mouse_hover = b.key
		}
	} else if b.key == c.mouse_hover {
		c.mouse_hover = ""
	}

	if .Clickable in b.flags {
		for key, mouse_button in c.mouse_button_active {
			if key == b.key {
				s.flags += {.Pressed_Left + Signal_Flag(mouse_button)}
			}
		}
	}

	return
}

events_from_w_events :: proc(c: ^Context, events: ^W.Event_List) -> (el: Event_List) {
	event_list_init(&el, _context_curr_allocator(c))

	for it := W.event_list_iterator(events^); event in W.event_list_iterate(&it) {
		switch event.kind {
		case .Close_Request: // ignore
		case .Resize:        // ignore
		case .Key:
			switch event.key {
			case .Mouse_Left, .Mouse_Right, .Mouse_Middle:
				// Some sanity checks, should probably be removed at some point

				#assert(int(Event_Key.Mouse_Left + Event_Key(W.Event_Key.Mouse_Left   - W.Event_Key.Mouse_Left)) == int(Event_Key.Mouse_Left))
				#assert(int(Event_Key.Mouse_Left + Event_Key(W.Event_Key.Mouse_Right  - W.Event_Key.Mouse_Left)) == int(Event_Key.Mouse_Right))
				#assert(int(Event_Key.Mouse_Left + Event_Key(W.Event_Key.Mouse_Middle - W.Event_Key.Mouse_Left)) == int(Event_Key.Mouse_Middle))

				#assert(int(Event_Kind.Pressed + Event_Kind(W.Event_Key_State.Pressed))  == int(Event_Kind.Pressed))
				#assert(int(Event_Kind.Pressed + Event_Kind(W.Event_Key_State.Released)) == int(Event_Kind.Released))

				event_list_push(
					&el,
					{
						key  = Event_Key.Mouse_Left + Event_Key(event.key - .Mouse_Left),
						kind = Event_Kind.Pressed + Event_Kind(event.key_state),
						pos  = event.pos,
					},
				)
			}
		}
	}

	return
}
