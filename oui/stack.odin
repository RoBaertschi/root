package oui

import "base:intrinsics"
import "base:runtime"

sll_push :: proc(base, last: ^^$T, item: ^T) where intrinsics.type_has_field(T, "next"), intrinsics.type_field_type(T, "next") == ^T {
	if last^ == nil || base^ == nil {
		last^     = item
		base^     = item
		item.next = nil
	} else {
		item.next = last^
		last^     = item
	}
}

dll_push :: proc(base, last: ^^$T, item: ^T)
	where intrinsics.type_has_field(T, "next"), intrinsics.type_field_type(T, "next") == ^T,
	      intrinsics.type_has_field(T, "prev"), intrinsics.type_field_type(T, "prev") == ^T
{
	if last^ == nil || base^ == nil {
		last^     = item
		base^     = item
		item.next = nil
		item.prev = nil
		return
	}

	last^.next = item
	item.prev  = last^
	item.next  = nil
	last^      = item
}

dll_pop :: proc(base, last: ^^$T) -> (item: ^T, ok: bool)
	where intrinsics.type_has_field(T, "next"), intrinsics.type_field_type(T, "next") == ^T,
	      intrinsics.type_has_field(T, "prev"), intrinsics.type_field_type(T, "prev") == ^T
{
	if last^ == nil {
		return
	}

	if last^ == base^ {
		base^ = nil
	}

	item       = last^
	last^      = item.prev
	if last^ != nil {
		last^.next = nil
	}

	item.next  = nil
	item.prev  = nil

	ok = true
	return
}

Test :: struct {
	next: ^Test,
}

Test_Stack :: Stack(Test)

test :: proc() {
	stack: Stack(int)
	stack_push(&stack, 3, context.allocator)
	stack_pop(&stack)
	stack_top(&stack)
}

Stack_Node :: struct($T: typeid) {
	next, prev: ^Stack_Node(T),
	value:      T,
}

Stack :: struct($T: typeid) {
	free:     ^Stack_Node(T),
	top:      ^Stack_Node(T),
	base:     ^Stack_Node(T),
	nil_node: ^Stack_Node(T), // default value and also always the base of the stack, cannot be popped of
	auto_pop: bool,
}

stack_init :: proc(s: ^Stack($T), nil_value: T, allocator: runtime.Allocator) {
	s^ = {}
	stack_push(s, nil_value, allocator)
	s.nil_node = s.base
	assert(s.nil_node != nil)
}

stack_auto_pop :: proc(s: ^Stack($T)) {
	if s.auto_pop {
		stack_pop(s)
		s.auto_pop = false
	}
}

stack_set_next :: proc(s: ^Stack($T), value: T, allocator: runtime.Allocator) {
	stack_push(s, value, allocator)
	s.auto_pop = true
}

stack_push :: proc(s: ^Stack($T), value: T, allocator: runtime.Allocator) {
	node: ^Stack_Node(T)

	if s.free != nil {
		node   = s.free
		s.free = node.next
	} else {
		node = new(Stack_Node(T), allocator)
	}

	node.value = value
	dll_push(&s.base, &s.top, node)

	s.auto_pop = false
}

stack_pop :: proc(s: ^Stack($T)) -> T {
	node  := s.top
	value := node.value

	if node != s.nil_node {
		dll_pop(&s.base, &s.top)

		node^     = {}
		node.next = s.free
		s.free    = node
	}

	return value
}

stack_top :: proc(s: ^Stack($T)) -> T {
	if s.top == nil {
		panic("nil value popped from stack, which is invalid")
	}

	return s.top.value
}
