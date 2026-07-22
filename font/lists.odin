package root_font

import B "../base"

glyph_list_push :: proc(gl: ^Glyph_List, glyph: Render_Glyph) -> ^Glyph_Node {
	node: ^Glyph_Node
	if state.glyph_node_free != nil {
		node                  = state.glyph_node_free
		state.glyph_node_free = node.next
	} else {
		node = B.arena_new(arena(), Glyph_Node)
	}

	node.glyph = glyph
	B.sll_insert(&gl.first, &gl.last, node)
	gl.len += 1
	return node
}

glyph_list_free :: proc(gl: Glyph_List) {
	for node := gl.first; node != nil; node = node.next {
		node.next             = state.glyph_node_free
		state.glyph_node_free = node
	}
}

Glyph_List_Iterator :: struct {
	current: ^Glyph_Node,
}

glyph_list_iterator :: proc(gl: Glyph_List) -> Glyph_List_Iterator {
	return {
		current = gl.first,
	}
}

glyph_list_iterate :: proc(it: ^Glyph_List_Iterator) -> (glyph: Render_Glyph, ok: bool) {
	node := it.current
	if node == nil {
		return
	}
	it.current = node.next

	return node.glyph, true
}

grapheme_list_push :: proc(gl: ^Grapheme_List, grapheme: Grapheme) -> ^Grapheme_Node {
	node: ^Grapheme_Node
	if state.glyph_node_free != nil {
		node            = state.grapheme_free
		state.grapheme_free = node.next
	} else {
		node = B.arena_new(arena(), Grapheme_Node)
	}

	node.grapheme = grapheme
	B.sll_insert(&gl.first, &gl.last, node)
	gl.len += 1
	return node
}

grapheme_list_free :: proc(gl: Grapheme_List) {
	for node := gl.first; node != nil; node = node.next {
		node.next           = state.grapheme_free
		state.grapheme_free = node
	}
}

Grapheme_List_Iterator :: struct {
	current: ^Grapheme_Node,
}

grapheme_list_iterator :: proc(gl: Grapheme_List) -> Grapheme_List_Iterator {
	return {
		current = gl.first,
	}
}

grapheme_list_iterate :: proc(it: ^Grapheme_List_Iterator) -> (grapheme: Grapheme, ok: bool) {
	node := it.current
	if node == nil {
		return
	}
	it.current = node.next

	return node.grapheme, true
}
